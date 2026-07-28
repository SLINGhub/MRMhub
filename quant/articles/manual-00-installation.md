# Installation

Manual

## Requirements

The `mrmhub` R package requires:

- **Operating system:** Windows, macOS, or Linux.
- **R:** version 4.1 or newer, from [CRAN](https://cran.r-project.org).
- **IDE (recommended):**
  [RStudio](https://posit.co/download/rstudio-desktop/) or
  [Positron](https://positron.posit.co), which combine a code editor,
  console, and package management in a single window.
- **Quarto:** bundled with recent RStudio and Positron releases;
  otherwise install it from
  [quarto.org](https://quarto.org/docs/get-started/). Required only for
  rendering reports and workflow documents.

All package dependencies are resolved and installed automatically, so no
further configuration is needed beyond a working R installation.

## Installing MRMhub

**Important.** Quit and reopen all RStudio/Positron sessions first; many
install failures come from R packages already loaded in another session

In a fresh R session:

``` r

if (!require("pak")) install.packages("pak")
pak::pak("SLINGhub/MRMhub")
```

We recommend `pak`, but if it fails behind a proxy or on an unusual
platform, `remotes` works as well:

``` r

if (!require("remotes")) install.packages("remotes")
remotes::install_github("SLINGhub/MRMhub")
```

## Confirm `mrmhub` is sucessfully installed

``` r

library(mrmhub)
```

If this loads without error, you are ready to go. Head to [Your first
analysis](https://slinghub.github.io/MRMhub/quant/articles/tutorial-00-first-analysis.md).

## Optional packages

To keep the base installation light, `mrmhub` installs only the packages
needed for the common workflow. A number of specialised functions rely
on additional packages that are not pulled in upfront. When such a
function is called and its package is missing, `mrmhub` reports what is
needed and, in an interactive session, offers to install it on the spot
— so most users never install these manually.

Ordered from the most commonly used functions to the more specialised
ones:

| Function | Optional package | Enables |
|----|----|----|
| QC and EDA plots | ggvenn, patchwork, ggforce, ggbeeswarm, ggsignif | QC-summary and exploratory plots |
| [`plot_pca()`](https://slinghub.github.io/MRMhub/quant/reference/plot_pca.md) | ggnewscale | PCA score plots |
| [`plot_runscatter()`](https://slinghub.github.io/MRMhub/quant/reference/plot_runscatter.md) | qpdf; mirai, carrier | multi-page PDF output; parallel rendering |
| [`correct_batch_combat()`](https://slinghub.github.io/MRMhub/quant/reference/correct_batch_combat.md) | sva | ComBat batch correction |
| [`correct_batch_serrf()`](https://slinghub.github.io/MRMhub/quant/reference/correct_batch_serrf.md) | ranger | SERRF batch correction |
| [`correct_drift_gam()`](https://slinghub.github.io/MRMhub/quant/reference/correct_drift_gam.md) | mgcv | GAM-based drift correction |
| [`plot_responsecurves()`](https://slinghub.github.io/MRMhub/quant/reference/plot_responsecurves.md) | ggpmisc | response-curve plots with fit annotations |
| [`build_workflow()`](https://slinghub.github.io/MRMhub/quant/reference/build_workflow.md) | shiny, bslib | interactive workflow-builder app |
| [`save_dataset_summarizedexperiment()`](https://slinghub.github.io/MRMhub/quant/reference/save_dataset_summarizedexperiment.md) | SummarizedExperiment, S4Vectors, lipidr *(Bioconductor)* | export to a `SummarizedExperiment` |
| Lipid-name parsing (isotope correction, lipid plots) | rgoslin *(Bioconductor)* | parse and normalise lipid shorthand |
| [`correct_isotopic_interferences()`](https://slinghub.github.io/MRMhub/quant/reference/correct_isotopic_interferences.md), [`calc_average_molweight()`](https://slinghub.github.io/MRMhub/quant/reference/calc_average_molweight.md) | enviPat | isotope-pattern and molecular-weight calculation |
| [`get_response_curve_stats()`](https://slinghub.github.io/MRMhub/quant/reference/get_response_curve_stats.md) | lancer *(GitHub)* | response-curve quality metrics |

To install all of them upfront, run the following in a fresh R session
(again, with all other RStudio/Positron sessions closed):

``` r

pak::pak(c(
  "sva", "ranger", "mgcv", "enviPat",
  "ggnewscale", "ggpmisc", "ggvenn", "patchwork",
  "ggforce", "ggbeeswarm", "ggsignif",
  "qpdf", "mirai", "carrier", "shiny", "bslib",
  "rgoslin", "lipidr", "SummarizedExperiment", "S4Vectors",
  "SLINGhub/lancer"
))
```

`pak` resolves CRAN, Bioconductor, and GitHub sources in one call. If it
fails behind a proxy or on an unusual platform, install the CRAN
packages with
[`install.packages()`](https://rdrr.io/r/utils/install.packages.html)
and the Bioconductor ones (`rgoslin`, `lipidr`, `SummarizedExperiment`,
`S4Vectors`) with `BiocManager::install()`.

## Troubleshooting

If the installation seemed succesfull but but the package doesnt load or
with errors, run
[`check_setup()`](https://slinghub.github.io/MRMhub/quant/reference/check_setup.md)
to report the R version and flag any missing dependencies:

``` r

check_setup()
```

**Most frequent installation errors**

See [Troubleshooting &
FAQ](https://slinghub.github.io/MRMhub/quant/articles/manual-10-troubleshooting.md)
for detailed error and resolution list.

| Error | Cause | Fix |
|----|----|----|
| `namespace 'rlang' is already loaded` | An old dependency is still loaded in the session | Restart R (`Ctrl+Shift+F10`) and retry the install |
| `pak` unavailable or failing | `pak` not installed, or its cache is stale | Install with `remotes::install_github("SLINGhub/MRMhub")` |
| `cannot open URL` | Firewall or proxy blocking GitHub | `options(download.file.method = "libcurl")`, or clone the repo and use `remotes::install_local("path/to/MRMhub")` |
| `package 'X' was installed under R version …` | Package built for a different R | `install.packages("X")` to rebuild it for your R |
| `there is no package called 'mrmhub'` | Install did not finish | Scroll up for the real error, then retry the install |
| `ERROR: Rtools is required` (Windows) | A source-only dependency needs compilation | Install [Rtools](https://cran.r-project.org/bin/windows/Rtools/) matching your R version, restart R, retry |
| `clang: error: ...` (macOS) | Compiler tools missing | Run `xcode-select --install` in Terminal, retry |
| `cannot find -lcurl` (Linux) | System libraries missing | `sudo apt install libcurl4-openssl-dev libxml2-dev libssl-dev libfontconfig1-dev` |

## Next steps

- [Key concepts &
  glossary](https://slinghub.github.io/MRMhub/quant/articles/manual-01-key-concepts.md):
  core vocabulary and the MRMhubExperiment object
- [Your first
  analysis](https://slinghub.github.io/MRMhub/quant/articles/tutorial-00-first-analysis.md):
  a short end-to-end walkthrough
- Questions or bug reports? File an issue on
  [GitHub](https://github.com/SLINGhub/MRMhub/issues), or contact the
  authors directly.
