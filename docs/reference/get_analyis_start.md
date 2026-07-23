# Get the start time of the analysis sequence

Returns the start time of the analysis, corresponding to the earliest
`acquisition_time_stamp` from the dataset.

## Usage

``` r
get_analyis_start(data)
```

## Arguments

- data:

  A
  [`MRMhubExperiment`](https://slinghub.github.io/MRMhub/quant/reference/MRMhubExperiment-class.md)
  object

## Value

A `POSIXct` timestamp, or `NA_POSIXct_` if the dataset is empty.
