//! One-time, conservative old-name detection. Never delete user data or the running app.
use serde::Serialize;
use std::{fs, path::{Path, PathBuf}};
use tauri::Manager;

const OLD_NAME: &str = "MRMhub Integrator GUI";
const MARKER: &str = "gui-rename-notice-v1.done";

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub struct Notice {
    paths: Vec<String>,
    can_trash: bool,
    instructions: String,
}

fn marker(app: &tauri::AppHandle) -> Result<PathBuf, String> {
    Ok(app.path().app_data_dir().map_err(|e| e.to_string())?.join(MARKER))
}

fn safe_separate_install(path: &Path, executable: &Path) -> bool {
    // No symlinked app/directory and no installation containing this executable.
    let Ok(metadata) = fs::symlink_metadata(path) else { return false; };
    if !metadata.is_dir() || metadata.file_type().is_symlink() { return false; }
    match (path.canonicalize(), executable.canonicalize()) {
        (Ok(candidate), Ok(current)) => !current.starts_with(candidate),
        _ => false,
    }
}

#[cfg(target_os = "macos")]
fn old_installs(home: &Path, executable: &Path, processes: &super::processes::ProcessState) -> Vec<PathBuf> {
    [PathBuf::from("/Applications"), home.join("Applications")].into_iter()
        .map(|base| base.join(format!("{OLD_NAME}.app")))
        .filter(|path| {
            if !safe_separate_install(path, executable) { return false; }
            let output = processes.output(std::process::Command::new("/usr/libexec/PlistBuddy")
                .args(["-c", "Print :CFBundleIdentifier"]).arg(path.join("Contents/Info.plist")));
            matches!(output, Ok(ref out) if out.status.success() && String::from_utf8_lossy(&out.stdout).trim() == "org.slinghub.mrmhub.integrator")
        }).collect()
}

#[cfg(target_os = "windows")]
fn old_installs(_home: &Path, executable: &Path, processes: &super::processes::ProcessState) -> Vec<PathBuf> {
    use std::os::windows::process::CommandExt;
    let mut candidates = Vec::new();
    for name in ["LOCALAPPDATA", "ProgramFiles", "ProgramFiles(x86)"] {
        if let Some(base) = std::env::var_os(name) {
            let base = PathBuf::from(base);
            candidates.push(base.join(OLD_NAME));
            if name == "LOCALAPPDATA" { candidates.push(base.join("Programs").join(OLD_NAME)); }
        }
    }
    // Read the old product's exact uninstall registration in both registry views.
    // UTF-8 JSON preserves non-ASCII custom paths; never execute UninstallString.
    let script = r#"[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
$paths = @()
foreach ($hive in @('CurrentUser', 'LocalMachine')) {
  foreach ($view in @('Registry64', 'Registry32')) {
    $base = $null; $key = $null
    try {
      $base = [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::$hive, [Microsoft.Win32.RegistryView]::$view)
      $key = $base.OpenSubKey('Software\Microsoft\Windows\CurrentVersion\Uninstall\MRMhub Integrator GUI')
      if ($key -and $key.GetValue('DisplayName') -eq 'MRMhub Integrator GUI') {
        $location = $key.GetValue('InstallLocation')
        if ($location) { $paths += $location.Trim('"') }
      }
    } catch {} finally { if ($key) { $key.Dispose() }; if ($base) { $base.Dispose() } }
  }
}
ConvertTo-Json -InputObject @($paths) -Compress"#;
    if let Some(system) = std::env::var_os("SystemRoot") {
        let powershell = PathBuf::from(system).join(r"System32\WindowsPowerShell\v1.0\powershell.exe");
        if let Ok(out) = processes.output(std::process::Command::new(powershell)
            .args(["-NoLogo", "-NoProfile", "-NonInteractive", "-Command", script])
            .creation_flags(0x08000000)) {
            if out.status.success() {
                if let Ok(paths) = serde_json::from_slice::<Vec<String>>(&out.stdout) { candidates.extend(paths.into_iter().map(PathBuf::from)); }
            }
        }
    }
    candidates.retain(|path| safe_separate_install(path, executable) && path.join("mrmhub-integrator-gui.exe").is_file());
    candidates.sort(); candidates.dedup(); candidates
}

#[cfg(not(any(target_os = "macos", target_os = "windows")))]
fn old_installs(_home: &Path, _executable: &Path, _processes: &super::processes::ProcessState) -> Vec<PathBuf> { Vec::new() }

fn detect(app: &tauri::AppHandle) -> Result<Vec<PathBuf>, String> {
    let home = app.path().home_dir().map_err(|e| e.to_string())?;
    let executable = std::env::current_exe().map_err(|e| e.to_string())?;
    Ok(old_installs(&home, &executable, &app.state::<super::processes::ProcessState>()))
}

