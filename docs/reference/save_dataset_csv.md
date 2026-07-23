# Export data to a CSV file

This function exports specific unprocessed or processed feature variable
(e.g. intensities or concentrations) from a `MRMhubExperiment` object to
a CSV file. Allows selection of features and optional QC filtering.

## Usage

``` r
save_dataset_csv(
  data = NULL,
  path,
  variable,
  qc_types = NA,
  filter_data = FALSE,
  include_qualifier = NA,
  include_istd = NA,
  include_feature_filter = NA,
  exclude_feature_filter = NA,
  add_qctype = NA
)
```

## Arguments

- data:

  [`MRMhubExperiment`](https://slinghub.github.io/MRMhub/quant/reference/MRMhubExperiment-class.md)
  object

- path:

  File name with path of exported CSV file

- variable:

  Variable to be exported, must be present in the data and any of
  "area", "height", "intensity", "norm_intensity", "response", "conc",
  "conc_raw", "rt", "fwhm".

- qc_types:

  QC types to be exported. Can be a vector of QC types or a regular
  expression pattern. `NA` (default) exports all available QC/Sample
  types.

- filter_data:

  A logical value indicating whether to use all data (default) or only
  QC-filtered data (filtered via
  [`filter_features_qc()`](https://slinghub.github.io/MRMhub/quant/reference/filter_features_qc.md)).
  Default is `FALSE`.

- include_qualifier:

  A logical value indicating whether to include qualifier features.
  Default is `NA`, which will be automatically set to `FALSE` if
  `variable` is `conc` or `conc_raw`, and `TRUE` otherwise.

- include_istd:

  A logical value indicating whether to include internal standard (ISTD)
  features. Default is `NA`, which will be automatically set to `FALSE`
  if `variable` is `norm_intensity`, `conc` or `conc_raw`, and `TRUE`
  otherwise.

- include_feature_filter:

  Feature(s) to include by `feature_id`, as a character vector. Each
  element is matched exactly when it names an existing feature,
  otherwise treated as a regex; elements combine with OR. A full ID
  (e.g. `"S1P d18:0 [M>60]"`) needs no escaping, while patterns like
  `"PC|PE"` still work. `NA` or `""` ignores the filter.

- exclude_feature_filter:

  Feature(s) to exclude by `feature_id`, matched the same way as
  `include_feature_filter`. `NA` or `""` ignores the filter.

- add_qctype:

  Add the QC type as column

## See also

[`normalize_by_istd()`](https://slinghub.github.io/MRMhub/quant/reference/normalize_by_istd.md),
[`quantify_by_istd()`](https://slinghub.github.io/MRMhub/quant/reference/quantify_by_istd.md),
[`quantify_by_calibration()`](https://slinghub.github.io/MRMhub/quant/reference/quantify_by_calibration.md),
[`calibrate_by_reference()`](https://slinghub.github.io/MRMhub/quant/reference/calibrate_by_reference.md)
