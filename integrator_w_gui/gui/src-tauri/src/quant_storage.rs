//! Read file metadata and small checkpoint manifests, never dataset/output
//! contents. No R startup or link traversal; shared hard links count only once.
use serde::Serialize;
use std::{
    collections::{HashMap, HashSet},
    fs,
    path::{Path, PathBuf},
};

#[derive(Serialize, Default)]
#[serde(rename_all = "camelCase")]
pub struct StorageSize {
    folder: PathBuf,
    total_bytes: u64,
    reclaimable_bytes: u64,
    trash_bytes: u64,
    files: u64,
    skipped_entries: u64,
}

#[derive(Eq, PartialEq, Hash)]
enum FileKey {
    #[cfg(unix)]
    Inode(u64, u64),
    #[cfg(windows)]
    Windows(u32, u64),
}
struct FileSize {
    bytes: u64,
    links: u64,
    cleanup_links: u64,
    in_trash: bool,
}

#[cfg(unix)]
fn identity(_path: &Path, metadata: &fs::Metadata) -> Result<(FileKey, u64), String> {
    use std::os::unix::fs::MetadataExt;
    Ok((
        FileKey::Inode(metadata.dev(), metadata.ino()),
        metadata.nlink(),
    ))
}
#[cfg(windows)]
fn identity(path: &Path, _metadata: &fs::Metadata) -> Result<(FileKey, u64), String> {
    use std::os::windows::{fs::OpenOptionsExt, io::AsRawHandle};
    use windows_sys::Win32::Storage::FileSystem::*;
    let file = fs::OpenOptions::new()
        .read(true)
        .custom_flags(FILE_FLAG_OPEN_REPARSE_POINT)
        .open(path)
        .map_err(|e| e.to_string())?;
    let mut info = std::mem::MaybeUninit::<BY_HANDLE_FILE_INFORMATION>::uninit();
    if unsafe { GetFileInformationByHandle(file.as_raw_handle(), info.as_mut_ptr()) } == 0 {
        return Err(std::io::Error::last_os_error().to_string());
    }
    let info = unsafe { info.assume_init() };
    if info.dwFileAttributes & FILE_ATTRIBUTE_REPARSE_POINT != 0 {
        return Err("Linked file skipped.".into());
    }
    Ok((
        FileKey::Windows(
            info.dwVolumeSerialNumber,
            (u64::from(info.nFileIndexHigh) << 32) | u64::from(info.nFileIndexLow),
        ),
        u64::from(info.nNumberOfLinks),
    ))
}

fn linked(metadata: &fs::Metadata) -> bool {
    if metadata.file_type().is_symlink() {
        return true;
    }
    #[cfg(windows)]
    {
        use std::os::windows::fs::MetadataExt;
        if metadata.file_attributes()
            & windows_sys::Win32::Storage::FileSystem::FILE_ATTRIBUTE_REPARSE_POINT
            != 0
        {
            return true;
        }
    }
    false
}

pub fn storage_at(root: &Path) -> Result<StorageSize, String> {
    let mut result = StorageSize {
        folder: root.to_path_buf(),
        ..Default::default()
    };
    let metadata = match fs::symlink_metadata(root) {
        Ok(meta) => meta,
        Err(error) if error.kind() == std::io::ErrorKind::NotFound => return Ok(result),
        Err(error) => return Err(error.to_string()),
    };
    if linked(&metadata) || !metadata.is_dir() {
        return Err("Folder sizing does not follow linked QUANT folders.".into());
    }
    let canonical = root.canonicalize().map_err(|e| e.to_string())?;
    let root = canonical.as_path();
    result.folder = canonical.clone();
    // Exactly the same dry-run plan as cleanup; don't classify retained sessions
    // or saved graphs/exports as reclaimable merely because they're old.
    let snapshots: HashSet<_> = super::quant::snapshot_cleanup_plan(root, true)?
        .into_iter()
        .flat_map(|(job, names)| names.into_iter().map(move |name| job.join(name)))
        .collect();
    let trash = root.join(".trash");
    let mut stack = vec![root.to_path_buf()];
    let mut files = HashMap::<FileKey, FileSize>::new();
    while let Some(directory) = stack.pop() {
        let entries = match fs::read_dir(&directory) {
            Ok(entries) => entries,
            Err(_) => {
                result.skipped_entries += 1;
                continue;
            }
        };
        for entry in entries {
            let entry = match entry {
                Ok(entry) => entry,
                Err(_) => {
                    result.skipped_entries += 1;
                    continue;
                }
            };
            let path = entry.path();
            let meta = match fs::symlink_metadata(&path) {
                Ok(meta) => meta,
                Err(_) => {
                    result.skipped_entries += 1;
                    continue;
                }
            };
            if linked(&meta) {
                result.skipped_entries += 1;
                continue;
            }
            if meta.is_dir() {
                stack.push(path);
                continue;
            }
            if !meta.is_file() {
                result.skipped_entries += 1;
                continue;
            }
            let (key, links) = match identity(&path, &meta) {
                Ok(key) => key,
                Err(_) => {
                    result.skipped_entries += 1;
                    continue;
                }
            };
            let in_trash = path.starts_with(&trash);
            let size = files.entry(key).or_insert(FileSize {
                bytes: meta.len(),
                links,
                cleanup_links: 0,
                in_trash: false,
            });
            size.in_trash |= in_trash;
            if in_trash || snapshots.contains(&path) {
                size.cleanup_links += 1;
            }
        }
    }
    result.files = files.len() as u64;
    for size in files.values() {
        result.total_bytes = result.total_bytes.saturating_add(size.bytes);
        if size.in_trash {
            result.trash_bytes = result.trash_bytes.saturating_add(size.bytes);
        }
        // Removing one hard link doesn't reclaim its data while a live session
        // (or a file outside QUANT) still references the same underlying file.
        if size.links > 0 && size.cleanup_links >= size.links {
            result.reclaimable_bytes = result.reclaimable_bytes.saturating_add(size.bytes);
        }
    }
    Ok(result)
}

