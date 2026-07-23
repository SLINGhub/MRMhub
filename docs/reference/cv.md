# Percent coefficient of variation (%CV)

This function computes the percent coefficient of variation of the
values in x. If na.rm is `TRUE` then missing values are removed before
computation proceeds.

## Usage

``` r
cv(x, na.rm = FALSE, use_robust_cv = FALSE, min_n = 1L)
```

## Arguments

- x:

  a numeric vector with untransformed data

- na.rm:

  logical, if `TRUE` then NA values are stripped from x before
  computation takes place

- use_robust_cv:

  logical, if `TRUE` the robust coefficient of variation (scaled median
  absolute deviation / median) is computed instead of the standard CV
  (SD / mean)

- min_n:

  integer, the minimum number of observations (non-missing ones when
  `na.rm = TRUE`) required to return a CV. Fewer than `min_n` values
  return `NA_real_`. The default (`1`) is a no-op, since
  [`sd()`](https://rdrr.io/r/stats/sd.html)/[`mad()`](https://rdrr.io/r/stats/mad.html)
  already return `NA` for fewer than two values.

## Value

a numeric value. If the mean (or the median, for robust CV) is zero, or
x is not numeric, NA_real\_ is returned

## Examples

``` r
cv(c(5, 6, 3, 4, 5, NA), na.rm = TRUE)
#> [1] 24.78642
```
