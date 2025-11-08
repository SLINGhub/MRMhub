# Get the median run time

Calculates the median run time (in seconds) based of the timestamps
differences between consecutive analyses in the sequence.

## Usage

``` r
get_runtime_median(data)
```

## Arguments

- data:

  A `MRMhubExperiment` object

## Value

A `lubridate` time period object, or `NA` if the dataset is empty.
