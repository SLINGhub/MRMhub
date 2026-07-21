# Manual isotopic interference correction

Subtract a single, user-specified interference from one feature. Use
this for a one-off correction or to validate a factor before trusting
the automatic derivation; for the metadata-driven paths use
[`correct_isotopic_interferences()`](https://slinghub.github.io/MRMhub/quant/reference/correct_isotopic_interferences.md)
(automatic, isotopic) or
[`correct_custom_interferences()`](https://slinghub.github.io/MRMhub/quant/reference/correct_custom_interferences.md)
(declared). The interference is subtracted as: \$\$Value\_{Corrected} =
Value\_{Feature} - Factor\_{Contribution} \* Value\_{Interfering
Feature}\$\$

## Usage

``` r
correct_interference_manual(
  data = NULL,
  variable,
  feature,
  interfering_feature,
  interference_contribution,
  neg_to_na = FALSE,
  updated_feature_id = NA
)
```

## Arguments

- data:

  MRMhubExperiment object

- variable:

  Name of the variable to be corrected, e.g. `feature_intensity`.

- feature:

  Name of feature to be corrected

- interfering_feature:

  Name of feature that is interfering, i.e. contributing to the signal
  of `feature`

- interference_contribution:

  Relative portion of the interfering feature contributing to the
  feature signal. Must be greater than 0; values are usually between 0
  and 1, and values above 1 trigger a warning.

- neg_to_na:

  If `TRUE`, negative or zero values after correction will be replaced
  with `NA`. Default: `FALSE`.

- updated_feature_id:

  Optional. New name of corrected feature. If empty then feature name
  will not change.

## Value

MRMhubExperiment object
