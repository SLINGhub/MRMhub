# Gaussian kernel smoothing helper function

Function for Gaussian kernel-based smoothing, for use by
`fun_correct_drift`.

## Usage

``` r
fun_gauss.kernel.smooth(tbl, ref_qc_types, log_transform_internal, ...)
```

## Arguments

- tbl:

  Table (`tibble` or `data.frame`) containing the fields `qc_type`, `x`
  (run order number), and `y` (variable)

- ref_qc_types:

  QC types used for the smoothing (fit) by loess

- log_transform_internal:

  Apply log transformation internally for smoothing if `TRUE` (default).
  This does not affect the final data, which remains untransformed.

- ...:

  Additional arguments

## Value

List with a `data.frame` containing original `x` and the smoothed `y`
values, and a `boolean` value indicting whether the fit failed or not
not.

## Author

Hyung Won Choi
