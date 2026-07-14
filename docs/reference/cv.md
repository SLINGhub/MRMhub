# Percent coefficient of variation (%CV)

This function computes the percent coefficient of variation of the
values in x. If na.rm is TRUE then missing values are removed before
computation proceeds.

## Usage

``` r
cv(x, na.rm = FALSE, use_robust_cv = FALSE)
```

## Arguments

- x:

  a numeric vector with untransformed data

- na.rm:

  logical, if TRUE then NA values are stripped from x before computation
  takes place

- use_robust_cv:

  logical, if TRUE the robust coefficient of variation (scaled median
  absolute deviation / median) is computed instead of the standard CV
  (SD / mean)

## Value

a numeric value. If x contains a zero or is not numeric, NA_real\_ is
returned

## Examples

``` r
cv(c(5, 6, 3, 4, 5, NA), na.rm = TRUE)
#> [1] 24.78642
```
