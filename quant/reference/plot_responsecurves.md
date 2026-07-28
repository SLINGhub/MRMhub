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
  create_dir = TRUE,
  return_plots = FALSE,
  color_curves = NULL,
  point_size = NULL,
  line_width = 0.7,
  label_wrap = FALSE,
  label_wrap_width = 25,
  font_base_size = NULL,
  autoscale = TRUE,
  legend_position = NULL,
  legend_size = NULL,
  show_legend_title = NULL,
  title = NULL,
  strip_text_size = NULL,
  strip_bg_color = NULL,
  rows_page = 4,
  cols_page = 5,
  curve_layout = "overlay",
  fixed_scale_curves = FALSE,
  r2_vstep = 0.06,
  specific_page = NA,
  page_orientation = "LANDSCAPE",
  page_width = NULL,
  page_height = NULL,
  page_units = "mm",
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

  Feature(s) to include by `feature_id`, as a character vector. Each
  element is matched exactly when it names an existing feature,
  otherwise treated as a regex; elements combine with OR. A full ID
  (e.g. `"S1P d18:0 [M>60]"`) needs no escaping, while patterns like
  `"PC|PE"` still work. `NA` or `""` ignores the filter.

- exclude_feature_filter:

  Feature(s) to exclude by `feature_id`, matched the same way as
  `include_feature_filter`. `NA` or `""` ignores the filter.

- max_regression_value:

  The maximum sample_amount (x) value for fitting the regression line.
  If `NA`, regression is based on all data points.

- output_pdf:

  If `TRUE`, saves the generated plots as a PDF file. When `FALSE`,
  plots are directly plotted.

- path:

  The file path for saving the PDF. Must be defined if `output_pdf` is
  `TRUE`.

