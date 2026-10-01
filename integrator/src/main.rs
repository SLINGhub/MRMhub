mod common;
mod feat;
mod get_auc;
mod read_mzml;

const MISCDIR: &str = "misc";
const RTM: &str = "RT_matrix.csv";
const TRANS_L: &str = "trans_list.bin";
const MZML_L: &str = "mzML_list.txt";
const VERSION: &str = env!("CARGO_PKG_VERSION");
use std::error::Error;
use std::path::PathBuf;
struct Param {
    mzml_fs: Vec<PathBuf>,
    peak_w: (f32, f32, f32, f32),
    crop_window: Option<(f32, f32)>,
    batch_i: PathBuf,
    t_list: PathBuf,
    num_t: usize,
    mz_tol: f32,
    rt_tol: f32,
    rt_shift: (f32, f32),
    rt_shift_bd: f32,
}

fn main() -> Result<(), Box<dyn Error>> {
    let mut args = std::env::args();
    args.next();
    let arg_1 = args.next();
    if matches!(arg_1.as_deref(), Some("--version" | "-V")) {
        println!("MRMhub INTEGRATOR {VERSION}");
        return Ok(());
    }
    std::env::set_current_dir(std::env::current_exe()?.parent().unwrap())?;
    let param_t = common::read_param()?;
    rayon::ThreadPoolBuilder::new()
        .num_threads(param_t.num_t)
        .build_global()?;
    match arg_1.as_deref() {
        Some("1") => read_mzml::read(&param_t),
        Some("2") => feat::detect(&param_t),
        Some("3") => get_auc::calc_auc(),
        Some("4") => gen_plots(),
        _ => {
            println!("\ntargeted MRM peak integration  v{VERSION}");
            loop {
                if let Err(x) = handle_input() {
                    use yansi::Paint;
                    println!("{}", format!("Error: {x}").white().on_red().bright());
                }
            }
        }
    }
}

fn handle_input() -> Result<(), Box<dyn Error>> {
    println!(
        "
Enter number.
1: Validate data,
2: RT shift estimation | Feature detection,
3: Update integration bounds, areas (using RT_matrix.csv),
4: Generate chromatograms in PDFs (optional)"
    );
    let mut guess = String::new();
    std::io::stdin().read_line(&mut guess)?;
    let param_t = common::read_param()?;
    let start = std::time::Instant::now();
    match guess.trim() {
        "1" => read_mzml::read(&param_t)?,
        "2" => feat::detect(&param_t)?,
        "3" => get_auc::calc_auc()?,
        "4" => gen_plots()?,
        _ => return Ok(()),
    }
    println!("----------Completed, {:.1?}----------", start.elapsed());
    Ok(())
}
fn gen_plots() -> Result<(), Box<dyn Error>> {
    use std::process::{Command, Stdio};
    let rscript = find_rscript().ok_or("R not found: install R or add it to PATH")?;
    Command::new(rscript)
        .arg("MRMhub_plot.r")
        .stdout(Stdio::inherit())
        .output()?;
    Ok(())
}

/// `Rscript` on PATH; on Windows otherwise the newest R installed for all users
/// (Program Files) or for the current user (LOCALAPPDATA).
fn find_rscript() -> Option<PathBuf> {
    use std::process::Command;
    if Command::new("Rscript").arg("--version").output().is_ok() {
        return Some(PathBuf::from("Rscript"));
    }
    if !cfg!(target_os = "windows") {
        return None;
    }
    let mut roots = vec![PathBuf::from(r"C:\Program Files\R")];
    if let Some(local) = std::env::var_os("LOCALAPPDATA") {
        roots.push(PathBuf::from(local).join("Programs").join("R"));
    }
    let found = roots
        .iter()
        .filter_map(|root| glob::glob(&root.join(r"R-*\bin\Rscript.exe").to_string_lossy()).ok())
        .flat_map(|paths| paths.filter_map(Result::ok))
        .collect();
    newest_r(found)
}

/// Compares the `R-x.y.z` folder versions numerically (R-4.10 is newer than R-4.9).
fn newest_r(paths: Vec<PathBuf>) -> Option<PathBuf> {
    paths.into_iter().max_by_key(|p| {
        p.iter()
            .filter_map(|c| c.to_str()?.strip_prefix("R-"))
            .next_back()
            .map(|v| {
                v.split('.')
                    .filter_map(|n| n.parse::<u32>().ok())
                    .collect::<Vec<_>>()
            })
            .unwrap_or_default()
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    fn rscript(version: &str) -> PathBuf {
        PathBuf::from(format!("C:/Program Files/R/R-{version}/bin/Rscript.exe"))
    }

    #[test]
    fn newest_r_compares_versions_numerically() {
        let found = vec![rscript("4.10.0"), rscript("4.5.1"), rscript("4.9.2")];
        assert_eq!(newest_r(found), Some(rscript("4.10.0")));
    }
}
