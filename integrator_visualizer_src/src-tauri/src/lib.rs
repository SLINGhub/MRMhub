// Learn more about Tauri commands at https://tauri.app/v1/guides/features/command
use std::fs::File;
use std::io;
use std::io::{BufRead, BufReader, Read};
use std::path::Path;
const MISCDIR: &str = "misc";

#[tauri::command]
fn get_ref() -> Vec<String> {
    glob::glob(Path::new(MISCDIR).join("se_*").to_str().unwrap())
        .unwrap()
        .filter_map(Result::ok)
        .filter_map(|path| {
            path.file_name()
                .and_then(|name| name.to_str())
                .map(String::from)
        })
        .collect()
}

#[tauri::command]
fn trans_csv() -> tauri::ipc::Response {
    let file_path = Path::new(MISCDIR).join("trans_R.csv");
    tauri::ipc::Response::new(std::fs::read(file_path).unwrap())
}

#[tauri::command]
fn mzml_tsv() -> tauri::ipc::Response {
    let file_path = Path::new(MISCDIR).join("mzML_list.txt");
    tauri::ipc::Response::new(std::fs::read(file_path).unwrap())
}

fn unpack_u16(file: &mut BufReader<File>) -> io::Result<u16> {
    let mut buffer = [0; std::mem::size_of::<u16>()];
    file.read_exact(&mut buffer)?;
    Ok(u16::from_le_bytes(buffer))
}
fn unpack_u8(file: &mut BufReader<File>) -> io::Result<u8> {
    let mut buffer = [0; std::mem::size_of::<u8>()];
    file.read_exact(&mut buffer)?;
    Ok(u8::from_le_bytes(buffer))
}
fn unpack_f32(file: &mut BufReader<File>) -> io::Result<f32> {
    let mut buffer = [0; std::mem::size_of::<f32>()];
    file.read_exact(&mut buffer)?;
    Ok(f32::from_le_bytes(buffer))
}

// begin QC
#[derive(Clone, serde::Serialize)]
struct QcStat {
    rt_apex: f32,
    area: f32,
    rt_int_start: f32,
    rt_int_end: f32,
}
#[tauri::command]
fn read_long(cqq: &str) -> Vec<(String, Vec<QcStat>)> {
    let file_path = Path::new(MISCDIR).join("long.bin");
    //if !std::fs::exists(&file_path).unwrap_or(false) {
    //    return Vec::new();
    //}
    let tp_path = Path::new(MISCDIR).join(["tp_", cqq].concat());
    let tp_time = std::fs::metadata(tp_path).and_then(|meta| meta.modified());
    if !std::fs::metadata(&file_path)
        .and_then(|meta| meta.modified())
        .and_then(|x| tp_time.map(|y| (y, x)))
        .is_ok_and(|(tp_time, x)| tp_time < x)
    {
        return Vec::new();
    }
    let cqq_iso = get_trans_istd().unwrap();
    let k: &ValidT = cqq_iso
        .binary_search_by_key(&cqq, |x| &x.cqq)
        .map_or_else(|_| panic!("{cqq} transition not found"), |k| &cqq_iso[k]);
    let bufr = &mut BufReader::new(File::open(file_path).unwrap());
    let len0 = unpack_u16(bufr).unwrap();
    k.iso_name
        .iter()
        .map(|mut iso_name| {
            if iso_name.is_empty() {
                iso_name = &k.cpd;
            }
            let mut a = Vec::new();
            while let Ok(name) = unpack_string(bufr) {
                //println!("{name}");
                if *iso_name == name {
                    a = (0..len0)
                        .map(|_| QcStat {
                            rt_apex: unpack_f32(bufr).unwrap(),
                            area: unpack_f32(bufr).unwrap(),
                            rt_int_start: unpack_f32(bufr).unwrap(),
                            rt_int_end: unpack_f32(bufr).unwrap(),
                        })
                        .collect();
                    break;
                }
                //bufr.seek_relative(i64::from(len0) * 12).unwrap();
                bufr.seek_relative(i64::from(len0) * 16).unwrap();
            }
            (iso_name.clone(), a)
        })
        .collect()

    //if !std::fs::exists("long.tsv").unwrap_or(false) {
    //    return Vec::new();
    //}
    //let cqq_iso = get_trans_istd().unwrap();
    //let k: &ValidT = cqq_iso
    //    .binary_search_by_key(&cqq, |x| &x.cqq)
    //    .map_or_else(|_| panic!("{cqq} transition not found"), |k| &cqq_iso[k]);
    //let mut rdr = csv::ReaderBuilder::new()
    //    .delimiter(b'\t')
    //    .has_headers(true)
    //    .trim(csv::Trim::All)
    //    .from_path("long.tsv")
    //    .unwrap();
    //let headers = rdr.headers().unwrap();
    //let apex_i = headers.iter().position(|x| x == "rt_apex").unwrap();
    //let area_i = headers.iter().position(|x| x == "area").unwrap();
    //let area_n_i = headers.iter().position(|x| x == "area_normalized").unwrap();
    //let feat_name_i = headers.iter().position(|x| x == "feature_name").unwrap();
    //let pos: csv::Position = rdr.records().reader().position().clone();
    //k.iso_name
    //    .iter()
    //    .map(|iso_name| {
    //        //println!("{iso_name}");
    //        rdr.records().reader_mut().seek(pos.clone()).unwrap();
    //        (
    //            iso_name.to_string(),
    //            rdr.records()
    //                .map(|x| x.unwrap())
    //                .skip_while(|rec| &rec[feat_name_i] != iso_name.as_str())
    //                .take_while(|rec| &rec[feat_name_i] == iso_name.as_str())
    //                .map(|rec| QcStat {
    //                    rt_apex: rec[apex_i].parse::<f32>().unwrap(),
    //                    area: rec[area_i].parse::<f32>().unwrap(),
    //                    area_normalized: rec[area_n_i].parse::<f32>().unwrap(),
    //                })
    //                .collect(),
    //        )
    //    })
    //    .collect()
}

