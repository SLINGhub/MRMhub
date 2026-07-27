# Compare feature variability before and after normalization

Evaluates the effectiveness of normalization by comparing feature
variability (measured as %CV) in QC and/or study samples before and
after normalization. The comparison is visualized through one of three
plot types:

- Scatter plot: CV values before vs after normalization

- Difference plot: (CV after - CV before) vs mean CV

- Ratio plot: log2 of (CV after / CV before) vs mean CV

Features can be grouped and visualized by their feature class using
facets.

The resulting visualization helps assess whether normalization improved
measurement precision across different features and sample/QC types.

## Usage

``` r
plot_normalization_qc(
  data = NULL,
  before_norm_var,
  after_norm_var,
  plot_type,
  qc_types = NA,
  facet_by_class = FALSE,
  y_shared = FALSE,
  filter_data = FALSE,
  include_qualifier = FALSE,
  cv_threshold_value = 25,
  x_lim = c(NA_real_, NA_real_),
  y_lim = c(NA_real_, NA_real_),
  cols_page = 5,
  point_size = NULL,
  point_alpha = 0.5,
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

- before_norm_var:

  A string specifying the variable from the QC metrics table to be used
  for the x-axis (before normalization).

- after_norm_var:

  A string specifying the variable from the QC metrics table to be used
  for the y-axis (after normalization).

- plot_type:

  A character string specifying the type of plot to generate. Must be
  one of "scatter", "diff", or "ratio". Selecting "scatter" plots the
  before and after normalization CV values as a scatter plot, "diff"
  plots the difference between the two CV values against the average CV,
  and "ratio" plots the log2 ratio of the two CV values against the
  average CV.

- qc_types:

  A character vector specifying the QC types to plot. It must contain at
  least one element. The default `NA` plots any of the non-blank QC
  types ("SPL", "TQC", "BQC", "HQC", "MQC", "LQC", "NIST", "LTR")
  present in the dataset.

- facet_by_class:

  If `TRUE`, facets the plot by `feature_class`, as defined in the
  feature metadata.

- y_shared:

  Logical; if `TRUE`, all facets share the same y-axis scale. If `FALSE`
  (default), each facet has its own y-axis scale.

- filter_data:

  Whether to use all data (default) or only QC-filtered data (filtered
  via
  [`filter_features_qc()`](https://slinghub.github.io/MRMhub/quant/reference/filter_features_qc.md)).

- include_qualifier:

  Whether to include qualifier features (default is `TRUE`).

- cv_threshold_value:

  Numerical threshold value to be shown as dashed lines in the plot
  (default is `25`).

- x_lim:

  Numeric vector of length 2 for x-axis limits. Use `NA` for
  auto-scaling (default is `c(NA, NA)`).

- y_lim:

  Numeric vector of length 2 for y-axis limits. Use `NA` for
  auto-scaling (default is `c(NA, NA)`). A fixed lower limit of `0`
  would clip the negative values of `plot_type = "diff"` and `"ratio"`,
  which are the features whose CV the normalization reduced.

- cols_page:

  Number of facet columns per page, representing different feature
  classes (default is `5`). Only used if `facet_by_class = TRUE`.

- point_size:

  Size of points in millimeters (default is `1`).

- point_alpha:

  Transparency of points (default is `0.5`).

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

A `ggplot` object representing the scatter plot comparing CV values
before and after normalization.

## Details

The function preselects the corresponding variables from the QC metrics
and uses
[`plot_qcmetrics_comparison()`](https://slinghub.github.io/MRMhub/quant/reference/plot_qcmetrics_comparison.md)
to visualize the results.

- The data must be normalized before using
  [`normalize_by_istd()`](https://slinghub.github.io/MRMhub/quant/reference/normalize_by_istd.md)
  followed by calculation of the QC metrics table via
  [`calc_qc_metrics()`](https://slinghub.github.io/MRMhub/quant/reference/calc_qc_metrics.md)
  or
  [`filter_features_qc()`](https://slinghub.github.io/MRMhub/quant/reference/filter_features_qc.md),
  see examples below.

- When `facet_by_class = TRUE`, then the `feature_class` must be defined
  in the metadata or retrieved via specific functions, e.g.,
  [`parse_lipid_feature_names()`](https://slinghub.github.io/MRMhub/quant/reference/parse_lipid_feature_names.md).

## See also

[`plot_qcmetrics_comparison()`](https://slinghub.github.io/MRMhub/quant/reference/plot_qcmetrics_comparison.md),
[`calc_qc_metrics()`](https://slinghub.github.io/MRMhub/quant/reference/calc_qc_metrics.md),
[`filter_features_qc()`](https://slinghub.github.io/MRMhub/quant/reference/filter_features_qc.md),

Other QC plots:
[`plot_feature_correlations()`](https://slinghub.github.io/MRMhub/quant/reference/plot_feature_correlations.md),
[`plot_interference_correction()`](https://slinghub.github.io/MRMhub/quant/reference/plot_interference_correction.md),
[`plot_matrixeffects()`](https://slinghub.github.io/MRMhub/quant/reference/plot_matrixeffects.md),
[`plot_pca()`](https://slinghub.github.io/MRMhub/quant/reference/plot_pca.md),
[`plot_pca_loading()`](https://slinghub.github.io/MRMhub/quant/reference/plot_pca_loading.md),
[`plot_qc_interference_impact()`](https://slinghub.github.io/MRMhub/quant/reference/plot_qc_interference_impact.md),
[`plot_qc_summary_byclass()`](https://slinghub.github.io/MRMhub/quant/reference/plot_qc_summary_byclass.md),
[`plot_qc_summary_overall()`](https://slinghub.github.io/MRMhub/quant/reference/plot_qc_summary_overall.md),
[`plot_qcmetrics_comparison()`](https://slinghub.github.io/MRMhub/quant/reference/plot_qcmetrics_comparison.md),
[`plot_rla_boxplot()`](https://slinghub.github.io/MRMhub/quant/reference/plot_rla_boxplot.md),
[`plot_rt_vs_chain()`](https://slinghub.github.io/MRMhub/quant/reference/plot_rt_vs_chain.md),
[`plot_runscatter()`](https://slinghub.github.io/MRMhub/quant/reference/plot_runscatter.md),
[`plot_runsequence()`](https://slinghub.github.io/MRMhub/quant/reference/plot_runsequence.md)

## Examples

``` r
# Example usage:
mexp <- lipidomics_dataset
mexp <- normalize_by_istd(mexp)
#> ! Interfering features defined in metadata, but no correction was applied. Use `correct_custom_interferences()` to correct.
#> ✔ 20 features normalized with 9 ISTDs in 499 analyses.
mexp <- calc_qc_metrics(mexp)
#> ✔ QC metrics calculated for 29 features across 7 sample types, including normalized-intensity and response-curve statistics.
plot_normalization_qc(
  data = mexp,
  before_norm_var = "intensity",
  after_norm_var = "norm_intensity",
  plot_type = "scatter",
  qc_types = "SPL",
  filter_data = FALSE,
  facet_by_class = TRUE,
  cv_threshold_value = 25
)

```
