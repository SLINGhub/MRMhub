//! Native QUANT bridge. No shell, no reimplementation of scientific methods.
use base64::{Engine, engine::general_purpose::STANDARD};
use serde_json::{Value, json};
use std::{
    fs,
    io::{BufRead, BufReader, Write},
    path::{Component, Path, PathBuf},
    process::{Command, Stdio},
    sync::atomic::{AtomicBool, AtomicU64, Ordering},
    time::{SystemTime, UNIX_EPOCH},
};
use tauri::{AppHandle, Emitter, Manager};

include!(concat!(env!("OUT_DIR"), "/quant_source.rs"));
const RUNNER: &str = include_str!("../quant/runner.R");
const CATALOG: &str = include_str!("../quant/catalog.R");
const LEGACY: &str = include_str!("../quant/legacy.R");
pub struct QuantState(pub AtomicBool);
struct Busy<'a>(&'a AtomicBool);
impl Drop for Busy<'_> {
    fn drop(&mut self) {
        self.0.store(false, Ordering::SeqCst);
    }
}
fn lock(state: &QuantState) -> Result<Busy<'_>, String> {
    state
        .0
        .compare_exchange(false, true, Ordering::SeqCst, Ordering::SeqCst)
        .map_err(|_| "QUANT is busy. Wait for the current operation to finish.".to_string())?;
    Ok(Busy(&state.0))
}
fn unique_id() -> String {
    static SEQUENCE: AtomicU64 = AtomicU64::new(0);
    format!(
        "q-{}-{}-{}",
        SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_nanos(),
        std::process::id(), SEQUENCE.fetch_add(1, Ordering::Relaxed)
    )
}
fn config_dir(app: &AppHandle) -> Result<PathBuf, String> {
    let path = app
        .path()
        .app_data_dir()
        .map_err(|e| e.to_string())?
        .join("quant");
    fs::create_dir_all(&path).map_err(|e| e.to_string())?;
    Ok(path)
}
fn engine(app: &AppHandle) -> Result<PathBuf, String> {
    let path = config_dir(app)?.join(PACKAGE_ID);
    for (name, bytes) in PACKAGE_FILES {
        let target = path.join("package").join(name);
        if !target.is_file() {
            fs::create_dir_all(target.parent().unwrap()).map_err(|e| e.to_string())?;
            fs::write(target, bytes).map_err(|e| e.to_string())?;
        }
    }
    fs::write(path.join("runner.R"), RUNNER).map_err(|e| e.to_string())?;
    fs::write(path.join("catalog.R"), CATALOG).map_err(|e| e.to_string())?;
    fs::write(path.join("legacy.R"), LEGACY).map_err(|e| e.to_string())?;
    Ok(path)
}
fn command(path: &Path) -> Command {
    let mut command = Command::new(path);
    command.env("R_CLI_NUM_COLORS", "1").env("NO_COLOR", "1");
    #[cfg(windows)]
    {
        use std::os::windows::process::CommandExt;
        command.creation_flags(0x08000000); // CREATE_NO_WINDOW (also R CMD INSTALL)
    }
    command
}
fn runtime(app: &AppHandle) -> Result<(PathBuf, String), String> {
    let mut candidates = Vec::new();
    if let Ok(saved) = fs::read_to_string(config_dir(app)?.join("rscript-path.txt")) {
        if !saved.trim().is_empty() {
            candidates.push(PathBuf::from(saved.trim()));
        }
    }
    let executable = if cfg!(windows) {
        "Rscript.exe"
    } else {
        "Rscript"
    };
    if let Some(paths) = std::env::var_os("PATH") {
        candidates.extend(std::env::split_paths(&paths).map(|p| p.join(executable)));
    }
    candidates.extend(
        [
            "/usr/local/bin/Rscript",
            "/opt/homebrew/bin/Rscript",
            "/usr/bin/Rscript",
            "/Library/Frameworks/R.framework/Resources/bin/Rscript",
        ]
        .map(PathBuf::from),
    );
    #[cfg(windows)]
    for name in ["ProgramFiles", "LOCALAPPDATA"] {
        if let Some(base) = std::env::var_os(name) {
            for suffix in ["R", "Programs/R"] {
                if let Ok(entries) = fs::read_dir(PathBuf::from(&base).join(suffix)) {
                    let mut dirs: Vec<_> = entries.flatten().map(|e| e.path()).collect();
                    dirs.sort();
                    dirs.reverse();
                    for dir in dirs {
                        candidates.push(dir.join("bin/Rscript.exe"));
                        candidates.push(dir.join("bin/x64/Rscript.exe"));
                    }
                }
            }
        }
    }
    for path in candidates {
        if !path.is_file() {
            continue;
        }
        if let Ok(output) = app.state::<super::processes::ProcessState>().output(command(&path).arg("--version")) {
            if output.status.success() {
                let version = format!(
                    "{}{}",
                    String::from_utf8_lossy(&output.stdout),
                    String::from_utf8_lossy(&output.stderr)
                )
                .trim()
                .to_owned();
                return Ok((path, version));
            }
        }
    }
    Err("Rscript was not found. Install R 4.1 or newer, then choose its Rscript executable here. RStudio is not required.".into())
}
fn library(engine: &Path, version: &str) -> PathBuf {
    // Separate libraries across R versions. Package source is
    // already pinned by the engine directory's content fingerprint.
    use std::hash::{Hash, Hasher};
    let mut hash = std::collections::hash_map::DefaultHasher::new();
    version.hash(&mut hash);
    engine.join(format!("library-{:016x}", hash.finish()))
}
// Reuse dependencies from ready libraries for this exact R runtime, without
// copying hundreds of MB on every bundled-source update. mrmhub is still
// loaded explicitly from the current engine's library.
fn reusable_libraries(engine: &Path, lib: &Path) -> Vec<PathBuf> {
    let mut paths = Vec::new();
    if let (Some(root), Some(name)) = (engine.parent(), lib.file_name()) {
        if let Ok(entries) = fs::read_dir(root) {
            for entry in entries.flatten() {
                if !entry.file_type().is_ok_and(|t| t.is_dir()) { continue; }
                let candidate = entry.path().join(name);
                if candidate != lib && candidate.join("ready").is_file() { paths.push(candidate); }
            }
        }
    }
    paths.sort();
    paths
}
fn read_json(path: &Path) -> Result<Value, String> {
    serde_json::from_slice(&fs::read(path).map_err(|e| e.to_string())?).map_err(|e| e.to_string())
}
fn write_json(path: &Path, value: &Value) -> Result<(), String> {
    fs::write(
        path,
        serde_json::to_vec_pretty(value).map_err(|e| e.to_string())?,
    )
    .map_err(|e| e.to_string())
}
fn progress_message(text: &str) -> Option<Value> {
    let payload: Value = serde_json::from_str(text.strip_prefix("__MRMHUB_QUANT_PROGRESS__")?).ok()?;
    let percent = payload["percent"].as_f64()?;
    if !(0.0..=100.0).contains(&percent) || payload["token"].as_str()?.len() > 100
        || payload["message"].as_str()?.len() > 1024 { return None; }
    Some(payload)
}

