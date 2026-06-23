# Plot Overall QC Filtering Summary

This function generates a summary of the feature QC filtering process,
visualizing the number of features that passed or failed the various QC
criteria. It includes a Venn diagram showing the features excluded due
to different filtering criteria such as signal-to-blank ratios, CV
thresholds, and linearity. The criteria are applied hierarchically,
meaning a feature must pass all lower-tier filters before being
considered for failure on higher-tier filters. See
[`plot_qc_summary_byclass()`](https://slinghub.github.io/MRMhub/quant/reference/plot_qc_summary_byclass.md)
for more information.

## Usage

``` r
plot_qc_summary_overall(data = NULL, with_venn = TRUE, font_base_size = 8)
```

## Arguments

- data:

  MRMhubExperiment object

- with_venn:

  Whether to include a Venn diagram summarizing the features excluded
  due to different QC criteria. Default is `TRUE`.

- font_base_size:

  The base font size for the plot. Default is `8`.

## Value

A `ggplot2` object showing the feature QC filtering summary with or
without a Venn diagram.

## Details

The QC filtering process follows a hierarchical structure, where
features are first evaluated against lower-level filters such as
signal-to-blank ratios and limit of detection (LOD). Only features that
pass these basic criteria are then subjected to higher-level filters
like the coefficient of variation (CV) or linear regression results. A
feature will only fail a higher-level filter (such as `CV` or
`R-squared`) if it has passed all previous lower-level filters. This
ensures that features are evaluated progressively, starting from
fundamental quality checks up to more stringent filtering criteria.

Note: The function currently shows a warning
`Using `size` aesthetic for lines was deprecated in ggplot2 3.4.0.`
which can be ignored.
