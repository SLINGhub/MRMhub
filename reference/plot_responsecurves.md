# Plot Response Curves

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

  A `MRMhubExperiment` object containing the dataset and metadata.

- variable:

  The variable to plot on the y-axis.

- filter_data:

  Whether to use all data (default) or only QC-filtered data (filtered
  via
  [`filter_features_qc()`](https://slinghub.github.io/MRMhub/reference/filter_features_qc.md)).

- include_qualifier:

  Logical, whether to include qualifier features. Default is `TRUE`.

- include_istd:

  Logical, whether to include internal standard (ISTD) features. Default
  is `TRUE`.

- include_feature_filter:

  A regex pattern or a vector of feature names used to filter features
  by `feature_id`. If `NA` or an empty string (`""`) is provided, the
  filter is ignored. When a vector of length \> 1 is supplied, is
  supplied, only features with exactly these names are selected (applied
  individually as OR conditions).

- exclude_feature_filter:

  A regex pattern or a vector of feature names to exclude features by
  feature_id. If `NA` or an empty string (`""`) is provided, the filter
  is ignored. When a vector of length \> 1 is supplied, is supplied,
  only features with exactly these names are excluded (applied
  individually as OR conditions).

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

  Logical. If `TRUE`, returns the plots as a list of `ggplot2` objects.

- color_curves:

  A vector of colors for the curves. If `NULL` (default), the colors for
  each curve are generated automatically. If colors are provided, the
  number of colors must match the number of curves.

- point_size:

  Size of points in millimeters.

- line_width:

  Width of regression lines.

- font_base_size:

  Base font size for text. Default is 7.

- rows_page:

  Number of rows of plots per page.

- cols_page:

  Number of columns of plots per page.

- specific_page:

  An integer specifying a specific page to plot. If `NA` (default), all
  pages are plotted.

- page_orientation:

  Orientation of the PDF paper: `"LANDSCAPE"` or `"PORTRAIT"`.

- show_progress:

  Logical. If `TRUE`, displays a progress bar during plot creation.

## Value

If `return_plots` is `TRUE`, a list of `ggplot2` objects is returned.
Otherwise, the function saves the plot output or does not return
anything.

## Details

Features for plotting can be filtered using QC filters defined via
[`filter_features_qc()`](https://slinghub.github.io/MRMhub/reference/filter_features_qc.md)
or through `include_feature_filter` and `exclude_feature_filter`
arguments. The resulting plots offer extensive customization options,
including point size, line width, point color, point fill, point shape,
line color, ribbon fill, and font base size.

Plots will be divided into multiple pages if the number of features
exceeds the product of `rows_page` and `cols_page` settings. The
function supports both direct plotting within R and saving plots as PDF
files. Additionally, plots can be returned as a list of ggplot2 objects
for further manipulation or integration into other analyses.
