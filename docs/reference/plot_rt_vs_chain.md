# Plot retention time versus chain length and saturation

Generates scatter plots of retention time (RT) versus either chain
length, degree of saturation (double bonds), or equivalent carbon number
(ECN) of lipid features of diffent feature classes. This visualization
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
  point_size = 2,
  point_alpha = 0.9,
  line_transparency = 0.5,
  font_base_size = 8
)
```

## Arguments

- data:

  A `MRMhubExperiment` object.

- x_var:

  Variable to use for the x-axis. One ofEither "total_c", "total_db" or
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

  Numeric. Base font size (in points) for plot text. Default is 8.

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
