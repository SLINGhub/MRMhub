# Drift correction by generalized additive model (GAM) smoothing

This function corrects for run-order drifts within or across batches
using Generalized Additive Models (GAMs). The correction uses penalized
splines, with automatic selection of smoothing parameters based on
cross-validation or penalized likelihood. It is typically based on QC
(Quality Control) samples measured at specific intervals throughout the
run sequence. The correction can be applied to "intensity",
"norm_intensity", or "conc" data.

It is recommended to visually inspect the correction using the
[`plot_runscatter()`](https://slinghub.github.io/MRMhub/quant/reference/plot_runscatter.md)
function. Set the argument `recalc_trend_after = TRUE` so that the
trends after correction are also available for plotting. For further
details, refer to the description of
[`plot_runscatter()`](https://slinghub.github.io/MRMhub/quant/reference/plot_runscatter.md).

The corrections can be applied on a batch-by-batch basis
(`batch_wise = TRUE`, default) or across all batches
(`batch_wise = FALSE`). Existing corrections are either replaced
(`replace_previous = TRUE`) or added on top of them
(`replace_previous = FALSE`).

Furthermore, drift correction can be applied unconditionally
(`conditional_correction = FALSE`) or conditionally, based on whether
the sample CV change before and after correction is below a defined
threshold (`cv_diff_threshold`). This conditional correction is assessed
independently for each batch if `batch_wise = TRUE`, where the median of
the CV changes across the batch is compared with the threshold.

**Note**: The function outputs a message indicating the median CV change
and the median absolute CV before and after correction for all samples.
However, these metrics are experimental and should not be used as
definitive criteria for correction (see Details below).

This method is implemented using penalized splines via the
[`mgcv::gam()`](https://rdrr.io/pkg/mgcv/man/gam.html) function.

## Usage

``` r
correct_drift_gam(
  data = NULL,
  variable,
  ref_qc_types,
  batch_wise = TRUE,
  ignore_istd = TRUE,
  replace_previous = TRUE,
  bs = "ps",
  k = -1,
  sp = NULL,
  log_transform_internal = TRUE,
  conditional_correction = FALSE,
  recalc_trend_after = FALSE,
  feature_list = NULL,
  cv_diff_threshold = 0,
  use_original_if_fail = FALSE,
  show_progress = TRUE
)
```

## Arguments

- data:

  [`MRMhubExperiment`](https://slinghub.github.io/MRMhub/quant/reference/MRMhubExperiment-class.md)
  object

- variable:

  The variable to be corrected for drift effects. Must be one of
  "intensity", "norm_intensity", or "conc"

- ref_qc_types:

  QC types used for drift correction

- batch_wise:

  Logical. Apply the correction to each batch separately (`TRUE`,
  default) or across all batches (`FALSE`).

- ignore_istd:

  Logical. Exclude internal standards (ISTDs) from correction if `TRUE`.

- replace_previous:

  Logical. Replace existing correction (`TRUE`, default) or layer on top
  of it (`FALSE`).

- bs:

  Basis type for the spline: `"ps"` (penalized spline, default) or
  `"tp"` (thin plate spline).

- k:

  Number of basis functions (default: `-1`, automatically chosen by
  GAM).

- sp:

  Smoothing parameter (`NULL` by default, estimated automatically).

- log_transform_internal:

  Log transform the data for correction when `TRUE` (the default). Note:
  log transformation is solely applied internally for smoothing, results
  will not be log-transformed.

- conditional_correction:

  Determines whether drift correction is applied to all features
  unconditionally (`FALSE`, the default) or, when `TRUE`, only
  conditionally based on sample CV change.

- recalc_trend_after:

  Recalculate trend post-drift correction for
  [`plot_runscatter()`](https://slinghub.github.io/MRMhub/quant/reference/plot_runscatter.md).
  This will double calculation time.

- feature_list:

  Subset the features for correction whose names match the specified
  text using regular expression. Default is `NULL`.

- cv_diff_threshold:

  Maximum allowable change (difference) in CV before and after smoothing
  for correction to be applied.

- use_original_if_fail:

  Determines the action when smoothing fails or results in invalid
  values for a feature. If `FALSE` (default), the result for each
  feature will be `NA` for all batches, if `TRUE`, the original data is
  kept.

- show_progress:

  Logical. Display progress bars if `TRUE`; disable for notebook
  rendering by setting to `FALSE`.

## Value

[`MRMhubExperiment`](https://slinghub.github.io/MRMhub/quant/reference/MRMhubExperiment-class.md)
object

## Details

In the output message, the median CV change is computed as the median of
CV changes for all features in global correction or for features where
the correction passed the defined CV difference threshold in case of
conditional correction (`conditional_correction = TRUE`). For batch-wise
correction, the change is calculated per batch, with the final median CV
change being the median of these batch medians across features.

This smoothing is based on Generalized Additive Models (GAM) using
penalized splines, implemented via
[`mgcv::gam()`](https://rdrr.io/pkg/mgcv/man/gam.html).

## See also

[`mgcv::gam()`](https://rdrr.io/pkg/mgcv/man/gam.html); the
[drift-correction
tutorial](https://slinghub.github.io/MRMhub/quant/articles/tutorial-04-drift-correction.html)
for a worked example.
