# Get calibration metrics

Extracts calibration fit metrics from a `MRMhubExperiment` object.

## Usage

``` r
get_calibration_metrics(
  data = NULL,
  with_lod = TRUE,
  with_loq = TRUE,
  with_coefficients = TRUE,
  with_sigma = TRUE
)
```

## Arguments

- data:

  A `MRMhubExperiment` object with QC metrics.

- with_lod:

  Whether to include LoD in output. Default is `TRUE`.

- with_loq:

  Whether to include LoQ in output. Default is `TRUE`.

- with_coefficients:

  Whether to include regression coefficients. Default is `TRUE`.

- with_sigma:

  Whether to include sigma in output. Default is `TRUE`.

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

- `weighting`: Weighting method used in fitting.

- `lowest_cal`: Lowest nonzero calibration concentration.

- `highest_cal`: Highest calibration concentration.

- `r.squared`: R-squared value, indicating goodness of fit.

- `coef_a`: Intercept of the regression line

- `coef_b`: Slope of the regression line in **linear** models, or
  coefficient of the linear term (`x`) in **quadratic** models.

- `coef_c`: Coefficient of the quadratic term (`x^2`) in **quadratic**
  models. Returns `NA` for **linear** models.

- `sigma`: Standard deviation of residuals.

- `reg_failed`: `TRUE` if regression fitting failed.

- `LoD` = 3.3× the sample standard error of residuals / slope of the
  regression (see Notes).

- `LoQ` = 10× the sample standard error of residuals / slope of the
  regression (see Notes).

**Note:** LoD/LoQ follow the ICH Q2(R1/R2) approach (3.3 sigma / S and
10 sigma / S). The slope `S` is the slope of the calibration curve at
zero concentration (the linear coefficient `coef_b`); for a
**quadratic** fit the quadratic term does not contribute to this slope.
