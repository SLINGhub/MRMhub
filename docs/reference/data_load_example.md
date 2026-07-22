# Load an example MRMhubExperiment dataset

Load an example MRMhubExperiment dataset. Dataset 1 is a small dataset
(Burla et al, 2024, see below) and Dataset 2 a larger dataset (Tan et
al, 2022).See Details below.

## Usage

``` r
data_load_example(data = NULL, dataset = 1)
```

## Arguments

- data:

  MRMhubExperiment object, optional. Data will be overwritten if
  provided.

- dataset:

  Dataset type. Either 1 or 2. Default is 1.

## Value

MRMhubExperiment object

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
#> ℹ Use `status()` for the full processing and metadata report
```
