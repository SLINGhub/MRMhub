//! Batched, cancellable selection loading with file-version validation.
use super::{
    data_file, invalid_data, read_qc_checked, stream_reference, stream_transition, AppState,
    FileStamp, Pd, QcStat,
};
use std::collections::{HashMap, HashSet, VecDeque};
use std::fs::{self, File};
use std::io::{self, BufReader};
use std::path::Path;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;

type CommandResult<T> = Result<T, String>;
type QcGroups = Vec<(String, Vec<QcStat>)>;
const BATCH_SIZE: usize = 16;
const CANCEL_HISTORY: usize = 256;

#[derive(Default)]
pub(super) struct RequestRegistry {
    active: HashMap<String, Arc<AtomicBool>>,
    cancelled: HashSet<String>,
    cancel_order: VecDeque<String>,
}

impl AppState {
    fn register(&self, id: &str) -> io::Result<RequestGuard> {
        validate_request_id(id)?;
        let mut requests = self.requests.lock().map_err(|_| state_error())?;
        if requests.cancelled.contains(id) {
            return Err(cancelled());
        }
        if requests.active.contains_key(id) {
            return Err(invalid_data("requestId is already active"));
        }
        let flag = Arc::new(AtomicBool::new(false));
        requests.active.insert(id.to_owned(), Arc::clone(&flag));
        Ok(RequestGuard {
            state: self.clone(),
            id: id.to_owned(),
            flag,
        })
    }

    fn cancel(&self, id: &str) -> io::Result<()> {
        validate_request_id(id)?;
        let mut requests = self.requests.lock().map_err(|_| state_error())?;
        if let Some(flag) = requests.active.get(id) {
            flag.store(true, Ordering::Release);
        }
        // A UI cancellation can arrive before its queued load command.
        if requests.cancelled.insert(id.to_owned()) {
            requests.cancel_order.push_back(id.to_owned());
        }
        while requests.cancel_order.len() > CANCEL_HISTORY {
            if let Some(old) = requests.cancel_order.pop_front() {
                requests.cancelled.remove(&old);
            }
        }
        Ok(())
    }
}

struct RequestGuard {
    state: AppState,
    id: String,
    flag: Arc<AtomicBool>,
}

impl Drop for RequestGuard {
    fn drop(&mut self) {
        if let Ok(mut requests) = self.state.requests.lock() {
            if requests
                .active
                .get(&self.id)
                .is_some_and(|flag| Arc::ptr_eq(flag, &self.flag))
            {
                requests.active.remove(&self.id);
            }
        }
    }
}

fn state_error() -> io::Error {
    io::Error::other("The data state is unavailable. Restart the app.")
}

fn cancelled() -> io::Error {
    io::Error::new(io::ErrorKind::Interrupted, "Selection load cancelled")
}

fn check_cancel(flag: &AtomicBool) -> io::Result<()> {
    if flag.load(Ordering::Acquire) {
        Err(cancelled())
    } else {
        Ok(())
    }
}

fn validate_request_id(id: &str) -> io::Result<()> {
    if id.is_empty() || id.len() > 128 {
        return Err(invalid_data("requestId must contain 1–128 bytes"));
    }
    Ok(())
}

async fn run_file_job<T: Send + 'static>(
    command: &'static str,
    job: impl FnOnce() -> io::Result<T> + Send + 'static,
) -> CommandResult<T> {
    tauri::async_runtime::spawn_blocking(job)
        .await
        .map_err(|error| format!("{command}: worker failed: {error}"))?
        .map_err(|error| format!("{command}: {error}"))
}

#[derive(Debug, serde::Serialize)]
#[serde(rename_all = "camelCase")]
pub(super) struct Catalog {
    references: Vec<String>,
    trans_csv: String,
    mzml_tsv: String,
    version: String,
}

#[derive(Debug, serde::Serialize)]
#[serde(tag = "type", rename_all = "snake_case")]
pub(super) enum SelectionEvent {
    Qc {
        #[serde(rename = "requestId")]
        request_id: String,
        groups: QcGroups,
    },
    Traces {
        #[serde(rename = "requestId")]
        request_id: String,
        start: usize,
        traces: Vec<Pd>,
    },
    Complete {
        #[serde(rename = "requestId")]
        request_id: String,
        version: String,
        count: usize,
    },
}

#[derive(Debug)]
enum Selection {
    Transition(String),
    Reference(String),
}

impl Selection {
    fn new(kind: &str, key: &str) -> io::Result<Self> {
        if key.contains('\0') {
            return Err(invalid_data("Invalid selection file name"));
        }
        data_file(Path::new(""), "", key).map_err(invalid_data)?;
        match kind {
            "transition" | "t" => Ok(Self::Transition(key.to_owned())),
            "reference" | "ref" | "r" if key.starts_with("se_") => {
                Ok(Self::Reference(key.to_owned()))
            }
            "reference" | "ref" | "r" => Err(invalid_data("Reference name must start with se_")),
            _ => Err(invalid_data(format!("Unknown selection kind: {kind}"))),
        }
    }
}

