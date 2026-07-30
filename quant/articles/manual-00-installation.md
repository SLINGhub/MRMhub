# Installation

Manual

## Requirements

- **Operating system:** Windows, macOS, or Linux.
- **R:** version 4.1 or newer, from [CRAN](https://cran.r-project.org).
- **R Editor (recommended):**
  [RStudio](https://posit.co/download/rstudio-desktop/) or
  [Positron](https://positron.posit.co).
- **Quarto:** bundled with recent RStudio and Positron releases;
  otherwise install it from
  [quarto.org](https://quarto.org/docs/get-started/). Required only for
  rendering notebooks.

## Installing and updating MRMhub

**Important.** Quit and reopen all RStudio/Positron sessions first. Many
installation issues are caused by R packages that are loaded in another
session while the installer tries to update them.

In a **fresh R session**, we recommend installing with `pak`:

``` r

if (!require("pak")) install.packages("pak")
pak::pak("SLINGhub/MRMhub")
```

To update MRMhub later, re-run the same command in a fresh session.

If `pak` fails, e.g. due to institutional network firewall or proxy
settings, try `remotes` instead:

``` r

if (!require("remotes")) install.packages("remotes")
remotes::install_github("SLINGhub/MRMhub")
```

If installation fails, see the ZIP-file method below or
[Troubleshooting](#troubleshooting).

## Installing from a downloaded repository ZIP file

If the methods above fail or R cannot reach GitHub, download a copy of
the repository and install MRMhub from it:

1.  Open <https://github.com/SLINGhub/MRMhub> in a browser.
2.  Click the green **Code** button and choose **Download ZIP** (or
    download
    <https://github.com/SLINGhub/MRMhub/archive/refs/heads/main.zip>
    directly).
3.  Unzip the file. It expands to a folder named `MRMhub-main`.
4.  In a **fresh R session**, install from that folder with `pak`:

``` r

pak::local_install("path/to/MRMhub-main")
```

Replace `path/to/MRMhub-main` with the actual location of the unzipped
folder, e.g. `"~/Downloads/MRMhub-main"`.

## Confirm `mrmhub` is successfully installed

``` r

library(mrmhub)
```

If this loads without error, you are ready to go. If you plan to use any
of the functions listed under [Optional packages](#optional-packages)
below, install those too. If it loads with errors, see
[Troubleshooting](#troubleshooting) below.

## Optional packages

To keep the base installation light, a number of specialised functions
in `mrmhub` rely on additional packages that are not installed upfront.
When such a function is called and its package is not yet installed,
`mrmhub` offers to install it.

| Function | Optional package | Enables |
|----|----|----|
| [`plot_runscatter()`](https://slinghub.github.io/MRMhub/quant/reference/plot_runscatter.md) | qpdf; mirai, carrier | only for multi-threaded PDF output |
| `plot_qc_summary_overall(with_venn = TRUE)` | ggvenn, patchwork | Venn diagram of features excluded by QC criteria |
| [`plot_matrixeffects()`](https://slinghub.github.io/MRMhub/quant/reference/plot_matrixeffects.md), [`plot_interference_correction()`](https://slinghub.github.io/MRMhub/quant/reference/plot_interference_correction.md) | ggbeeswarm | beeswarm/quasirandom point layers |
| [`correct_isotopic_interferences()`](https://slinghub.github.io/MRMhub/quant/reference/correct_isotopic_interferences.md), [`calc_average_molweight()`](https://slinghub.github.io/MRMhub/quant/reference/calc_average_molweight.md) | enviPat | isotope-pattern and molecular-weight calculation |
| [`correct_batch_combat()`](https://slinghub.github.io/MRMhub/quant/reference/correct_batch_combat.md) | sva | ComBat batch correction |
| [`correct_batch_serrf()`](https://slinghub.github.io/MRMhub/quant/reference/correct_batch_serrf.md) | ranger | SERRF batch correction |
| [`correct_drift_gam()`](https://slinghub.github.io/MRMhub/quant/reference/correct_drift_gam.md) | mgcv | GAM-based drift correction |
| [`build_workflow()`](https://slinghub.github.io/MRMhub/quant/reference/build_workflow.md) | shiny, bslib | interactive workflow-builder app |
| [`save_dataset_summarizedexperiment()`](https://slinghub.github.io/MRMhub/quant/reference/save_dataset_summarizedexperiment.md) | SummarizedExperiment, S4Vectors, lipidr *(Bioconductor)* | export to a `SummarizedExperiment` |
| Lipid-name parsing (isotope correction, lipid plots) | rgoslin *(Bioconductor)* | parse and normalise lipid shorthand |
| [`get_response_curve_stats()`](https://slinghub.github.io/MRMhub/quant/reference/get_response_curve_stats.md) | lancer *(GitHub)* | only for specific response-curve metrics |

To install all of them upfront, run the following in a fresh R session
(again, with all other RStudio/Positron sessions closed):

``` r

pak::pak(c(
  "sva", "ranger", "mgcv", "enviPat",
  "qpdf", "mirai", "carrier", "shiny", "bslib",
  "ggvenn", "patchwork", "ggbeeswarm",
  "rgoslin", "lipidr", "SummarizedExperiment", "S4Vectors",
  "SLINGhub/lancer"
))
```

Alternatively, install the CRAN packages with
[`install.packages()`](https://rdrr.io/r/utils/install.packages.html)
and the Bioconductor ones (`rgoslin`, `lipidr`, `SummarizedExperiment`,
`S4Vectors`) with `BiocManager::install()`.

## Troubleshooting

If the installation seemed successful but the package does not load, or
loads with errors, run
[`check_setup()`](https://slinghub.github.io/MRMhub/quant/reference/check_setup.md)
to report the R version and flag any missing dependencies:

``` r

mrmhub::check_setup()
```

**Frequent installation errors**

See [Troubleshooting &
FAQ](https://slinghub.github.io/MRMhub/quant/articles/manual-10-troubleshooting.md)
for a detailed list of errors and resolutions.

| Error | Cause | Fix |
|----|----|----|
| `namespace 'rlang' is already loaded` | An old dependency is still loaded in the session | Restart R (`Ctrl+Shift+F10`) and retry the install |
| `pak` unavailable or failing | `pak` not installed, or its cache is stale | Install with `remotes::install_github("SLINGhub/MRMhub")` |
| `cannot open URL` | Firewall or proxy blocking GitHub | `options(download.file.method = "libcurl")`, or [install from a downloaded repository ZIP file](#installing-from-a-downloaded-repository-zip-file) |
| `Could not resolve host: api.github.com` | Firewall or proxy blocking the GitHub API | Set `http_proxy`/`https_proxy`, or [install from a downloaded repository ZIP file](#installing-from-a-downloaded-repository-zip-file) |
| `SSL certificate problem: self signed certificate in certificate chain` | Corporate proxy inspecting TLS traffic | Use `remotes` (it uses the system certificate store), or install your organisation’s root certificate |
| `package 'X' was installed under R version …` | Package built for a different R | `install.packages("X")` to rebuild it for your R |
| `there is no package called 'mrmhub'` | Install did not finish | Scroll up for the real error, then retry the install |
| `ERROR: Rtools is required` (Windows) | A source-only dependency needs compilation | Install [Rtools](https://cran.r-project.org/bin/windows/Rtools/) matching your R version, restart R, retry |
| `clang: error: ...` (macOS) | Compiler tools missing | Run `xcode-select --install` in Terminal, retry |
| `cannot find -lcurl` (Linux) | System libraries missing | `sudo apt install libcurl4-openssl-dev libxml2-dev libssl-dev libfontconfig1-dev` |

## Next steps

- [MRMhub
  overview](https://slinghub.github.io/MRMhub/quant/articles/manual-01-key-concepts.md):
  core vocabulary and the MRMhubExperiment object
- [Getting started with
  MRMhub](https://slinghub.github.io/MRMhub/quant/articles/tutorial-02-getting-started-mrmhub.md):
  a short end-to-end walkthrough
- Questions or bug reports? File an issue on
  [GitHub](https://github.com/SLINGhub/MRMhub/issues), or contact the
  authors directly.
