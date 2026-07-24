# Pooled percent relative standard deviation (%RSD) across groups

[`pooled_sd()`](https://slinghub.github.io/MRMhub/quant/reference/pooled_sd.md)
expressed as a percentage of the grand mean of `x`, i.e. a batch-pooled
%CV. The pooled SD weights each group by its degrees of freedom and the
grand mean weights each value equally, so both are consistently weighted
by group size. See
[`pooled_sd()`](https://slinghub.github.io/MRMhub/quant/reference/pooled_sd.md)
for how groups are pooled.

## Usage

``` r
pooled_rsd(x, group, na.rm = FALSE, min_n = 2L)
```

## Arguments

- x:

  a numeric vector

- group:

  a vector the same length as `x` giving the pooling group of each value
  (e.g. `batch_id`)

- na.rm:

  logical, if `TRUE` then NA values in `x` are stripped before pooling

- min_n:

  integer, the minimum number of non-missing values a group must have to
  contribute. Groups with fewer than `min_n` are dropped; a group is
  always dropped below two values, which have no within-group variance.
  The default is `2`.

## Value

a single numeric value. `NA_real_` if the grand mean is zero or NA, `x`
is not numeric, or no group has enough replicates.

## Examples

``` r
pooled_rsd(c(5, 6, 4, 15, 16, 14), group = c(1, 1, 1, 2, 2, 2))
#> [1] 10
```
