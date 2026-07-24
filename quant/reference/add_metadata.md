# Add metadata to an `MRMhubExperiment` object

Metadata provided as a list of tibbles will be validated for consistency
against the loaded analysis data of the provided `MRMhubExperiment`
object and then transferred.

## Usage

``` r
add_metadata(data = NULL, metadata, excl_unmatched_analyses = FALSE)
```

## Arguments

- data:

  [`MRMhubExperiment`](https://slinghub.github.io/MRMhub/quant/reference/MRMhubExperiment-class.md)
  object

- metadata:

  List of tibbles or data.frames containing analysis, feature, istd,
  response curve tables

- excl_unmatched_analyses:

  Exclude analyses (samples) that have no matching metadata

## Value

An updated
[`MRMhubExperiment`](https://slinghub.github.io/MRMhub/quant/reference/MRMhubExperiment-class.md)
object

## See also

The [metadata
guide](https://slinghub.github.io/MRMhub/quant/articles/manual-05-metadata.html).
