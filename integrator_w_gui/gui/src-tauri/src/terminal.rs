//! One local, interactive PTY per app. Separate from QUANT's saved R sessions.
use portable_pty::{Child, CommandBuilder, MasterPty, PtySize, native_pty_system};
use serde::Serialize;
use std::{
    io::{Read, Write},
    path::Path,
    sync::{
        Arc, Mutex,
        atomic::{AtomicBool, AtomicU64, Ordering},
        mpsc,
    },
    time::Duration,
};
use tauri::{AppHandle, Manager, State, ipc::Channel};

#[derive(Default)]
pub struct TerminalState(Mutex<Option<Session>>);
static NEXT_ID: AtomicU64 = AtomicU64::new(1);

#[derive(Clone, Serialize)]
#[serde(tag = "kind", rename_all = "camelCase")]
pub enum TerminalEvent {
    Data { id: u64, data: Vec<u8> },
    Exit { id: u64, message: String },
}
#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub struct SessionInfo {
    id: u64,
    shell: String,
    home: String,
}

struct Session {
    info: SessionInfo,
    master: Box<dyn MasterPty + Send>,
    writer: Arc<Mutex<Box<dyn Write + Send>>>,
    child: Arc<Mutex<Box<dyn Child + Send + Sync>>>,
    stopped: Arc<AtomicBool>,
    running: Arc<AtomicBool>,
    ack: mpsc::SyncSender<()>,
    tree: Arc<super::processes::ProcessTree>,
}
impl Drop for Session {
    fn drop(&mut self) {
        self.stopped.store(true, Ordering::Release);
        let _ = self.ack.try_send(());
        self.tree.stop();
        if let Ok(mut child) = self.child.lock() {
            if matches!(child.try_wait(), Ok(None)) {
                let _ = child.kill();
            }
            let _ = child.wait();
        }
        // Dropping master/writer closes the PTY (ConPTY on Windows).
    }
}
impl TerminalState {
    pub fn shutdown(&self) {
        if let Ok(mut session) = self.0.lock() {
            session.take();
        }
    }
}
fn size(cols: u16, rows: u16) -> Result<PtySize, String> {
    if !(2..=500).contains(&cols) || !(1..=300).contains(&rows) {
        return Err("Invalid terminal dimensions".into());
    }
    Ok(PtySize {
        rows,
        cols,
        pixel_width: 0,
        pixel_height: 0,
    })
}

#[cfg(unix)]
fn shell_command() -> (CommandBuilder, String) {
    // Honor SHELL, falling back to the account's login shell. Login startup
    // files supply the normal PATH, including user-installed tools.
    let command = CommandBuilder::new_default_prog();
    let shell = command.get_shell();
    (command, shell)
}
#[cfg(windows)]
fn shell_command() -> (CommandBuilder, String) {
    // Prefer PowerShell 7 if installed; otherwise use Windows' built-in 5.1.
    let pwsh = std::env::var_os("PATH")
        .and_then(|path| {
            std::env::split_paths(&path)
                .map(|p| p.join("pwsh.exe"))
                .find(|p| p.is_file())
        })
        .or_else(|| {
            std::env::var_os("ProgramFiles")
                .map(|p| Path::new(&p).join("PowerShell/7/pwsh.exe"))
                .filter(|p| p.is_file())
        });
    let executable = pwsh.unwrap_or_else(|| {
        Path::new(&std::env::var_os("SystemRoot").unwrap_or_else(|| "C:\\Windows".into()))
            .join("System32/WindowsPowerShell/v1.0/powershell.exe")
    });
    let mut cmd = CommandBuilder::new(executable);
    cmd.arg("-NoLogo");
    (cmd, "PowerShell".into())
}

