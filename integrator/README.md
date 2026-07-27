# INTEGRATOR

**INTEGRATOR** is the raw-data processing module of [MRMhub](https://github.com/SLINGhub/MRMhub):
automated peak detection, picking, and integration for targeted MRM mass-spectrometry data. It is a
stand-alone executable and does **not** depend on the `mrmhub` R package. It reads a `param.txt` and
input files from its own folder and writes `long.csv` / `quant_raw.csv`, which the QUANT R package
ingests via `mrmhub::import_data_mrmhub()`. A companion viewer, **MRMhub-viz**, reviews the results.

## Install

INTEGRATOR is a portable executable — no installation. Download the archive for your platform, unzip,
and run `MRMhub` from the folder (keep one copy per analysis project). Download links, first-launch
security steps, input files, and full usage are in the
**[INTEGRATOR manual](https://slinghub.github.io/MRMhub/integrator/)**.

## Build from source

Requires **Rust** (stable, via [rustup](https://rustup.rs); edition 2024 needs Rust ≥ 1.85); on
**Windows** also the MSVC C++ Build Tools.

```bash
cd integrator
cargo build --release        # → target/release/MRMhub  (MRMhub.exe on Windows)
```

`MRMhub --version` prints the version. At startup the executable runs from its own folder, so
`param.txt`, the input files, and `MRMhub_plot.r` must sit next to it; step 4 (PDF plots) requires R.

## Documentation

Full manual: <https://slinghub.github.io/MRMhub/integrator/>
