# Drift correction by Gaussian kernel smoothing

Performs drift correction for run-order effects within or across batches
using Gaussian kernel smoothing, as detailed in Teo et al. (2020). The
Gaussian kernel estimates the local data trend, with bandwidth defined
by the `kernel_size` parameter. This smoothing approach is mostly used
with study samples and should only be applied to datasets with
sufficiently randomized or stratified samples to avoid local biases and
artifacts. The smoothing can be applied to `concentration`,
`norm_intensity`, and `intensity` data.

Corrections can be applied on a batch-by-batch basis
(`batch_wise = TRUE`, default) or across all batches
(`batch_wise = FALSE`). The correction can either replace existing drift
or batch corrections (`replace_previous = TRUE`, default) or applied on
top of existing corrections (`replace_previous = FALSE`).

Drift correction can be applied to all features
(`conditional_correction = FALSE`) or conditionally, based on whether
the sample CV difference before and after correction is below a defined
threshold (`cv_diff_threshold`). The conditional correction is applied
separately for each batch if `batch_wise = TRUE`.

It is recommended to visually inspect the correction using the
[`plot_runscatter()`](https://slinghub.github.io/MRMhub/quant/reference/plot_runscatter.md)
function. Set the argument `recalc_trend_after = TRUE` so that the
trends after correction are also available for plotting. For further
details, refer to the description of
[`plot_runscatter()`](https://slinghub.github.io/MRMhub/quant/reference/plot_runscatter.md).
This will double the processing time.

**Note**: The function outputs a message indicating the median CV change
and the median absolute CV before and after correction for all samples.
However, these metrics are experimental and should not be used as
definitive criteria for correction (see Details below).

## Usage

``` r
correct_drift_gaussiankernel(
  data = NULL,
  variable,
  ref_qc_types,
  batch_wise = TRUE,
  ignore_istd = TRUE,
  replace_previous = TRUE,
  kernel_size = 10,
  outlier_filter = FALSE,
  outlier_ksd = 5,
  location_smooth = TRUE,
  scale_smooth = FALSE,
  log_transform_internal = TRUE,
  conditional_correction = FALSE,
  cv_diff_threshold = 0,
  recalc_trend_after = FALSE,
  feature_list = NULL,
  use_original_if_fail = FALSE,
  show_progress = TRUE
)
```

## Arguments

- data:

  A
  [`MRMhubExperiment`](https://slinghub.github.io/MRMhub/quant/reference/MRMhubExperiment-class.md)
  object.

- variable:

  The target variable for drift correction; options include "intensity",
  "norm_intensity", or "conc".

- ref_qc_types:

  QC types used for drift correction, typically including study samples
  (`SPL`).

- batch_wise:

  Logical. Apply the correction to each batch separately (`TRUE`,
  default) or across all batches (`FALSE`).

- ignore_istd:

  Logical. Exclude internal standards (ISTDs) from correction if `TRUE`.

- replace_previous:

  Logical. Replace existing correction (`TRUE`, default) or layer on top
  of it (`FALSE`).

- kernel_size:

  Numeric. Defines the Gaussian kernel's bandwidth.

- outlier_filter:

  Logical. Enable kernel outlier filtering if `TRUE`.

- outlier_ksd:

  Numeric. Set the kernel's k times standard deviation for outlier
  detection.

- location_smooth:

  Logical. Apply smoothing to the location parameter if `TRUE`.

- scale_smooth:

  Logical. Apply smoothing to the scale parameter if `TRUE`.

- log_transform_internal:

  Logical. Conduct log transformation internally for enhanced outlier
  robustness if `TRUE` (default); does not alter the output data.

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

- recalc_trend_after:

  Logical. Recalculate trends post-smoothing for visualization (e.g.,
  [`plot_runscatter()`](https://slinghub.github.io/MRMhub/quant/reference/plot_runscatter.md)).

- feature_list:

  Character vector. Regular expression pattern to select specific
  features for correction. Default is `NULL` for all features.

- use_original_if_fail:

  Determines the action when smoothing fails or results in invalid
  values for a feature. If `FALSE` (default), the result for each
  feature will be `NA` for all batches, if `TRUE`, the original data is
  kept.

- show_progress:

  Logical. Display progress bars if `TRUE`; disable for notebook
  rendering by setting to `FALSE`.

## Value

Returns a
[`MRMhubExperiment`](https://slinghub.github.io/MRMhub/quant/reference/MRMhubExperiment-class.md)
object.

## Details

In the output message, the median CV change is computed as the median of
CV changes for all features in global correction or for features where
the correction passed the defined CV difference threshold in case of
conditional correction (`conditional_correction = TRUE`). For batch-wise
correction, the change is calculated per batch, with the final median CV
change being the median of these batch medians across features.

## References

Teo G., Chew WS, Burla B, Herr D, Tai ES, Wenk MR, Torta F, & Choi H
(2020). MRMkit: Automated Data Processing for Large-Scale Targeted
Metabolomics Analysis. *Analytical Chemistry*, 92(20), 13677–13682.
<https://doi.org/10.1021/acs.analchem.0c03060>
