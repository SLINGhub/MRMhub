# Plot abundance profile

Creates a profile plot showing the abundance distribution of features
across different classes.

## Usage

``` r
plot_abundanceprofile(
  data,
  variable,
  qc_types,
  log_scale,
  use_qc_metrics = FALSE,
  feature_map = NA,
  show_sum = NA,
  exclude_classes = NA,
  filter_data = FALSE,
  include_qualifier = FALSE,
  include_istd = FALSE,
  include_feature_filter = NA,
  exclude_feature_filter = NA,
  analysis_range = NA,
  drop_empty_classes = TRUE,
  density_strip = FALSE,
  scale_factor = 1,
  x_lim = NA,
  x_label = NA,
  y_axis_position = "right",
  segment_width = 0.25,
  font_base_size = NULL,
  grid_major_color = "grey50",
  grid_major_linewidth = 0.1,
  grid_minor_color = "grey50",
  grid_minor_linewidth = 0.1
)
```

## Arguments

- data:

  A `MRMhubExperiment` object.

- variable:

  A character string indicating the variable to plot. For
  `use_qc_metrics = FALSE`, this must be a base name like "area" or
  "conc". For `use_qc_metrics = TRUE`, this is the base name of a metric
  in the `metrics_qc` table (e.g., "rt" for "rt_mean_SPL").

- qc_types:

  A character vector specifying the QC types to be averaged and plotted.
  If `use_qc_metrics` is `TRUE`, this must be a single character string
  (e.g., "SPL").

- log_scale:

  A logical value indicating whether to use a log10 scale for the
  x-axis.

- use_qc_metrics:

  A logical value. If `FALSE` (default), data is summarized on the fly
  from the main dataset. If `TRUE`, pre-calculated summary data is used
  from the `metrics_qc` table, which is much faster. When `TRUE`,
  `qc_types` must specify only one QC type.

- feature_map:

  A named character vector specifying feature classes, their order, and
  color. The order of the vector determines the y-axis order.
  Alternatively, can be a single string: `lipidomics` to use a default
  theme comprising a mapping for lipid classes frequently measured in
  lipidomics methods. When using the default theme, set
  `drop_empty_classes = TRUE` to avoid showing classes not present in
  the data. If `NA` (default), the default theme is used.

- show_sum:

  A logical value indicating whether to plot a summary point (diamond
  shape) representing the mean of the summed abundances for each class.
  Defaults to `TRUE` for abundance-related variables and `FALSE` for
  others (e.g., "rt", "fwhm").

- exclude_classes:

  A character vector of feature classes to be excluded from the plot.

- filter_data:

  A logical value indicating whether to use all data (`FALSE`, default)
  or only QC-filtered data (`TRUE`, via
  [`filter_features_qc()`](https://slinghub.github.io/MRMhub/quant/reference/filter_features_qc.md)).
  This is ignored if `use_qc_metrics` is `TRUE`.

- include_qualifier:

  A logical value indicating whether to include qualifier features.
  Default is `FALSE`.

- include_istd:

  A logical value indicating whether to include internal standard (ISTD)
  features. Default is `FALSE`.

- include_feature_filter:

  Feature(s) to include by `feature_id`, as a character vector. Each
  element is matched exactly when it names an existing feature,
  otherwise treated as a regex; elements combine with OR. A full ID
  (e.g. `"S1P d18:0 [M>60]"`) needs no escaping, while patterns like
  `"PC|PE"` still work. `NA` or `""` ignores the filter.

- exclude_feature_filter:

  Feature(s) to exclude by `feature_id`, matched the same way as
  `include_feature_filter`. `NA` or `""` ignores the filter.

- analysis_range:

  A numeric vector of length 2 specifying the inclusive range of
  `analysis_order`. If `NA` (default), all analyses are included.

- drop_empty_classes:

  A logical value. If `TRUE` (default), feature classes from
  `feature_map` that are not found in the data are removed from the
  plot. If `FALSE`, they are kept as empty rows.

- density_strip:

  A logical value. If `TRUE`, a density strip showing the distribution
  of all features is added to the top of the plot.

- scale_factor:

  A numeric value to scale the selected variable. Default is 1.

- x_lim:

  A numeric vector of length 2 specifying the x-axis limits. If
  `log_scale` is `TRUE`, these are interpreted as exponents (e.g.,
  `c(2, 6)` for `10^2` to `10^6`). If `NA`, limits are determined
  automatically from the data.

- x_label:

  A character string for the x-axis label. If `NA`, a default label is
  generated.

- y_axis_position:

  A character string specifying the y-axis position ("left" or "right").
  Default is "right".

- segment_width:

  A numeric value for the linewidth of the feature segments. Default is
  0.25.

- font_base_size:

  Numeric. Base font size (in points) for plot text; all plot text
  scales proportionally with this value. `NULL` (default) uses the
  global default set by
  [`mrmhub_set_plot_defaults()`](https://slinghub.github.io/MRMhub/quant/reference/mrmhub_set_plot_defaults.md)
  if one is in effect, otherwise an automatic size (derived from the
  facet-column count on paged plots, or the per-plot default shown in
  the Usage section above).

- grid_major_color:

  Color for major grid lines. Default is "grey50".

- grid_major_linewidth:

  Linewidth for major grid lines. Default is 0.1.

- grid_minor_color:

  Color for minor grid lines. Default is "grey50".

- grid_minor_linewidth:

  Linewidth for minor grid lines. Default is 0.1.

## Value

A `ggplot` object representing the abundance profile plot.
