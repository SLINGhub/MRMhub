# RunScatter Plot

The `runscatter` function visualizes raw or processed feature signals
across different sample/QC types along the analysis sequence. It helps
identify trends, detect outliers, and assess analytical performance.
Available feature variables, such as retention time (RT) and full width
at half maximum (FWHM), can be plotted against analysis order or
timestamps.

By default, all QC types present in the dataset will be plotted. QC
types that predefined colors or shapes are assigned black shapes.
User-defined QC types that have no predefined colors or shapes in
mrmhub. will be assigned black shapes. have no predefined color and
shape, will be assigned shapes in black. To show specific QC types use
the `qc_types` argument.

To plot the feature values before the last applied drift/batch
correction, add `*_before` to the variable name, e.g.,
`intensity_before` or `conc_before`. To plot the uncorrected feature
values (before any drift/batch correction), add `*_raw` to the variable
name, e.g., `intensity_raw` or `conc_raw`. To show corresponding fit
curves, set `show_trend = TRUE`.

The function also supports visualizing analysis batches, reference lines
(mean \\\pm\\ SD), and trends. It offers customization options to
display batch separators, apply outlier capping, show smoothed trend
curves, add reference lines, and incorporate other features. Outlier
capping is particularly useful to focus on QC or study sample trends
that might otherwise be obscured by extreme values or high variability.

The `runscatter` function serves as a central QC tool in the workflow,
providing critical insights into data quality.

## Usage

``` r
plot_runscatter(
  data = NULL,
  variable = c("intensity", "norm_intensity", "conc", "rt", "area", "height", "fwhm",
    "width", "symmetry", "intensity_raw", "intensity_before", "norm_intensity_raw",
    "norm_intensity_before", "conc_raw", "conc_before"),
  filter_data = FALSE,
  qc_types = NA,
  include_qualifier = TRUE,
  include_istd = TRUE,
  include_feature_filter = NA,
  exclude_feature_filter = NA,
  plot_range = NA,
  output_pdf = FALSE,
  path = NA,
  multithreading = FALSE,
  return_plots = FALSE,
  show_batches = TRUE,
  batch_zebra_stripe = FALSE,
  batch_line_color = "#cdf7d9",
  batch_fill_color = "grey93",
  cap_outliers = FALSE,
  cap_sample_k_mad = 4,
  cap_qc_k_mad = 4,
  cap_top_n_outliers = NA,
  show_reference_lines = FALSE,
  ref_qc_types = NA,
  reference_k_sd = 2,
  reference_batchwise = FALSE,
  reference_line_color = "#04bf9a",
  reference_sd_shade = FALSE,
  reference_fill_color = NA,
  reference_linewidth = 0.75,
  show_trend = FALSE,
  trend_color = "#22e06b",
  y_lim = c(0, NA),
  log_scale = FALSE,
  show_gridlines = FALSE,
  point_size = 1.5,
  point_transparency = 1,
  point_border_width = NA,
  base_font_size = 10,
  rows_page = 3,
  cols_page = 3,
  specific_page = NA,
  page_orientation = "LANDSCAPE",
  y_label_text = NA,
  pages_per_core = 1,
  use_dingbats = TRUE,
  show_progress = TRUE,
  remove_gaps = FALSE,
  collapse_excluded = FALSE,
  gap_line_color = "#e34a33",
  gap_line_width = 0.3,
  gap_label_size = 2.5,
  gap_scale = 1,
  label_wrap = FALSE,
  label_wrap_width = 25
)
```

## Arguments

- data:

  A `MRMhubExperiment` object containing the dataset and metadata.

- variable:

  The variable to plot on the y-axis, one of 'intensity',
  'norm_intensity', 'conc', 'conc', 'rt', 'fwhm', 'area', 'height',
  response'. Add `_before` after the variable name to plot the feature
  values before the last applied drift/batch correction, (e.g.,
  `conc_before`). Add `_raw` after the variable name to plot the raw
  uncorrected feature values (e.g., `conc_raw`).

