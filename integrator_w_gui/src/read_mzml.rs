use rayon::prelude::*;
use std::error::Error;
use std::fs::File;
use std::io::{BufReader, BufWriter, Write};
use std::path::Path;
// declares the low level mzml parser
mod parse;

// limits the source mzml data held in one parsing batch
const MAX_MZML_BATCH_BYTES: u64 = 256 * 1024 * 1024;

// validates the inputs and extracts every requested chromatogram
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
    let mut time_stamp = Vec::with_capacity(mzml_fs.len());
    {
        let mut wtr = csv::WriterBuilder::new().from_path("ambiguous_assignment.csv")?;
        wtr.write_record(["Transition Name", "chromatogram index"])?;
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
    let mut batch_start = 0;
    while batch_start < mzml_fs.len() {
        let batch_end = mzml_batch_end(&mzml_fs, batch_start)?;
        let mzml_fs_ = &mzml_fs[batch_start..batch_end];
        let (mut ts, q1q3eics): (Vec<String>, Vec<Vec<parse::Q1Q3RtI>>) =
            mzml_fs_.par_iter().map(|(bn, ..)| parse::mzml(bn)).unzip();
        time_stamp.append(&mut ts);
        trans_f.iter().zip(&t_list).for_each(|(trans_f_i, trans)| {
            write_block(&q1q3eics, mzml_fs_, trans, trans_f_i, param_t).unwrap();
        });
        batch_start = batch_end;
        println!("{batch_start}/{}", mzml_fs.len());
    }
    write_mzml_list(&mzml_fs, &time_stamp)?;
    write_miss_cpd(&t_list, &mzml_fs, &trans_f)
}
// stores one transition from the assay definition
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
// returns a normalized header token for flexible csv column matching
fn normalized_header(header: &str) -> String {
    header
        .trim()
        .split_once(' ')
        .map_or(header.trim(), |(prefix, _)| prefix)
        .trim_matches(|character: char| character == '(' || character == ')')
        .chars()
        .map(|character| match character {
            ' ' | '-' => '_',
            _ => character.to_ascii_lowercase(),
        })
        .collect()
}

// finds a csv column by any accepted header name
fn find_col(header: &csv::StringRecord, names: &[&str]) -> Option<usize> {
    let names = names
        .iter()
        .map(|name| normalized_header(name))
        .collect::<Vec<_>>();
    header.iter().position(|column| {
        let column = normalized_header(column);
        names.iter().any(|name| &column == name)
    })
}

// finds a required csv column, with a clear upstream-compatible error
fn require_col(header: &csv::StringRecord, names: &[&str]) -> Result<usize, Box<dyn Error>> {
    find_col(header, names).ok_or_else(|| format!("{} column not found!", names[0]).into())
}

