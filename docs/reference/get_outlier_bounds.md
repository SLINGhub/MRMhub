# Get outlier bounds via different methods

Computes lower and upper bounds for a numeric vector using one of
several methods:

- `"iqr"`: Tukey's Interquartile Range fences

- `"mad"`: Median Absolute Deviation

- `"sd"`: Standard deviation from mean

- `"quantile"`: Fixed percentile cutoffs

- `"z_normal"`: Standard Z-score using mean & SD

- `"z_robust"`: Modified Z-score using median & MAD

- `"fold_change"`: Median ± log10(k), assumes log-transformed data

## Usage

``` r
get_outlier_bounds(
  x,
  method = c("iqr", "mad", "sd", "quantile", "z_normal", "z_robust", "fold_change"),
  k = NULL,
  outlier_log = FALSE,
  na.rm = FALSE
)
```

## Arguments

- x:

  A numeric vector.

- method:

  Character string: one of `"iqr"`, `"mad"`, `"sd"`, `"quantile"`,
  `"z_normal"`, `"z_robust"`, or `"fold_change"`.

- k:

  Numeric multiplier or threshold. Defaults depend on method:

  - `"iqr"`: 1.5 (multiplier of IQR)

  - `"mad"`: 3 (multiplier of MAD)

  - `"sd"`: 3 (multiplier of SD)

  - `"z_normal"`: 3 (threshold in SD units)

  - `"z_robust"`: 3.5 (threshold in robust Z units)

  - `"fold_change"`: 2 (fold-change multiplier, assumes log-transformed
    data)

  - `"quantile"`: 0.01 (lower/upper quantiles, e.g., 1% and 99%)

- outlier_log:

  Logical. If `TRUE`, applies log10 transformation to `x`

- na.rm:

  Logical. Should missing values be removed? Default is `FALSE`.

## Value

A numeric vector of length 2: `c(lower_bound, upper_bound)` representing
the smallest and largest observed values within the computed fences.

## Examples

``` r
get_outlier_bounds(c(1, 2, 3, 4, 100), "iqr")
#> [1] 1 4
get_outlier_bounds(c(1, 2, 3, 4, 100), "mad")
#> [1] 1 4
get_outlier_bounds(c(1, 2, 3, 4, 100), "sd")
#> [1]   1 100
get_outlier_bounds(c(1, 2, 3, 4, 100), "quantile", k = 0.05)
#> [1] 2 4
get_outlier_bounds(c(1, 2, 3, 4, 100), "z_normal")
#> [1]   1 100
get_outlier_bounds(c(1, 2, 3, 4, 100), "z_robust")
#> [1] 1 4
get_outlier_bounds(log10(c(1, 2, 4, 8)), "fold_change")       # default 2×
#> [1] 0.30103 0.60206
get_outlier_bounds(log10(c(1, 2, 4, 8)), "fold_change", k = 3) # 3× fold-change
#> [1] 0.00000 0.90309
```
