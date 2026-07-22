# Pooled standard deviation across groups

Pools the within-group variances of `x` across the levels of `group`,
weighting each group by its degrees of freedom (`n_i - 1`), and returns
the square root. This is the within-group precision estimate: unlike a
plain `sd(x)` it is not inflated by systematic shifts *between* groups
(e.g. batch offsets or drift), so it is the appropriate spread for a
batch-pooled %RSD.

## Usage

``` r
pooled_sd(x, group, na.rm = FALSE, min_n = 2L)
```

## Arguments

- x:

  a numeric vector

- group:

  a vector the same length as `x` giving the pooling group of each value
  (e.g. `batch_id`)

- na.rm:

  logical, if TRUE then NA values in `x` are stripped before pooling

- min_n:

  integer, the minimum number of non-missing values a group must have to
  contribute. Groups with fewer than `min_n` are dropped; a group is
  always dropped below two values, which have no within-group variance.
  The default is `2`.

## Value

a single numeric value. `NA_real_` if `x` is not numeric or no group has
enough replicates to pool.

## Examples

``` r
pooled_sd(c(5, 6, 4, 15, 16, 14), group = c(1, 1, 1, 2, 2, 2))
#> [1] 1
```
