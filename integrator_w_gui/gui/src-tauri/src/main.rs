#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::fs::{self, OpenOptions};
use std::io::{BufReader, Read, Write};
use std::path::{Component, Path, PathBuf};
use std::process::{Command, Stdio};
use std::sync::atomic::{AtomicBool, Ordering};
use std::time::{SystemTime, UNIX_EPOCH};
use tauri::{AppHandle, Emitter, Manager, State, WindowEvent};

mod visualizer;

// names the backup folder stored directly inside each selected dataset
const BACKUP_DIR: &str = "RT_matrix_backups";

// names the protected snapshot created from the latest Step 2 output
const ORIGINAL_BACKUP: &str = "RT_matrix_original.csv";

// default param.txt template used when a selected dataset does not have one
const DEFAULT_PARAM_TEMPLATE: &str = r#"### location of .mzML files
mzML_files =  'mzML/*.mzML'


### table indicating file name, batch, sample type and reference sample
batch_info = 'run_order_20251009.csv'


### If "peak_width = [w, x, y, z]", the left integration bound will be between w and x minutes left of the estimated apex, while the right integration bound will be between y and z minutes right of the estimated apex. To fix integration bounds between samples, set w=x and y=z.
peak_width =  [0.17, 0.05, 0.1, 0.35]


### Table with transition information: the file '..._Final.csv' contains the final curated dataset, '..._withRTerrors.csv' (commented with #) includes features with incorrect RTs for demonstration purposes.
#transition_list =  'transition_list_20251009_Final.csv'
transition_list =  'transition_list_20251009_withRTerrors.csv'

num_threads = 14


### m/z tolerence, maximum difference between m/z in transition list and m/z values in mzML file
mz_tol = 0.06


### RT tolerence, maximum difference indicated RT and detected RT
RT_tol = 0.1


### if "RT_shift = [x, y]", the estimation will assume that RT shift is no more than x minutes to the left and no more than y minutes to the right with respect to the reference samples. Let x = 0.0 and y = 0.0 if no significant RT shift occurs in the samples.
RT_shift = [-0.2, 0.2]


### this parameter restricts RT shift between adjacent samples
RT_shift_bound = 0.1
"#;

// tracks whether a processing step is already running
struct RunState(AtomicBool);

// stores the user's remembered project, interface theme, and per-project state
#[derive(Default, Deserialize, Serialize)]
struct Settings {
    #[serde(default)]
    last_project: String,
    #[serde(default)]
    theme: Option<String>,
    // maps a project path to the RT_matrix backup it last used
    #[serde(default)]
    last_backups: HashMap<String, String>,
    // maps a project path and backup file name to a user-facing dropdown label
    #[serde(default)]
    backup_labels: HashMap<String, HashMap<String, String>>,
}

// describes which workflow outputs currently exist
#[derive(Clone, Serialize)]
#[serde(rename_all = "camelCase")]
struct ProjectOutputs {
    validated: bool,
    detected: bool,
    integrated: bool,
    plotted: bool,
}

// describes a selected project and its readiness
#[derive(Clone, Serialize)]
#[serde(rename_all = "camelCase")]
struct ProjectSummary {
    name: String,
    path: String,
    sample_count: usize,
    transition_file: Option<String>,
    worker_name: Option<String>,
    issues: Vec<String>,
    outputs: ProjectOutputs,
    can_run: bool,
}

// describes one required input that the GUI can create without overwriting
#[derive(Clone, Deserialize, Serialize)]
#[serde(rename_all = "camelCase")]
struct MissingInput {
    kind: String,
    name: String,
}

// describes the missing-input confirmation shown after selecting a dataset
#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct MissingInputPlan {
    files: Vec<MissingInput>,
    param_needs_configuration: bool,
}

// returns the refreshed project together with the files that were created
#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct CreatedInputs {
    project: ProjectSummary,
    created: Vec<String>,
}

// describes the remembered project at application startup
#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct StartupState {
    project: Option<ProjectSummary>,
    remembered_path: Option<String>,
    needs_reselection: bool,
    theme: Option<String>,
}

// carries one line of worker output to the frontend
#[derive(Clone, Serialize)]
#[serde(rename_all = "camelCase")]
struct WorkerOutput {
    step: u8,
    stream: String,
    line: String,
}

// carries the current workflow state to the frontend
#[derive(Clone, Serialize)]
#[serde(rename_all = "camelCase")]
struct StepState {
    step: u8,
    status: String,
}

// stores saved scratchpad note metadata without loading note bodies
#[derive(Clone, Deserialize, Serialize)]
#[serde(rename_all = "camelCase")]
struct ScratchpadNoteSummary {
    id: String,
    title: String,
    created_at: u64,
    updated_at: u64,
    pinned: bool,
    include_timestamp: bool,
}

// stores one loaded scratchpad note and its text content
#[derive(Clone, Deserialize, Serialize)]
#[serde(rename_all = "camelCase")]
struct ScratchpadNote {
    #[serde(flatten)]
    summary: ScratchpadNoteSummary,
    content: String,
}

// payload for saving editable scratchpad note fields
#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct ScratchpadSaveInput {
    id: String,
    title: String,
    content: String,
    pinned: bool,
    include_timestamp: bool,
}

// describes one project input file that can be edited in the GUI
#[derive(Clone, Serialize)]
#[serde(rename_all = "camelCase")]
struct DataEditorFile {
    kind: String,
    title: String,
    name: String,
    format: String,
}

// returns text or table data for one editable project input file
#[derive(Clone, Serialize)]
#[serde(rename_all = "camelCase")]
struct DataEditorContent {
    file: DataEditorFile,
    text: Option<String>,
    headers: Vec<String>,
    rows: Vec<Vec<String>>,
    backups: Vec<String>,
}

// editable content coming from the data editor
#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct DataEditorSaveInput {
    kind: String,
    text: Option<String>,
    headers: Vec<String>,
    rows: Vec<Vec<String>>,
}

// returns the settings file inside the platform application directory
fn settings_path(app: &AppHandle) -> Result<PathBuf, String> {
    app.path()
        .app_config_dir()
        .map(|directory| directory.join("settings.json"))
        .map_err(|error| error.to_string())
}

// returns unix milliseconds for compact stable note timestamps
fn now_millis() -> Result<u64, String> {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|duration| duration.as_millis() as u64)
        .map_err(|error| error.to_string())
}

// returns the directory that stores scratchpad note metadata and content
fn scratchpad_dir(app: &AppHandle) -> Result<PathBuf, String> {
    app.path()
        .app_config_dir()
        .map(|directory| directory.join("scratchpad_notes"))
        .map_err(|error| error.to_string())
}

// validates a scratchpad id before using it in a file path
fn safe_note_id(id: &str) -> Result<&str, String> {
    if id.is_empty()
        || id.len() > 80
        || !id.chars().all(|character| {
            character.is_ascii_alphanumeric() || character == '_' || character == '-'
        })
    {
        return Err("the note id is invalid".to_string());
    }
    Ok(id)
}

// returns metadata and content paths for one saved scratchpad note
fn scratchpad_paths(app: &AppHandle, id: &str) -> Result<(PathBuf, PathBuf), String> {
    let id = safe_note_id(id)?;
    let directory = scratchpad_dir(app)?;
    Ok((
        directory.join(format!("{id}.json")),
        directory.join(format!("{id}.txt")),
    ))
}

// normalizes saved note titles
fn safe_note_title(title: &str) -> String {
    let title = title.trim();
    if title.is_empty() {
        "Untitled note".to_string()
    } else {
        title.chars().take(120).collect()
    }
}

// writes note metadata and text content to separate files
fn write_scratchpad_note(app: &AppHandle, note: &ScratchpadNote) -> Result<(), String> {
    let (metadata_path, content_path) = scratchpad_paths(app, &note.summary.id)?;
    if let Some(parent) = metadata_path.parent() {
        fs::create_dir_all(parent).map_err(|error| error.to_string())?;
    }
    let metadata = serde_json::to_vec_pretty(&note.summary).map_err(|error| error.to_string())?;
    fs::write(metadata_path, metadata).map_err(|error| error.to_string())?;
    fs::write(content_path, &note.content).map_err(|error| error.to_string())
}

// reads only note metadata for the saved-notes list
fn read_scratchpad_summary(path: &Path) -> Option<ScratchpadNoteSummary> {
    let contents = fs::read(path).ok()?;
    serde_json::from_slice(&contents).ok()
}

// converts unix milliseconds into a sortable decimal string backup name
fn timestamp_token() -> Result<String, String> {
    Ok(now_millis()?.to_string())
}

// reads the saved application settings
fn read_settings(app: &AppHandle) -> Option<Settings> {
    let contents = fs::read(settings_path(app).ok()?).ok()?;
    serde_json::from_slice(&contents).ok()
}

// writes the application settings
fn write_settings(app: &AppHandle, settings: &Settings) -> Result<(), String> {
    let settings_path = settings_path(app)?;
    if let Some(parent) = settings_path.parent() {
        fs::create_dir_all(parent).map_err(|error| error.to_string())?;
    }
    let json = serde_json::to_vec_pretty(settings).map_err(|error| error.to_string())?;
    fs::write(settings_path, json).map_err(|error| error.to_string())
}

// appends one close timestamp to the selected dataset's exit log
fn append_exit_log_entry(project: &Path, entry: &str) -> Result<(), String> {
    if !project.is_dir() {
        return Ok(());
    }
    let log_path = project.join("exit_log.txt");
    let separator = fs::read(&log_path).map_or("", |contents| {
        if contents.is_empty() || contents.ends_with(b"\n\n") {
            ""
        } else if contents.ends_with(b"\n") {
            "\n"
        } else {
            "\n\n"
        }
    });
    let mut file = OpenOptions::new()
        .create(true)
        .append(true)
        .open(log_path)
        .map_err(|error| error.to_string())?;
    if !separator.is_empty() {
        file.write_all(separator.as_bytes())
            .map_err(|error| error.to_string())?;
    }
    file.write_all(entry.as_bytes())
        .map_err(|error| error.to_string())?;
    file.write_all(b"\n").map_err(|error| error.to_string())
}

// records that the gui window closed in the remembered dataset folder
fn append_exit_log(project: &Path) -> Result<(), String> {
    let timestamp = chrono::Local::now().format("%d/%m/%Y , %Hh:%Mm:%Ss");
    append_exit_log_entry(project, &format!("exit // mrmhub-gui closed @ {timestamp}"))
}

// writes a close entry for the current dataset, if one is remembered
fn log_exit_for_current_project(app: &AppHandle) {
    if let Some(settings) = read_settings(app) {
        if !settings.last_project.trim().is_empty() {
            let _ = append_exit_log(&PathBuf::from(settings.last_project));
        }
    }
}

// saves the selected project for the next launch
fn save_project(app: &AppHandle, project: &Path) -> Result<(), String> {
    let mut settings = read_settings(app).unwrap_or_default();
    settings.last_project = project.to_string_lossy().into_owned();
    write_settings(app, &settings)
}

// resolves a parameter path relative to its project directory
fn project_file(project: &Path, value: &str) -> PathBuf {
    let path = PathBuf::from(value);
    if path.is_absolute() {
        path
    } else {
        project.join(path)
    }
}