fn run_r(
    app: &AppHandle,
    mode: &str,
    engine: &Path,
    work: &Path,
    r: &Path,
    lib: &Path,
) -> Result<Value, String> {
    fs::create_dir_all(work).map_err(|e| e.to_string())?;
    let log = std::sync::Arc::new(std::sync::Mutex::new(
        fs::File::create(work.join("run.log")).map_err(|e| e.to_string())?,
    ));
    let mut r_command = command(r);
    r_command
        .env("MRMHUB_QUANT_LIBRARIES", std::env::join_paths(reusable_libraries(engine, lib)).map_err(|e| e.to_string())?)
        .arg("--vanilla")
        .arg(engine.join("runner.R"))
        .args([
            std::ffi::OsStr::new(mode),
            engine.as_os_str(),
            work.as_os_str(),
            lib.as_os_str(),
        ])
        .current_dir(work)
        .stdin(Stdio::null())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped());
    let mut managed = app.state::<super::processes::ProcessState>().spawn(&mut r_command)
        .map_err(|e| format!("Could not start R: {e}"))?;
    let child = managed.child.as_mut().unwrap();
    fn forward(
        reader: impl std::io::Read + Send + 'static,
        app: AppHandle,
        log: std::sync::Arc<std::sync::Mutex<fs::File>>,
    ) -> std::thread::JoinHandle<()> {
        std::thread::spawn(move || {
            for line in BufReader::new(reader).split(b'\n').flatten() {
                let text = super::clean_worker_output(&line);
                if let Some(progress) = progress_message(&text) {
                    let _ = app.emit("quant-progress", progress);
                    continue;
                }
                if let Ok(mut file) = log.lock() {
                    let _ = writeln!(file, "{text}");
                }
                let _ = app.emit("quant-log", &text);
            }
        })
    }
    let stdout = forward(child.stdout.take().unwrap(), app.clone(), log.clone());
    let stderr = forward(child.stderr.take().unwrap(), app.clone(), log);
    let status = child.wait().map_err(|e| e.to_string())?;
    managed.finish();
    let _ = stdout.join();
    let _ = stderr.join();
    if !status.success() {
        let error = fs::read_to_string(work.join("error.txt")).unwrap_or_else(|_| {
            "R could not finish. See the QUANT activity log for details.".into()
        });
        return Err(error);
    }
    if mode == "setup" {
        Ok(json!({"ready": true}))
    } else {
        read_json(&work.join("result.json"))
    }
}
pub(super) fn dataset_root(project: &str) -> Result<PathBuf, String> {
    let path = Path::new(project)
        .canonicalize()
        .map_err(|_| "Choose an existing dataset folder.")?;
    if !path.is_dir() {
        return Err("Dataset must be a folder.".into());
    }
    Ok(path.join("QUANT"))
}
fn valid_component(value: &str) -> bool {
    !value.is_empty()
        && value
            .chars()
            .all(|c| c.is_ascii_alphanumeric() || c == '-' || c == '_' || c == '.')
        && Path::new(value)
            .components()
            .all(|c| matches!(c, Component::Normal(_)))
}
fn job_path(root: &Path, id: &str) -> Result<PathBuf, String> {
    if !id.starts_with("q-") || !valid_component(id) {
        return Err("Invalid QUANT checkpoint ID.".into());
    }
    let path = root.join(id).canonicalize().map_err(|e| e.to_string())?;
    let canonical = root.canonicalize().map_err(|e| e.to_string())?;
    if !path.starts_with(canonical) || !path.join("completed.json").is_file() {
        return Err("Checkpoint is unavailable or incomplete.".into());
    }
    Ok(path)
}
fn valid_artifact_name(name: &str) -> bool {
    !name.is_empty() && name != "." && name != ".."
        && !name.chars().any(|c| matches!(c, '/' | '\\' | ':' | '\0'))
}
fn artifact_path(project: &str, id: &str, name: &str) -> Result<PathBuf, String> {
    if !valid_artifact_name(name) {
        return Err("Invalid artifact name.".into());
    }
    let job = job_path(&dataset_root(project)?, id)?;
    let result = read_json(&job.join("completed.json"))?;
    let allowed = result["artifacts"]
        .as_array()
        .is_some_and(|a| a.iter().any(|a| a["name"] == name));
    if !allowed {
        return Err("This file is not an output of the selected analysis.".into());
    }
    let file = job.join(name).canonicalize().map_err(|e| e.to_string())?;
    if !file.starts_with(job) || !file.is_file() {
        return Err("Artifact is outside its analysis folder.".into());
    }
    Ok(file)
}

