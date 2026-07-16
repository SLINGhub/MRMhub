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

  A `MRMhubExperiment` object.

- variable:

  A character string indicating the signal variable to plot. Must be one
  of: "area", "height", "intensity", "norm_intensity", "response",
  "conc", "conc_raw", "rt", "fwhm".

- qc_types:

  A character vector specifying the QC types to plot. It must contain at
  least one element. The default `NA` plots any of the non-blank QC
  types ("SPL", "TQC", "BQC", "HQC", "MQC", "LQC", "NIST", "LTR")
  present in the dataset.

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

  A regex pattern or a vector of feature names used to filter features
  by `feature_id`. If `NA` or an empty string (`""`) is provided, the
  filter is ignored. When a vector of length \> 1 is supplied, only
  features with exactly these names are selected (applied individually
  as OR conditions).

- exclude_feature_filter:

  A regex pattern or a vector of feature names used to exclude features
  by `feature_id`. If `NA` or an empty string (`""`) is provided, the
  filter is ignored. When a vector of length \> 1 is supplied, only
  features with exactly these names are excluded (applied individually
  as OR conditions).

- min_median_value:

  Minimum median feature value across the selected QC-type samples
  required for a feature to be included. `NA` (default) applies no
  filtering. This is a fast way to exclude noisy features; for
  principled QC-based filtering use
  [`filter_features_qc()`](https://slinghub.github.io/MRMhub/quant/reference/filter_features_qc.md).

- y_lim:

  A numeric vector of length 2 specifying the y-axis limits.

- point_size:

  A numeric value indicating the size of points in millimeters. Default
  is `0.5`.

- dodge_width:

  Numeric. Width used to dodge overlapping points by `qc_type`. Default
  is `0.6`.

- point_alpha:

  Numeric. Transparency of the plotted points. Default is `0.3`.

- box_alpha:

  Numeric. Transparency of the boxplot. Default is `0.3`.

- box_linewidth:

  Numeric. Width of the boxplot lines. Default is `0.5`.

- font_base_size:

  Numeric. Base font size (in points) for plot text. Default is 8.

- angle_x:

  Numeric. Angle of the x-axis text labels. Default is `45`.

## Value

A `ggplot` object showing the grouped standardized beeswarm plot.

## See also

Other QC plots:
[`plot_feature_correlations()`](https://slinghub.github.io/MRMhub/quant/reference/plot_feature_correlations.md),
[`plot_normalization_qc()`](https://slinghub.github.io/MRMhub/quant/reference/plot_normalization_qc.md),
[`plot_pca()`](https://slinghub.github.io/MRMhub/quant/reference/plot_pca.md),
[`plot_pca_loading()`](https://slinghub.github.io/MRMhub/quant/reference/plot_pca_loading.md),
[`plot_qc_interferences()`](https://slinghub.github.io/MRMhub/quant/reference/plot_qc_interferences.md),
[`plot_qc_summary_byclass()`](https://slinghub.github.io/MRMhub/quant/reference/plot_qc_summary_byclass.md),
[`plot_qc_summary_overall()`](https://slinghub.github.io/MRMhub/quant/reference/plot_qc_summary_overall.md),
[`plot_qcmetrics_comparison()`](https://slinghub.github.io/MRMhub/quant/reference/plot_qcmetrics_comparison.md),
[`plot_rla_boxplot()`](https://slinghub.github.io/MRMhub/quant/reference/plot_rla_boxplot.md),
[`plot_rt_vs_chain()`](https://slinghub.github.io/MRMhub/quant/reference/plot_rt_vs_chain.md),
[`plot_runscatter()`](https://slinghub.github.io/MRMhub/quant/reference/plot_runscatter.md),
[`plot_runsequence()`](https://slinghub.github.io/MRMhub/quant/reference/plot_runsequence.md)
