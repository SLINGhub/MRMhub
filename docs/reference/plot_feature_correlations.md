# Plot highly correlated feature pairs

Creates scatter plots for pairs of features that have correlations
outside specified thresholds. Each pair is displayed in a separate facet
with its correlation coefficient.

This plot can be used to visually inspect highly correlated features,
that may represent duplicate identifications or represent isomers.

## Usage

``` r
plot_feature_correlations(
  data,
  variable,
  qc_types = NA,
  cor_min,
  cor_min_neg = -0.99,
  log_scale = FALSE,
  sort_by_corr = TRUE,
  filter_data = FALSE,
  include_qualifier = FALSE,
  include_istd = FALSE,
  include_feature_filter = NA,
  exclude_feature_filter = NA,
  min_median_value = NA,
  output_pdf = FALSE,
  path = NA,
  return_plots = FALSE,
  rows_page = 4,
  cols_page = 5,
  specific_page = NA,
  page_orientation = "LANDSCAPE",
  point_size = 1,
  point_alpha = 0.8,
  point_stroke = 0.3,
  line_width = 0.5,
  line_color = "orange",
  line_alpha = 0.5,
  font_base_size = 8,
  show_progress = TRUE
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

- cor_min:

  Numeric. Minimum correlation threshold. Only feature pairs with
  positive correlations above this value will be shown. Set to Inf to
  exclude positive corrections.

- cor_min_neg:

  Numeric. Minimum nagative correlation threshold. Only feature pairs
  with negative correlations above this value will be shown. Set to -Inf
  to exclude nagative corrections.

- log_scale:

  A logical value indicating whether to use a log10 scale for both axes.
  Default is `FALSE`.

- sort_by_corr:

  A logical value indicating whether to sort the features in the plot by
  correlation or alphabetically by feature ID. Default is `TRUE`.

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

- output_pdf:

  If `TRUE`, saves the generated plots as a PDF file. When `FALSE`,
  plots are directly plotted.

- path:

  The file path for saving the PDF. Must be defined if `output_pdf` is
  `TRUE`.

- return_plots:

  Logical. If `TRUE`, returns the plots as a list of `ggplot` objects.

- rows_page:

  Number of rows of plots per page.

- cols_page:

  Number of columns of plots per page.

- specific_page:

  An integer specifying a specific page to plot. If `NA` (default), all
  pages are plotted.

- page_orientation:

  Orientation of the PDF paper: `"LANDSCAPE"` or `"PORTRAIT"`.

- point_size:

  A numeric value indicating the size of points in millimeters. Default
  is 1.

- point_alpha:

  A numeric value indicating the transparency of points (0-1). Default
  is 0.8.

- point_stroke:

  A numeric value indicating the stroke width of the points. Default is
  0.3.

- line_width:

  A numeric value indicating the size of the correlation line. Default
  is 0.5.

- line_color:

  A character string indicating the color of the correlation line.
  Default is orange.

- line_alpha:

  A numeric value indicating the transparency of the correlation line
  (0-1). Default is 0.5.

- font_base_size:

  Numeric. Base font size (in points) for plot text. Default is 8.

- show_progress:

  Logical. If `TRUE`, displays a progress bar during plot creation.

## Value

A `ggplot` object showing scatter plots of highly correlated feature
pairs. Returns `NULL` if no correlations meet the threshold criteria.

## See also

Other QC plots:
[`plot_normalization_qc()`](https://slinghub.github.io/MRMhub/quant/reference/plot_normalization_qc.md),
[`plot_pca()`](https://slinghub.github.io/MRMhub/quant/reference/plot_pca.md),
[`plot_pca_loading()`](https://slinghub.github.io/MRMhub/quant/reference/plot_pca_loading.md),
[`plot_qc_interference_impact()`](https://slinghub.github.io/MRMhub/quant/reference/plot_qc_interference_impact.md),
[`plot_qc_interferences()`](https://slinghub.github.io/MRMhub/quant/reference/plot_qc_interferences.md),
[`plot_qc_matrixeffects()`](https://slinghub.github.io/MRMhub/quant/reference/plot_qc_matrixeffects.md),
[`plot_qc_summary_byclass()`](https://slinghub.github.io/MRMhub/quant/reference/plot_qc_summary_byclass.md),
[`plot_qc_summary_overall()`](https://slinghub.github.io/MRMhub/quant/reference/plot_qc_summary_overall.md),
[`plot_qcmetrics_comparison()`](https://slinghub.github.io/MRMhub/quant/reference/plot_qcmetrics_comparison.md),
[`plot_rla_boxplot()`](https://slinghub.github.io/MRMhub/quant/reference/plot_rla_boxplot.md),
[`plot_rt_vs_chain()`](https://slinghub.github.io/MRMhub/quant/reference/plot_rt_vs_chain.md),
[`plot_runscatter()`](https://slinghub.github.io/MRMhub/quant/reference/plot_runscatter.md),
[`plot_runsequence()`](https://slinghub.github.io/MRMhub/quant/reference/plot_runsequence.md)
