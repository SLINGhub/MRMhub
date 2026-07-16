use rayon::prelude::*;
use std::error::Error;
use std::fs::File;
use std::io::{BufReader, BufWriter, Write};
use std::path::Path;
mod parse;
pub fn read(param_t: &crate::Param) -> Result<(), Box<dyn Error>> {
    let t_list = read_assay(&param_t.t_list)?;
    let mut prev: &str = "";
    for trans in &t_list {
        if prev != trans.istd {
            if let Ok(pos0) = t_list.binary_search_by_key(&&trans.istd, |x| &x.name) {
                let t_list_i = &t_list[pos0];
                if t_list_i.name != t_list_i.istd {
                    return Err(format!(
                        "Internal standard {} with {} indicated as internal standard",
                        t_list_i.name, t_list_i.istd
                    )
                    .into());
                }
                prev = &trans.istd;
            } else {
                return Err(format!("Internal standard {} not found", trans.istd).into());
            }
        }
    }
    let file_ord = read_file_ord(&param_t.batch_i)?;
    let mzml_fs = filter_mzml(param_t, &file_ord)?;
    File::create("missing_details.txt")?;
    let _ = std::fs::remove_dir_all(crate::MISCDIR);
    std::fs::create_dir(crate::MISCDIR)?;
    let trans_f = create_t_files(&t_list)?;
    let nfile = (mzml_fs.len() as f32 / (mzml_fs.len() as f32 / 600.).ceil()).ceil() as usize;
    let mut time_stamp = Vec::with_capacity(mzml_fs.len());
    {
        let mut wtr = csv::WriterBuilder::new().from_path("ambiguous_assignment.csv")?;
        wtr.write_record(["Transition_Name", "chromatogram_index"])?;
        let (_, qq) = parse::mzml(mzml_fs[0].0);
        let &crate::Param { mz_tol, .. } = param_t;
        for trans in &t_list {
            let pos0 = trans.q1 - mz_tol;
            let pos0 = qq.partition_point(|x| x.q1 < pos0);
            let ma: Vec<u16> = qq[pos0..]
                .iter()
                .take_while(|x| x.q1 < trans.q1 + mz_tol)
                .filter(|x| {
                    let sta = x.rt_i_l[0].0;
                    let end = x.rt_i_l[x.rt_i_l.len() - 1].0;
                    (x.q3 - trans.q3).abs() < mz_tol && sta < trans.rt && trans.rt < end
                })
                .map(|x| x.ord)
                .collect();
            if ma.len() > 1 {
                wtr.write_record([
                    &trans.name,
                    &ma.iter()
                        .map(std::string::ToString::to_string)
                        .collect::<Vec<_>>()
                        .join(", "),
                ])?;
            }
        }
    }
    for (i, mzml_fs_) in (1..).zip(mzml_fs.chunks(nfile)) {
        let (mut ts, q1q3eics): (Vec<String>, Vec<Vec<parse::Q1Q3RtI>>) =
            mzml_fs_.par_iter().map(|(bn, ..)| parse::mzml(bn)).unzip();
        time_stamp.append(&mut ts);
        trans_f.iter().zip(&t_list).for_each(|(trans_f_i, trans)| {
            write_block(&q1q3eics, mzml_fs_, trans, trans_f_i, param_t).unwrap();
        });
        println!("{}/{}", i * nfile, mzml_fs.len());
    }
    write_mzml_list(&mzml_fs, &time_stamp)?;
    write_miss_cpd(&t_list, &mzml_fs, &trans_f)
}
struct QQ {
    name: String,
    rt_iso: Vec<(f32, String, f32, f32)>,
    istd: String,
    q1: f32,
    q3: f32,
    rt: f32,
    u_rt: bool,
    peak_w: Option<(f32, f32, f32, f32)>,
    baseline: String,
    index: Option<u16>,
}
fn read_assay(assay_f: &Path) -> Result<Vec<QQ>, Box<dyn Error>> {
    let mut rdr = csv::ReaderBuilder::new()
        .comment(Some(b'#'))
        .has_headers(true)
        .trim(csv::Trim::All)
        .from_path(assay_f)?;
    let header = rdr.headers()?;
    let get_col = |name: &str| -> Result<usize, Box<dyn Error>> {
        header
            .iter()
            .position(|x| {
                x.split_once(' ').map_or_else(
                    || x.eq_ignore_ascii_case(name),
                    |x| x.0.eq_ignore_ascii_case(name),
                )
            })
            .ok_or_else(|| format!("{name} column not found!").into())
    };
    let feat_id_c = get_col("Feature_ID")?;
    let t_name_c = get_col("Transition_Name")?;
    let istd_c = get_col("ISTD_Feature_ID")?;
    let q1_c = get_col("Precursor_Ion")?;
    let q3_c = get_col("Product_Ion")?;
    let rt_c = get_col("RT")?;
    let unif_c = get_col("uniform_width")?;
    let srt_c = get_col("start_RT")?;
    let ert_c = get_col("end_RT")?;
    let pw_c = get_col("peak_width")?;
    let bl_c = get_col("baseline")?;
    let ci_c = get_col("chromatogram_index")?;

    let mut records: Vec<csv::StringRecord> = rdr.into_records().collect::<Result<_, _>>()?;
    records.sort_unstable_by(|x, y| x[t_name_c].cmp(&y[t_name_c]));
    let mut t_name: Vec<&str> = records.iter().map(|x| &x[t_name_c]).collect();
    t_name.dedup();
    let mut pos0 = 0;
    let mut pos1 = 0;
    t_name
        .into_iter()
        .map(|name| {
            pos0 = pos1;
            pos1 = (pos0 + 1..records.len())
                .find(|x| &records[*x][t_name_c] != name)
                .unwrap_or(records.len());
            let rec_p = &records[pos0];
            for x in &records[pos0 + 1..pos1] {
                if x[q1_c] != rec_p[q1_c] || x[q3_c] != rec_p[q3_c] {
                    return Err([&rec_p[feat_id_c], &rec_p[t_name_c]].join(", ").into());
                }
            }
            let mut rt_iso: Vec<(f32, _, f32, f32)> = records[pos0..pos1]
                .iter()
                .map(|x| {
                    x[rt_c]
                        .parse()
                        .map_err(|_| {
                            format!("{}, {}, RT = {}", &x[feat_id_c], &x[t_name_c], &x[rt_c])
                        })
                        .map(|rt| {
                            (
                                rt,
                                x[feat_id_c].to_string(),
                                x[srt_c].parse().unwrap_or(-90.),
                                x[ert_c].parse().unwrap_or(990.),
                            )
                        })
                })
                .collect::<Result<_, _>>()?;
            if let Some(x) = rt_iso.iter().find(|x| x.1.is_empty()) {
                rt_iso = vec![x.clone()];
            }
            rt_iso.sort_unstable_by(|x, y| x.0.partial_cmp(&y.0).unwrap());
            let Ok(q1) = rec_p[q1_c].parse::<f32>() else {
                return Err(["precursor m/z for ", name].concat().into());
            };
            let Ok(q3) = rec_p[q3_c].parse::<f32>() else {
                return Err(["product m/z for ", name].concat().into());
            };
            Ok(QQ {
                name: rec_p[t_name_c].to_string(),
                istd: rec_p[if rec_p[istd_c].is_empty() {
                    t_name_c
                } else {
                    istd_c
                }]
                .to_string(),
                q1,
                q3,
                rt: rt_iso.iter().map(|x| x.0).sum::<f32>() / (rt_iso.len() as f32),
                rt_iso,
                u_rt: rec_p[unif_c].eq_ignore_ascii_case("y"),
                peak_w: {
                    let mut iter = rec_p[pw_c]
                        .trim()
                        .trim_start_matches('[')
                        .trim_end_matches(']')
                        .split(',');
                    let p0 = |x: &str| x.trim().parse().ok();
                    (|| {
                        Some((
                            p0(iter.next()?)?,
                            p0(iter.next()?)?,
                            p0(iter.next()?)?,
                            p0(iter.next()?)?,
                        ))
                    })()
                },
                baseline: rec_p[bl_c].to_string(),
                index: rec_p[ci_c].parse().ok(),
            })
        })
        .collect::<Result<_, Box<dyn Error>>>()
}
type FileD<'a, 'b> = (&'a Path, &'b str, &'b str, bool, bool);
fn write_miss_cpd(
    t_list: &[QQ],
    mzml_fs: &[FileD],
    trans_f: &[String],
) -> Result<(), Box<dyn Error>> {
    let mut valid_trans = Vec::with_capacity(t_list.len());
    let mut remove_l = Vec::new();
    let mut bufw = BufWriter::new(File::create("missing_compounds.txt")?);
    for (trans_f_i, trans) in trans_f.iter().zip(t_list) {
        let file_path = Path::new(crate::MISCDIR).join(trans_f_i);
        let bufre = &mut BufReader::new(File::open(file_path)?);
        let cs: usize = (0..mzml_fs.len())
            .take_while(|_| crate::common::get_eic(bufre).is_ok())
            .count();
        if cs < mzml_fs.len() {
            writeln!(
                bufw,
                "removed \"{}\". Present in {}/{} samples",
                trans.name,
                cs,
                mzml_fs.len()
            )?;
            remove_l.push(trans_f_i);
        } else {
            valid_trans.push((trans, trans_f_i));
        }
    }
    let mut v_trans_w_is = Vec::<(&QQ, &str, usize)>::new();
    for (trans, trans_f_i) in &valid_trans {
        if let Ok(pos0) = valid_trans.binary_search_by_key(&&trans.istd, |x| &x.0.name) {
            v_trans_w_is.push((trans, trans_f_i, pos0));
        } else {
            remove_l.push(trans_f_i);
            writeln!(bufw, "ISTD not found for {}", trans.name)?;
        }
    }
    if !remove_l.is_empty() {
        use yansi::Paint;
        println!("Check {}.", "missing_compounds.txt".bold().underline());
    }
    let file_path = Path::new(crate::MISCDIR).join(crate::TRANS_L);
    let mut bufw = BufWriter::new(File::create(file_path)?);
    v_trans_w_is.sort_unstable_by_key(|x| x.1);
    bufw.write_all(&u16::try_from(v_trans_w_is.len())?.to_le_bytes())?;
    for &(trans, trans_f_i, pos) in &v_trans_w_is {
        bufw.write_all(trans_f_i.split_once('_').unwrap().1.as_bytes())?;
        bufw.write_all(b"\0")?;
        bufw.write_all(trans.name.as_bytes())?;
        bufw.write_all(b"\0")?;
        bufw.write_all(valid_trans[pos].1.split_once('_').unwrap().1.as_bytes())?;
        bufw.write_all(b"\0")?;
        bufw.write_all(&trans.q1.to_le_bytes())?;
        bufw.write_all(&trans.q3.to_le_bytes())?;
        bufw.write_all(&u8::from(trans.u_rt).to_le_bytes())?;
        bufw.write_all(&u8::try_from(trans.rt_iso.len())?.to_le_bytes())?;
        for (rt, name, beg, end) in &trans.rt_iso {
            bufw.write_all(&rt.to_le_bytes())?;
            bufw.write_all(name.as_bytes())?;
            bufw.write_all(b"\0")?;
            bufw.write_all(&beg.to_le_bytes())?;
            bufw.write_all(&end.to_le_bytes())?;
        }
        if let Some(peak_w) = trans.peak_w {
            bufw.write_all(&4u8.to_le_bytes())?;
            bufw.write_all(&peak_w.0.to_le_bytes())?;
            bufw.write_all(&peak_w.1.to_le_bytes())?;
            bufw.write_all(&peak_w.2.to_le_bytes())?;
            bufw.write_all(&peak_w.3.to_le_bytes())?;
        } else {
            bufw.write_all(&0u8.to_le_bytes())?;
        }
        bufw.write_all(trans.baseline.as_bytes())?;
        bufw.write_all(b"\0")?;
    }
    let mut wtr =
        csv::WriterBuilder::new().from_path(Path::new(crate::MISCDIR).join("trans_R.csv"))?;
    wtr.write_record([
        "numeric ID",
        "transition name",
        "precursor",
        "product",
        "uniform",
        "baseline",
        "left view bound",
        "right view bound",
    ])?;
    for (trans, trans_f_i, _) in &v_trans_w_is {
        wtr.write_record([
            &trans_f_i[2..],
            &trans.name,
            &format!("{:.3}", trans.q1),
            &format!("{:.3}", trans.q3),
            if trans.u_rt { "1" } else { "0" },
            &trans.baseline,
            "",
            "",
        ])?;
    }
    Ok(())
}
fn write_mzml_list(mzml_fs: &[FileD], time_stamp: &[String]) -> std::io::Result<()> {
    let file_path = Path::new(crate::MISCDIR).join(crate::MZML_L);
    let mut wtr = csv::WriterBuilder::new()
        .delimiter(b'\t')
        .from_path(file_path)?;
    for ((mzml_f, batchno, ftype, is_ref, is_learn), ts) in mzml_fs.iter().zip(time_stamp) {
        wtr.write_record([
            mzml_f.file_name().unwrap().to_str().unwrap(),
            &ftype.to_ascii_uppercase(),
            ts,
            batchno,
            if *is_ref { "1" } else { "0" },
            if *is_learn { "1" } else { "0" },
        ])?;
    }
    Ok(())
}
fn write_block(
    q1q3eics: &[Vec<parse::Q1Q3RtI>],
    mzml_fs: &[FileD],
    trans: &QQ,
    trans_f_i: &str,
    param_t: &crate::Param,
) -> Result<(), Box<dyn Error>> {
    let &crate::Param {
        mz_tol,
        crop_window,
        ..
    } = param_t;
    let file_path = Path::new(crate::MISCDIR).join(trans_f_i);
    let mut bufw = BufWriter::new(File::options().append(true).open(file_path)?);
    let mut missing_f = Vec::new();
    for (qq, (mzml_f, ..)) in q1q3eics.iter().zip(mzml_fs) {
        let pos0 = trans.q1 - mz_tol;
        let pos0 = qq.partition_point(|x| x.q1 < pos0);
        let iter = qq[pos0..].iter().take_while(|x| x.q1 < trans.q1 + mz_tol);
        let i: Option<&parse::Q1Q3RtI> = trans
            .index
            .and_then(|i| {
                iter.clone()
                    .filter(|x| (x.q3 - trans.q3).abs() < mz_tol)
                    .find(|x| x.ord == i)
            })
            .or_else(|| {
                iter.clone()
                    .filter_map(|x| {
                        let sta = x.rt_i_l[0].0;
                        let end = x.rt_i_l[x.rt_i_l.len() - 1].0;
                        ((x.q3 - trans.q3).abs() < mz_tol && sta < trans.rt && trans.rt < end)
                            .then(|| (x, (trans.rt - sta.midpoint(end)).abs()))
                    })
                    .min_by(|x, y| x.1.partial_cmp(&y.1).unwrap())
                    .map(|x| x.0)
            });
        if let Some(i) = i {
            bufw.write_all(&i.ce.to_le_bytes())?;
            bufw.write_all(&u8::from(i.polarity).to_le_bytes())?;
            let rt_in: &[(f32, f32)] = if let Some(cw) = crop_window {
                let pos1 = trans.rt + cw.1;
                let pos1 = i.rt_i_l.partition_point(|x| x.0 < pos1);
                let pos0 = trans.rt - cw.0;
                let pos0 = i.rt_i_l[..pos1].partition_point(|x| x.0 < pos0);
                &i.rt_i_l[pos0..pos1]
            } else {
                &i.rt_i_l
            };
            bufw.write_all(&u16::try_from(rt_in.len())?.to_le_bytes())?;
            for (x, y) in rt_in {
                bufw.write_all(&x.to_le_bytes())?;
                bufw.write_all(&y.to_le_bytes())?;
            }
        } else {
            missing_f.push(mzml_f);
        }
    }
    let mut bufw = BufWriter::new(File::options().append(true).open("missing_details.txt")?);
    for mzml_f in missing_f {
        writeln!(
            bufw,
            "\"{}\" not in \"{}\"",
            trans.name,
            mzml_f.file_name().unwrap().display()
        )?;
    }
    Ok(())
}

fn create_t_files(t_list: &[QQ]) -> std::io::Result<Vec<String>> {
    (0..t_list.len())
        .map(|i| {
            let trans_f_i = format!("te_{i:0>4}");
            let file_path = Path::new(crate::MISCDIR).join(&trans_f_i);
            File::create(file_path)?;
            Ok(trans_f_i)
        })
        .collect()
}
fn filter_mzml<'a, 'b>(
    param_t: &'a crate::Param,
    file_ord: &'b [FileO],
) -> Result<Vec<FileD<'a, 'b>>, Box<dyn Error>> {
    let mut bufw = BufWriter::new(File::create("missing_files.txt")?);
    let mut miss_flag = false;
    let mut mzml_fs_ord = Vec::<(FileD, usize)>::new();
    for mzml_f in &param_t.mzml_fs {
        let base_n = mzml_f.file_name().unwrap().to_str().unwrap();
        if let Ok(pos0) = file_ord.binary_search_by_key(&base_n, |x| &x.0) {
            let f = &file_ord[pos0];
            mzml_fs_ord.push(((mzml_f.as_path(), &f.1, &f.2, f.3, f.4), f.5));
        } else {
            miss_flag = true;
            writeln!(
                bufw,
                "{:?} not in \"{}\"",
                base_n,
                param_t.batch_i.display()
            )?;
        }
    }
    writeln!(bufw)?;
    let mut files_in_dir: Vec<_> = param_t
        .mzml_fs
        .iter()
        .map(|x| x.file_name().unwrap().to_str().unwrap())
        .collect();
    files_in_dir.sort_unstable();
    for (f0, ..) in file_ord
        .iter()
        .filter(|x| files_in_dir.binary_search(&x.0.as_str()).is_err())
    {
        miss_flag = true;
        writeln!(bufw, "{f0:?} not in directory")?;
    }
    if miss_flag {
        use yansi::Paint;
        println!("Check {}.", "missing_files.txt".bold().underline());
    }
    if !mzml_fs_ord.iter().any(|x| x.0.3) {
        return Err("no reference sample!".into());
    }
    if !mzml_fs_ord.iter().any(|x| x.0.4) {
        return Err("no learning sample!".into());
    }
    mzml_fs_ord.sort_unstable_by_key(|x| x.1);
    Ok(mzml_fs_ord.into_iter().map(|x| x.0).collect())
}
type FileO = (String, String, String, bool, bool, usize);
fn read_file_ord(batch_i_file: &Path) -> std::io::Result<Vec<FileO>> {
    let mut rdr = csv::ReaderBuilder::new()
        .comment(Some(b'#'))
        .has_headers(true)
        .trim(csv::Trim::All)
        .from_path(batch_i_file)?;
    let ncol = rdr.headers()?.len();
    let mut file_ord: Vec<_> = rdr
        .into_records()
        .enumerate()
        .map(|(i, rec)| {
            rec.map(|x| {
                (
                    x[0].to_string(),
                    x[1].to_string(),
                    x[2].to_string(),
                    !x[3].trim().is_empty(),
                    ncol < 5 || !x[4].trim().is_empty(),
                    i,
                )
            })
        })
        .collect::<Result<_, _>>()?;
    file_ord.sort_unstable_by(|x, y| x.0.cmp(&y.0));
    Ok(file_ord)
}
