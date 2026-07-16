# Calculate external calibration curve results

Calibration curves are calculated for each feature using ISTD-normalized
intensities and the corresponding concentrations of calibration samples,
as defined in the `qc_concentrations` metadata. The regression fit model
(linear or quadratic) and the weighting method (either "none", "1/x", or
"1/x^2") can be defined globally via the arguments `fit_model` and
`fit_weighting` for all features, if `fit_overwrite` is `TRUE`.
Alternatively, the model and weighting can be defined individually for
each feature in the `feature` metadata (columns `curve_fit_model` and
`fit_weighting`). If these details are missing in the metadata, the
default values provided via `fit_model` and `fit_weighting` will be
used.

## Usage

``` r
calc_calibration_results(
  data = NULL,
  variable = "feature_norm_intensity",
  include_qualifier = TRUE,
  fit_overwrite,
  fit_model,
  fit_weighting,
  ignore_missing_annotation = FALSE,
  include_fit_object = FALSE,
  lod_sigma = c("residual", "intercept")
)
```

## Arguments

- data:

  A `MRMhubExperiment` object containing the data to be used for
  calibration.

- variable:

  A character string specifying the variable for calibration. Use
  `"feature_norm_intensity"` for typical scenarios involving internal
  standardization. When performing only external standardization,
  without internal standardization, use `"feature_intensity"`.

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

- ignore_missing_annotation:

  If `FALSE`, an error will be raised if any of the following
  information is missing: calibration curve data, ISTD mix volume, and
  sample amounts for any feature.

- include_fit_object:

  If `TRUE`, the function will return the full regression fit objects
  for each feature in the `metrics_calibration` table.

- lod_sigma:

  A character string selecting the response standard deviation (sigma)
  used in the ICH Q2 LoD/LoQ formulas. Must be one of `"residual"` (the
  residual standard error of the regression, Sy/x; the default) or
  `"intercept"` (the standard error of the intercept). No averaging of
  the two is performed.

## Value

A modified `MRMhubExperiment` object with an updated
`metrics_calibration` table containing the calibration curve results,
including concentrations, LoD, and LoQ values for each feature.

## Details

Additionally, the limit of detection (LoD) and limit of quantification
(LoQ) are calculated for each feature based on the calibration curve,
following the ICH Q2(R1/R2) approach (LoD = 3.3 sigma / S, LoQ = 10
sigma / S). Here S is the slope of the calibration curve, taken at zero
concentration (the linear coefficient `coef_b`). For a quadratic fit the
true slope is `b + 2 c x`, which reduces to `coef_b` at zero
concentration, so the quadratic term does not contribute to the slope
used here. ICH Q2 specifies the slope formula for linear responses only;
using the low-concentration tangent slope for a quadratic fit is an
approximation beyond the guideline (adequate when the curvature near
zero is small).

The response standard deviation `sigma` is selected via `lod_sigma`,
following the ICH-acceptable choices: `"residual"` uses the residual
standard error of the regression (Sy/x; the default and prior
behaviour), while `"intercept"` uses the standard error of the
intercept. The `sigma` column reported in `metrics_calibration` is
always the residual standard error, independent of this choice.

The results of the regression and the calculated LoD and LoQ values are
stored in the `metrics_calibration` table of the returned
`MRMhubExperiment` object.

## References

ICH Harmonised Tripartite Guideline. Validation of Analytical
Procedures: Text and Methodology Q2(R1) (2005); Q2(R2) (2023).
International Council for Harmonisation of Technical Requirements for
Pharmaceuticals for Human Use.

## See also

[`quantify_by_calibration()`](https://slinghub.github.io/MRMhub/quant/reference/quantify_by_calibration.md)
for calculating concentrations based on external calibration curves.
