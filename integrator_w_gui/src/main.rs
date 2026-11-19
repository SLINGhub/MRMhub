// declares the shared utility module
mod common;
// declares the feature detection module
mod feat;
// declares the area calculation module
mod get_auc;
// declares the mzml reader module
mod read_mzml;
// emits bounded, monotonic workflow progress for the desktop GUI
mod progress;

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
// names the worker version reported by the command line
const VERSION: &str = env!("CARGO_PKG_VERSION");
use std::error::Error;
use std::path::PathBuf;
// stores the parameters used across the integration workflow
struct Param {
    mzml_fs: Vec<PathBuf>,
    peak_w: (f32, f32, f32, f32),
    crop_window: Option<(f32, f32)>,
    sn_noise: common::Noise,
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
    let arg1 = args.next();
    if matches!(arg1.as_deref(), Some("--version" | "-V")) {
        println!("MRMhub INTEGRATOR {VERSION}");
        return Ok(());
    }
    let project_dir = std::env::var_os("MRMHUB_PROJECT_DIR")
        .map(PathBuf::from)
        .unwrap_or(std::env::current_exe()?.parent().unwrap().to_path_buf());
    std::env::set_current_dir(project_dir)?;
    let param_t = common::read_param()?;
    rayon::ThreadPoolBuilder::new()
        .num_threads(param_t.num_t)
        .build_global()?;
    match arg1.as_deref() {
        Some("1") => read_mzml::read(&param_t)?,
        Some("2") => feat::detect(&param_t)?,
        Some("3") => get_auc::calc_auc(&param_t)?,
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
        "3" => get_auc::calc_auc(&param_t)?,
        "4" => gen_plots()?,
        _ => return Ok(()),
    }
    println!("----------Completed, {:.1?}----------", start.elapsed());
    Ok(())
}
// generates the chromatogram pdf files with the r plotting script
fn gen_plots() -> Result<(), Box<dyn Error>> {
    use std::io::Write;
    use std::process::{Command, Stdio};
    let mut command =
        Command::new(std::env::var_os("MRMHUB_RSCRIPT").unwrap_or_else(|| "Rscript".into()));
    let project_script = std::path::Path::new("MRMhub_plot.r");
    if project_script.is_file() {
        let source = std::fs::read_to_string(project_script)?;
        // Unmodified scripts distributed with GUI 1.2.5 / integrator 1.0.1–2
        // use older plot logic or a different binary layout. Keep custom scripts.
        if !matches!(
            crc32fast::hash(source.replace("\r\n", "\n").as_bytes()),
            0xda418536 | 0xab4049de | 0xd39a8e32
        ) {
            return run_plot_command(command.arg(project_script));
        }
    }
    let mut child = command
        .args(["--vanilla", "-"])
        .stdin(Stdio::piped())
        .spawn()?;
    let written = child
        .stdin
        .take()
        .unwrap()
        .write_all(include_bytes!("../MRMhub_plot.r"));
    let status = child.wait()?;
    written?;
    if !status.success() {
        return Err(
            format!("Report generation failed ({status}). See the R output for details.").into(),
        );
    }
    Ok(())
}

fn run_plot_command(command: &mut std::process::Command) -> Result<(), Box<dyn Error>> {
    let status = command.status()?;
    if !status.success() {
        return Err(
            format!("Report generation failed ({status}). See the R output for details.").into(),
        );
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn exit_command(code: u8) -> std::process::Command {
        #[cfg(unix)]
        let mut command = {
            let mut command = std::process::Command::new("/bin/sh");
            command.arg("-c");
            command
        };
        #[cfg(windows)]
        let mut command = {
            let mut command = std::process::Command::new("cmd.exe");
            command.arg("/C");
            command
        };
        command.arg(format!("exit {code}"));
        command
    }

    #[test]
    fn report_generation_propagates_the_child_exit_status() {
        assert!(run_plot_command(&mut exit_command(0)).is_ok());
        let error = run_plot_command(&mut exit_command(7))
            .unwrap_err()
            .to_string();
        assert!(error.contains("Report generation failed"), "{error}");
        assert!(error.contains('7'), "{error}");
    }
}
