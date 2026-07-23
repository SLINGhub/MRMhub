# Exclude analyses from the dataset

This function excludes specified analyses from a `MRMhubExperiment`
object, either by marking them as invalid for downstream processing. The
function also allows to reset the exclusions.

## Usage

``` r
exclude_analyses(data = NULL, analyses, clear_existing)
```

## Arguments

- data:

  A
  [`MRMhubExperiment`](https://slinghub.github.io/MRMhub/quant/reference/MRMhubExperiment-class.md)
  object

- analyses:

  A character vector of analysis IDs (case-sensitive) to be excluded
  from the dataset. If this is `NA` or an empty vector, the exclusion
  behavior will be handled as set via the `clear_existing` flag.

- clear_existing:

  A logical value. If `TRUE`, existing `valid_analysis` flags will be
  overwritten. If `FALSE`, the exclusions will be appended, preserving
  any existing invalidated analyses.

## Value

A modified
[`MRMhubExperiment`](https://slinghub.github.io/MRMhub/quant/reference/MRMhubExperiment-class.md)
object with the specified analyses defined as excluded.
