# Plot calibration curves

This function plots calibration curves of each feature where defined and
displays QC samples with defined concentrations within the plot. Users
can select a regression model (`linear` or `quadratic`) and apply
weighting (`none`, `"1/x"`, or `"1/x^2"`), either through function
arguments or feature metadata.

## Usage

``` r
plot_calibrationcurves(
  data = NULL,
  variable = "norm_intensity",
  qc_types = NA,
  fit_overwrite,
  fit_model = c("linear", "quadratic"),
  fit_weighting = c(NA, "none", "1/x", "1/x^2"),
  ci_show = NA,
  ci_clip = TRUE,
  zoom_n_points = NA,
  log_axes = FALSE,
  filter_data = FALSE,
  include_qualifier = TRUE,
  include_istd = FALSE,
  include_feature_filter = NA,
  exclude_feature_filter = NA,
  output_pdf = FALSE,
  path = NA,
  return_plots = FALSE,
  point_size = 1.5,
  line_width = 0.7,
  point_color = NA,
  point_fill = NA,
  point_shape = NA,
  line_color = "#4575b4",
  ribbon_fill = "#e6f6ff",
  font_base_size = 7,
  rows_page = 4,
  cols_page = 5,
  specific_page = NA,
  page_orientation = "LANDSCAPE",
  show_progress = TRUE
)
```

## Arguments

- data:

  A `MRMhubExperiment` object containing the dataset.

- variable:

  Variable to plot on the y-axis, usually intensity. Default is
  `"intensity"`.

- qc_types:

  A character vector specifying the QC types to plot. It must contain at
  least `CAL`, which represents calibration curve samples. Other QC
  types will be plotted as points when they have assigned concentrations
  (see QC-concentration metadata). These QC types need to be present in
  the data and defined in the analysis metadata. The default is `NA`,
  which means any of the QC types "CAL", "HQC", "MQC", "LQC", "EQA",
  "QC", will be plotted if present and have assigned concentrations.

- fit_overwrite:

  If `TRUE`, the function will use the provided `fit_model` and
  `fit_weighting` values for all analytes and ignore any fit method and
  weighting settings defined in the metadata .

- fit_model:

  A character string specifying the default regression fit method to use
  for the calibration curve. Must be one of `"linear"` or `"quadratic"`.
  This method will be applied if no specific fit method is defined for a
  feature in the metadata, or when `fit_overwrite = TRUE`.

- fit_weighting:

  A character string specifying the default weighting method for the
  regression points in the calibration curve. Must be one of `"none"`,
  `"1/x"`, or `"1/x^2"`. This method will be applied if no specific
  weighting method is defined for a feature in the metadata, or when
  `fit_overwrite = TRUE`.

- ci_show:

  Logical, if `TRUE`, displays the confidence interval as ribbon.
  Default is `NA`, in which case confidence intervals are plotted in a
  linear scale and ommitted in log-log scale.

- ci_clip:

  Logical, if `TRUE`, clips the confidence interval above or below the
  highest and lowest data point, respectively.

- zoom_n_points:

  Number of x lowest concentration points to display, used for zooming.
  Set to `NULL` or `NA` (default) to show all points.

- log_axes:

  Logical. Determines whether the x and y axes are displayed in a
  logarithmic scale (log-log scale). Set to `TRUE` to enable logarithmic
  scaling; otherwise, set to `FALSE` for a linear scale. Note: If
  `TRUE`, any regression curves or standard error regions with negative
  values will be omitted from display. equimolar response of spiked-in
  non-labelled and labelled standards. At a normalized intensity of 1,
  assuming an equimolar response, both types of standards are present at
  equal concentrations.

- filter_data:

  Logical, if `TRUE`, uses QC filtered data; otherwise uses raw data.
  Default is `FALSE`.

- include_qualifier:

  Logical, whether to include qualifier features. Default is `TRUE`.

- include_istd:

  Logical, whether to include internal standard (ISTD) features. Default
  is `TRUE`.

- include_feature_filter:

  Regex pattern to include features. If omitted, considers all features.

- exclude_feature_filter:

  Regex pattern to exclude features. If omitted, excludes none.

- output_pdf:

  Logical, if `TRUE`, saves plots as a PDF file. Default is `FALSE`.

- path:

  File path for saving the PDF. Default is an empty string.

- return_plots:

  Logical, if `TRUE`, returns plots as a list of ggplot2 objects.
  Default is `FALSE`.

- point_size:

  Size of points in the plot. Default is 1.5.

- line_width:

  Width of regression lines. Default is 0.7.

- point_color:

  A vector specifying the colors for points corresponding to different
  QC types. This can be either an unnamed vector or a named vector, with
  names corresponding to QC types. Unused colors will be ignored.
  Default is `NA` which corresponds to the default colors for QC types
  defined in the package.

- point_fill:

  A vector specifying the fill colors for points corresponding to
  different QC types. This can be either an unnamed vector or a named
  vector, with names corresponding to QC types. Unused fill colors will
  be ignored. Default is `NA` which corresponds to the default fill
  colors for QC types defined in the package.

- point_shape:

  A vector specifying the shapes for points corresponding to different
  QC types. This can be either an unnamed vector or a named vector, with
  names corresponding to QC types. Unused shapes will be ignored.
  Default is `NA` which corresponds to the default shapes for QC types
  defined in the package.

- line_color:

  Color of the regression line. Default is `"#4575b4"`.

- ribbon_fill:

  Color for the confidence interval ribbon. Default is `"#91bfdb40"`.

- font_base_size:

  Base font size for text in plots. Default is 7.

- rows_page:

  Number of plot rows. Default is 4.

- cols_page:

  Number of plot columns. Default is 5.

- specific_page:

  Show/save a specific page number only. `NA` plots/saves all pages.

- page_orientation:

  Orientation of PDF, either `"LANDSCAPE"` or `"PORTRAIT"`. Default is
  `"LANDSCAPE"`.

- show_progress:

  Logical. If `TRUE`, displays a progress bar during plot creation.

## Details

Features for plotting can be filtered using QC filters defined via
[`filter_features_qc()`](https://slinghub.github.io/MRMhub/quant/reference/filter_features_qc.md)
or through `include_feature_filter` and `exclude_feature_filter`
arguments. The resulting plots offer extensive customization options,
including point size, line width, point color, point fill, point shape,
line color, ribbon fill, and font base size.

Plots will be divided into multiple pages if the number of features
exceeds the product of `rows_page` and `cols_page` settings. The
function supports both direct plotting within R and saving plots as PDF
files. Additionally, plots can be returned as a list of ggplot2 objects
for further manipulation or integration into other analyses.
