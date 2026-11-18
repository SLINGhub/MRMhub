# Calculate external calibration curve results

Calibration curves are calculated for each feature using ISTD-normalized
intensities and the corresponding concentrations of calibration samples,
as defined in the `qc_concentrations` metadata. The regression fit model
(linear or quadratic) and the weighting method (either "none", "1/x",
"1/x^2", or "1/sqrt(x)") can be defined globally via the arguments
`fit_model` and `fit_weighting` for all features, if `fit_overwrite` is
`TRUE`. Alternatively, the model and weighting can be defined
individually for each feature in the `feature` metadata (columns
`curve_fit_model` and `curve_fit_weighting`). If these details are
missing in the metadata, the default values provided via `fit_model` and
`fit_weighting` will be used.

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
  lod_sigma = c("auto", "residual", "intercept"),
  ignore_failed_calibration = FALSE
)
```

## Arguments

- data:

  A
  [`MRMhubExperiment`](https://slinghub.github.io/MRMhub/quant/reference/MRMhubExperiment-class.md)
  object containing the data to be used for calibration.

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
  `"1/x"`, `"1/x^2"`, or `"1/sqrt(x)"`. This method will be applied if
  no specific weighting method is defined for a feature in the metadata,
  or when `fit_overwrite = TRUE`.

- ignore_missing_annotation:

  If `FALSE`, an error will be raised if calibration curve data is
  missing for any feature.

- include_fit_object:

  If `TRUE`, the function will return the full regression fit objects
  for each feature in the `metrics_calibration` table.

- lod_sigma:

  A character string selecting the response standard deviation (sigma)
  used in the ICH Q2 LoD/LoQ formulas. Must be one of `"auto"` (the
  default: residual standard error, Sy/x, for unweighted fits and
  intercept standard error for weighted fits), `"residual"` (Sy/x;
  LoD/LoQ are `NA` for weighted fits) or `"intercept"` (intercept
  standard error for all fits).

- ignore_failed_calibration:

  If `FALSE`, an error is raised if all quantifier calibration curve
  fits fail. If `TRUE`, a warning is shown instead and the failed fits
  are returned, so resulting concentrations are `NA`.

## Value

A modified
[`MRMhubExperiment`](https://slinghub.github.io/MRMhub/quant/reference/MRMhubExperiment-class.md)
object with an updated `metrics_calibration` table containing the
calibration curve results, including concentrations, LoD, and LoQ values
for each feature.

## Details

A linear curve is also fitted with 2 calibrators, and a single
calibrator gives a line through the origin (`coef_a = 0`). A quadratic
curve needs at least 3 calibrators. A zero-concentration calibrator is
dropped from weighted fits, so a blank plus one standard is then fitted
through the origin. A curve that passes through all its calibrators
(e.g. 2 points for a line, 3 for a quadratic) has no R², sigma, LoD or
LoQ (`NA`).

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
from the two ICH Q2 choices: the residual standard error of the
regression (Sy/x) or the standard error of the intercept. Both must be
in response units for `sigma / S` to be a concentration. For a
**weighted** fit (`1/x`, `1/x^2`, `1/sqrt(x)`) the residual standard
error is computed from weighted residuals, so its units depend on the
weights (e.g. response / concentration for `1/x^2`), and LoD/LoQ derived
from it do not scale with the concentration unit. The intercept standard
error is in response units for any weighting. Hence:

- `"auto"` (default): residual standard error for unweighted fits,
  intercept standard error for weighted fits (reported once per call).

- `"residual"`: residual standard error; LoD/LoQ are `NA` for weighted
  fits, with a warning.

- `"intercept"`: intercept standard error for all fits.

A line through the origin (single linear calibrator) has no intercept
and no residual degrees of freedom, so its LoD/LoQ are `NA`. The `sigma`
column in `metrics_calibration` is always the residual standard error,
independent of `lod_sigma`; for weighted fits it is the weighted
residual standard error, which has no simple units.

The results of the regression and the calculated LoD and LoQ values are
stored in the `metrics_calibration` table of the returned
`MRMhubExperiment` object.

### Calibration coefficient columns

The fitted curve is stored in **ascending** power order, following R's
[`lm()`](https://rdrr.io/r/stats/lm.html) /
[`poly()`](https://rdrr.io/r/stats/poly.html) convention. The model is

`response = coef_a + coef_b * x + coef_c * x^2`

- `coef_a` — intercept (0th-order term, `x^0`)

- `coef_b` — 1st-order (linear) coefficient (`x^1`); the slope of a
  linear fit

- `coef_c` — 2nd-order (quadratic) coefficient (`x^2`); `NA` for a
  linear fit

Only linear and quadratic models are fitted, so there are no
higher-order terms. This ascending order is the **reverse** of the
descending `a*x^2 + b*x + c` form printed by some vendor software (e.g.
Agilent MassHunter, where `a` is the quadratic term). When comparing
against such an export, match coefficients by power (`coef_a` =
intercept, `coef_c` = `x^2`), not by letter.

## References

ICH Harmonised Tripartite Guideline. Validation of Analytical
Procedures: Text and Methodology Q2(R1) (2005); Q2(R2) (2023).
International Council for Harmonisation of Technical Requirements for
Pharmaceuticals for Human Use.

## See also

[`quantify_by_calibration()`](https://slinghub.github.io/MRMhub/quant/reference/quantify_by_calibration.md)
for calculating concentrations based on external calibration curves.
