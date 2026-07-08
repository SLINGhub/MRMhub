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
    let arg1 = args.next();
    // Report the version without needing a param.txt / working directory.
    if matches!(arg1.as_deref(), Some("--version" | "-V")) {
        println!("MRMhub INTEGRATOR {VERSION}");
        return Ok(());
    }
    std::env::set_current_dir(std::env::current_exe()?.parent().unwrap())?;
    let param_t = common::read_param()?;
    rayon::ThreadPoolBuilder::new()
        .num_threads(param_t.num_t)
        .build_global()?;
    match arg1.as_deref() {
        Some("1") => read_mzml::read(&param_t)?,
        Some("2") => feat::detect(&param_t)?,
        Some("3") => get_auc::calc_auc()?,
        Some("4") => gen_plots()?,
        _ => {
            println!(
                r"
███    ███ ██████  ███    ███ ██   ██ ██    ██ ██████
████  ████ ██   ██ ████  ████ ██   ██ ██    ██ ██   ██
██ ████ ██ ██████  ██ ████ ██ ███████ ██    ██ ██████
██  ██  ██ ██   ██ ██  ██  ██ ██   ██ ██    ██ ██   ██
██      ██ ██   ██ ██      ██ ██   ██  ██████  ██████  "
            );
            println!("  targeted MRM peak integration  v{VERSION}");
            loop {
                if let Err(x) = handle_input() {
                    use yansi::Paint;
                    println!("{}", format!("Error: {x}").white().on_red().bright());
                }
            }
        }
    }
    Ok(())
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
    Command::new("Rscript")
        .arg("MRMhub_plot.r")
        .stdout(Stdio::inherit())
        .output()?;
    Ok(())
}
