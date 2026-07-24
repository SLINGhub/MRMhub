# Get the end time of the analysis sequence

Returns the end time of the analysis, corresponding to the last
`acquisition_time_stamp` from the dataset. Note: if
`estimate_sequence_end` is set to `FALSE`, the function will return the
timestamp of the last analysis in the dataset, corresponding to the
start of the last analysis. Set `estimate_sequence_end` to `TRUE` to
estimate the end time of the analysis sequence, based on the median
runtime.

## Usage

``` r
get_analyis_end(data, estimate_sequence_end)
```

## Arguments

- data:

  A
  [`MRMhubExperiment`](https://slinghub.github.io/MRMhub/quant/reference/MRMhubExperiment-class.md)
  object

- estimate_sequence_end:

  If `TRUE`, the function will estimate the end time of the analysis
  sequence based on the median runtime. `FALSE` will return the start
  time of the last analysis in the sequence.

## Value

A `POSIXct` timestamp, or `NA_POSIXct_` if the dataset is empty.