// rejects path separators and traversal in a backup file name
fn safe_backup_name(name: &str) -> Result<&str, String> {
    if name.is_empty() || name.contains('/') || name.contains('\\') || name.contains("..") {
        return Err("the backup name is invalid".to_string());
    }
    Ok(name)
}

fn backup_directory(project: &Path) -> PathBuf {
    project.join(BACKUP_DIR)
}

// Resolves the short-lived v1.2.0/v1.2.1 nested layout so those backups can be
// flattened back into the dataset's own RT_matrix_backups directory once.
fn previous_nested_backup_directory(project: &Path) -> PathBuf {
    let name = project
        .file_name()
        .and_then(|name| name.to_str())
        .unwrap_or("dataset");
    let mut safe: String = name
        .chars()
        .map(|character| {
            if character.is_control()
                || matches!(
                    character,
                    '<' | '>' | ':' | '"' | '/' | '\\' | '|' | '?' | '*'
                )
            {
                '_'
            } else {
                character
            }
        })
        .collect();
    while safe.ends_with(' ') || safe.ends_with('.') {
        safe.pop();
    }
    let folder = if safe.is_empty() || safe == "." || safe == ".." {
        "dataset".to_string()
    } else {
        safe
    };
    backup_directory(project).join(folder)
}

fn files_match(left: &Path, right: &Path) -> Result<bool, String> {
    if fs::metadata(left).map_err(|error| error.to_string())?.len()
        != fs::metadata(right)
            .map_err(|error| error.to_string())?
            .len()
    {
        return Ok(false);
    }
    let mut left = BufReader::new(fs::File::open(left).map_err(|error| error.to_string())?);
    let mut right = BufReader::new(fs::File::open(right).map_err(|error| error.to_string())?);
    let mut left_buffer = [0_u8; 16 * 1024];
    let mut right_buffer = [0_u8; 16 * 1024];
    loop {
        let left_count = left
            .read(&mut left_buffer)
            .map_err(|error| error.to_string())?;
        let right_count = right
            .read(&mut right_buffer)
            .map_err(|error| error.to_string())?;
        if left_count != right_count || left_buffer[..left_count] != right_buffer[..right_count] {
            return Ok(false);
        }
        if left_count == 0 {
            return Ok(true);
        }
    }
}

fn unique_flattened_target(directory: &Path, source: &Path) -> Result<PathBuf, String> {
    let name = source
        .file_name()
        .and_then(|name| name.to_str())
        .ok_or_else(|| "a nested backup has an invalid file name".to_string())?;
    let direct = directory.join(name);
    if !direct.exists() || files_match(source, &direct)? {
        return Ok(direct);
    }
    let stem = source
        .file_stem()
        .and_then(|stem| stem.to_str())
        .unwrap_or("RT_matrix");
    for index in 1..=10_000 {
        let candidate = directory.join(format!("{stem}_nested_{index}.csv"));
        if !candidate.exists() || files_match(source, &candidate)? {
            return Ok(candidate);
        }
    }
    Err("could not create a unique name for a nested RT_matrix backup".to_string())
}

// Safely moves any backups made by the briefly nested layout back to the
// dataset-level backup folder. Same-named files with different content are
// retained under a collision-safe name; exact duplicates are removed.
fn flatten_previous_nested_backups(project: &Path) -> Result<usize, String> {
    let directory = backup_directory(project);
    let nested = previous_nested_backup_directory(project);
    fs::create_dir_all(&directory).map_err(|error| error.to_string())?;
    if !nested.is_dir() {
        return Ok(0);
    }
    let mut sources: Vec<PathBuf> = fs::read_dir(&nested)
        .map_err(|error| error.to_string())?
        .filter_map(Result::ok)
        .map(|entry| entry.path())
        .filter(|path| {
            path.is_file()
                && path
                    .extension()
                    .and_then(|extension| extension.to_str())
                    .is_some_and(|extension| extension.eq_ignore_ascii_case("csv"))
        })
        .collect();
    sources.sort_unstable();
    let mut moved = 0;
    for source in sources {
        let target = unique_flattened_target(&directory, &source)?;
        if target.exists() {
            fs::remove_file(source).map_err(|error| error.to_string())?;
        } else {
            fs::rename(source, target).map_err(|error| error.to_string())?;
            moved += 1;
        }
    }
    let _ = fs::remove_dir(nested);
    Ok(moved)
}

// validates a generated fallback file name supplied by the local GUI
fn safe_suggested_csv_name<'a>(name: &'a str, prefix: &str) -> Result<&'a str, String> {
    let lower = name.to_ascii_lowercase();
    if !name.starts_with(prefix)
        || !lower.ends_with(".csv")
        || name.contains('/')
        || name.contains('\\')
        || name.contains("..")
    {
        return Err(format!("the suggested {prefix} file name is invalid"));
    }
    Ok(name)
}

// restricts generated inputs to relative paths inside the selected dataset
fn safe_project_output(project: &Path, value: &str) -> Result<PathBuf, String> {
    let relative = Path::new(value);
    if value.is_empty()
        || relative.is_absolute()
        || !relative
            .components()
            .all(|component| matches!(component, Component::Normal(_)))
    {
        return Err(format!("{value} is not a safe dataset-relative path"));
    }
    Ok(project.join(relative))
}

// reads valid parameters when possible without requiring param.txt to exist
fn project_parameters(project: &Path) -> Option<toml::Table> {
    fs::read_to_string(project.join("param.txt"))
        .ok()?
        .parse::<toml::Table>()
        .ok()
}

// finds an existing root-level CSV matching an input family
fn existing_input_csv(project: &Path, prefix: &str) -> Option<PathBuf> {
    let mut candidates: Vec<PathBuf> = fs::read_dir(project)
        .ok()?
        .filter_map(Result::ok)
        .map(|entry| entry.path())
        .filter(|path| {
            path.is_file()
                && path
                    .file_name()
                    .and_then(|name| name.to_str())
                    .is_some_and(|name| {
                        name.starts_with(prefix) && name.to_ascii_lowercase().ends_with(".csv")
                    })
        })
        .collect();
    candidates.sort_unstable();
    candidates.into_iter().next()
}

// resolves the requested table names, preferring values already in param.txt
fn requested_input_paths(
    project: &Path,
    run_order_name: &str,
    transition_name: &str,
) -> Result<(PathBuf, PathBuf), String> {
    let run_order_name = safe_suggested_csv_name(run_order_name, "run_order_")?;
    let transition_name = safe_suggested_csv_name(transition_name, "transition_list")?;
    let parameters = project_parameters(project);
    let configured_run_order = parameters
        .as_ref()
        .and_then(|table| table.get("batch_info").and_then(toml::Value::as_str))
        .map(str::to_string);
    let configured_transition = parameters
        .as_ref()
        .and_then(|table| table.get("transition_list").and_then(toml::Value::as_str))
        .map(str::to_string);
    let run_order = if let Some(value) = configured_run_order {
        safe_project_output(project, &value)?
    } else {
        existing_input_csv(project, "run_order")
            .unwrap_or(safe_project_output(project, run_order_name)?)
    };
    let transition = if let Some(value) = configured_transition {
        safe_project_output(project, &value)?
    } else {
        existing_input_csv(project, "transition_list")
            .unwrap_or(safe_project_output(project, transition_name)?)
    };
    Ok((run_order, transition))
}

// resolves the project input files currently used by the dataset
fn data_editor_paths(project: &Path) -> Result<Vec<(String, String, PathBuf, String)>, String> {
    let (run_order, transition) = requested_input_paths(
        project,
        "run_order_editor_placeholder.csv",
        "transition_list.csv",
    )?;
    Ok(vec![
        (
            "param".to_string(),
            "param.txt".to_string(),
            project.join("param.txt"),
            "text".to_string(),
        ),
        (
            "runOrder".to_string(),
            "Run order".to_string(),
            run_order,
            "csv".to_string(),
        ),
        (
            "transition".to_string(),
            "Transition list".to_string(),
            transition,
            "csv".to_string(),
        ),
    ])
}

// resolves a single editable data file by kind
fn data_editor_file(project: &Path, kind: &str) -> Result<DataEditorFile, String> {
    data_editor_files_for_project(project)?
        .into_iter()
        .find(|file| file.kind == kind)
        .ok_or_else(|| "that editable data file is not available".to_string())
}

// returns editor file metadata for a project
fn data_editor_files_for_project(project: &Path) -> Result<Vec<DataEditorFile>, String> {
    Ok(data_editor_paths(project)?
        .into_iter()
        .map(|(kind, title, path, format)| DataEditorFile {
            kind,
            title,
            name: relative_name(project, &path),
            format,
        })
        .collect::<Vec<_>>())
}

// resolves the absolute path for a single editable data file
fn data_editor_path(project: &Path, kind: &str) -> Result<PathBuf, String> {
    data_editor_paths(project)?
        .into_iter()
        .find(|(candidate, _, _, _)| candidate == kind)
        .map(|(_, _, path, _)| path)
        .ok_or_else(|| "that editable data file is not available".to_string())
}

// returns the backup directory for one editable project input file
fn data_editor_backup_dir(project: &Path, kind: &str) -> Result<PathBuf, String> {
    data_editor_file(project, kind)?;
    Ok(project.join("data_file_backups").join(kind))
}

// returns the protected original snapshot name for one editor file
fn data_editor_original_backup_name(project: &Path, kind: &str) -> Result<String, String> {
    let path = data_editor_path(project, kind)?;
    let extension = path
        .extension()
        .and_then(|extension| extension.to_str())
        .unwrap_or("txt");
    Ok(format!("original.{extension}"))
}

// creates the protected original snapshot once, without overwriting it later
fn ensure_data_editor_original_backup(
    project: &Path,
    kind: &str,
) -> Result<Option<String>, String> {
    let path = data_editor_path(project, kind)?;
    if !path.is_file() {
        return Ok(None);
    }
    let name = data_editor_original_backup_name(project, kind)?;
    let directory = data_editor_backup_dir(project, kind)?;
    fs::create_dir_all(&directory).map_err(|error| error.to_string())?;
    let target = directory.join(&name);
    if !target.exists() {
        fs::copy(path, target).map_err(|error| error.to_string())?;
    }
    Ok(Some(name))
}

// checks whether a backup is the protected original snapshot
fn is_data_editor_original_backup(project: &Path, kind: &str, name: &str) -> Result<bool, String> {
    Ok(name == data_editor_original_backup_name(project, kind)?)
}

// lists saved backups for one editable input file, oldest-to-newest
fn list_data_editor_backups(project: &Path, kind: &str) -> Result<Vec<String>, String> {
    let original = ensure_data_editor_original_backup(project, kind)?;
    let directory = data_editor_backup_dir(project, kind)?;
    if !directory.is_dir() {
        return Ok(Vec::new());
    }
    let mut backups: Vec<String> = fs::read_dir(directory)
        .map_err(|error| error.to_string())?
        .filter_map(Result::ok)
        .filter_map(|entry| entry.file_name().to_str().map(str::to_string))
        .collect();
    backups.sort_unstable();
    if let Some(original) = original {
        if let Some(index) = backups.iter().position(|name| name == &original) {
            let original = backups.remove(index);
            backups.insert(0, original);
        }
    }
    Ok(backups)
}

