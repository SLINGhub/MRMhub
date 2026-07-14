# Calculate concentrations based on external calibration

Concentrations of all features in all analyses are determined using
ISTD-normalized intensities and corresponding external calibration
curves. Calibration curves are calculated for each feature based on
calibration sample concentrations defined in the `qc_concentrations`
metadata. The regression fit model (linear or quadratic) and the
weighting method (either "none", "1/x", or "1/x^2") can be defined
globally via the arguments `fit_model` and `fit_weighting` for all
features, if `fit_overwrite` is `TRUE`. Alternatively, the model and
weighting can be defined individually for each feature in the `feature`
metadata (columns `curve_fit_model` and `fit_weighting`). If these
details are missing in the metadata, the default values provided via
`fit_model` and `fit_weighting` will be used.

## Usage

``` r
quantify_by_calibration(
  data = NULL,
  include_qualifier = TRUE,
  fit_overwrite,
  fit_model = c("linear", "quadratic"),
  fit_weighting = c("none", "1/x", "1/x^2"),
  ignore_failed_calibration = FALSE,
  ignore_missing_annotation = FALSE
)
```

## Arguments

- data:

  A `MRMhubExperiment` object

- include_qualifier:

  A logical value. If `TRUE`, the function will include qualifier
  features in the calibration curve calculations.

- fit_overwrite:

  If `TRUE`, the function will use the provided `fit_model` and
  `fit_weighting` values for all analytes and ignore any fit method and
  weighting settings defined in the metadata.

- fit_model:

  A character string specifying the default regression fit method to use
  for the calibration curve. Must be one of `"linear"` or `"quadratic"`.
  This method will be applied if no specific fit method is defined for a
  feature in the metadata, or when `fit_overwrite = TRUE`.

- fit_weighting:

  A character string specifying the default weighting method for the
  regression points in the calibration curve. Must be one of `"none"`,
  `"1/x"`, or `"1/x^2"`. This method will be applied if no specific
  weighting method is defined for a feature in the metadata, or when
  `fit_overwrite = TRUE`.

- ignore_failed_calibration:

  If `FALSE`, raises error if calibration curve fit fails for any
  feature. If `TRUE`, failed fits will be ignored, and resulting feature
  concentration will be `NA`.

- ignore_missing_annotation:

  If `FALSE`, raises error if any of the following information is
  missing: calibration curve data, ISTD mix volume and sample amounts
  for any feature. If `TRUE`, missing annotations will be ignored, and
  resulting feature concentration will be `NA`

## Value

A modified `MRMhubExperiment` object with updated concentration values.

## Details

The concentrations are added to the `dataset` table as `feature_conc`
column. The results of the regression and the calculated LoD and LoQ
values are stored in the `metrics_calibration` table of the returned
`MRMhubExperiment` object.

## See also

[`calc_calibration_results()`](https://slinghub.github.io/MRMhub/quant/reference/calc_calibration_results.md)
for calculating the calibration curve results including LoD and LoQ.

[`quantify_by_istd()`](https://slinghub.github.io/MRMhub/quant/reference/quantify_by_istd.md)
for calculation of concentrations based on spiked-in internal standard
concentration.
