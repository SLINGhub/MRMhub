# Installation

## Requirements

- **R ≥ 4.2** — install from [CRAN](https://cran.r-project.org)
- **An IDE** — [Positron](https://positron.posit.co),
  [RStudio](https://posit.co/download/rstudio-desktop/), or [VS
  Code](https://code.visualstudio.com)

## Installation

**Tip.** Quit and reopen your IDE first — most install failures come
from packages already loaded in memory.

In a fresh R session:

``` r

if (!require("pak")) install.packages("pak")
pak::pak("SLINGhub/mrmhub")
```

The same command works on Windows, macOS, and Linux. `pak` pulls
prebuilt binaries where available, so compilation tools are usually not
needed. If `pak` is unavailable, use
`remotes::install_github("SLINGhub/mrmhub")`.

## Verify Your Setup

``` r

library(mrmhub)
check_setup()
```

This checks your R version and dependencies and reports exactly what’s
missing if anything fails.

## Troubleshooting Common Errors

| Error | Cause | Fix |
|----|----|----|
| `namespace 'rlang' is already loaded` | An old dependency is still loaded in the session | Restart R (`Ctrl+Shift+F10`) and retry the install |
| `cannot open URL` | Firewall or proxy blocking GitHub | `options(download.file.method = "libcurl")`, or clone the repo and use `remotes::install_local("path/to/MRMhub")` |
| `package 'X' was installed under R version …` | Package built for a different R | `install.packages("X")` to rebuild it for your R |
| `there is no package called 'mrmhub'` | Install did not finish | Scroll up for the real error, then retry the install |
| `ERROR: Rtools is required` (Windows) | A source-only dependency needs compilation | Install [Rtools](https://cran.r-project.org/bin/windows/Rtools/) matching your R version, restart R, retry |
| `clang: error: ...` (macOS) | Compiler tools missing | Run `xcode-select --install` in Terminal, retry |
| `cannot find -lcurl` (Linux) | System libraries missing | `sudo apt install libcurl4-openssl-dev libxml2-dev libssl-dev libfontconfig1-dev` |

The longer list — proxies, mixed R installations on macOS, INTEGRATOR
security warnings — lives in [Troubleshooting &
FAQ](https://slinghub.github.io/MRMhub/quant/articles/manual-09-troubleshooting.md).

## Support

File issues or questions on
[GitHub](https://github.com/SLINGhub/MRMhub/issues), or contact the
authors directly.
