# Installation

Manual

## Requirements

- **R ≥ 4.2** — install from [CRAN](https://cran.r-project.org)
- **An IDE** — [Positron](https://positron.posit.co),
  [RStudio](https://posit.co/download/rstudio-desktop/), or [VS
  Code](https://code.visualstudio.com)

MRMhub’s core functionality requires no R coding skills, but basic
familiarity with R and an IDE is needed to run and adapt the workflows.

**New to R?**

Try online tutorials such as [An opinionated tour of
RStudio](https://rladiessydney.org/courses/ryouwithme/01-basicbasics-1/)
and the [RStudio User
Guide](https://docs.posit.co/ide/user/ide/get-started/). Having a
colleague who is familiar with the IDE can also help you get started
smoothly and stay motivated.

## Installing MRMhub

**Tip.** Quit and reopen the IDE first; most install failures come from
packages already loaded in memory.

In a fresh R session:

``` r

if (!require("pak")) install.packages("pak")
pak::pak("SLINGhub/MRMhub")
```

The same command works on Windows, macOS, and Linux. `pak` pulls
prebuilt binaries where available, so compilation tools are usually not
needed. If `pak` is unavailable, use
`remotes::install_github("SLINGhub/MRMhub")`.

## Confirm It Loaded

``` r

library(mrmhub)
```

If this loads without error, you are ready to go — head to [Your First
Analysis](https://slinghub.github.io/MRMhub/quant/articles/tutorial-00-first-analysis.md).

## Troubleshooting Common Errors

If the install seemed to succeed but something isn’t working, run
[`check_setup()`](https://slinghub.github.io/MRMhub/quant/reference/check_setup.md)
to report the R version and flag any missing dependencies:

``` r

check_setup()
```

| Error | Cause | Fix |
|----|----|----|
| `namespace 'rlang' is already loaded` | An old dependency is still loaded in the session | Restart R (`Ctrl+Shift+F10`) and retry the install |
| `cannot open URL` | Firewall or proxy blocking GitHub | `options(download.file.method = "libcurl")`, or clone the repo and use `remotes::install_local("path/to/MRMhub")` |
| `package 'X' was installed under R version …` | Package built for a different R | `install.packages("X")` to rebuild it for your R |
| `there is no package called 'mrmhub'` | Install did not finish | Scroll up for the real error, then retry the install |
| `ERROR: Rtools is required` (Windows) | A source-only dependency needs compilation | Install [Rtools](https://cran.r-project.org/bin/windows/Rtools/) matching your R version, restart R, retry |
| `clang: error: ...` (macOS) | Compiler tools missing | Run `xcode-select --install` in Terminal, retry |
| `cannot find -lcurl` (Linux) | System libraries missing | `sudo apt install libcurl4-openssl-dev libxml2-dev libssl-dev libfontconfig1-dev` |

A longer list, covering proxies, mixed R installations on macOS, and
INTEGRATOR security warnings, is given in [Troubleshooting &
FAQ](https://slinghub.github.io/MRMhub/quant/articles/manual-10-troubleshooting.md).

## Next steps

- [Key Concepts &
  Glossary](https://slinghub.github.io/MRMhub/quant/articles/manual-01-key-concepts.md)
  — core vocabulary and the MRMhubExperiment object
- [Your First
  Analysis](https://slinghub.github.io/MRMhub/quant/articles/tutorial-00-first-analysis.md)
  — a short end-to-end walkthrough
- Questions or bug reports? File an issue on
  [GitHub](https://github.com/SLINGhub/MRMhub/issues), or contact the
  authors directly.
