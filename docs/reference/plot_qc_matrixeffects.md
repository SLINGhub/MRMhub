# Plot standardized feature intensities grouped by QC type

This function creates a grouped beeswarm plot of standardized feature
intensities, where the y-axis represents intensity standardized such
that the mean across all features is 100%. Points are grouped by
`qc_type` and spread using quasirandom jitter.

## Usage

``` r
plot_qc_matrixeffects(
  data,
  variable = "intensity",
  qc_types = c("SPL", "TQC", "PBLK", "BQC"),
  batchwise_normalization = TRUE,
  include_qualifier = FALSE,
  only_istd = TRUE,
  include_feature_filter = NA,
  exclude_feature_filter = NA,
  min_median_value = NA,
  y_lim = c(-NA, NA),
  point_size = 0.5,
  dodge_width = 0.6,
  point_alpha = 0.3,
  box_alpha = 0.3,
  box_linewidth = 0.5,
  font_base_size = 8,
  angle_x = 45
)
```

## Arguments

- data:

  A MRMhubExperiment object

- variable:

  A character string indicating the variable to use for PCA analysis.
  Must be one of: "area", "height", "intensity", "norm_intensity",
  "response", "conc", "conc_raw", "rt", "fwhm".

- qc_types:

  A character vector specifying the QC types to plot. It must contain at
  least one element. The default is `NA`, which means any of the
  non-blank QC types ("SPL", "TQC", "BQC", "HQC", "MQC", "LQC", "NIST",
  "LTR") will be plotted if present in the dataset.

- batchwise_normalization:

  A logical value indicating whether to normalize the signals by batch
  instead of globally.

- include_qualifier:

  A logical value indicating whether to include qualifier features.
  Default is `TRUE`.

- only_istd:

  A logical value indicating whether to include features used as
  internal standards (ISTD). Default is `TRUE`. Set to `FALSE` in
  combination with feature_filter parameters to show other features.

- include_feature_filter:

  A character or regex pattern used to filter features by `feature_id`.
  If `NA` or an empty string (`""`) is provided, the filter is ignored.
  When a vector of length \> 1 is supplied, only features with exactly
  these names are selected (applied individually as OR conditions).

- exclude_feature_filter:

  A character or regex pattern used to exclude features by `feature_id`.
  If `NA` or an empty string (`""`) is provided, the filter is ignored.
  When a vector of length \> 1 is supplied, only features with exactly
  these names are excluded (applied individually as OR conditions).

- min_median_value:

  Minimum median feature value (as determined by the `variable`) across
  all samples from selected QC types that must be met for a feature to
  be included in the PCA analysis. `NA` (default) means no filtering
  will be applied. This parameter provides an fast way to exclude noisy
  features from the analysis. However, it is recommended to use
  `filter_data` with
  [`filter_features_qc()`](https://slinghub.github.io/MRMhub/quant/reference/filter_features_qc.md).

- y_lim:

  A numeric vector of length 2 specifying the y-axis limits.

- point_size:

  A numeric value indicating the size of points in millimeters. Default
  is 2.

- dodge_width:

  Numeric. Width used to dodge overlapping points by `qc_type`. Default
  is `0.6`.

- point_alpha:

  Numeric. Transparency of the plotted points. Default is `0.7`.

- box_alpha:

  Numeric. Transparency of the boxplot. Default is `0.3`.

- box_linewidth:

  Numeric. Width of the boxplot lines. Default is `0.5`.

- font_base_size:

  A numeric value indicating the base font size for plot text elements.
  Default is 8.

- angle_x:

  Numeric. Angle of the x-axis text labels. Default is `45`.

## Value

A `ggplot` object showing the grouped standardized beeswarm plot.
