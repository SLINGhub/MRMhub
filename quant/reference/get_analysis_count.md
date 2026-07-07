# Get the number of analyses in the dataset

Returns the number of analyses in the dataset, with an optional filter
based on `qc_types`.

## Usage

``` r
get_analysis_count(data, qc_types = NULL)
```

## Arguments

- data:

  A `MRMhubExperiment` object

- qc_types:

  Defines the `qc_types` to be counted. If `NULL` or `NA`, all analyses
  will be counted.

## Value

An integer with the analysis count
