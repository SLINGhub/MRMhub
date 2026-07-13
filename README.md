# MRMhub <a href="https://slinghub.github.io/MRMhub/"><img src="man/figures/logo.png" alt="MRMhub logo" align="right" height="139"/></a>

<!-- badges: start -->
[![Lifecycle: stable](https://img.shields.io/badge/lifecycle-stable-brightgreen.svg)](https://lifecycle.r-lib.org/articles/stages.html) [![R-CMD-check](https://github.com/SLINGhub/MRMhub/actions/workflows/R-CMD-check.yml/badge.svg)](https://github.com/SLINGhub/MRMhub/actions/workflows/R-CMD-check.yml) [![Codecov test coverage](https://codecov.io/gh/SLINGhub/MRMhub/graph/badge.svg)](https://app.codecov.io/gh/SLINGhub/MRMhub) [![License: AGPL v3](https://img.shields.io/badge/License-AGPLv3-blue.svg)](https://www.gnu.org/licenses/agpl-3.0)
<!-- badges: end -->

Open-source toolchain for targeted Multiple Reaction Monitoring (MRM) mass spectrometry — from raw vendor files to QC'd quantitative reports. Two modules that work independently or together:

- **INTEGRATOR** — stand-alone application for peak detection, picking, and integration. Pre-built executable, no Python install required.
- **QUANT** (the `mrmhub` R package) — the post-processing pipeline: ISTD normalisation, drift/batch correction, ISTD- or calibration-based quantitation, QC metrics, filtering, reporting. Accepts integrated peaks from INTEGRATOR **and** vendor outputs (MassHunter, Skyline, MS-DIAL, generic CSV).

> **New here?** Install QUANT and run a [5-minute first analysis](https://slinghub.github.io/MRMhub/quant/articles/tutorial-00-first-analysis.html) on bundled demo data — no files of your own required.

## Choose your path

| If you have... | Use | Start here |
|---|---|---|
| Raw vendor files (`.raw`, `.d`, `.wiff`) | INTEGRATOR + QUANT | [Releases](https://github.com/SLINGhub/MRMhub/releases) → [Docs hub](https://slinghub.github.io/MRMhub/) |
| Integrated peaks (MassHunter, Skyline, MS-DIAL) | QUANT only | [QUANT install](https://slinghub.github.io/MRMhub/quant/articles/manual-00-installation.html) |
| Only peak picking | INTEGRATOR only | [Releases](https://github.com/SLINGhub/MRMhub/releases) |

## Install

- **INTEGRATOR:** download from [Releases](https://github.com/SLINGhub/MRMhub/releases), unzip, double-click. macOS/Windows security setup: see [INTEGRATOR Manual](https://slinghub.github.io/MRMhub/integrator/).
- **QUANT (R ≥ 4.2):** quit RStudio/Positron entirely first (locked dependencies cause most failures), then in a fresh R session:

  ```r
  if (!require("pak")) install.packages("pak")
  pak::pak("SLINGhub/MRMhub")
  library(mrmhub)
  ```

  `pak` resolves locked packages and parallelises downloads; `remotes::install_github("SLINGhub/MRMhub")` is an equivalent fallback. Install failed? See [Troubleshooting](https://slinghub.github.io/MRMhub/quant/articles/manual-09-troubleshooting.html).

## Documentation

**Docs hub:** <https://slinghub.github.io/MRMhub/> — project overview + routing.
**INTEGRATOR docs:** <https://slinghub.github.io/MRMhub/integrator/> — manual, input files, msconvert.
**QUANT R package docs:** <https://slinghub.github.io/MRMhub/quant/> — manual, tutorials, function reference.
**Example workflows:** <https://slinghub.github.io/mrmhub-workflows/> — reproducible end-to-end examples.

## Why MRMhub?

- **Reproducible.** Every step is code (parameter files, R scripts), not click-through, so analyses can be re-run, audited, and shared.
- **Modular.** Each module is independent — use what you need, replace what you don't.
- **MRM-specific.** Drift/batch correction (Broadhurst 2018), ISTD/calibration quantitation, isotope-interference correction, and the QC-sample vocabulary (BQC, TQC, SBLK, CAL, RQC, ...) all built around targeted lipidomics and metabolomics conventions.

---

<small>
**Requirements:** macOS (Apple Silicon) or Windows 11, 16 GB RAM recommended; R ≥ 4.2 for QUANT and INTEGRATOR PDF plotting.&nbsp;|&nbsp;
**Contributing:** open an issue on [GitHub](https://github.com/SLINGhub/MRMhub/issues). Project follows the [Contributor Code of Conduct](https://contributor-covenant.org/version/2/0/CODE_OF_CONDUCT.html).&nbsp;|&nbsp;
**Licence:** dual-licensed — non-commercial under [GNU AGPLv3](https://www.gnu.org/licenses/agpl-3.0.en.html); for commercial use contact Jonathan Tan (jonathan_tan@nus.edu.sg).
</small>
