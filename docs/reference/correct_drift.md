# Drift correction by custom function

Function to correct for run-order drifts within or across batches via a
provided custom function

## Usage

``` r
correct_drift(
  data = NULL,
  smooth_fun,
  variable,
  ref_qc_types,
  batch_wise,
  replace_previous = TRUE,
  log_transform_internal = TRUE,
  conditional_correction = FALSE,
  cv_diff_threshold = 0,
  use_original_if_fail = TRUE,
  ignore_istd = TRUE,
  feature_list = NULL,
  recalc_trend_after = FALSE,
  show_progress = TRUE,
  ...
)
```

## Arguments

- data:

  [`MRMhubExperiment`](https://slinghub.github.io/MRMhub/quant/reference/MRMhubExperiment-class.md)
  object

- smooth_fun:

  Function that performs the drift correction for a single feature
  within one batch. It must accept the arguments `tbl` (a data frame
  with the columns `qc_type`, `x` (run-order number), `y` (the variable
  to correct), and `analysis_id`, `feature_id`, `batch_id`),
  `ref_qc_types` (one or more QC-type strings used to fit the trend),
  `log_transform_internal` (logical), and `...` (smoother-specific
  parameters such as `span` or `degree`). It must return a named list
  carrying `y_adj` (the drift-adjusted `y`) and `fit_error` (logical),
  and typically also `y_fit`, `fit_warning`, and the passed-through
  `analysis_id`, `feature_id`, `batch_id`, `qc_type`, and `x`. When the
  fit fails it must return that same structure with `y_adj = NA_real_`
  and `fit_error = TRUE`. See
  [`fun_loess()`](https://slinghub.github.io/MRMhub/quant/reference/fun_loess.md)
  for a reference implementation.

- variable:

  The variable to be corrected for drift effects. Must be one of
  "intensity", "norm_intensity", or "conc"

- ref_qc_types:

  QC types used for drift correction

- batch_wise:

  Apply to each batch separately if `TRUE` (the default)

- replace_previous:

  Logical. Replace previous correction (`TRUE`), or adds on top of
  previous correction (`FALSE`). Default is `TRUE`.

- log_transform_internal:

  Apply log transformation internally for smoothing if `TRUE` (default).
  This enhances robustness against outliers but does not affect the
  final data, which remains untransformed.

- conditional_correction:

  Determines whether drift correction is applied to all features
  unconditionally (`FALSE`, the default) or, when `TRUE`, only to
  features whose difference of sample CV before vs after smoothing is
  below the threshold specified by `cv_diff_threshold`.

- cv_diff_threshold:

  This parameter defines the maximum allowable change (difference) in
  the coefficient of variation (CV) of samples before and after
  smoothing for the correction to be applied. A value of 0 (the default)
  requires the CV to improve, while a value above 0 allows the CV to
  also become worse by a maximum of the defined difference.

- use_original_if_fail:

  Determines the action when smoothing fails or results in invalid
  values for a feature. If `TRUE` (default), the original data is used;
  if `FALSE`, the result for each analysis is NA.

- ignore_istd:

  Do not apply corrections to ISTDs

- feature_list:

  Sets specific features for correction only. Can be character vector or
  a single string which is then interpreted as regular expression.
  Default is `NULL` which means all features are selected.

- recalc_trend_after:

  Recalculate trend post-drift correction for
  [`plot_runscatter()`](https://slinghub.github.io/MRMhub/quant/reference/plot_runscatter.md).
  This will double calculation time.

- show_progress:

  Show progress bar. Default = `TRUE`.

- ...:

  Arguments specific for the smoothing function

## Value

[`MRMhubExperiment`](https://slinghub.github.io/MRMhub/quant/reference/MRMhubExperiment-class.md)
object

## Details

The drift correction function needs to be provided by the user. See
`smooth_fun` for details.
