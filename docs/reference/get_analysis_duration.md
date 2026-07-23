# Get the total duration of the analysis

This function returns the total duration of the analysis, which is the
time difference between the timestamps of the first and last analyses in
the sequence.

## Usage

``` r
get_analysis_duration(data, estimate_sequence_end)
```

## Arguments

- data:

  A
  [`MRMhubExperiment`](https://slinghub.github.io/MRMhub/quant/reference/MRMhubExperiment-class.md)
  object

- estimate_sequence_end:

  If `TRUE`, the function will estimate the end time of the analysis
  sequence based on the median runtime, added to the timestamp of the
  last analysis. If `FALSE`, the function will calculate the time
  difference between the first and last analysis timestamps without any
  adjustment.

## Details

If `estimate_sequence_end` is `TRUE`, the function will estimate the end
time of the analysis sequence by adding the median runtime to the
timestamp of the last analysis, instead of simply using the timestamp of
the last analysis.
