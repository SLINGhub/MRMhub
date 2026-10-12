//! Own only processes launched by this app, never kill by executable name.
use std::{
    process::{Child, Command, Output},
    sync::{Arc, Mutex, Weak},
};

#[derive(Default)]
struct Registry {
    closing: bool,
    trees: Vec<Weak<ProcessTree>>,
}

#[derive(Default)]
pub struct ProcessState {
    registry: Mutex<Registry>,
    // Windows descendants inherit this job even if they detach from a shell.
    // The OS closes its last handle on app exit, including abnormal termination.
    #[cfg(windows)]
    _app_job: Option<WindowsJob>,
}

impl ProcessState {
    pub fn new() -> Result<Self, String> {
        Ok(Self {
            registry: Mutex::default(),
            #[cfg(windows)]
            _app_job: Some(WindowsJob::for_process(std::process::id())?),
        })
    }

    pub fn spawn(&self, command: &mut Command) -> Result<ManagedChild, String> {
        let mut registry = self.registry.lock().map_err(|e| e.to_string())?;
        if registry.closing {
            return Err("The application is closing.".into());
        }
        #[cfg(unix)]
        {
            use std::os::unix::process::CommandExt;
            // A separate session owns R's subprocesses without touching any
            // terminal, RStudio or Integrator instance launched outside this app.
            unsafe {
                command.pre_exec(|| {
                    if libc::setsid() < 0 {
                        return Err(std::io::Error::last_os_error());
                    }
                    Ok(())
                });
            }
        }
        let mut child = command.spawn().map_err(|e| e.to_string())?;
        let tree = match ProcessTree::new(child.id()) {
            Ok(tree) => Arc::new(tree),
            Err(error) => {
                let _ = child.kill();
                let _ = child.wait();
                return Err(error);
            }
        };
        registry.trees.retain(|tree| tree.strong_count() > 0);
        registry.trees.push(Arc::downgrade(&tree));
        Ok(ManagedChild {
            child: Some(child),
            tree,
        })
    }

    pub fn output(&self, command: &mut Command) -> Result<Output, String> {
        command
            .stdin(std::process::Stdio::null())
            .stdout(std::process::Stdio::piped())
            .stderr(std::process::Stdio::piped());
        let mut managed = self.spawn(command)?;
        managed
            .child
            .take()
            .unwrap()
            .wait_with_output()
            .map_err(|e| e.to_string())
    }

    pub fn spawn_pty(
        &self,
        spawn: impl FnOnce() -> Result<Box<dyn portable_pty::Child + Send + Sync>, String>,
    ) -> Result<(Box<dyn portable_pty::Child + Send + Sync>, Arc<ProcessTree>), String> {
        let mut registry = self.registry.lock().map_err(|e| e.to_string())?;
        if registry.closing {
            return Err("The application is closing.".into());
        }
        let mut child = spawn()?;
        let tree = match child
            .process_id()
            .ok_or("The terminal process ID is unavailable.")
            .and_then(|pid| {
                ProcessTree::new(pid).map_err(|_| "Could not own the terminal process tree.")
            }) {
            Ok(tree) => Arc::new(tree),
            Err(error) => {
                let _ = child.kill();
                let _ = child.wait();
                return Err(error.into());
            }
        };
        registry.trees.retain(|tree| tree.strong_count() > 0);
        registry.trees.push(Arc::downgrade(&tree));
        Ok((child, tree))
    }

    pub fn shutdown(&self) {
        let trees = {
            let mut registry = self.registry.lock().unwrap_or_else(|e| e.into_inner());
            registry.closing = true; // No late R/worker/PTY launch can race shutdown.
            registry
                .trees
                .drain(..)
                .filter_map(|tree| tree.upgrade())
                .collect::<Vec<_>>()
        };
        for tree in trees {
            tree.stop();
        }
    }
}

impl Drop for ProcessState {
    fn drop(&mut self) {
        self.shutdown();
    }
}

pub struct ManagedChild {
    pub child: Option<Child>,
    tree: Arc<ProcessTree>,
}
impl ManagedChild {
    pub fn finish(&self) {
        self.tree.stop();
    }
}
impl Drop for ManagedChild {
    fn drop(&mut self) {
        self.tree.stop();
        if let Some(child) = self.child.as_mut() {
            let _ = child.wait();
        }
    }
}