// reads and validates the transition assay
fn read_assay(assay_f: &Path) -> Result<Vec<QQ>, Box<dyn Error>> {
    fn cell(record: &csv::StringRecord, column: usize) -> &str {
        record.get(column).unwrap_or("")
    }

    let mut rdr = csv::ReaderBuilder::new()
        .comment(Some(b'#'))
        .has_headers(true)
        .trim(csv::Trim::All)
        .from_path(assay_f)?;
    let headers = rdr.headers()?.clone();
    let compound_col = require_col(&headers, &["Feature_ID", "Compound Name"])?;
    let transition_col = require_col(&headers, &["Transition_Name", "Transition Name"])?;
    let istd_col = require_col(&headers, &["ISTD_Feature_ID", "ISTD"])?;
    let precursor_col = require_col(&headers, &["Precursor_mz", "Precursor Ion"])?;
    let product_col = require_col(&headers, &["Product_mz", "Product Ion"])?;
    let rt_col = require_col(&headers, &["RT"])?;
    let uniform_col = require_col(
        &headers,
        &["uniform_width", "uniform_width (y/n)", "uniform width"],
    )?;
    let left_bound_col = require_col(
        &headers,
        &[
            "begin_RT",
            "left integration bound",
            "left integration bound (integration will not start earlier than the set RT)",
        ],
    )?;
    let right_bound_col = require_col(
        &headers,
        &[
            "end_RT",
            "right integration bound",
            "right integration bound (integration must end before the set RT)",
        ],
    )?;
    let fixed_col = find_col(&headers, &["fixed", "fixed(y/n)"]);
    let peak_width_col = find_col(&headers, &["peak_width", "peak width"]);
    let baseline_col = find_col(&headers, &["baseline"]);
    let index_col = find_col(&headers, &["chromatogram_index", "chromatogram index"]);
    let mut records: Vec<csv::StringRecord> = rdr.into_records().collect::<Result<_, _>>()?;
    let is_yes = |value: &str| {
        matches!(
            value.trim().to_ascii_lowercase().as_str(),
            "y" | "yes" | "true" | "1"
        )
    };
    records.sort_unstable_by(|x, y| cell(x, transition_col).cmp(cell(y, transition_col)));
    let mut t_name: Vec<&str> = records
        .iter()
        .map(|record| cell(record, transition_col))
        .collect();
    t_name.dedup();
    let mut pos0 = 0;
    let mut pos1 = 0;
    t_name
        .into_iter()
        .map(|name| {
            pos0 = pos1;
            pos1 = (pos0 + 1..records.len())
                .find(|x| cell(&records[*x], transition_col) != name)
                .unwrap_or(records.len());
            let rec_p = &records[pos0];
            for x in &records[pos0 + 1..pos1] {
                if cell(x, precursor_col) != cell(rec_p, precursor_col)
                    || cell(x, product_col) != cell(rec_p, product_col)
                {
                    return Err([cell(rec_p, compound_col), cell(rec_p, transition_col)]
                        .join(", ")
                        .into());
                }
            }
            let mut rt_iso: Vec<(f32, _, f32, f32)> = records[pos0..pos1]
                .iter()
                .map(|x| {
                    let fixed_bounds = fixed_col.map_or(true, |column| is_yes(cell(x, column)));
                    let left_bound = fixed_bounds
                        .then(|| cell(x, left_bound_col).parse().unwrap_or(-90.))
                        .unwrap_or(-90.);
                    let right_bound = fixed_bounds
                        .then(|| cell(x, right_bound_col).parse().unwrap_or(990.))
                        .unwrap_or(990.);
                    cell(x, rt_col)
                        .parse()
                        .map_err(|_| {
                            format!(
                                "{}, {}, RT = {}",
                                cell(x, compound_col),
                                cell(x, transition_col),
                                cell(x, rt_col)
                            )
                        })
                        .map(|rt| {
                            (
                                rt,
                                cell(x, compound_col).to_string(),
                                left_bound,
                                right_bound,
                            )
                        })
                })
                .collect::<Result<_, _>>()?;
            if let Some(x) = rt_iso.iter().find(|x| x.1.is_empty()) {
                rt_iso = vec![x.clone()];
            }
            rt_iso.sort_unstable_by(|x, y| x.0.partial_cmp(&y.0).unwrap());
            let Ok(q1) = cell(rec_p, precursor_col).parse::<f32>() else {
                return Err(["precursor m/z for ", name].concat().into());
            };
            let Ok(q3) = cell(rec_p, product_col).parse::<f32>() else {
                return Err(["product m/z for ", name].concat().into());
            };
            Ok(QQ {
                name: cell(rec_p, transition_col).to_string(),
                istd: if cell(rec_p, istd_col).is_empty() {
                    cell(rec_p, transition_col)
                } else {
                    cell(rec_p, istd_col)
                }
                .to_string(),
                q1,
                q3,
                rt: rt_iso.iter().map(|x| x.0).sum::<f32>() / (rt_iso.len() as f32),
                rt_iso,
                u_rt: is_yes(cell(rec_p, uniform_col)),
                peak_w: peak_width_col
                    .and_then(|column| rec_p.get(column))
                    .and_then(|value| {
                        let mut iter = value.split(',');
                        let parse = |x: &str| x.trim().parse().ok();
                        Some((
                            parse(iter.next()?)?,
                            parse(iter.next()?)?,
                            parse(iter.next()?)?,
                            parse(iter.next()?)?,
                        ))
                    }),
                baseline: baseline_col
                    .and_then(|column| rec_p.get(column))
                    .unwrap_or("default")
                    .to_string(),
                index: index_col
                    .and_then(|column| rec_p.get(column))
                    .and_then(|value| value.parse().ok()),
            })
        })
        .collect::<Result<_, Box<dyn Error>>>()
}
// describes one ordered mzml sample and its processing roles
type FileD<'a, 'b> = (&'a Path, &'b str, &'b str, bool, bool);
// finds the largest source file batch within the memory budget
fn mzml_batch_end(mzml_fs: &[FileD], start: usize) -> std::io::Result<usize> {
    let mut batch_bytes: u64 = 0;
    let mut end = start;
    while end < mzml_fs.len() {
        let file_bytes = std::fs::metadata(mzml_fs[end].0)?.len();
        if end > start && batch_bytes.saturating_add(file_bytes) > MAX_MZML_BATCH_BYTES {
            break;
        }
        batch_bytes = batch_bytes.saturating_add(file_bytes);
        end += 1;
    }
    Ok(end)
}
// removes incomplete transitions and writes the validated transition files
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
    let baseline_path = Path::new(crate::MISCDIR).join(crate::TRANS_BL);
    let mut baseline_bufw = BufWriter::new(File::create(baseline_path)?);
    v_trans_w_is.sort_unstable_by_key(|x| x.1);
    bufw.write_all(&u16::try_from(v_trans_w_is.len())?.to_le_bytes())?;
    baseline_bufw.write_all(&u16::try_from(v_trans_w_is.len())?.to_le_bytes())?;
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
        baseline_bufw.write_all(trans.baseline.as_bytes())?;
        baseline_bufw.write_all(b"\0")?;
    }
    let mut legacy_wtr =
        csv::WriterBuilder::new().from_path(Path::new(crate::MISCDIR).join("trans_R.csv"))?;
    legacy_wtr.write_record([
        "numeric ID",
        "transition name",
        "precursor",
        "product",
        "uniform",
        "left view bound",
        "right view bound",
    ])?;
    let mut extended_wtr =
        csv::WriterBuilder::new().from_path(Path::new(crate::MISCDIR).join("trans_R_v2.csv"))?;
    extended_wtr.write_record([
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
        legacy_wtr.write_record([
            &trans_f_i[2..],
            &trans.name,
            &format!("{:.3}", trans.q1),
            &format!("{:.3}", trans.q3),
            if trans.u_rt { "1" } else { "0" },
            "",
            "",
        ])?;
        extended_wtr.write_record([
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
// writes the ordered mzml sample metadata list
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
// extracts and writes one transition block for a group of samples
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

// creates an empty binary file for every assay transition
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
// matches available mzml files to the batch information
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
// describes one row of ordered batch information
type FileO = (String, String, String, bool, bool, usize);
// reads and sorts the batch information by filename
fn read_file_ord(batch_i_file: &Path) -> Result<Vec<FileO>, Box<dyn Error>> {
    let mut rdr = csv::ReaderBuilder::new()
        .comment(Some(b'#'))
        .has_headers(true)
        .trim(csv::Trim::All)
        .from_path(batch_i_file)?;
    let headers = rdr.headers()?.clone();
    let filename_col = require_col(&headers, &["file_name", "file name"])?;
    let batch_col = require_col(&headers, &["batch"])?;
    let sample_type_col = require_col(&headers, &["sample_type", "sample type"])?;
    let reference_col = require_col(
        &headers,
        &[
            "reference",
            "reference (indicate at least one sample to be used for RT shift estimation)",
        ],
    )?;
    let learn_col = find_col(&headers, &["learn"]);
    let mut file_ord: Vec<_> = rdr
        .into_records()
        .enumerate()
        .map(|(i, rec)| {
            rec.map(|x| {
                (
                    x[filename_col].to_string(),
                    x[batch_col].to_string(),
                    x[sample_type_col].to_string(),
                    !x[reference_col].trim().is_empty(),
                    learn_col.map_or(true, |column| !x[column].trim().is_empty()),
                    i,
                )
            })
        })
        .collect::<Result<_, _>>()?;
    file_ord.sort_unstable_by(|x, y| x.0.cmp(&y.0));
    Ok(file_ord)
}
