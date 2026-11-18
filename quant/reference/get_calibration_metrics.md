# Get calibration metrics

Extracts calibration fit metrics from a `MRMhubExperiment` object.

## Usage

``` r
get_calibration_metrics(
  data = NULL,
  include_qualifier = TRUE,
  with_lod = TRUE,
  with_loq = TRUE,
  with_coefficients = TRUE,
  with_sigma = TRUE,
  summary_table = FALSE
)
```

## Arguments

- data:

  A
  [`MRMhubExperiment`](https://slinghub.github.io/MRMhub/quant/reference/MRMhubExperiment-class.md)
  object with QC metrics.

- include_qualifier:

  Whether to include qualifier features. When `FALSE`, only quantifier
  features are returned. Default is `TRUE`.

- with_lod:

  Whether to include LoD in output. Default is `TRUE`.

- with_loq:

  Whether to include LoQ in output. Default is `TRUE`.

- with_coefficients:

  Whether to include regression coefficients. Default is `TRUE`.

- with_sigma:

  Whether to include sigma in output. Default is `TRUE`.

- summary_table:

  When `TRUE`, return a compact, display-formatted summary tibble
  (`analyte`, `fit_model`, `fit_weighting`, `r2`, `lod`, `loq`) with
  `r2` rounded to 5 decimals and `lod`/`loq` to 3 significant figures.
  This is a presentation view for reporting; the values are **rounded**,
  so do not use it for downstream computation. `lod`/`loq` follow
  `with_lod`/`with_loq`. The `with_coefficients`/`with_sigma` flags are
  ignored in this mode. Default is `FALSE` (full, unrounded metrics).

## Value

A tibble with exported calibration metrics.

## Details

Requires prior computation of regression results using
[`calc_calibration_results()`](https://slinghub.github.io/MRMhub/quant/reference/calc_calibration_results.md).
See its documentation for details.

### Returned Details and Metrics

- `feature_id`: Feature identifier.

- `is_quantifier`: Logical, indicates if the feature is a quantifier.

- `fit_model`: Regression model used for fitting.

- `fit_weighting`: Weighting method used in fitting.

- `lowest_cal`: Lowest non-zero calibrator concentration with a
  response.

- `highest_cal`: Highest calibrator concentration with a response.

- `r2`: R² value, indicating goodness of fit. For a **weighted** fit
  this is the weighted coefficient of determination (computed from
  weighted sums of squares), matching the value reported by vendor
  software such as Agilent MassHunter for the same weighted curve.

- `coef_a`: **Intercept** (0th-order term, `x^0`) of the fitted curve.

- `coef_b`: **1st-order** (linear, `x^1`) coefficient — the slope in a
  **linear** fit, or the linear term in a **quadratic** fit.

- `coef_c`: **2nd-order** (quadratic, `x^2`) coefficient in
  **quadratic** fits. Returns `NA` for **linear** fits.

- `sigma`: Residual standard error of the fit. For a **weighted** fit
  this is the weighted residual standard error, which has no simple
  units.

- `reg_failed`: `TRUE` if regression fitting failed.

- `lod` = 3.3 × sigma / slope at zero concentration (see Note).

- `loq` = 10 × sigma / slope at zero concentration (see Note).

The coefficients describe the curve in **ascending** power order (R's
[`lm()`](https://rdrr.io/r/stats/lm.html) /
[`poly()`](https://rdrr.io/r/stats/poly.html) convention):
`response = coef_a + coef_b * x + coef_c * x^2`. This is the reverse of
the descending `a*x^2 + b*x + c` form used by some vendor software (e.g.
Agilent MassHunter, where `a` is the `x^2` term), so when comparing
against such an export, match by power, not by letter.

**Note:** LoD/LoQ follow the ICH Q2(R1/R2) approach (3.3 sigma / S and
10 sigma / S). The slope `S` is the slope of the calibration curve at
zero concentration (the linear coefficient `coef_b`); for a
**quadratic** fit the quadratic term does not contribute to this slope.
The response sigma must be in response units, so by default
(`lod_sigma = "auto"` in
[`calc_calibration_results()`](https://slinghub.github.io/MRMhub/quant/reference/calc_calibration_results.md))
unweighted fits use the residual standard error (Sy/x) and **weighted**
fits (`1/x`, `1/x^2`, `1/sqrt(x)`) the standard error of the intercept.
The weighted residual standard error is not in response units, so
LoD/LoQ derived from it would not scale with the concentration unit. The
`sigma` column reported here is always the residual standard error,
independent of `lod_sigma`.
