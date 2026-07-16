# Plot response curves

This function plots response curves for each feature. Multiple response
curves, each with a linear regression line, can be plotted on the same
graph. Each feature is displayed as a separate facet.

## Usage

``` r
plot_responsecurves(
  data = NULL,
  variable = "intensity",
  filter_data = FALSE,
  include_qualifier = TRUE,
  include_istd = TRUE,
  include_feature_filter = NA,
  exclude_feature_filter = NA,
  max_regression_value = NA,
  output_pdf = FALSE,
  path = NA,
  return_plots = FALSE,
  color_curves = NULL,
  point_size = 1.5,
  line_width = 0.7,
  label_wrap = FALSE,
  label_wrap_width = 25,
  font_base_size = 8,
  rows_page = 4,
  cols_page = 5,
  curve_layout = "overlay",
  fixed_scale_curves = FALSE,
  r2_vstep = 0.06,
  specific_page = NA,
  page_orientation = "LANDSCAPE",
  show_progress = TRUE
)
```

## Arguments

- data:

  A `MRMhubExperiment` object.

- variable:

  The variable to plot on the y-axis.

- filter_data:

  Whether to use all data (default) or only QC-filtered data (filtered
  via
  [`filter_features_qc()`](https://slinghub.github.io/MRMhub/quant/reference/filter_features_qc.md)).

- include_qualifier:

  Logical, whether to include qualifier features. Default is `TRUE`.

- include_istd:

  Logical, whether to include internal standard (ISTD) features. Default
  is `TRUE`.

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

- max_regression_value:

  The maximum sample_amount (x) value for fitting the regression line.
  If `NA`, regression is based on all data points.

- output_pdf:

  If `TRUE`, saves the generated plots as a PDF file. When `FALSE`,
  plots are directly plotted.

- path:

  The file path for saving the PDF. Must be defined if `output_pdf` is
  `TRUE`.

- return_plots:

  Logical. If `TRUE`, returns the plots as a list of `ggplot` objects.

- color_curves:

  A vector of colors for the curves. If `NULL` (default), the colors for
  each curve are generated automatically. If colors are provided, the
  number of colors must match the number of curves.

- point_size:

  Size of points in millimeters.

- line_width:

  Width of regression lines.

- label_wrap:

  Logical. If `TRUE`, long `feature_id` labels are wrapped to multiple
  lines using `label_wrap_width`. Default is `FALSE`.

- label_wrap_width:

  Integer. Maximum width in characters for wrapped labels when
  `label_wrap = TRUE`. Default is `25`. Ignored when
  `label_wrap = FALSE`.

- font_base_size:

  Numeric. Base font size (in points) for plot text. Default is 8.

- rows_page:

  Number of rows of plots per page. Used for pagination in
  `curve_layout = "overlay"` and `"cols"`. Ignored in
  `curve_layout = "rows"`.

- cols_page:

  Number of columns of plots per page. Used for pagination in
  `curve_layout = "overlay"` and `"rows"`. Ignored in
  `curve_layout = "cols"`.

- curve_layout:

  Controls how multiple curves are displayed. One of:

  `"overlay"`

  :   (default) All curves overlaid in each feature panel using
      `facet_wrap2`. Pagination uses `rows_page * cols_page`.

  `"cols"`

  :   Grid layout with features as rows and curves as columns using
      `facet_grid2`. Pagination uses `rows_page` only.

  `"rows"`

  :   Grid layout with curves as rows and features as columns using
      `facet_grid2`. Pagination uses `cols_page` only.

- fixed_scale_curves:

  Logical. If `TRUE`, fixes the y-axis scale per feature row
  (`curve_layout = "cols"`) or per curve row (`curve_layout = "rows"`).
  If `FALSE` (default), each panel auto-scales. Silently ignored when
  `curve_layout = "overlay"`.

- r2_vstep:

  Numeric. Vertical step between stacked R-squared labels when multiple
  curves are plotted in the same panel (`curve_layout = "overlay"`).
  Default is `0.06`. Ignored when `curve_layout` is `"cols"` or
  `"rows"`, where each panel has one curve.

- specific_page:

  An integer specifying a specific page to plot. If `NA` (default), all
  pages are plotted.

- page_orientation:

  Orientation of the PDF paper: `"LANDSCAPE"` or `"PORTRAIT"`.

- show_progress:

  Logical. If `TRUE`, displays a progress bar during plot creation.

## Value

If `return_plots` is `TRUE`, a list of `ggplot` objects is returned.
Otherwise, the function saves the plot output or does not return
anything.

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

## See also

Other calibration plots:
[`plot_calibrationcurves()`](https://slinghub.github.io/MRMhub/quant/reference/plot_calibrationcurves.md)