#[tauri::command]
pub async fn quant_status(app: AppHandle, rscript: Option<String>) -> Result<Value, String> {
    tauri::async_runtime::spawn_blocking(move || {
        let state = app.state::<QuantState>(); let _busy = lock(&state)?;
        if let Some(path) = rscript {
            let path = Path::new(&path).canonicalize().map_err(|e| e.to_string())?;
            fs::write(config_dir(&app)?.join("rscript-path.txt"), path.to_string_lossy().as_bytes()).map_err(|e| e.to_string())?;
        }
        let (r, version) = match runtime(&app) { Ok(v) => v, Err(e) => return Ok(json!({"ready": false, "message": e})) };
        let engine = engine(&app)?; let lib = library(&engine, &version);
        let ready = lib.join("ready").is_file();
        let catalog = if ready { run_r(&app, "catalog", &engine, &engine.join("catalog"), &r, &lib)? } else { Value::Null };
        Ok(json!({"ready": ready, "rscript": r, "rVersion": version, "packageId": PACKAGE_ID, "catalog": catalog}))
    }).await.map_err(|e| e.to_string())?
}

#[tauri::command]
pub async fn quant_setup(app: AppHandle, packages: Option<Vec<String>>) -> Result<Value, String> {
    tauri::async_runtime::spawn_blocking(move || {
        let state = app.state::<QuantState>();
        let _busy = lock(&state)?;
        let (r, version) = runtime(&app)?;
        let engine = engine(&app)?;
        let lib = library(&engine, &version);
        let packages = packages.unwrap_or_default();
        if packages.iter().any(|p| !["sva", "ranger", "rgoslin", "enviPat"].contains(&p.as_str())) {
            return Err("Unsupported optional QUANT dependency.".into());
        }
        let work = engine.join(unique_id());
        fs::create_dir_all(&work).map_err(|e| e.to_string())?;
        fs::write(work.join("optional-packages.txt"), packages.join("\n")).map_err(|e| e.to_string())?;
        run_r(&app, "setup", &engine, &work, &r, &lib)
    })
    .await
    .map_err(|e| e.to_string())?
}

#[tauri::command]
pub fn quant_history(project: String) -> Result<Value, String> {
    let root = dataset_root(&project)?;
    Ok(json!(history_at(&root)?))
}

fn history_at(root: &Path) -> Result<Vec<Value>, String> {
    let mut results = Vec::new();
    if root.exists() {
        for entry in fs::read_dir(root).map_err(|e| e.to_string())?.flatten() {
            let id = entry.file_name().to_string_lossy().into_owned();
            if !id.starts_with("q-") || !valid_component(&id)
                || !entry.file_type().map_err(|e| e.to_string())?.is_dir() { continue; }
            let manifest = entry.path().join("completed.json");
            // A size/cleanup scan must not read manifests linked outside QUANT.
            if !fs::symlink_metadata(&manifest).is_ok_and(|meta| meta.file_type().is_file()) { continue; }
            if let Ok(mut value) = read_json(&manifest) {
                if value["id"] != id { continue; }
                value["resumable"] = json!(entry.path().join(snapshot_name(&value)).is_file());
                // Manifests stay unchanged: restoring a trashed PNG to its original
                // location makes it reappear, without rewriting scientific outputs.
                if let Some(artifacts) = value["artifacts"].as_array_mut() {
                    artifacts.retain(|a| a["name"].as_str().is_some_and(|n|
                        valid_artifact_name(n) && entry.path().join(n).is_file()));
                }
                results.push(value);
            }
        }
    }
    results.sort_by(|a, b| b["id"].as_str().cmp(&a["id"].as_str()));
    Ok(results)
}

