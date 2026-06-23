# Export Data to CSV file

This function exports specific unprocessed or pr ocessed feature
variable (e.g. intensities or concentrations) from a `MRMhubExperiment`
object to a CSV file. Allows selection of features and optional QC
filtering.

## Usage

``` r
save_dataset_csv(
  data = NULL,
  path,
  variable,
  filter_data = FALSE,
  qc_types = NA,
  include_qualifier = NA,
  include_istd = NA,
  include_feature_filter = NA,
  exclude_feature_filter = NA,
  add_qctype = NA
)
```

## Arguments

- data:

  MRMhubExperiment object

- path:

  File name with path of exported CSV file

- variable:

  Variable to be exported, must be present in the data and any of
  "area", "height", "intensity", "norm_intensity", "response", "conc",
  "conc_raw", "rt", "fwhm".

- filter_data:

  A logical value indicating whether to use all data (default) or only
  QC-filtered data (filtered via
  [`filter_features_qc()`](https://slinghub.github.io/MRMhub/quant/reference/filter_features_qc.md)).
  Default is `FALSE`.

- qc_types:

  QC types to be plotted. Can be a vector of QC types or a regular
  expression pattern. `NA` (default) displays all available QC/Sample
  types.

- include_qualifier:

  A logical value indicating whether to include qualifier features.
  Default is `NA`, which will be automatically set to `FALSE` if
  `variable` is `conc` or `conc_raw`, and `FALSE` otherwise.

- include_istd:

  A logical value indicating whether to include internal standard (ISTD)
  features. Default is `NA`, which will be automatically set to `FALSE`
  if `variable` is ”norm_intensity`, `conc`or`conc_raw`, and `TRUE\`
  otherwise.

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

- add_qctype:

  Add the QC type as column

## See also

[`normalize_by_istd()`](https://slinghub.github.io/MRMhub/quant/reference/normalize_by_istd.md),
[`quantify_by_istd()`](https://slinghub.github.io/MRMhub/quant/reference/quantify_by_istd.md),
[`quantify_by_calibration()`](https://slinghub.github.io/MRMhub/quant/reference/quantify_by_calibration.md),
[`calibrate_by_reference()`](https://slinghub.github.io/MRMhub/quant/reference/calibrate_by_reference.md)
