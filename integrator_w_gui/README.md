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

Once the Rust crate is in place:
To compile on Mac:
- Download the source and cd bash directory to the MRMhub folder
- run `bash integrator_w_gui/gui/build-macos.sh`
- output in integrator_w_gui/gui/src-tauri/target/release, put both executables in the same directory to run (may need to verify security perms on newer versions of OSX!)
- an error may print in bash after build is done, you can ignore it as it doesn't affect the actual build (related to windows style crlf line endings being used)
- IF you are unable to run the script at all and it exits with errors, cd to the repo folder and run:
```bash
perl -pi -e 's/\r$//' integrator_w_gui/gui/build-macos.sh
chmod +x integrator_w_gui/gui/build-macos.sh
./integrator_w_gui/gui/build-macos.sh
```

To compile on Windows:
- Download the source and cd bash directory to the MRMhub folder
- run `cargo build --release --manifest-path integrator_w_gui/Cargo.toml`
- outputs in /integrator_w_gui/gui/src-tauri-target/release; MRMhub-integrator-worker.exe must be in the same directory to run the gui !

Releases are built and published automatically by
[`.github/workflows/integrator-release.yml`](../.github/workflows/integrator-release.yml) when a
GitHub Release is published — it cross-compiles the executable for macOS and Windows and attaches the
binaries to the Release.

## Layout

| Path | Purpose |
|------|---------|
| `Cargo.toml`, `src/` | Rust crate (the executable) — *in progress* |
| `MRMhub_plot.r` | Base-R per-transition PDF plotting, invoked by the executable |
