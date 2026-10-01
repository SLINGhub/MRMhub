use std::collections::HashMap;
use std::fs::{self, File};
use std::io::{self, BufRead, BufReader, Read, Seek, SeekFrom};
use std::path::{Component, Path, PathBuf};
use std::sync::{Arc, Mutex};
use std::time::SystemTime;
use tauri::Manager;

mod selection;

const MAX_NAME_BYTES: u64 = 1024 * 1024;

type CommandResult<T> = Result<T, String>;

#[derive(Clone)]
struct AppState {
    data: Arc<Mutex<DataState>>,
    requests: Arc<Mutex<selection::RequestRegistry>>,
}

struct DataState {
    directory: PathBuf,
    transitions: Option<Cached<HashMap<String, ValidT>>>,
    long_index: Option<Cached<Arc<LongIndex>>>,
}

impl DataState {
    fn new(directory: PathBuf) -> Self {
        Self {
            directory,
            transitions: None,
            long_index: None,
        }
    }

    #[cfg(test)]
    fn qc_source(&mut self, cqq: &str) -> io::Result<(ValidT, Arc<LongIndex>)> {
        self.qc_source_checked(cqq, &mut || Ok(()))
    }

    fn qc_source_checked(
        &mut self,
        cqq: &str,
        check: &mut impl FnMut() -> io::Result<()>,
    ) -> io::Result<(ValidT, Arc<LongIndex>)> {
        check()?;
        let transitions_path = self.directory.join("trans_list.bin");
        let transitions_stamp = FileStamp::read(&transitions_path)?;
        if self.transitions.as_ref().map(|cached| &cached.stamp) != Some(&transitions_stamp) {
            let value = parse_transitions_checked(
                &mut BufReader::new(File::open(&transitions_path)?),
                check,
            )?;
            if FileStamp::read(&transitions_path)? != transitions_stamp {
                return Err(invalid_data(
                    "trans_list.bin changed while reading; reload the selection",
                ));
            }
            self.transitions = Some(Cached {
                stamp: transitions_stamp,
                value,
            });
        }
        let transition = self
            .transitions
            .as_ref()
            .and_then(|cached| cached.value.get(cqq))
            .cloned()
            .ok_or_else(|| invalid_data(format!("Transition {cqq} was not found")))?;
        let long_path = self.directory.join("long.bin");
        let long_stamp = FileStamp::read(&long_path)?;
        if self.long_index.as_ref().map(|cached| &cached.stamp) != Some(&long_stamp) {
            let mut file = BufReader::new(File::open(&long_path)?);
            let value = Arc::new(index_long_checked(&mut file, long_stamp.len, check)?);
            if FileStamp::read(&long_path)? != long_stamp {
                return Err(invalid_data(
                    "long.bin changed while indexing; reload the selection",
                ));
            }
            self.long_index = Some(Cached {
                stamp: long_stamp,
                value,
            });
        }
        let index = self
            .long_index
            .as_ref()
            .map(|cached| Arc::clone(&cached.value))
            .ok_or_else(|| invalid_data("QC index is unavailable"))?;
        Ok((transition, index))
    }
}

impl AppState {
    fn new(directory: PathBuf) -> Self {
        Self {
            data: Arc::new(Mutex::new(DataState::new(directory))),
            requests: Arc::new(Mutex::new(selection::RequestRegistry::default())),
        }
    }

    fn directory(&self) -> CommandResult<PathBuf> {
        self.data
            .lock()
            .map(|data| data.directory.clone())
            .map_err(|_| "The data directory is unavailable. Restart the app.".to_string())
    }
}

fn data_dir_for_executable(executable: &Path) -> io::Result<PathBuf> {
    executable
        .parent()
        .map(|directory| directory.join("misc"))
        .ok_or_else(|| {
            io::Error::new(
                io::ErrorKind::NotFound,
                "Cannot locate the executable directory",
            )
        })
}

fn data_file(directory: &Path, prefix: &str, name: &str) -> CommandResult<PathBuf> {
    let mut components = Path::new(name).components();
    if name.is_empty()
        || name.contains(['/', '\\'])
        || !matches!(components.next(), Some(Component::Normal(_)))
        || components.next().is_some()
    {
        return Err("Invalid data file name".into());
    }
    Ok(directory.join(format!("{prefix}{name}")))
}

