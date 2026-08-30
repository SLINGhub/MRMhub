# Check MRMhub setup

Validates that the user's R environment is correctly configured to use
mrmhub. Checks R version, key dependencies, and optional packages.

## Usage

``` r
check_setup(verbose = TRUE)
```

## Arguments

- verbose:

  Logical. If `TRUE` (default), prints detailed results. If `FALSE`,
  returns results invisibly.

## Value

A list (invisibly) with elements `r_version`, `required`, and
`optional`, each containing pass/fail status.

## Examples

``` r
check_setup()
#> ✔ R version 4.6.1 (>= 4.1.0 required)
#> 
#> ── Required packages ──
#> 
#> ✔ cli (3.6.6)
#> ✔ dplyr (1.2.1)
#> ✔ tibble (3.3.1)
#> ✔ tidyr (1.3.2)
#> ✔ purrr (1.2.2)
#> ✔ readr (2.2.0)
#> ✔ rlang (1.3.0)
#> ✔ ggplot2 (4.0.3)
#> ✔ stringr (1.6.0)
#> ✔ glue (1.8.1)
#> ✔ forcats (1.0.1)
#> ✔ lubridate (1.9.5)
#> ✔ fs (2.1.0)
#> ✔ openxlsx2 (1.29)
#> ✔ scales (1.4.0)
#> ✔ ggh4x (0.3.1)
#> ✔ assertr (3.0.1)
#> 
#> ── Optional packages ──
#> 
#> ✔ knitr (1.51)
#> ✔ rmarkdown (2.31)
#> ✔ testthat (3.3.2)
#> ✔ patchwork (1.3.2)
#> ✔ ggvenn (0.1.19)
#> ✔ ggbeeswarm (0.7.3)
#> ✔ ggrepel (0.9.8)
#> ✔ rgoslin (1.16.0)
#> ✔ lancer (0.1.1)
#> ✔ enviPat (2.8)
#> ✔ SummarizedExperiment (1.42.0)
#> ✔ lipidr (2.26.0)
#> 
#> ── Summary ──
#> 
#> ✔ All good! mrmhub is ready to use.
```
