# Parses MRMhub peak integration results into a tibble

Parses MRMhub peak integration results into a tibble

## Usage

``` r
parse_mrmhub_result(path, silent = FALSE)
```

## Arguments

- path:

  File name of the MRMhub result file (\*.tsv or \*.csv)

- silent:

  No comments printed

## Value

A tibble in the long format

## Examples

``` r
file_path = system.file("extdata", "MRMhub_demo.tsv", package = "mrmhub")

tbl <- parse_mrmhub_result(path = file_path)

head(tbl)
#> # A tibble: 6 × 19
#>   analysis_id          raw_data_filename acquisition_time_stamp qc_type batch_id
#>   <chr>                <chr>             <dttm>                 <chr>   <chr>   
#> 1 Longit_BLANK-01 (El… Longit_BLANK-01 … 2017-10-20 14:15:36    SBLK    1       
#> 2 Longit_B-ISTD 01 Ex… Longit_B-ISTD 01… 2017-10-20 14:27:06    PBLK    1       
#> 3 Longit_Un-ISTD 01 U… Longit_Un-ISTD 0… 2017-10-20 14:38:26    UBLK    1       
#> 4 Longit_LTR 01        Longit_LTR 01.mz… 2017-10-20 14:49:48    LTR     1       
#> 5 Longit_TQC-10%       Longit_TQC-10%.m… 2017-10-20 15:12:31    TQC     1       
#> 6 Longit_TQC-20%       Longit_TQC-20%.m… 2017-10-20 15:23:51    TQC     1       
#> # ℹ 14 more variables: feature_id <chr>, istd_feature_id <chr>,
#> #   integration_qualifier <lgl>, method_precursor_mz <dbl>,
#> #   method_product_mz <dbl>, method_collision_energy <dbl>,
#> #   method_polarity <chr>, feature_rt <dbl>, feature_area <dbl>,
#> #   feature_height <dbl>, feature_fwhm <dbl>, feature_int_start <dbl>,
#> #   feature_int_end <dbl>, feature_width <dbl>
```