fn spawn_session(
    processes: &super::processes::ProcessState,
    home: &Path,
    mut command: CommandBuilder,
    shell: String,
    dimensions: PtySize,
    send: impl Fn(TerminalEvent) -> bool + Send + Sync + 'static,
) -> Result<Session, String> {
    if !home.is_dir() {
        return Err("Your home directory could not be found".into());
    }
    command.cwd(home);
    command.env("TERM", "xterm-256color");
    command.env("COLORTERM", "truecolor");
    // Finder-launched apps often lack a locale. Without UTF-8, zsh's line
    // editor displays pasted non-ASCII characters as individual byte codes.
    #[cfg(unix)]
    if std::env::var_os("LC_ALL").is_none()
        && std::env::var_os("LC_CTYPE").is_none()
        && std::env::var("LANG").map_or(true, |value| {
            value.is_empty() || value == "C" || value == "POSIX"
        })
    {
        command.env(
            "LANG",
            if cfg!(target_os = "macos") {
                "en_US.UTF-8"
            } else {
                "C.UTF-8"
            },
        );
    }
    let pair = native_pty_system()
        .openpty(dimensions)
        .map_err(|e| e.to_string())?;
    let mut reader = pair.master.try_clone_reader().map_err(|e| e.to_string())?;
    let writer = Arc::new(Mutex::new(
        pair.master.take_writer().map_err(|e| e.to_string())?,
    ));
    let (child, tree) = processes.spawn_pty(|| pair.slave.spawn_command(command).map_err(|e| e.to_string()))?;
    drop(pair.slave);
    let id = NEXT_ID.fetch_add(1, Ordering::Relaxed);
    let child = Arc::new(Mutex::new(child));
    let stopped = Arc::new(AtomicBool::new(false));
    let running = Arc::new(AtomicBool::new(true));
    let (ack, received) = mpsc::sync_channel(1);
    let send = Arc::new(send);
    let read_stop = stopped.clone();
    let read_send = send.clone();
    let read_child = child.clone();
    let read_tree = tree.clone();
    std::thread::spawn(move || {
        let mut buffer = [0u8; 8192];
        while !read_stop.load(Ordering::Acquire) {
            match reader.read(&mut buffer) {
                Ok(0) | Err(_) => break,
                Ok(n) => {
                    if !read_send(TerminalEvent::Data {
                        id,
                        data: buffer[..n].to_vec(),
                    }) {
                        read_stop.store(true, Ordering::Release);
                        read_tree.stop();
                        if let Ok(mut child) = read_child.lock() {
                            if matches!(child.try_wait(), Ok(None)) {
                                let _ = child.kill();
                            }
                        }
                        break;
                    }
                    // Backpressure: only one chunk may await xterm's parser.
                    // This bounds memory even for endless output or hidden tabs.
                    while !read_stop.load(Ordering::Acquire) {
                        match received.recv_timeout(Duration::from_millis(250)) {
                            Ok(()) => break,
                            Err(mpsc::RecvTimeoutError::Disconnected) => return,
                            Err(mpsc::RecvTimeoutError::Timeout) => {}
                        }
                    }
                }
            }
        }
    });
    let wait_child = child.clone();
    let wait_running = running.clone();
    let wait_tree = tree.clone();
    std::thread::spawn(move || {
        loop {
            let status = wait_child.lock().unwrap().try_wait();
            match status {
                Ok(None) => std::thread::sleep(Duration::from_millis(100)),
                result => {
                    wait_running.store(false, Ordering::Release);
                    wait_tree.stop();
                    let message = match result {
                        Ok(Some(s)) => format!("Shell exited ({})", s.exit_code()),
                        Err(e) => e.to_string(),
                        _ => unreachable!(),
                    };
                    send(TerminalEvent::Exit { id, message });
                    break;
                }
            }
        }
    });
    Ok(Session {
        info: SessionInfo {
            id,
            shell,
            home: home.to_string_lossy().into(),
        },
        master: pair.master,
        writer,
        child,
        stopped,
        running,
        ack,
        tree,
    })
}

