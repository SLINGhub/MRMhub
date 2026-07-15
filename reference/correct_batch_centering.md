# Batch Centering Correction

This function performs batch centering correction on each feature.
Optionally, the scale of the batches can be equalized across batches.
The selected QC types (`ref_qc_types`) are used to calculate the
medians, which are then used to align all other samples. The correction
can be applied to one of three variables: "intensity", "norm_intensity",
or "conc". The correction can either be applied on top of previous
corrections or replace all prior batch corrections.

## Usage

``` r
correct_batch_centering(
  data = NULL,
  variable,
  ref_qc_types,
  correct_scale = FALSE,
  replace_previous = TRUE,
  log_transform_internal = TRUE,
  feature_list = NULL,
  replace_exisiting_trendcurves = FALSE,
  ...
)
```

## Arguments

- data:

  A `MRMhubExperiment` object containing the data to be corrected. This
  object must include information about QC types and measurements.

- variable:

  The variable to be corrected. Must be one of "intensity",
  "norm_intensity", or "conc".

- ref_qc_types:

  A character vector specifying the QC types to be used as references
  for batch centering.

- correct_scale:

  A logical value indicating whether to equalize the scale of the
  batches in addition to center them. Defaults to `FALSE`.

- replace_previous:

  A logical value indicating whether to replace any previous batch
  corrections or apply the new correction on top. Defaults to `TRUE`
  (replace).

- log_transform_internal:

  A logical value indicating whether to log-transform the data
  internally during correction. Defaults to `TRUE`.

- feature_list:

  Sets specific features for correction only. Can be character vector or
  a single string which is then interpreted as regular expression.
  Default is `NULL` which means all features are selected.

- replace_exisiting_trendcurves:

  A logical value indicating whether to replace trend curves from
  previous corrections. This is only use for plotting using
  [`plot_runscatter()`](https://slinghub.github.io/MRMhub/reference/plot_runscatter.md).
  Default is `FALSE`.

- ...:

  Additional arguments that can be passed to the batch correction
  function.

## Value

A `MRMhubExperiment` object containing the corrected data.

## See also

`plot_runscatter` for visualizing the correction before and after.
