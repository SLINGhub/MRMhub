# MRMhub <a href="https://slinghub.github.io/mrmhub/"><img src="/quant/man/figures/logo.svg" alt="mrmhub website" align="right" height="139"/></a>

<!-- badges: start -->

[![Lifecycle: stable](https://img.shields.io/badge/lifecycle-stable-brightgreen.svg)](https://lifecycle.r-lib.org/articles/stages.html) [![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0) [![GitHub stars](https://img.shields.io/github/stars/SLINGhub/MRMhub)](https://github.com/SLINGhub/MRMhub/stargazers) <!--
[![Build Executables](https://github.com/SLINGhub/MRMhub/actions/workflows/build-executables.yml/badge.svg)](https://github.com/SLINGhub/MRMhub/actions/workflows/build-executables.yml)
[![R-CMD-check](https://github.com/SLINGhub/mrmhub/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/SLINGhub/mrmhub/actions/workflows/R-CMD-check.yaml)
--> [![Codecov test coverage](https://codecov.io/gh/slinghub/mrmhub/branch/main/graph/badge.svg?flag=quant)](https://app.codecov.io/gh/slinghub/mrmhub?branch=main) [![Platform](https://img.shields.io/badge/platform-linux%20%7C%20osx%20%7C%20win-lightgrey)](https://github.com/SLINGhub/MRMhub)

<!-- badges: end -->

## Overview

MRMhub is a set of tools for reproducible raw data processing, post-processing, quality control, and reporting of targeted quantitative small-molecule mass spectrometry experiments using Multiple Reaction Monitoring (MRM). The platform includes two complementary tools:

-   **INTEGRATOR**: Python application for efficient and automated raw data processing, i.e., peak detection, picking, and integration.

-   **QUANT**: R package providing a function library for data post- processing, including quantitation, data corrections, comprehensive quality control, and reporting.

The modular functionalities and defined data structures support diverse analytical designs, data formats, and processing tasks, as found in metabolomics, lipidomics and other quantitative small molecule analyses. `MRMhub` is intended for both analytical and bioinformatics scientists and facilitates collaboration between them. It enables the creation of efficient, customizable, supervisable, and documented end-to-end data processing workflows through intuitive functions and data objects.

## Usage

##### INTEGRATOR (Peak Integration)

To download the latest release of INTEGRATOR, visit the [Releases page](https://github.com/SLINGhub/MRMhub/releases). Choose the appropriate version for your operating system (Windows, macOS, or Linux) and download the corresponding executable file. Unzip the downloaded file and double-click the executable to launch the application. Refer to the [Documentation](https://slinghub.github.io/mrmhub/) for detailed instructions on how to use INTEGRATOR.

##### QUANT (Postprocessing and Quality Control)

Install the `mrmhub` package from Github using the following command:

``` r
if (!require("remotes")) install.packages("remotes")
remotes::install_github("SLINGhub/MRMhub", subdir = "quant")
```

Load the package in your R session via `library(mrmhub)`. For detailed usage instructions and examples, refer to the [Documentation](https://slinghub.github.io/mrmhub/).

## Documentation

See the online Documentation on [https://slinghub.github.io/mrmhub](https://slinghub.github.io/mrmhub/) for detailed information on installation, usage, and examples of MRMhub.

## Contributing

We welcome contributions. For questions, bug reports, feature requests, or suggestions, please contact us directly or submit an issue through the [GitHub issues](https://github.com/SLINGhub/MRMhub/issues) page.

## Contributor Code of Conduct

Please note that the MRMhub project is released with a [Contributor Code of Conduct](https://contributor-covenant.org/version/2/0/CODE_OF_CONDUCT.html). By contributing to this project, you agree to abide by its terms.

## License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE](LICENSE.md) file for details.