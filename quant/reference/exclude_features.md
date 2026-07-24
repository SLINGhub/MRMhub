# Exclude features from the dataset

This function excludes specified features from a `MRMhubExperiment`
object, either by marking them as invalid for downstream processing. The
function also allows to reset the exclusions.

## Usage

``` r
exclude_features(data = NULL, features, clear_existing)
```

## Arguments

- data:

  A
  [`MRMhubExperiment`](https://slinghub.github.io/MRMhub/quant/reference/MRMhubExperiment-class.md)
  object

- features:

  A character vector of feature IDs (case-sensitive) to be excluded from
  the dataset. If this is `NA` or an empty vector, the exclusion
  behavior will be handled as set via the `clear_existing` flag.

- clear_existing:

  A logical value. If `TRUE`, existing `valid_feature` flags will be
  overwritten. If `FALSE`, the exclusions will be appended, preserving
  any existing invalidated features

## Value

A modified
[`MRMhubExperiment`](https://slinghub.github.io/MRMhub/quant/reference/MRMhubExperiment-class.md)
object with the specified features defined as excluded.