// reads one editable project file or one of its saved backups into editor data
fn read_data_editor_content_from_path(
    project: &Path,
    kind: &str,
    path: &Path,
) -> Result<DataEditorContent, String> {
    let file = data_editor_file(project, kind)?;
    let backups = list_data_editor_backups(project, kind)?;
    if file.format == "text" {
        let text = fs::read_to_string(path).unwrap_or_default();
        Ok(DataEditorContent {
            file,
            text: Some(text),
            headers: Vec::new(),
            rows: Vec::new(),
            backups,
        })
    } else {
        let (headers, rows) = read_csv_table(path)?;
        Ok(DataEditorContent {
            file,
            text: None,
            headers,
            rows,
            backups,
        })
    }
}

// validates a user-supplied editor backup rename and keeps the old extension
fn safe_data_editor_backup_name(name: &str, old_name: &str) -> Result<String, String> {
    let mut name = name.trim().to_string();
    if name.is_empty()
        || name.len() > 120
        || name.contains('/')
        || name.contains('\\')
        || name.contains("..")
        || name.chars().any(|character| {
            character.is_control() || matches!(character, '<' | '>' | ':' | '"' | '|' | '?' | '*')
        })
    {
        return Err("the backup name is invalid".to_string());
    }

    let old_extension = Path::new(old_name)
        .extension()
        .and_then(|extension| extension.to_str())
        .unwrap_or("");
    let has_extension = Path::new(&name).extension().is_some();
    if !old_extension.is_empty() && !has_extension {
        name.push('.');
        name.push_str(old_extension);
    }
    safe_backup_name(&name)?;
    Ok(name)
}

// backs up the current editable file before replacing it
fn backup_data_editor_file(
    project: &Path,
    kind: &str,
    path: &Path,
) -> Result<Option<String>, String> {
    if !path.is_file() {
        return Ok(None);
    }
    let directory = data_editor_backup_dir(project, kind)?;
    fs::create_dir_all(&directory).map_err(|error| error.to_string())?;
    let extension = path
        .extension()
        .and_then(|ext| ext.to_str())
        .unwrap_or("txt");
    let name = format!("{}_{}.{}", kind, timestamp_token()?, extension);
    fs::copy(path, directory.join(&name)).map_err(|error| error.to_string())?;
    Ok(Some(name))
}

// reads a CSV file into headers and editable rows
fn read_csv_table(path: &Path) -> Result<(Vec<String>, Vec<Vec<String>>), String> {
    if !path.is_file() {
        return Ok((Vec::new(), Vec::new()));
    }
    let mut reader = csv::ReaderBuilder::new()
        .flexible(true)
        .from_path(path)
        .map_err(|error| error.to_string())?;
    let headers = reader
        .headers()
        .map_err(|error| error.to_string())?
        .iter()
        .map(str::to_string)
        .collect::<Vec<_>>();
    let rows = reader
        .records()
        .map(|record| {
            record
                .map(|record| record.iter().map(str::to_string).collect::<Vec<_>>())
                .map_err(|error| error.to_string())
        })
        .collect::<Result<Vec<_>, _>>()?;
    Ok((headers, rows))
}

// writes headers and rows into a CSV file
fn write_csv_table(path: &Path, headers: &[String], rows: &[Vec<String>]) -> Result<(), String> {
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent).map_err(|error| error.to_string())?;
    }
    let mut writer = csv::Writer::from_path(path).map_err(|error| error.to_string())?;
    writer
        .write_record(headers)
        .map_err(|error| error.to_string())?;
    for row in rows {
        writer
            .write_record(row)
            .map_err(|error| error.to_string())?;
    }
    writer.flush().map_err(|error| error.to_string())
}

// returns a project-relative display name for a generated input
fn relative_name(project: &Path, path: &Path) -> String {
    path.strip_prefix(project)
        .unwrap_or(path)
        .to_string_lossy()
        .into_owned()
}

// finds an existing sibling table to use only as a structural template
fn csv_template(project: &Path, prefix: &str, target: &Path) -> Option<PathBuf> {
    let mut candidates: Vec<PathBuf> = fs::read_dir(project)
        .ok()?
        .filter_map(Result::ok)
        .map(|entry| entry.path())
        .filter(|path| {
            path != target
                && path.is_file()
                && path
                    .file_name()
                    .and_then(|name| name.to_str())
                    .is_some_and(|name| {
                        name.starts_with(prefix) && name.to_ascii_lowercase().ends_with(".csv")
                    })
        })
        .collect();
    candidates.sort_unstable();
    candidates.into_iter().next()
}

// escapes a dataset-relative path for a TOML basic string
fn toml_string(value: &str) -> String {
    let escaped = value.replace('\\', "\\\\").replace('"', "\\\"");
    format!("\"{escaped}\"")
}

// reports whether a simple top-level key exists in a param template
fn has_toml_key(contents: &str, key: &str) -> bool {
    contents.lines().any(|line| {
        let trimmed = line.trim_start();
        trimmed
            .strip_prefix(key)
            .is_some_and(|rest| rest.trim_start().starts_with('='))
    })
}

// replaces one top-level param key while leaving the rest of the template
// untouched, appending the key when the template did not contain it
fn set_toml_string(contents: &mut String, key: &str, value: &str) {
    let replacement = toml_string(value);
    let mut found = false;
    let mut lines = Vec::new();
    for line in contents.lines() {
        let trimmed = line.trim_start();
        if trimmed
            .strip_prefix(key)
            .is_some_and(|rest| rest.trim_start().starts_with('='))
        {
            let leading = &line[..line.len() - trimmed.len()];
            lines.push(format!("{leading}{key} = {replacement}"));
            found = true;
        } else {
            lines.push(line.to_string());
        }
    }
    *contents = lines.join("\n");
    if !found {
        if !contents.is_empty() && !contents.ends_with('\n') {
            contents.push('\n');
        }
        contents.push_str(&format!("{key} = {replacement}\n"));
    } else if !contents.ends_with('\n') {
        contents.push('\n');
    }
}

// creates param.txt from the built-in template and points it at the detected or
// newly-created transition list and run-order files
fn create_param(
    project: &Path,
    target: &Path,
    run_order: &Path,
    transition: &Path,
) -> Result<(), String> {
    let mut contents = DEFAULT_PARAM_TEMPLATE.to_string();
    if !has_toml_key(&contents, "mzML_files") {
        if !contents.is_empty() && !contents.ends_with('\n') {
            contents.push('\n');
        }
        contents.push_str("mzML_files = \"mzML/*.mzML\"\n");
    }
    let run_order = relative_name(project, run_order).replace('\\', "/");
    let transition = relative_name(project, transition).replace('\\', "/");
    set_toml_string(&mut contents, "batch_info", &run_order);
    set_toml_string(&mut contents, "transition_list", &transition);

    let mut output = create_new_file(target)?;
    output
        .write_all(contents.as_bytes())
        .map_err(|error| error.to_string())
}

// creates parent folders and opens a new file without ever replacing one
fn create_new_file(path: &Path) -> Result<fs::File, String> {
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent).map_err(|error| error.to_string())?;
    }
    OpenOptions::new()
        .write(true)
        .create_new(true)
        .open(path)
        .map_err(|error| error.to_string())
}

// creates a blank run-order table with the same sample-name rows as a sibling
// template, or with one row for every mzML file when no template exists
fn create_run_order(project: &Path, target: &Path) -> Result<(), String> {
    let output = create_new_file(target)?;
    let mut writer = csv::Writer::from_writer(output);
    if let Some(template) = csv_template(project, "run_order", target) {
        let mut reader = csv::ReaderBuilder::new()
            .flexible(true)
            .from_path(template)
            .map_err(|error| error.to_string())?;
        let headers = reader.headers().map_err(|error| error.to_string())?.clone();
        let name_column = headers
            .iter()
            .position(|header| header.trim().eq_ignore_ascii_case("file name"))
            .unwrap_or(0);
        writer
            .write_record(&headers)
            .map_err(|error| error.to_string())?;
        for record in reader.records() {
            let record = record.map_err(|error| error.to_string())?;
            let mut blank = vec![String::new(); headers.len()];
            if name_column < blank.len() {
                blank[name_column] = record.get(name_column).unwrap_or_default().to_string();
            }
            writer
                .write_record(blank)
                .map_err(|error| error.to_string())?;
        }
    } else {
        writer
            .write_record([
                "file name",
                "batch",
                "sample_type",
                "reference (indicate at least one sample to be used for RT shift estimation)",
            ])
            .map_err(|error| error.to_string())?;
        let parameters = project_parameters(project);
        let mzml_pattern = parameters
            .as_ref()
            .and_then(|table| table.get("mzML_files").and_then(toml::Value::as_str))
            .unwrap_or("mzML/*.mzML");
        let mut files: Vec<String> =
            glob::glob(&project_file(project, mzml_pattern).to_string_lossy())
                .into_iter()
                .flatten()
                .filter_map(Result::ok)
                .filter_map(|path| {
                    path.file_name()
                        .and_then(|name| name.to_str())
                        .map(str::to_string)
                })
                .collect();
        files.sort_unstable();
        for file in files {
            writer
                .write_record([file.as_str(), "", "", ""])
                .map_err(|error| error.to_string())?;
        }
    }
    writer.flush().map_err(|error| error.to_string())
}

// creates a blank transition table while preserving its headers and the
// compound, transition, and internal-standard labels from a sibling template
fn create_transition_list(project: &Path, target: &Path) -> Result<(), String> {
    let output = create_new_file(target)?;
    let mut writer = csv::Writer::from_writer(output);
    if let Some(template) = csv_template(project, "transition_list", target) {
        let mut reader = csv::ReaderBuilder::new()
            .flexible(true)
            .from_path(template)
            .map_err(|error| error.to_string())?;
        let headers = reader.headers().map_err(|error| error.to_string())?.clone();
        let label_columns: Vec<usize> = headers
            .iter()
            .enumerate()
            .filter_map(|(index, header)| {
                let header = header.trim().to_ascii_lowercase();
                matches!(
                    header.as_str(),
                    "compound name" | "transition name" | "istd"
                )
                .then_some(index)
            })
            .collect();
        writer
            .write_record(&headers)
            .map_err(|error| error.to_string())?;
        for record in reader.records() {
            let record = record.map_err(|error| error.to_string())?;
            let mut blank = vec![String::new(); headers.len()];
            for &column in &label_columns {
                blank[column] = record.get(column).unwrap_or_default().to_string();
            }
            writer
                .write_record(blank)
                .map_err(|error| error.to_string())?;
        }
    } else {
        writer
            .write_record([
                "Compound Name",
                "Transition Name",
                "ISTD",
                "Precursor Ion",
                "Product Ion",
                "RT",
                "uniform_width (y/n)",
                "left integration bound (integration will not start earlier than the set RT)",
                "right integration bound (integration must end before the set RT)",
                "fixed(y/n)",
                "Remarks",
            ])
            .map_err(|error| error.to_string())?;
    }
    writer.flush().map_err(|error| error.to_string())
}

