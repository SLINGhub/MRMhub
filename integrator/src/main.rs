// declares the shared utility module
mod common;
// declares the feature detection module
mod feat;
// declares the area calculation module
mod get_auc;
// declares the mzml reader module
mod read_mzml;

// names the directory used for intermediate files
const MISCDIR: &str = "misc";
// names the retention time matrix file
const RTM: &str = "RT_matrix.csv";
// names the validated transition list file
const TRANS_L: &str = "trans_list.bin";
// names the transition baseline sidecar file
const TRANS_BL: &str = "trans_baseline.bin";
// names the mzml sample list file
const MZML_L: &str = "mzML_list.txt";
use std::error::Error;
use std::path::PathBuf;
// stores the parameters used across the integration workflow
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

// starts the requested workflow step or the interactive menu
fn main() -> Result<(), Box<dyn Error>> {
    let mut args = std::env::args();
    args.next();
    std::env::set_current_dir(std::env::current_exe()?.parent().unwrap())?;
    let param_t = common::read_param()?;
    rayon::ThreadPoolBuilder::new()
        .num_threads(param_t.num_t)
        .build_global()?;
    match args.next().as_deref() {
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

// reads and runs a workflow step from the interactive menu
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
// generates the chromatogram pdf files with the r plotting script
fn gen_plots() -> Result<(), Box<dyn Error>> {
    use std::process::{Command, Stdio};
    Command::new("Rscript")
        .arg("MRMhub_plot.r")
        .stdout(Stdio::inherit())
        .output()?;
    Ok(())
}
