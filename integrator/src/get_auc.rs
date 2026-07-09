use std::error::Error;
use std::fs::File;
use std::io;
use std::io::{BufReader, BufWriter, Write};
use std::path::Path;

// recalculates peak areas from the retention time matrix
pub fn calc_auc() -> Result<(), Box<dyn Error>> {
    let (s_trans, rt_vec_d) = read_rtmat()?;
    let t_to_istd = crate::common::get_trans_istd()?;
    let area_all = areas(&s_trans, &rt_vec_d, &t_to_istd);
    let mzml_fs = crate::common::get_mzml()?;
    write_long(&s_trans, &area_all, &t_to_istd, &mzml_fs)?;
    write_area(&s_trans, &area_all, &t_to_istd, &mzml_fs)?;
    crate::common::write_by_sample(&t_to_istd, &mzml_fs)
}
// calculates feature measurements for every transition
fn areas(
    s_trans: &[(String, String)],
    rt_vec_d: &[(f32, f32)],
    t_to_istd: &[crate::common::ValidT],
) -> Vec<Vec<RowDat>> {
    let mut trans_name_l: Vec<&str> = s_trans.iter().map(|x| x.0.as_str()).collect();
    trans_name_l.dedup();
    let mut pos0 = 0;
    let mut pos1 = 0;
    trans_name_l
        .into_iter()
        .flat_map(|trans| {
            pos0 = pos1;
            pos1 = (pos0 + 1..s_trans.len())
                .find(|x| s_trans[*x].0.as_str() != trans)
                .unwrap_or(s_trans.len());
            let k: &crate::common::ValidT = {
                let t = s_trans[pos0].0.as_str();
                t_to_istd
                    .binary_search_by_key(&t, |x| &x.cqq)
                    .map_or_else(|_| panic!("{t} transition not found"), |k| &t_to_istd[k])
            };
            let rt_i_all = write_trans(trans, rt_vec_d, (s_trans.len(), pos0, pos1), k).unwrap();
            (pos0..pos1).map(move |i| {
                feat_data(i - pos0, &rt_i_all, &rt_vec_d[i..], s_trans.len(), k).unwrap()
            })
        })
        .collect::<Vec<_>>()
}
// stores one chromatogram with its peak positions and instrument settings
type EicPos = (Vec<(f32, f32)>, Vec<(usize, usize)>, f32, bool);
// updates the binary peak positions for one transition
fn write_trans(
    trans: &str,
    rt_vec_d: &[(f32, f32)],
    (tlen, pos0, pos1): (usize, usize, usize),
    k: &crate::common::ValidT,
) -> Result<Vec<EicPos>, Box<dyn Error>> {
    let file_path = Path::new(crate::MISCDIR).join(["tp_", trans].concat());
    let sh_l: Vec<f32> = {
        use crate::common::{unpack_f32, unpack_u8};
        let bufr = &mut BufReader::new(File::open(&file_path)?);
        let len0 = unpack_u8(bufr)?;
        (0..rt_vec_d.len() / tlen)
            .map(|_| {
                let sh = unpack_f32(bufr)?;
                bufr.seek_relative(i64::from(len0) * 12)?;
                Ok(sh)
            })
            .collect::<io::Result<_>>()?
    };
    let mut bufw = BufWriter::new(File::create(file_path)?);

    let file_path = Path::new(crate::MISCDIR).join(["te_", trans].concat());
    let bufre = &mut BufReader::new(File::open(file_path)?);

    bufw.write_all(&u8::try_from(pos1 - pos0)?.to_le_bytes())?;
    sh_l.iter()
        .enumerate()
        .map(|(i, sh)| {
            use crate::common::Bl;
            use crate::common::{unpack_f32, unpack_f32_2, unpack_u8, unpack_u16};
            let ce = unpack_f32(bufre)?;
            let polarity = unpack_u8(bufre)? == 1;
            let rt_i_l: Vec<_> = (0..unpack_u16(bufre)?)
                .map(|_| unpack_f32_2(bufre).unwrap())
                .collect();
            bufw.write_all(&sh.to_le_bytes())?;
            let rt_pos: Vec<(usize, usize)> = rt_vec_d[i * tlen..][pos0..pos1]
                .iter()
                .map(|&(rt0, rt1)| {
                    let pos1 = rt_i_l.partition_point(|x| x.0 < rt1);
                    let pos0 = rt_i_l[..pos1].partition_point(|x| x.0 < rt0);
                    let pos0 = crate::common::find_closest(&rt_i_l, rt0, pos0);
                    bufw.write_all(&u16::try_from(pos0 + 1)?.to_le_bytes())?;
                    let pos1 = 1 + crate::common::find_closest(&rt_i_l, rt1, pos1);
                    bufw.write_all(&u16::try_from(pos1)?.to_le_bytes())?;
                    Ok((pos0, pos1))
                })
                .collect::<Result<_, Box<dyn Error>>>()?;
            for &(pos0, pos1) in &rt_pos {
                let bl = match k.baseline {
                    Bl::P => {
                        let bl = p_bl(&rt_i_l);
                        Some((bl, bl))
                    }
                    Bl::VDrop => {
                        v_drop_bl(&rt_i_l[rt_pos[0].0..rt_pos[rt_pos.len() - 1].1]).map(|x| (x, x))
                    }
                    Bl::V2v => v2v_bl(&rt_i_l[pos0..pos1]).map(|(x, y)| (x.1, y.1)),
                }
                .unwrap_or((0., 0.));
                bufw.write_all(&bl.0.to_le_bytes())?;
                bufw.write_all(&bl.1.to_le_bytes())?;
            }
            Ok((rt_i_l, rt_pos, ce, polarity))
        })
        .collect()
}
// writes the long format feature measurements
fn write_long(
    s_trans: &[(String, String)],
    area_all: &[Vec<RowDat>],
    t_to_istd: &[crate::common::ValidT],
    mzml_fs: &[crate::common::FileA],
) -> Result<(), Box<dyn Error>> {
    let file_path = Path::new(crate::MISCDIR).join("long.bin");
    let mut bufw = BufWriter::new(File::create(file_path)?);
    bufw.write_all(&u16::try_from(mzml_fs.len())?.to_le_bytes())?;
    let mut wtr = csv::WriterBuilder::new().from_path("long.csv")?;
    wtr.write_record([
        "feature_name",
        "internal_standard",
        "raw_data_filename",
        "time_stamp",
        "batch",
        "sample_type",
        "precursor_mz",
        "product_mz",
        "collision_energy",
        "polarity",
        "rt_apex",
        "area",
        "height",
        "FWHM",
        "rt_int_start",
        "rt_int_end",
    ])?;
    let blkstr = String::new();
    let (pos_string, neg_string) = ("+".to_string(), "-".to_string());
    for ((t, t_name), area_t) in s_trans.iter().zip(area_all) {
        let k: &crate::common::ValidT = t_to_istd
            .binary_search_by_key(&t, |x| &x.cqq)
            .map_or_else(|_| panic!("{t} transition not found"), |k| &t_to_istd[k]);
        bufw.write_all(if t_name.is_empty() {
            k.cpd.as_bytes()
        } else {
            t_name.as_bytes()
        })?;
        bufw.write_all(b"\0")?;
        let i: &crate::common::ValidT = t_to_istd
            .binary_search_by_key(&&k.iqq, |x| &x.cqq)
            .map_or_else(|_| panic!("{t} istd not found"), |k| &t_to_istd[k]);
        for (filedat, rowd) in mzml_fs.iter().zip(area_t.iter()) {
            let [r_rt, r_auc, r_height, r_fwhm, r_beg, r_end] = if rowd.beg == rowd.end {
                [&blkstr; 6]
            } else {
                [
                    &format!("{:.3}", rowd.rt),
                    &format!("{:.1}", rowd.auc),
                    &format!("{:.1}", rowd.height),
                    &rowd.fwhm.map_or(String::new(), |x| format!("{x:.3}")),
                    &format!("{:.3}", rowd.beg),
                    &format!("{:.3}", rowd.end),
                ]
            };
            wtr.write_record([
                if t_name.is_empty() { &k.cpd } else { t_name },
                &i.cpd,
                &filedat.mzml_f,
                &filedat.ts,
                &filedat.batchno,
                &filedat.ftype,
                &format!("{:.3}", k.q1),
                &format!("{:.3}", k.q3),
                &format!("{:.1}", rowd.ce),
                if rowd.polarity {
                    &pos_string
                } else {
                    &neg_string
                },
                r_rt,
                r_auc,
                r_height,
                r_fwhm,
                r_beg,
                r_end,
            ])?;
            bufw.write_all(&rowd.rt.to_le_bytes())?;
            bufw.write_all(&rowd.auc.to_le_bytes())?;
            bufw.write_all(&rowd.beg.to_le_bytes())?;
            bufw.write_all(&rowd.end.to_le_bytes())?;
        }
    }
    Ok(())
}
// writes the wide format raw area table
fn write_area(
    s_trans: &[(String, String)],
    area_all: &[Vec<RowDat>],
    t_to_istd: &[crate::common::ValidT],
    mzml_fs: &[crate::common::FileA],
) -> io::Result<()> {
    let mut wtr = csv::WriterBuilder::new().from_path("quant_raw.csv")?;
    let t_index: Vec<&crate::common::ValidT> = s_trans
        .iter()
        .map(|(t, _)| {
            t_to_istd
                .binary_search_by_key(&t, |x| &x.cqq)
                .map_or_else(|_| panic!("{t} transition not found"), |x| &t_to_istd[x])
        })
        .collect();
    wtr.write_field("name")?;
    wtr.write_record(t_index.iter().zip(s_trans).map(|(&k, (_, t_name))| {
        if t_name.is_empty() { &k.cpd } else { t_name }
    }))?;

    wtr.write_field("precursor")?;
    wtr.write_record(t_index.iter().map(|k| format!("{:.3}", k.q1)))?;

    wtr.write_field("product")?;
    wtr.write_record(t_index.iter().map(|k| format!("{:.3}", k.q3)))?;

    wtr.write_field("RT")?;
    wtr.write_record(t_index.iter().zip(s_trans).map(|(k, (_, t_name))| {
        if t_name.is_empty() {
            k.rt_iso[0].rt.to_string()
        } else {
            let k = k.rt_iso.iter().find(|x| x.name == *t_name).unwrap();
            k.rt.to_string()
        }
    }))?;
    for (j, crate::common::FileA { mzml_f, .. }) in mzml_fs.iter().enumerate() {
        wtr.write_field(mzml_f)?;
        wtr.write_record(area_all.iter().map(|x| x[j].auc.to_string()))?;
    }
    Ok(())
}

