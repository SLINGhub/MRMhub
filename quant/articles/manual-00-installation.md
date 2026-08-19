# Installation

Manual

## Requirements

- **Operating system:** Windows, macOS, or Linux.
- **R:** the current release, from [CRAN](https://cran.r-project.org).
  Minimum is 4.1; on older releases some packages must be built from
  source, which is slower and requires additional tools.
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

In a **fresh R session**:

``` r

# mrmhub from the MRMhub R-universe repository, dependencies from CRAN
install.packages("mrmhub",
                 repos = c("https://slinghub.r-universe.dev",
                           "https://cloud.r-project.org"))
```

The same command installs later updates.

Confirm the installation:

``` r

library(mrmhub)
```

If R is older than the version the package was built with, the warning
`package 'mrmhub' was built under R version ...` appears. It can be
ignored: `mrmhub` contains no compiled code, so the version difference
has no effect. If the package does not load, see
[Troubleshooting](#troubleshooting) or the ZIP-file method below. For
optional features, see [Optional packages](#optional-packages).

### Alternative installation methods

If R-universe is unreachable, MRMhub can be installed from GitHub. Both
routes build the package locally.

``` r

if (!requireNamespace("pak", quietly = TRUE)) install.packages("pak")
pak::pak("SLINGhub/MRMhub")
```

`pak` may fail because of a network or proxy restriction, or a request
for build tools such as the Xcode command line tools on macOS. In that
case, use `remotes`:

``` r

if (!requireNamespace("remotes", quietly = TRUE)) install.packages("remotes")
remotes::install_github("SLINGhub/MRMhub")
```

## Installing from a downloaded repository ZIP file

If the methods above fail or R cannot reach the repositories, download a
copy of the repository and install MRMhub from it:

1.  Open <https://github.com/SLINGhub/MRMhub> in a browser.
2.  Click the green **Code** button and choose **Download ZIP** (or
    download
    <https://github.com/SLINGhub/MRMhub/archive/refs/heads/main.zip>
    directly).
3.  Unzip the file. It expands to a folder named `MRMhub-main`.
4.  In a **fresh R session**, install from that folder with `remotes`:

``` r

remotes::install_local("path/to/MRMhub-main")
```

Replace `path/to/MRMhub-main` with the actual location of the unzipped
folder, e.g. `"~/Downloads/MRMhub-main"`.

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

Alternatively, the CRAN packages can be installed with
[`install.packages()`](https://rdrr.io/r/utils/install.packages.html).
For the Bioconductor ones (`sva`, `rgoslin`, `lipidr`,
`SummarizedExperiment`, `S4Vectors`), use `pak` as shown above: it
selects the Bioconductor release paired with the installed R version.
`BiocManager` may instead resolve to an older release and report that
the current one requires a newer R. That message is advisory, and
upgrading R is not necessary.

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
| `package 'mrmhub' was built under R version …` | The R-universe binary is built under the current R patch release, newer than the R in use | Cosmetic; `mrmhub` contains no compiled code. Update R to the current release to silence it |
| `there is no package called 'mrmhub'` | Install did not finish | Scroll up for the real error, then retry the install |
| `ERROR: Rtools is required`, or packages start compiling (Windows) | A dependency has no binary for your R version | Update R, or set `options(install.packages.compile.from.source = "never")`. If a source build is unavoidable, install [Rtools](https://cran.r-project.org/bin/windows/Rtools/) matching your R version |
| `Bioconductor version '3.23' requires R version '4.6'` | `BiocManager` selected a Bioconductor release newer than the installed R | Install the Bioconductor packages with `pak` instead: it selects the release paired with your R. Upgrading R is not required |
| `clang: error:`, `Could not find tools necessary to compile a package`, or `No developer tools were found` (macOS) | Xcode command line tools missing | Run `xcode-select --install` in a Terminal, accept the dialog, retry in a fresh session, or install with `remotes` instead of `pak` |
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