- filter_data:

  Logical, whether to use QC-filtered data based on criteria set via
  [`filter_features_qc()`](https://slinghub.github.io/MRMhub/quant/reference/filter_features_qc.md).

- qc_types:

  QC types to be plotted. Can be a vector of QC types or a regular
  expression pattern. `NA` (default) displays all available QC/Sample
  types.

- include_qualifier:

  Logical, whether to include qualifier features. Default is `TRUE`.

- include_istd:

  Logical, whether to include internal standard (ISTD) features. Default
  is `TRUE`.

- include_feature_filter:

  A regex pattern or a vector of feature names used to filter features
  by `feature_id`. If `NA` or an empty string (`""`) is provided, the
  filter is ignored. When a vector of length \> 1 is supplied, is
  supplied, only features with exactly these names are selected (applied
  individually as OR conditions).

- exclude_feature_filter:

  A regex pattern or a vector of feature names to exclude features by
  feature_id. If `NA` or an empty string (`""`) is provided, the filter
  is ignored. When a vector of length \> 1 is supplied, is supplied,
  only features with exactly these names are excluded (applied
  individually as OR conditions).

- plot_range:

  Numeric vector of length 2, specifying the start and end indices of
  the analysis order to be plotted. `NA` plots all samples.

- output_pdf:

  Logical, whether to save the plot as a PDF file.

- path:

  File name for the PDF output.

- multithreading:

  Logical, whether to use parallel processing to speed up plot
  generation.

- return_plots:

  Logical, whether to return the list of ggplot objects.

- show_batches:

  Logical, whether to show batch separators in the plot.

- batch_zebra_stripe:

  Logical, whether to display batches with alternating shaded and
  non-shaded areas.

- batch_line_color:

  Color of the batch separator lines.

- batch_fill_color:

  Color for the shaded areas representing batches.

- cap_outliers:

  Logical, whether to cap upper outliers based on MAD fences of SPL and
  QC samples.

- cap_sample_k_mad:

  Numeric, k \* MAD (median absolute deviation) for outlier capping of
  SPL samples.

- cap_qc_k_mad:

  Numeric, k \* MAD (median absolute deviation) for outlier capping of
  QC samples.

- cap_top_n_outliers:

  Numeric, cap the top n outliers regardless of MAD fences. `NA` or `0`
  ignores this filter.

- show_reference_lines:

  Whether to display reference lines (mean \\\pm\\ n x SD).

- ref_qc_types:

  QC type for which the reference lines are calculated.

- reference_k_sd:

  Multiplier for standard deviations to define SD reference lines.

- reference_batchwise:

  Whether to calculate reference lines per batch.

- reference_line_color:

  Color of the reference lines.

- reference_sd_shade:

  `TRUE` plots a colored band indicating the \\\pm\\ n x SD reference
  range. `FALSE` (default) shows reference lines instead.

- reference_fill_color:

  Fill color of the batch-wise reference ranges. If `NA` (default), the
  color assigned to the qc_type is used.

- reference_linewidth:

  Width of the reference lines.

- show_trend:

  If `TRUE` trend curves before or after drift/batch correction are
  shown.

- trend_color:

  Color of the trend curve.

- y_lim:

  Numeric vector of length 2, specifying the lower and upper y-axis
  limits. Default is \`c(0,NA)“, which sets the lower limit to 0 and the
  upper limit automatically.

- log_scale:

  Logical, whether to use a log10 scale for the y-axis.

- show_gridlines:

  Whether to show major x and y gridlines.

- point_size:

  Size of the data points. Default is `1.5`.

- point_transparency:

  Alpha transparency of the data points.

- point_border_width:

  Width of the data point borders.

- base_font_size:

  Base font size for the plot.

- rows_page:

  Number of rows per page.

- cols_page:

  Number of columns per page.

- specific_page:

  Show/save a specific page number only. `NA` plots/saves all pages.

- page_orientation:

  Page orientation, "LANDSCAPE" or "PORTRAIT".

- y_label_text:

  Override the default y-axis label text.

- pages_per_core:

  Number of pages to be plotted by core when multithreading is enabled.
  Default is `6`. Changing this number may improve performance.

- use_dingbats:

  Logical, whether to use Dingbats font in the PDF output for improved
  plotting speed. Default is `TRUE`. Set to `FALSE` if your PDF viewer
  does not show points correctly.

- show_progress:

  Logical, whether to show a progress bar. Default is `TRUE`.

- remove_gaps:

  Logical. If `TRUE`, contiguous indices replace the original
  `analysis_order` on the x-axis so that missing/filtered samples no
  longer leave large gaps. Each gap is highlighted with a thick vertical
  line and annotated with the flanking analysis-order IDs. Default is
  `FALSE`.

- collapse_excluded:

  Logical. If `TRUE`, gaps in the x-axis caused by QC types that were
  not selected (via `qc_types`) are collapsed, re-indexing x to a
  contiguous sequence. Default is `FALSE`.

- gap_line_color:

  Color of the vertical gap-indicator lines. Default is `"#e34a33"`.

- gap_line_width:

  Line width of the vertical gap-indicator lines. Default is `0.3`.

- gap_label_size:

  Font size of the gap-boundary labels. Default is `2.5`.

- gap_scale:

  Numeric multiplication factor for the gap band width. Default is `1`.
  Increase (e.g. `2`) for wider gaps, decrease for narrower.

- label_wrap:

  Logical. If `TRUE`, long `feature_id` labels are wrapped to multiple
  lines using `label_wrap_width`. Default is `FALSE`.

- label_wrap_width:

  Integer. Maximum width in characters for wrapped labels when
  `label_wrap = TRUE`. Default is `25`. Ignored when
  `label_wrap = FALSE`.

## Value

A list of ggplot2 plots, or `NULL` if \`return

## Details

- The outlier capping feature (`cap_outliers`) allows you to cap upper
  outliers based on median absolute deviation (MAD) fences of SPL and QC
  samples, or to remove the top n points. This can help to focus on the
  trends of interest when there are outlier or a high variability in the
  data, e.g. in the study samples.

- When using log-scale (`log_scale = TRUE`), zero or negative values
  will replaced with the minimum positive value divided by 5 to avoid
  log 0 errors

- Reference lines/ranges corresponding to mean \\\pm\\ k x SD can be
  shown across or within batches as lines or shaded stripes.

- Trend curves can be displayed before or after drift/batch correction.
  In either case, a drift and/or batch correction must be applied to the
  data to enable plotting of trend curves. To show trend curves used for
  the last drift or batch correction, add "\_before" to the variable
  name, e.g. `conc_before` or `intensity_before` and set
  `show_trend = TRUE`.