// replaces the protected original with the current Step 2 RT matrix
fn capture_original(project: &Path) -> Result<(), String> {
    let source = project.join("RT_matrix.csv");
    if !source.is_file() {
        return Ok(());
    }
    let directory = backup_directory(project);
    fs::create_dir_all(&directory).map_err(|error| error.to_string())?;
    fs::copy(source, directory.join(ORIGINAL_BACKUP))
        .map(|_| ())
        .map_err(|error| error.to_string())
}

// captures an existing RT matrix once without replacing an earlier original
fn ensure_original(project: &Path) -> Result<(), String> {
    if !backup_directory(project).join(ORIGINAL_BACKUP).is_file() {
        capture_original(project)?;
    }
    Ok(())
}

// creates only internal application state; user-facing input templates require
// confirmation and are created by create_missing_project_files
fn scaffold_project(project: &Path) {
    let _ = fs::create_dir_all(backup_directory(project));
    let _ = flatten_previous_nested_backups(project);
}

// resolves a worker binary name with this platform's executable extension
fn worker_name(base: &str) -> String {
    if cfg!(windows) {
        format!("{base}.exe")
    } else {
        base.to_string()
    }
}

// locates the processing worker used by the graphical interface. Only names
// that can actually execute on this OS are listed, so a dataset that also
// carries the other platform's build is never launched (executing a Windows
// .exe on macOS fails with exit code 126).
fn find_worker(project: &Path) -> Option<PathBuf> {
    let mut candidates = Vec::new();
    // the worker bundled beside the GUI executable (Tauri sidecar); preferred so
    // the release-optimized worker built for this platform is used
    if let Ok(executable) = std::env::current_exe()
        && let Some(directory) = executable.parent()
    {
        candidates.push(directory.join(worker_name("MRMhub-integrator-worker")));
        candidates.push(directory.join(worker_name("MRMhub-integrator")));
    }
    // a worker placed directly in the dataset folder
    candidates.push(project.join(worker_name("MRMhub-integrator-optimized")));
    candidates.push(project.join(worker_name("MRMhub-integrator")));
    // the legacy standalone build, but only the one for this platform
    candidates.push(project.join(if cfg!(windows) {
        "MRMhub_windows.exe"
    } else {
        "MRMhub_macOS"
    }));
    candidates.into_iter().find(|path| path.is_file())
}

// inspects a project without changing any of its files
fn inspect_project(project: &Path) -> ProjectSummary {
    let mut issues = Vec::new();
    let mut sample_count = 0;
    let mut transition_file = None;
    let param_path = project.join("param.txt");

    if !param_path.is_file() {
        issues.push("param.txt was not found".to_string());
    } else {
        match fs::read_to_string(&param_path)
            .map_err(|error| error.to_string())
            .and_then(|contents| {
                contents
                    .parse::<toml::Table>()
                    .map_err(|error| error.to_string())
            }) {
            Ok(parameters) => {
                if let Some(pattern) = parameters.get("mzML_files").and_then(toml::Value::as_str) {
                    let pattern = project_file(project, pattern);
                    match glob::glob(&pattern.to_string_lossy()) {
                        Ok(files) => sample_count = files.filter_map(Result::ok).count(),
                        Err(error) => issues.push(format!("the mzml pattern is invalid: {error}")),
                    }
                    if sample_count == 0 {
                        issues.push("no mzml files match param.txt".to_string());
                    }
                } else {
                    issues.push("mzML_files is missing from param.txt".to_string());
                }

                if let Some(value) = parameters
                    .get("transition_list")
                    .and_then(toml::Value::as_str)
                {
                    let path = project_file(project, value);
                    transition_file = path
                        .file_name()
                        .map(|name| name.to_string_lossy().into_owned());
                    if !path.is_file() {
                        issues.push("the transition list was not found".to_string());
                    }
                } else {
                    issues.push("transition_list is missing from param.txt".to_string());
                }

                if let Some(value) = parameters.get("batch_info").and_then(toml::Value::as_str) {
                    if !project_file(project, value).is_file() {
                        issues.push("the sample list was not found".to_string());
                    }
                } else {
                    issues.push("batch_info is missing from param.txt".to_string());
                }
            }
            Err(error) => issues.push(format!("param.txt could not be read: {error}")),
        }
    }

    let worker = find_worker(project);
    if worker.is_none() {
        issues.push("the integrator processing engine was not found".to_string());
    }
    let outputs = ProjectOutputs {
        validated: project.join("misc").join("trans_list.bin").is_file(),
        detected: project.join("RT_matrix.csv").is_file(),
        integrated: project.join("long.csv").is_file() && project.join("quant_raw.csv").is_file(),
        plotted: project.join("by_transition").is_dir() || project.join("by_sample").is_dir(),
    };
    let can_run = issues.is_empty();

    ProjectSummary {
        name: project.file_name().map_or_else(
            || "project".to_string(),
            |name| name.to_string_lossy().into_owned(),
        ),
        path: project.to_string_lossy().into_owned(),
        sample_count,
        transition_file,
        worker_name: worker.and_then(|path| {
            path.file_name()
                .map(|name| name.to_string_lossy().into_owned())
        }),
        issues,
        outputs,
        can_run,
    }
}

// loads and validates the remembered project
#[tauri::command]
fn load_startup_state(app: AppHandle) -> StartupState {
    let settings = read_settings(&app);
    let remembered = settings.as_ref().and_then(|settings| {
        (!settings.last_project.is_empty()).then(|| PathBuf::from(&settings.last_project))
    });
    let project = remembered
        .as_deref()
        .filter(|path| path.is_dir())
        .map(|path| {
            scaffold_project(path);
            inspect_project(path)
        });
    StartupState {
        remembered_path: remembered
            .as_ref()
            .map(|path| path.to_string_lossy().into_owned()),
        needs_reselection: remembered.is_some() && project.is_none(),
        project,
        theme: settings.and_then(|settings| settings.theme),
    }
}

// selects validates and remembers a project directory
#[tauri::command]
fn select_project(app: AppHandle, path: String) -> Result<ProjectSummary, String> {
    let project = PathBuf::from(path);
    if !project.is_dir() {
        return Err("the selected project folder does not exist".to_string());
    }
    save_project(&app, &project)?;
    scaffold_project(&project);
    Ok(inspect_project(&project))
}

// returns a fresh status summary for the selected project
#[tauri::command]
fn refresh_project(path: String) -> Result<ProjectSummary, String> {
    let project = PathBuf::from(path);
    if !project.is_dir() {
        return Err("the selected project folder does not exist".to_string());
    }
    Ok(inspect_project(&project))
}

// lists project input files available to the data editor
#[tauri::command]
fn data_editor_files(project_path: String) -> Result<Vec<DataEditorFile>, String> {
    let project = PathBuf::from(project_path);
    if !project.is_dir() {
        return Err("the selected dataset folder does not exist".to_string());
    }
    data_editor_files_for_project(&project)
}

// reads one project input file for editing
#[tauri::command]
fn data_editor_read(project_path: String, kind: String) -> Result<DataEditorContent, String> {
    let project = PathBuf::from(project_path);
    if !project.is_dir() {
        return Err("the selected dataset folder does not exist".to_string());
    }
    let path = data_editor_path(&project, &kind)?;
    read_data_editor_content_from_path(&project, &kind, &path)
}

// reads one saved data editor backup without replacing the active project file
#[tauri::command]
fn data_editor_read_backup(
    project_path: String,
    kind: String,
    backup: String,
) -> Result<DataEditorContent, String> {
    let project = PathBuf::from(project_path);
    if !project.is_dir() {
        return Err("the selected dataset folder does not exist".to_string());
    }
    let backup = safe_backup_name(&backup)?.to_string();
    let directory = data_editor_backup_dir(&project, &kind)?;
    let source = directory.join(&backup);
    if !source.is_file() {
        return Err("that data backup no longer exists".to_string());
    }
    read_data_editor_content_from_path(&project, &kind, &source)
}

// saves one project input file after snapshotting its previous version
#[tauri::command]
fn data_editor_save(
    project_path: String,
    input: DataEditorSaveInput,
) -> Result<DataEditorContent, String> {
    let project = PathBuf::from(&project_path);
    if !project.is_dir() {
        return Err("the selected dataset folder does not exist".to_string());
    }
    let file = data_editor_file(&project, &input.kind)?;
    let path = data_editor_path(&project, &input.kind)?;
    // preserve the pristine original before the first edit lands, if it has not
    // already been captured (reads/lists normally do this on open)
    ensure_data_editor_original_backup(&project, &input.kind)?;
    if file.format == "text" {
        if let Some(parent) = path.parent() {
            fs::create_dir_all(parent).map_err(|error| error.to_string())?;
        }
        fs::write(&path, input.text.unwrap_or_default()).map_err(|error| error.to_string())?;
    } else {
        write_csv_table(&path, &input.headers, &input.rows)?;
    }
    // snapshot AFTER writing so the backup captures the change just saved, not
    // the previous state (which used to lag one save behind)
    backup_data_editor_file(&project, &input.kind, &path)?;
    data_editor_read(project_path, input.kind)
}

// restores a selected backup over one editable project input file
#[tauri::command]
fn data_editor_restore_backup(
    project_path: String,
    kind: String,
    backup: String,
) -> Result<DataEditorContent, String> {
    let project = PathBuf::from(&project_path);
    if !project.is_dir() {
        return Err("the selected dataset folder does not exist".to_string());
    }
    let backup = safe_backup_name(&backup)?.to_string();
    let path = data_editor_path(&project, &kind)?;
    let directory = data_editor_backup_dir(&project, &kind)?;
    let source = directory.join(&backup);
    if !source.is_file() {
        return Err("that data backup no longer exists".to_string());
    }
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent).map_err(|error| error.to_string())?;
    }
    fs::copy(source, &path).map_err(|error| error.to_string())?;
    data_editor_read(project_path, kind)
}

// deletes one saved data editor backup
#[tauri::command]
fn data_editor_delete_backup(
    project_path: String,
    kind: String,
    backup: String,
) -> Result<DataEditorContent, String> {
    let project = PathBuf::from(&project_path);
    if !project.is_dir() {
        return Err("the selected dataset folder does not exist".to_string());
    }
    let backup = safe_backup_name(&backup)?.to_string();
    if is_data_editor_original_backup(&project, &kind, &backup)? {
        return Err("Original cannot be deleted".to_string());
    }
    let directory = data_editor_backup_dir(&project, &kind)?;
    let source = directory.join(&backup);
    if !source.is_file() {
        return Err("that data backup no longer exists".to_string());
    }
    fs::remove_file(source).map_err(|error| error.to_string())?;
    data_editor_read(project_path, kind)
}

// renames one saved data editor backup and returns the new file name
#[tauri::command]
fn data_editor_rename_backup(
    project_path: String,
    kind: String,
    backup: String,
    name: String,
) -> Result<String, String> {
    let project = PathBuf::from(project_path);
    if !project.is_dir() {
        return Err("the selected dataset folder does not exist".to_string());
    }
    let backup = safe_backup_name(&backup)?.to_string();
    if is_data_editor_original_backup(&project, &kind, &backup)? {
        return Err("Original cannot be renamed".to_string());
    }
    let new_name = safe_data_editor_backup_name(&name, &backup)?;
    let directory = data_editor_backup_dir(&project, &kind)?;
    let source = directory.join(&backup);
    if !source.is_file() {
        return Err("that data backup no longer exists".to_string());
    }
    let target = directory.join(&new_name);
    if target.exists() {
        return Err("a backup with that name already exists".to_string());
    }
    fs::rename(source, target).map_err(|error| error.to_string())?;
    Ok(new_name)
}

