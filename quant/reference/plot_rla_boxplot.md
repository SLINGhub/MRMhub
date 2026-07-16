# Relative log abundance (RLA) plot

The Relative Log Abundance (RLA) plot visualizes standardized feature
abundances distributions across samples. RLA standardization involves
subtracting either the within-batch or across-batch median from each
feature's log-transformed abundance. Thse plots are effective for
identifying systematic technical variations, such as batch effects,
instrument drift, or sample handling inconsistencies, by providing a
robust representation less susceptible to global intensity shifts.

The function also incorporates optional outlier detection and
visualization functionalities to identify anomalous samples based on
their median RLA values.

This funcion returns a list with the ggplot object representing the RLA
plot and a table with detected outliers (if `outlier_detection = TRUE`).

## Usage

``` r
plot_rla_boxplot(
  data = NULL,
  variable,
  rla_type_batch,
  qc_types = NA,
  plot_range = NA,
  rla_limit_to_range = FALSE,
  collapse_excluded = FALSE,
  remove_gaps = FALSE,
  gap_line_color = "#e34a33",
  gap_line_width = 0.3,
  gap_label_size = 2.5,
  gap_scale = 1,
  filter_data = FALSE,
  include_qualifier = TRUE,
  include_istd = TRUE,
  include_feature_filter = NA,
  exclude_feature_filter = NA,
  show_timestamp = FALSE,
  min_feature_intensity = 0,
  y_lim = NA,
  outlier_detection = TRUE,
  outlier_exclude = FALSE,
  outlier_method = "mad",
  outlier_qctypes = c("SPL", "TQC", "BQC", "LTR", "NIST"),
  outlier_k = NULL,
  show_batches = TRUE,
  batch_zebra_stripe = FALSE,
  batch_line_color = "#b6f0c5",
  batch_fill_color = "grey93",
  x_gridlines = FALSE,
  linewidth = 0.2,
  font_base_size = 8,
  relative_log_abundances = TRUE,
  show_plot = TRUE
)
```

## Arguments

- data:

  A `MRMhubExperiment` object.

- variable:

  Variable to plot, must be one of "intensity", "norm_intensity",
  "conc", "area", "height", "fwhm", or one of "intensity_raw",
  "intensity_before", "norm_intensity_raw", "norm_intensity_before",
  "conc_raw", "conc_before"

- rla_type_batch:

  Character, must be either "within" or "across", defining whether to
  use within-batch or across-batch RLA

- qc_types:

  QC types to be plotted. Can be a vector of QC types or a regular
  expression pattern. `NA` (default) displays all available QC/Sample
  types.

- plot_range:

  Numeric vector of length 2, specifying the start and end indices of
  the analysis order to be plotted. `NA` plots all samples.

- rla_limit_to_range:

  Logical, whether to limit the RLA values to the specified
  `plot_range`. Default is `FALSE`, which means RLA values are
  calculated for all samples.

- collapse_excluded:

  Logical, whether to collapse gaps in the x-axis caused by QC types
  that were not selected, re-indexing x to a contiguous sequence.
  Default is `FALSE`.

- remove_gaps:

  Logical. If `TRUE`, contiguous indices replace the original
  `analysis_order` on the x-axis so that missing/filtered samples no
  longer leave large gaps. Each gap is highlighted with a thick vertical
  line and annotated with the flanking analysis-order IDs. Default is
  `FALSE`.

- gap_line_color:

  Color of the vertical gap-indicator lines. Default is `"#e34a33"`.

- gap_line_width:

  Line width of the vertical gap-indicator lines. Default is `0.3`.

- gap_label_size:

  Font size of the gap-boundary labels. Default is `2.5`.

- gap_scale:

  Numeric multiplication factor for the gap band width. Default is `1`.
  Increase (e.g. `2`) for wider gaps, decrease for narrower.

