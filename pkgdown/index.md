# MRMhub-QUANT <a href="https://slinghub.github.io/MRMhub/quant/"><img src="man/figures/logo.svg" align="right" height="139" alt="MRMhub-QUANT website" /></a>

<!-- badges: start -->
[![Lifecycle: stable](https://img.shields.io/badge/lifecycle-stable-brightgreen.svg)](https://lifecycle.r-lib.org/articles/stages.html)
[![R-CMD-check](https://github.com/SLINGhub/MRMhub/actions/workflows/R-CMD-check.yml/badge.svg)](https://github.com/SLINGhub/MRMhub/actions/workflows/R-CMD-check.yml)
[![Codecov test coverage](https://codecov.io/gh/SLINGhub/MRMhub/graph/badge.svg)](https://app.codecov.io/gh/SLINGhub/MRMhub)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
<!-- badges: end -->

**MRMhub-QUANT** is the post-processing module of [MRMhub](https://slinghub.github.io/MRMhub/), distributed as the R package `mrmhub` (`library(mrmhub)`). It covers the full workflow from feature intensities to curated, QC-filtered concentrations, and works with any intensity data — such as from [MRMhub](https://slinghub.github.io/MRMhub/), Skyline, Agilent MassHunter, and generic CSV files. MRMhub-QUANT features:

- **Reproducible pipelines.** Create reproducible computational pipelines with QC vizualizations. Script, re-run, and share it.
- **Flexible workflows.** Metabolomics and lipidomics data post-processing using dedicated customizable functions. 
- **A single data object.** Data, metadata, and processing details are stored in single sharable data object (`MRMhubExperiment`).

<div style="text-align: center; margin: 1.5em 0 0.5em;">
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 840 130" style="max-width: 840px; width: 100%; height: auto; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;">
  <style>
    .wf-box { rx: 8; ry: 8; stroke-width: 1.5; cursor: pointer; transition: opacity 0.2s; }
    .wf-box:hover { opacity: 0.85; }
    .wf-label { font-size: 12px; font-weight: 600; fill: #1a1a1a; pointer-events: none; text-decoration: underline; text-underline-offset: 2px; }
    .wf-arrow { fill: #2C3E50; }
    .wf-box-dashed { fill: transparent; stroke-dasharray: 4,3; }
    .wf-box-dashed:hover { fill: rgba(91,143,168,0.08); }
    .wf-detail { font-size: 9.5px; fill: #555; pointer-events: none; }
  </style>
  <a href="articles/manual-05a-which-importer.html"><rect class="wf-box wf-box-dashed" x="35" y="10" width="110" height="70" stroke="#5B8FA8"/><text class="wf-label" x="90" y="50" text-anchor="middle">Data Import</text></a>
  <text class="wf-detail" x="90" y="98" text-anchor="middle">MRMhub-INTEGRATOR</text>
  <text class="wf-detail" x="90" y="112" text-anchor="middle">Other formats</text>
  <polygon class="wf-arrow" points="148,38 148,52 164,45"/>
  <a href="articles/manual-06-metadata-import.html"><rect class="wf-box" x="167" y="10" width="110" height="70" fill="#f5e0c8" stroke="#D4914E"/><text class="wf-label" x="222" y="50" text-anchor="middle">Metadata</text></a>
  <text class="wf-detail" x="222" y="98" text-anchor="middle">import CSV/XLS</text>
  <text class="wf-detail" x="222" y="112" text-anchor="middle">Integrity validation</text>
  <polygon class="wf-arrow" points="280,38 280,52 296,45"/>
  <a href="articles/recipe-01-ext-calibration-qc.html"><rect class="wf-box" x="299" y="10" width="110" height="70" fill="#d8e6d4" stroke="#6B9E5E"/><text class="wf-label" x="354" y="42" text-anchor="middle"><tspan x="354" dy="0">Normalize /</tspan><tspan x="354" dy="16">Quantify</tspan></text></a>
  <text class="wf-detail" x="354" y="98" text-anchor="middle">ISTD</text>
  <text class="wf-detail" x="354" y="112" text-anchor="middle">Calibration curve</text>
  <polygon class="wf-arrow" points="412,38 412,52 428,45"/>
  <a href="articles/manual-07-drift-batch-correction.html"><rect class="wf-box" x="431" y="10" width="110" height="70" fill="#ecd2d2" stroke="#C27171"/><text class="wf-label" x="486" y="50" text-anchor="middle">Corrections</text></a>
  <text class="wf-detail" x="486" y="98" text-anchor="middle">Drift</text>
  <text class="wf-detail" x="486" y="112" text-anchor="middle">Batch</text>
  <polygon class="wf-arrow" points="544,38 544,52 560,45"/>
  <a href="articles/tutorial-09-pca-exploration.html"><rect class="wf-box" x="563" y="10" width="110" height="70" fill="#d6e4eb" stroke="#5B8FA8"/><text class="wf-label" x="618" y="50" text-anchor="middle">QC</text></a>
  <text class="wf-detail" x="618" y="98" text-anchor="middle">Metrics</text>
  <text class="wf-detail" x="618" y="112" text-anchor="middle">Plots</text>
  <polygon class="wf-arrow" points="676,38 676,52 692,45"/>
  <a href="articles/recipe-02-custom-qc-report.html"><rect class="wf-box" x="695" y="10" width="110" height="70" fill="#c8cfd6" stroke="#2C3E50"/><text class="wf-label" x="750" y="50" text-anchor="middle">Reporting</text></a>
  <text class="wf-detail" x="750" y="98" text-anchor="middle">Plain tables</text>
  <text class="wf-detail" x="750" y="112" text-anchor="middle">QC reports</text>
</svg>
</div>

## Quick Start and Demos
 
- **[Installation](articles/manual-00-get-started.html)** — install and verify your setup
- **[Example](articles/tutorial-03-lipidomics-workflow.html)** - Targeted Lipidomics Data Processing
- **[Example](articles/recipe-01-ext-calibration-qc.html)** - Quantitative Assay with Ext. Calibration
- **[Quick Start](articles/tutorial-00-first-analysis.html)** - 5 minute run on bundled data
- **[Prepare your data](articles/manual-05a-which-importer.html)** - file formats and importers


## Installation and Updating

Make sure to use a fresh R session without loaded packages (quit RStudio/Positron first to avoid locked packages):

```r
if (!require("pak")) install.packages("pak")
pak::pak("SLINGhub/MRMhub")
```

For more details and troubleshooting see [Installation](articles/manual-00-get-started.html) and [Installation Troubleshooting & FAQ](articles/manual-09-troubleshooting.html).



## Contributing

Questions, bug reports, feature requests, and suggestions are welcome via [GitHub issues](https://github.com/SLINGhub/MRMhub/issues). The project is released with a [Contributor Code of Conduct](https://contributor-covenant.org/version/2/0/CODE_OF_CONDUCT.html).

## Dual licensing

The source code is dual-licensed: [GNU AGPLv3](https://www.gnu.org/licenses/agpl-3.0.en.html) for non-commercial use, or commercial licensing — contact Jonathan Tan (<jonathan_tan@nus.edu.sg>).
