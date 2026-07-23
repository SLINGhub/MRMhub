# Get feature IDs

Returns a vector of annotated feature IDs (`feature_id`) present in the
dataset

## Usage

``` r
get_featurelist(data, is_istd = NA, is_quantifier = NA)
```

## Arguments

- data:

  A
  [`MRMhubExperiment`](https://slinghub.github.io/MRMhub/quant/reference/MRMhubExperiment-class.md)
  object

- is_istd:

  If set, then defines whether to include or exclude internal standard
  features. Default is `NA` means no filter for internal standards is
  applied.

- is_quantifier:

  If set, then defines whether to include or exclude quantifier
  features. Default is `NA` means no filter for quantifier features is
  applied.

## Value

A character vector with `feature_id` values
