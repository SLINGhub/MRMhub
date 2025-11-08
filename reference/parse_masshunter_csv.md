# Reads and parses one Agilent MassHunter Quant CSV result file

Reads and parses one Agilent MassHunter Quant CSV result file

## Usage

``` r
parse_masshunter_csv(
  path,
  expand_qualifier_names = TRUE,
  silent = FALSE,
  conc_column = "conc_final"
)
```

## Arguments

- path:

  File path of MassHunter Quant CSV file

- expand_qualifier_names:

  If TRUE, original qualifier names will be renamed by adding the
  quantifier name in front and placing qualifier name into square
  brackets(e.g. `Qualifier (422.3 -> 113.0)` transition names of
  quantifier will be added to qualifier names

- silent:

  Suppress messages

- conc_column:

  Which concentration field of the masshunter data to use, in case
  "Calc. Conc." and "Final. Conc." are present. Default is "conc_final".

## Value

A tibble with the parse results in the long format

## Examples

``` r
file_path = system.file("extdata", "MHQuant_demo.csv", package = "mrmhub")

tbl <- parse_masshunter_csv(
  path = file_path,
  expand_qualifier_names = TRUE)

head(tbl)
#> # A tibble: 6 × 18
#>   analysis_id      file_analysis_order raw_data_filename sample_name sample_type
#>   <chr>                          <int> <chr>             <chr>       <chr>      
#> 1 001_EQC_TQC pre…                   1 001_EQC_TQC prer… 001_EQC_TQ… Sample     
#> 2 001_EQC_TQC pre…                   1 001_EQC_TQC prer… 001_EQC_TQ… Sample     
#> 3 001_EQC_TQC pre…                   1 001_EQC_TQC prer… 001_EQC_TQ… Sample     
#> 4 001_EQC_TQC pre…                   1 001_EQC_TQC prer… 001_EQC_TQ… Sample     
#> 5 001_EQC_TQC pre…                   1 001_EQC_TQC prer… 001_EQC_TQ… Sample     
#> 6 001_EQC_TQC pre…                   1 001_EQC_TQC prer… 001_EQC_TQ… Sample     
#> # ℹ 13 more variables: sample_level <chr>, acquisition_time_stamp <dttm>,
#> #   vial_position <chr>, feature_id <chr>, integration_qualifier <lgl>,
#> #   method_polarity <fct>, method_precursor_mz <dbl>, method_product_mz <dbl>,
#> #   method_collision_energy <dbl>, feature_rt <dbl>, feature_area <dbl>,
#> #   feature_fwhm <dbl>, feature_manual_integration <lgl>
```