// lists missing user-facing inputs without creating or changing any files
#[tauri::command]
fn missing_project_files(
    project_path: String,
    run_order_name: String,
    transition_name: String,
) -> Result<MissingInputPlan, String> {
    let project = PathBuf::from(&project_path);
    if !project.is_dir() {
        return Err("the selected dataset folder does not exist".to_string());
    }
    let (run_order, transition) =
        requested_input_paths(&project, &run_order_name, &transition_name)?;
    let param_missing = !project.join("param.txt").is_file();
    let mut files = Vec::new();
    if param_missing {
        files.push(MissingInput {
            kind: "param".to_string(),
            name: "param.txt".to_string(),
        });
    }
    if !transition.is_file() {
        files.push(MissingInput {
            kind: "transition".to_string(),
            name: relative_name(&project, &transition),
        });
    }
    if !run_order.is_file() {
        files.push(MissingInput {
            kind: "runOrder".to_string(),
            name: relative_name(&project, &run_order),
        });
    }
    Ok(MissingInputPlan {
        files,
        param_needs_configuration: false,
    })
}

// creates only the missing inputs approved by the user and never overwrites
// an existing param, transition-list, or run-order file
#[tauri::command]
fn create_missing_project_files(
    project_path: String,
    run_order_name: String,
    transition_name: String,
) -> Result<CreatedInputs, String> {
    let project = PathBuf::from(&project_path);
    if !project.is_dir() {
        return Err("the selected dataset folder does not exist".to_string());
    }
    let (run_order, transition) =
        requested_input_paths(&project, &run_order_name, &transition_name)?;
    let mut created = Vec::new();
    let param = project.join("param.txt");
    if !transition.exists() {
        create_transition_list(&project, &transition)?;
        created.push(relative_name(&project, &transition));
    }
    if !run_order.exists() {
        create_run_order(&project, &run_order)?;
        created.push(relative_name(&project, &run_order));
    }
    if !param.exists() {
        create_param(&project, &param, &run_order, &transition)?;
        created.push("param.txt".to_string());
    }
    Ok(CreatedInputs {
        project: inspect_project(&project),
        created,
    })
}

// lists the RT_matrix snapshots plus the version this project last used
#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct BackupList {
    backups: Vec<String>,
    last: Option<String>,
    labels: HashMap<String, String>,
}

// returns the file name and label assigned to an imported RT_matrix backup
#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct ImportedBackup {
    name: String,
    label: String,
}

// keeps the original first and timestamped versions oldest-to-newest so the
// latest save appears at the bottom of the dropdown
fn order_backups(mut backups: Vec<String>) -> Vec<String> {
    backups.sort_unstable();
    if let Some(index) = backups.iter().position(|name| name == ORIGINAL_BACKUP) {
        let original = backups.remove(index);
        backups.insert(0, original);
    }
    backups
}

// copies the current RT_matrix.csv into a timestamped backup; returns the name
// actually written, or None when there is no RT_matrix.csv to snapshot
#[tauri::command]
fn backup_rtmatrix(project_path: String, name: String) -> Result<Option<String>, String> {
    let project = PathBuf::from(&project_path);
    if !project.is_dir() {
        return Err("the selected dataset folder does not exist".to_string());
    }
    let name = safe_backup_name(&name)?;
    let source = project.join("RT_matrix.csv");
    if !source.is_file() {
        return Ok(None);
    }
    let directory = backup_directory(&project);
    fs::create_dir_all(&directory).map_err(|error| error.to_string())?;
    fs::copy(&source, directory.join(name)).map_err(|error| error.to_string())?;
    Ok(Some(name.to_string()))
}

// deletes a user-created RT_matrix backup while keeping the protected original
// snapshot available for safe reverts
fn delete_rtmatrix_backup_file(project: &Path, name: &str) -> Result<(), String> {
    let name = safe_backup_name(name)?;
    if name == ORIGINAL_BACKUP {
        return Err("Original RT_matrix cannot be deleted".to_string());
    }
    let source = backup_directory(project).join(name);
    if !source.is_file() {
        return Err("that backup version no longer exists".to_string());
    }
    fs::remove_file(source).map_err(|error| error.to_string())
}

// validates the friendly dropdown label for a saved RT_matrix snapshot
fn safe_backup_label(label: &str) -> Result<String, String> {
    let label = label.trim();
    if label.is_empty() {
        return Err("the backup label cannot be blank".to_string());
    }
    if label.chars().count() > 80 || label.chars().any(char::is_control) {
        return Err("the backup label is too long or contains invalid characters".to_string());
    }
    Ok(label.to_string())
}

// returns the next import label, preserving already-used import numbers
fn next_import_label(labels: &HashMap<String, String>) -> String {
    let maximum = labels
        .values()
        .filter_map(|label| {
            label
                .strip_prefix("import")
                .and_then(|suffix| suffix.parse::<usize>().ok())
        })
        .max()
        .unwrap_or(0);
    format!("import{}", maximum + 1)
}

// imports an external CSV into the RT_matrix backup folder and labels it as an
// import without replacing the current working RT_matrix.csv yet
#[tauri::command]
fn import_rtmatrix_backup(
    app: AppHandle,
    project_path: String,
    source_path: String,
    name: String,
) -> Result<ImportedBackup, String> {
    let project = PathBuf::from(&project_path);
    if !project.is_dir() {
        return Err("the selected dataset folder does not exist".to_string());
    }
    let source = PathBuf::from(source_path);
    if !source.is_file()
        || !source
            .extension()
            .and_then(|extension| extension.to_str())
            .is_some_and(|extension| extension.eq_ignore_ascii_case("csv"))
    {
        return Err("select a CSV file to import".to_string());
    }
    let name = safe_backup_name(&name)?.to_string();
    let directory = backup_directory(&project);
    fs::create_dir_all(&directory).map_err(|error| error.to_string())?;
    let target = directory.join(&name);
    if target.exists() {
        return Err("a backup with that timestamp already exists; try importing again".to_string());
    }
    fs::copy(source, &target).map_err(|error| error.to_string())?;

    let mut settings = read_settings(&app).unwrap_or_default();
    let label = {
        let labels = settings
            .backup_labels
            .entry(project_path.clone())
            .or_default();
        let label = next_import_label(labels);
        labels.insert(name.clone(), label.clone());
        label
    };
    settings.last_backups.insert(project_path, name.clone());
    write_settings(&app, &settings)?;
    Ok(ImportedBackup { name, label })
}

// deletes one saved RT_matrix snapshot from the selected dataset
#[tauri::command]
fn delete_rtmatrix_backup(
    app: AppHandle,
    project_path: String,
    name: String,
) -> Result<(), String> {
    let project = PathBuf::from(&project_path);
    if !project.is_dir() {
        return Err("the selected dataset folder does not exist".to_string());
    }
    delete_rtmatrix_backup_file(&project, &name)?;
    let mut settings = read_settings(&app).unwrap_or_default();
    if settings
        .last_backups
        .get(&project_path)
        .is_some_and(|last| last == &name)
    {
        settings.last_backups.remove(&project_path);
    }
    let remove_project_labels = if let Some(labels) = settings.backup_labels.get_mut(&project_path)
    {
        labels.remove(&name);
        labels.is_empty()
    } else {
        false
    };
    if remove_project_labels {
        settings.backup_labels.remove(&project_path);
    }
    write_settings(&app, &settings)?;
    Ok(())
}

fn delete_all_user_rtmatrix_backup_files(project: &Path) -> Result<usize, String> {
    let directory = backup_directory(project);
    if !directory.is_dir() {
        return Ok(0);
    }
    let mut deleted = 0;
    for entry in fs::read_dir(directory).map_err(|error| error.to_string())? {
        let path = entry.map_err(|error| error.to_string())?.path();
        let is_csv = path.is_file()
            && path
                .extension()
                .and_then(|extension| extension.to_str())
                .is_some_and(|extension| extension.eq_ignore_ascii_case("csv"));
        let is_original = path
            .file_name()
            .and_then(|name| name.to_str())
            .is_some_and(|name| name == ORIGINAL_BACKUP);
        if is_csv && !is_original {
            fs::remove_file(path).map_err(|error| error.to_string())?;
            deleted += 1;
        }
    }
    Ok(deleted)
}

// Restores the protected Original as the working matrix before removing every
// user-created snapshot. This leaves both the data on disk and the dropdown's
// remembered selection on a real, recoverable version after Delete All.
fn restore_original_and_delete_all_rtmatrix_backups(project: &Path) -> Result<usize, String> {
    ensure_original(project)?;
    let original = backup_directory(project).join(ORIGINAL_BACKUP);
    fs::copy(original, project.join("RT_matrix.csv")).map_err(|error| error.to_string())?;
    delete_all_user_rtmatrix_backup_files(project)
}

// Deletes every user-created backup for only the selected dataset. The
// protected Step 2 Original becomes the active working matrix afterward.
#[tauri::command]
fn delete_all_rtmatrix_backups(app: AppHandle, project_path: String) -> Result<usize, String> {
    let project = PathBuf::from(&project_path);
    if !project.is_dir() {
        return Err("the selected dataset folder does not exist".to_string());
    }
    let deleted = restore_original_and_delete_all_rtmatrix_backups(&project)?;
    let mut settings = read_settings(&app).unwrap_or_default();
    settings
        .last_backups
        .insert(project_path.clone(), ORIGINAL_BACKUP.to_string());
    settings.backup_labels.remove(&project_path);
    write_settings(&app, &settings)?;
    Ok(deleted)
}

// Replaces one existing user-created backup with the current working matrix.
// Original stays immutable so an override can never destroy the Step 2 baseline.
#[tauri::command]
fn overwrite_rtmatrix_backup(project_path: String, name: String) -> Result<(), String> {
    let project = PathBuf::from(project_path);
    if !project.is_dir() {
        return Err("the selected dataset folder does not exist".to_string());
    }
    let name = safe_backup_name(&name)?;
    if name == ORIGINAL_BACKUP {
        return Err("Original RT_matrix cannot be overridden".to_string());
    }
    let source = project.join("RT_matrix.csv");
    if !source.is_file() {
        return Err("RT_matrix.csv does not exist".to_string());
    }
    let target = backup_directory(&project).join(name);
    if !target.is_file() {
        return Err("that backup version no longer exists".to_string());
    }
    fs::copy(source, target)
        .map(|_| ())
        .map_err(|error| error.to_string())
}

// stores a friendly dropdown label for one saved RT_matrix snapshot without
// renaming the file, preserving chronological ordering and restore safety
#[tauri::command]
fn rename_rtmatrix_backup(
    app: AppHandle,
    project_path: String,
    name: String,
    label: String,
) -> Result<(), String> {
    let project = PathBuf::from(&project_path);
    if !project.is_dir() {
        return Err("the selected dataset folder does not exist".to_string());
    }
    let name = safe_backup_name(&name)?.to_string();
    if name == ORIGINAL_BACKUP {
        return Err("Original RT_matrix cannot be renamed".to_string());
    }
    if !backup_directory(&project).join(&name).is_file() {
        return Err("that backup version no longer exists".to_string());
    }
    let label = safe_backup_label(&label)?;
    let mut settings = read_settings(&app).unwrap_or_default();
    settings
        .backup_labels
        .entry(project_path)
        .or_default()
        .insert(name, label);
    write_settings(&app, &settings)
}

