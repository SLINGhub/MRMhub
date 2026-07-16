# PCA plot for quality control

Generates a Principal Component Analysis (PCA) plot for visualizing
samples including quality control (QC) samples. This function provides
options for filtering data, applying transformations, and labelling of
outliers.

Experimental batches can be visualized as ellipses to assess batch
effects.

This function returns a ggplot object. Identified outliers can be
printed to the console.

## Usage

``` r
plot_pca(
  data = NULL,
  variable,
  qc_types = NA,
  ellipse_variable = "qc_type",
  ellipse_levels = NA,
  pca_dims = c(1, 2),
  log_transform = TRUE,
  filter_data = FALSE,
  include_qualifier = FALSE,
  include_istd = FALSE,
  include_feature_filter = NA,
  exclude_feature_filter = NA,
  min_median_value = NA,
  show_labels = TRUE,
  labels_column = "analysis_id",
  labels_threshold_mad = 3,
  shared_labeltext_hide = NA,
  label_font_size = 3,
  point_size = 2,
  point_alpha = 0.8,
  font_base_size = 8,
  ellipse_confidence_level = 0.95,
  ellipse_linewidth = 1,
  ellipse_fill = TRUE,
  ellipse_fillcolor = NA,
  ellipse_alpha = 0.1
)
```

## Arguments

- data:

  A `MRMhubExperiment` object.

- variable:

  A character string indicating the variable to use for PCA analysis.
  Must be one of: "area", "height", "intensity", "norm_intensity",
  "response", "conc", "conc_raw", "rt", "fwhm".

- qc_types:

  A character vector specifying the QC types to plot. It must contain at
  least one element. The default `NA` plots any of the non-blank QC
  types ("SPL", "TQC", "BQC", "HQC", "MQC", "LQC", "NIST", "LTR")
  present in the dataset.

- ellipse_variable:

  String specifying which sample variable to show as ellipses. Must be
  one of: "none", "qc_type", "batch_id". "none" omits ellipses.

- ellipse_levels:

  A character vector specifying the levels of `ellipse_variable` to
  display as ellipses.

- pca_dims:

  A numeric vector of length 2 indicating the PCA dimensions to plot.
  Default is c(1, 2).

- log_transform:

  A logical value indicating whether to log-transform the data before
  the PCA. Default is `TRUE`.

- filter_data:

  A logical value indicating whether to use all data (default) or only
  QC-filtered data (filtered via
  [`filter_features_qc()`](https://slinghub.github.io/MRMhub/quant/reference/filter_features_qc.md)).

- include_qualifier:

  A logical value indicating whether to include qualifier features.
  Default is `TRUE`.

- include_istd:

  A logical value indicating whether to include internal standard (ISTD)
  features. Default is `TRUE`.

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

- show_labels:

  A logical value indicating whether to show analysis_id labels for
  points outside k \* MAD of the selected PCA dimensions. Default is
  `TRUE`.

- labels_column:

  A character string indicating the column to be use for the point
  labels. Typically "analysis_id" or "analysis_order". Default is
  "analysis_id".

- labels_threshold_mad:

  A numeric value determining the threshold for showing labels based on
  the median absolute deviation (MAD). Default is 3. Set to `NULL` to
  suppress labels.

- shared_labeltext_hide:

  A character string representing text shared across labels to be hidden
  (case-sensitive). If this results in non-unique analysis_id's, an
  error will be raised.

- label_font_size:

  Number indicating the font size for labels in 'mm'. Note the unit is
  different from font_base_size that is in 'pt'.

- point_size:

  A numeric value indicating the size of points in millimeters. Default
  is 2.

- point_alpha:

  A numeric value indicating the transparency of points (0-1). Default
  is 0.5.

- font_base_size:

  Numeric. Base font size (in points) for plot text. Default is 8.

- ellipse_confidence_level:

  A numeric value indicating the confidence level for the ellipses.
  Default is 0.95.

- ellipse_linewidth:

  A numeric value indicating the line width of the ellipses. Default is
  1.

- ellipse_fill:

  A logical value indicating whether to fill the ellipses.

- ellipse_fillcolor:

  A vector specifying the fill colors for ellipse corresponding to
  different `ellipse_variable` levels. This can be either an unnamed
  vector or a named vector, with names corresponding to leves in
  `ellipse_variable`. Unused fill colors will be ignored. Default is
  `NA` which corresponds to the default fill colors in case of
  `ellipse_variable = qc_type`, and to automatically generated colors
  otherwise.

- ellipse_alpha:

  A numeric value indicating the transparency of the ellipse fill (0-1).
  Default is 0.3.

## Value

A `ggplot` object with the PCA plot

## See also

Other QC plots:
[`plot_feature_correlations()`](https://slinghub.github.io/MRMhub/quant/reference/plot_feature_correlations.md),
[`plot_normalization_qc()`](https://slinghub.github.io/MRMhub/quant/reference/plot_normalization_qc.md),
[`plot_pca_loading()`](https://slinghub.github.io/MRMhub/quant/reference/plot_pca_loading.md),
[`plot_qc_interferences()`](https://slinghub.github.io/MRMhub/quant/reference/plot_qc_interferences.md),
[`plot_qc_matrixeffects()`](https://slinghub.github.io/MRMhub/quant/reference/plot_qc_matrixeffects.md),
[`plot_qc_summary_byclass()`](https://slinghub.github.io/MRMhub/quant/reference/plot_qc_summary_byclass.md),
[`plot_qc_summary_overall()`](https://slinghub.github.io/MRMhub/quant/reference/plot_qc_summary_overall.md),
[`plot_qcmetrics_comparison()`](https://slinghub.github.io/MRMhub/quant/reference/plot_qcmetrics_comparison.md),
[`plot_rla_boxplot()`](https://slinghub.github.io/MRMhub/quant/reference/plot_rla_boxplot.md),
[`plot_rt_vs_chain()`](https://slinghub.github.io/MRMhub/quant/reference/plot_rt_vs_chain.md),
[`plot_runscatter()`](https://slinghub.github.io/MRMhub/quant/reference/plot_runscatter.md),
[`plot_runsequence()`](https://slinghub.github.io/MRMhub/quant/reference/plot_runsequence.md)
