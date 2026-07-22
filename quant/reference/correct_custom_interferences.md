# Correct declared (custom) interferences

Applies the interference corrections you declared in the feature
metadata (the legacy `interference_feature_id` /
`interference_contribution` columns, and any `source == "manual"` rows
in `annot_interferences`) to the raw feature intensities, using the same
engine and formula as
[`correct_isotopic_interferences()`](https://slinghub.github.io/MRMhub/quant/reference/correct_isotopic_interferences.md).
Use this for in-source fragments, co-eluting isobars or other
non-isotopic interferences you know about. Warns and returns the data
unchanged if none are defined.

## Usage

``` r
correct_custom_interferences(
  data = NULL,
  variable = "feature_intensity",
  sequential_correction = TRUE,
  neg_to_na = FALSE
)
```

## Arguments

- data:

  MRMhubExperiment object.

- variable:

  Name of the variable to correct. Only `"feature_intensity"` (the raw
  intensity) is supported. Default: `"feature_intensity"`.

- sequential_correction:

  Logical. If `TRUE` (default), a chain of interferences is corrected
  sequentially so each feature uses the already-corrected signal of its
  interferer (propagates along the chain). If `FALSE`, each feature is
  corrected from the raw interferer, without propagation.

- neg_to_na:

  If `TRUE`, negative or zero values after correction are replaced with
  `NA`. Default: `FALSE`.

## Value

MRMhubExperiment object with feature intensities corrected.

## See also

[`correct_isotopic_interferences()`](https://slinghub.github.io/MRMhub/quant/reference/correct_isotopic_interferences.md),
[`correct_interference_manual()`](https://slinghub.github.io/MRMhub/quant/reference/correct_interference_manual.md)