#[tauri::command]
pub async fn quant_storage(project: String) -> Result<StorageSize, String> {
    tauri::async_runtime::spawn_blocking(move || storage_at(&super::quant::dataset_root(&project)?))
        .await
        .map_err(|e| e.to_string())?
}

#[cfg(test)]
mod tests {
    use super::*;
    struct Fixture(PathBuf);
    impl Fixture {
        fn new() -> Self {
            let root = std::env::temp_dir().join(format!(
                "quant-size-{}-{}",
                std::process::id(),
                std::time::SystemTime::now()
                    .duration_since(std::time::UNIX_EPOCH)
                    .unwrap()
                    .as_nanos()
            ));
            fs::create_dir(&root).unwrap();
            Self(root)
        }
        fn checkpoint(&self, id: &str) -> PathBuf {
            let job = self.0.join(id);
            fs::create_dir(&job).unwrap();
            fs::write(
                job.join("completed.json"),
                serde_json::to_vec(&serde_json::json!({"id":id,"action":"run"})).unwrap(),
            )
            .unwrap();
            job
        }
    }
    impl Drop for Fixture {
        fn drop(&mut self) {
            let _ = fs::remove_dir_all(&self.0);
        }
    }
    #[test]
    fn sizes_missing_folder_without_creating_it() {
        let f = Fixture::new();
        let missing = f.0.join("QUANT");
        let size = storage_at(&missing).unwrap();
        assert_eq!(size.total_bytes, 0);
        assert!(!missing.exists());
    }
    #[test]
    fn cleanup_estimate_retains_latest_session_and_saved_outputs() {
        let f = Fixture::new();
        let old = f.checkpoint("q-1");
        let latest = f.checkpoint("q-2");
        fs::write(old.join("experiment.rds"), [0; 32]).unwrap();
        fs::write(old.join("plot.png"), [0; 64]).unwrap();
        fs::write(latest.join("experiment.rds"), [0; 128]).unwrap();
        fs::create_dir(f.0.join(".trash")).unwrap();
        fs::write(f.0.join(".trash/old.png"), [0; 16]).unwrap();
        let size = storage_at(&f.0).unwrap();
        assert_eq!(size.reclaimable_bytes, 48);
        assert_eq!(size.trash_bytes, 16);
        assert!(size.total_bytes >= 240);
        assert_eq!(size.skipped_entries, 0);
    }
    #[test]
    fn shared_snapshots_count_once_and_do_not_claim_reclaimable_space() {
        let f = Fixture::new();
        let old = f.checkpoint("q-1");
        let latest = f.checkpoint("q-2");
        fs::write(latest.join("experiment.rds"), [0; 128]).unwrap();
        fs::hard_link(latest.join("experiment.rds"), old.join("experiment.rds")).unwrap();
        let size = storage_at(&f.0).unwrap();
        assert_eq!(size.reclaimable_bytes, 0);
        assert_eq!(size.files, 3);
        fs::remove_file(old.join("experiment.rds")).unwrap();
        assert_eq!(size.total_bytes, storage_at(&f.0).unwrap().total_bytes);
    }
    #[test]
    fn trash_shared_with_a_retained_file_cannot_reclaim_its_bytes() {
        let f = Fixture::new();
        let latest = f.checkpoint("q-1");
        fs::write(latest.join("experiment.rds"), [0; 128]).unwrap();
        fs::create_dir(f.0.join(".trash")).unwrap();
        fs::hard_link(latest.join("experiment.rds"), f.0.join(".trash/shared.rds")).unwrap();
        let size = storage_at(&f.0).unwrap();
        assert_eq!(size.trash_bytes, 128);
        assert_eq!(size.reclaimable_bytes, 0);
    }
    #[cfg(unix)]
    #[test]
    fn never_follows_links_outside_the_folder_or_counts_dataset_input() {
        let f = Fixture::new();
        let root = f.0.join("QUANT");
        fs::create_dir(&root).unwrap();
        fs::write(f.0.join("input.csv"), [0; 4096]).unwrap();
        std::os::unix::fs::symlink(&f.0, root.join("outside")).unwrap();
        std::os::unix::fs::symlink(f.0.join("input.csv"), root.join("linked.csv")).unwrap();
        let size = storage_at(&root).unwrap();
        assert_eq!(size.total_bytes, 0);
        assert_eq!(size.skipped_entries, 2);
    }
    #[cfg(unix)]
    #[test]
    fn linked_checkpoint_manifest_is_not_read_or_used_for_cleanup() {
        let f = Fixture::new();
        let root = f.0.join("QUANT");
        fs::create_dir(&root).unwrap();
        let old = root.join("q-1");
        let latest = root.join("q-2");
        fs::create_dir(&old).unwrap();
        fs::create_dir(&latest).unwrap();
        fs::write(f.0.join("outside.json"), r#"{"id":"q-1","action":"run"}"#).unwrap();
        std::os::unix::fs::symlink(f.0.join("outside.json"), old.join("completed.json")).unwrap();
        fs::write(old.join("experiment.rds"), [0; 128]).unwrap();
        fs::write(
            latest.join("completed.json"),
            r#"{"id":"q-2","action":"run"}"#,
        )
        .unwrap();
        fs::write(latest.join("experiment.rds"), [0; 128]).unwrap();
        let size = storage_at(&root).unwrap();
        assert_eq!(size.reclaimable_bytes, 0);
        assert_eq!(size.skipped_entries, 1);
    }
}
