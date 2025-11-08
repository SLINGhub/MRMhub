# Get the number of analysis breaks in the analysis

Counts the number of interruptions in the analysis, where an
interruption is defined as a time gap between consecutive acquisition
timestamps that exceeds a given threshold (`break_duration_minutes`).

## Usage

``` r
get_analysis_breaks(data, break_duration_minutes)
```

## Arguments

- data:

  A `MRMhubExperiment` object

- break_duration_minutes:

  A numeric value specifying the minimum duration (in minutes) between
  two consecutive analyses that qualifies as an interruption.

## Value

An integer with the number of interruptions, or `NA_integer_` if the
dataset is empty.
