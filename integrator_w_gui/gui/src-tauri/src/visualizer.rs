use std::error::Error;
use std::fs::File;
use std::io::{self, BufRead, BufReader, Read};
use std::path::{Path, PathBuf};
use tauri::ipc::{Channel, Response};

// describes one qc result for a single sample
#[derive(Clone, serde::Serialize)]
pub struct QcStat {
    rt_apex: f32,
    area: f32,
    rt_int_start: f32,
    rt_int_end: f32,
}

// describes one chromatogram sent to the visualizer
#[derive(Clone, serde::Serialize)]
pub struct PlotData {
    sh: f32,
    pos_l: Vec<u16>,
    bl: Vec<Option<f32>>,
    te: Vec<Point>,
}

// stores one retention-time and intensity pair
#[derive(Clone, serde::Serialize)]
pub struct Point {
    x: f32,
    y: f32,
}

// stores the transition metadata needed to locate qc records
struct ValidTransition {
    cqq: String,
    cpd: String,
    iso_name: Vec<String>,
}

// validates the selected dataset and returns its misc directory
fn misc_dir(project_path: &str) -> Result<PathBuf, String> {
    let project = PathBuf::from(project_path);
    if !project.is_dir() {
        return Err("the selected dataset folder does not exist".to_string());
    }
    let misc = project.join("misc");
    if !misc.is_dir() {
        return Err("run step 1 before opening the visualizer".to_string());
    }
    Ok(misc)
}

// rejects path separators in names read from visualizer metadata
fn safe_component(value: &str) -> Result<&str, String> {
    if value.is_empty()
        || value == "."
        || value == ".."
        || value.contains('/')
        || value.contains('\\')
    {
        return Err("the visualizer requested an invalid data file".to_string());
    }
    Ok(value)
}

// Creates the export folder before graph rendering starts, so the user gets
// immediate filesystem feedback even when a large reference takes time.
fn png_export_folder(project_path: &str, folder_name: &str) -> Result<PathBuf, String> {
    let folder_name = safe_component(folder_name)?;
    let project = PathBuf::from(project_path);
    if !project.is_dir() {
        return Err("the selected dataset folder does not exist".to_string());
    }
    let folder = project.join("visualizer_png").join(folder_name);
    std::fs::create_dir_all(&folder).map_err(|error| error.to_string())?;
    Ok(folder)
}

#[tauri::command]
pub fn visualizer_prepare_png_export(
    project_path: &str,
    folder_name: &str,
) -> Result<String, String> {
    Ok(png_export_folder(project_path, folder_name)?
        .to_string_lossy()
        .into_owned())
}

// saves one browser-rendered PNG sheet beneath the selected dataset. Both
// names are single validated path components, so exports cannot escape the
// project-owned visualizer_png directory.
#[tauri::command]
pub fn visualizer_save_png(
    project_path: &str,
    folder_name: &str,
    file_name: &str,
    bytes: Vec<u8>,
) -> Result<String, String> {
    let file_name = safe_component(file_name)?;
    if !file_name.to_ascii_lowercase().ends_with(".png") {
        return Err("the visualizer export must use a .png file name".to_string());
    }
    const PNG_SIGNATURE: &[u8; 8] = b"\x89PNG\r\n\x1a\n";
    if bytes.len() < PNG_SIGNATURE.len() || &bytes[..PNG_SIGNATURE.len()] != PNG_SIGNATURE {
        return Err("the visualizer export did not contain valid PNG data".to_string());
    }
    if bytes.len() > 64 * 1024 * 1024 {
        return Err("the visualizer PNG sheet exceeded the 64 MB limit".to_string());
    }

    let folder = png_export_folder(project_path, folder_name)?;
    let path = folder.join(file_name);
    std::fs::write(&path, bytes).map_err(|error| error.to_string())?;
    Ok(path.to_string_lossy().into_owned())
}

// counts samples without retaining the sample table
fn sample_count(misc: &Path) -> Result<usize, String> {
    let file = File::open(misc.join("mzML_list.txt")).map_err(|error| error.to_string())?;
    Ok(BufReader::new(file).lines().count())
}

