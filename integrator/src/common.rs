use std::error::Error;
use std::fs::File;
use std::io;
use std::io::{BufRead, BufReader, BufWriter, Read, Write};
use std::path::{Path, PathBuf};

pub fn read_param() -> Result<crate::Param, Box<dyn Error>> {
    let (mut param, mzml_glob, notes) = parse_param(&std::fs::read_to_string("param.txt")?)?;
    for note in notes {
        println!("param.txt: {note}");
    }
    param.mzml_fs = glob::glob(&mzml_glob)?.filter_map(Result::ok).collect();
    if param.mzml_fs.is_empty() {
        return Err("mzML files not found".into());
    }
    Ok(param)
}
/// Parses param.txt. Settings that are missing (e.g. in a param.txt from an older version) take their documented
/// defaults and unknown ones are ignored; both are listed in the returned notes. Whole numbers are accepted where a
/// decimal is expected. Returns the parameters (without the mzML files), the mzML path pattern and the notes.
fn parse_param(text: &str) -> Result<(crate::Param, String, Vec<String>), Box<dyn Error>> {
    const KNOWN: [&str; 11] = [
        "mzML_files",
        "batch_info",
        "transition_list",
        "peak_width",
        "num_threads",
        "mz_tol",
        "RT_tol",
        "RT_shift",
        "RT_shift_bound",
        "crop_window",
        "sn_noise",
    ];
    let table = text.parse::<toml::Table>()?;
    let mut defaults = Vec::new();
    let number = |key: &str, x: &toml::Value| match x {
        toml::Value::Float(x) => Ok(*x as f32),
        toml::Value::Integer(x) => Ok(*x as f32),
        _ => Err(format!(
            "{key} in param.txt must be a number or a list of numbers"
        )),
    };
    let mut numbers = |key: &'static str, default: &[f32]| -> Result<Vec<f32>, String> {
        let Some(x) = table.get(key) else {
            defaults.push(match default {
                [x] => format!("{key} = {x}"),
                _ => format!("{key} = {default:?}"),
            });
            return Ok(default.to_vec());
        };
        let x: Vec<f32> = match x.as_array() {
            Some(a) => a.iter().map(|x| number(key, x)).collect::<Result<_, _>>()?,
            None => vec![number(key, x)?],
        };
        if x.len() == default.len() {
            Ok(x)
        } else {
            Err(format!(
                "{key} in param.txt must have {} value(s), e.g. {default:?}",
                default.len()
            ))
        }
    };
    let peak_w = numbers("peak_width", &[0.17, 0.05, 0.1, 0.35])?;
    let rt_shift = numbers("RT_shift", &[-0.2, 0.2])?;
    let mz_tol = numbers("mz_tol", &[0.06])?[0];
    let rt_tol = numbers("RT_tol", &[0.1])?[0];
    let rt_shift_bd = numbers("RT_shift_bound", &[0.1])?[0];
    let num_t = numbers("num_threads", &[2.])?[0];
    let crop_window = match table.get("crop_window") {
        None => None,
        Some(_) => Some(numbers("crop_window", &[0., 0.])?),
    };
    let mut text = |key: &str, default: &str| -> Result<String, String> {
        match table.get(key) {
            None => {
                defaults.push(format!("{key} = '{default}'"));
                Ok(default.to_owned())
            }
            Some(x) => x.as_str().map(str::to_owned).ok_or_else(|| {
                format!("{key} in param.txt must be text in quotes, e.g. '{default}'")
            }),
        }
    };
    let mzml_glob = text("mzML_files", "mzML/*.mzML")?;
    let batch_i = PathBuf::from(text("batch_info", "run_order.csv")?);
    let t_list = PathBuf::from(text("transition_list", "feature_list.csv")?);
    let sn_noise = match text("sn_noise", "robust")?.as_str() {
        "robust" => Noise::Robust,
        "rms" => Noise::Rms,
        "p2p" => Noise::P2p,
        x => {
            return Err(format!(
                "sn_noise in param.txt must be robust, rms or p2p (found: {x})"
            )
            .into());
        }
    };
    let mut notes = Vec::new();
    // sn_noise is new and optional: only report it when other settings were missing too
    if defaults.iter().any(|x| !x.starts_with("sn_noise")) {
        notes.push(format!("not set, using defaults: {}", defaults.join(", ")));
    }
    let unknown: Vec<&str> = table
        .keys()
        .map(String::as_str)
        .filter(|x| !KNOWN.contains(x))
        .collect();
    if !unknown.is_empty() {
        notes.push(format!(
            "ignored (not used by this version): {}",
            unknown.join(", ")
        ));
    }
    let param = crate::Param {
        mzml_fs: Vec::new(),
        batch_i,
        t_list,
        num_t: num_t.max(1.) as usize,
        mz_tol,
        rt_tol,
        crop_window: crop_window.map(|x| (x[0], x[1])),
        peak_w: (peak_w[0], peak_w[1], peak_w[2], peak_w[3]),
        rt_shift: (rt_shift[0], rt_shift[1]),
        rt_shift_bd,
        sn_noise,
    };
    Ok((param, mzml_glob, notes))
}
/// Noise estimate of the signal-to-noise ratio in long.csv (`sn_noise` in param.txt).
#[derive(Clone, Copy)]
pub enum Noise {
    Robust,
    Rms,
    P2p,
}
impl Noise {
    pub fn name(self) -> &'static str {
        match self {
            Noise::Robust => "robust",
            Noise::Rms => "rms",
            Noise::P2p => "p2p",
        }
    }
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
                mzml_f: x[0].to_owned(),
                ftype: x[1].to_owned(),
                ts: x[2].to_owned(),
                batchno: x[3].to_owned(),
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