// lists RT_matrix backups oldest-first with the remembered selection
#[tauri::command]
fn list_rtmatrix_backups(app: AppHandle, project_path: String) -> Result<BackupList, String> {
    let project = PathBuf::from(&project_path);
    flatten_previous_nested_backups(&project)?;
    ensure_original(&project)?;
    let directory = backup_directory(&project);
    let backups: Vec<String> = if directory.is_dir() {
        fs::read_dir(&directory)
            .map_err(|error| error.to_string())?
            .filter_map(Result::ok)
            .filter(|entry| entry.path().extension().is_some_and(|ext| ext == "csv"))
            .filter_map(|entry| entry.file_name().to_str().map(str::to_string))
            .collect()
    } else {
        Vec::new()
    };
    let backups = order_backups(backups);
    let settings = read_settings(&app).unwrap_or_default();
    let last = settings
        .last_backups
        .get(&project_path)
        .cloned()
        .filter(|name| backups.contains(name));
    let labels = settings
        .backup_labels
        .get(&project_path)
        .map(|labels| {
            labels
                .iter()
                .filter(|(name, _)| backups.contains(name))
                .map(|(name, label)| (name.clone(), label.clone()))
                .collect()
        })
        .unwrap_or_default();
    Ok(BackupList {
        backups,
        last,
        labels,
    })
}

// restores a chosen backup over the working RT_matrix.csv
#[tauri::command]
fn restore_rtmatrix_backup(project_path: String, name: String) -> Result<(), String> {
    let project = PathBuf::from(&project_path);
    if !project.is_dir() {
        return Err("the selected dataset folder does not exist".to_string());
    }
    let name = safe_backup_name(&name)?;
    let source = backup_directory(&project).join(name);
    if !source.is_file() {
        return Err("that backup version no longer exists".to_string());
    }
    fs::copy(&source, project.join("RT_matrix.csv")).map_err(|error| error.to_string())?;
    Ok(())
}

// remembers which backup version a project is currently using
#[tauri::command]
fn set_last_backup(app: AppHandle, project_path: String, name: String) -> Result<(), String> {
    let name = safe_backup_name(&name)?.to_string();
    let mut settings = read_settings(&app).unwrap_or_default();
    settings.last_backups.insert(project_path, name);
    write_settings(&app, &settings)
}

// saves the selected light or dark interface theme
#[tauri::command]
fn set_theme(app: AppHandle, theme: String) -> Result<(), String> {
    if theme != "light" && theme != "dark" {
        return Err("the interface theme must be light or dark".to_string());
    }
    let mut settings = read_settings(&app).unwrap_or_default();
    settings.theme = Some(theme);
    write_settings(&app, &settings)
}

// opens the fixed sling website in the operating system browser
#[tauri::command]
fn open_sling() -> Result<(), String> {
    const SLING_URL: &str = "https://sling.sg/";

    #[cfg(target_os = "windows")]
    let mut command = {
        let mut command = Command::new("rundll32.exe");
        command.arg("url.dll,FileProtocolHandler").arg(SLING_URL);
        use std::os::windows::process::CommandExt;
        command.creation_flags(0x08000000);
        command
    };

    #[cfg(target_os = "macos")]
    let mut command = {
        let mut command = Command::new("open");
        command.arg(SLING_URL);
        command
    };

    #[cfg(all(unix, not(target_os = "macos")))]
    let mut command = {
        let mut command = Command::new("xdg-open");
        command.arg(SLING_URL);
        command
    };

    command
        .spawn()
        .map(|_| ())
        .map_err(|error| format!("the sling website could not be opened: {error}"))
}

// Removes terminal-only styling/control sequences before worker output reaches
// the GUI. This keeps colored or underlined CLI messages readable in Activity.
fn clean_worker_output(bytes: &[u8]) -> String {
    let mut clean = Vec::with_capacity(bytes.len());
    let mut index = 0;
    while index < bytes.len() {
        if bytes[index] == 0x1b {
            index += 1;
            match bytes.get(index) {
                // CSI sequence, such as ESC[1;4m for bold + underline.
                Some(b'[') => {
                    index += 1;
                    while index < bytes.len() {
                        let byte = bytes[index];
                        index += 1;
                        if (0x40..=0x7e).contains(&byte) {
                            break;
                        }
                    }
                }
                // OSC sequence, terminated by BEL or ESC + backslash.
                Some(b']') => {
                    index += 1;
                    while index < bytes.len() {
                        if bytes[index] == 0x07 {
                            index += 1;
                            break;
                        }
                        if bytes[index] == 0x1b && bytes.get(index + 1) == Some(&b'\\') {
                            index += 2;
                            break;
                        }
                        index += 1;
                    }
                }
                Some(_) => index += 1,
                None => {}
            }
        } else if bytes[index] < 0x20 && bytes[index] != b'\t' {
            index += 1;
        } else {
            clean.push(bytes[index]);
            index += 1;
        }
    }
    String::from_utf8_lossy(&clean).trim().to_string()
}

// Drains worker output in chunks and treats both carriage returns and newlines
// as progress boundaries. Chunking avoids flooding Windows WebView2 with tiny
// native reads, while the size cap prevents malformed output from accumulating.
fn read_output_records<R, F>(mut reader: R, mut on_record: F) -> Result<(), String>
where
    R: Read,
    F: FnMut(String),
{
    const MAX_RECORD_BYTES: usize = 64 * 1024;
    let mut chunk = [0_u8; 8192];
    let mut pending = Vec::with_capacity(256);
    let emit = |pending: &mut Vec<u8>, on_record: &mut F| {
        if pending.is_empty() {
            return;
        }
        let text = clean_worker_output(pending);
        pending.clear();
        if !text.is_empty() {
            on_record(text);
        }
    };
    loop {
        let count = reader.read(&mut chunk).map_err(|error| error.to_string())?;
        if count == 0 {
            break;
        }
        for &byte in &chunk[..count] {
            if byte == b'\n' || byte == b'\r' {
                emit(&mut pending, &mut on_record);
            } else {
                pending.push(byte);
                if pending.len() >= MAX_RECORD_BYTES {
                    emit(&mut pending, &mut on_record);
                }
            }
        }
    }
    emit(&mut pending, &mut on_record);
    Ok(())
}

// emits complete cleaned records from a worker output stream
fn forward_output<R: Read>(
    reader: R,
    app: &AppHandle,
    step: u8,
    stream: &str,
) -> Result<(), String> {
    read_output_records(reader, |line| {
        let _ = app.emit(
            "worker-output",
            WorkerOutput {
                step,
                stream: stream.to_string(),
                line,
            },
        );
    })
}

// runs one processing step inside the selected project
fn run_worker(app: AppHandle, project: PathBuf, step: u8) -> Result<ProjectSummary, String> {
    let worker = find_worker(&project)
        .ok_or_else(|| "the integrator processing engine was not found".to_string())?;
    let mut command = Command::new(worker);
    command
        .arg(step.to_string())
        .current_dir(&project)
        .env("MRMHUB_PROJECT_DIR", &project)
        .stdout(Stdio::piped())
        .stderr(Stdio::piped());

    #[cfg(target_os = "windows")]
    {
        use std::os::windows::process::CommandExt;
        command.creation_flags(0x08000000);
    }

    let mut child = command.spawn().map_err(|error| error.to_string())?;
    let stdout = child
        .stdout
        .take()
        .ok_or_else(|| "the processing output stream was unavailable".to_string())?;
    let stderr = child
        .stderr
        .take()
        .ok_or_else(|| "the processing error stream was unavailable".to_string())?;

    let stderr_app = app.clone();
    let stderr_thread =
        std::thread::spawn(move || forward_output(stderr, &stderr_app, step, "error"));
    forward_output(stdout, &app, step, "output")?;
    let status = child.wait().map_err(|error| error.to_string())?;
    stderr_thread
        .join()
        .map_err(|_| "the processing error reader stopped unexpectedly".to_string())??;

    if !status.success() {
        return Err(format!(
            "processing step {step} exited with code {}",
            status.code().unwrap_or(-1)
        ));
    }
    if step == 2 {
        capture_original(&project)?;
    }
    Ok(inspect_project(&project))
}

// ensures workflow steps cannot run before their required outputs exist
fn validate_prerequisite(project: &Path, step: u8) -> Result<(), String> {
    let outputs = inspect_project(project).outputs;
    let requirement = match step {
        2 if !outputs.validated => Some("run step 1, Validate data, before detecting peaks"),
        3 if !outputs.detected => Some("run step 2, Detect peaks, before integrating peaks"),
        4 if !outputs.integrated => Some("run step 3, Integrate peaks, before generating reports"),
        _ => None,
    };
    requirement.map_or(Ok(()), |message| Err(message.to_string()))
}

// starts one workflow step while preventing overlapping runs
#[tauri::command]
async fn run_step(
    app: AppHandle,
    state: State<'_, RunState>,
    path: String,
    step: u8,
) -> Result<ProjectSummary, String> {
    if !(1..=4).contains(&step) {
        return Err("the workflow step must be between 1 and 4".to_string());
    }
    let project = PathBuf::from(&path);
    if !project.is_dir() {
        return Err("the selected dataset folder does not exist".to_string());
    }
    validate_prerequisite(&project, step)?;
    if state
        .0
        .compare_exchange(false, true, Ordering::AcqRel, Ordering::Acquire)
        .is_err()
    {
        return Err("another processing step is already running".to_string());
    }

    let _ = app.emit(
        "step-state",
        StepState {
            step,
            status: "running".to_string(),
        },
    );
    let worker_app = app.clone();
    let result =
        tauri::async_runtime::spawn_blocking(move || run_worker(worker_app, project, step))
            .await
            .map_err(|error| error.to_string())
            .and_then(|result| result);

    state.0.store(false, Ordering::Release);
    let status = if result.is_ok() { "complete" } else { "failed" };
    let _ = app.emit(
        "step-state",
        StepState {
            step,
            status: status.to_string(),
        },
    );
    result
}

// lists saved scratchpad notes without loading their text bodies
#[tauri::command]
fn scratchpad_list_notes(app: AppHandle) -> Result<Vec<ScratchpadNoteSummary>, String> {
    let directory = scratchpad_dir(&app)?;
    if !directory.is_dir() {
        return Ok(Vec::new());
    }
    let mut notes: Vec<ScratchpadNoteSummary> = fs::read_dir(directory)
        .map_err(|error| error.to_string())?
        .filter_map(Result::ok)
        .map(|entry| entry.path())
        .filter(|path| {
            path.extension()
                .is_some_and(|extension| extension == "json")
        })
        .filter_map(|path| read_scratchpad_summary(&path))
        .collect();
    notes.sort_by(|left, right| {
        right
            .pinned
            .cmp(&left.pinned)
            .then_with(|| right.created_at.cmp(&left.created_at))
            .then_with(|| left.title.cmp(&right.title))
    });
    Ok(notes)
}