#[tauri::command]
pub fn rename_notice_acknowledge(app: tauri::AppHandle) -> Result<(), String> {
    let path = marker(&app)?;
    fs::create_dir_all(path.parent().unwrap()).map_err(|e| e.to_string())?;
    fs::write(path, b"Shown or checked for the GUI rename.\n").map_err(|e| e.to_string())
}

#[tauri::command]
pub fn rename_notice(app: tauri::AppHandle) -> Result<Option<Notice>, String> {
    if marker(&app)?.try_exists().map_err(|e| e.to_string())? { return Ok(None); }
    let paths = detect(&app)?;
    if paths.is_empty() { rename_notice_acknowledge(app)?; return Ok(None); }
    let instructions = if cfg!(target_os = "macos") {
        "To remove it manually: quit the old app, open Finder → Applications (or Go → Go to Folder for the path below), find MRMhub Integrator GUI, and move only that old app to Trash. Keep MRMhub GUI. If macOS asks, enter your administrator password in Finder. Your datasets and app settings are not part of this cleanup."
    } else {
        "To remove the old version safely: quit MRMhub Integrator GUI, open Settings → Apps → Installed apps (Apps & features on Windows 10), find the exact old name MRMhub Integrator GUI, and choose Uninstall. Keep MRMhub GUI. Leave any option to remove application data/settings unchecked: both names share those settings. If no old entry exists, check the old installation folder below and use its uninstaller. Do not delete a folder containing your new app."
    };
    Ok(Some(Notice { paths: paths.iter().map(|p| p.display().to_string()).collect(), can_trash: cfg!(target_os = "macos"), instructions: instructions.into() }))
}

#[cfg(target_os = "macos")]
fn move_to_trash(source: &Path, trash: &Path) -> Result<PathBuf, String> {
    // Reserve a unique container: never overwrite an existing Trash item.
    let container = trash.join(format!("MRMhub-old-app-{}", std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).map_err(|e| e.to_string())?.as_nanos()));
    fs::create_dir(&container).map_err(|e| e.to_string())?;
    let destination = container.join(source.file_name().ok_or("Invalid old app path")?);
    if let Err(error) = fs::rename(source, &destination) {
        let _ = fs::remove_dir(&container); // Only our own empty reservation.
        return Err(error.to_string());
    }
    Ok(destination)
}

#[tauri::command]
pub fn rename_trash_old_app(app: tauri::AppHandle) -> Result<String, String> {
    #[cfg(target_os = "macos")]
    {
        // UI supplies no paths. Revalidate the exact known bundles on every click.
        let paths = detect(&app)?;
        if paths.is_empty() { return Ok("No separate old-name installation remains.".into()); }
        let trash = app.path().home_dir().map_err(|e| e.to_string())?.join(".Trash");
        let mut messages = Vec::new();
        for path in paths {
            match move_to_trash(&path, &trash) {
                Ok(destination) => messages.push(format!("Moved {} to {}. You can restore it from Trash.", path.display(), destination.display())),
                Err(e) => messages.push(format!("Could not move {}: {e}. Use the Finder instructions below; no administrator privileges are requested by the app.", path.display())),
            }
        }
        Ok(messages.join("\n\n"))
    }
    #[cfg(not(target_os = "macos"))]
    { let _ = app; Err("Use the operating system's uninstaller; direct folder deletion is not supported.".into()) }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn never_offer_the_running_installation_or_a_symlink() {
        let base = std::env::temp_dir().join(format!("mrmhub-rename-test-{}", std::process::id()));
        fs::create_dir_all(base.join("old")).unwrap(); fs::create_dir_all(base.join("new")).unwrap();
        let old = base.join("old"); let new_exe = base.join("new/app"); let old_exe = old.join("app");
        fs::write(&new_exe, "test").unwrap(); fs::write(&old_exe, "test").unwrap();
        assert!(safe_separate_install(&old, &new_exe));
        assert!(!safe_separate_install(&old, &old_exe));
        assert!(!safe_separate_install(&base.join("missing"), &new_exe));
        #[cfg(unix)] { std::os::unix::fs::symlink(&old, base.join("link")).unwrap(); assert!(!safe_separate_install(&base.join("link"), &new_exe)); }
        fs::remove_dir_all(base).unwrap();
    }
    #[cfg(target_os = "macos")]
    #[test]
    fn trash_is_recoverable_and_never_overwrites_existing_items() {
        let base = std::env::temp_dir().join(format!("mrmhub-trash-test-{}", std::process::id()));
        let old = base.join("old.app"); let trash = base.join("Trash");
        fs::create_dir_all(&old).unwrap(); fs::create_dir_all(&trash).unwrap();
        fs::write(old.join("binary"), "original").unwrap();
        fs::write(trash.join("old.app"), "keep").unwrap();
        let moved = move_to_trash(&old, &trash).unwrap();
        assert!(!old.exists()); assert_eq!(fs::read_to_string(moved.join("binary")).unwrap(), "original");
        assert_eq!(fs::read_to_string(trash.join("old.app")).unwrap(), "keep");
        fs::remove_dir_all(base).unwrap();
    }
}
