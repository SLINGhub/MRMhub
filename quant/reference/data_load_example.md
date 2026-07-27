# Load an example `MRMhubExperiment` dataset

Load an example `MRMhubExperiment` dataset: a small, preprocessed subset
of a plasma lipidomics dataset (Tan et al., ATVB, 2022).

## Usage

``` r
data_load_example(data = NULL, dataset = 1)
```

## Arguments

- data:

  [`MRMhubExperiment`](https://slinghub.github.io/MRMhub/quant/reference/MRMhubExperiment-class.md)
  object, optional. Data will be overwritten if provided.

- dataset:

  Which example dataset to load. Currently only `1` (the default) is
  available.

## Value

[`MRMhubExperiment`](https://slinghub.github.io/MRMhub/quant/reference/MRMhubExperiment-class.md)
object

## Examples

``` r
myexp <- MRMhubExperiment()
myexp <- data_load_example(myexp)
#> ✔ Loaded example dataset 1: 499 analyses and 29 features.
myexp
#> 
#> ── MRMhubExperiment:  ──────────────────────────────────────────────────────────
#> lipidomics | 499 analyses and 29 features | signal: feature_area
#> Last step: Annotated raw AREA values
#> Normalized ✖ Quantitated ✖ Drift/batch ✖ Filtered ✖
#> ℹ Use `mrmhub_status()` for the full processing and metadata report
```
