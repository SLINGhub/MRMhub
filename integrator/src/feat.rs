use rayon::prelude::*;
use std::error::Error;
use std::fs::File;
use std::io::{self, BufReader, BufWriter, Write};
use std::path::Path;

#[derive(Clone, Copy)]
struct RtScCA {
    rt: f32,
    auc: f32,
}
pub fn detect(param_t: &crate::Param) -> Result<(), Box<dyn Error>> {
    let mzml_fs = crate::common::get_mzml()?;
    let t_to_istd = crate::common::get_trans_istd()?;
    let wave_scs = [0.05, 0.1];
    let wave_sqrt = wave_scs.map(f32::sqrt);
    let start_end_d: Vec<Fff32> = t_to_istd
        .par_iter()
        .map(|t_i| {
            print!("\r{: <50.40}", t_i.cpd);
            io::stdout().flush()?;
            write_trans(t_i, param_t, &mzml_fs, &wave_scs, &wave_sqrt)
        })
        .collect::<Result<_, _>>()?;
    println!("\r{: <50.40}", "");
    crate::common::write_by_sample(&t_to_istd, &mzml_fs)?;
    write_rtmat(&t_to_istd, &start_end_d, &mzml_fs)?;
    Ok(())
}
type Fff32 = (Vec<(f32, f32)>, usize);
fn write_rtmat(
    t_to_istd: &[crate::common::ValidT],
    start_end_d: &[Fff32],
    mzml_fs: &[crate::common::FileA],
) -> io::Result<()> {
    let mut wtr = csv::WriterBuilder::new().from_path(crate::RTM)?;
    wtr.write_field("")?;
    for ((_, isolen), t_i) in start_end_d.iter().zip(t_to_istd) {
        wtr.write_field("")?;
        let x = [&t_i.cpd, " / ", &t_i.cqq].concat();
        for _ in 0..*isolen {
            wtr.write_field(&x)?;
            wtr.write_field(&x)?;
        }
    }
    wtr.write_record(None::<&[u8]>)?;

    wtr.write_field("compound name")?;
    for ((_, isolen), t_i) in start_end_d.iter().zip(t_to_istd) {
        wtr.write_field("")?;
        if t_i.rt_iso[0].name.is_empty() {
            for _ in 0..*isolen {
                wtr.write_field("")?;
                wtr.write_field("")?;
            }
        } else {
            for i in t_i.rt_iso.iter().map(|x| &x.name) {
                wtr.write_field(i)?;
                wtr.write_field(i)?;
            }
        }
    }
    wtr.write_record(None::<&[u8]>)?;

    wtr.write_field("")?;
    for (_, isolen) in start_end_d {
        wtr.write_field("")?;
        for _ in 0..*isolen {
            wtr.write_field("-")?;
            wtr.write_field("-")?;
        }
    }
    wtr.write_record(None::<&[u8]>)?;
    for (i, crate::common::FileA { mzml_f, .. }) in mzml_fs.iter().enumerate() {
        wtr.write_field(mzml_f)?;
        for (se, isolen) in start_end_d {
            wtr.write_field("")?;
            for x in &se[i * isolen..][..*isolen] {
                wtr.write_field(format!("{:.3}", x.0))?;
                wtr.write_field(format!("{:.3}", x.1))?;
            }
        }
        wtr.write_record(None::<&[u8]>)?;
    }
    Ok(())
}
fn isomer_range(
    t_i: &crate::common::ValidT,
    median_rt: &[f32],
    bufw: &mut BufWriter<File>,
    rt_tol: f32,
) -> io::Result<Vec<Vec<(usize, bool)>>> {
    Ok(if t_i.rt_iso[0].name.is_empty() {
        bufw.write_all(&u8::try_from(median_rt.len()).unwrap().to_le_bytes())?;
        vec![vec![(0, true)]; median_rt.len()]
    } else {
        bufw.write_all(&u8::try_from(t_i.rt_iso.len()).unwrap().to_le_bytes())?;
        let mut pos = 0;
        let new_rt_i: Vec<(usize, bool)> = t_i
            .rt_iso
            .iter()
            .map(|x| {
                pos += median_rt[pos..].partition_point(|y| *y < x.rt);
                let p = if pos == median_rt.len()
                    || (pos > 0 && x.rt - median_rt[pos - 1] <= median_rt[pos] - x.rt)
                {
                    pos - 1
                } else {
                    pos
                };
                (p, (median_rt[p] - x.rt).abs() < rt_tol)
            })
            .collect();
        let mut p0 = 0;
        let mut p1 = 0;
        (0..median_rt.len())
            .map(|jj| {
                p0 = p1;
                p1 = (p0..new_rt_i.len())
                    .find(|x| new_rt_i[*x].0 != jj)
                    .unwrap_or(new_rt_i.len());
                (p0..p1).map(|p| (p, new_rt_i[p].1)).collect()
            })
            .collect()
    })
}
fn lowest_left(p0_: usize, p1: f32, rt_i_l: &[(f32, f32)]) -> usize {
    (p0_..)
        .zip(rt_i_l[p0_..].iter().take_while(|x| x.0 < p1))
        .min_by(|x, y| x.1.1.partial_cmp(&y.1.1).unwrap())
        .map_or(p0_, |x| x.0)
}
fn write_trans(
    t_i: &crate::common::ValidT,
    param_t: &crate::Param,
    mzml_fs: &[crate::common::FileA],
    wave_scs: &[f32],
    wave_sqrt: &[f32],
) -> io::Result<Fff32> {
    let peak_w = t_i.peak_w.unwrap_or(param_t.peak_w);
    let rt_i_all: Vec<Vec<(f32, f32)>> = {
        let file_path = Path::new(crate::MISCDIR).join(["te_", &t_i.cqq].concat());
        let bufr = &mut BufReader::new(File::open(file_path)?);
        (0..mzml_fs.len())
            .map(|_| crate::common::get_eic(bufr))
            .collect::<io::Result<_>>()?
    };
    let dec_l: Vec<f32> = rt_i_all
        .iter()
        .map(|rt_i_l| {
            let mut i_l: Vec<_> = rt_i_l.iter().map(|x| x.1).collect();
            let i = i_l.len() / 20;
            i_l.select_nth_unstable_by(i, |a, b| a.partial_cmp(b).unwrap());
            i_l[i] * 1.1
        })
        .collect();
    let rt_sh = calc_shift(&rt_i_all, &dec_l, mzml_fs, param_t);
    let rt_sh = final_shift(&rt_sh, param_t, mzml_fs);
    let trans_feats: Vec<Vec<RtScCA>> = rt_i_all
        .iter()
        .zip(&dec_l)
        .zip(&rt_sh)
        .zip(mzml_fs)
        .filter(|y| y.1.is_learn)
        .map(|(((x, y), sh), _)| findridge(x, *y, wave_scs, wave_sqrt, *sh))
        .collect();
    let median_rt = calc_med_rt(&trans_feats);
    let file_path = Path::new(crate::MISCDIR).join(["tp_", &t_i.cqq].concat());
    let mut bufw = BufWriter::new(File::create(file_path)?);
    let iso_range = isomer_range(t_i, &median_rt, &mut bufw, param_t.rt_tol)?;
    let peak_wid = peak_w.0 + peak_w.3;
    let isolen = iso_range.iter().map(std::vec::Vec::len).sum();
    let mut start_end_rt = Vec::with_capacity(mzml_fs.len() * isolen);
    let mut trunc = Vec::with_capacity(start_end_rt.capacity());
    let mut new_rt = Vec::with_capacity(median_rt.len());
    for (rt_i_l, sh) in rt_i_all.iter().zip(&rt_sh) {
        new_rt.clear();
        new_rt.extend(median_rt.iter().map(|x| x + sh));
        let mut pos01: usize = 0;
        for (jj, (&f_cc, range)) in new_rt.iter().zip(&iso_range).enumerate() {
            let pos0 = {
                let p0 = f_cc - peak_w.0;
                if jj == 0 || (f_cc - new_rt[jj - 1]) > peak_wid {
                    if peak_w.0 > peak_w.1 {
                        let p1 = f_cc - peak_w.1;
                        let p1_ = rt_i_l.partition_point(|x| x.0 < p1);
                        rt_i_l[..p1_]
                            .iter()
                            .enumerate()
                            .rev()
                            .take_while(|x| x.1.0 > p0)
                            .min_by(|x, y| x.1.1.partial_cmp(&y.1.1).unwrap())
                            .map_or(p1_, |x| x.0)
                    } else {
                        rt_i_l.partition_point(|x| x.0 < p0)
                    }
                } else {
                    pos01.max(rt_i_l.partition_point(|x| x.0 < p0))
                }
            };
            let pos2 = {
                let p1 = f_cc + peak_w.3;
                if jj == new_rt.len() - 1 || (new_rt[jj + 1] - f_cc) > peak_wid {
                    if peak_w.2 < peak_w.3 {
                        let p0 = f_cc + peak_w.2;
                        let p0_ = rt_i_l.partition_point(|x| x.0 < p0);
                        lowest_left(p0_, p1, rt_i_l)
                    } else {
                        rt_i_l.partition_point(|x| x.0 < p1)
                    }
                } else {
                    let p0 = f_cc.next_up();
                    let p0_ = rt_i_l.partition_point(|x| x.0 < p0);
                    pos01 = lowest_left(p0_, new_rt[jj + 1].next_down(), rt_i_l);
                    pos01.min(rt_i_l.partition_point(|x| x.0 < p1))
                }
            };
            let bd = if pos0 == rt_i_l.len() {
                let last = rt_i_l.last().unwrap().0;
                (last, last)
            } else if pos2 == rt_i_l.len() {
                (rt_i_l[pos0].0, rt_i_l.last().unwrap().0)
            } else {
                (rt_i_l[pos0].0, rt_i_l[pos2].0)
            };
            start_end_rt.extend(range.iter().map(|(pos, rt_valid)| {
                let (lb, rb) = t_i.rt_iso[*pos].range;
                if !rt_valid && lb < 0. && rb > 900. {
                    return (f_cc, f_cc);
                }
                let lb = lb + sh;
                let rb = rb + sh;
                (
                    if lb >= 0. { lb } else { bd.0.clamp(lb, rb) },
                    if rb < 900. { rb } else { bd.1.clamp(lb, rb) },
                )
            }));
            trunc.extend(std::iter::repeat_n(
                (f_cc > rt_i_l[0].0, f_cc < rt_i_l.last().unwrap().0),
                range.len(),
            ));
        }
    }
    let mut rt_0 = Vec::with_capacity(mzml_fs.len());
    let mut rt_1 = Vec::with_capacity(mzml_fs.len());
    let median_se: Vec<(f32, f32)> = (0..isolen)
        .map(|i| {
            rt_0.clear();
            rt_1.clear();
            for ((x, sh), t) in start_end_rt[i..]
                .iter()
                .step_by(isolen)
                .zip(&rt_sh)
                .zip(trunc[i..].iter().step_by(isolen))
            {
                if t.0 {
                    rt_0.push(x.0 - sh);
                }
                if t.1 {
                    rt_1.push(x.1 - sh);
                }
            }
            let j0 = rt_0.len() / 2;
            let j1 = rt_1.len() / 2;
            rt_0.select_nth_unstable_by(j0, |x, y| x.partial_cmp(y).unwrap());
            rt_1.select_nth_unstable_by(j1, |x, y| x.partial_cmp(y).unwrap());
            (rt_0[j0], rt_1[j1])
        })
        .collect();
    if t_i.u_rt {
        for (se, sh) in start_end_rt.chunks_exact_mut(isolen).zip(&rt_sh) {
            for (se_i, rt) in se.iter_mut().zip(&median_se) {
                *se_i = (rt.0 + sh, rt.1 + sh);
            }
        }
    } else {
        for ((se, sh), _) in start_end_rt
            .chunks_exact_mut(isolen)
            .zip(&rt_sh)
            .zip(mzml_fs)
            .filter(|x| x.1.ftype.contains("BLK"))
        {
            for (se_i, rt) in se.iter_mut().zip(&median_se) {
                *se_i = (rt.0 + sh, rt.1 + sh);
            }
        }
    }
    write_tp(&rt_i_all, &start_end_rt, &rt_sh, &mut bufw, isolen)?;
    Ok((start_end_rt, isolen))
}
fn write_tp(
    rt_i_all: &[Vec<(f32, f32)>],
    start_end_rt: &[(f32, f32)],
    rt_sh: &[f32],
    bufw: &mut BufWriter<File>,
    isolen: usize,
) -> io::Result<()> {
    for ((rt_i_l, sh), se) in rt_i_all
        .iter()
        .zip(rt_sh)
        .zip(start_end_rt.chunks_exact(isolen))
    {
        bufw.write_all(&sh.to_le_bytes())?;
        for &(rt0, rt1) in se {
            let mut pos = rt_i_l.partition_point(|x| x.0 < rt0);
            pos = crate::common::find_closest(rt_i_l, rt0, pos);
            bufw.write_all(&u16::try_from(pos + 1).unwrap().to_le_bytes())?;
            pos += rt_i_l[pos..].partition_point(|x| x.0 < rt1);
            pos = 1 + crate::common::find_closest(rt_i_l, rt1, pos);
            bufw.write_all(&u16::try_from(pos).unwrap().to_le_bytes())?;
        }
        for _ in se {
            bufw.write_all(&f32::NAN.to_le_bytes())?;
            bufw.write_all(&f32::NAN.to_le_bytes())?;
        }
    }
    Ok(())
}
fn calc_med_rt(trans_feats: &[Vec<RtScCA>]) -> Vec<f32> {
    let med_npeaks = {
        let mut npeaks_l: Vec<_> = trans_feats.iter().map(std::vec::Vec::len).collect();
        let i = npeaks_l.len() / 2;
        npeaks_l.select_nth_unstable(i);
        npeaks_l[i].min(12)
    };
    let mut median_rt = Vec::new();
    let mut feats = Vec::<RtScCA>::new();
    let mut feats_rt = Vec::<f32>::new();
    let mut rt_l = Vec::<f32>::new();
    for npeaks in (1..=med_npeaks).rev() {
        if npeaks < median_rt.len() {
            break;
        }
        feats_rt.clear();
        for feats_ in trans_feats.iter().filter(|x| npeaks <= x.len()) {
            feats.extend(feats_);
            if npeaks < feats.len() {
                feats.select_nth_unstable_by(npeaks - 1, |y, x| x.auc.partial_cmp(&y.auc).unwrap());
                feats.truncate(npeaks);
            }
            feats.sort_unstable_by(|x, y| x.rt.partial_cmp(&y.rt).unwrap());
            feats_rt.extend(feats.drain(..).map(|x| x.rt));
        }
        let mt = trans_feats.len() / 2;
        rt_l.resize(feats_rt.len() / npeaks, 0.);
        let mf = rt_l.len() / 2;
        let cm: Vec<f32> = (0..npeaks)
            .map(|i| {
                rt_l.iter_mut()
                    .zip(feats_rt[i..].iter().step_by(npeaks))
                    .for_each(|(dest, src)| *dest = *src);
                rt_l.select_nth_unstable_by(mf, |x, y| x.partial_cmp(y).unwrap());
                rt_l[mf]
            })
            .filter(|x| {
                trans_feats
                    .iter()
                    .filter(|f| f.iter().any(|z| (z.rt - x).abs() < 0.025))
                    .count()
                    >= mt
            })
            .collect();
        if median_rt.len() <= cm.len() {
            median_rt = cm;
        }
    }
    if median_rt.is_empty() {
        return vec![rt_l[rt_l.len() / 2]];
    }
    median_rt
}
fn calc_shift(
    rt_i_all: &[Vec<(f32, f32)>],
    dec_l: &[f32],
    mzml_fs: &[crate::common::FileA],
    &crate::Param { rt_shift, .. }: &crate::Param,
) -> Vec<Option<(f32, f32)>> {
    struct RtAB {
        rt: f32,
        a: f32,
        b: f32,
    }
    fn pred_i(rti0: (f32, f32), rti1: (f32, f32), rt: f32) -> f32 {
        rti0.1 + (rt - rti0.0) * (rti1.1 - rti0.1) / (rti1.0 - rti0.0)
    }
    let rt_i_ref_l: Vec<Vec<(f32, f32)>> = rt_i_all
        .iter()
        .zip(dec_l)
        .zip(mzml_fs)
        .filter(|(_, x)| x.is_ref)
        .map(|((rt_i_ref, first_dec), _)| {
            let mut rt_i_ref = rt_i_ref.clone();
            for x in &mut rt_i_ref {
                x.1 = 0f32.max(x.1 - first_dec);
            }
            rt_i_ref
        })
        .collect();
    let sh_grid: Vec<f32> = (0..401)
        .map(|x| (x as f32).mul_add(0.01, rt_shift.0))
        .take_while(|sh| *sh < rt_shift.1 + 0.0001)
        .collect();
    let mut a_b = Vec::<RtAB>::new();
    let calc_dotp = |a_b: &mut Vec<RtAB>, rt_i: &[(f32, f32)], rt_i_ref: &[(f32, f32)]| {
        sh_grid
            .iter()
            .filter_map(|&sh| {
                let mut pos = 0;
                a_b.clear();
                a_b.extend(rt_i.iter().filter_map(|(rt0, i0)| {
                    let rt = rt0 - sh;
                    pos = (pos..rt_i_ref.len())
                        .find(|x| rt_i_ref[*x].0 >= rt)
                        .unwrap_or(rt_i_ref.len());
                    (0 < pos && pos < rt_i_ref.len()).then(|| RtAB {
                        rt,
                        a: *i0,
                        b: pred_i(rt_i_ref[pos - 1], rt_i_ref[pos], rt).max(0.),
                    })
                }));
                if a_b.len() < 40 {
                    return None;
                }
                let mut a_dot_b = 0.;
                let mut a_mag = 0.;
                let mut b_mag = 0.;
                for (x0, x1) in a_b.iter().zip(&a_b[1..]) {
                    let d = x1.rt - x0.rt;
                    a_dot_b = ((x0.a * x0.b).sqrt() + (x1.a * x1.b).sqrt()).mul_add(d, a_dot_b);
                    a_mag = (x0.a + x1.a).mul_add(d, a_mag);
                    b_mag = (x0.b + x1.b).mul_add(d, b_mag);
                }
                (a_dot_b > 0.).then(|| (sh, a_dot_b / (a_mag * b_mag).sqrt()))
            })
            .max_by(|x, y| x.1.partial_cmp(&y.1).unwrap())
    };
    rt_i_all
        .iter()
        .zip(dec_l)
        .zip(mzml_fs)
        .map(|((rt_i_l, first_dec), mzml)| {
            if mzml.is_ref {
                return Some((0., 1.));
            }
            let mut rt_i = rt_i_l.clone();
            for x in &mut rt_i {
                x.1 = 0f32.max(x.1 - first_dec);
            }
            rt_i_ref_l
                .iter()
                .filter_map(|rt_i_ref| calc_dotp(&mut a_b, &rt_i, rt_i_ref))
                .map(|x| (x, x.0.abs()))
                .min_by(|x, y| x.1.partial_cmp(&y.1).unwrap())
                .map(|x| x.0)
        })
        .collect()
}
fn final_shift(
    rt_sh_l: &[Option<(f32, f32)>],
    &crate::Param { rt_shift_bd, .. }: &crate::Param,
    mzml_fs: &[crate::common::FileA],
) -> Vec<f32> {
    let mut neigh = Vec::new();
    rt_sh_l
        .iter()
        .zip(mzml_fs)
        .enumerate()
        .map(|(i, (sh_sc, crate::common::FileA { ftype, .. }))| {
            sh_sc.map_or(0., |sh_sc| {
                if rt_sh_l[..i]
                    .iter()
                    .rev()
                    .take(4)
                    .filter_map(|x| *x)
                    .filter(|x| (x.0 - sh_sc.0).abs() < 0.031)
                    .count()
                    > 2
                    || rt_sh_l[i + 1..]
                        .iter()
                        .take(4)
                        .filter_map(|x| *x)
                        .filter(|x| (x.0 - sh_sc.0).abs() < 0.031)
                        .count()
                        > 2
                {
                    return sh_sc.0;
                }
                neigh.clear();
                neigh.extend(
                    rt_sh_l[..i]
                        .iter()
                        .rev()
                        .take(4)
                        .chain(rt_sh_l[i + 1..].iter().take(4))
                        .filter_map(|x| *x)
                        .map(|x| x.0),
                );
                if neigh.len() > 5 {
                    let pos = neigh.len() / 2;
                    neigh.sort_unstable_by(|a, b| a.partial_cmp(b).unwrap());
                    let med = if neigh.len() % 2 == 1 {
                        neigh[pos]
                    } else {
                        neigh[pos].midpoint(neigh[pos - 1])
                    };
                    if (med - sh_sc.0).abs() > rt_shift_bd {
                        let pos0 = neigh.partition_point(|x| *x < med - 0.031);
                        if neigh[pos0..].partition_point(|x| *x < med + 0.031) > 5 {
                            return med;
                        }
                    }
                }
                if ftype.contains("BLK") {
                    if neigh.len() > 2 {
                        let pos = neigh.len() / 2;
                        neigh.sort_unstable_by(|a, b| a.partial_cmp(b).unwrap());
                        let med = if neigh.len() % 2 == 1 {
                            neigh[pos]
                        } else {
                            neigh[pos].midpoint(neigh[pos - 1])
                        };
                        let pos0 = neigh.partition_point(|x| *x < med - 0.031);
                        if neigh[pos0..].partition_point(|x| *x < med + 0.031) > 2 {
                            return med;
                        }
                    }
                    return 0.;
                }
                sh_sc.0
            })
        })
        .collect()
}
fn findridge(
    rt_i_l: &[(f32, f32)],
    first_dec: f32,
    wave_scs: &[f32],
    wave_sqrt: &[f32],
    sh: f32,
) -> Vec<RtScCA> {
    struct RtScC {
        rt: f32,
        sc: f32,
        coef: f32,
    }
    let mut rt_i_l: Vec<(f32, f32)> = rt_i_l.to_vec();
    for j in &mut rt_i_l {
        j.1 = 0f32.max(j.1 - first_dec);
    }
    let rerunw = 2. * (rt_i_l.last().unwrap().0 - rt_i_l[0].0) / (rt_i_l.len() - 1) as f32;
    let i_cut = 0.;
    let mut prev = true;
    let (eic_rt, mut calc_p): (Vec<_>, Vec<_>) = rt_i_l
        .iter()
        .zip(&rt_i_l[1..])
        .filter_map(|((rt0, i0), (rt1, i1))| {
            let c = *i0 > i_cut || *i1 > i_cut;
            (c || prev).then(|| {
                prev = c;
                (rt0.midpoint(*rt1), c)
            })
        })
        .unzip();
    calc_p[0] = false;
    calc_p[eic_rt.len() - 1] = false;
    let bisect = |a| rt_i_l.partition_point(|x| x.0 < a);
    let mut coefs = vec![0f32; eic_rt.len() * wave_scs.len()];
    let mut int_i = Vec::new();
    for ((wave_s, w_sqrt), coef_xx) in wave_scs
        .iter()
        .zip(wave_sqrt)
        .zip(coefs.chunks_exact_mut(eic_rt.len()))
    {
        let wave_s_ = wave_s.recip();
        for ((yy, wave_loc), _) in coef_xx
            .iter_mut()
            .zip(&eic_rt)
            .zip(&calc_p)
            .filter(|x| *x.1)
        {
            let pos0 = bisect(wave_loc - rerunw);
            let pos1 = bisect(wave_loc + rerunw);
            let rt_i = &rt_i_l[pos0..pos1];
            if rt_i.is_empty() {
                println!(
                    "missing MS1 scans between {:.2} and {:.2} minutes",
                    rt_i_l[pos0 - 1].0,
                    rt_i_l[pos0].0
                );
                continue;
            }
            int_i.clear();
            int_i.extend(rt_i.iter().map(|(rt0, i0)| {
                let tsig2 = ((rt0 - wave_loc) * wave_s_).powi(2);
                i0 * (-tsig2 / 2.).exp() * (1. - tsig2)
            }));
            *yy = rt_i
                .iter()
                .zip(&int_i)
                .zip(&rt_i[1..])
                .zip(&int_i[1..])
                .map(|((((rt0, _), i0), (rt1, _)), i1)| (i0 + i1) * (rt1 - rt0))
                .sum::<f32>()
                / w_sqrt;
        }
    }
    let mut local_max = Vec::new();
    for coef_xx in coefs.chunks_exact_mut(eic_rt.len()) {
        let mut l_max = Vec::new();
        loop {
            let (max_i, max_coef) = coef_xx
                .iter()
                .copied()
                .enumerate()
                .max_by(|a, b| a.1.partial_cmp(&b.1).unwrap())
                .unwrap();
            if max_coef <= 0. {
                break;
            }
            if coef_xx[max_i - 1] <= 0. || coef_xx[max_i + 1] <= 0. {
                coef_xx[max_i] = 0.;
                continue;
            }
            l_max.push((max_i, max_coef));
            let lo = eic_rt[max_i] - rerunw;
            let up = eic_rt[max_i] + rerunw;
            let lo = eic_rt[..max_i].partition_point(|x| *x <= lo);
            let up = max_i + eic_rt[max_i..].partition_point(|x| *x < up);
            coef_xx[lo..up].fill(0.);
        }
        local_max.push(l_max);
    }
    let mut ridgels: Vec<Vec<RtScC>> = local_max[0]
        .iter()
        .map(|&(max_i, coef)| {
            vec![RtScC {
                rt: eic_rt[max_i],
                sc: wave_scs[0],
                coef,
            }]
        })
        .collect();
    for (xx, scale_coef) in local_max[1..].iter().enumerate() {
        for &(max_i, coef) in scale_coef {
            let rt = eic_rt[max_i];
            if let Some(rl) = ridgels.iter_mut().find(|rl| {
                let rl_last = rl.last().unwrap();
                rl_last.sc == wave_scs[xx]
                    && ((rl_last.rt - rt).abs() < 0.01
                        || bisect(rt).abs_diff(bisect(rl_last.rt)) < 2)
            }) {
                rl.push(RtScC {
                    rt,
                    sc: wave_scs[xx + 1],
                    coef,
                });
            } else {
                ridgels.push(vec![RtScC {
                    rt,
                    sc: wave_scs[xx + 1],
                    coef,
                }]);
            }
        }
    }
    let peaks: Vec<RtScCA> = ridgels
        .into_iter()
        .filter(|x| x.len() > 1)
        .map(|rd| {
            let p_loc = rd
                .into_iter()
                .max_by(|a, b| a.coef.partial_cmp(&b.coef).unwrap())
                .unwrap();
            let pos = bisect(p_loc.rt);
            RtScCA {
                rt: p_loc.rt - sh,
                auc: rt_i_l[pos - 1].1 + rt_i_l[pos].1,
            }
        })
        .collect();
    if peaks.is_empty() {
        return vec![RtScCA {
            rt: rt_i_l[0].0.midpoint(rt_i_l.last().unwrap().0) - sh,
            auc: 1.,
        }];
    }
    peaks
}