use std::error::Error;
struct ValidT {
    cqq: String,
    cpd: String,
    iso_name: Vec<String>,
}
fn unpack_string(file: &mut BufReader<File>) -> Result<String, Box<dyn Error>> {
    let mut str_buf = Vec::new();
    file.read_until(b'\0', &mut str_buf)?;
    str_buf.pop().ok_or("unpack_string")?;
    Ok(String::from_utf8(str_buf)?)
}
fn get_trans_istd() -> Result<Vec<ValidT>, Box<dyn Error>> {
    let file_path = Path::new(MISCDIR).join("trans_list.bin");
    let bufr = &mut BufReader::new(File::open(file_path)?);
    (0..unpack_u16(bufr)?)
        .map(|_| {
            let cqq = unpack_string(bufr)?;
            let cpd = unpack_string(bufr)?;
            bufr.skip_until(b'\0')?;
            bufr.seek_relative(9)?;
            let iso_name = (0..unpack_u8(bufr)?)
                .map(|_| {
                    bufr.seek_relative(4)?;
                    let name = unpack_string(bufr);
                    bufr.seek_relative(8)?;
                    name
                })
                .collect::<Result<_, Box<dyn Error>>>()?;
            let slen = i64::from(unpack_u8(bufr)?);
            bufr.seek_relative(4 * slen)?;
            bufr.skip_until(b'\0')?;
            Ok(ValidT { cqq, cpd, iso_name })
        })
        .collect::<Result<_, _>>()
}
// end QC

#[derive(Clone, serde::Serialize)]
struct Pd {
    sh: f32,
    pos_l: Vec<u16>,
    bl: Vec<f32>,
    te: Vec<Point>,
}
#[tauri::command]
fn get_t(cqq: &str, on_event: tauri::ipc::Channel<Pd>) {
    let file_path = Path::new(MISCDIR).join(["te_", cqq].concat());
    let bufr = &mut BufReader::new(File::open(file_path).unwrap());
    let file_path = Path::new(MISCDIR).join(["tp_", cqq].concat());
    let bufr1 = &mut BufReader::new(File::open(file_path).unwrap());
    let len1 = unpack_u8(bufr1).unwrap();
    for pd in (0..).map_while(|_| {
        bufr.seek_relative(5).unwrap();
        unpack_u16(bufr)
            .map(|len0| Pd {
                sh: unpack_f32(bufr1).unwrap(),
                pos_l: (0..len1 * 2).map(|_| unpack_u16(bufr1).unwrap()).collect(),
                bl: (0..len1 * 2).map(|_| unpack_f32(bufr1).unwrap()).collect(),
                te: (0..len0)
                    .map(|_| Point {
                        x: unpack_f32(bufr).unwrap(),
                        y: unpack_f32(bufr).unwrap(),
                    })
                    .collect(),
            })
            .ok()
    }) {
        on_event.send(pd).unwrap();
    }
}
#[derive(Clone, serde::Serialize)]
struct Point {
    x: f32,
    y: f32,
}
#[tauri::command]
fn get_sh(cqq: &str) -> Vec<f32> {
    let file_path = Path::new(MISCDIR).join(["tp_", cqq].concat());
    let bufr1 = &mut BufReader::new(File::open(file_path).unwrap());
    let len1 = unpack_u8(bufr1).unwrap();
    (0..)
        .map_while(|_| {
            let sh = unpack_f32(bufr1);
            bufr1.seek_relative(i64::from(len1) * 12).unwrap();
            sh.ok()
        })
        .collect()
}
#[tauri::command]
fn get_r(mzml: &str, on_event: tauri::ipc::Channel<Pd>) {
    let file_path = Path::new(MISCDIR).join(mzml);
    let bufr = &mut BufReader::new(File::open(file_path).unwrap());
    for pd in (0..).map_while(|_| {
        unpack_u16(bufr)
            .map(|len0| {
                let te = (0..len0)
                    .map(|_| Point {
                        x: unpack_f32(bufr).unwrap(),
                        y: unpack_f32(bufr).unwrap(),
                    })
                    .collect();
                let sh = unpack_f32(bufr).unwrap();
                let len1 = unpack_u8(bufr).unwrap();
                let pos_l = (0..len1 * 2).map(|_| unpack_u16(bufr).unwrap()).collect();
                Pd {
                    te,
                    sh,
                    pos_l,
                    bl: (0..len1 * 2).map(|_| unpack_f32(bufr).unwrap()).collect(),
                }
            })
            .ok()
    }) {
        on_event.send(pd).unwrap();
    }
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    std::env::set_current_dir(std::env::current_exe().unwrap().parent().unwrap()).unwrap();
    tauri::Builder::default()
        .plugin(tauri_plugin_opener::init())
        .invoke_handler(tauri::generate_handler![
            trans_csv, mzml_tsv, get_t, read_long, get_sh, get_ref, get_r
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