// detects the older peak files that stored baselines inline
fn has_inline_baselines(path: &Path, peak_count: u8, samples: usize) -> Result<bool, String> {
    let length = std::fs::metadata(path)
        .map_err(|error| error.to_string())?
        .len() as usize;
    let inline_record_size = 4 + usize::from(peak_count) * 12;
    Ok(length == 1 + samples * inline_record_size)
}

// reads one little-endian unsigned integer
fn unpack_u16(file: &mut BufReader<File>) -> io::Result<u16> {
    let mut buffer = [0; std::mem::size_of::<u16>()];
    file.read_exact(&mut buffer)?;
    Ok(u16::from_le_bytes(buffer))
}

// reads one little-endian byte
fn unpack_u8(file: &mut BufReader<File>) -> io::Result<u8> {
    let mut buffer = [0; std::mem::size_of::<u8>()];
    file.read_exact(&mut buffer)?;
    Ok(u8::from_le_bytes(buffer))
}

// reads one little-endian floating-point value
fn unpack_f32(file: &mut BufReader<File>) -> io::Result<f32> {
    let mut buffer = [0; std::mem::size_of::<f32>()];
    file.read_exact(&mut buffer)?;
    Ok(f32::from_le_bytes(buffer))
}

// reads one null-terminated utf-8 string
fn unpack_string(file: &mut BufReader<File>) -> Result<String, Box<dyn Error>> {
    let mut string = Vec::new();
    file.read_until(b'\0', &mut string)?;
    string.pop().ok_or("the string terminator was missing")?;
    Ok(String::from_utf8(string)?)
}

// reads the compact transition metadata file
fn get_transitions(misc: &Path) -> Result<Vec<ValidTransition>, Box<dyn Error>> {
    let mut reader = BufReader::new(File::open(misc.join("trans_list.bin"))?);
    (0..unpack_u16(&mut reader)?)
        .map(|_| {
            let cqq = unpack_string(&mut reader)?;
            let cpd = unpack_string(&mut reader)?;
            reader.skip_until(b'\0')?;
            reader.seek_relative(9)?;
            let iso_name = (0..unpack_u8(&mut reader)?)
                .map(|_| {
                    reader.seek_relative(4)?;
                    let name = unpack_string(&mut reader);
                    reader.seek_relative(8)?;
                    name
                })
                .collect::<Result<_, Box<dyn Error>>>()?;
            let standard_count = i64::from(unpack_u8(&mut reader)?);
            reader.seek_relative(4 * standard_count)?;
            Ok(ValidTransition { cqq, cpd, iso_name })
        })
        .collect::<Result<_, _>>()
}

// describes one integration window edited by dragging on a chromatogram.
// each edit is self-describing (its own transition + sample) so a single call
// covers both transition view (one cqq, many samples) and reference view
// (one sample, many cqqs).
#[derive(serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct BoundEdit {
    cqq: String,
    sample_index: usize,
    file_name: String,
    isomer_index: usize,
    rt_start: f32,
    rt_end: f32,
}

// drops a trailing .mzML extension so sample names compare regardless of it
fn strip_mzml(name: &str) -> &str {
    name.strip_suffix(".mzML")
        .or_else(|| name.strip_suffix(".mzml"))
        .unwrap_or(name)
}

