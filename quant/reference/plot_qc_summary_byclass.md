# Plot QC filtering summary by feature class

This function provides a summary of feature QC filtering based on
feature class, showing the number of features that passed or failed
various quality control criteria. It visualizes the filtering in a
hierarchical sequence. Features are first evaluated against lower-level
filters such as signal-to-blank (S/B) ratios and limit of detection
(LOD), followed by higher-level filters like the coefficient of
variation (CV) or linear regression results. This means that a feature
is classified as failing a given criterion (e.g., `CV`) only if it has
passed all hierarchically lower filters (e.g., `S/B` ratio and `LOD`).

## Usage

``` r
plot_qc_summary_byclass(
  data = NULL,
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

A `ggplot` object showing the feature QC filtering summary by feature
class.

## See also

[`plot_qc_summary_overall()`](https://slinghub.github.io/MRMhub/quant/reference/plot_qc_summary_overall.md)
for an overall summary plot
[`filter_features_qc()`](https://slinghub.github.io/MRMhub/quant/reference/filter_features_qc.md)
for comparing QC metrics

Other QC plots:
[`plot_feature_correlations()`](https://slinghub.github.io/MRMhub/quant/reference/plot_feature_correlations.md),
[`plot_interference_correction()`](https://slinghub.github.io/MRMhub/quant/reference/plot_interference_correction.md),
[`plot_matrixeffects()`](https://slinghub.github.io/MRMhub/quant/reference/plot_matrixeffects.md),
[`plot_normalization_qc()`](https://slinghub.github.io/MRMhub/quant/reference/plot_normalization_qc.md),
[`plot_pca()`](https://slinghub.github.io/MRMhub/quant/reference/plot_pca.md),
[`plot_pca_loading()`](https://slinghub.github.io/MRMhub/quant/reference/plot_pca_loading.md),
[`plot_qc_interference_impact()`](https://slinghub.github.io/MRMhub/quant/reference/plot_qc_interference_impact.md),
[`plot_qc_summary_overall()`](https://slinghub.github.io/MRMhub/quant/reference/plot_qc_summary_overall.md),
[`plot_qcmetrics_comparison()`](https://slinghub.github.io/MRMhub/quant/reference/plot_qcmetrics_comparison.md),
[`plot_rla_boxplot()`](https://slinghub.github.io/MRMhub/quant/reference/plot_rla_boxplot.md),
[`plot_rt_vs_chain()`](https://slinghub.github.io/MRMhub/quant/reference/plot_rt_vs_chain.md),
[`plot_runscatter()`](https://slinghub.github.io/MRMhub/quant/reference/plot_runscatter.md),
[`plot_runsequence()`](https://slinghub.github.io/MRMhub/quant/reference/plot_runsequence.md)
