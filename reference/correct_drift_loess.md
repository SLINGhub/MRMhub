# Drift Correction by LOESS Smoothing

This function corrects for run-order drifts within or across batches
using LOESS (Locally Estimated Scatterplot Smoothing). The correction is
typically based on QC (Quality Control) samples that were measured at
specific intervals throughout the run sequence. The smoothed curve
derived from the QC samples is then used to adjust all other samples in
the dataset. The correction can be applied to "intensity",
"norm_intensity", or "conc" data.

The degree of smoothing is controlled by the span parameter `span`
(default is 0.75). Additionally, the `degree` parameter can be specified
to control the degree of the polynomial used in the local regression
(default is 2)

It is recommended to visually inspect the correction using the
[`plot_runscatter()`](https://slinghub.github.io/MRMhub/reference/plot_runscatter.md)
function. Set the argument `recalc_trend_after = TRUE` so that the
trends after correction are also available for plotting. For further
details, refer to the description of
[`plot_runscatter()`](https://slinghub.github.io/MRMhub/reference/plot_runscatter.md).

The LOESS correction only applies to samples that lie within the span of
the QC samples used for smoothing. Extrapolation outside this range is
not recommended, as it can lead to unreliable corrections or artefacts
in the extrapolated regions. However, extrapolation can be activated by
setting `extrapolate = TRUE`. This may be useful in cases where specific
drifts occur in segments of the analysis sequence that are not spanned
by the QC samples, such as when the analysis was interrupted or the
instrument had rapid changes in performance.

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
and the mean absolute CV before and after correction for all samples.
However, these metrics are experimental and should not be used as
definitive criteria for correction (see Details below).

This LOESS method is implemented using the base R function
[`stats::loess()`](https://rdrr.io/r/stats/loess.html).

## Usage

``` r
correct_drift_loess(
  data = NULL,
  variable,
  ref_qc_types,
  span = 0.75,
  degree = 2,
  batch_wise = TRUE,
  ignore_istd = TRUE,
  replace_previous = TRUE,
  conditional_correction = FALSE,
  recalc_trend_after = FALSE,
  log_transform_internal = TRUE,
  feature_list = NULL,
  cv_diff_threshold = 0,
  use_original_if_fail = FALSE,
  extrapolate = FALSE,
  show_progress = TRUE
)
```

## Arguments

- data:

  MRMhubExperiment object

- variable:

  The variable to be corrected for drift effects. Must be one of
  "intensity", "norm_intensity", or "conc"

- ref_qc_types:

  QC types used for drift correction

- span:

  Loess span width (default is 0.75)

- degree:

  Degree of the polynomial to be used in the loess smoothing, normally 1
  (default) or 2

- batch_wise:

  Logical. Apply the correction to each batch separately (`TRUE`,
  default) or across all batches (`FALSE`).

- ignore_istd:

  Do not apply corrections to ISTDs

- replace_previous:

  Logical. Replace existing correction (`TRUE`, default) or layer on top
  of it (`FALSE`).

- conditional_correction:

  Determines whether drift correction should be applied to all features
  unconditionally (`TRUE`) or only when the difference of sample CV
  before vs after smoothing is below the threshold specified by
  `cv_diff_threshold`.

- recalc_trend_after:

  Recalculate trend post-drift correction for `plot_qc_runscatter()`.
  This will double calculation time.

- log_transform_internal:

  Log transform the data for correction when `TRUE` (the default). Note:
  log transformation is solely applied internally for smoothing, results
  will not be be log-transformed. Log transformation may result in more
  robust smoothing that is less sensitive to outlier.

- feature_list:

  Subset the features for correction whose names matches the specified
  text using regular expression. Default is `NULL` which means all
  features are selected.

- cv_diff_threshold:

  This parameter defines the maximum allowable change (difference) in
  the coefficient of variation (CV) ratio of samples before and after
  smoothing for the correction to be applied. A value of 0 (the default)
  requires the CV to improve, while a value above 0 allows the CV to
  also become worse by a maximum of the defined difference.

- use_original_if_fail:

  Determines the action when smoothing fails or results in invalid
  values for a feature. If `FALSE` (default), the result for each
  feature will `NA` for all batches, if `TRUE`, the original data is
  kept.

- extrapolate:

  Extrapolate loess smoothing. WARNING: It is generally not recommended
  to extrapolate outside of the range spanned by the QCs used for
  smoothing. See details below.

- show_progress:

  Logical. Display progress bars if `TRUE`; disable for notebook
  rendering by setting to `FALSE`.

## Value

MRMhubExperiment object

## Details

In the output message, the median CV change is computed as the median of
CV changes for all features in global correction or for features where
the correction passed the defined CV difference treshold in case of
conditional correction (`conditional_correction = FALSE`). For
batch-wise correction, the change is calculated per batch, with the
final median CV change being the median of these batch medians across
features.