fn reference_names(root: &Path) -> io::Result<Vec<String>> {
    let mut names = Vec::new();
    for entry in fs::read_dir(root)? {
        let entry = entry?;
        if entry.file_type()?.is_file() {
            if let Some(name) = entry
                .file_name()
                .to_str()
                .filter(|name| name.starts_with("se_"))
            {
                names.push(name.to_owned());
            }
        }
    }
    names.sort_unstable();
    Ok(names)
}

fn file_stamp(path: &Path) -> io::Result<Option<FileStamp>> {
    match FileStamp::read(path) {
        Ok(stamp) => Ok(Some(stamp)),
        Err(error) if error.kind() == io::ErrorKind::NotFound => Ok(None),
        Err(error) => Err(io::Error::new(
            error.kind(),
            format!("{}: {error}", path.display()),
        )),
    }
}

fn required_stamp(path: &Path) -> io::Result<FileStamp> {
    file_stamp(path)?.ok_or_else(|| {
        io::Error::new(
            io::ErrorKind::NotFound,
            format!("{} is missing", path.display()),
        )
    })
}

#[derive(Debug, PartialEq, Eq, serde::Serialize)]
struct SelectionSnapshot(Vec<(String, Option<FileStamp>)>);

impl SelectionSnapshot {
    fn version(&self) -> io::Result<String> {
        serde_json::to_string(self).map_err(io::Error::other)
    }
}

#[derive(Debug, PartialEq, Eq, serde::Serialize)]
struct CatalogSnapshot {
    trans_csv: FileStamp,
    mzml_tsv: FileStamp,
    references: Vec<String>,
}

impl CatalogSnapshot {
    fn version(&self) -> io::Result<String> {
        serde_json::to_string(self).map_err(io::Error::other)
    }
}

fn catalog_snapshot(root: &Path) -> io::Result<CatalogSnapshot> {
    Ok(CatalogSnapshot {
        trans_csv: required_stamp(&root.join("trans_R.csv"))?,
        mzml_tsv: required_stamp(&root.join("mzML_list.txt"))?,
        references: reference_names(root)?,
    })
}

fn get_catalog_blocking(root: &Path) -> io::Result<Catalog> {
    let before = catalog_snapshot(root)?;
    let trans_csv = fs::read_to_string(root.join("trans_R.csv"))?;
    let mzml_tsv = fs::read_to_string(root.join("mzML_list.txt"))?;
    if before != catalog_snapshot(root)? {
        return Err(invalid_data("Catalog changed; refresh the data"));
    }
    let version = before.version()?;
    Ok(Catalog {
        references: before.references,
        trans_csv,
        mzml_tsv,
        version,
    })
}

fn validate_catalog_version(root: &Path, expected: Option<&str>) -> io::Result<()> {
    if let Some(expected) = expected {
        if catalog_snapshot(root)?.version()? != expected {
            return Err(invalid_data("Catalog changed; refresh the data"));
        }
    }
    Ok(())
}

fn selection_snapshot(root: &Path, selection: &Selection) -> io::Result<SelectionSnapshot> {
    let mut files = Vec::new();
    match selection {
        Selection::Transition(key) => {
            for name in [format!("te_{key}"), format!("tp_{key}")] {
                files.push((name.clone(), Some(required_stamp(&root.join(name))?)));
            }
            for name in ["long.bin", "trans_list.bin"] {
                files.push((name.to_owned(), file_stamp(&root.join(name))?));
            }
        }
        Selection::Reference(key) => {
            files.push((key.clone(), Some(required_stamp(&root.join(key))?)));
        }
    }
    for name in ["trans_R.csv", "mzML_list.txt"] {
        files.push((name.to_owned(), file_stamp(&root.join(name))?));
    }
    Ok(SelectionSnapshot(files))
}

fn open_reader(path: &Path) -> io::Result<BufReader<File>> {
    File::open(path)
        .map(BufReader::new)
        .map_err(|error| io::Error::new(error.kind(), format!("{}: {error}", path.display())))
}

fn read_groups(state: &AppState, key: &str, flag: &AtomicBool) -> io::Result<QcGroups> {
    check_cancel(flag)?;
    let mut data = state.data.lock().map_err(|_| state_error())?;
    check_cancel(flag)?;
    let path = data.directory.join("long.bin");
    let Some(long_stamp) = file_stamp(&path)? else {
        return Ok(Vec::new());
    };
    let tp_stamp = required_stamp(&data.directory.join(format!("tp_{key}")))?;
    if tp_stamp.modified >= long_stamp.modified {
        return Ok(Vec::new());
    }
    let (transition, index) = data.qc_source_checked(key, &mut || check_cancel(flag))?;
    drop(data);
    check_cancel(flag)?;
    read_qc_checked(&mut open_reader(&path)?, &index, &transition, &mut || {
        check_cancel(flag)
    })
}