// rewrites only the dragged integration bounds in RT_matrix.csv, leaving
// every other cell untouched; step 3 recomputes areas from these values
#[tauri::command]
pub fn visualizer_save_bounds(project_path: &str, edits: Vec<BoundEdit>) -> Result<usize, String> {
    if edits.is_empty() {
        return Ok(0);
    }
    let project = PathBuf::from(project_path);
    if !project.is_dir() {
        return Err("the selected dataset folder does not exist".to_string());
    }
    let rtm_path = project.join("RT_matrix.csv");
    if !rtm_path.is_file() {
        return Err("RT_matrix.csv was not found; run step 2 before editing bounds".to_string());
    }

    let mut records: Vec<Vec<String>> = csv::ReaderBuilder::new()
        .has_headers(false)
        .flexible(true)
        .from_path(&rtm_path)
        .map_err(|error| error.to_string())?
        .records()
        .map(|record| {
            record
                .map(|record| record.iter().map(str::to_string).collect())
                .map_err(|error| error.to_string())
        })
        .collect::<Result<_, _>>()?;
    if records.len() < 4 {
        return Err("RT_matrix.csv does not contain any samples".to_string());
    }
    let row_count = records.len();

    let mut written = 0;
    for edit in &edits {
        // the header repeats "compound / cqq" twice per isomer; collect this
        // edit's transition columns in order so pairs map to isomers
        let columns: Vec<usize> = records[0]
            .iter()
            .enumerate()
            .filter(|(_, cell)| {
                cell.trim()
                    .rsplit_once(" / ")
                    .is_some_and(|(_, id)| id == edit.cqq)
            })
            .map(|(index, _)| index)
            .collect();
        let start_col = *columns
            .get(edit.isomer_index * 2)
            .ok_or_else(|| format!("transition {} was not found in RT_matrix.csv", edit.cqq))?;
        let end_col = *columns.get(edit.isomer_index * 2 + 1).ok_or_else(|| {
            format!(
                "transition {} is missing an integration column in RT_matrix.csv",
                edit.cqq
            )
        })?;

        // trust the streamed order but verify by filename before writing
        let target = 3 + edit.sample_index;
        let row_index = if target < row_count
            && strip_mzml(records[target][0].trim()) == strip_mzml(edit.file_name.trim())
        {
            target
        } else {
            (3..row_count)
                .find(|&index| {
                    strip_mzml(records[index][0].trim()) == strip_mzml(edit.file_name.trim())
                })
                .ok_or_else(|| {
                    format!("sample {} was not found in RT_matrix.csv", edit.file_name)
                })?
        };

        let row = &mut records[row_index];
        if start_col >= row.len() || end_col >= row.len() {
            return Err("RT_matrix.csv is malformed for this transition".to_string());
        }
        let (low, high) = if edit.rt_start <= edit.rt_end {
            (edit.rt_start, edit.rt_end)
        } else {
            (edit.rt_end, edit.rt_start)
        };
        row[start_col] = format!("{low:.3}");
        row[end_col] = format!("{high:.3}");
        written += 1;
    }

    let mut writer = csv::WriterBuilder::new()
        .flexible(true)
        .from_path(&rtm_path)
        .map_err(|error| error.to_string())?;
    for record in &records {
        writer
            .write_record(record)
            .map_err(|error| error.to_string())?;
    }
    writer.flush().map_err(|error| error.to_string())?;
    Ok(written)
}

// lists the available reference chromatogram files
#[tauri::command]
pub fn visualizer_get_ref(project_path: &str) -> Result<Vec<String>, String> {
    let misc = misc_dir(project_path)?;
    let pattern = misc.join("se_*");
    let mut files = glob::glob(&pattern.to_string_lossy())
        .map_err(|error| error.to_string())?
        .filter_map(Result::ok)
        .filter_map(|path| {
            path.file_name()
                .and_then(|name| name.to_str())
                .map(str::to_owned)
        })
        .collect::<Vec<_>>();
    files.sort_unstable();
    Ok(files)
}

// returns the transition table without converting it in rust
#[tauri::command]
pub fn visualizer_trans_csv(project_path: &str) -> Result<Response, String> {
    let path = misc_dir(project_path)?.join("trans_R.csv");
    std::fs::read(path)
        .map(Response::new)
        .map_err(|error| error.to_string())
}

// returns the sample table without converting it in rust
#[tauri::command]
pub fn visualizer_mzml_tsv(project_path: &str) -> Result<Response, String> {
    let path = misc_dir(project_path)?.join("mzML_list.txt");
    std::fs::read(path)
        .map(Response::new)
        .map_err(|error| error.to_string())
}

