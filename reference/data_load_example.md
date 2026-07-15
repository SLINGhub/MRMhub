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
myexp
#> 
#> ── MRMhubExperiment ────────────────────────────────────────────────────────────
#> Title:
#> 
#> Processing status: Annotated raw AREA values
#> 
#> ── Annotated Raw Data ──
#> 
#> • Analyses: 499
#> • Features: 29
#> • Raw signal used for processing: `feature_area`
#> 
#> ── Metadata ──
#> 
#> • Analyses/samples: ✔
#> • Features/analytes: ✔
#> • Internal standards: ✔
#> • Response curves: ✔
#> • Calibrants/QC concentrations: ✖
#> • Study samples: ✖
#> 
#> ── Processing Status ──
#> 
#> • Isotope corrected: ✖
#> • ISTD normalized: ✖
#> • ISTD quantitated: ✖
#> • Drift corrected variables: ✖
#> • Batch corrected variables: ✖
#> • Feature filtering applied: ✖
#> 
#> ── Exclusion of Analyses and Features ──
#> 
#> • Analyses manually excluded (`analysis_id`): ✖
#> • Features manually excluded (`feature_id`): ✖
```
