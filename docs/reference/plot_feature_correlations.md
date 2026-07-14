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
  rows_page = 4,
  cols_page = 5,
  filter_data = FALSE,
  include_qualifier = FALSE,
  include_istd = FALSE,
  include_feature_filter = NA,
  exclude_feature_filter = NA,
  min_median_value = NA,
  output_pdf = FALSE,
  path = NA,
  specific_page = NA,
  page_orientation = "LANDSCAPE",
  return_plots = FALSE,
  point_size = 1,
  point_alpha = 0.8,
  point_stroke = 0.3,
  line_size = 0.5,
  line_color = "orange",
  line_alpha = 0.5,
  font_base_size = 8,
  show_progress = TRUE
)
```

## Arguments

- data:

  A `MRMhubExperiment` object containing the dataset and metadata.

- variable:

  A character string indicating the variable to use for PCA analysis.
  Must be one of: "area", "height", "intensity", "norm_intensity",
  "response", "conc", "conc_raw", "rt", "fwhm".

- qc_types:

  A character vector specifying the QC types to plot. It must contain at
  least one element. The default is `NA`, which means any of the
  non-blank QC types ("SPL", "TQC", "BQC", "HQC", "MQC", "LQC", "QC",
  "NIST", "LTR") will be plotted if present in the dataset.

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

- rows_page:

  Number of rows of plots per page.

- cols_page:

  Number of columns of plots per page.

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

- output_pdf:

  If `TRUE`, saves the generated plots as a PDF file. When `FALSE`,
  plots are directly plotted.

- path:

  The file path for saving the PDF. Must be defined if `output_pdf` is
  `TRUE`.

- specific_page:

  An integer specifying a specific page to plot. If `NA` (default), all
  pages are plotted.

- page_orientation:

  Orientation of the PDF paper: `"LANDSCAPE"` or `"PORTRAIT"`.

- return_plots:

  Logical. If `TRUE`, returns the plots as a list of `ggplot2` objects.

- point_size:

  A numeric value indicating the size of points in millimeters. Default
  is 1.

- point_alpha:

  A numeric value indicating the transparency of points (0-1). Default
  is 0.8.

- point_stroke:

  A numeric value indicating the stroke width of the points. Default is
  0.3.

- line_size:

  A numeric value indicating the size of the correlation line. Default
  is 0.5.

- line_color:

  A character string indicating the color of the correlation line.
  Default is orange.

- line_alpha:

  A numeric value indicating the transparency of the correlation line
  (0-1). Default is 0.5.

- font_base_size:

  A numeric value indicating the base font size for plot text elements.
  Default is 8.

- show_progress:

  Logical. If `TRUE`, displays a progress bar during plot creation.

## Value

A ggplot object showing scatter plots of highly correlated feature
pairs. Returns NULL if no correlations meet the threshold criteria.