pub struct ProcessTree {
    stopped: Mutex<bool>,
    #[cfg(unix)]
    pid: i32,
    #[cfg(unix)]
    started: Option<u128>,
    #[cfg(windows)]
    job: Mutex<Option<WindowsJob>>,
}
impl ProcessTree {
    fn new(pid: u32) -> Result<Self, String> {
        if pid <= 1 || pid == std::process::id() {
            return Err("Invalid owned process ID.".into());
        }
        Ok(Self {
            stopped: Mutex::new(false),
            #[cfg(unix)]
            pid: pid as i32,
            #[cfg(unix)]
            started: unix_snapshot()
                .iter()
                .find(|p| p.pid == pid as i32)
                .map(|p| p.started),
            #[cfg(windows)]
            job: Mutex::new(Some(WindowsJob::for_process(pid)?)),
        })
    }
    pub fn stop(&self) {
        // A simultaneous exit handler must wait for an in-progress cleanup,
        // rather than see "stopping" and exit before background jobs are killed.
        let mut stopped = self.stopped.lock().unwrap_or_else(|e| e.into_inner());
        if *stopped {
            return;
        }
        *stopped = true;
        #[cfg(unix)]
        {
            let processes = unix_snapshot();
            // A recycled PID must never target a different application's session.
            if processes
                .iter()
                .any(|p| p.pid == self.pid && self.started.is_some_and(|start| start != p.started))
            {
                return;
            }
            let mut owned = std::collections::HashSet::from([self.pid]);
            owned.extend(
                processes
                    .iter()
                    .filter(|p| p.session == self.pid)
                    .map(|p| p.pid),
            );
            loop {
                let count = owned.len();
                owned.extend(
                    processes
                        .iter()
                        .filter(|p| owned.contains(&p.parent))
                        .map(|p| p.pid)
                        .collect::<Vec<_>>(),
                );
                if owned.len() == count {
                    break;
                }
            }
            // Kill the isolated root group first; then other foreground/background
            // job-control groups and still-parented children in their own sessions.
            unsafe {
                libc::kill(-self.pid, libc::SIGKILL);
            }
            for pid in owned {
                if pid > 1 && pid != std::process::id() as i32 {
                    unsafe {
                        libc::kill(pid, libc::SIGKILL);
                    }
                }
            }
        }
        #[cfg(windows)]
        {
            self.job.lock().unwrap_or_else(|e| e.into_inner()).take();
        }
    }
}
impl Drop for ProcessTree {
    fn drop(&mut self) {
        self.stop();
    }
}

#[cfg(unix)]
struct UnixProcess {
    pid: i32,
    parent: i32,
    session: i32,
    started: u128,
}

#[cfg(target_os = "macos")]
fn unix_snapshot() -> Vec<UnixProcess> {
    let capacity = unsafe { libc::proc_listallpids(std::ptr::null_mut(), 0) }.max(0) as usize + 256;
    let mut pids = vec![0i32; capacity];
    let count = unsafe { libc::proc_listallpids(pids.as_mut_ptr().cast(), (pids.len() * 4) as i32) }
        .max(0) as usize;
    pids.into_iter()
        .take(count)
        .filter_map(|pid| {
            if pid <= 1 {
                return None;
            }
            let mut info = std::mem::MaybeUninit::<libc::proc_bsdinfo>::uninit();
            let size = std::mem::size_of::<libc::proc_bsdinfo>();
            if unsafe {
                libc::proc_pidinfo(
                    pid,
                    libc::PROC_PIDTBSDINFO,
                    0,
                    info.as_mut_ptr().cast(),
                    size as i32,
                )
            } != size as i32
            {
                return None;
            }
            let info = unsafe { info.assume_init() };
            Some(UnixProcess {
                pid,
                parent: info.pbi_ppid as i32,
                session: unsafe { libc::getsid(pid) },
                started: u128::from(info.pbi_start_tvsec) * 1_000_000
                    + u128::from(info.pbi_start_tvusec),
            })
        })
        .collect()
}

