use std::error::Error;
use std::fs::File;
use std::io;
use std::io::{BufReader, BufWriter, Write};
use std::path::Path;

pub fn calc_auc(param_t: &crate::Param) -> Result<(), Box<dyn Error>> {
    let (s_trans, rt_vec_d) = read_rtmat()?;
    let t_to_istd = crate::common::get_trans_istd()?;
    // with crop_window, step 1 stored only the cropped trace, so its ends are not the acquired trace ends
    let cropped = param_t.crop_window.is_some();
    let noise = param_t.sn_noise;
    println!("S/N noise: {}", noise.name());
    let area_all = areas(&s_trans, &rt_vec_d, &t_to_istd, cropped, noise);
    let mzml_fs = crate::common::get_mzml()?;
    write_long(&s_trans, &area_all, &t_to_istd, &mzml_fs)?;
    write_area(&s_trans, &area_all, &t_to_istd, &mzml_fs)?;
    crate::common::write_by_sample(&t_to_istd, &mzml_fs)
}
fn areas(
    s_trans: &[(String, String)],
    rt_vec_d: &[(f32, f32)],
    t_to_istd: &[crate::common::ValidT],
    cropped: bool,
    noise: crate::common::Noise,
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
                feat_data(
                    i - pos0,
                    &rt_i_all,
                    &rt_vec_d[i..],
                    s_trans.len(),
                    k,
                    cropped,
                    noise,
                )
                .unwrap()
            })
        })
        .collect::<Vec<_>>()
}
type EicPos = (Vec<(f32, f32)>, Vec<(usize, usize)>, f32, bool);
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
                    if rt_i_l.is_empty() {
                        bufw.write_all(&[0u8; 4])?;
                        return Ok((0, 0));
                    }
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
                    _ if rt_i_l.is_empty() => None,
                    Bl::P => {
                        let bl = p_bl(&rt_i_l);
                        Some((bl, bl))
                    }
                    Bl::VDrop => v_drop_bl(&rt_i_l, &rt_pos).map(|x| (x, x)),
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
        "trace_cut_pct",
        "sn_ratio",
        "noise_method",
    ])?;
    let blkstr = String::new();
    let (pos_string, neg_string) = ("+".to_owned(), "-".to_owned());
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
            // empty also where the transition is absent, even if RT_matrix.csv was edited to give it bounds
            let no_result = rowd.beg == rowd.end || rowd.absent;
            let [r_rt, r_auc, r_height, r_fwhm, r_beg, r_end, r_cut, r_sn] = if no_result {
                [&blkstr; 8]
            } else {
                [
                    &format!("{:.3}", rowd.rt),
                    &format!("{:.1}", rowd.auc),
                    &format!("{:.1}", rowd.height),
                    &rowd.fwhm.map_or(String::new(), |x| format!("{x:.3}")),
                    &format!("{:.3}", rowd.beg),
                    &format!("{:.3}", rowd.end),
                    &rowd.trace_cut.map_or(String::new(), |x| format!("{x:.1}")),
                    &rowd.sn.map_or(String::new(), |x| format!("{:.1}", x.0)),
                ]
            };
            let r_noise = match rowd.sn {
                Some((_, n)) if !no_result => n.name().to_owned(),
                _ => String::new(),
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
                r_cut,
                r_sn,
                &r_noise,
            ])?;
            bufw.write_all(&rowd.rt.to_le_bytes())?;
            bufw.write_all(&rowd.auc.to_le_bytes())?;
            bufw.write_all(&rowd.beg.to_le_bytes())?;
            bufw.write_all(&rowd.end.to_le_bytes())?;
        }
    }
    Ok(())
}
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
        // Empty cell where the transition is absent from the sample
        wtr.write_record(area_all.iter().map(|x| {
            if x[j].absent {
                String::new()
            } else {
                x[j].auc.to_string()
            }
        }))?;
    }
    Ok(())
}

