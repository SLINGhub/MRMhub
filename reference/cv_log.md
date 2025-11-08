# Percent coefficient of variation (%CV) based on log-transformation

Computes the percent coefficient of variation (CV) based on the
log-transformation of the input data. This can be more robust in certain
cases, especially when the data is not normally distributed.

## Usage

``` r
cv_log(x, na.rm = FALSE)
```

## Arguments

- x:

  a numeric vector with untransformed data

- na.rm:

  logical, if TRUE then NA values are stripped from x before computation
  takes place

## Value

a numeric value. If x contains a zero, then NaN is returned. If x is not
numeric, NA_real\_ is returned

## References

Canchola et al. (2017) Correct use of percent coefficient of variation
(% CV) formula for log-transformed data. MOJ Proteomics Bioinform.
2017;6(4):316‒317. [DOI:
10.15406/mojpb.2017.06.00200](https://doi.org/10.15406/mojpb.2017.06.00200)

## Examples

``` r
cv_log(c(5, 6, 3, 4, 5, NA), na.rm = TRUE)
#> [1] 27.082
```