#[cfg(test)]
mod tests {
    use super::parse_param;

    #[test]
    fn empty_param_uses_defaults() {
        let (p, mzml, notes) = parse_param("").unwrap();
        assert_eq!(mzml, "mzML/*.mzML");
        assert_eq!(p.batch_i.to_str(), Some("run_order.csv"));
        assert_eq!(p.peak_w, (0.17, 0.05, 0.1, 0.35));
        assert_eq!(
            (p.num_t, p.mz_tol, p.rt_tol, p.rt_shift, p.rt_shift_bd),
            (2, 0.06, 0.1, (-0.2, 0.2), 0.1)
        );
        assert!(p.crop_window.is_none());
        assert!(
            notes[0].starts_with("not set, using defaults: peak_width"),
            "{notes:?}"
        );
    }

    #[test]
    fn older_param_works_and_obsolete_settings_are_noted() {
        // complete settings of an older version, without sn_noise, with the removed fill_RT
        let old = "mzML_files = 'mzML/*.mzML'\nbatch_info = 'run_order.csv'\npeak_width = [0.17, 0.05, 0.1, 0.35]\n\
                   transition_list = 'feature_list.csv'\nnum_threads = 8\nmz_tol = 0.06\nRT_tol = 0.04\n\
                   fill_RT = false\nRT_shift = [-0.1, 0.4]\nRT_shift_bound = 0.05\n";
        let (p, _, notes) = parse_param(old).unwrap();
        assert_eq!((p.num_t, p.rt_tol, p.rt_shift), (8, 0.04, (-0.1, 0.4)));
        assert_eq!(p.sn_noise.name(), "robust");
        assert_eq!(notes, ["ignored (not used by this version): fill_RT"]);
    }

    #[test]
    fn whole_numbers_are_accepted() {
        let (p, _, _) =
            parse_param("RT_tol = 1\nRT_shift = [0, 0]\ncrop_window = [1, 2.5]").unwrap();
        assert_eq!(
            (p.rt_tol, p.rt_shift, p.crop_window),
            (1., (0., 0.), Some((1., 2.5)))
        );
    }

    #[test]
    fn wrong_values_give_a_message() {
        let msg = |t| parse_param(t).err().unwrap().to_string();
        assert!(msg("RT_tol = 'x'").contains("RT_tol in param.txt must be a number"));
        assert!(msg("RT_shift = [0.1]").contains("RT_shift in param.txt must have 2 value(s)"));
        assert!(msg("batch_info = 3").contains("batch_info in param.txt must be text"));
        assert!(msg("sn_noise = 'mad'").contains("must be robust, rms or p2p"));
    }
}