#[cfg(all(unix, not(target_os = "macos")))]
fn unix_snapshot() -> Vec<UnixProcess> {
    std::fs::read_dir("/proc")
        .into_iter()
        .flatten()
        .flatten()
        .filter_map(|entry| {
            let pid = entry.file_name().to_str()?.parse().ok()?;
            let stat = std::fs::read_to_string(entry.path().join("stat")).ok()?;
            let fields = stat[stat.rfind(')')? + 1..]
                .split_whitespace()
                .collect::<Vec<_>>();
            Some(UnixProcess {
                pid,
                parent: fields.get(1)?.parse().ok()?,
                session: fields.get(3)?.parse().ok()?,
                started: fields.get(19)?.parse().ok()?,
            })
        })
        .collect()
}

#[cfg(windows)]
struct WindowsJob(std::os::windows::io::OwnedHandle);
#[cfg(windows)]
impl WindowsJob {
    fn for_process(pid: u32) -> Result<Self, String> {
        use std::os::windows::io::{AsRawHandle, FromRawHandle, OwnedHandle};
        use windows_sys::Win32::System::{JobObjects::*, Threading::*};
        let handle = unsafe { CreateJobObjectW(std::ptr::null(), std::ptr::null()) };
        if handle.is_null() {
            return Err(std::io::Error::last_os_error().to_string());
        }
        let job = Self(unsafe { OwnedHandle::from_raw_handle(handle) });
        let mut limits: JOBOBJECT_EXTENDED_LIMIT_INFORMATION = unsafe { std::mem::zeroed() };
        limits.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;
        if unsafe {
            SetInformationJobObject(
                handle,
                JobObjectExtendedLimitInformation,
                (&limits as *const JOBOBJECT_EXTENDED_LIMIT_INFORMATION).cast(),
                std::mem::size_of_val(&limits) as u32,
            )
        } == 0
        {
            return Err(std::io::Error::last_os_error().to_string());
        }
        let process = unsafe { OpenProcess(PROCESS_SET_QUOTA | PROCESS_TERMINATE, 0, pid) };
        if process.is_null() {
            return Err(std::io::Error::last_os_error().to_string());
        }
        let process = unsafe { OwnedHandle::from_raw_handle(process) };
        if unsafe { AssignProcessToJobObject(job.0.as_raw_handle(), process.as_raw_handle()) } == 0
        {
            return Err(format!(
                "Could not contain the application process tree: {}",
                std::io::Error::last_os_error()
            ));
        }
        Ok(job)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn shutdown_is_idempotent_and_rejects_late_launches() {
        let state = ProcessState::default();
        state.shutdown();
        state.shutdown();
        assert!(
            state
                .spawn(&mut Command::new("unused"))
                .err()
                .unwrap()
                .contains("closing")
        );
    }
    #[cfg(unix)]
    #[test]
    fn shutdown_kills_owned_work_and_children_but_not_an_unrelated_process() {
        use std::{
            io::{BufRead, BufReader},
            process::Stdio,
            time::Duration,
        };
        let state = ProcessState::default();
        let mut outside = Command::new("/bin/sleep").arg("120").spawn().unwrap();
        let mut command = Command::new("/bin/sh");
        command
            .args(["-c", "sleep 120 & echo $!; wait"])
            .stdout(Stdio::piped());
        let mut owned = state.spawn(&mut command).unwrap();
        let child = owned.child.as_mut().unwrap();
        let mut line = String::new();
        BufReader::new(child.stdout.take().unwrap())
            .read_line(&mut line)
            .unwrap();
        let pid: i32 = line.trim().parse().unwrap();
        assert_eq!(unsafe { libc::getsid(pid) }, child.id() as i32);
        state.shutdown();
        assert!(!child.wait().unwrap().success());
        for _ in 0..100 {
            if !unix_snapshot().iter().any(|p| p.pid == pid) {
                break;
            }
            std::thread::sleep(Duration::from_millis(10));
        }
        assert!(!unix_snapshot().iter().any(|p| p.pid == pid));
        assert!(outside.try_wait().unwrap().is_none());
        outside.kill().unwrap();
        outside.wait().unwrap();
    }
}
