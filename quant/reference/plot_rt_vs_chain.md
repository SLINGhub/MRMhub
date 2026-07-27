# Plot retention time versus chain length and saturation

Generates scatter plots of retention time (RT) versus either chain
length, degree of saturation (double bonds), or equivalent carbon number
(ECN) of lipid features of different feature classes. This visualization
can be useful in identifying annotation (peak picking) errors in
reversed-phase (RP)-LC lipidomics dataset arising from isotopic,
isobaric, isomeric, or unknown interferences.

## Usage

``` r
plot_rt_vs_chain(
  data = NULL,
  x_var = c("total_c", "total_db", "ecn"),
  qc_types = NA,
  outliers_highlight = TRUE,
  outlier_residual_min = 0.15,
  outlier_print = TRUE,
  ecn_k = 1.5,
  include_qualifier = FALSE,
  robust_regression = TRUE,
  cols_page = 5,
  point_size = NULL,
  point_alpha = 0.9,
  line_transparency = 0.5,
  font_base_size = NULL,
  autoscale = TRUE,
  legend_position = NULL,
  legend_size = NULL,
  show_legend_title = NULL,
  title = NULL,
  strip_text_size = NULL,
  strip_bg_color = NULL
)
```

## Arguments

- data:

  A `MRMhubExperiment` object.

- x_var:

  Variable to use for the x-axis. One of "total_c", "total_db", or
  "ecn".

- qc_types:

  A character vector specifying the QC types to plot. It must contain at
  least one element. The default `NA` plots any of the non-blank QC
  types ("SPL", "TQC", "BQC", "HQC", "MQC", "LQC", "NIST", "LTR")
  present in the dataset.

- outliers_highlight:

  Whether to highlight potential outliers in the plot. Default is
  `TRUE`.

- outlier_residual_min:

  Minimum value for the residuals to be considered an outlier (default
  is `0.15`). The value corresponds to the RT difference betweem the
  fitted line and the median RT of the feature. The value is used to
  flag outliers.

- outlier_print:

  Whether to print the features that are flagged as potential outliers
  to the console. Default is `TRUE`.

- ecn_k:

  Constant for ECN calculation (ECN = C - ecn_k\* DB), see Details.
  Default is `1.5`.

- include_qualifier:

  Whether to include qualifier features.

- robust_regression:

  Whether to use robust regression, which is less sensitive to outlier
  (default is `TRUE`).

- cols_page:

  Number of facet columns, representing different feature classes, shown
  per page (default is `5`).

- point_size:

  Size of the data points. Default is 2

- point_alpha:

  Alpha transparency of the data point. Default is 0.9

- line_transparency:

  Alpha transparency of the regression lines. Default is 0.9

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

## Value

A `ggplot` object representing faceted scatter plots

## Details

The retention time can be either plotted against the total number of
carbon atoms with the total number of double bonds as curves, or
opposite, with the total double bond number as x axis and the total
number of carbon atoms as curves. Alternatively, the retention time can
be plotted against the ECN, which is calculated as \\ECN = C\_{total} -
ecn_k \times DB\_{total}\\, where \\ecn_k\\ is a constant that may need
to be adjusted to the specific chromatographic properties. The default
value is \\ecn_k = 1.5\\.

## See also

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
[`plot_qcmetrics_comparison()`](https://slinghub.github.io/MRMhub/quant/reference/plot_qcmetrics_comparison.md),
[`plot_rla_boxplot()`](https://slinghub.github.io/MRMhub/quant/reference/plot_rla_boxplot.md),
[`plot_runscatter()`](https://slinghub.github.io/MRMhub/quant/reference/plot_runscatter.md),
[`plot_runsequence()`](https://slinghub.github.io/MRMhub/quant/reference/plot_runsequence.md)
