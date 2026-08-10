# INTEGRATOR

**INTEGRATOR** is the raw-data processing module of [MRMhub](https://github.com/SLINGhub/MRMhub):
automated peak detection, picking, and integration for targeted Multiple Reaction Monitoring (MRM)
mass-spectrometry data. It is a stand-alone application — it does **not** depend on the `mrmhub` R
package and ships as a pre-built executable.

**THIS VERSION INCLUDES A FEW OPTIONAL CHANGES & THE GUI. THE ORIGINAL SOURCE CODE EVERYTHING IS BASED OFF OF IS IN ../integrator**

## What it does

INTEGRATOR reads its configuration from a `param.txt` file in the working directory, processes the
input chromatograms, and emits two tables consumed by the QUANT R package:

- `quant_raw.csv` — wide-format peak areas (feature × sample)
- `long.csv` — long-format peaks with areas, retention times, and per-pair parameters

The two MRMhub tools are coupled **only** through these files: INTEGRATOR writes them, then
`mrmhub::import_data_mrmhub()` ingests `long.csv`. There are no shared code paths.

A companion visualizer (`MRMhub-viz`) lets you inspect every transition's integration result, and
`MRMhub_plot.r` (base R + `parallel`, no `mrmhub` dependency) renders per-transition PDFs in the
executable's "Step 4".

## Install / run

Download the latest pre-built executable for macOS (Apple Silicon) or Windows from the
[Releases page](https://github.com/SLINGhub/MRMhub/releases), unzip, and run. First-launch security
setup and a full walkthrough are in the
[INTEGRATOR Manual](https://slinghub.github.io/MRMhub/integrator-manual.html).

## Building from source

> **Note:** INTEGRATOR is being rewritten in Rust. The Rust crate lives in this directory
> (`integrator/Cargo.toml`).

### Signed macOS DMG

The macOS builder creates a universal app (Apple Silicon + Intel), embeds the worker binary, signs
the app and DMG with a `Developer ID Application` certificate, submits the DMG to Apple's notary
service, staples the ticket, and verifies the result with Gatekeeper.

One-time setup:

1. Install a `Developer ID Application` certificate **and its private key** in the login Keychain.
   Confirm that macOS can use it:

   ```bash
   security find-identity -v -p codesigning
   ```

2. Save notarization credentials in the Keychain. `notarytool` prompts securely for an Apple ID,
   Team ID, and app-specific password (or App Store Connect API-key details):

   ```bash
   xcrun notarytool store-credentials "mrmhub-notary" \
     --apple-id "YOUR_APPLE_ACCOUNT_EMAIL" \
     --team-id "L6FU3FBMXX"
   ```

Create a distributable DMG from the repository root:

```bash
./integrator_w_gui/gui/build-macos.sh
```

The finished DMG is copied to `integrator_w_gui/gui/dist/`. Run
`./integrator_w_gui/gui/build-macos.sh --help` for architecture, identity, profile, and output
options. If the active command-line developer directory points at Command Line Tools, the builder
automatically uses `/Applications/Xcode.app` without requiring an administrator-level
`xcode-select` change. For a local test build that deliberately skips Developer ID signing and
notarization, use:

```bash
./integrator_w_gui/gui/build-macos.sh --ad-hoc
```

### Windows

From PowerShell, build the worker and a lightweight Windows installer with:

```powershell
.\integrator_w_gui\gui\build-windows.ps1
```

The finished installer is copied to `integrator_w_gui/gui/dist/`. The script installs Tauri CLI 2
when needed and bundles the correctly named worker automatically. For a larger installer that also
includes the offline WebView2 runtime, run:

```powershell
.\integrator_w_gui\gui\build-windows.ps1 -InstallerMode Offline
```

Use `-OutputDirectory <path>` to copy the finished installer somewhere else.

Releases are built and published automatically by
[`.github/workflows/integrator-release.yml`](../.github/workflows/integrator-release.yml) when a
GitHub Release is published — it cross-compiles the executable for macOS and Windows and attaches the
binaries to the Release.

## Layout

| Path | Purpose |
|------|---------|
| `Cargo.toml`, `src/` | Rust crate (the executable) — *in progress* |
| `MRMhub_plot.r` | Base-R per-transition PDF plotting, invoked by the executable |
