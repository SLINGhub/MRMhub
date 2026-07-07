use std::error::Error;
use std::fs::File;
use std::io;
use std::io::{BufRead, BufReader, BufWriter, Read, Write};
use std::path::{Path, PathBuf};

pub fn read_param() -> Result<crate::Param, Box<dyn Error>> {
    let param = std::fs::read_to_string("param.txt")?;
    let value = param.parse::<toml::Table>()?;
    let mzml_fs: Vec<_> = glob::glob(value["mzML_files"].as_str().unwrap())?
        .filter_map(Result::ok)
        .collect();
    if mzml_fs.is_empty() {
        return Err("mzML files not found".into());
    }
    let mut rt_shift = value["RT_shift"]
        .as_array()
        .unwrap()
        .iter()
        .map(|x| x.as_float().unwrap() as f32);
    let mut peak_w = value["peak_width"]
        .as_array()
        .unwrap()
        .iter()
        .map(|x| x.as_float().unwrap() as f32);
    Ok(crate::Param {
        mzml_fs,
        batch_i: PathBuf::from(value["batch_info"].as_str().unwrap()),
        t_list: PathBuf::from(value["transition_list"].as_str().unwrap()),
        num_t: usize::try_from(value["num_threads"].as_integer().unwrap())?,
        mz_tol: value["mz_tol"].as_float().unwrap() as f32,
        rt_tol: value["RT_tol"].as_float().unwrap() as f32,
        crop_window: value.get("crop_window").map(|x| {
            (
                x[0].as_float().unwrap() as f32,
                x[1].as_float().unwrap() as f32,
            )
        }),
        peak_w: (
            peak_w.next().unwrap(),
            peak_w.next().unwrap(),
            peak_w.next().unwrap(),
            peak_w.next().unwrap(),
        ),
        rt_shift: (rt_shift.next().unwrap(), rt_shift.next().unwrap()),
        rt_shift_bd: value["RT_shift_bound"].as_float().unwrap() as f32,
    })
}
fn unpack_string(file: &mut BufReader<File>) -> Result<String, Box<dyn Error>> {
    let mut str_buf = Vec::new();
    file.read_until(b'\0', &mut str_buf)?;
    str_buf.pop().ok_or("unpack_string")?;
    Ok(String::from_utf8(str_buf)?)
}
pub fn unpack_f32_2(file: &mut BufReader<File>) -> io::Result<(f32, f32)> {
    let mut buffer = [0; std::mem::size_of::<f32>()];
    file.read_exact(&mut buffer)?;
    let a = f32::from_le_bytes(buffer);
    file.read_exact(&mut buffer)?;
    Ok((a, f32::from_le_bytes(buffer)))
}

