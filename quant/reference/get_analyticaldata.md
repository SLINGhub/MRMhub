# Get the annotated or the originally imported analytical data

Get the annotated or the originally imported analytical data

## Usage

``` r
get_analyticaldata(data = NULL, annotated)
```

## Arguments

- data:

  [`MRMhubExperiment`](https://slinghub.github.io/MRMhub/quant/reference/MRMhubExperiment-class.md)
  object

- annotated:

  Boolean indicating whether to return the annotated data (`TRUE`) or
  the original imported data (`FALSE`)

## Value

A tibble with the analytical data in the long format
