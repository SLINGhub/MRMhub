# Comparison of two feature QC metrics variables

This function generates scatter plots comparing two QC metrics variables
across feature classes. A list of available QC metrics is available from
the
[`calc_qc_metrics()`](https://slinghub.github.io/MRMhub/quant/reference/calc_qc_metrics.md)
documentation.

## Usage

``` r
plot_qcmetrics_comparison(
  data = NULL,
  plot_type,
  x_variable,
  y_variable,
  qc_types = NA,
  facet_by_class = FALSE,
  y_shared = FALSE,
  filter_data = FALSE,
  include_qualifier = FALSE,
  equality_line = FALSE,
  threshold_values = NA_real_,
  log_scale = FALSE,
  x_lim = c(NA_real_, NA_real_),
  y_lim = c(NA_real_, NA_real_),
  cols_page = 5,
  point_size = NULL,
  point_alpha = 0.5,
  point_color = "#0460acff",
  point_fill = "#4da2e7ff",
  point_shape = 21,
  point_stroke = 0.5,
  font_base_size = NULL,
  autoscale = TRUE,
  legend_position = NULL,
  legend_size = NULL,
  show_legend_title = NULL,
  title = NULL,
  strip_text_size = NULL,
  strip_bg_color = NULL,
  legend_bg_alpha = NULL
)
```

## Arguments

- data:

  A `MRMhubExperiment` object.

- plot_type:

  A character string specifying the type of plot to generate. Must be
  one of "scatter", "diff", or "ratio". Selecting "scatter" plots the
  "y_variable" against the "x_variable" values as a scatter plot, "diff"
  plots the difference between the two values against the average value,
  and "ratio" plots the log2 ratio of the two values against the average
  value.

- x_variable:

  The name of the QC metric variable to be plotted on the x-axis.

- y_variable:

  The name of the QC metric variable to be plotted on the y-axis.

- qc_types:

  A character vector specifying the QC types to plot.

- facet_by_class:

  Logical; if `TRUE`, facets the plot by `feature_class`, as defined in
  the feature metadata.

- y_shared:

  Logical; if `TRUE`, all facets share the same y-axis scale. If `FALSE`
  (default), each facet has its own y-axis scale.

- filter_data:

  Logical; whether to use all data (default) or only QC-filtered data
  (filtered via
  [`filter_features_qc()`](https://slinghub.github.io/MRMhub/quant/reference/filter_features_qc.md)).

- include_qualifier:

  Logical; whether to include qualifier features (default is `TRUE`).

- equality_line:

  Logical; whether to show a line indicating identical values in both
  compared variables (default is `FALSE`).

- threshold_values:

  Numeric single value or vector with 2 elements; threshold valus to be
  shown as dashed lines from both axes on the plot (default is `NA`).

- log_scale:

  Logical, whether to use a log10 scale the axes.

- x_lim:

  Numeric vector of length 2 for x-axis limits. Use `NA` for
  auto-scaling (default is `c(0, NA)`).

- y_lim:

  Numeric vector of length 2 for y-axis limits. Use `NA` for
  auto-scaling (default is `c(0, NA)`).

- cols_page:

  Integer; number of facet columns per page (default is `5`).

- point_size:

  Numeric; size of points in millimeters (default is `1`).

- point_alpha:

  Numeric; transparency of points (default is `0.5`).

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

- point_stroke:

  Numeric; thickness of point borders (default is `0.5`).

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

- legend_bg_alpha:

  Optional opacity (`[0, 1]`) of a white legend background box, useful
  for a readable inside legend drawn over points. `NULL` (default)
  leaves the legend background unchanged.

## Value

A `ggplot` object representing the scatter plot.

## Details

The comparison is visualized through one of three plot types:

- Scatter plot: Values of `y_variable` vs `x_variable`

- Difference plot: (`y_variable` - `x_variable`) vs mean of both values

- Ratio plot: log2(`y_variable` / `x_variable`) vs mean of both values

&nbsp;

- `x_variable` and `y_variable` must be available in the QC metrics
  table. Please refer to the help page of
  [`calc_qc_metrics()`](https://slinghub.github.io/MRMhub/quant/reference/calc_qc_metrics.md)
  for more information on the available QC metric variables.

- When `facet_by_class = TRUE`, then the `feature_class` must be defined
  in the metadata or retrieved via specific functions, e.g.,
  [`parse_lipid_feature_names()`](https://slinghub.github.io/MRMhub/quant/reference/parse_lipid_feature_names.md).

## See also

[`calc_qc_metrics()`](https://slinghub.github.io/MRMhub/quant/reference/calc_qc_metrics.md),
[`filter_features_qc()`](https://slinghub.github.io/MRMhub/quant/reference/filter_features_qc.md),
[`plot_normalization_qc()`](https://slinghub.github.io/MRMhub/quant/reference/plot_normalization_qc.md),
[`normalize_by_istd()`](https://slinghub.github.io/MRMhub/quant/reference/normalize_by_istd.md)

Other QC plots:
[`plot_feature_correlations()`](https://slinghub.github.io/MRMhub/quant/reference/plot_feature_correlations.md),
[`plot_interference_correction()`](https://slinghub.github.io/MRMhub/quant/reference/plot_interference_correction.md),
[`plot_matrixeffects()`](https://slinghub.github.io/MRMhub/quant/reference/plot_matrixeffects.md),
[`plot_normalization_qc()`](https://slinghub.github.io/MRMhub/quant/reference/plot_normalization_qc.md),
[`plot_pca()`](https://slinghub.github.io/MRMhub/quant/reference/plot_pca.md),
[`plot_pca_loading()`](https://slinghub.github.io/MRMhub/quant/reference/plot_pca_loading.md),
[`plot_qc_interference_impact()`](https://slinghub.github.io/MRMhub/quant/reference/plot_qc_interference_impact.md),
[`plot_qc_summary_byclass()`](https://slinghub.github.io/MRMhub/quant/reference/plot_qc_summary_byclass.md),
[`plot_qc_summary_overall()`](https://slinghub.github.io/MRMhub/quant/reference/plot_qc_summary_overall.md),
[`plot_rla_boxplot()`](https://slinghub.github.io/MRMhub/quant/reference/plot_rla_boxplot.md),
[`plot_rt_vs_chain()`](https://slinghub.github.io/MRMhub/quant/reference/plot_rt_vs_chain.md),
[`plot_runscatter()`](https://slinghub.github.io/MRMhub/quant/reference/plot_runscatter.md),
[`plot_runsequence()`](https://slinghub.github.io/MRMhub/quant/reference/plot_runsequence.md)