// creates a new saved scratchpad note and returns it as the current note
#[tauri::command]
fn scratchpad_create_note(
    app: AppHandle,
    title: String,
    include_timestamp: bool,
) -> Result<ScratchpadNote, String> {
    let created_at = now_millis()?;
    let mut id = format!("note_{created_at}");
    let mut suffix = 1;
    while scratchpad_paths(&app, &id)?.0.exists() {
        id = format!("note_{created_at}_{suffix}");
        suffix += 1;
    }
    let note = ScratchpadNote {
        summary: ScratchpadNoteSummary {
            id,
            title: safe_note_title(&title),
            created_at,
            updated_at: created_at,
            pinned: false,
            include_timestamp,
        },
        content: String::new(),
    };
    write_scratchpad_note(&app, &note)?;
    Ok(note)
}

// loads one saved scratchpad note together with its text body
#[tauri::command]
fn scratchpad_load_note(app: AppHandle, id: String) -> Result<ScratchpadNote, String> {
    let (metadata_path, content_path) = scratchpad_paths(&app, &id)?;
    let summary = read_scratchpad_summary(&metadata_path)
        .ok_or_else(|| "that scratchpad note no longer exists".to_string())?;
    let content = fs::read_to_string(content_path).unwrap_or_default();
    Ok(ScratchpadNote { summary, content })
}

// saves editable scratchpad note fields
#[tauri::command]
fn scratchpad_save_note(
    app: AppHandle,
    input: ScratchpadSaveInput,
) -> Result<ScratchpadNote, String> {
    let (metadata_path, _) = scratchpad_paths(&app, &input.id)?;
    let mut summary = read_scratchpad_summary(&metadata_path)
        .ok_or_else(|| "that scratchpad note no longer exists".to_string())?;
    summary.title = safe_note_title(&input.title);
    summary.updated_at = now_millis()?;
    summary.pinned = input.pinned;
    summary.include_timestamp = input.include_timestamp;
    let note = ScratchpadNote {
        summary,
        content: input.content,
    };
    write_scratchpad_note(&app, &note)?;
    Ok(note)
}

// deletes one saved scratchpad note
#[tauri::command]
fn scratchpad_delete_note(app: AppHandle, id: String) -> Result<(), String> {
    let (metadata_path, content_path) = scratchpad_paths(&app, &id)?;
    if !metadata_path.exists() {
        return Err("that scratchpad note no longer exists".to_string());
    }
    fs::remove_file(metadata_path).map_err(|error| error.to_string())?;
    match fs::remove_file(content_path) {
        Ok(()) => Ok(()),
        Err(error) if error.kind() == std::io::ErrorKind::NotFound => Ok(()),
        Err(error) => Err(error.to_string()),
    }
}

// starts the graphical application
fn main() {
    tauri::Builder::default()
        .manage(RunState(AtomicBool::new(false)))
        .plugin(tauri_plugin_dialog::init())
        .on_window_event(|window, event| {
            if matches!(event, WindowEvent::CloseRequested { .. }) {
                log_exit_for_current_project(window.app_handle());
            }
        })
        .invoke_handler(tauri::generate_handler![
            load_startup_state,
            select_project,
            refresh_project,
            data_editor_files,
            data_editor_read,
            data_editor_read_backup,
            data_editor_save,
            data_editor_restore_backup,
            data_editor_delete_backup,
            data_editor_rename_backup,
            missing_project_files,
            create_missing_project_files,
            backup_rtmatrix,
            delete_rtmatrix_backup,
            delete_all_rtmatrix_backups,
            import_rtmatrix_backup,
            list_rtmatrix_backups,
            overwrite_rtmatrix_backup,
            rename_rtmatrix_backup,
            restore_rtmatrix_backup,
            set_last_backup,
            set_theme,
            open_sling,
            scratchpad_list_notes,
            scratchpad_create_note,
            scratchpad_load_note,
            scratchpad_save_note,
            scratchpad_delete_note,
            visualizer::visualizer_get_ref,
            visualizer::visualizer_trans_csv,
            visualizer::visualizer_mzml_tsv,
            visualizer::visualizer_read_long,
            visualizer::visualizer_get_t,
            visualizer::visualizer_get_sh,
            visualizer::visualizer_get_r,
            visualizer::visualizer_save_bounds,
            visualizer::visualizer_save_shared_bounds,
            visualizer::visualizer_prepare_png_export,
            visualizer::visualizer_save_png,
            run_step
        ])
        .run(tauri::generate_context!())
        .expect("error while running mrmhub integrator");
}

#[cfg(test)]
mod tests {
    use super::*;

    fn temp_project(tag: &str) -> PathBuf {
        let dir = std::env::temp_dir().join(format!("mrmhub_backup_{tag}_{}", std::process::id()));
        let _ = fs::remove_dir_all(&dir);
        fs::create_dir_all(&dir).unwrap();
        dir
    }

    #[test]
    fn worker_output_removes_terminal_formatting_before_display() {
        let output = clean_worker_output(b"Check \x1b[1;4mmissing_compounds.txt\x1b[0m.");
        assert_eq!(output, "Check missing_compounds.txt.");
    }

    #[test]
    fn worker_progress_splits_carriage_returns_without_large_buffering() {
        let mut records = Vec::new();
        read_output_records(
            std::io::Cursor::new(b"first\rsecond\r\nthird\nlast"),
            |record| records.push(record),
        )
        .unwrap();
        assert_eq!(records, ["first", "second", "third", "last"]);
    }

    #[test]
    fn approved_setup_creates_blank_templates_without_overwriting() {
        let dir = temp_project("setup");
        fs::create_dir_all(dir.join("mzML")).unwrap();
        fs::write(dir.join("mzML").join("a.mzML"), b"").unwrap();
        fs::write(dir.join("mzML").join("b.mzML"), b"").unwrap();
        fs::write(
            dir.join("param.txt"),
            "mzML_files = 'mzML/*.mzML'\nbatch_info = 'run_order_2026-07-09_21-30-45.csv'\ntransition_list = 'transition_list_missing.csv'\n",
        )
        .unwrap();
        fs::write(
            dir.join("transition_list_template.csv"),
            "Compound Name,Transition Name,ISTD,Precursor Ion,Product Ion,RT,Remarks\nCE 14:0,CE 14:0,CE d7,614.6,369.3,7.133,review\n",
        )
        .unwrap();

        let plan = missing_project_files(
            dir.to_string_lossy().into_owned(),
            "run_order_2026-07-09_21-30-45.csv".to_string(),
            "transition_list.csv".to_string(),
        )
        .unwrap();
        assert_eq!(plan.files.len(), 2);
        assert!(!plan.param_needs_configuration);

        let created = create_missing_project_files(
            dir.to_string_lossy().into_owned(),
            "run_order_2026-07-09_21-30-45.csv".to_string(),
            "transition_list.csv".to_string(),
        )
        .unwrap();
        assert_eq!(created.created.len(), 2);

        let run_order = fs::read_to_string(dir.join("run_order_2026-07-09_21-30-45.csv")).unwrap();
        assert!(run_order.contains("file name,batch,sample_type"));
        assert!(run_order.contains("a.mzML,,,"));
        assert!(run_order.contains("b.mzML,,,"));

        let transitions = fs::read_to_string(dir.join("transition_list_missing.csv")).unwrap();
        assert!(transitions.contains("CE 14:0,CE 14:0,CE d7,,,,"));
        assert!(!transitions.contains("614.6"));
        assert!(!transitions.contains("review"));

        fs::write(dir.join("run_order_2026-07-09_21-30-45.csv"), "sentinel").unwrap();
        let second = create_missing_project_files(
            dir.to_string_lossy().into_owned(),
            "run_order_2026-07-09_21-30-45.csv".to_string(),
            "transition_list.csv".to_string(),
        )
        .unwrap();
        assert!(second.created.is_empty());
        assert_eq!(
            fs::read_to_string(dir.join("run_order_2026-07-09_21-30-45.csv")).unwrap(),
            "sentinel"
        );
        fs::remove_dir_all(&dir).unwrap();
    }

    #[test]
    fn missing_param_plan_uses_timestamped_run_order_and_creates_filled_param() {
        let dir = temp_project("blank_param");
        let run_order = "run_order_2026-07-09_21-30-45.csv".to_string();
        let transition = "transition_list.csv".to_string();
        let plan = missing_project_files(
            dir.to_string_lossy().into_owned(),
            run_order.clone(),
            transition.clone(),
        )
        .unwrap();
        assert!(!plan.param_needs_configuration);
        assert_eq!(plan.files[0].name, "param.txt");
        assert!(plan.files.iter().any(|file| file.name == run_order));
        assert!(plan.files.iter().any(|file| file.name == transition));

        create_missing_project_files(
            dir.to_string_lossy().into_owned(),
            run_order.clone(),
            transition.clone(),
        )
        .unwrap();
        let param = fs::read_to_string(dir.join("param.txt")).unwrap();
        assert!(param.contains("mzML_files"));
        assert!(param.contains(&format!("batch_info = \"{run_order}\"")));
        assert!(param.contains(&format!("transition_list = \"{transition}\"")));
        fs::remove_dir_all(&dir).unwrap();
    }

    #[test]
    fn missing_param_does_not_duplicate_existing_input_tables() {
        let dir = temp_project("existing_inputs");
        fs::write(dir.join("run_order_existing.csv"), "file name,batch\n").unwrap();
        fs::write(
            dir.join("transition_list_existing.csv"),
            "Compound Name,Transition Name\n",
        )
        .unwrap();
        let plan = missing_project_files(
            dir.to_string_lossy().into_owned(),
            "run_order_2026-07-09_21-30-45.csv".to_string(),
            "transition_list.csv".to_string(),
        )
        .unwrap();
        assert_eq!(plan.files.len(), 1);
        assert_eq!(plan.files[0].name, "param.txt");
        let created = create_missing_project_files(
            dir.to_string_lossy().into_owned(),
            "run_order_2026-07-09_21-30-45.csv".to_string(),
            "transition_list.csv".to_string(),
        )
        .unwrap();
        assert_eq!(created.created, ["param.txt"]);
        let param = fs::read_to_string(dir.join("param.txt")).unwrap();
        assert!(param.contains("batch_info = \"run_order_existing.csv\""));
        assert!(param.contains("transition_list = \"transition_list_existing.csv\""));
        fs::remove_dir_all(&dir).unwrap();
    }

    #[test]
    fn data_editor_save_backs_up_the_content_just_saved() {
        let dir = temp_project("editor_save");
        // an existing param.txt stands in for the previous saved state
        fs::write(dir.join("param.txt"), "v0").unwrap();

        data_editor_save(
            dir.to_string_lossy().into_owned(),
            DataEditorSaveInput {
                kind: "param".to_string(),
                text: Some("v1".to_string()),
                headers: Vec::new(),
                rows: Vec::new(),
            },
        )
        .unwrap();

        // the live file holds the new edit
        assert_eq!(fs::read_to_string(dir.join("param.txt")).unwrap(), "v1");

        let backup_dir = dir.join("data_file_backups").join("param");
        let mut timestamped = Vec::new();
        let mut original = None;
        for entry in fs::read_dir(&backup_dir).unwrap() {
            let name = entry.unwrap().file_name().to_string_lossy().into_owned();
            let body = fs::read_to_string(backup_dir.join(&name)).unwrap();
            if name == "original.txt" {
                original = Some(body);
            } else {
                timestamped.push(body);
            }
        }
        // the timestamped snapshot must be the edit just saved (not "v0"), so a
        // single save is enough — no need to press Save twice
        assert_eq!(timestamped, ["v1"]);
        // and the pristine pre-edit state is still preserved as the Original
        assert_eq!(original.as_deref(), Some("v0"));
        fs::remove_dir_all(&dir).unwrap();
    }