fn load_selection_blocking(
    state: &AppState,
    selection: &Selection,
    request_id: &str,
    catalog_version: Option<&str>,
    flag: &AtomicBool,
    mut send: impl FnMut(SelectionEvent) -> io::Result<()>,
) -> io::Result<()> {
    check_cancel(flag)?;
    let root = state.directory().map_err(io::Error::other)?;
    validate_catalog_version(&root, catalog_version)?;
    let before = selection_snapshot(&root, selection)?;
    let groups = match selection {
        Selection::Transition(key) => read_groups(state, key, flag)?,
        Selection::Reference(_) => Vec::new(),
    };
    check_cancel(flag)?;
    send(SelectionEvent::Qc {
        request_id: request_id.to_owned(),
        groups,
    })?;
    let mut batch = Vec::with_capacity(BATCH_SIZE);
    let mut count = 0;
    let mut start = 0;
    let mut emit = |record| -> CommandResult<()> {
        check_cancel(flag).map_err(|error| error.to_string())?;
        batch.push(record);
        count += 1;
        if batch.len() == BATCH_SIZE {
            check_cancel(flag).map_err(|error| error.to_string())?;
            send(SelectionEvent::Traces {
                request_id: request_id.to_owned(),
                start,
                traces: std::mem::replace(&mut batch, Vec::with_capacity(BATCH_SIZE)),
            })
            .map_err(|error| error.to_string())?;
            start = count;
        }
        Ok(())
    };
    check_cancel(flag)?;
    match selection {
        Selection::Transition(key) => {
            stream_transition(
                &mut open_reader(&root.join(format!("te_{key}")))?,
                &mut open_reader(&root.join(format!("tp_{key}")))?,
                &mut emit,
            )
            .map_err(io::Error::other)?;
        }
        Selection::Reference(key) => {
            stream_reference(&mut open_reader(&root.join(key))?, &mut emit)
                .map_err(io::Error::other)?;
        }
    }
    check_cancel(flag)?;
    if !batch.is_empty() {
        send(SelectionEvent::Traces {
            request_id: request_id.to_owned(),
            start,
            traces: batch,
        })?;
    }
    // Only a stable complete event allows the frontend to reuse a selection.
    validate_catalog_version(&root, catalog_version)?;
    if before != selection_snapshot(&root, selection)? {
        return Err(invalid_data(
            "Selection files changed while loading; reload the selection",
        ));
    }
    check_cancel(flag)?;
    send(SelectionEvent::Complete {
        request_id: request_id.to_owned(),
        version: before.version()?,
        count,
    })
}

#[tauri::command]
pub(super) async fn get_catalog(state: tauri::State<'_, AppState>) -> CommandResult<Catalog> {
    let root = state.directory()?;
    run_file_job("get_catalog", move || get_catalog_blocking(&root)).await
}

#[tauri::command]
pub(super) async fn selection_version(
    kind: String,
    key: String,
    state: tauri::State<'_, AppState>,
) -> CommandResult<String> {
    let root = state.directory()?;
    run_file_job("selection_version", move || {
        selection_snapshot(&root, &Selection::new(&kind, &key)?)?.version()
    })
    .await
}

#[tauri::command]
pub(super) async fn cancel_load(
    request_id: String,
    state: tauri::State<'_, AppState>,
) -> CommandResult<()> {
    state
        .cancel(&request_id)
        .map_err(|error| format!("cancel_load: {error}"))
}

#[tauri::command]
pub(super) async fn load_selection(
    kind: String,
    key: String,
    request_id: String,
    catalog_version: Option<String>,
    on_event: tauri::ipc::Channel<SelectionEvent>,
    state: tauri::State<'_, AppState>,
) -> CommandResult<()> {
    let selection = Selection::new(&kind, &key).map_err(|error| error.to_string())?;
    let state = state.inner().clone();
    let guard = state
        .register(&request_id)
        .map_err(|error| error.to_string())?;
    run_file_job("load_selection", move || {
        let result = load_selection_blocking(
            &state,
            &selection,
            &request_id,
            catalog_version.as_deref(),
            &guard.flag,
            |event| {
                on_event
                    .send(event)
                    .map_err(|error| io::Error::new(io::ErrorKind::BrokenPipe, error.to_string()))
            },
        );
        drop(guard);
        result
    })
    .await
}

#[cfg(test)]
mod tests;