- create_dir:

  A logical value. If `TRUE` (the default) and `output_pdf` is `TRUE`,
  the parent directory of `path` is created if it does not yet exist.

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

  Numeric. Base font size (in points) for plot text; all plot text
  scales proportionally with this value. `NULL` (default) uses the
  global default set by
  [`mrmhub_set_plot_defaults()`](https://slinghub.github.io/MRMhub/quant/reference/mrmhub_set_plot_defaults.md)
  if one is in effect, otherwise an automatic size (derived from the
  facet-column count on paged plots, or the per-plot default shown in
  the Usage section above).

- autoscale:

  Logical. When `TRUE` (default), `font_base_size` and `point_size` left
  as `NULL` are sized automatically from `cols_page` (more facet columns
  per page give smaller text and points). Any value passed explicitly
  always takes precedence. When `FALSE`, unset sizes fall back to the
  single-plot defaults.

- legend_position:

  Optional legend placement. One of `"right"`, `"left"`, `"top"`,
  `"bottom"`, `"none"`; a corner keyword `"inside-tr"`, `"inside-tl"`,
  `"inside-br"`, `"inside-bl"`; or a numeric `c(x, y)` in `[0, 1]`
  coordinates. `NULL` (default) keeps the current placement, unless a
  global default is set with
  [`mrmhub_set_plot_defaults()`](https://slinghub.github.io/MRMhub/quant/reference/mrmhub_set_plot_defaults.md).

- legend_size:

  Optional single multiplier of `font_base_size` (when `<= 3`) or
  absolute point size (when `> 3`) that scales the whole legend: text,
  title, key and the plotted symbols. `NULL` (default) leaves the legend
  unchanged.

- show_legend_title:

  Logical. `NULL` (default) keeps the legend title, unless a global
  default is set with
  [`mrmhub_set_plot_defaults()`](https://slinghub.github.io/MRMhub/quant/reference/mrmhub_set_plot_defaults.md);
  `FALSE` hides it, `TRUE` forces it shown.

- title:

  Optional plot title. `NULL` (default) or `NA` shows no title; a
  character string is shown as the title.

- strip_text_size:

  Optional facet strip text size, as a multiplier of `font_base_size`
  (when `<= 3`) or an absolute point size (when `> 3`). `NULL` (default)
  inherits from `font_base_size`.

- strip_bg_color:

  Optional facet strip background fill colour. The strip text colour is
  set automatically for contrast (white on a dark fill, black on a light
  one). `NULL` (default) keeps the house dark-navy strips.

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

  Numeric. Vertical step between stacked R² labels when multiple curves
  are plotted in the same panel (`curve_layout = "overlay"`). Default is
  `0.06`. Ignored when `curve_layout` is `"cols"` or `"rows"`, where
  each panel has one curve.

- specific_page:

  An integer specifying a specific page to plot. If `NA` (default), all
  pages are plotted.

- page_orientation:

  Orientation of the PDF paper: `"LANDSCAPE"` or `"PORTRAIT"`. Ignored
  when `page_width` and `page_height` are given.

- page_width, page_height:

  Size of a PDF page, in `page_units`. Both must be given together.
  `NULL` (default) uses an A4 page of 280 x 200 mm, oriented by
  `page_orientation`. When an explicit size is given, `page_orientation`
  has no effect.

- page_units:

  Unit of `page_width` and `page_height`: `"mm"` (default), `"cm"`,
  `"in"` or `"pt"`.

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

## Preferred formats and devices

|  |  |  |  |
|----|----|----|----|
| Purpose | Format | Device used | Typical `dpi` |
| Journal figure, vector (default choice) | `"pdf"` | [`grDevices::cairo_pdf`](https://rdrr.io/r/grDevices/cairo.html), else [`grDevices::pdf`](https://rdrr.io/r/grDevices/pdf.html) | n/a |
| Figure for further editing (Illustrator, Inkscape) | `"svg"` | [`svglite::svglite`](https://svglite.r-lib.org/reference/svglite.html), else [`grDevices::svg`](https://rdrr.io/r/grDevices/cairo.html) | n/a |
| Slides, Quarto HTML, GitHub | `"png"` | [`ragg::agg_png`](https://ragg.r-lib.org/reference/agg_png.html), else [`grDevices::png`](https://rdrr.io/r/grDevices/png.html) | 150-300 |
| Journal requiring raster submission | `"tiff"` | [`ragg::agg_tiff`](https://ragg.r-lib.org/reference/agg_tiff.html), else [`grDevices::tiff`](https://rdrr.io/r/grDevices/png.html) | 300-600 |

Prefer a **vector** format (`pdf`, `svg`) for publication: text stays
selectable and searchable, and lines stay sharp at any magnification.

Prefer a **raster** format (`png`, `tiff`) when a plot draws very many
marks – a
[`plot_runscatter()`](https://slinghub.github.io/MRMhub/quant/reference/plot_runscatter.md)
page covering several thousand analyses, or a dense
[`plot_pca()`](https://slinghub.github.io/MRMhub/quant/reference/plot_pca.md)
score plot. Every point becomes a separate object in a PDF, so such
figures produce very large files that are slow to open and to typeset.
Saving them at 300-600 dpi instead keeps the file small with no visible
loss.

The optional packages `ragg` and `svglite` are used automatically when
installed, giving better text rendering, system-font support and smaller
SVG files. When they are absent the equivalent `grDevices` device is
used and the output is still correct. Installing both is recommended:
`install.packages(c("ragg", "svglite"))`.

PDF output uses the cairo device wherever R was built with cairo support
(`capabilities("cairo")`), because plain
[`grDevices::pdf()`](https://rdrr.io/r/grDevices/pdf.html) writes text
in a single-byte encoding and silently transliterates anything outside
it – an en dash becomes `-`, `>=` replaces the proper symbol. Unit
labels such as `umol/L` and statistical annotations routinely depend on
those glyphs.

Multi-page output from the paged plot functions
([`plot_runscatter()`](https://slinghub.github.io/MRMhub/quant/reference/plot_runscatter.md),
[`plot_calibrationcurves()`](https://slinghub.github.io/MRMhub/quant/reference/plot_calibrationcurves.md),
`plot_responsecurves()`,
[`plot_feature_correlations()`](https://slinghub.github.io/MRMhub/quant/reference/plot_feature_correlations.md))
is PDF only, which is the only format that holds many pages in one file.
Use
[`save_plot()`](https://slinghub.github.io/MRMhub/quant/reference/save_plot.md)
for single figures in any of the other formats.

## See also

[`save_plot()`](https://slinghub.github.io/MRMhub/quant/reference/save_plot.md)
to save a single figure in any format.

Other calibration plots:
[`plot_calibrationcurves()`](https://slinghub.github.io/MRMhub/quant/reference/plot_calibrationcurves.md)
