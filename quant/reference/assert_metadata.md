# Add metadata to an `MRMhubExperiment` object

Metadata provided as a list of tibbles will be validated for consistency
against the loaded analysis data of the provided `MRMhubExperiment`
object and then transferred.

## Usage

``` r
assert_metadata(
  data = NULL,
  metadata,
  ignore_warnings,
  excl_unmatched_analyses
)
```

## Arguments

- data:

  [`MRMhubExperiment`](https://slinghub.github.io/MRMhub/quant/reference/MRMhubExperiment-class.md)
  object

- metadata:

  List of tibbles or data.frames containing analysis, feature, istd,
  response curve tables

- ignore_warnings:

  Ignore data validation warnings and proceed with adding metadata

- excl_unmatched_analyses:

  Exclude analyses (samples) that have no matching metadata

## Value

metadata list
