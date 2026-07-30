# MRMhub-QUANT <a href="https://slinghub.github.io/MRMhub/quant/"><img src="man/figures/logo.svg" align="right" height="139" alt="MRMhub-QUANT website" /></a>

<!-- badges: start -->
[![Version](https://img.shields.io/badge/version-0.9.9-blue.svg)](https://github.com/SLINGhub/MRMhub/releases) [![License: AGPL v3](https://img.shields.io/badge/License-AGPLv3-blue.svg)](https://www.gnu.org/licenses/agpl-3.0) [![bioRxiv](https://img.shields.io/badge/bioRxiv-preprint-b31b1b.svg)](https://doi.org/10.64898/2025.12.20.695370) [![R-CMD-check](https://github.com/SLINGhub/MRMhub/actions/workflows/R-CMD-check.yml/badge.svg)](https://github.com/SLINGhub/MRMhub/actions/workflows/R-CMD-check.yml) [![Codecov test coverage](https://codecov.io/gh/SLINGhub/MRMhub/graph/badge.svg)](https://app.codecov.io/gh/SLINGhub/MRMhub)
<!-- badges: end -->

**MRMhub-QUANT** turns targeted MRM feature intensities into curated, QC-filtered, quantified results. It is the post-processing module of [MRMhub](https://slinghub.github.io/MRMhub/), distributed as the R package `mrmhub` (`library(mrmhub)`), and works with any intensity data from [MRMhub-INTEGRATOR](https://slinghub.github.io/MRMhub/integrator/), Skyline, or generic CSV files. MRMhub-QUANT features:

- **Reproducible pipelines.** Script, explore and document, with QC visualisations at every step.
- **Flexible workflows.** Customisable functions for metabolomics and lipidomics post-processing.
- **A single data object.** Data, metadata, and processing results live in one shareable object.

<div style="margin: 1.5em 0 0.5em;">
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 960 182" role="img" aria-label="MRMhub-QUANT workflow in five stages, each with its key actions. Import and Validate: import data, add metadata, validate IDs, set run order. Quantify: ISTD normalisation, quantify by ISTD, calibration curves, reference calibration. Correct: drift correction, batch effects, interferences. QC and Filter: QC metrics, PCA and run-scatter, outlier detection, feature filtering. Report: Excel and CSV, mzTab-M, QC reports, shareable object." style="width: 100%; height: auto; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;">
  <style>
    .q-arrow { cursor: pointer; transition: opacity 0.2s; fill: #ffffff; stroke: #dee2e6; stroke-width: 1; }
    .q-link:hover .q-arrow { opacity: 0.82; }
    .q-link:hover .q-name { text-decoration: underline; text-underline-offset: 2px; }
    .q-name { font-size: 20px; font-weight: 700; fill: #2C3E50; pointer-events: none; }
    .q-item { font-size: 16px; fill: #46535f; pointer-events: none; }
    .q-div { stroke: #dfe4e8; stroke-width: 1; }
  </style>
  <rect x="0" y="0" width="960" height="182" rx="6" fill="#f4f6f8"/>
  <line class="q-div" x1="234" y1="70" x2="234" y2="176"/>
  <line class="q-div" x1="433" y1="70" x2="433" y2="176"/>
  <line class="q-div" x1="596" y1="70" x2="596" y2="176"/>
  <line class="q-div" x1="766" y1="70" x2="766" y2="176"/>
  <a class="q-link" href="articles/manual-04-data-import.html"><polygon class="q-arrow" points="4,4 231,4 255,30 231,56 4,56"/><text class="q-name" x="118" y="37" text-anchor="middle">Import &amp; Validate</text></a>
  <text class="q-item" x="20" y="88">Import data</text>
  <text class="q-item" x="20" y="112">Add metadata</text>
  <text class="q-item" x="20" y="136">Validate IDs</text>
  <text class="q-item" x="20" y="160">Set run order</text>
  <a class="q-link" href="articles/tutorial-03-lipidomics-workflow.html"><polygon class="q-arrow" points="237,4 430,4 454,30 430,56 237,56 261,30"/><text class="q-name" x="334" y="37" text-anchor="middle">Quantify</text></a>
  <text class="q-item" x="253" y="88">ISTD normalisation</text>
  <text class="q-item" x="253" y="112">Quantify by ISTD</text>
  <text class="q-item" x="253" y="136">Calibration curves</text>
  <text class="q-item" x="253" y="160">Reference calibration</text>
  <a class="q-link" href="articles/manual-07-corrections.html"><polygon class="q-arrow" points="436,4 593,4 617,30 593,56 436,56 460,30"/><text class="q-name" x="515" y="37" text-anchor="middle">Correct</text></a>
  <text class="q-item" x="452" y="88">Drift correction</text>
  <text class="q-item" x="452" y="112">Batch effects</text>
  <text class="q-item" x="452" y="136">Interferences</text>
  <a class="q-link" href="articles/tutorial-05-run-scatter.html"><polygon class="q-arrow" points="599,4 763,4 787,30 763,56 599,56 623,30"/><text class="q-name" x="681" y="37" text-anchor="middle">QC &amp; Filter</text></a>
  <text class="q-item" x="615" y="88">QC metrics</text>
  <text class="q-item" x="615" y="112">PCA &amp; run-scatter</text>
  <text class="q-item" x="615" y="136">Outlier detection</text>
  <text class="q-item" x="615" y="160">Feature filtering</text>
  <a class="q-link" href="articles/tutorial-08-export-formats.html"><polygon class="q-arrow" points="769,4 926,4 950,30 926,56 769,56 793,30"/><text class="q-name" x="848" y="37" text-anchor="middle">Report</text></a>
  <text class="q-item" x="785" y="88">Excel &amp; CSV</text>
  <text class="q-item" x="785" y="112">mzTab-M</text>
  <text class="q-item" x="785" y="136">QC reports</text>
  <text class="q-item" x="785" y="160">Shareable object</text>
</svg>
</div>


## Quick Start

- **[Installation](articles/manual-00-installation.html)** - install and verify your setup
- **[Getting started with R and Quarto](articles/tutorial-13-getting-started-r-quarto.html)** - *new to R?* set up R, an IDE, and a Quarto project
- **[Getting started with MRMhub](articles/tutorial-02-getting-started-mrmhub.html)** - a first end-to-end analysis on the bundled data
- **[Try the interactive workflow builder](articles/tutorial-12-workflow-builder.html)** - generate a runnable Quarto notebook
- **[Run the demo ↗](https://slinghub.github.io/MRMhub/get-started.html)** - a bundled, runnable demo project with data

## Example Workflows

- **[Example: targeted lipidomics](articles/tutorial-03-lipidomics-workflow.html)** - a full lipidomics workflow
- **[Example: external calibration](articles/tutorial-06-external-calibration.html)** - a quantitative assay with calibration curves
- **[Browse real analyses ↗](https://slinghub.github.io/MRMhub-workflows/)** - annotated, end-to-end reports from large-scale studies


## Installation and Updating

Make sure to use a fresh R session without loaded packages (restart RStudio/Positron first). Please read [the Installation guide](articles/manual-00-installation.html) first for full instructions and troubleshooting.

```r
if (!require("pak")) install.packages("pak")
pak::pak("SLINGhub/MRMhub")
library(mrmhub)
```

## Citation

If you use MRMhub in your research, please cite the accompanying preprint (bioRxiv, <https://doi.org/10.64898/2025.12.20.695370>). From within R, `citation("mrmhub")` prints the current citation.

## Contributing

Bug reports and feature requests are welcome via [GitHub issues](https://github.com/SLINGhub/MRMhub/issues). The project follows the [Contributor Code of Conduct](https://contributor-covenant.org/version/2/0/CODE_OF_CONDUCT.html).

## License

Dual-licensed - non-commercial under [GNU AGPLv3](https://www.gnu.org/licenses/agpl-3.0.en.html). For commercial use contact Jonathan Tan (jonathan_tan@nus.edu.sg).
