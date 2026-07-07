# The MRMhubExperiment Data Object

## Overview

The `MRMhubExperiment` object is the main data container used in the
MRMhub workflow. See also [Data and Metadata in
MRMhub](https://slinghub.github.io/MRMhub/quant/articles/manual-01-data-structure.md).
It holds all experimental and processed data and metadata.
`MRMhubExperiment` is an S4 object with the following slots:

**Full slot tree (click to expand)**

    MRMhubExperiment
      ├─ title:                 chr "My LCMS Assay"
      ├─ analysis_type:         chr NA
      ├─ feature_intensity_var: chr "feature_area"
      ├─ dataset_orig:          tibble [400 × 26]
      ├─ dataset:               tibble [400 × 26]
      ├─ dataset_filtered:      tibble [0 × 14]
      ├─ annot_analyses:        tibble [25 × 13]
      ├─ annot_features:        tibble [16 × 16]
      ├─ annot_istds:           tibble [8 × 4]
      ├─ annot_responsecurves:  tibble [0 × 3]
      ├─ annot_qcconcentrations: tibble [32 × 5]
      ├─ annot_studysamples:    tibble [0 × 0]
      ├─ annot_batches:         tibble [1 × 4]
      ├─ metrics_qc:            tibble [0 × 0]
      ├─ metrics_calibration:   tibble [4 × 15]
      ├─ parameters_processing: tibble [0 × 1]
      ├─ status_processing:     chr "Calibration-quantitated data"
      ├─ is_istd_normalized:    logi TRUE
      ├─ is_quantitated:        logi TRUE
      ├─ is_filtered:           logi FALSE
      ├─ has_outliers_tech:     logi FALSE
      ├─ is_isotope_corr:       logi FALSE
      ├─ analyses_excluded:     logi NA
      ├─ features_excluded:     logi NA
      ├─ var_drift_corrected:   Named logi [1:3]
      └─ var_batch_corrected:   Named logi [1:3]

## Creating a MRMhubExperiment Object

``` r

library(mrmhub)
myexp <- MRMhubExperiment()
```

## Using MRMhubExperiment Objects

Most MRMhub functions take an `MRMhubExperiment` as input. Data
processing functions return a modified copy, which can be used in
subsequent steps.

``` r

myexp <- MRMhubExperiment()
myexp <- data_load_example(myexp, 1)
myexp <- normalize_by_istd(myexp)
#> ! Interfering features defined in metadata, but no correction was applied. Use `correct_interferences()` to correct.
#> ✔ 20 features normalized with 9 ISTDs in 499 analyses.

save_dataset_csv(myexp, tempfile(fileext = ".csv"), "norm_intensity", FALSE)
#> ✔ Norm_intensity values for 499 analyses and 20 features have been exported to '/var/folders/3r/ywcsb3896zj4_0xlb_70yvlh0000gn/T//Rtmp31ox8Q/filec3ff60dafa9e.csv'.
```

R pipes allow chaining multiple functions together, making the
processing workflow easier to read:

``` r

myexp <- MRMhubExperiment() |>
  data_load_example(1) |>
  normalize_by_istd()
```

## Multiple MRMhubExperiment Objects

Multiple objects can be created and processed independently within the
same script:

``` r

m_polars <- MRMhubExperiment(title = "Polar metabolites")
m_lipids <- MRMhubExperiment(title = "Non-polar metabolites")
```

## Accessing Data and Metadata

Functions starting with `get_` retrieve data from the object:

``` r

myexp <- data_load_example(MRMhubExperiment(), 1)
dataset <- get_analyticaldata(myexp, annotated = TRUE)
dataset
```

Alternatively, use `$` syntax to access metadata tables directly:

``` r

analyses <- myexp$annot_analyses
features <- myexp$annot_features
features
```

## Saving and Loading

``` r

saveRDS(myexp, file = "myexp-mrmhub.rds", compress = TRUE)
my_saved_exp <- readRDS(file = "myexp-mrmhub.rds")
```

## Checking Processing Status

View the current dataset and processing status at any time:

``` r

myexp
```

## Next Steps

- [Data and
  Metadata](https://slinghub.github.io/MRMhub/quant/articles/manual-01-data-structure.md)
  — table overview
- [Data
  Identifiers](https://slinghub.github.io/MRMhub/quant/articles/manual-02-data-identifiers.md)
  — ID columns explained
- [Feature
  Variables](https://slinghub.github.io/MRMhub/quant/articles/manual-03-feature-variables.md)
  — measurement columns
- [Key
  Concepts](https://slinghub.github.io/MRMhub/quant/articles/manual-00-key-concepts.md)
  — terminology
