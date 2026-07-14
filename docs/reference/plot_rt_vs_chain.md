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
  point_transparency = 0.9,
  line_transparency = 0.5,
  base_font_size = 8
)
```

## Arguments

- data:

  A `MRMhubExperiment` object

- x_var:

  Variable to use for the x-axis. One ofEither "total_c", "total_db" or
  "ecn".

- qc_types:

  A character vector of QC types to include in the plot. If `NA`, all

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

- point_transparency:

  Alpha transparency of the data point. Default is 0.9

- line_transparency:

  Alpha transparency of the regression lines. Default is 0.9

- base_font_size:

  Base font size for the plot.

## Value

A `ggplot2` object representing faceted scatter plots

## Details

The retention time can be either plotted against the total number of
carbon atoms with the total number of double bonds as curves, or
opposite, with the total double bond number as x axis and the total
number of carbon atoms as curves. Alternatively, the retention time can
be plotted against the ECN, which is calculated as \\ECN = C\_{total} -
ecn_k \times DB\_{total}\\, where \\ecn_k\\ is a constant that may need
to be adjusted to the specific chromatographic properties. The default
value is \\ecn_k = 1.5\\.
