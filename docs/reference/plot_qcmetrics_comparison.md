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
  point_size = 1.5,
  point_alpha = 0.5,
  point_color = "#0460acff",
  point_fill = "#4da2e7ff",
  point_shape = 21,
  point_stroke = 0.5,
  font_base_size = 8
)
```

## Arguments

- data:

  A `MRMhubExperiment` object.

- plot_type:

  A character string specifying the type of plot to generate. Must be
  one of "scatter", "diff", or "ratio". Selecting "scatter" plots the
  "y_variable" against the "y_variable" values as a scatter plot, "diff"
  plots the difference between the two values against the average value,
  and "ratio" plots the log2 ratio of the two values against the average
  value.c

- x_variable:

  The name of the QC metric variable to be plotted on the x-axis.

- y_variable:

  The name of the QC metric variable to be plotted on the y-axis.

- qc_types:

  A character vector specifying the QC types to plot.

- facet_by_class:

  Logical; if `TRUE`, facets the plot by `feature_class`, as defined

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

  Numeric. Base font size (in points) for plot text. Default is 8.

## Value

A `ggplot` object representing the scatter plot.

## Details

The comparison is visualized through one of three plot types:

- Scatter plot: Values of `y_variable` vs `x_variable`

- Difference plot: (`y_variable` - \`x_variable“) vs mean of both values

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
[`plot_normalization_qc()`](https://slinghub.github.io/MRMhub/quant/reference/plot_normalization_qc.md),
[`plot_pca()`](https://slinghub.github.io/MRMhub/quant/reference/plot_pca.md),
[`plot_pca_loading()`](https://slinghub.github.io/MRMhub/quant/reference/plot_pca_loading.md),
[`plot_qc_interferences()`](https://slinghub.github.io/MRMhub/quant/reference/plot_qc_interferences.md),
[`plot_qc_matrixeffects()`](https://slinghub.github.io/MRMhub/quant/reference/plot_qc_matrixeffects.md),
[`plot_qc_summary_byclass()`](https://slinghub.github.io/MRMhub/quant/reference/plot_qc_summary_byclass.md),
[`plot_qc_summary_overall()`](https://slinghub.github.io/MRMhub/quant/reference/plot_qc_summary_overall.md),
[`plot_rla_boxplot()`](https://slinghub.github.io/MRMhub/quant/reference/plot_rla_boxplot.md),
[`plot_rt_vs_chain()`](https://slinghub.github.io/MRMhub/quant/reference/plot_rt_vs_chain.md),
[`plot_runscatter()`](https://slinghub.github.io/MRMhub/quant/reference/plot_runscatter.md),
[`plot_runsequence()`](https://slinghub.github.io/MRMhub/quant/reference/plot_runsequence.md)