fn snapshot_name(result: &Value) -> &'static str {
    if result["action"] == "legacy" { "workspace.rds" } else { "experiment.rds" }
}

// Only generated snapshot filenames inside a verified job; never recurse
// through user exports or follow file/directory symlinks during compaction.
fn remove_snapshots(job: &Path, names: &[&str]) -> Result<u64, String> {
    let mut bytes = 0;
    for name in names {
        let path = job.join(name);
        match fs::symlink_metadata(&path) {
            Ok(meta) if meta.file_type().is_file() => {
                fs::remove_file(&path).map_err(|e| format!("Could not retire {}: {e}", path.display()))?;
                bytes += meta.len();
            },
            Ok(_) => return Err(format!("Refusing to compact a linked/non-file snapshot: {}", path.display())),
            Err(e) if e.kind() == std::io::ErrorKind::NotFound => {},
            Err(e) => return Err(e.to_string()),
        }
    }
    Ok(bytes)
}

pub(super) fn snapshot_cleanup_plan(root: &Path, include_older_versions: bool) -> Result<Vec<(PathBuf, Vec<&'static str>)>, String> {
    if !root.exists() { return Ok(Vec::new()); }
    if !fs::symlink_metadata(root).map_err(|e| e.to_string())?.file_type().is_dir() {
        return Err("Storage cleanup does not follow linked QUANT folders.".into());
    }
    let mut retained = [false; 2];
    let mut plan = Vec::new();
    for result in history_at(root)? {
        let legacy = result["action"] == "legacy";
        let slot = usize::from(legacy);
        let keep = result["resumable"] == true && !retained[slot];
        retained[slot] |= keep;
        // Existing users explicitly approve retiring pre-rolling checkpoints.
        if !include_older_versions && result["storagePolicy"] != "rolling-v1" { continue; }
        let job = job_path(root, result["id"].as_str().ok_or("Invalid checkpoint ID.")?)?;
        let names: &[&str] = if legacy {
            if keep { &["experiment.rds"] } else { &["workspace.rds", "experiment.rds"] }
        } else if keep { &["plots.rds"] } else { &["experiment.rds", "plots.rds"] };
        plan.push((job, names.to_vec()));
    }
    Ok(plan)
}

fn compact_history(root: &Path, include_older_versions: bool) -> Result<u64, String> {
    snapshot_cleanup_plan(root, include_older_versions)?.into_iter().try_fold(0, |bytes, (job, names)| {
        remove_snapshots(&job, &names).map(|removed| bytes + removed)
    })
}

#[tauri::command]
pub async fn quant_compact(app: AppHandle, project: String) -> Result<Value, String> {
    tauri::async_runtime::spawn_blocking(move || {
        let state = app.state::<QuantState>(); let _busy = lock(&state)?;
        let root = dataset_root(&project)?;
        let bytes = compact_history(&root, true)?;
        // The UI explicitly confirms permanent deletion of this dataset's
        // app-managed trash. Live results and input datasets are not targets.
        let trash = root.join(".trash");
        match fs::symlink_metadata(&trash) {
            Ok(meta) if meta.file_type().is_dir() => fs::remove_dir_all(&trash).map_err(|e| e.to_string())?,
            Ok(_) => return Err("Refusing to empty a linked trash folder.".into()),
            Err(e) if e.kind() == std::io::ErrorKind::NotFound => {},
            Err(e) => return Err(e.to_string()),
        }
        Ok(json!({"retiredSnapshotBytes":bytes}))
    }).await.map_err(|e| e.to_string())?
}

