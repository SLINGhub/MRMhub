# Plot QC Filtering Summary by Feature Class

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

  MRMhubExperiment object

- font_base_size:

  The base font size for the plot. Default is `8`.

## Value

A `ggplot2` object showing the feature QC filtering summary by feature
class.

## See also

[`plot_qc_summary_overall`](https://slinghub.github.io/MRMhub/quant/reference/plot_qc_summary_overall.md)
for an overall summary plot
[`filter_features_qc`](https://slinghub.github.io/MRMhub/quant/reference/filter_features_qc.md)
for comparing QC metrics
