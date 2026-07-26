# MRMhub <a href="https://slinghub.github.io/MRMhub/"><img src="man/figures/logo.png" alt="MRMhub logo" align="right" height="139"/></a>

<!-- badges: start -->
[![Lifecycle: stable](https://img.shields.io/badge/lifecycle-stable-brightgreen.svg)](https://lifecycle.r-lib.org/articles/stages.html) [![R-CMD-check](https://github.com/SLINGhub/MRMhub/actions/workflows/R-CMD-check.yml/badge.svg)](https://github.com/SLINGhub/MRMhub/actions/workflows/R-CMD-check.yml) [![Codecov test coverage](https://codecov.io/gh/SLINGhub/MRMhub/graph/badge.svg)](https://app.codecov.io/gh/SLINGhub/MRMhub) [![License: AGPL v3](https://img.shields.io/badge/License-AGPLv3-blue.svg)](https://www.gnu.org/licenses/agpl-3.0)
<!-- badges: end -->

**MRMhub** is an open-source framework for reproducible, automated processing of targeted metabolomics and lipidomics data acquired by LC–MS in Multiple Reaction Monitoring (MRM) mode. It takes an experiment from raw instrument data to quality-controlled quantitative results at population scale on standard hardware, recording a full digital footprint of every step for reproducibility and traceability. Two modules work independently or together:

- **INTEGRATOR** — consensus-based peak detection, picking, and integration that determines peak boundaries consistently across an entire analysis sequence. Pre-built executable, no runtime install required.
- **QUANT** (the `mrmhub` R package) — the post-processing pipeline: ISTD normalisation, drift/batch correction, ISTD- or calibration-based quantitation, QC metrics, filtering, and reporting. Accepts integrated peaks from INTEGRATOR **and** vendor/community formats (MassHunter, Skyline, generic CSV, mzTab-M).

> **New here?** Install QUANT and run a [5-minute first analysis](https://slinghub.github.io/MRMhub/quant/articles/tutorial-00-first-analysis.html) on bundled demo data — no files of your own required.

## Choose your path

| If you have... | Use | Start here |
|---|---|---|
| Raw vendor files (`.raw`, `.d`, `.wiff`) | INTEGRATOR + QUANT | [Releases](https://github.com/SLINGhub/MRMhub/releases) → [Docs hub](https://slinghub.github.io/MRMhub/) |
| Integrated peaks (MassHunter, Skyline, mzTab-M) | QUANT only | [QUANT install](https://slinghub.github.io/MRMhub/quant/articles/manual-00-installation.html) |
| Only peak picking | INTEGRATOR only | [Releases](https://github.com/SLINGhub/MRMhub/releases) |

## Install

- **INTEGRATOR:** download from [Releases](https://github.com/SLINGhub/MRMhub/releases), unzip, double-click. Full download, first-launch security, and per-project setup: [INTEGRATOR installation guide](https://slinghub.github.io/MRMhub/integrator/setup.html).
- **QUANT (R ≥ 4.1):** quit RStudio/Positron entirely first (locked dependencies cause most failures), then in a fresh R session:

  ```r
  if (!require("pak")) install.packages("pak")
  pak::pak("SLINGhub/MRMhub")
  library(mrmhub)
  ```

  `pak` resolves locked packages and parallelises downloads; `remotes::install_github("SLINGhub/MRMhub")` is an equivalent fallback. Full instructions: [QUANT installation guide](https://slinghub.github.io/MRMhub/quant/articles/manual-00-installation.html). Install failed? See [Troubleshooting](https://slinghub.github.io/MRMhub/quant/articles/manual-09-troubleshooting.html).

## Documentation

**Docs hub:** <https://slinghub.github.io/MRMhub/> — project overview + routing.
**INTEGRATOR docs:** <https://slinghub.github.io/MRMhub/integrator/> — manual, input files, msconvert.
**QUANT R package docs:** <https://slinghub.github.io/MRMhub/quant/> — manual, tutorials, function reference.

**Get started fast:**

- **Demo — QUANT first analysis:** [5-minute walkthrough](https://slinghub.github.io/MRMhub/quant/articles/tutorial-00-first-analysis.html) on bundled demo data — no files of your own required.
- **INTEGRATOR Quick Start:** [set up a new peak-integration project](https://slinghub.github.io/MRMhub/integrator/quickstart.html).
- **Example workflows:** [MRMhub-workflows](https://slinghub.github.io/MRMhub-workflows/) — reproducible end-to-end analyses from large-scale lipidomics studies.

## Why MRMhub?

- **Reproducible.** Every step is code (parameter files, R scripts), not click-through, so analyses can be re-run, audited, and shared.
- **Modular.** Each module is independent — use what you need, replace what you don't.
- **MRM-specific.** Drift/batch correction (Broadhurst 2018), ISTD/calibration quantitation, isotope-interference correction, and the QC-sample vocabulary (BQC, TQC, SBLK, CAL, RQC, ...) all built around targeted lipidomics and metabolomics conventions.

## Citation

Burla B. *et al.* (2025). *MRMhub: one-stop solution for automated processing of large-scale targeted metabolomics data.* bioRxiv. [doi:10.64898/2025.12.20.695370](https://doi.org/10.64898/2025.12.20.695370)

---

<small>
**Requirements:** macOS (Apple Silicon) or Windows 11, 16 GB RAM recommended; R ≥ 4.1 for QUANT and INTEGRATOR PDF plotting.&nbsp;|&nbsp;
**Contributing:** open an issue on [GitHub](https://github.com/SLINGhub/MRMhub/issues). Project follows the [Contributor Code of Conduct](https://contributor-covenant.org/version/2/0/CODE_OF_CONDUCT.html).&nbsp;|&nbsp;
**Licence:** dual-licensed — non-commercial under [GNU AGPLv3](https://www.gnu.org/licenses/agpl-3.0.en.html); for commercial use contact Jonathan Tan (jonathan_tan@nus.edu.sg).
</small>
