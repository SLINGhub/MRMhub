# INTEGRATOR

**INTEGRATOR** is the raw-data processing module of [MRMhub](https://github.com/SLINGhub/MRMhub):
automated peak detection, picking, and integration for targeted Multiple Reaction Monitoring (MRM)
mass-spectrometry data. It is a stand-alone application — it does **not** depend on the `mrmhub` R
package and ships as a pre-built executable.

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

```bash
cd integrator
cargo build --release
```

Releases are built and published automatically by
[`.github/workflows/integrator-release.yml`](../.github/workflows/integrator-release.yml) when a
GitHub Release is published — it cross-compiles the executable for macOS and Windows and attaches the
binaries to the Release.

## Layout

| Path | Purpose |
|------|---------|
| `Cargo.toml`, `src/` | Rust crate (the executable) — *in progress* |
| `MRMhub_plot.r` | Base-R per-transition PDF plotting, invoked by the executable |