fn delete_items(project: &str, kind: &str, all: bool, id: &str, name: &str, mode: &str) -> Result<Value, String> {
    if !["plots", "checkpoints"].contains(&kind) || !["guided", "legacy"].contains(&mode) {
        return Err("Invalid QUANT deletion scope.".into());
    }
    let root = dataset_root(project)?;
    if !root.exists() { return Ok(json!({"count": 0})); }
    if !fs::symlink_metadata(&root).map_err(|e| e.to_string())?.file_type().is_dir() {
        return Err("QUANT deletion does not follow linked analysis folders.".into());
    }
    let history = history_at(&root)?;
    let mut targets: Vec<(PathBuf, PathBuf)> = Vec::new();
    for checkpoint in history {
        let checkpoint_id = checkpoint["id"].as_str().ok_or("Invalid checkpoint ID.")?;
        if !all && checkpoint_id != id { continue; }
        if kind == "checkpoints" && (checkpoint["action"] == "legacy") != (mode == "legacy") { continue; }
        let job = job_path(&root, checkpoint_id)?;
        if kind == "checkpoints" {
            targets.push((job, PathBuf::from(checkpoint_id)));
        } else if let Some(artifacts) = checkpoint["artifacts"].as_array() {
            for artifact in artifacts {
                let Some(filename) = artifact["name"].as_str() else { continue; };
                if artifact["kind"] != "image" || (!all && filename != name) { continue; }
                let source = artifact_path(project, checkpoint_id, filename)?;
                if fs::symlink_metadata(job.join(filename)).map_err(|e| e.to_string())?.file_type().is_symlink() {
                    return Err("QUANT deletion does not follow linked plot files.".into());
                }
                if !targets.iter().any(|(p, _)| *p == source) {
                    targets.push((source, PathBuf::from(checkpoint_id).join(filename)));
                }
            }
        }
    }
    if targets.is_empty() {
        return if all { Ok(json!({"count": 0})) } else { Err("The selected item is no longer available.".into()) };
    }
    let trash_root = root.join(".trash");
    match fs::create_dir(&trash_root) {
        Ok(()) => {},
        Err(e) if e.kind() == std::io::ErrorKind::AlreadyExists => {},
        Err(e) => return Err(e.to_string()),
    }
    if !fs::symlink_metadata(&trash_root).map_err(|e| e.to_string())?.file_type().is_dir() {
        return Err("QUANT trash must be a real folder, not a link.".into());
    }
    let trash = trash_root.join(unique_id());
    fs::create_dir(&trash).map_err(|e| e.to_string())?;
    let recovery: Vec<_> = targets.iter().map(|(source, relative)| json!({"original": source, "trashed": trash.join(relative)})).collect();
    write_json(&trash.join("restore-info.json"), &json!({"kind":kind, "items":recovery,
        "instructions":"Close QUANT first. Move each trashed item back to its original path without overwriting existing files. Reopen the dataset to refresh history. Emptying this trash manually is permanent."}))?;
    for (moved, (source, relative)) in targets.iter().enumerate() {
        let destination = trash.join(relative);
        let result = fs::create_dir_all(destination.parent().unwrap()).and_then(|_| fs::rename(source, &destination));
        if let Err(error) = result {
            return Err(format!("Moved {moved} items before an error: {error}. Recovery information: {}", trash.display()));
        }
    }
    Ok(json!({"count":targets.len(), "trash":trash}))
}

#[tauri::command]
pub async fn quant_delete(app: AppHandle, project: String, kind: String, all: bool, id: String, name: String, mode: String) -> Result<Value, String> {
    tauri::async_runtime::spawn_blocking(move || {
        let state = app.state::<QuantState>(); let _busy = lock(&state)?;
        delete_items(&project, &kind, all, &id, &name, &mode)
    }).await.map_err(|e| e.to_string())?
}