fn invalid_data(message: impl Into<String>) -> io::Error {
    io::Error::new(io::ErrorKind::InvalidData, message.into())
}

fn unpack_u16(reader: &mut impl Read) -> io::Result<u16> {
    let mut bytes = [0; 2];
    reader.read_exact(&mut bytes)?;
    Ok(u16::from_le_bytes(bytes))
}

fn unpack_u8(reader: &mut impl Read) -> io::Result<u8> {
    let mut bytes = [0];
    reader.read_exact(&mut bytes)?;
    Ok(bytes[0])
}

fn unpack_f32(reader: &mut impl Read) -> io::Result<f32> {
    let mut bytes = [0; 4];
    reader.read_exact(&mut bytes)?;
    Ok(f32::from_le_bytes(bytes))
}

fn unpack_string(reader: &mut impl BufRead) -> io::Result<String> {
    let mut bytes = Vec::new();
    reader
        .take(MAX_NAME_BYTES + 1)
        .read_until(b'\0', &mut bytes)?;
    if bytes.last() != Some(&0) {
        return Err(io::Error::new(
            io::ErrorKind::UnexpectedEof,
            "Unterminated or oversized name in data file",
        ));
    }
    bytes.pop();
    String::from_utf8(bytes).map_err(|error| invalid_data(error.to_string()))
}

fn skip_exact(reader: &mut impl Read, bytes: usize) -> io::Result<()> {
    let copied = io::copy(&mut reader.take(bytes as u64), &mut io::sink())?;
    if copied != bytes as u64 {
        return Err(io::Error::new(
            io::ErrorKind::UnexpectedEof,
            "Truncated data record",
        ));
    }
    Ok(())
}

fn has_record(reader: &mut impl BufRead) -> io::Result<bool> {
    Ok(!reader.fill_buf()?.is_empty())
}

#[derive(Clone, Debug, serde::Serialize)]
struct QcStat {
    rt_apex: f32,
    area: f32,
    rt_int_start: f32,
    rt_int_end: f32,
}

#[derive(Clone, Debug)]
struct ValidT {
    cpd: String,
    iso_name: Vec<String>,
}

#[derive(Clone, Debug, PartialEq, Eq, serde::Serialize)]
struct FileStamp {
    len: u64,
    modified: SystemTime,
    #[cfg(unix)]
    device: u64,
    #[cfg(unix)]
    inode: u64,
    #[cfg(unix)]
    changed: (i64, i64),
    #[cfg(not(unix))]
    created: Option<SystemTime>,
}

impl FileStamp {
    fn read(path: &Path) -> io::Result<Self> {
        let metadata = fs::metadata(path)?;
        if !metadata.is_file() {
            return Err(invalid_data(format!(
                "{} is not a regular file",
                path.display()
            )));
        }
        #[cfg(unix)]
        use std::os::unix::fs::MetadataExt;
        Ok(Self {
            len: metadata.len(),
            modified: metadata.modified()?,
            #[cfg(unix)]
            device: metadata.dev(),
            #[cfg(unix)]
            inode: metadata.ino(),
            #[cfg(unix)]
            changed: (metadata.ctime(), metadata.ctime_nsec()),
            #[cfg(not(unix))]
            created: metadata.created().ok(),
        })
    }
}

struct Cached<T> {
    stamp: FileStamp,
    value: T,
}

#[cfg(test)]
fn parse_transitions(reader: &mut impl BufRead) -> io::Result<HashMap<String, ValidT>> {
    parse_transitions_checked(reader, &mut || Ok(()))
}

fn parse_transitions_checked(
    reader: &mut impl BufRead,
    check: &mut impl FnMut() -> io::Result<()>,
) -> io::Result<HashMap<String, ValidT>> {
    let count = unpack_u16(reader)?;
    let mut transitions = HashMap::with_capacity(usize::from(count));
    for _ in 0..count {
        check()?;
        let cqq = unpack_string(reader)?;
        let cpd = unpack_string(reader)?;
        unpack_string(reader)?;
        skip_exact(reader, 9)?;
        let isotope_count = unpack_u8(reader)?;
        let mut iso_name = Vec::with_capacity(usize::from(isotope_count));
        for _ in 0..isotope_count {
            skip_exact(reader, 4)?;
            iso_name.push(unpack_string(reader)?);
            skip_exact(reader, 8)?;
        }
        let segment_count = usize::from(unpack_u8(reader)?);
        skip_exact(reader, segment_count * 4)?;
        unpack_string(reader)?;
        if transitions
            .insert(cqq.clone(), ValidT { cpd, iso_name })
            .is_some()
        {
            return Err(invalid_data(format!("Duplicate transition {cqq}")));
        }
    }
    Ok(transitions)
}

