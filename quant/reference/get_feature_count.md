# Get the number of features in the dataset

Returns the number of features in the dataset, with optional filters
whether counted features must be internal standard and/or quantifier.

## Usage

``` r
get_feature_count(data, is_istd = NA, is_quantifier = NA)
```

## Arguments

- data:

  A `MRMhubExperiment` object

- is_istd:

  If set, then defines whether to include or exclude internal standard
  features. Default is `NA` means no filter for internal standards is
  applied.

- is_quantifier:

  If set, then defines whether to include or exclude qualifier features.
  Default is `NA` means no filter for qualifier features is applied.

## Value

An integer with the feature count