#[tauri::command]
pub async fn quant_execute(
    app: AppHandle,
    project: String,
    mut request: Value,
) -> Result<Value, String> {
    tauri::async_runtime::spawn_blocking(move || {
        let state = app.state::<QuantState>(); let _busy = lock(&state)?;
        if !request.is_object() { return Err("Invalid QUANT request.".into()); }
        // Step 3 must not overwrite long.csv while R imports it, even when
        // the user switches tabs. Both workflows acquire the same atomic lock.
        let processing = app.state::<super::RunState>();
        processing.0.compare_exchange(false, true, Ordering::SeqCst, Ordering::SeqCst)
            .map_err(|_| "Wait for the integrator step to finish before using QUANT.".to_string())?;
        let _processing = Busy(&processing.0);
        let (r, version) = runtime(&app)?; let engine = engine(&app)?; let lib = library(&engine, &version);
        if !lib.join("ready").is_file() { return Err("Set up the R engine first.".into()); }
        let action = request["action"].as_str().unwrap_or("").to_string();
        if !["run", "edit", "table", "legacy"].contains(&action.as_str()) { return Err("Invalid QUANT action.".into()); }
        if action == "legacy" {
            let code = request["code"].as_str().ok_or("Paste an R code block first.")?;
            if code.trim().is_empty() || code.len() > 1024 * 1024 {
                return Err("Enter an R code block between 1 byte and 1 MB.".into());
            }
        }
        let root = dataset_root(&project)?;
        request["project"] = json!(root.parent().unwrap());
        let parent = request["checkpoint"].as_str().unwrap_or("").to_owned();
        if !parent.is_empty() {
            let previous = job_path(&root, &parent)?;
            let completed = read_json(&previous.join("completed.json"))?;
            if completed["packageId"] != PACKAGE_ID {
                return Err("This checkpoint used a different QUANT source version. Its saved files remain available; reimport to process with the updated engine.".into());
            }
            if action != "table" && (action == "legacy") != (completed["action"] == "legacy") {
                return Err("Guided and Legacy sessions use separate checkpoints.".into());
            }
            let snapshot = previous.join(snapshot_name(&completed));
            if !snapshot.is_file() {
                return Err("This older run keeps its outputs only. Select the latest saved session to continue.".into());
            }
            request["legacyTable"] = json!(action == "table" && completed["action"] == "legacy");
            request["checkpoint"] = json!(snapshot);
        }
        let id = unique_id();
        let work = if action == "table" { engine.join(&id) } else { root.join(&id) };
        fs::create_dir_all(&work).map_err(|e| e.to_string())?;
        write_json(&work.join("request.json"), &request)?;
        let output = run_r(&app, if action == "legacy" { "legacy" } else { "run" }, &engine, &work, &r, &lib);
        if action == "table" {
            // Only this freshly-created, app-owned query directory is removed.
            let _ = fs::remove_dir_all(&work);
            return output;
        }
        let mut result = match output {
            Ok(result) => result,
            Err(error) => {
                if let Err(cleanup) = remove_snapshots(&work, &["workspace.rds", "experiment.rds", "plots.rds"]) {
                    let _ = app.emit("quant-log", format!("Warning: {cleanup}"));
                }
                return Err(error);
            }
        };
        result["id"] = json!(id); result["parent"] = json!(parent);
        result["operation"] = request["operation"].clone(); result["action"] = json!(action);
        result["created"] = json!(chrono::Utc::now().to_rfc3339());
        result["parameters"] = request["parameters"].clone(); result["packageId"] = json!(PACKAGE_ID);
        result["directory"] = json!(work);
        result["storagePolicy"] = json!("rolling-v1");
        result["artifacts"].as_array_mut().unwrap().push(json!({"name": "request.json", "kind": "file"}));
        result["artifacts"].as_array_mut().unwrap().push(json!({"name": "run.log", "kind": "file"}));
        if let Err(error) = write_json(&work.join("completed.json"), &result) {
            let _ = remove_snapshots(&work, &["workspace.rds", "experiment.rds", "plots.rds"]);
            return Err(error);
        }
        // Commit first: a failed block never discards the last good session.
        if let Err(error) = compact_history(&root, false) {
            let _ = app.emit("quant-log", format!("Warning: result saved, but storage compaction failed: {error}"));
        }
        result["resumable"] = json!(true);
        Ok(result)
    }).await.map_err(|e| e.to_string())?
}

#[tauri::command]
pub fn quant_image(project: String, id: String, name: String) -> Result<String, String> {
    let path = artifact_path(&project, &id, &name)?;
    if path.extension().and_then(|x| x.to_str()) != Some("png") {
        return Err("Not a PNG image.".into());
    }
    if fs::metadata(&path).map_err(|e| e.to_string())?.len() > 32 * 1024 * 1024 {
        return Err("Image too large to preview. Save it to view externally.".into());
    }
    Ok(format!(
        "data:image/png;base64,{}",
        STANDARD.encode(fs::read(path).map_err(|e| e.to_string())?)
    ))
}

#[tauri::command]
pub fn quant_save_artifact(
    project: String,
    id: String,
    name: String,
    destination: String,
) -> Result<(), String> {
    let source = artifact_path(&project, &id, &name)?;
    let dest = Path::new(&destination);
    if dest.exists() && dest.canonicalize().ok().as_ref() == Some(&source) {
        return Ok(());
    }
    // Never allow an export to overwrite a checkpoint / input inside QUANT.
    let root = dataset_root(&project)?
        .canonicalize()
        .map_err(|e| e.to_string())?;
    let parent = dest
        .parent()
        .ok_or("Invalid destination.")?
        .canonicalize()
        .map_err(|e| e.to_string())?;
    if parent.starts_with(root) {
        return Err("Choose a destination outside the QUANT analysis folder.".into());
    }
    fs::copy(source, dest).map_err(|e| e.to_string())?;
    Ok(())
}

