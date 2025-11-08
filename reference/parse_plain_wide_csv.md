# Parses a plain wide CSV file

Parses a CSV table with analysis/samples in rows, features values in
columns.

## Usage

``` r
parse_plain_wide_csv(
  path,
  variable_name,
  analysis_id_col = NA,
  import_metadata = TRUE,
  first_feature_column = NA,
  na_strings = "NA"
)
```

## Arguments

- path:

  path name and path of a plain long-format CSV file

- variable_name:

  Name of the variable representing the values in the table. Must be one
  of "intensity", "norm_intensity", "conc", "area", "height",
  "response")

- analysis_id_col:

  Column to be used as analysis_id

- import_metadata:

  Import additional metadata columns (e.g. batch ID, sample type) and
  add to the `MRMhubExperiment` object

- first_feature_column:

  Column number of the first column representing the feature values

- na_strings:

  A character vector of strings which are to be interpreted as NA
  values. Blank fields are also considered to be missing values.

## Value

A tibble in the long format

## Examples

``` r
file_path <- system.file("extdata", "plain_wide_dataset.csv", package = "mrmhub")

tbl <- parse_plain_wide_csv(
 path = file_path,
 variable_name = "conc",
 analysis_id_col = "analysis_id",
 import_metadata = TRUE)
#> ℹ Metadata column(s) 'qc_type, batch_id' imported. To ignore, set `import_metadata = FALSE`

head(tbl)
#> # A tibble: 6 × 6
#>   analysis_id qc_type batch_id feature_id  feature_conc integration_qualifier
#>   <chr>       <chr>   <chr>    <chr>              <dbl> <lgl>                
#> 1 1           SPL     1        S1P 18:1;O2        944.  FALSE                
#> 2 1           SPL     1        S1P 18:2;O2        321.  FALSE                
#> 3 1           SPL     1        S1P 18:0;O2        338.  FALSE                
#> 4 1           SPL     1        S1P 16:1;O2         91.2 FALSE                
#> 5 1           SPL     1        S1P 17:1;O2         24.5 FALSE                
#> 6 2           SPL     1        S1P 18:1;O2        977.  FALSE                
```