#[tauri::command]
pub async fn terminal_start(
    app: AppHandle,
    output: Channel<TerminalEvent>,
    cols: u16,
    rows: u16,
) -> Result<SessionInfo, String> {
    tauri::async_runtime::spawn_blocking(move || {
        let state = app.state::<TerminalState>();
        let mut active = state.0.lock().map_err(|e| e.to_string())?;
        if active
            .as_ref()
            .is_some_and(|s| s.running.load(Ordering::Acquire))
        {
            return Err("A terminal session is already running".into());
        }
        active.take();
        let home = app.path().home_dir().map_err(|e| e.to_string())?;
        let (command, shell) = shell_command();
        let session = spawn_session(&app.state::<super::processes::ProcessState>(), &home, command, shell, size(cols, rows)?, move |event| {
            output.send(event).is_ok()
        })?;
        let info = SessionInfo {
            id: session.info.id,
            shell: session.info.shell.clone(),
            home: session.info.home.clone(),
        };
        *active = Some(session);
        Ok(info)
    })
    .await
    .map_err(|e| e.to_string())?
}

#[tauri::command]
pub async fn terminal_write(app: AppHandle, id: u64, data: String) -> Result<(), String> {
    if data.len() > 65536 {
        return Err("Terminal input is too large".into());
    }
    tauri::async_runtime::spawn_blocking(move || {
        let state = app.state::<TerminalState>();
        let writer = {
            let active = state.0.lock().map_err(|e| e.to_string())?;
            let session = active
                .as_ref()
                .filter(|s| s.info.id == id && s.running.load(Ordering::Acquire))
                .ok_or("Terminal session has ended")?;
            session.writer.clone()
        };
        // Never hold the session-state lock during a potentially blocking write:
        // output acknowledgements and Stop must remain available.
        let mut writer = writer.lock().map_err(|e| e.to_string())?;
        writer
            .write_all(data.as_bytes())
            .and_then(|_| writer.flush())
            .map_err(|e| e.to_string())
    })
    .await
    .map_err(|e| e.to_string())?
}
#[tauri::command]
pub async fn terminal_resize(
    state: State<'_, TerminalState>,
    id: u64,
    cols: u16,
    rows: u16,
) -> Result<(), String> {
    let active = state.0.lock().map_err(|e| e.to_string())?;
    let session = active
        .as_ref()
        .filter(|s| s.info.id == id)
        .ok_or("Terminal session has ended")?;
    session
        .master
        .resize(size(cols, rows)?)
        .map_err(|e| e.to_string())
}
#[tauri::command]
pub async fn terminal_ack(state: State<'_, TerminalState>, id: u64) -> Result<(), String> {
    if let Ok(active) = state.0.lock() {
        if let Some(session) = active.as_ref().filter(|s| s.info.id == id) {
            let _ = session.ack.try_send(());
        }
    }
    Ok(())
}
#[tauri::command]
pub async fn terminal_stop(app: AppHandle, id: u64) -> Result<(), String> {
    tauri::async_runtime::spawn_blocking(move || {
        let state = app.state::<TerminalState>();
        let mut active = state.0.lock().map_err(|e| e.to_string())?;
        if active.as_ref().is_some_and(|s| s.info.id == id) {
            active.take();
        }
        Ok(())
    })
    .await
    .map_err(|e| e.to_string())?
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn terminal_rejects_invalid_sizes() {
        assert!(size(0, 24).is_err());
        assert!(size(80, 0).is_err());
        assert!(size(501, 24).is_err());
        assert!(size(80, 24).is_ok());
    }
    #[cfg(unix)]
    #[test]
    fn real_pty_cwd_input_unicode_resize_and_exit() {
        let processes = super::super::processes::ProcessState::default();
        let (tx, rx) = mpsc::channel();
        let home = std::env::temp_dir().canonicalize().unwrap();
        let mut command = CommandBuilder::new("/bin/sh");
        command.arg("-i");
        let session = spawn_session(
            &processes,
            &home,
            command,
            "sh".into(),
            size(80, 24).unwrap(),
            move |e| tx.send(e).is_ok(),
        )
        .unwrap();
        session.master.resize(size(100, 30).unwrap()).unwrap();
        session
            .writer
            .lock()
            .unwrap()
            .write_all(b"pwd; printf '\\342\\234\\223'; stty size; exit\r")
            .unwrap();
        let mut bytes = Vec::new();
        let mut exited = false;
        let until = std::time::Instant::now() + Duration::from_secs(8);
        while std::time::Instant::now() < until {
            match rx.recv_timeout(Duration::from_millis(300)) {
                Ok(TerminalEvent::Data { data, .. }) => {
                    bytes.extend(data);
                    let _ = session.ack.try_send(());
                }
                Ok(TerminalEvent::Exit { .. }) => exited = true,
                Err(_) if exited => break,
                Err(_) => {}
            }
        }
        let output = String::from_utf8_lossy(&bytes);
        assert!(exited, "{output}");
        assert!(output.contains(home.to_str().unwrap()), "{output}");
        assert!(output.contains('✓'), "{output}");
        assert!(output.contains("30 100"), "{output}");
    }
    #[cfg(unix)]
    #[test]
    fn ending_session_reaps_shell_even_when_output_is_backpressured() {
        let processes = super::super::processes::ProcessState::default();
        let (tx, rx) = mpsc::channel();
        let mut command = CommandBuilder::new("/bin/sh");
        command.args(["-c", "while :; do printf 'test output\\n'; done"]);
        let session = spawn_session(
            &processes,
            &std::env::temp_dir(),
            command,
            "sh".into(),
            size(80, 24).unwrap(),
            move |e| tx.send(e).is_ok(),
        )
        .unwrap();
        assert!(matches!(
            rx.recv_timeout(Duration::from_secs(3)),
            Ok(TerminalEvent::Data { .. })
        ));
        // No ACK: reader is deliberately blocked waiting for the UI.
        assert!(rx.recv_timeout(Duration::from_millis(150)).is_err());
        let child = session.child.clone();
        drop(session);
        let until = std::time::Instant::now() + Duration::from_secs(3);
        while std::time::Instant::now() < until {
            if child.lock().unwrap().try_wait().unwrap().is_some() {
                return;
            }
            std::thread::sleep(Duration::from_millis(20));
        }
        panic!("Shell remained alive after session ended");
    }
    #[cfg(windows)]
    #[test]
    fn windows_uses_interactive_powershell_not_cmd_or_bash() {
        let (command, name) = shell_command();
        assert_eq!(name, "PowerShell");
        let args = command.get_argv();
        assert!(
            args[0].to_string_lossy().ends_with("powershell.exe")
                || args[0].to_string_lossy().ends_with("pwsh.exe")
        );
        assert!(!args.iter().any(|a| a == "-NonInteractive"));
    }
    #[cfg(unix)]
    #[test]
    fn app_shutdown_kills_terminal_background_jobs_in_other_job_control_groups() {
        let processes = super::super::processes::ProcessState::default();
        let pid_file = std::env::temp_dir().join(format!("mrmhub-pty-child-{}-{}", std::process::id(), NEXT_ID.fetch_add(1, Ordering::Relaxed)));
        let mut command = CommandBuilder::new("/bin/sh");
        command.args(["-c", &format!("set -m; trap '' HUP; sleep 120 & echo $! > '{}'; wait", pid_file.display())]);
        let session = spawn_session(&processes, &std::env::temp_dir(), command, "sh".into(), size(80, 24).unwrap(), |_| true).unwrap();
        let until = std::time::Instant::now() + Duration::from_secs(3);
        let pid = loop {
            if let Ok(text) = std::fs::read_to_string(&pid_file) {
                if let Ok(pid) = text.trim().parse::<i32>() { break pid; }
            }
            assert!(std::time::Instant::now() < until, "Background job did not start");
            std::thread::sleep(Duration::from_millis(10));
        };
        let _ = std::fs::remove_file(pid_file);
        let root = session.child.lock().unwrap().process_id().unwrap() as i32;
        assert_eq!(unsafe { libc::getsid(pid) }, root);
        assert_ne!(unsafe { libc::getpgid(pid) }, unsafe { libc::getpgid(root) });
        processes.shutdown(); drop(session);
        let until = std::time::Instant::now() + Duration::from_secs(3);
        while unsafe { libc::kill(pid, 0) } == 0 && std::time::Instant::now() < until {
            std::thread::sleep(Duration::from_millis(10));
        }
        assert_ne!(unsafe { libc::kill(pid, 0) }, 0, "Background job survived app shutdown");
    }
}