struct RowDat {
    auc: f32,
    height: f32,
    rt: f32,
    fwhm: Option<f32>,
    beg: f32,
    end: f32,
    ce: f32,
    polarity: bool,
    absent: bool,
    trace_cut: Option<f32>,
    sn: Option<(f32, crate::common::Noise)>,
}
/// Signal left where the integration window reaches an end of the acquired trace, in % of the apex height, both
/// above the 5th-percentile baseline of the whole trace (`p_bl`), rounded to 1 decimal. Negative for the first trace
/// point, positive for the last; +/-100 means the apex is on that end. `None` if the window reaches no trace end or
/// the signal there is not above baseline. If the window reaches both ends, the larger value is returned.
fn trace_cut_pct(rt_i_l: &[(f32, f32)], (pos0, pos1): (usize, usize)) -> Option<f32> {
    if pos0 >= pos1 {
        return None;
    }
    let bl = p_bl(rt_i_l);
    let apex = rt_i_l[pos0..pos1]
        .iter()
        .map(|x| x.1)
        .fold(f32::MIN, f32::max);
    if apex <= bl {
        return None;
    }
    let pct = |i: f32| (1000. * (i - bl) / (apex - bl)).round() / 10.;
    let left = (pos0 == 0).then(|| pct(rt_i_l[0].1)).filter(|&x| x > 0.);
    let right = (pos1 == rt_i_l.len())
        .then(|| pct(rt_i_l[pos1 - 1].1))
        .filter(|&x| x > 0.);
    match (left, right) {
        (Some(l), Some(r)) if l > r => Some(-l),
        (Some(l), None) => Some(-l),
        (_, r) => r,
    }
}
fn auc_flat(rt_i_l: &[(f32, f32)], bl: f32) -> f32 {
    rt_i_l
        .windows(2)
        .map(|rti| (0f32.max(rti[0].1 - bl) + 0f32.max(rti[1].1 - bl)) * (rti[1].0 - rti[0].0))
        .sum::<f32>()
        * 30.
}
fn p_bl(rt_i_l: &[(f32, f32)]) -> f32 {
    let mut i_l: Vec<_> = rt_i_l.iter().map(|x| x.1).collect();
    let i = i_l.len() / 20;
    i_l.select_nth_unstable_by(i, |a, b| a.partial_cmp(b).unwrap());
    i_l[i]
}
fn v_drop_bl(rt_i_l: &[(f32, f32)], rt_pos: &[(usize, usize)]) -> Option<f32> {
    rt_i_l[rt_pos.iter().map(|x| x.0).reduce(usize::min).unwrap()
        ..rt_pos.iter().map(|x| x.1).reduce(usize::max).unwrap()]
        .iter()
        .map(|x| x.1)
        .reduce(f32::min)
}
fn v2v_bl(rt_i_l: &[(f32, f32)]) -> Option<((f32, f32), (f32, f32))> {
    rt_i_l.first().map(|ep0| (*ep0, rt_i_l[rt_i_l.len() - 1]))
}
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
/// Integration baseline at the apex, as used for the area of the feature's baseline mode.
fn bl_at_apex(
    rt_i_l: &[(f32, f32)],
    rt_pos: &[(usize, usize)],
    (pos0, pos1): (usize, usize),
    apex_i: usize,
    mode: &crate::common::Bl,
) -> f32 {
    use crate::common::Bl;
    match mode {
        Bl::P => p_bl(rt_i_l),
        Bl::VDrop => v_drop_bl(rt_i_l, rt_pos).unwrap_or(0.),
        Bl::V2v => v2v_bl(&rt_i_l[pos0..pos1]).map_or(0., |(ep0, ep1)| {
            if ep1.0 == ep0.0 {
                ep0.1
            } else {
                ep0.1 + (rt_i_l[apex_i].0 - ep0.0) * (ep1.1 - ep0.1) / (ep1.0 - ep0.0)
            }
        }),
    }
}
/// Peak width at half height above the integration baseline `bl`, from the first half-height crossing on the left to
/// the last on the right inside the window `pos0..pos1`, so a group of peaks above half height is spanned as a whole;
/// linear interpolation between points. `None` if a window edge is at or above half height (the peak is cut, or the
/// apex is on the edge) or the apex is not above `bl`.
fn fwhm(
    rt_i_l: &[(f32, f32)],
    (pos0, pos1): (usize, usize),
    apex_i: usize,
    bl: f32,
) -> Option<f32> {
    let apex = rt_i_l[apex_i].1;
    let hm = bl + (apex - bl) / 2.;
    if apex <= bl || rt_i_l[pos0].1 >= hm || rt_i_l[pos1 - 1].1 >= hm {
        return None;
    }
    // both edges are below hm, so the outermost crossing pairs have one point below hm: no 0/0
    let at = |p: &[(f32, f32)]| p[0].0 + (hm - p[0].1) * (p[1].0 - p[0].0) / (p[1].1 - p[0].1);
    let left = rt_i_l[pos0..=apex_i]
        .windows(2)
        .find(|p| p[0].1 <= hm && hm <= p[1].1)
        .map(at)?;
    let right = rt_i_l[apex_i..pos1]
        .windows(2)
        .rfind(|p| p[0].1 >= hm && hm >= p[1].1)
        .map(at)?;
    Some(right - left)
}
/// Signal-to-noise ratio: `height` (above the integration baseline) divided by the noise of the trace within
/// 10 × `half_width` of the apex, outside the integration windows of all features of the transition (`rt_pos`).
/// Noise: robust = 1.4826 × MAD after repeatedly removing points more than 3 × that noise above the median (other
/// peaks in the region, e.g. isomers or isotopic interferences; as OpenMS `SignalToNoiseEstimatorMeanIterative`),
/// stopping before less than half of the region is left,
/// rms = standard deviation, p2p = (max − min) / 2, i.e. USP 2H/h; at least 1.
/// `None` with fewer than 10 noise points. Rounded to 1 decimal.
fn sn_ratio(
    rt_i_l: &[(f32, f32)],
    rt_pos: &[(usize, usize)],
    apex_i: usize,
    height: f32,
    half_width: f32,
    noise: crate::common::Noise,
) -> Option<f32> {
    use crate::common::Noise;
    fn median(v: &mut [f32]) -> f32 {
        v.sort_unstable_by(f32::total_cmp);
        let n = v.len();
        if n % 2 == 1 {
            v[n / 2]
        } else {
            (v[n / 2 - 1] + v[n / 2]) / 2.
        }
    }
    let t_apex = rt_i_l[apex_i].0;
    let mut y: Vec<f32> = rt_i_l
        .iter()
        .enumerate()
        .filter(|&(j, &(t, _))| {
            (t - t_apex).abs() <= 10. * half_width
                && !rt_pos.iter().any(|&(p0, p1)| (p0..p1).contains(&j))
        })
        .map(|(_, &(_, i))| i)
        .collect();
    if y.len() < 10 {
        return None;
    }
    let n = match noise {
        Noise::Robust | Noise::Flank => {
            let mad_sd = |y: &mut [f32]| {
                let m = median(y);
                let mut dev: Vec<f32> = y.iter().map(|x| (x - m).abs()).collect();
                (m, 1.4826 * median(&mut dev))
            };
            let (mut m, mut n) = mad_sd(&mut y);
            // keep at least half of the region, so that a quiet remainder does not make the noise too small
            let min_kept = (y.len() / 2).max(10);
            for _ in 0..10 {
                let kept: Vec<f32> = y
                    .iter()
                    .copied()
                    .filter(|&x| x <= m + 3. * n.max(1.))
                    .collect();
                if kept.len() == y.len() || kept.len() < min_kept {
                    break;
                }
                y = kept;
                (m, n) = mad_sd(&mut y);
            }
            n
        }
        Noise::Rms => {
            let mean = y.iter().sum::<f32>() / y.len() as f32;
            (y.iter().map(|x| (x - mean).powi(2)).sum::<f32>() / (y.len() - 1) as f32).sqrt()
        }
        Noise::P2p => {
            let (lo, hi) = y
                .iter()
                .fold((f32::MAX, f32::MIN), |(lo, hi), &x| (lo.min(x), hi.max(x)));
            (hi - lo) / 2.
        }
    };
    Some((10. * height / n.max(1.)).round() / 10.)
}
/// S/N with the noise of `sn_noise` and the method actually used: `flank` falls back to `robust` (region) when
/// neither side of the window `win` has 5 free baseline points.
fn sn_with(
    rt_i_l: &[(f32, f32)],
    rt_pos: &[(usize, usize)],
    win: (usize, usize),
    apex_i: usize,
    height: f32,
    half_width: f32,
    noise: crate::common::Noise,
) -> Option<(f32, crate::common::Noise)> {
    use crate::common::Noise;
    if let Noise::Flank = noise
        && let Some(n) = flank_noise(rt_i_l, rt_pos, win, half_width)
    {
        return Some(((10. * height / n.max(1.)).round() / 10., Noise::Flank));
    }
    let noise = if let Noise::Flank = noise {
        Noise::Robust
    } else {
        noise
    };
    sn_ratio(rt_i_l, rt_pos, apex_i, height, half_width, noise).map(|x| (x, noise))
}
/// Half the peak-to-peak range of the baseline next to the integration window `win`, within 3 × `half_width` on each
/// side and outside the windows of all features of the transition; the quieter side (pharmacopoeia 2H/h measured
/// beside the peak, avoiding a neighbouring peak on the other side). `None` if neither side has 5 points.
fn flank_noise(
    rt_i_l: &[(f32, f32)],
    rt_pos: &[(usize, usize)],
    (pos0, pos1): (usize, usize),
    half_width: f32,
) -> Option<f32> {
    let side = |lo: f32, hi: f32| {
        let v: Vec<f32> = rt_i_l
            .iter()
            .enumerate()
            .filter(|&(j, &(t, _))| {
                lo <= t && t <= hi && !rt_pos.iter().any(|&(p0, p1)| (p0..p1).contains(&j))
            })
            .map(|(_, &(_, i))| i)
            .collect();
        (v.len() >= 5).then(|| {
            let (lo, hi) = v
                .iter()
                .fold((f32::MAX, f32::MIN), |(lo, hi), &x| (lo.min(x), hi.max(x)));
            (hi - lo) / 2.
        })
    };
    let (t0, t1, w) = (rt_i_l[pos0].0, rt_i_l[pos1 - 1].0, 3. * half_width);
    match (side(t0 - w, t0), side(t1, t1 + w)) {
        (Some(l), Some(r)) => Some(l.min(r)),
        (l, r) => l.or(r),
    }
}
fn feat_data(
    i: usize,
    rt_i_all: &[EicPos],
    rt_vec_d: &[(f32, f32)],
    tlen: usize,
    k: &crate::common::ValidT,
    cropped: bool,
    noise: crate::common::Noise,
) -> io::Result<Vec<RowDat>> {
    rt_i_all
        .iter()
        .zip(rt_vec_d.iter().step_by(tlen))
        .map(|(&(ref rt_i_l, ref rt_pos, ce, polarity), &(beg, end))| {
            let (pos0, pos1) = rt_pos[i];
            let auc = {
                use crate::common::Bl;
                let rt_i = &rt_i_l[pos0..pos1];
                match k.baseline {
                    _ if rt_i_l.is_empty() => 0.,
                    Bl::P => auc_flat(rt_i, p_bl(rt_i_l)),
                    Bl::VDrop => v_drop_bl(rt_i_l, rt_pos).map_or(0., |bl| auc_flat(rt_i, bl)),
                    Bl::V2v => v2v_auc(rt_i),
                }
            };
            let (fwhm, rt, height, sn) = if let Some((max_i, &(rt, apex))) = (pos0..)
                .zip(&rt_i_l[pos0..pos1])
                .max_by(|x, y| x.1.1.partial_cmp(&y.1.1).unwrap())
            {
                let bl = bl_at_apex(rt_i_l, rt_pos, (pos0, pos1), max_i, &k.baseline);
                let fwhm = fwhm(rt_i_l, (pos0, pos1), max_i, bl);
                let height = 0f32.max(apex - bl);
                // without a measured FWHM: the integration window is about 3.5 half-widths in DYNAMO and Dataset4
                let half_width = fwhm.unwrap_or((rt_i_l[pos1 - 1].0 - rt_i_l[pos0].0) / 3.5);
                let sn = sn_with(
                    rt_i_l,
                    rt_pos,
                    (pos0, pos1),
                    max_i,
                    height,
                    half_width,
                    noise,
                );
                (fwhm, rt, height, sn)
            } else {
                (None, beg, 0., None)
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
                absent: rt_i_l.is_empty(),
                trace_cut: if cropped {
                    None
                } else {
                    trace_cut_pct(rt_i_l, (pos0, pos1))
                },
                sn,
            })
        })
        .collect()
}
type RtMat = (Vec<(String, String)>, Vec<(f32, f32)>);
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
        trans_col.push((name_rt.0.to_owned(), name_rt.1.to_owned(), ii, 0));
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
                .map_err(|_| format!("({}, {}), {str0}", trans_str[cn], &line[0]))
        };
        for &(.., beg0, end0) in &trans_col {
            let beg = to_float(beg0)?;
            let end = to_float(end0)?;
            rt_vec_d.push((beg, end));
            if beg > end {
                return Err(format!(
                    "({}, {}), (begin RT)>(end RT) {beg} {end}",
                    trans_str[beg0], &line[0]
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

#[cfg(test)]
mod tests {
    use super::{bl_at_apex, fwhm, sn_ratio, sn_with, trace_cut_pct};
    use crate::common::Noise;

    // 40 points at baseline 0 with a peak `peak` placed at `at`; the 5th-percentile baseline is 0.
    fn trace(at: usize, peak: &[f32]) -> Vec<(f32, f32)> {
        let mut i = vec![0f32; 40];
        i[at..at + peak.len()].copy_from_slice(peak);
        (0u8..40).map(f32::from).zip(i).collect()
    }

    #[test]
    fn left_cut_is_negative() {
        let t = trace(0, &[50., 100., 50.]);
        assert_eq!(trace_cut_pct(&t, (0, 5)), Some(-50.));
    }

    #[test]
    fn right_cut_is_positive() {
        let t = trace(37, &[50., 100., 25.]);
        assert_eq!(trace_cut_pct(&t, (35, 40)), Some(25.));
    }

    #[test]
    fn apex_on_trace_end_is_100() {
        let t = trace(0, &[100., 50.]);
        assert_eq!(trace_cut_pct(&t, (0, 4)), Some(-100.));
        let t = trace(38, &[50., 100.]);
        assert_eq!(trace_cut_pct(&t, (36, 40)), Some(100.));
    }

    #[test]
    fn empty_if_window_reaches_no_trace_end() {
        let t = trace(10, &[50., 100., 50.]);
        assert_eq!(trace_cut_pct(&t, (8, 15)), None);
    }

    #[test]
    fn empty_if_trace_end_at_baseline_or_no_peak() {
        let t = trace(2, &[50., 100., 50.]);
        assert_eq!(trace_cut_pct(&t, (0, 7)), None);
        assert_eq!(trace_cut_pct(&t, (3, 3)), None);
        assert_eq!(trace_cut_pct(&trace(0, &[]), (0, 40)), None);
    }

    #[test]
    fn both_ends_cut_reports_larger_side() {
        let mut t = trace(0, &[30.]);
        t[39].1 = 60.;
        t[20].1 = 100.;
        assert_eq!(trace_cut_pct(&t, (0, 40)), Some(60.));
        t[0].1 = 80.;
        assert_eq!(trace_cut_pct(&t, (0, 40)), Some(-80.));
    }

    #[test]
    fn fwhm_at_half_height_above_baseline() {
        // half height 50 is reached at t = 11 and t = 13
        let t = trace(10, &[25., 50., 100., 50., 25.]);
        assert_eq!(fwhm(&t, (5, 20), 12, 0.), Some(2.));
        // same peak on a baseline of 100: half height 150, same width (raw half height 100 would span the window)
        let raised: Vec<(f32, f32)> = t.iter().map(|&(x, y)| (x, y + 100.)).collect();
        assert_eq!(fwhm(&raised, (5, 20), 12, 100.), Some(2.));
    }

    #[test]
    fn fwhm_interpolates_between_points() {
        let t = trace(10, &[0., 100., 0.]);
        assert_eq!(fwhm(&t, (5, 20), 11, 0.), Some(1.));
    }

    #[test]
    fn fwhm_spans_a_group_of_peaks_above_half_height() {
        let mut t = trace(10, &[50., 100., 50.]);
        t[15].1 = 30.;
        t[16..19].copy_from_slice(&[(16., 50.), (17., 80.), (18., 50.)]);
        assert_eq!(fwhm(&t, (5, 25), 11, 0.), Some(8.));
    }

    #[test]
    fn fwhm_empty_if_cut_by_the_window_or_not_above_baseline() {
        let t = trace(10, &[25., 50., 100., 50., 25.]);
        assert_eq!(fwhm(&t, (11, 20), 12, 0.), None); // left edge at half height
        assert_eq!(fwhm(&t, (5, 13), 12, 0.), None); // apex on the right edge
        assert_eq!(fwhm(&t, (5, 20), 12, 100.), None); // apex not above baseline
    }

    #[test]
    fn v2v_baseline_at_apex_is_on_the_line() {
        use crate::common::Bl;
        let t: Vec<(f32, f32)> = (0u8..11)
            .map(|x| (f32::from(x), f32::from(x) * 10.))
            .collect();
        assert_eq!(bl_at_apex(&t, &[(0, 11)], (0, 11), 5, &Bl::V2v), 50.);
    }

    // 60 points, baseline alternating 9 / 11 (MAD 1, peak-to-peak 2), peak window 28..33 with the apex at 30
    fn noisy() -> Vec<(f32, f32)> {
        (0u8..60)
            .map(|x| (f32::from(x), if x % 2 == 0 { 9. } else { 11. }))
            .collect()
    }

    #[test]
    fn sn_noise_methods() {
        let (t, w) = (noisy(), vec![(28, 33)]);
        // 16 noise points within 10 half-widths (t 20..=40 outside 28..33)
        assert_eq!(sn_ratio(&t, &w, 30, 100., 1., Noise::P2p), Some(100.));
        assert_eq!(sn_ratio(&t, &w, 30, 100., 1., Noise::Robust), Some(67.4)); // 100 / 1.4826
        assert_eq!(sn_ratio(&t, &w, 30, 100., 1., Noise::Rms), Some(96.8)); // 100 / sqrt(16 / 15)
    }

    #[test]
    fn sn_excludes_all_feature_windows() {
        let (mut t, mut w) = (noisy(), vec![(28, 33)]);
        t[24].1 = 1000.; // a second feature of the transition
        w.push((23, 26));
        assert_eq!(sn_ratio(&t, &w, 30, 100., 1., Noise::P2p), Some(100.));
    }

    #[test]
    fn sn_empty_with_few_noise_points_and_offset_invariant() {
        let (t, w) = (noisy(), vec![(28, 33)]);
        assert_eq!(sn_ratio(&t, &w, 30, 100., 0.3, Noise::Robust), None);
        let raised: Vec<(f32, f32)> = t.iter().map(|&(x, y)| (x, y + 1000.)).collect();
        assert_eq!(
            sn_ratio(&raised, &w, 30, 100., 1., Noise::Robust),
            Some(67.4)
        );
    }

    #[test]
    fn sn_noise_at_least_1() {
        let t: Vec<(f32, f32)> = (0u8..60).map(|x| (f32::from(x), 10.)).collect();
        assert_eq!(
            sn_ratio(&t, &[(28, 33)], 30, 100., 1., Noise::Robust),
            Some(100.)
        );
        assert_eq!(
            sn_ratio(&t, &[(28, 33)], 30, 0., 1., Noise::Robust),
            Some(0.)
        );
    }

    #[test]
    fn sn_robust_ignores_an_interference_peak_in_the_region() {
        // an isomer peak at t 35..37 (not a feature of the transition): robust unchanged, rms much lower
        let mut t = noisy();
        t[35..38].copy_from_slice(&[(35., 500.), (36., 1000.), (37., 500.)]);
        let w = vec![(28, 33)];
        let robust = sn_ratio(&t, &w, 30, 100., 1., Noise::Robust).unwrap();
        assert!((30. ..=100.).contains(&robust), "{robust}"); // clean trace: 67.4
        assert!(sn_ratio(&t, &w, 30, 100., 1., Noise::Rms).unwrap() < 1.);
    }

    #[test]
    fn sn_flank_uses_the_quieter_side() {
        // left of the window peak-to-peak 2 (noise 1), right 20 (noise 10); 3 half-widths = 6 points per side
        let mut t = noisy();
        for (j, p) in t.iter_mut().enumerate().skip(33).take(8) {
            p.1 = if j % 2 == 0 { 0. } else { 20. };
        }
        let flank = sn_with(&t, &[(28, 33)], (28, 33), 30, 100., 2., Noise::Flank)
            .map(|x| (x.0, x.1.name()));
        assert_eq!(flank, Some((100., "flank")));
    }

    #[test]
    fn sn_flank_falls_back_to_robust_without_free_baseline() {
        // neighbouring features on both sides: the region estimate is used and reported as robust
        let w = [(28, 33), (20, 28), (33, 45)];
        let sn =
            sn_with(&noisy(), &w, (28, 33), 30, 100., 2., Noise::Flank).map(|x| (x.0, x.1.name()));
        assert_eq!(sn, Some((67.4, "robust")));
    }
}
