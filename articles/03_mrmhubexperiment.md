# The \`MRMhubExperiment\` data object

## Overview

The `MRMhubExperiment` object is the main **data container** used in the
MRMhub workflow, see also [Data and Metadata in
MRMhub](https://slinghub.github.io/MRMhub/articles/01_datastructure.md).
It holds all the experimental and processed data and metadata, as well
as other details. `MRMhubExperiment` is an S4 object with following
slots:

    MRMhubExperiment
      ├─title:  chr "My LCMS Assay"
      ├─analysis_type:  chr NA
      ├─feature_intensity_var:  chr "feature_area"
      ├─dataset_orig: tibble [400 × 26] (S3: tbl_df/tbl/data.frame)
      ├─dataset: tibble [400 × 26] (S3: tbl_df/tbl/data.frame)
      ├─dataset_filtered: tibble [0 × 14] (S3: tbl_df/tbl/data.frame)
      ├─annot_analyses: tibble [25 × 13] (S3: tbl_df/tbl/data.frame)
      ├─annot_features: tibble [16 × 16] (S3: tbl_df/tbl/data.frame)
      ├─annot_istds: tibble [8 × 4] (S3: tbl_df/tbl/data.frame)
      ├─annot_responsecurves: tibble [0 × 3] (S3: tbl_df/tbl/data.frame)
      ├─annot_qcconcentrations: tibble [32 × 5] (S3: tbl_df/tbl/data.frame)
      ├─annot_studysamples: tibble [0 × 0] (S3: tbl_df/tbl/data.frame)
      ├─annot_batches: tibble [1 × 4] (S3: tbl_df/tbl/data.frame)
      ├─metrics_qc: tibble [0 × 0] (S3: tbl_df/tbl/data.frame)
      ├─metrics_calibration: tibble [4 × 15] (S3: tbl_df/tbl/data.frame)
      ├─parameters_processing: tibble [0 × 1] (S3: tbl_df/tbl/data.frame)
      ├─status_processing:  chr "Calibration-quantitated data"
      ├─is_istd_normalized:  logi TRUE
      ├─is_quantitated:  logi TRUE
      ├─is_filtered:  logi FALSE
      ├─has_outliers_tech:  logi FALSE\
      ├─is_isotope_corr:  logi FALSE
      ├─analyses_excluded:  logi NA
      ├─features_excluded:  logi NA
      ├─var_drift_corrected:  Named logi [1:3] FALSE FALSE FALSE
      ├─var_batch_corrected:  Named logi [1:3] FALSE FALSE FALSE

#### Creating a MRMhubExperiment object

``` r

library(mrmhub)
myexp <- MRMhubExperiment()
```

#### Using MRMhubExperiment objects

Most `MRMhub` functions take an MRMhubExperiment object as input. Data
processing functions return a modified `MRMhubExperiment`, which can be
in subsequent step.

``` r

myexp <- MRMhubExperiment()
myexp <- data_load_example(myexp, 1)
myexp <- normalize_by_istd(myexp)
#> ! Interfering features defined in metadata, but no correction was applied. Use `correct_interferences()` to correct.
#> ✔ 20 features normalized with 9 ISTDs in 499 analyses.

save_dataset_csv(myexp, "mydata.csv", "norm_intensity", FALSE)
#> ✔ Norm_intensity values for 499 analyses and 20 features have been exported to 'mydata.csv'.
```

R pipes can also be used, allowing to chain multiple functions together.
This can more clearly indicate the processing workflow and make the code
more easier to read.

``` r

  myexp |> 
  MRMhubExperiment() |>
  data_load_example(1) |>
  normalize_by_istd() |>
  save_dataset_csv("mydata.csv", "norm_intensity", FALSE)
#> ! Interfering features defined in metadata, but no correction was applied. Use `correct_interferences()` to correct.
#> ✔ 20 features normalized with 9 ISTDs in 499 analyses.
#> ✔ Norm_intensity values for 499 analyses and 20 features have been exported to 'mydata.csv'.
```

#### Multiple `MRMhubExperiment` objects

Multiple `MRMhubExperiment` objects can be created and processed
independently within the same script.

``` r

m_polars <- MRMhubExperiment(title = "Polar metabolites")
m_lipids <- MRMhubExperiment(title = "Non-polar metabolites")
```

#### Accessing data and metadata

Functions starting with `data_get_` allow to retrieve data and metadat
from `MRMhubExperiment` object.

``` r

myexp <- data_load_example(myexp, 1)
dataset <- get_analyticaldata(myexp, annotated = TRUE)

print(dataset)
#> # A tibble: 14,471 × 20
#>    analysis_order analysis_id  acquisition_time_stamp qc_type batch_id sample_id
#>             <int> <chr>        <dttm>                 <chr>   <chr>    <chr>    
#>  1              1 Longit_BLAN… 2017-10-20 14:15:36    SBLK    1        Longit_B…
#>  2              1 Longit_BLAN… 2017-10-20 14:15:36    SBLK    1        Longit_B…
#>  3              1 Longit_BLAN… 2017-10-20 14:15:36    SBLK    1        Longit_B…
#>  4              1 Longit_BLAN… 2017-10-20 14:15:36    SBLK    1        Longit_B…
#>  5              1 Longit_BLAN… 2017-10-20 14:15:36    SBLK    1        Longit_B…
#>  6              1 Longit_BLAN… 2017-10-20 14:15:36    SBLK    1        Longit_B…
#>  7              1 Longit_BLAN… 2017-10-20 14:15:36    SBLK    1        Longit_B…
#>  8              1 Longit_BLAN… 2017-10-20 14:15:36    SBLK    1        Longit_B…
#>  9              1 Longit_BLAN… 2017-10-20 14:15:36    SBLK    1        Longit_B…
#> 10              1 Longit_BLAN… 2017-10-20 14:15:36    SBLK    1        Longit_B…
#> # ℹ 14,461 more rows
#> # ℹ 14 more variables: replicate_no <int>, specimen <chr>, feature_id <chr>,
#> #   feature_class <chr>, feature_label <chr>, is_istd <lgl>,
#> #   is_quantifier <lgl>, analyte_id <chr>, feature_rt <dbl>,
#> #   feature_area <dbl>, feature_height <dbl>, feature_fwhm <dbl>,
#> #   feature_width <dbl>, feature_intensity <dbl>
```

Alternatively, the `$` syntax can be used access data and metadata
tables in `MRMhubExperiment` objects.

``` r

analyses <- myexp$annot_analyses
features <- myexp$annot_features
  print(features)
#> # A tibble: 29 × 17
#>    feature_id     feature_class analyte_id chem_formula molecular_weight is_istd
#>    <chr>          <chr>         <chr>      <chr>                   <dbl> <lgl>  
#>  1 CE 18:1        CE            NA         NA                         NA FALSE  
#>  2 CE 18:1 d7 (I… CE            NA         NA                         NA TRUE   
#>  3 Cer d18:1/16:0 Cer 18:1;O2   NA         NA                         NA FALSE  
#>  4 Cer d18:1/24:0 Cer 18:1;O2   NA         NA                         NA FALSE  
#>  5 Cer d18:1/25:… Cer 18:1;O2   NA         NA                         NA TRUE   
#>  6 LPC 18:1 (a)   LPC           NA         NA                         NA FALSE  
#>  7 LPC 18:1 (ab)… LPC           NA         NA                         NA TRUE   
#>  8 LPC 18:1 (b)   LPC           NA         NA                         NA FALSE  
#>  9 PC 28:0|SM 32… PC            NA         NA                         NA FALSE  
#> 10 PC 32:1        PC            NA         NA                         NA FALSE  
#> # ℹ 19 more rows
#> # ℹ 11 more variables: istd_feature_id <chr>, quant_istd_feature_id <chr>,
#> #   is_quantifier <lgl>, valid_feature <lgl>, response_factor <dbl>,
#> #   interference_feature_id <chr>, interference_contribution <dbl>,
#> #   curve_fit_model <chr>, curve_fit_weighting <chr>, remarks <chr>,
#> #   feature_label <chr>
```

#### Saving and Reading MRMhubExperiment objects

``` r

myexp <- MRMhubExperiment()
myexp <- data_load_example(myexp, 1)
saveRDS(myexp, file = "myexp-mrmhub.rds", compress = TRUE)
my_saved_exp <- readRDS(file = "myexp-mrmhub.rds")
```

#### Status of an `MRMhubExperiment`

A detailed summary of the dataset and processing status can be printed
any time

``` r

print(my_saved_exp)
```