#[cfg(test)]
mod tests {
    #[test]
    fn dependency_reuse_is_scoped_to_ready_libraries_for_the_same_r_runtime() {
        let f = Fixture::new(); let engine = f.0.join("new-engine");
        let lib = engine.join("library-current-r");
        for (id, name, ready) in [("new-engine", "library-current-r", true), ("old-engine", "library-current-r", true), ("other-r", "library-other-r", true), ("incomplete", "library-current-r", false)] {
            let path = f.0.join(id).join(name); fs::create_dir_all(&path).unwrap();
            if ready { fs::write(path.join("ready"), "ready").unwrap(); }
        }
        assert_eq!(reusable_libraries(&engine, &lib), vec![f.0.join("old-engine/library-current-r")]);
    }
    #[test]
    fn rolling_storage_keeps_one_snapshot_per_mode_and_all_graphs() {
        let f = Fixture::new(); let root = f.0.join("QUANT");
        for id in ["q-1", "q-2", "q-3"] {
            let job = root.join(id);
            fs::write(job.join("experiment.rds"), "full experiment").unwrap();
            let mut result = read_json(&job.join("completed.json")).unwrap();
            result["storagePolicy"] = json!("rolling-v1");
            write_json(&job.join("completed.json"), &result).unwrap();
        }
        assert!(compact_history(&root, false).unwrap() > 0);
        assert!(!root.join("q-1/workspace.rds").exists());
        assert!(!root.join("q-1/experiment.rds").exists());
        assert!(root.join("q-2/workspace.rds").is_file());
        assert!(!root.join("q-2/experiment.rds").exists());
        assert!(root.join("q-3/experiment.rds").is_file());
        for id in ["q-1", "q-2", "q-3"] { assert!(root.join(id).join("plot.png").is_file()); }
        let history = history_at(&root).unwrap();
        assert_eq!(history.iter().filter(|r| r["resumable"] == true).count(), 2);
        assert_eq!(history.len(), 3);
        assert_eq!(compact_history(&root, false).unwrap(), 0);
    }
    #[test]
    fn pre_rolling_history_requires_explicit_compaction_and_failures_keep_latest() {
        let f = Fixture::new(); let root = f.0.join("QUANT");
        fs::write(root.join("q-3/experiment.rds"), "guided state").unwrap();
        let failed = root.join("q-999"); fs::create_dir(&failed).unwrap();
        fs::write(failed.join("workspace.rds"), "incomplete partial state").unwrap();
        assert_eq!(compact_history(&root, false).unwrap(), 0);
        assert!(root.join("q-1/workspace.rds").is_file());
        assert!(compact_history(&root, true).unwrap() > 0);
        assert!(!root.join("q-1/workspace.rds").exists());
        assert!(root.join("q-2/workspace.rds").is_file());
        assert!(root.join("q-3/experiment.rds").is_file());
        remove_snapshots(&failed, &["workspace.rds", "experiment.rds", "plots.rds"]).unwrap();
        assert!(!failed.join("workspace.rds").exists());
        assert!(root.join("q-2/workspace.rds").is_file());
    }
    #[test]
    fn compacting_a_hardlinked_guided_snapshot_keeps_the_new_copy_readable() {
        let f = Fixture::new(); let root = f.0.join("QUANT");
        let old = root.join("q-3"); let new = root.join("q-4"); fs::create_dir(&new).unwrap();
        fs::write(old.join("experiment.rds"), "unchanged numerical data").unwrap();
        fs::hard_link(old.join("experiment.rds"), new.join("experiment.rds")).unwrap();
        let mut result = read_json(&old.join("completed.json")).unwrap();
        result["id"] = json!("q-4"); write_json(&new.join("completed.json"), &result).unwrap();
        compact_history(&root, true).unwrap();
        assert!(!old.join("experiment.rds").exists());
        assert_eq!(fs::read_to_string(new.join("experiment.rds")).unwrap(),"unchanged numerical data");
    }
    struct Fixture(PathBuf);
    impl Fixture {
        fn new() -> Self {
            let path = std::env::temp_dir().join(format!("quant-delete-test-{}", unique_id()));
            fs::create_dir_all(path.join("QUANT")).unwrap();
            fs::write(path.join("long.csv"), "original input").unwrap();
            for (id, action) in [("q-1", "legacy"), ("q-2", "legacy"), ("q-3", "run")] {
                let job = path.join("QUANT").join(id); fs::create_dir(&job).unwrap();
                fs::write(job.join("plot.png"), id).unwrap();
                fs::write(job.join("workspace.rds"), "saved independent session").unwrap();
                write_json(&job.join("completed.json"), &json!({"id":id,"action":action,
                    "parent":if id == "q-2" {"q-1"} else {""},
                    "artifacts":[{"name":"plot.png","kind":"image"},{"name":"workspace.rds","kind":"file"}]})).unwrap();
            }
            Self(path)
        }
        fn project(&self) -> &str { self.0.to_str().unwrap() }
    }
    impl Drop for Fixture { fn drop(&mut self) { let _ = fs::remove_dir_all(&self.0); } }
    #[test]
    fn plot_deletion_is_recoverable_without_modifying_analysis_manifests() {
        let f = Fixture::new(); let job = f.0.join("QUANT/q-1");
        let manifest = fs::read(job.join("completed.json")).unwrap();
        let result = delete_items(f.project(), "plots", false, "q-1", "plot.png", "legacy").unwrap();
        assert_eq!(result["count"], 1);
        assert!(!job.join("plot.png").exists());
        assert_eq!(fs::read(job.join("completed.json")).unwrap(), manifest);
        let history = history_at(&f.0.join("QUANT")).unwrap();
        assert_eq!(history.iter().find(|h| h["id"] == "q-1").unwrap()["artifacts"].as_array().unwrap().len(), 1);
        let trash = Path::new(result["trash"].as_str().unwrap());
        assert!(trash.join("restore-info.json").is_file());
        fs::rename(trash.join("q-1/plot.png"), job.join("plot.png")).unwrap();
        assert_eq!(history_at(&f.0.join("QUANT")).unwrap().iter().find(|h| h["id"] == "q-1").unwrap()["artifacts"].as_array().unwrap().len(), 2);
        assert_eq!(fs::read_to_string(f.0.join("long.csv")).unwrap(), "original input");
    }
    #[test]
    fn all_plot_deletion_spans_modes_but_keeps_sessions() {
        let f = Fixture::new();
        let result = delete_items(f.project(), "plots", true, "", "", "legacy").unwrap();
        assert_eq!(result["count"], 3);
        for id in ["q-1", "q-2", "q-3"] {
            assert!(f.0.join("QUANT").join(id).join("workspace.rds").is_file());
            assert!(!f.0.join("QUANT").join(id).join("plot.png").exists());
        }
        assert_eq!(delete_items(f.project(), "plots", true, "", "", "guided").unwrap()["count"], 0);
    }
    #[test]
    fn checkpoint_deletion_preserves_other_sessions_and_scopes_all_by_mode() {
        let f = Fixture::new();
        let one = delete_items(f.project(), "checkpoints", false, "q-1", "", "legacy").unwrap();
        assert_eq!(one["count"],1);
        assert!(Path::new(one["trash"].as_str().unwrap()).join("q-1/workspace.rds").is_file());
        assert!(f.0.join("QUANT/q-2/workspace.rds").is_file());
        assert_eq!(delete_items(f.project(), "checkpoints", true, "", "", "legacy").unwrap()["count"],1);
        let history = history_at(&f.0.join("QUANT")).unwrap();
        assert_eq!(history.len(),1); assert_eq!(history[0]["id"],"q-3");
        assert!(f.0.join("long.csv").is_file());
    }
    #[test]
    fn deletion_rejects_invalid_targets_and_non_image_artifacts() {
        let f = Fixture::new();
        for (kind,id,name,mode) in [("plots","q-1","workspace.rds","legacy"),
            ("plots","q-1","../long.csv","legacy"), ("checkpoints","../q-1","","legacy"),
            ("checkpoints","q-1","","guided"), ("files","q-1","","legacy")] {
            assert!(delete_items(f.project(),kind,false,id,name,mode).is_err());
        }
        assert!(!f.0.join("QUANT/.trash").exists());
        assert_eq!(history_at(&f.0.join("QUANT")).unwrap().len(),3);
    }
    #[cfg(unix)]
    #[test]
    fn deletion_rejects_linked_plots_and_trash() {
        use std::os::unix::fs::symlink;
        let f = Fixture::new(); let plot = f.0.join("QUANT/q-1/plot.png");
        fs::remove_file(&plot).unwrap(); symlink(f.0.join("long.csv"),&plot).unwrap();
        assert!(delete_items(f.project(),"plots",false,"q-1","plot.png","legacy").is_err());
        symlink(&f.0,f.0.join("QUANT/.trash")).unwrap();
        assert!(delete_items(f.project(),"checkpoints",false,"q-2","","legacy").is_err());
        assert!(f.0.join("long.csv").is_file());
        assert!(f.0.join("QUANT/q-2").is_dir());
    }
    #[test]
    fn progress_protocol_validates_values_and_leaves_plain_logs_alone() {
        assert!(super::progress_message("Error in run(): bad input").is_none());
        assert!(super::progress_message("__MRMHUB_QUANT_PROGRESS__not json").is_none());
        assert!(super::progress_message(r#"__MRMHUB_QUANT_PROGRESS__{"token":"a","percent":101,"message":"bad"}"#).is_none());
        let progress = super::progress_message(r#"__MRMHUB_QUANT_PROGRESS__{"token":"a","percent":33.3333,"message":"Running statement 1"}"#).unwrap();
        assert_eq!(progress["token"], "a");
        assert_eq!(progress["percent"], 33.3333);
    }
    use super::*;
    #[test]
    fn filenames_cannot_traverse() {
        for value in ["", ".", "..", "../a", "/tmp/a", "a/b", "a\\b", "C:a"] {
            assert!(!valid_component(value), "{value}");
        }
        assert!(valid_component("plot-001.png"));
        assert!(valid_component("q-12345"));
        assert!(valid_artifact_name("My results μmol.csv"));
        for name in ["", ".", "..", "../secret", "a/b", "a\\b", "C:secret"] {
            assert!(!valid_artifact_name(name));
        }
    }
    #[test]
    fn exact_package_is_embedded() {
        assert!(
            PACKAGE_FILES
                .iter()
                .any(|(name, _)| *name == "R/sysdata.rda")
        );
        assert!(PACKAGE_FILES.iter().any(|(name, _)| *name == "DESCRIPTION"));
        assert!(
            PACKAGE_FILES
                .iter()
                .any(|(name, _)| *name == "R/calc-istd-normalization.R")
        );
    }
    #[test]
    fn failed_job_is_not_a_checkpoint() {
        let root = std::env::temp_dir().join(unique_id());
        fs::create_dir_all(root.join("q-123")).unwrap();
        assert!(job_path(&root, "q-123").is_err());
        assert!(job_path(&root, "../q-123").is_err());
        fs::remove_dir_all(root).unwrap();
    }
}