struct LongIndex {
    samples: u16,
    offsets: HashMap<String, u64>,
}

#[cfg(test)]
fn index_long(reader: &mut (impl BufRead + Seek), file_len: u64) -> io::Result<LongIndex> {
    index_long_checked(reader, file_len, &mut || Ok(()))
}

fn index_long_checked(
    reader: &mut (impl BufRead + Seek),
    file_len: u64,
    check: &mut impl FnMut() -> io::Result<()>,
) -> io::Result<LongIndex> {
    let samples = unpack_u16(reader)?;
    let record_bytes = u64::from(samples) * 16;
    let mut offsets = HashMap::new();
    while has_record(reader)? {
        check()?;
        let name = unpack_string(reader)?;
        let offset = reader.stream_position()?;
        let end = offset
            .checked_add(record_bytes)
            .filter(|end| *end <= file_len)
            .ok_or_else(|| io::Error::new(io::ErrorKind::UnexpectedEof, "Truncated QC record"))?;
        offsets.entry(name).or_insert(offset);
        reader.seek(SeekFrom::Start(end))?;
    }
    Ok(LongIndex { samples, offsets })
}

#[cfg(test)]
fn read_qc(
    reader: &mut (impl Read + Seek),
    index: &LongIndex,
    transition: &ValidT,
) -> io::Result<Vec<(String, Vec<QcStat>)>> {
    read_qc_checked(reader, index, transition, &mut || Ok(()))
}

fn read_qc_checked(
    reader: &mut (impl Read + Seek),
    index: &LongIndex,
    transition: &ValidT,
    check: &mut impl FnMut() -> io::Result<()>,
) -> io::Result<Vec<(String, Vec<QcStat>)>> {
    transition
        .iso_name
        .iter()
        .map(|isotope| {
            check()?;
            let name = if isotope.is_empty() {
                &transition.cpd
            } else {
                isotope
            };
            let mut stats = Vec::new();
            if let Some(offset) = index.offsets.get(name) {
                reader.seek(SeekFrom::Start(*offset))?;
                stats.reserve(usize::from(index.samples));
                for _ in 0..index.samples {
                    check()?;
                    stats.push(QcStat {
                        rt_apex: unpack_f32(reader)?,
                        area: unpack_f32(reader)?,
                        rt_int_start: unpack_f32(reader)?,
                        rt_int_end: unpack_f32(reader)?,
                    });
                }
            }
            Ok((name.clone(), stats))
        })
        .collect()
}

#[derive(Clone, Debug, serde::Serialize)]
struct Pd {
    sh: f32,
    pos_l: Vec<u16>,
    bl: Vec<f32>,
    te: Vec<Point>,
}

#[derive(Clone, Debug, serde::Serialize)]
struct Point {
    x: f32,
    y: f32,
}

fn read_points(reader: &mut impl Read, count: u16) -> io::Result<Vec<Point>> {
    (0..count)
        .map(|_| {
            Ok(Point {
                x: unpack_f32(reader)?,
                y: unpack_f32(reader)?,
            })
        })
        .collect()
}

fn read_integration(reader: &mut impl Read, count: u8) -> io::Result<(Vec<u16>, Vec<f32>)> {
    // Widen before multiplying: valid peak counts can exceed 127.
    let positions = usize::from(count) * 2;
    let pos_l = (0..positions)
        .map(|_| unpack_u16(reader))
        .collect::<io::Result<_>>()?;
    let bl = (0..positions)
        .map(|_| unpack_f32(reader))
        .collect::<io::Result<_>>()?;
    Ok((pos_l, bl))
}

