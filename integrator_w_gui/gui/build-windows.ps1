[CmdletBinding()]
param(
    [ValidateSet("Lightweight", "Offline")]
    [string]$InstallerMode = "Lightweight",

    [string]$OutputDirectory
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Invoke-NativeCommand {
    param(
        [Parameter(Mandatory = $true)]
        [scriptblock]$Command,

        [Parameter(Mandatory = $true)]
        [string]$FailureMessage
    )

    # Windows PowerShell 5 can turn ordinary native stderr progress into error records.
    # Let the program run and use its exit code as the source of truth instead.
    $PreviousPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = "Continue"
        & $Command
        $ExitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $PreviousPreference
    }

    if ($ExitCode -ne 0) {
        throw "$FailureMessage (exit code $ExitCode)."
    }
}

function Test-TauriCli {
    $PreviousPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = "Continue"
        cargo tauri --version 2>$null | Out-Null
        return $LASTEXITCODE -eq 0
    }
    finally {
        $ErrorActionPreference = $PreviousPreference
    }
}

$GuiRoot = $PSScriptRoot
$IntegratorRoot = Split-Path -Parent $GuiRoot
$IntegratorManifest = Join-Path $IntegratorRoot "Cargo.toml"
$TauriRoot = Join-Path $GuiRoot "src-tauri"
$TauriConfig = Join-Path $TauriRoot "tauri.conf.json"
$LightweightConfig = Join-Path $TauriRoot "tauri.lightweight.conf.json"
$SidecarDirectory = Join-Path $TauriRoot "binaries"

if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $GuiRoot "dist"
}
$OutputDirectory = [System.IO.Path]::GetFullPath($OutputDirectory)

if ($env:OS -ne "Windows_NT") {
    throw "This script must be run on Windows."
}

foreach ($CommandName in @("cargo", "rustc")) {
    if (-not (Get-Command $CommandName -ErrorAction SilentlyContinue)) {
        throw "Required command '$CommandName' was not found. Install Rust with rustup and try again."
    }
}

$PreviousPreference = $ErrorActionPreference
try {
    $ErrorActionPreference = "Continue"
    $RustcDetails = rustc -vV
    $RustcExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $PreviousPreference
}
$HostLine = $RustcDetails | Select-String "^host:"
if ($RustcExitCode -ne 0 -or -not $HostLine) {
    throw "Could not determine the Rust host target."
}
$TargetTriple = $HostLine.ToString().Split(":", 2)[1].Trim()
if ($TargetTriple -notmatch "-pc-windows-") {
    throw "The active Rust host '$TargetTriple' is not a Windows target."
}

if (-not (Test-TauriCli)) {
    Write-Host "Installing Tauri CLI 2..."
    Invoke-NativeCommand -FailureMessage "Tauri CLI installation failed" -Command {
        cargo install tauri-cli --version "^2" --locked
    }
}

Write-Host "Building MRMhub Integrator worker for $TargetTriple..."
Invoke-NativeCommand -FailureMessage "MRMhub Integrator worker build failed" -Command {
    cargo build `
        --release `
        --locked `
        --target $TargetTriple `
        --manifest-path $IntegratorManifest
}

$WorkerSource = Join-Path $IntegratorRoot "target\$TargetTriple\release\MRMhub-integrator.exe"
$WorkerDestination = Join-Path $SidecarDirectory "MRMhub-integrator-worker-$TargetTriple.exe"
if (-not (Test-Path -LiteralPath $WorkerSource -PathType Leaf)) {
    throw "Expected worker executable was not created at '$WorkerSource'."
}
New-Item -ItemType Directory -Force -Path $SidecarDirectory | Out-Null
Copy-Item -LiteralPath $WorkerSource -Destination $WorkerDestination -Force

$BuildArguments = @("tauri", "build", "--bundles", "nsis")
if ($InstallerMode -eq "Lightweight") {
    $BuildArguments += @("--config", $LightweightConfig)
}

Write-Host "Building the $($InstallerMode.ToLowerInvariant()) Windows installer..."
Push-Location $TauriRoot
try {
    Invoke-NativeCommand -FailureMessage "Tauri installer build failed" -Command {
        cargo @BuildArguments
    }
}
finally {
    Pop-Location
}

$Config = Get-Content -LiteralPath $TauriConfig -Raw | ConvertFrom-Json
$BundleDirectory = Join-Path $TauriRoot "target\release\bundle\nsis"
$InstallerPattern = "$($Config.productName)_$($Config.version)_*-setup.exe"
$Installer = Get-ChildItem -LiteralPath $BundleDirectory -Filter $InstallerPattern -File |
    Where-Object { $_.Name -notlike "*_lightweight-setup.exe" } |
    Sort-Object LastWriteTimeUtc -Descending |
    Select-Object -First 1
if (-not $Installer) {
    throw "The completed NSIS installer could not be found in '$BundleDirectory'."
}

New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
$OutputName = if ($InstallerMode -eq "Lightweight") {
    $Installer.BaseName -replace "-setup$", "_lightweight-setup"
} else {
    $Installer.BaseName
}
$FinalInstaller = Join-Path $OutputDirectory "$OutputName$($Installer.Extension)"
Copy-Item -LiteralPath $Installer.FullName -Destination $FinalInstaller -Force

$FinalFile = Get-Item -LiteralPath $FinalInstaller
$Hash = Get-FileHash -LiteralPath $FinalInstaller -Algorithm SHA256
Write-Host ""
Write-Host "Build complete."
Write-Host "Installer: $($FinalFile.FullName)"
Write-Host "Size: $([math]::Round($FinalFile.Length / 1MB, 2)) MB"
Write-Host "SHA256: $($Hash.Hash)"
