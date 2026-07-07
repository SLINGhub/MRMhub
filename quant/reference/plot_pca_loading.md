# Plot PCA loadings

Generates a plot of PCA loadings, illustrating the contribution of
features to each principal component. This function can be used to
investigate which feature (groups) are contributing to the variance seen
in the plot and which need further investigation.

## Usage

``` r
plot_pca_loading(
  data = NULL,
  variable,
  qc_types = NA,
  pca_dims = c(1, 2, 3, 4),
  log_transform = TRUE,
  top_n = 30,
  vertical_bars = FALSE,
  abs_loading = TRUE,
  filter_data = FALSE,
  include_qualifier = FALSE,
  include_istd = FALSE,
  include_feature_filter = NA,
  exclude_feature_filter = NA,
  min_median_value = NA,
  font_base_size = 7
)
```

## Arguments

- data:

  A MRMhubExperiment object

- variable:

  A character string indicating the variable to use for PCA analysis.
  Must be one of: "area", "height", "intensity", "norm_intensity",
  "response", "conc", "conc_raw", "rt", "fwhm".

- qc_types:

  A character vector specifying the QC types to plot. It must contain at
  least one element. The default is `NA`, which means any of the
  non-blank QC types ("SPL", "TQC", "BQC", "HQC", "MQC", "LQC", "NIST",
  "LTR") will be plotted if present in the dataset.

- pca_dims:

  A numeric vector indicating for which PCA dimensions to the loadings
  should be shown. Default is c(1, 2, 3, 4).

- log_transform:

  A logical value indicating whether to log-transform the data before
  the PCA. Default is `TRUE`.

- top_n:

  Number of top features with highest absolute loading that will be to
  shown for each PC dimension. Default is 30.

- vertical_bars:

  Show vertical bars instead of horizontal bars in the plot. Default is
  `FALSE`.

- abs_loading:

  Show absolute loading values instead of signed loadings. Default is
  `TRUE`.

- filter_data:

  A logical value indicating whether to use all data (default) or only
  QC-filtered data (filtered via
  [`filter_features_qc()`](https://slinghub.github.io/MRMhub/quant/reference/filter_features_qc.md)).

- include_qualifier:

  A logical value indicating whether to include qualifier features.
  Default is `TRUE`.

- include_istd:

  A logical value indicating whether to include internal standard (ISTD)
  features. Default is `TRUE`.

- include_feature_filter:

  A character or regex pattern used to filter features by `feature_id`.
  If `NA` or an empty string (`""`) is provided, the filter is ignored.
  When a vector of length \> 1 is supplied, only features with exactly
  these names are selected (applied individually as OR conditions).

- exclude_feature_filter:

  A character or regex pattern used to exclude features by `feature_id`.
  If `NA` or an empty string (`""`) is provided, the filter is ignored.
  When a vector of length \> 1 is supplied, only features with exactly
  these names are excluded (applied individually as OR conditions).

- min_median_value:

  Minimum median feature value (as determined by the `variable`) across
  all samples from selected QC types that must be met for a feature to
  be included in the PCA analysis. `NA` (default) means no filtering
  will be applied. This parameter provides an fast way to exclude noisy
  features from the analysis. However, it is recommended to use
  `filter_data` with
  [`filter_features_qc()`](https://slinghub.github.io/MRMhub/quant/reference/filter_features_qc.md).

- font_base_size:

  A numeric value indicating the base font size for plot text elements.
  Default is 7.

## Value

ggplot object with PCA loadings plot