- filter_data:

  Logical, whether to use QC-filtered data based on criteria set via
  [`filter_features_qc()`](https://slinghub.github.io/MRMhub/quant/reference/filter_features_qc.md).

- include_qualifier:

  Logical, whether to include qualifier features. Default is `TRUE`.

- include_istd:

  Logical, whether to include internal standard (ISTD) features. Default
  is `TRUE`.

- include_feature_filter:

  A regex pattern or a vector of feature names used to filter features
  by `feature_id`. If `NA` or an empty string (`""`) is provided, the
  filter is ignored. When a vector of length \> 1 is supplied, only
  features with exactly these names are selected (applied individually
  as OR conditions).

- exclude_feature_filter:

  A regex pattern or a vector of feature names used to exclude features
  by `feature_id`. If `NA` or an empty string (`""`) is provided, the
  filter is ignored. When a vector of length \> 1 is supplied, only
  features with exactly these names are excluded (applied individually
  as OR conditions).

- show_timestamp:

  Logical, whether to use the acquisition timestamp as the x-axis
  instead of the run sequence number

- min_feature_intensity:

  Numeric, exclude features with overall median signal below this value

- y_lim:

  Numeric vector of length 2, specifying the lower and upper y-axis
  limits. Default is `NA`, which uses limits calculated based on
  `outlier_exclude`.

- outlier_detection:

  Logical, whether to show outlier fences on the plot and return a table
  with detect outliers based on the method defined by `outlier_method`.

- outlier_exclude:

  Logical, whether to exclude outlier values from the plot. Default is
  `FALSE`, which means outliers are shown.

- outlier_method:

  Character, method used for outlier detection. Default is "mad" (median
  absolute deviation). Other possible values are "iqr", "sd",
  "z_normal", "z_robust", "quantile", and "fold". See
  get_outlier_bounds() for details.

- outlier_qctypes:

  Character vector, QC types to use for outlier detection. Default is
  `c("SPL", "TQC", "BQC")`.

- outlier_k:

  Numeric, multiplier for the outlier detection method. Default is
  `NULL`, which uses the default value for the selected method. See
  get_outlier_bounds() for details. When using the "fold" method, either
  single numeric value or a vector with two values (lower and upper
  fences) can be supplied.

- show_batches:

  Logical, whether to show batch separators in the plot

- batch_zebra_stripe:

  Logical, whether to show batches as shaded areas instead of line
  separators

- batch_line_color:

  Character, color of the batch separator lines

- batch_fill_color:

  Character, color of the batch shaded areas

- x_gridlines:

  Logical, whether to show major x-axis gridlines

- linewidth:

  Numeric, line width used for whiskers of the boxplot

- font_base_size:

  Numeric. Base font size (in points) for plot text. Default is 8.

- relative_log_abundances:

  Logical, whether to use relative log abundances (RLA) or just
  log-transformed values

- show_plot:

  Logical, whether to display the plot. Default is `TRUE`.

## Value

A list with the `ggplot` object representing the RLA plot and a table
with detected outliers if `outlier_detection = TRUE`.

## References

De Livera et al. (2012) Normalizing and integrating metabolomics data.
Analytical Chemistry 10768-10776 [DOI:
10.1021/ac302748b](https://doi.org/10.1021/ac302748b) De Livera et al.
(2015) Statistical Methods for Handling Unwanted Variation in
Metabolomics Data. Analytical Chemistry 87(7):3606-3615 [DOI:
10.1021/ac502439y](https://doi.org/10.1021/ac502439y)

## See also

Other QC plots:
[`plot_feature_correlations()`](https://slinghub.github.io/MRMhub/quant/reference/plot_feature_correlations.md),
[`plot_normalization_qc()`](https://slinghub.github.io/MRMhub/quant/reference/plot_normalization_qc.md),
[`plot_pca()`](https://slinghub.github.io/MRMhub/quant/reference/plot_pca.md),
[`plot_pca_loading()`](https://slinghub.github.io/MRMhub/quant/reference/plot_pca_loading.md),
[`plot_qc_interferences()`](https://slinghub.github.io/MRMhub/quant/reference/plot_qc_interferences.md),
[`plot_qc_matrixeffects()`](https://slinghub.github.io/MRMhub/quant/reference/plot_qc_matrixeffects.md),
[`plot_qc_summary_byclass()`](https://slinghub.github.io/MRMhub/quant/reference/plot_qc_summary_byclass.md),
[`plot_qc_summary_overall()`](https://slinghub.github.io/MRMhub/quant/reference/plot_qc_summary_overall.md),
[`plot_qcmetrics_comparison()`](https://slinghub.github.io/MRMhub/quant/reference/plot_qcmetrics_comparison.md),
[`plot_rt_vs_chain()`](https://slinghub.github.io/MRMhub/quant/reference/plot_rt_vs_chain.md),
[`plot_runscatter()`](https://slinghub.github.io/MRMhub/quant/reference/plot_runscatter.md),
[`plot_runsequence()`](https://slinghub.github.io/MRMhub/quant/reference/plot_runsequence.md)
