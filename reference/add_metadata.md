# Add metadata an MRMhubExperiment object

Metadata provided as a list of tibbles will validates for consistency
again loaded analysis data of the provided MRMhubExperiment object and
then transfered.

## Usage

``` r
add_metadata(data = NULL, metadata, excl_unmatched_analyses = FALSE)
```

## Arguments

- data:

  MRMhubExperiment object

- metadata:

  List of tibbles or data.frames containing analysis, feature, istd,
  response curve tables

- excl_unmatched_analyses:

  Exclude analyses (samples) that have no matching metadata

## Value

metadata list