// stores the calculated measurements for one feature
struct RowDat {
    auc: f32,
    height: f32,
    rt: f32,
    fwhm: Option<f32>,
    beg: f32,
    end: f32,
    ce: f32,
    polarity: bool,
}
// calculates the trapezoidal area above a flat baseline
fn auc_flat(rt_i_l: &[(f32, f32)], bl: f32) -> f32 {
    rt_i_l
        .windows(2)
        .map(|rti| (0f32.max(rti[0].1 - bl) + 0f32.max(rti[1].1 - bl)) * (rti[1].0 - rti[0].0))
        .sum::<f32>()
        * 30.
}
// estimates a constant baseline from the lower intensity distribution
fn p_bl(rt_i_l: &[(f32, f32)]) -> f32 {
    let mut i_l: Vec<_> = rt_i_l.iter().map(|x| x.1).collect();
    let i = i_l.len() / 20;
    i_l.select_nth_unstable_by(i, |a, b| a.partial_cmp(b).unwrap());
    i_l[i]
}
// finds the lowest intensity for a vertical drop baseline
fn v_drop_bl(rt_i_l: &[(f32, f32)]) -> Option<f32> {
    rt_i_l.iter().map(|x| x.1).reduce(f32::min)
}
// identifies the endpoints for a valley to valley baseline
fn v2v_bl(rt_i_l: &[(f32, f32)]) -> Option<((f32, f32), (f32, f32))> {
    rt_i_l.first().map(|ep0| (*ep0, rt_i_l[rt_i_l.len() - 1]))
}
// calculates the area above a valley to valley baseline
fn v2v_auc(rt_i_l: &[(f32, f32)]) -> f32 {
    v2v_bl(rt_i_l).map_or(0., |(ep0, ep1)| {
        let bl: Vec<f32> = rt_i_l
            .iter()
            .map(|x| ep0.1 + (x.0 - ep0.0) * (ep1.1 - ep0.1) / (ep1.0 - ep0.0))
            .collect();
        rt_i_l
            .windows(2)
            .zip(bl.windows(2))
            .map(|(rti, b)| {
                (0f32.max(rti[0].1 - b[0]) + 0f32.max(rti[1].1 - b[1])) * (rti[1].0 - rti[0].0)
            })
            .sum::<f32>()
            * 30.
    })
}
// calculates the area height apex and width for one feature
fn feat_data(
    i: usize,
    rt_i_all: &[EicPos],
    rt_vec_d: &[(f32, f32)],
    tlen: usize,
    k: &crate::common::ValidT,
) -> io::Result<Vec<RowDat>> {
    // interpolates the retention time at a target intensity
    fn pred_rt(rti: &[(f32, f32)], hm: f32) -> f32 {
        rti[0].0 + (hm - rti[0].1) * (rti[1].0 - rti[0].0) / (rti[1].1 - rti[0].1)
    }
    rt_i_all
        .iter()
        .zip(rt_vec_d.iter().step_by(tlen))
        .map(|(&(ref rt_i_l, ref rt_pos, ce, polarity), &(beg, end))| {
            let (pos0, pos1) = rt_pos[i];
            let auc = {
                use crate::common::Bl;
                let rt_i = &rt_i_l[pos0..pos1];
                match k.baseline {
                    Bl::P => auc_flat(rt_i, p_bl(rt_i_l)),
                    Bl::VDrop => v_drop_bl(&rt_i_l[rt_pos[0].0..rt_pos[rt_pos.len() - 1].1])
                        .map_or(0., |bl| auc_flat(rt_i, bl)),
                    Bl::V2v => v2v_auc(rt_i),
                }
            };
            let (fwhm, rt, height) = if let Some((max_i, (rt, height))) = (pos0..)
                .zip(&rt_i_l[pos0..pos1])
                .max_by(|x, y| x.1.1.partial_cmp(&y.1.1).unwrap())
            {
                let hm = height / 2.;
                let fwhm = rt_i_l[max_i..pos1]
                    .windows(2)
                    .rfind(|rti01| rti01[1].1 <= hm && hm <= rti01[0].1)
                    .map_or_else(
                        || rt_i_l[max_i..pos1].last().map(|x| x.0),
                        |rti1| Some(pred_rt(rti1, hm)),
                    )
                    .and_then(|h1| {
                        rt_i_l[pos0..=max_i]
                            .windows(2)
                            .find(|rti01| rti01[0].1 <= hm && hm <= rti01[1].1)
                            .map_or_else(
                                || rt_i_l[pos0..=max_i].first().map(|x| x.0),
                                |rti0| Some(pred_rt(rti0, hm)),
                            )
                            .map(|x| h1 - x)
                    });
                (fwhm, *rt, *height)
            } else {
                (None, beg, 0.)
            };
            Ok(RowDat {
                auc,
                height,
                rt,
                fwhm,
                beg,
                end,
                ce,
                polarity,
            })
        })
        .collect()
}
// stores the transition labels and integration boundaries from the matrix
type RtMat = (Vec<(String, String)>, Vec<(f32, f32)>);
// reads and validates the retention time matrix
fn read_rtmat() -> Result<RtMat, Box<dyn Error>> {
    let mut rdr = csv::ReaderBuilder::new()
        .has_headers(false)
        .trim(csv::Trim::All)
        .from_path(crate::RTM)?;
    let line = rdr.records().next().unwrap()?;
    let (trans_str, names_l): (Vec<&str>, Vec<&str>) = line
        .into_iter()
        .map(|x| x.rsplit_once(" / ").unwrap_or(("", "")))
        .unzip();
    let line = rdr.records().next().unwrap()?;

    let mut trans_col = Vec::<(String, String, usize, usize)>::new();
    for (ii, name_rt) in names_l
        .into_iter()
        .zip(&line)
        .enumerate()
        .filter(|(_, (x, _))| !x.is_empty())
    {
        if let Some((name, rt, _, index)) = trans_col.last_mut()
            && name_rt == (name, rt)
        {
            *index = ii;
            continue;
        }
        trans_col.push((name_rt.0.to_string(), name_rt.1.to_string(), ii, 0));
    }
    if let Some((.., col_no, _)) = trans_col.iter().find(|(.., y)| *y == 0) {
        return Err([trans_str[*col_no], " less than 2 columns"].concat().into());
    }
    trans_col.sort_unstable();
    let mut rt_vec_d = Vec::<(f32, f32)>::new();
    for rec in rdr.records().skip(1) {
        let line = rec.as_ref().unwrap();
        let to_float = |cn| -> Result<_, _> {
            let str0 = &line[cn];
            str0.parse()
                .map_err(|_| format!("({}, {}), {str0}", &trans_str[cn], &line[0]))
        };
        for &(.., beg0, end0) in &trans_col {
            let beg = to_float(beg0)?;
            let end = to_float(end0)?;
            rt_vec_d.push((beg, end));
            if beg > end {
                return Err(format!(
                    "({}, {}), (begin RT)>(end RT) {beg} {end}",
                    &trans_str[beg0], &line[0]
                )
                .into());
            }
        }
    }
    Ok((
        trans_col.into_iter().map(|x| (x.0, x.1)).collect(),
        rt_vec_d,
    ))
}