macro_rules! unpack {
    ($sn:ident, $sn1:ident) => {
        pub fn $sn1(file: &mut BufReader<File>) -> io::Result<$sn> {
            let mut buffer = [0; std::mem::size_of::<$sn>()];
            file.read_exact(&mut buffer)?;
            Ok($sn::from_le_bytes(buffer))
        }
    };
}
unpack!(f32, unpack_f32);
unpack!(u16, unpack_u16);
unpack!(u8, unpack_u8);
pub fn get_eic(bufr: &mut BufReader<File>) -> io::Result<Vec<(f32, f32)>> {
    bufr.seek_relative(5)?;
    Ok((0..unpack_u16(bufr)?)
        .map(|_| unpack_f32_2(bufr).unwrap())
        .collect())
}
pub struct FileA {
    pub mzml_f: String,
    pub ftype: String,
    pub ts: String,
    pub batchno: String,
    pub is_ref: bool,
    pub is_learn: bool,
}
pub struct ValidI {
    pub rt: f32,
    pub name: String,
    pub range: (f32, f32),
}
pub enum Bl {
    VDrop,
    V2v,
    P,
}
pub struct ValidT {
    pub cqq: String,
    pub iqq: String,
    pub cpd: String,
    pub q1: f32,
    pub q3: f32,
    pub u_rt: bool,
    pub rt_iso: Vec<ValidI>,
    pub peak_w: Option<(f32, f32, f32, f32)>,
    pub baseline: Bl,
}
pub fn get_trans_istd() -> Result<Vec<ValidT>, Box<dyn Error>> {
    let file_path = Path::new(crate::MISCDIR).join(crate::TRANS_L);
    let bufr = &mut BufReader::new(File::open(file_path)?);
    (0..unpack_u16(bufr)?)
        .map(|_| {
            Ok(ValidT {
                cqq: unpack_string(bufr)?,
                cpd: unpack_string(bufr)?,
                iqq: unpack_string(bufr)?,
                q1: unpack_f32(bufr)?,
                q3: unpack_f32(bufr)?,
                u_rt: unpack_u8(bufr).map(|x| x == 1)?,
                rt_iso: (0..unpack_u8(bufr)?)
                    .map(|_| {
                        Ok(ValidI {
                            rt: unpack_f32(bufr)?,
                            name: unpack_string(bufr)?,
                            range: unpack_f32_2(bufr)?,
                        })
                    })
                    .collect::<Result<_, Box<dyn Error>>>()?,
                peak_w: (unpack_u8(bufr)? > 0).then(|| {
                    (
                        unpack_f32(bufr).unwrap(),
                        unpack_f32(bufr).unwrap(),
                        unpack_f32(bufr).unwrap(),
                        unpack_f32(bufr).unwrap(),
                    )
                }),
                baseline: match unpack_string(bufr)?.to_lowercase().as_str() {
                    "v_drop" | "v drop" => Bl::VDrop,
                    "v2v" => Bl::V2v,
                    _ => Bl::P,
                },
            })
        })
        .collect::<Result<_, _>>()
}
pub fn get_mzml() -> io::Result<Vec<FileA>> {
    let file_path = Path::new(crate::MISCDIR).join(crate::MZML_L);
    let rdr = csv::ReaderBuilder::new()
        .delimiter(b'\t')
        .has_headers(false)
        .trim(csv::Trim::All)
        .from_path(file_path)?;
    Ok(rdr
        .into_records()
        .map(|rec| {
            rec.map(|x| FileA {
                mzml_f: x[0].to_string(),
                ftype: x[1].to_string(),
                ts: x[2].to_string(),
                batchno: x[3].to_string(),
                is_ref: &x[4] == "1",
                is_learn: &x[5] == "1",
            })
        })
        .collect::<Result<_, _>>()?)
}
pub fn write_by_sample(t_to_istd: &[ValidT], mzml_fs: &[FileA]) -> Result<(), Box<dyn Error>> {
    let count_s = mzml_fs.iter().filter(|x| x.is_ref).count();
    let se_pos = t_to_istd
        .iter()
        .flat_map(|valid_t| {
            let file_path = Path::new(crate::MISCDIR).join(["tp_", &valid_t.cqq].concat());
            let mut bufr = BufReader::new(File::open(file_path).unwrap());
            let len0 = unpack_u8(&mut bufr).unwrap();
            (0..)
                .map(move |_| {
                    (
                        unpack_f32(&mut bufr).unwrap(),
                        (0..len0)
                            .map(|_| {
                                (
                                    unpack_u16(&mut bufr).unwrap(),
                                    unpack_u16(&mut bufr).unwrap(),
                                )
                            })
                            .collect(),
                        (0..len0)
                            .map(|_| unpack_f32_2(&mut bufr).unwrap())
                            .collect::<Vec<(f32, f32)>>(),
                    )
                })
                .zip(mzml_fs)
                .filter(|x| x.1.is_ref)
                .take(count_s)
                .map(|x| x.0)
        })
        .collect::<Vec<(f32, Vec<(u16, u16)>, Vec<(f32, f32)>)>>();
    let eics = t_to_istd
        .iter()
        .flat_map(|valid_t| {
            let file_path = Path::new(crate::MISCDIR).join(["te_", &valid_t.cqq].concat());
            let mut bufr = BufReader::new(File::open(file_path).unwrap());
            (0..)
                .map(move |_| get_eic(&mut bufr).unwrap())
                .zip(mzml_fs)
                .filter(|x| x.1.is_ref)
                .take(count_s)
                .map(|x| x.0)
        })
        .collect::<Vec<Vec<(f32, f32)>>>();

    for (i, FileA { mzml_f, .. }) in mzml_fs.iter().filter(|x| x.is_ref).enumerate() {
        let file_path = Path::new(crate::MISCDIR).join(["se_", mzml_f].concat());
        let mut bufw = BufWriter::new(File::create(file_path)?);
        for (rt_i_l, (sh, se_vec, bl_vec)) in eics[i..]
            .iter()
            .step_by(count_s)
            .zip(se_pos[i..].iter().step_by(count_s))
        {
            bufw.write_all(&u16::try_from(rt_i_l.len())?.to_le_bytes())?;
            for (x, y) in rt_i_l {
                bufw.write_all(&x.to_le_bytes())?;
                bufw.write_all(&y.to_le_bytes())?;
            }
            bufw.write_all(&sh.to_le_bytes())?;
            bufw.write_all(&u8::try_from(se_vec.len())?.to_le_bytes())?;
            for (sta_, end_) in se_vec {
                bufw.write_all(&sta_.to_le_bytes())?;
                bufw.write_all(&end_.to_le_bytes())?;
            }
            for bl in bl_vec {
                bufw.write_all(&bl.0.to_le_bytes())?;
                bufw.write_all(&bl.1.to_le_bytes())?;
            }
        }
    }
    Ok(())
}
#[must_use]
pub fn find_closest(vec: &[(f32, f32)], pt: f32, pos: usize) -> usize {
    if pos == vec.len() || (pos > 0 && pt - vec[pos - 1].0 <= vec[pos].0 - pt) {
        pos - 1
    } else {
        pos
    }
}
