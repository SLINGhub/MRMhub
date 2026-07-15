# Linear Regression Statistics of Response Curves

This function calculates linear regression statistics (R-squared, slope,
and intercept) for each response curve in the provided
`MRMhubExperiment` object. Optionally, it can include additional
statistics from the `lancer` package (if installed) when
`with_staturation_stats` is set to TRUE.

## Usage

``` r
get_response_curve_stats(
  data = NULL,
  with_staturation_stats = FALSE,
  limit_to_rqc = FALSE,
  silent_invalid_data = FALSE
)
```

## Arguments

- data:

  A `MRMhubExperiment` object containing the dataset and response curve
  annotations.

- with_staturation_stats:

  Logical, if TRUE, include additional statistics from the `lancer`
  package. Note: The `lancer` package must be installed when this
  argument is set to TRUE.

- limit_to_rqc:

  Logical, if TRUE (default), only include rows with `qc_type == "RQC"`.

- silent_invalid_data:

  Logical, if TRUE suppresses raising an error when required data or
  metadata are missing, or there is a mismatch between them.

## Value

A tibble with linear regression statistics (`r2`, `slopenorm`, `y0norm`)
for each curve, or `NULL` if no data matches the criteria.