// reads the qc values for one transition while bounding memory to one feature
#[tauri::command]
pub fn visualizer_read_long(
    project_path: &str,
    cqq: &str,
) -> Result<Vec<(String, Vec<QcStat>)>, String> {
    let misc = misc_dir(project_path)?;
    let cqq = safe_component(cqq)?;
    let long_path = misc.join("long.bin");
    if !long_path.is_file() {
        return Ok(Vec::new());
    }

    let transition_path = misc.join(format!("tp_{cqq}"));
    let transition_time = std::fs::metadata(transition_path).and_then(|meta| meta.modified());
    let long_is_current = std::fs::metadata(&long_path)
        .and_then(|meta| meta.modified())
        .and_then(|long_time| transition_time.map(|transition_time| transition_time < long_time))
        .is_ok_and(|is_current| is_current);
    if !long_is_current {
        return Ok(Vec::new());
    }

    let transitions = get_transitions(&misc).map_err(|error| error.to_string())?;
    let transition = transitions
        .binary_search_by_key(&cqq, |transition| transition.cqq.as_str())
        .ok()
        .and_then(|index| transitions.get(index))
        .ok_or_else(|| format!("transition {cqq} was not found"))?;
    let mut reader = BufReader::new(File::open(long_path).map_err(|error| error.to_string())?);
    let sample_count = unpack_u16(&mut reader).map_err(|error| error.to_string())?;
    let mut output = Vec::with_capacity(transition.iso_name.len());

    for original_name in &transition.iso_name {
        let feature_name = if original_name.is_empty() {
            &transition.cpd
        } else {
            original_name
        };
        let mut values = Vec::new();
        while let Ok(name) = unpack_string(&mut reader) {
            if feature_name == &name {
                values = (0..sample_count)
                    .map(|_| {
                        Ok(QcStat {
                            rt_apex: unpack_f32(&mut reader)?,
                            area: unpack_f32(&mut reader)?,
                            rt_int_start: unpack_f32(&mut reader)?,
                            rt_int_end: unpack_f32(&mut reader)?,
                        })
                    })
                    .collect::<io::Result<Vec<_>>>()
                    .map_err(|error| error.to_string())?;
                break;
            }
            reader
                .seek_relative(i64::from(sample_count) * 16)
                .map_err(|error| error.to_string())?;
        }
        output.push((feature_name.clone(), values));
    }
    Ok(output)
}

// streams transition chromatograms one sample at a time
#[tauri::command]
pub fn visualizer_get_t(
    project_path: &str,
    cqq: &str,
    on_event: Channel<PlotData>,
) -> Result<(), String> {
    let misc = misc_dir(project_path)?;
    let cqq = safe_component(cqq)?;
    let peak_path = misc.join(format!("tp_{cqq}"));
    let mut trace_reader = BufReader::new(
        File::open(misc.join(format!("te_{cqq}"))).map_err(|error| error.to_string())?,
    );
    let mut peak_reader =
        BufReader::new(File::open(&peak_path).map_err(|error| error.to_string())?);
    let peak_count = unpack_u8(&mut peak_reader).map_err(|error| error.to_string())?;
    let mut baseline_reader = File::open(misc.join(format!("tb_{cqq}")))
        .ok()
        .map(BufReader::new);
    if let Some(reader) = baseline_reader.as_mut()
        && unpack_u8(reader).map_err(|error| error.to_string())? != peak_count
    {
        return Err("the transition baseline count does not match the peak count".to_string());
    }
    let inline_baselines = baseline_reader.is_none()
        && has_inline_baselines(&peak_path, peak_count, sample_count(&misc)?)?;

    loop {
        trace_reader
            .seek_relative(5)
            .map_err(|error| error.to_string())?;
        let point_count = match unpack_u16(&mut trace_reader) {
            Ok(count) => count,
            Err(error) if error.kind() == io::ErrorKind::UnexpectedEof => break,
            Err(error) => return Err(error.to_string()),
        };
        let sh = unpack_f32(&mut peak_reader).map_err(|error| error.to_string())?;
        let pos_l = (0..peak_count * 2)
            .map(|_| unpack_u16(&mut peak_reader))
            .collect::<io::Result<Vec<_>>>()
            .map_err(|error| error.to_string())?;
        let bl = if let Some(reader) = baseline_reader.as_mut() {
            (0..peak_count * 2)
                .map(|_| unpack_f32(reader).map(Some))
                .collect::<io::Result<Vec<_>>>()
                .map_err(|error| error.to_string())?
        } else if inline_baselines {
            (0..peak_count * 2)
                .map(|_| unpack_f32(&mut peak_reader).map(Some))
                .collect::<io::Result<Vec<_>>>()
                .map_err(|error| error.to_string())?
        } else {
            vec![None; usize::from(peak_count) * 2]
        };
        let plot = PlotData {
            sh,
            pos_l,
            bl,
            te: (0..point_count)
                .map(|_| {
                    Ok(Point {
                        x: unpack_f32(&mut trace_reader)?,
                        y: unpack_f32(&mut trace_reader)?,
                    })
                })
                .collect::<io::Result<Vec<_>>>()
                .map_err(|error| error.to_string())?,
        };
        on_event.send(plot).map_err(|error| error.to_string())?;
    }
    Ok(())
}