fn stream_transition(
    trace: &mut impl BufRead,
    integration: &mut impl BufRead,
    mut send: impl FnMut(Pd) -> CommandResult<()>,
) -> CommandResult<()> {
    let count = unpack_u8(integration).map_err(|error| error.to_string())?;
    while has_record(trace).map_err(|error| error.to_string())? {
        let pd = (|| -> io::Result<Pd> {
            skip_exact(trace, 5)?;
            let points = unpack_u16(trace)?;
            let sh = unpack_f32(integration)?;
            let (pos_l, bl) = read_integration(integration, count)?;
            Ok(Pd {
                sh,
                pos_l,
                bl,
                te: read_points(trace, points)?,
            })
        })()
        .map_err(|error| format!("Invalid transition data: {error}"))?;
        send(pd)?;
    }
    if has_record(integration).map_err(|error| error.to_string())? {
        return Err("The trace and integration files have different sample counts".into());
    }
    Ok(())
}

#[cfg(test)]
fn read_shifts(reader: &mut impl BufRead) -> io::Result<Vec<f32>> {
    let count = usize::from(unpack_u8(reader)?);
    let mut shifts = Vec::new();
    while has_record(reader)? {
        shifts.push(unpack_f32(reader)?);
        skip_exact(reader, count * 12)?;
    }
    Ok(shifts)
}

