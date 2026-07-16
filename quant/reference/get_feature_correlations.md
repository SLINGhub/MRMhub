# Generate correlation matrix in long format

Creates a correlation matrix and transforms it to long format, filtering
by correlation thresholds.

## Usage

``` r
get_feature_correlations(tbl, cor_min_neg, cor_min)
```

## Arguments

- tbl:

  A data frame containing numeric columns for correlation analysis

- cor_min_neg:

  Numeric. Lower Pearson's correlation threshold

- cor_min:

  Numeric. Upper Pearson's correlation threshold

## Value

A data frame in long format containing filtered correlations
