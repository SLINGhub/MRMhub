# Plot the magnitude of interference correction as a histogram

Shows how many features were affected by which magnitude of interference
correction, as a histogram of the per-feature correction impact (percent
of raw signal removed) within one or more QC types (study samples by
default). The data must already be interference-corrected. Features with
no impact are excluded and reported.

## Usage

``` r
plot_qc_interference_impact(
  data,
  qc_types = "SPL",
  include_qualifier = FALSE,
  include_istd = TRUE,
  include_feature_filter = NA,
  exclude_feature_filter = NA,
  min_correction_pct = NA,
  binwidth = NA,
  font_base_size = 8
)
```

## Arguments

- data:

  A
  [`MRMhubExperiment`](https://slinghub.github.io/MRMhub/quant/reference/MRMhubExperiment-class.md)
  (already interference-corrected).

- qc_types:

  QC type(s) to summarize. Default `"SPL"` (study samples). Set to `NA`
  to use all non-blank sample/QC types.

- include_qualifier:

  Include qualifier features. Default `FALSE`.

- include_istd:

  Include internal standards. Default `TRUE`.

- include_feature_filter:

  Feature(s) to include by `feature_id`, as a character vector. Each
  element is matched exactly when it names an existing feature,
  otherwise treated as a regex; elements combine with OR. A full ID
  (e.g. `"S1P d18:0 [M>60]"`) needs no escaping, while patterns like
  `"PC|PE"` still work. `NA` or `""` ignores the filter.

- exclude_feature_filter:

  Feature(s) to exclude by `feature_id`, matched the same way as
  `include_feature_filter`. `NA` or `""` ignores the filter.

- min_correction_pct:

  Keep only features whose median correction (percent of raw signal
  removed) is at least this value. `NA` (default) keeps every feature
  with a positive impact. Use to drop negligible corrections.

- binwidth:

  Histogram bin width (percent). Default `NA` (30 bins).

- font_base_size:

  Base font size. Default `8`.

## Value

A `ggplot` object: feature count vs. percent of signal removed.

## See also

Other QC plots:
[`plot_feature_correlations()`](https://slinghub.github.io/MRMhub/quant/reference/plot_feature_correlations.md),
[`plot_interference_correction()`](https://slinghub.github.io/MRMhub/quant/reference/plot_interference_correction.md),
[`plot_matrixeffects()`](https://slinghub.github.io/MRMhub/quant/reference/plot_matrixeffects.md),
[`plot_normalization_qc()`](https://slinghub.github.io/MRMhub/quant/reference/plot_normalization_qc.md),
[`plot_pca()`](https://slinghub.github.io/MRMhub/quant/reference/plot_pca.md),
[`plot_pca_loading()`](https://slinghub.github.io/MRMhub/quant/reference/plot_pca_loading.md),
[`plot_qc_summary_byclass()`](https://slinghub.github.io/MRMhub/quant/reference/plot_qc_summary_byclass.md),
[`plot_qc_summary_overall()`](https://slinghub.github.io/MRMhub/quant/reference/plot_qc_summary_overall.md),
[`plot_qcmetrics_comparison()`](https://slinghub.github.io/MRMhub/quant/reference/plot_qcmetrics_comparison.md),
[`plot_rla_boxplot()`](https://slinghub.github.io/MRMhub/quant/reference/plot_rla_boxplot.md),
[`plot_rt_vs_chain()`](https://slinghub.github.io/MRMhub/quant/reference/plot_rt_vs_chain.md),
[`plot_runscatter()`](https://slinghub.github.io/MRMhub/quant/reference/plot_runscatter.md),
[`plot_runsequence()`](https://slinghub.github.io/MRMhub/quant/reference/plot_runsequence.md)