    #[test]
    fn exit_log_appends_blank_line_between_close_entries() {
        let dir = temp_project("exit_log");

        append_exit_log_entry(&dir, "exit // mrmhub-gui closed @ 23/07/2026 , 18h:22m:30s")
            .unwrap();
        append_exit_log_entry(&dir, "exit // mrmhub-gui closed @ 24/07/2026 , 10h:51m:19s")
            .unwrap();

        let log = fs::read_to_string(dir.join("exit_log.txt")).unwrap();
        assert_eq!(
            log,
            "exit // mrmhub-gui closed @ 23/07/2026 , 18h:22m:30s\n\nexit // mrmhub-gui closed @ 24/07/2026 , 10h:51m:19s\n"
        );
        fs::remove_dir_all(&dir).unwrap();
    }

    #[test]
    fn backup_then_restore_round_trips_rt_matrix() {
        let dir = temp_project("roundtrip");
        fs::write(dir.join("RT_matrix.csv"), "original").unwrap();

        let name = "RT_matrix_2026-07-09_14-30-45.csv".to_string();
        let written = backup_rtmatrix(dir.to_string_lossy().into_owned(), name.clone()).unwrap();
        assert_eq!(written.as_deref(), Some(name.as_str()));
        assert!(backup_directory(&dir).join(&name).is_file());

        // the working copy changes, then a restore brings the snapshot back
        fs::write(dir.join("RT_matrix.csv"), "edited").unwrap();
        restore_rtmatrix_backup(dir.to_string_lossy().into_owned(), name).unwrap();
        assert_eq!(
            fs::read_to_string(dir.join("RT_matrix.csv")).unwrap(),
            "original"
        );
        fs::remove_dir_all(&dir).unwrap();
    }

    #[test]
    fn backup_is_a_no_op_without_an_rt_matrix() {
        let dir = temp_project("missing");
        let written = backup_rtmatrix(
            dir.to_string_lossy().into_owned(),
            "RT_matrix_2026-01-01_00-00-00.csv".to_string(),
        )
        .unwrap();
        assert_eq!(written, None);
        fs::remove_dir_all(&dir).unwrap();
    }

    #[test]
    fn backup_name_rejects_path_traversal() {
        assert!(safe_backup_name("../evil.csv").is_err());
        assert!(safe_backup_name("a/b.csv").is_err());
        assert!(safe_backup_name("RT_matrix_2026-01-01_00-00-00.csv").is_ok());
    }

    #[test]
    fn worker_name_uses_the_platform_extension() {
        if cfg!(windows) {
            assert_eq!(worker_name("MRMhub-integrator"), "MRMhub-integrator.exe");
        } else {
            assert_eq!(worker_name("MRMhub-integrator"), "MRMhub-integrator");
        }
    }

    #[test]
    fn find_worker_ignores_the_other_platforms_binary() {
        let dir = temp_project("worker_platform");
        // the build for the other OS must never be selected (running it fails
        // with exit code 126)
        let foreign = if cfg!(windows) {
            "MRMhub_macOS"
        } else {
            "MRMhub-integrator-optimized.exe"
        };
        fs::write(dir.join(foreign), b"").unwrap();
        assert_eq!(find_worker(&dir), None);

        // a worker named for THIS platform is selected
        let native = dir.join(worker_name("MRMhub-integrator"));
        fs::write(&native, b"").unwrap();
        assert_eq!(find_worker(&dir), Some(native));
        fs::remove_dir_all(&dir).unwrap();
    }

    #[test]
    fn deletes_timestamped_backup_but_keeps_original() {
        let dir = temp_project("delete_backup");
        let directory = backup_directory(&dir);
        fs::create_dir_all(&directory).unwrap();
        let backup = "RT_matrix_2026-07-10_09-00-00.csv";
        fs::write(directory.join(backup), "backup").unwrap();
        fs::write(directory.join(ORIGINAL_BACKUP), "original").unwrap();

        delete_rtmatrix_backup_file(&dir, backup).unwrap();
        assert!(!directory.join(backup).exists());
        assert!(delete_rtmatrix_backup_file(&dir, ORIGINAL_BACKUP).is_err());
        assert!(directory.join(ORIGINAL_BACKUP).is_file());
        fs::remove_dir_all(&dir).unwrap();
    }

    #[test]
    fn import_labels_increment_from_existing_imports() {
        let mut labels = HashMap::new();
        labels.insert(
            "RT_matrix_2026-07-10_09-00-00.csv".to_string(),
            "import1".to_string(),
        );
        labels.insert(
            "RT_matrix_2026-07-10_10-00-00.csv".to_string(),
            "manual baseline".to_string(),
        );
        labels.insert(
            "RT_matrix_2026-07-10_11-00-00.csv".to_string(),
            "import3".to_string(),
        );
        assert_eq!(next_import_label(&labels), "import4");
    }

    #[test]
    fn original_is_captured_once_and_refreshed_by_detection() {
        let dir = temp_project("original");
        fs::write(dir.join("RT_matrix.csv"), "detected").unwrap();

        // first sight captures the current file as the Original...
        ensure_original(&dir).unwrap();
        let original = backup_directory(&dir).join(ORIGINAL_BACKUP);
        assert_eq!(fs::read_to_string(&original).unwrap(), "detected");

        // ...and later edits do NOT overwrite that captured Original
        fs::write(dir.join("RT_matrix.csv"), "edited").unwrap();
        ensure_original(&dir).unwrap();
        assert_eq!(fs::read_to_string(&original).unwrap(), "detected");

        // a fresh Step 2 detection deliberately refreshes it
        fs::write(dir.join("RT_matrix.csv"), "re-detected").unwrap();
        capture_original(&dir).unwrap();
        assert_eq!(fs::read_to_string(&original).unwrap(), "re-detected");
        fs::remove_dir_all(&dir).unwrap();
    }

    #[test]
    fn original_is_first_and_timestamped_backups_are_oldest_first() {
        let backups = order_backups(vec![
            "RT_matrix_2026-07-09_14-30-45.csv".to_string(),
            ORIGINAL_BACKUP.to_string(),
            "RT_matrix_2026-07-10_09-00-00.csv".to_string(),
        ]);
        assert_eq!(backups[0], ORIGINAL_BACKUP);
        assert_eq!(backups[1], "RT_matrix_2026-07-09_14-30-45.csv");
        assert_eq!(backups[2], "RT_matrix_2026-07-10_09-00-00.csv");
    }

    #[test]
    fn backup_directory_is_directly_inside_the_dataset() {
        let dir = temp_project("direct_backup_folder");
        assert_eq!(backup_directory(&dir), dir.join(BACKUP_DIR));
        fs::remove_dir_all(&dir).unwrap();
    }

    #[test]
    fn nested_layout_is_flattened_without_losing_backups() {
        let dir = temp_project("flatten_nested");
        let root = dir.join(BACKUP_DIR);
        let nested = previous_nested_backup_directory(&dir);
        fs::create_dir_all(&nested).unwrap();
        let first = "RT_matrix_2026-08-01_10-00-00.csv";
        fs::write(nested.join(first), "nested backup").unwrap();
        fs::write(nested.join(ORIGINAL_BACKUP), "nested original").unwrap();

        assert_eq!(flatten_previous_nested_backups(&dir).unwrap(), 2);
        assert_eq!(
            fs::read_to_string(root.join(first)).unwrap(),
            "nested backup"
        );
        assert_eq!(
            fs::read_to_string(root.join(ORIGINAL_BACKUP)).unwrap(),
            "nested original"
        );
        assert!(!nested.exists());
        assert_eq!(flatten_previous_nested_backups(&dir).unwrap(), 0);
        fs::remove_dir_all(&dir).unwrap();
    }

    #[test]
    fn flattening_preserves_different_same_named_backups() {
        let dir = temp_project("flatten_collision");
        let root = dir.join(BACKUP_DIR);
        let nested = previous_nested_backup_directory(&dir);
        fs::create_dir_all(&nested).unwrap();
        let name = "RT_matrix_2026-08-01_10-00-00.csv";
        fs::write(root.join(name), "direct backup").unwrap();
        fs::write(nested.join(name), "nested backup").unwrap();

        assert_eq!(flatten_previous_nested_backups(&dir).unwrap(), 1);
        assert_eq!(
            fs::read_to_string(root.join(name)).unwrap(),
            "direct backup"
        );
        assert_eq!(
            fs::read_to_string(root.join("RT_matrix_2026-08-01_10-00-00_nested_1.csv")).unwrap(),
            "nested backup"
        );
        fs::remove_dir_all(&dir).unwrap();
    }

    #[test]
    fn delete_all_backups_restores_and_preserves_original() {
        let dir = temp_project("delete_all");
        let scoped = backup_directory(&dir);
        fs::create_dir_all(&scoped).unwrap();
        fs::write(scoped.join(ORIGINAL_BACKUP), "original").unwrap();
        fs::write(scoped.join("RT_matrix_1.csv"), "one").unwrap();
        fs::write(scoped.join("RT_matrix_2.csv"), "two").unwrap();
        fs::write(dir.join("RT_matrix.csv"), "current edits").unwrap();

        assert_eq!(
            restore_original_and_delete_all_rtmatrix_backups(&dir).unwrap(),
            2
        );
        assert_eq!(
            fs::read_to_string(dir.join("RT_matrix.csv")).unwrap(),
            "original"
        );
        assert!(scoped.join(ORIGINAL_BACKUP).is_file());
        assert!(!scoped.join("RT_matrix_1.csv").exists());
        assert!(!scoped.join("RT_matrix_2.csv").exists());
        fs::remove_dir_all(&dir).unwrap();
    }

    #[test]
    fn override_replaces_selected_backup_but_rejects_original() {
        let dir = temp_project("override");
        let scoped = backup_directory(&dir);
        fs::create_dir_all(&scoped).unwrap();
        let name = "RT_matrix_2026-08-01_10-00-00.csv";
        fs::write(dir.join("RT_matrix.csv"), "edited").unwrap();
        fs::write(scoped.join(name), "before").unwrap();
        fs::write(scoped.join(ORIGINAL_BACKUP), "original").unwrap();

        overwrite_rtmatrix_backup(dir.to_string_lossy().into_owned(), name.to_string()).unwrap();
        assert_eq!(fs::read_to_string(scoped.join(name)).unwrap(), "edited");
        assert!(
            overwrite_rtmatrix_backup(
                dir.to_string_lossy().into_owned(),
                ORIGINAL_BACKUP.to_string()
            )
            .is_err()
        );
        assert_eq!(
            fs::read_to_string(scoped.join(ORIGINAL_BACKUP)).unwrap(),
            "original"
        );
        fs::remove_dir_all(&dir).unwrap();
    }
}
