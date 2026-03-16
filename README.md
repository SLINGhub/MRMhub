# MRMhub <a href="https://slinghub.github.io/MRMhub/"><img src="quant/man/figures/logo.png" alt="midar website" align="right" height="139"/></a>

<!-- badges: start -->

[![Lifecycle: stable](https://img.shields.io/badge/lifecycle-stable-brightgreen.svg)](https://lifecycle.r-lib.org/articles/stages.html) [![R-CMD-check](https://github.com/SLINGhub/MRMhub/actions/workflows/R-CMD-check.yml/badge.svg)](https://github.com/SLINGhub/MRMhub/actions/workflows/R-CMD-check.yml) [![Codecov test coverage](https://codecov.io/gh/SLINGhub/MRMhub/graph/badge.svg)](https://app.codecov.io/gh/SLINGhub/MRMhub) [![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)

<!-- badges: end -->

# Overview

MRMhub is a set of tools for reproducible raw data processing, post-processing, quality control, and reporting of targeted quantitative small-molecule mass spectrometry experiments using Multiple Reaction Monitoring (MRM). The platform includes two complementary tools:

-   **INTEGRATOR**: A stand-alone application for efficient and automated raw data processing, i.e., peak detection, picking, and integration.

-   **QUANT**: R package providing a function library for data post- processing, including quantitation, data corrections, comprehensive quality control, and reporting.

The modular functionalities and defined data structures support diverse analytical designs, data formats, and processing tasks, as found in metabolomics, lipidomics and other quantitative small molecule analyses. `MRMhub` is intended for both analytical and bioinformatics scientists and facilitates collaboration between them. It enables the creation of efficient, customizable, supervisable, and documented end-to-end data processing workflows through intuitive functions and data objects.

# Documentation

See [https://slinghub.github.io/MRMhub](https://slinghub.github.io/MRMhub/) for a detailed online information on MRMhub.

# System Requirements

A standard computer running macOS (Apple Silicon only) or Windows 11 with 16 GB RAM is recommended (8 GB may be sufficient for smaller datasets with ≤1,000 samples and 500 features). The software should run on any Apple Silicon macOS system, but it has been tested only on macOS Ventura and Tahoe.

INTEGRATOR and QUANT support multithreading, so CPUs with more cores can improve computation speed.

INTEGRATOR and the corresponding Visualizer run as standalone applications. However, plotting peak integration results as PDFs requires R version 4.2 or higher ([https://cloud.r-project.org](https://cloud.r-project.org/)). The QUANT module also requires R ≥ 4.2.

# Installation and Stetup

### **INTEGRATOR** (Peak Integration Module)

1.  Download the latest version of the **INTEGRATOR** executable for your operating system from the [Releases page](#0) of this repository. This should take less than 5 minutes depending on your internet connection

2.  Move or copy the decompressed folder to a location of your choice. This folder contains:

    -   The **INTEGRATOR** executable: `MRMhub`
    -   The visualizer application: `MRMhub-viz`
    -   A demo dataset comprising `.mzML` files and INTEGRATOR input files.

::: callout-important
**Note**: Upon the first launch, you will need to adjust security settings on both macOS and Windows to allow the applications to run. Please refer to the detailed [INTEGRATOR manual](https://slinghub.github.io/MRMhub/articles/Integrator_manual.html) for instructions.
:::

> [!NOTE]
> Upon the first launch, you will need to adjust security settings on both macOS and Windows to allow the applications to run. Please refer to the detailed [INTEGRATOR manual](https://slinghub.github.io/MRMhub/articles/Integrator_manual.html) for instructions.

### **QUANT** (Postprocessing and Quality Control Module)

The **QUANT** module is implemented as an R package. It requires an installation of **R Version 4.2** or higher (available at (<https://cloud.r-project.org>). An installation of a corresponding GUI, such as [RStudio](https://posit.co/download/rstudio-desktop/) or [Positron](https://positron.posit.co), is recommended. To install the `mrmhub` package from GitHub, run the following commands in your R console:

``` r
if (!require("remotes")) install.packages("remotes")
remotes::install_github("SLINGhub/MRMhub", subdir = "quant")
```

The installation of the `mrmhub` package will automatically install other R packages required for its core functionality if they are not already present. Installation may therefore take a few minutes on a fresh R installation. Other R packages required for specific `mrmhub` functions will be installed via a user dialog when those functions are called. Load the package in your R session via:

``` r
library(mrmhub)
```

# Demo

## Peak Integration using INTEGRATOR

1.  Navigate to the downloaded INTEGRATOR folder (see Installation).
2.  Explore the INTEGRATOR input files `param.txt`, `run_order.csv`, and `sPerfect_transition_list20250528.csv` (do not change the files).
3.  Double-click on the `MRMhub` executable. The system's terminal application will appear with `mrmhub` running, asking for user input. Run Steps 1, 2, and 3 one after the other, which should take no more than 1 minute in total.
4.  You will now see the following files and folders:
    -   `quant_raw.csv`: Table in wide format with the determined peak areas for each feature and sample defined in the input files.
    -   `long.csv`: Table in long format with peak areas, retention times, and other parameters for each feature-sample pair. This file can be directly used for postprocessing using the QUANT module.
5.  Double-click on the `MRMhub-viz` executable to view and explore all transitions with peak integration results.
6.  Run Step 4 in the `mrmhub` terminal to generate PDFs of each transition with peak integration results (Note: this requires an installation of R, see System Requirements). This step typically takes less than 1 min, but may take longer depending on the system. The PDF files can then be found in the folders starting with `by_`, specifically in `by_transition`.

::: callout-important
Please refer to the Installation instructions above if double-clicking the exetubales does not have any effect or a security warning appears, .
:::

## Post Processing and QC using QUANT

1.  Navigate to the QUANT folder located inside the downloaded INTEGRATOR directory (see Installation). This folder contains a subfolder named `data` holding both data and metadata:
    -   The data corresponds to the INTEGRATOR output `long.csv` (containing peak area results).
    -   The file `metadata.xlsx` contains detailed metadata describing the analysis, which is used for post-processing.
2.  Open the Quarto notebook `quant.qmd` in an R IDE such as RStudio (see System Requirements) and run the code chunks according to the instructions.
3.  This will generate plots and processed datasets. Depending on your system, this may take a few minutes.
4.  The output files (plots and reports) of the QUANT workflow can be found in the `output` folder.

# Instructions for Use

To run the MRMhub workflow with your own data, please refer to the manual and tutorials in the [MRMhub documentation](https://slinghub.github.io/MRMhub/). Visit <https://slinghub.github.io/mrmhub-workflows/>, to view complete example workflows and corresponding outputs discussed in the manuscript.

# Contributing

We welcome contributions. For questions, bug reports, feature requests, or suggestions, please contact us directly or submit an issue through the [GitHub issues](https://github.com/SLINGhub/MRMhub/issues) page.

Please note that the MRMhub project is released with a [Contributor Code of Conduct](https://contributor-covenant.org/version/2/0/CODE_OF_CONDUCT.html). By contributing to this project, you agree to abide by its terms.

# Licence

The source code and models within this repository are dual licenced. You may choose to use it under the terms of the [GNU AGPLv3](https://www.gnu.org/licenses/agpl-3.0.en.html) for non-commercial purposes, or you can obtain a commercial license for commercial use.

For non-commercial uses and licensing of this / these code and models and its derivatives, an open-source licence is granted in accordance with the following terms and conditions - [GNU AGPLv3](https://www.gnu.org/licenses/agpl-3.0.en.html). For commercial use and licensing of this / these code and models, please contact - Jonathan Tan ( jonathan_tan\@nus.edu.sg )

Reporting unauthorized commercial use and/or further enquiries

If you become aware of any unauthorised commercial use of this source code and models or have any questions regarding licensing terms, please contact Jonathan Tan (jonathan_tan\@nus.edu.sg).