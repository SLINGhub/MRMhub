# Normalize feature intensities using internal standards

Normalize feature intensities by dividing them by the intensities of the
corresponding internal standards (ISTDs). Each feature must have a
defined internal standard (ISTD) in the `feature` metadata.

## Usage

``` r
normalize_by_istd(data = NULL, ignore_missing_annotation = FALSE)
```

## Arguments

- data:

  A
  [`MRMhubExperiment`](https://slinghub.github.io/MRMhub/quant/reference/MRMhubExperiment-class.md)
  object.

- ignore_missing_annotation:

  If `FALSE`, the function will raise an error when an ISTD is not
  defined for one or more features (excluding the ISTDs themselves). If
  `TRUE`, features with missing ISTD annotations will have NA values in
  the normalized intensities.

## Value

A
[`MRMhubExperiment`](https://slinghub.github.io/MRMhub/quant/reference/MRMhubExperiment-class.md)
object with normalized feature intensities