// reads the retention-time shifts for one transition
#[tauri::command]
pub fn visualizer_get_sh(project_path: &str, cqq: &str) -> Result<Vec<f32>, String> {
    let misc = misc_dir(project_path)?;
    let cqq = safe_component(cqq)?;
    let peak_path = misc.join(format!("tp_{cqq}"));
    let mut reader = BufReader::new(File::open(&peak_path).map_err(|error| error.to_string())?);
    let peak_count = unpack_u8(&mut reader).map_err(|error| error.to_string())?;
    let inline_baselines = has_inline_baselines(&peak_path, peak_count, sample_count(&misc)?)?;
    let record_tail = if inline_baselines { 12 } else { 4 };
    let mut shifts = Vec::new();
    loop {
        match unpack_f32(&mut reader) {
            Ok(shift) => shifts.push(shift),
            Err(error) if error.kind() == io::ErrorKind::UnexpectedEof => break,
            Err(error) => return Err(error.to_string()),
        }
        reader
            .seek_relative(i64::from(peak_count) * record_tail)
            .map_err(|error| error.to_string())?;
    }
    Ok(shifts)
}

// streams one reference sample's chromatograms by transition
#[tauri::command]
pub fn visualizer_get_r(
    project_path: &str,
    mzml: &str,
    on_event: Channel<PlotData>,
) -> Result<(), String> {
    let misc = misc_dir(project_path)?;
    let mzml = safe_component(mzml)?;
    let mut reader =
        BufReader::new(File::open(misc.join(mzml)).map_err(|error| error.to_string())?);
    let baseline_name = mzml.strip_prefix("se_").map(|name| format!("sb_{name}"));
    let mut baseline_reader = baseline_name
        .and_then(|name| File::open(misc.join(name)).ok())
        .map(BufReader::new);
    loop {
        let point_count = match unpack_u16(&mut reader) {
            Ok(count) => count,
            Err(error) if error.kind() == io::ErrorKind::UnexpectedEof => break,
            Err(error) => return Err(error.to_string()),
        };
        let te = (0..point_count)
            .map(|_| {
                Ok(Point {
                    x: unpack_f32(&mut reader)?,
                    y: unpack_f32(&mut reader)?,
                })
            })
            .collect::<io::Result<Vec<_>>>()
            .map_err(|error| error.to_string())?;
        let sh = unpack_f32(&mut reader).map_err(|error| error.to_string())?;
        let peak_count = unpack_u8(&mut reader).map_err(|error| error.to_string())?;
        let pos_l = (0..peak_count * 2)
            .map(|_| unpack_u16(&mut reader))
            .collect::<io::Result<Vec<_>>>()
            .map_err(|error| error.to_string())?;
        let bl = if let Some(baseline_reader) = baseline_reader.as_mut() {
            let baseline_count = unpack_u8(baseline_reader).map_err(|error| error.to_string())?;
            if baseline_count != peak_count {
                return Err(
                    "the reference baseline count does not match the peak count".to_string()
                );
            }
            (0..peak_count * 2)
                .map(|_| unpack_f32(baseline_reader).map(Some))
                .collect::<io::Result<Vec<_>>>()
                .map_err(|error| error.to_string())?
        } else {
            vec![None; usize::from(peak_count) * 2]
        };
        on_event
            .send(PlotData { sh, pos_l, bl, te })
            .map_err(|error| error.to_string())?;
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    // builds an RT_matrix.csv mirroring the real layout: a leading label column,
    // then per transition a spacer column plus (start,end) columns per isomer.
    // "0000" is single-isomer (blue only), "0001" is two-isomer (blue + orange).
    fn write_fixture(dir: &Path) {
        let mut writer = csv::Writer::from_path(dir.join("RT_matrix.csv")).unwrap();
        writer
            .write_record([
                "",
                "",
                "CE 14:0 / 0000",
                "CE 14:0 / 0000",
                "",
                "PC 34:1 / 0001",
                "PC 34:1 / 0001",
                "PC 34:1 / 0001",
                "PC 34:1 / 0001",
            ])
            .unwrap();
        writer
            .write_record([
                "compound name",
                "",
                "CE 14:0",
                "CE 14:0",
                "",
                "iso a",
                "iso a",
                "iso b",
                "iso b",
            ])
            .unwrap();
        writer
            .write_record(["", "", "-", "-", "", "-", "-", "-", "-"])
            .unwrap();
        writer
            .write_record([
                "sample one.mzML",
                "",
                "1.000",
                "2.000",
                "",
                "3.000",
                "4.000",
                "5.000",
                "6.000",
            ])
            .unwrap();
        writer
            .write_record([
                "sample two.mzML",
                "",
                "1.100",
                "2.100",
                "",
                "3.100",
                "4.100",
                "5.100",
                "6.100",
            ])
            .unwrap();
        writer.flush().unwrap();
    }

    fn read_rows(dir: &Path) -> Vec<Vec<String>> {
        csv::ReaderBuilder::new()
            .has_headers(false)
            .flexible(true)
            .from_path(dir.join("RT_matrix.csv"))
            .unwrap()
            .records()
            .map(|record| record.unwrap().iter().map(str::to_string).collect())
            .collect()
    }

    fn temp_project(tag: &str) -> PathBuf {
        let dir =
            std::env::temp_dir().join(format!("mrmhub_save_test_{tag}_{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&dir);
        std::fs::create_dir_all(&dir).unwrap();
        dir
    }

    #[test]
    fn saves_single_isomer_blue_only_graph() {
        let dir = temp_project("blue");
        write_fixture(&dir);
        // the frontend sends the sample name without the .mzML extension
        let written = visualizer_save_bounds(
            dir.to_str().unwrap(),
            vec![BoundEdit {
                cqq: "0000".to_string(),
                sample_index: 1,
                file_name: "sample two".to_string(),
                isomer_index: 0,
                rt_start: 9.5,
                rt_end: 9.9,
            }],
        )
        .unwrap();
        assert_eq!(written, 1);

        let rows = read_rows(&dir);
        // only "sample two"'s 0000 start/end cells change
        assert_eq!(rows[4][2], "9.500");
        assert_eq!(rows[4][3], "9.900");
        // the other sample and the other transition are untouched
        assert_eq!(rows[3][2], "1.000");
        assert_eq!(rows[3][3], "2.000");
        assert_eq!(rows[4][5], "3.100");
        assert_eq!(rows[4][8], "6.100");
        std::fs::remove_dir_all(&dir).unwrap();
    }

    #[test]
    fn moves_only_the_blue_band_on_a_two_isomer_transition() {
        let dir = temp_project("multi");
        write_fixture(&dir);
        let written = visualizer_save_bounds(
            dir.to_str().unwrap(),
            vec![BoundEdit {
                cqq: "0001".to_string(),
                sample_index: 0,
                file_name: "sample one".to_string(),
                isomer_index: 0,
                rt_start: 7.2,
                rt_end: 7.8,
            }],
        )
        .unwrap();
        assert_eq!(written, 1);

        let rows = read_rows(&dir);
        // blue (isomer 0) columns of 0001 change...
        assert_eq!(rows[3][5], "7.200");
        assert_eq!(rows[3][6], "7.800");
        // ...while orange (isomer 1) is left exactly as detected
        assert_eq!(rows[3][7], "5.000");
        assert_eq!(rows[3][8], "6.000");
        std::fs::remove_dir_all(&dir).unwrap();
    }

    #[test]
    fn falls_back_to_filename_when_sample_index_is_stale() {
        let dir = temp_project("fallback");
        write_fixture(&dir);
        // a wrong index still resolves via the filename check
        visualizer_save_bounds(
            dir.to_str().unwrap(),
            vec![BoundEdit {
                cqq: "0000".to_string(),
                sample_index: 99,
                file_name: "sample one".to_string(),
                isomer_index: 0,
                rt_start: 8.0,
                rt_end: 8.4,
            }],
        )
        .unwrap();
        let rows = read_rows(&dir);
        assert_eq!(rows[3][2], "8.000");
        assert_eq!(rows[3][3], "8.400");
        std::fs::remove_dir_all(&dir).unwrap();
    }

    #[test]
    fn reference_view_writes_many_transitions_into_one_sample_row() {
        let dir = temp_project("reference");
        write_fixture(&dir);
        // reference view: one fixed sample, edits across different transitions
        let written = visualizer_save_bounds(
            dir.to_str().unwrap(),
            vec![
                BoundEdit {
                    cqq: "0000".to_string(),
                    sample_index: 0,
                    file_name: "sample one".to_string(),
                    isomer_index: 0,
                    rt_start: 1.5,
                    rt_end: 1.9,
                },
                BoundEdit {
                    cqq: "0001".to_string(),
                    sample_index: 0,
                    file_name: "sample one".to_string(),
                    isomer_index: 0,
                    rt_start: 3.5,
                    rt_end: 3.9,
                },
            ],
        )
        .unwrap();
        assert_eq!(written, 2);

        let rows = read_rows(&dir);
        // both transitions written into "sample one"'s single row
        assert_eq!(rows[3][2], "1.500");
        assert_eq!(rows[3][3], "1.900");
        assert_eq!(rows[3][5], "3.500");
        assert_eq!(rows[3][6], "3.900");
        // the other sample row is untouched
        assert_eq!(rows[4][2], "1.100");
        std::fs::remove_dir_all(&dir).unwrap();
    }

    #[test]
    fn saves_png_exports_inside_the_selected_project() {
        let dir = temp_project("png");
        let bytes = b"\x89PNG\r\n\x1a\nfixture".to_vec();
        let saved = visualizer_save_png(
            dir.to_str().unwrap(),
            "2026-08-07_transition",
            "transition_qc_01.png",
            bytes.clone(),
        )
        .unwrap();
        let path = PathBuf::from(saved);
        assert_eq!(std::fs::read(&path).unwrap(), bytes);
        assert!(path.starts_with(dir.join("visualizer_png")));
        std::fs::remove_dir_all(&dir).unwrap();
    }

    #[test]
    fn prepares_png_export_folder_before_rendering() {
        let dir = temp_project("png_prepare");
        let prepared =
            visualizer_prepare_png_export(dir.to_str().unwrap(), "2026-08-07_reference").unwrap();
        let path = PathBuf::from(prepared);
        assert!(path.is_dir());
        assert_eq!(
            path,
            dir.join("visualizer_png").join("2026-08-07_reference")
        );
        std::fs::remove_dir_all(&dir).unwrap();
    }

    #[test]
    fn rejects_png_export_path_traversal() {
        let dir = temp_project("png_traversal");
        let result = visualizer_save_png(
            dir.to_str().unwrap(),
            "..",
            "outside.png",
            b"\x89PNG\r\n\x1a\nfixture".to_vec(),
        );
        assert!(result.is_err());
        std::fs::remove_dir_all(&dir).unwrap();
    }
}
