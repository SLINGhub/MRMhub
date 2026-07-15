# Retrieve Calibration Regression Results

This function retrieves calibration curve regression results from a
`MRMhubExperiment` object. It returns a summary of quality control (QC)
metrics for specified QC samples. including bias, absolute bias, and
intra-assay coefficient of variation (CV). The standard deviation of
bias and percentage bias are also included unless the it is `NA` for all
analytes, i.e. when no replicates were measured.

## Usage

``` r
get_qc_bias_variability(
  data,
  qc_types = NA,
  sample_ids = NA,
  wide_format = "none",
  include_qualifier = FALSE,
  with_conc = TRUE,
  with_conc_target = TRUE,
  with_bias = TRUE,
  with_bias_abs = FALSE,
  with_conc_ratio = FALSE,
  with_cv_intra = TRUE
)
```

## Arguments

- data:

  A `MRMhubExperiment` object containing the dataset and necessary
  annotations for calibration analysis.

- qc_types:

  A character vector specifying the QC types to include in the results,
  in addition to `CAL`. If not specified, all applicable QC types are
  included by default.

- sample_ids:

  A character vector specifying the sample IDs to include in the
  results. If not specified, all analyses regardless of their sample IDs
  are included by default.

- wide_format:

  Format of the output table. Must be one of `"none"`, `"features"`, or
  `"samples"`. If `"none"`, the output is in long format. If
  `"features"`, the output is in wide format with features as columns.
  If `"samples"`, the output is in wide format with samples as columns.

- include_qualifier:

  Logical. If `TRUE`, includes qualifier features in the results.
  Defaults to `FALSE`.

- with_conc:

  Logical. If `TRUE`, includes target and measured mean concentrations
  in the results. Defaults to `TRUE`.

- with_conc_target:

  Logical. If `TRUE`, includes target (know) concentration of the QC
  sample in the results. Defaults to `TRUE`.

- with_bias:

  Logical. If `TRUE`, includes percentage bias in the results. Defaults
  to `TRUE`.

- with_bias_abs:

  Logical. If `TRUE`, includes absolute bias in concentration units in
  the results. Defaults to `FALSE`.

- with_conc_ratio:

  Logical. If `TRUE`, includes the ratio of measured to target
  concentration in the results. Defaults to `TRUE`.

- with_cv_intra:

  Logical. If `TRUE`, includes intra-assay coefficient of variation (CV)
  for the in the results. Defaults to `TRUE`.

## Value

A data frame containing the calibration results, including metrics such
as bias, percentage bias, and intra-assay CV based on specified
parameters.

## Details

The standard deviation of concentration is also included unless the
number of replicates was 1.

The function uses data from the `MRMhubExperiment` object and filters it
according to the specified QC types and other parameters. It then
calculates summary statistics for each feature, such as bias and CV, and
organizes the data into a user-specified format.
