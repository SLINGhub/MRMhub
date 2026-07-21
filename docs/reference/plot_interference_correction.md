# Plot the results of interference correction

This function generates grouped standardized beeswarm plots to visualize
the results of interference correction across different QC types.

## Usage

``` r
plot_interference_correction(
  data,
  qc_types = c("SPL", "TQC", "PBLK", "BQC"),
  include_qualifier = FALSE,
  include_istd = TRUE,
  include_feature_filter = NA,
  exclude_feature_filter = NA,
  min_median_value = NA,
  min_correction_pct = NA,
  sort_by_effect = c("none", "desc", "asc"),
  top_n = NA,
  y_lim = c(-NA, NA),
  point_size = 0.5,
  dodge_width = 0.6,
  point_alpha = 0.3,
  box_alpha = 0.3,
  box_linewidth = 0.5,
  font_base_size = 8,
  angle_x = 45
)
```

## Arguments

- data:

  A `MRMhubExperiment` object.

- qc_types:

  A character vector specifying the QC types to plot. It must contain at
  least one element. The default `NA` plots any of the non-blank QC
  types ("SPL", "TQC", "BQC", "HQC", "MQC", "LQC", "NIST", "LTR")
  present in the dataset.

- include_qualifier:

  A logical value indicating whether to include qualifier features.
  Default is `TRUE`.

- include_istd:

  A logical value indicating whether to include internal standards
  (ISTD) features. Default is `TRUE`.

- include_feature_filter:

  Feature(s) to include by `feature_id`, as a character vector. Each
  element is matched exactly when it names an existing feature,
  otherwise treated as a regex; elements combine with OR. A full ID
  (e.g. `"S1P d18:0 [M>60]"`) needs no escaping, while patterns like
  `"PC|PE"` still work. `NA` or `""` ignores the filter.

- exclude_feature_filter:

  Feature(s) to exclude by `feature_id`, matched the same way as
  `include_feature_filter`. `NA` or `""` ignores the filter.

- min_median_value:

  Median raw-signal abundance floor: drop features whose median
  `feature_intensity` across the selected QC types is below this value.
  `NA` (default) applies no threshold. Use to hide low-signal features.

- min_correction_pct:

  Keep only features whose median correction (percent of raw signal
  removed, across the selected QC types) is at least this value. `NA`
  (default) applies no threshold. Use to focus the plot on
  substantially-corrected features.

- sort_by_effect:

  Order the x-axis by correction effect, defined per feature as the
  deviation of its median % change from 100% (pooled across the
  displayed QC-type points). One of `"none"` (default, alphabetical),
  `"desc"` (largest effect first) or `"asc"`.

- top_n:

  Keep only the `top_n` features with the largest correction effect (see
  `sort_by_effect`). `NA` (default) keeps all. Applied after the
  `min_median_value` / `min_correction_pct` filters.

- y_lim:

  A numeric vector of length 2 specifying the y-axis limits.

- point_size:

  A numeric value indicating the size of points in millimeters. Default
  is `0.5`.

- dodge_width:

  Numeric. Width used to dodge overlapping points by `qc_type`. Default
  is `0.6`.

- point_alpha:

  Numeric. Transparency of the plotted points. Default is `0.3`.

- box_alpha:

  Numeric. Transparency of the boxplot. Default is `0.3`.

- box_linewidth:

  Numeric. Width of the boxplot lines. Default is `0.5`.

- font_base_size:

  Numeric. Base font size (in points) for plot text. Default is 8.

- angle_x:

  Numeric. Angle of the x-axis text labels. Default is `45`.

## Value

A `ggplot` object showing the grouped standardized beeswarm plot.

## See also

Other QC plots:
[`plot_feature_correlations()`](https://slinghub.github.io/MRMhub/quant/reference/plot_feature_correlations.md),
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
[`plot_runscatter()`](https://slinghub.github.io/MRMhub/quant/reference/plot_runscatter.md),
[`plot_runsequence()`](https://slinghub.github.io/MRMhub/quant/reference/plot_runsequence.md)
