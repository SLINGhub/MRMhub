# Drift correction by custom function

Function to correct for run-order drifts within or across batches via a
provided custom function \#' @details The drift correction function
needs to be provided by the user. See `smooth_fun` for details.

## Usage

``` r
fun_correct_drift(
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

  MRMhubExperiment object

- smooth_fun:

  Function that performs drift correction. Function need to have
  following parameter `data` (`MRMhubExperiment`), `ref_qc_types` (one
  or more strings), and `span_width` (numerical). Function needs to
  return a numerical vector with the length of number of rows in `data`.
  In case functions fails a vector with NA_real\_ needs be returned

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
  values for a feature. If TRUE (default), the original data is used; if
  FALSE, the result for each analysis is NA.

- ignore_istd:

  Do not apply corrections to ISTDs

- feature_list:

  Sets specific features for correction only. Can be character vector or
  a single string which is then interpreted as regular expression.
  Default is `NULL` which means all features are selected.

- recalc_trend_after:

  Recalculate trend post-drift correction for `plot_qc_runscatter()`.
  This will double calculation time.

- show_progress:

  Show progress bar. Default = \`TRUE.

- ...:

  Arguments specific for the smoothing function

## Value

MRMhubExperiment object