fn stream_reference(
    reader: &mut impl BufRead,
    mut send: impl FnMut(Pd) -> CommandResult<()>,
) -> CommandResult<()> {
    while has_record(reader).map_err(|error| error.to_string())? {
        let pd = (|| -> io::Result<Pd> {
            let count = unpack_u16(reader)?;
            let te = read_points(reader, count)?;
            let sh = unpack_f32(reader)?;
            let peak_count = unpack_u8(reader)?;
            let (pos_l, bl) = read_integration(reader, peak_count)?;
            Ok(Pd { te, sh, pos_l, bl })
        })()
        .map_err(|error| format!("Invalid reference data: {error}"))?;
        send(pd)?;
    }
    Ok(())
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .setup(|app| {
            let directory = data_dir_for_executable(&std::env::current_exe()?)?;
            app.manage(AppState::new(directory));
            Ok(())
        })
        .invoke_handler(tauri::generate_handler![
            selection::get_catalog,
            selection::selection_version,
            selection::load_selection,
            selection::cancel_load
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::Cursor;
    use std::sync::atomic::{AtomicU64, Ordering};

    static NEXT_DIRECTORY: AtomicU64 = AtomicU64::new(0);

    struct TestDirectory(PathBuf);

    impl TestDirectory {
        fn new() -> Self {
            let path = std::env::temp_dir().join(format!(
                "mrmhub-viz-test-{}-{}",
                std::process::id(),
                NEXT_DIRECTORY.fetch_add(1, Ordering::Relaxed)
            ));
            fs::create_dir(&path).unwrap();
            Self(path)
        }
    }

    impl Drop for TestDirectory {
        fn drop(&mut self) {
            let _ = fs::remove_dir_all(&self.0);
        }
    }

    fn transition_bytes(records: &[(&str, &str, &[&str])]) -> Vec<u8> {
        let mut bytes = (records.len() as u16).to_le_bytes().to_vec();
        for (cqq, compound, isotopes) in records {
            for name in [*cqq, *compound, "formula"] {
                bytes.extend_from_slice(name.as_bytes());
                bytes.push(0);
            }
            bytes.extend_from_slice(&[0; 9]);
            bytes.push(isotopes.len() as u8);
            for name in *isotopes {
                bytes.extend_from_slice(&[0; 4]);
                bytes.extend_from_slice(name.as_bytes());
                bytes.push(0);
                bytes.extend_from_slice(&[0; 8]);
            }
            bytes.push(0);
            bytes.push(0);
        }
        bytes
    }

    fn long_bytes(records: &[(&str, f32)]) -> Vec<u8> {
        let mut bytes = 1u16.to_le_bytes().to_vec();
        for (name, value) in records {
            bytes.extend_from_slice(name.as_bytes());
            bytes.push(0);
            for stat in [*value, value + 1.0, value + 2.0, value + 3.0] {
                bytes.extend_from_slice(&stat.to_le_bytes());
            }
        }
        bytes
    }

    #[test]
    fn names_require_a_terminator_and_valid_utf8() {
        assert_eq!(
            unpack_string(&mut Cursor::new(b"compound\0")).unwrap(),
            "compound"
        );
        assert!(unpack_string(&mut Cursor::new(b"compound")).is_err());
        assert!(unpack_string(&mut Cursor::new([255, 0])).is_err());
    }

    #[test]
    fn transitions_work_without_sorted_ids_and_reject_truncation() {
        let bytes = transition_bytes(&[("9999", "later", &["heavy"]), ("0000", "earlier", &[""])]);
        let transitions = parse_transitions(&mut Cursor::new(&bytes)).unwrap();
        assert_eq!(transitions["0000"].cpd, "earlier");
        assert_eq!(transitions["9999"].iso_name, ["heavy"]);
        assert!(parse_transitions(&mut Cursor::new(&bytes[..bytes.len() - 1])).is_err());
    }

    #[test]
    fn qc_isotope_lookup_is_independent_of_record_order() {
        let bytes = long_bytes(&[("heavy", 20.0), ("compound", 10.0)]);
        let mut reader = Cursor::new(&bytes);
        let index = index_long(&mut reader, bytes.len() as u64).unwrap();
        let transition = ValidT {
            cpd: "compound".into(),
            iso_name: vec!["".into(), "heavy".into(), "missing".into(), "heavy".into()],
        };
        let values = read_qc(&mut reader, &index, &transition).unwrap();
        assert_eq!(values[0].0, "compound");
        assert_eq!(values[0].1[0].rt_apex, 10.0);
        assert_eq!(values[1].1[0].rt_apex, 20.0);
        assert!(values[2].1.is_empty());
        assert_eq!(values[3].1[0].area, 21.0);
        assert!(index_long(
            &mut Cursor::new(&bytes[..bytes.len() - 1]),
            (bytes.len() - 1) as u64
        )
        .is_err());
    }

    #[test]
    fn caches_are_reused_and_invalidated_when_files_change() {
        let directory = TestDirectory::new();
        let transitions_path = directory.0.join("trans_list.bin");
        let long_path = directory.0.join("long.bin");
        fs::write(
            &transitions_path,
            transition_bytes(&[("0000", "compound", &[""])]),
        )
        .unwrap();
        fs::write(&long_path, long_bytes(&[("compound", 1.0)])).unwrap();
        let mut state = DataState::new(directory.0.clone());
        let (_, initial) = state.qc_source("0000").unwrap();
        let (_, reused) = state.qc_source("0000").unwrap();
        assert!(Arc::ptr_eq(&initial, &reused));
        let initial_time = fs::metadata(&long_path).unwrap().modified().unwrap();
        fs::write(&long_path, long_bytes(&[("renamed!", 1.0)])).unwrap();
        File::options()
            .write(true)
            .open(&long_path)
            .unwrap()
            .set_modified(initial_time + std::time::Duration::from_secs(1))
            .unwrap();
        let (_, renamed) = state.qc_source("0000").unwrap();
        assert!(!Arc::ptr_eq(&initial, &renamed));
        assert!(renamed.offsets.contains_key("renamed!"));
        fs::write(&long_path, long_bytes(&[("compound", 1.0), ("heavy", 2.0)])).unwrap();
        fs::write(
            &transitions_path,
            transition_bytes(&[("0000", "compound", &["", "heavy"])]),
        )
        .unwrap();
        let (updated_transition, updated_index) = state.qc_source("0000").unwrap();
        assert!(!Arc::ptr_eq(&initial, &updated_index));
        assert_eq!(updated_transition.iso_name, ["", "heavy"]);
        assert!(updated_index.offsets.contains_key("heavy"));
    }

    #[test]
    fn integration_supports_full_u8_peak_count() {
        let mut bytes = Vec::new();
        for position in 0..510u16 {
            bytes.extend_from_slice(&position.to_le_bytes());
        }
        for baseline in 0..510u16 {
            bytes.extend_from_slice(&f32::from(baseline).to_le_bytes());
        }
        let (positions, baselines) = read_integration(&mut Cursor::new(&bytes), 255).unwrap();
        assert_eq!(positions.len(), 510);
        assert_eq!(positions[509], 509);
        assert_eq!(baselines[509], 509.0);
        assert!(read_integration(&mut Cursor::new(&bytes[..bytes.len() - 1]), 255).is_err());
    }

    #[test]
    fn streams_preserve_points_and_reject_partial_records() {
        let mut trace = vec![0; 5];
        trace.extend_from_slice(&1u16.to_le_bytes());
        trace.extend_from_slice(&2.0f32.to_le_bytes());
        trace.extend_from_slice(&3.0f32.to_le_bytes());
        let mut integration = vec![0];
        integration.extend_from_slice(&4.0f32.to_le_bytes());
        let mut records = Vec::new();
        stream_transition(
            &mut Cursor::new(&trace),
            &mut Cursor::new(&integration),
            |record| {
                records.push(record);
                Ok(())
            },
        )
        .unwrap();
        assert_eq!(records[0].sh, 4.0);
        assert_eq!(records[0].te[0].x, 2.0);
        assert_eq!(records[0].te[0].y, 3.0);
        trace.push(0);
        assert!(stream_transition(
            &mut Cursor::new(trace),
            &mut Cursor::new(&integration),
            |_| Ok(())
        )
        .is_err());
        assert!(stream_reference(&mut Cursor::new([1]), |_| Ok(())).is_err());
        assert!(read_shifts(&mut Cursor::new([0, 1])).is_err());
    }

    #[test]
    fn executable_adjacent_folder_and_filenames_stay_local() {
        let directory = TestDirectory::new();
        let expected = directory.0.join("misc");
        assert!(!expected.exists());
        let resolved = data_dir_for_executable(&directory.0.join("mrmhub-viz")).unwrap();
        assert_eq!(resolved, expected);
        assert_eq!(AppState::new(resolved).directory().unwrap(), expected);
        assert_eq!(
            data_dir_for_executable(Path::new(
                "/Applications/mrmhub-viz.app/Contents/MacOS/mrmhub-viz"
            ))
            .unwrap(),
            PathBuf::from("/Applications/mrmhub-viz.app/Contents/MacOS/misc")
        );
        assert!(data_file(&directory.0, "tp_", "../outside").is_err());
        assert!(data_file(&directory.0, "", "/outside").is_err());
        assert!(data_file(&directory.0, "tp_", "0000").is_ok());
    }

    #[test]
    #[ignore = "Requires the external regression dataset in MRMHUB_TEST_DATA_DIR"]
    fn external_dataset_smoke() {
        let directory = PathBuf::from(
            std::env::var_os("MRMHUB_TEST_DATA_DIR")
                .expect("Set MRMHUB_TEST_DATA_DIR to the external regression dataset"),
        )
        .canonicalize()
        .unwrap();
        let mut data = DataState::new(directory.clone());
        for cqq in ["0000", "0005", "0245"] {
            let mut trace =
                BufReader::new(File::open(directory.join(format!("te_{cqq}"))).unwrap());
            let mut integration =
                BufReader::new(File::open(directory.join(format!("tp_{cqq}"))).unwrap());
            let shifts = read_shifts(&mut integration).unwrap();
            integration.rewind().unwrap();
            let mut sample = 0;
            stream_transition(&mut trace, &mut integration, |record| {
                assert_eq!(record.sh, shifts[sample]);
                assert_eq!(record.pos_l.len(), record.bl.len());
                sample += 1;
                Ok(())
            })
            .unwrap();
            assert_eq!(sample, shifts.len());
            assert!(!shifts.is_empty());
            let (transition, index) = data.qc_source(cqq).unwrap();
            let mut reader = BufReader::new(File::open(directory.join("long.bin")).unwrap());
            let qc = read_qc(&mut reader, &index, &transition).unwrap();
            assert!(qc.iter().all(|(_, stats)| stats.len() == shifts.len()));
            if cqq == "0000" {
                assert!((qc[0].1[0].rt_apex - 1.343_483_3).abs() < 0.000_001);
                assert!((qc[0].1[0].area - 531.743_84).abs() < 0.001);
            }
            if cqq == "0245" {
                assert_eq!(qc[0].0, qc[1].0);
                assert_eq!(qc[0].1[0].area, qc[1].1[0].area);
            }
        }
        let transitions = parse_transitions(&mut BufReader::new(
            File::open(directory.join("trans_list.bin")).unwrap(),
        ))
        .unwrap();
        let mut references = 0;
        for entry in fs::read_dir(&directory).unwrap() {
            let entry = entry.unwrap();
            if entry.file_name().to_string_lossy().starts_with("se_") {
                let mut reader = BufReader::new(File::open(entry.path()).unwrap());
                let mut count = 0;
                stream_reference(&mut reader, |_| {
                    count += 1;
                    Ok(())
                })
                .unwrap();
                assert_eq!(count, transitions.len());
                references += 1;
            }
        }
        assert!(references > 0);
    }
}
