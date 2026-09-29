# Linear regression statistics of response curves

This function calculates linear regression statistics (R², slope, and
intercept) for each response curve in the provided `MRMhubExperiment`
object. Each curve is fitted on its points with a non-missing intensity,
with a warning when some are missing; a curve with 2 such points has a
slope and intercept but no R² (`NA`), and a curve with fewer gives `NA`
throughout. Before fitting, the analyzed sample amount (`x`) and feature
intensity (`y`) of these points are each scaled to their maximum (set to
1), so the returned `slopenorm` and `y0norm` are on this normalized
scale. Optionally, it can include additional statistics from the
`lancer` package (if installed) when `with_saturation_stats` is set to
`TRUE`.

## Usage

``` r
get_response_curve_stats(
  data = NULL,
  with_saturation_stats = FALSE,
  limit_to_rqc = FALSE,
  silent_invalid_data = FALSE
)
```

## Arguments

- data:

  A
  [`MRMhubExperiment`](https://slinghub.github.io/MRMhub/quant/reference/MRMhubExperiment-class.md)
  object containing the dataset and response curve annotations.

- with_saturation_stats:

  Logical, if `TRUE`, include additional statistics from the `lancer`
  package. Note: The `lancer` package must be installed when this
  argument is set to `TRUE`.

- limit_to_rqc:

  Logical, if `TRUE`, only include rows with `qc_type == "RQC"`. Default
  is `FALSE`.

- silent_invalid_data:

  Logical, if `TRUE` suppresses raising an error when required data or
  metadata are missing, or there is a mismatch between them.

## Value

A tibble with linear regression statistics (`r2`, `slopenorm`, `y0norm`)
for each curve, or `NULL` if no data matches the criteria.
