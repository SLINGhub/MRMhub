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
plot_qc_summary_byclass(data = NULL, font_base_size = 8)
```

## Arguments

- data:

  A `MRMhubExperiment` object.

- font_base_size:

  Numeric. Base font size (in points) for plot text. Default is 8.

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
[`plot_normalization_qc()`](https://slinghub.github.io/MRMhub/quant/reference/plot_normalization_qc.md),
[`plot_pca()`](https://slinghub.github.io/MRMhub/quant/reference/plot_pca.md),
[`plot_pca_loading()`](https://slinghub.github.io/MRMhub/quant/reference/plot_pca_loading.md),
[`plot_qc_interferences()`](https://slinghub.github.io/MRMhub/quant/reference/plot_qc_interferences.md),
[`plot_qc_matrixeffects()`](https://slinghub.github.io/MRMhub/quant/reference/plot_qc_matrixeffects.md),
[`plot_qc_summary_overall()`](https://slinghub.github.io/MRMhub/quant/reference/plot_qc_summary_overall.md),
[`plot_qcmetrics_comparison()`](https://slinghub.github.io/MRMhub/quant/reference/plot_qcmetrics_comparison.md),
[`plot_rla_boxplot()`](https://slinghub.github.io/MRMhub/quant/reference/plot_rla_boxplot.md),
[`plot_rt_vs_chain()`](https://slinghub.github.io/MRMhub/quant/reference/plot_rt_vs_chain.md),
[`plot_runscatter()`](https://slinghub.github.io/MRMhub/quant/reference/plot_runscatter.md),
[`plot_runsequence()`](https://slinghub.github.io/MRMhub/quant/reference/plot_runsequence.md)
