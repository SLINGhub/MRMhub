# RunSequence plot

The RunSequence plot provides an overview of the analysis design and
timelines, which can be useful for subsequent processing steps. The plot
illustrates the batch structure, the quality control (QC) samples
included with their respective positions, and additional information
regarding the date, duration, and run time of the analysis.

Setting `show_timestamp = TRUE` allows you to check for any
interruptions in the analysis timeline.

## Usage

``` r
plot_runsequence(
  data = NULL,
  qc_types = NA,
  show_batches = TRUE,
  show_timestamp = FALSE,
  add_info_title = TRUE,
  single_row = FALSE,
  segment_linewidth = 0.5,
  batch_zebra_stripe = FALSE,
  batch_line_color = "#b6f0c5",
  batch_fill_color = "grey93",
  font_base_size = NULL,
  legend_position = NULL,
  legend_size = NULL,
  show_legend_title = NULL,
  title = NULL
)
```

## Arguments

- data:

  A `MRMhubExperiment` object.

- qc_types:

  QC types to be plotted. Can be a vector of QC types or a regular
  expression pattern. `NA` (default) displays all available QC/Sample
  types.

- show_batches:

  Logical, whether to show batch separators in the plot.

- show_timestamp:

  Logical, whether to use the acquisition timestamp as the x-axis
  instead of the run sequence number.

- add_info_title:

  Logical, whether to add a title with the experiment title, analysis
  date, and analysis times.

- single_row:

  Logical, whether to show all QC types in a single row.

- segment_linewidth:

  Width of the segment lines, default is 0.5.

- batch_zebra_stripe:

  Logical, whether to show batches as shaded areas instead of line
  separators.

- batch_line_color:

  Color of the batch separator lines.

- batch_fill_color:

  Color of the batch shaded areas.

- font_base_size:

  Numeric. Base font size (in points) for plot text; all plot text
  scales proportionally with this value. `NULL` (default) uses the
  global default set by
  [`mrmhub_set_plot_defaults()`](https://slinghub.github.io/MRMhub/quant/reference/mrmhub_set_plot_defaults.md)
  if one is in effect, otherwise an automatic size (derived from the
  facet-column count on paged plots, or the per-plot default shown in
  the Usage section above).

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

## Value

A `ggplot` object representing the run sequence plot.

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
[`plot_rt_vs_chain()`](https://slinghub.github.io/MRMhub/quant/reference/plot_rt_vs_chain.md),
[`plot_runscatter()`](https://slinghub.github.io/MRMhub/quant/reference/plot_runscatter.md)
