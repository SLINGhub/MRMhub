# Generalized additive model (GAM) smoothing helper function

Function for penalized spline-based smoothing using GAM, for use by
`correct_drift`

## Usage

``` r
fun_gam_smooth(tbl, ref_qc_types, log_transform_internal = TRUE, ...)
```

## Arguments

- tbl:

  Table (`tibble` or `data.frame`) containing the fields `qc_type`, `x`
  (run order number), and `y` (variable)

- ref_qc_types:

  QC types used for the smoothing (fit) by GAM

- log_transform_internal:

  Apply log transformation internally for smoothing if `TRUE` (default).
  This does not affect the final data, which remains untransformed.

- ...:

  Additional arguments forwarded to
  [`mgcv::gam`](https://rdrr.io/pkg/mgcv/man/gam.html)

## Value

List with a `data.frame` containing original x and the smoothed y
values, and a `boolean` value indicating whether the fit failed or not.
