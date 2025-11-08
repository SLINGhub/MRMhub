# Manual isotopic interference correction

The interference is subtracted using following formula:
\$\$Value\_{Corrected} = Value\_{Feature} - Factor\_{Contribution} \*
Value\_{Interfering Feature}\$\$

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

  Default: `feature_intensity`. Name of Variable to be corrected.

- feature:

  Name of feature to be corrected

- interfering_feature:

  Name of feature that is interfering, i.e. contributing to the signal
  of `feature`

- interference_contribution:

  Relative portion of the interfering feature to contribute to the
  feature signal. Must be between 0 and 1.

- neg_to_na:

  If `TRUE`, negative or zero values after correction will be replaced
  with `NA`. Default: `FALSE`.

- updated_feature_id:

  Optional. New name of corrected feature. If empty then feature name
  will not change.

## Value

MRMhubExperiment object
