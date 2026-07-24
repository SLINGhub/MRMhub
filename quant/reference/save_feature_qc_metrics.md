# Save feature QC metrics to CSV

This function exports the feature information and QC (Quality Control)
metrics from a `MRMhubExperiment` object to a CSV file.

## Usage

``` r
save_feature_qc_metrics(data = NULL, path)
```

## Arguments

- data:

  A
  [`MRMhubExperiment`](https://slinghub.github.io/MRMhub/quant/reference/MRMhubExperiment-class.md)
  object containing the QC metrics.

- path:

  A string specifying the file path where the CSV file will be saved.

## Value

A tibble with the QC metrics that have been exported.
