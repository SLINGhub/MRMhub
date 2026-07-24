# Parses skyline peak integration results into a tibble

Parses skyline peak integration results into a tibble

## Usage

``` r
parse_skyline_result(path, na_strings, silent = FALSE, ...)
```

## Arguments

- path:

  File name of the Skyline result file (\*.tsv or \*.csv)

- na_strings:

  A character vector of strings to be interpreted as NA values.

- silent:

  No comments printed

- ...:

  Additional arguments passed to the function. Currently only
  `transition_id_columns`, which is used for Skyline-like data files.
  The column mapped to `feature_id` will be appended with following
  info: if `transition_id_columns = "name"`, the function will use the
  `method_precursor_name` and `method_product_name` columns to create
  unique feature IDs. If `transition_id_columns = "mz"`, the function
  will use the `method_precursor_mz` and `method_product_mz` columns to
  create unique feature IDs.

## Value

A tibble in the long format

## Examples

``` r

file_path = system.file("extdata", "Skyline_MoleculeTransitionResults.csv", package = "mrmhub")

tbl <- parse_skyline_result(path = file_path, na_strings = "NA")

head(tbl)
#> # A tibble: 6 × 10
#>   analysis_id feature_id feature_class integration_qualifier method_precursor_mz
#>   <chr>       <chr>      <chr>         <lgl>                               <dbl>
#> 1 SBLK1       Aldostero… Steroids      FALSE                                359.
#> 2 SBLK1       Aldostero… Steroids      FALSE                                359.
#> 3 SBLK1       Aldostero… Steroids      FALSE                                361.
#> 4 SBLK1       Aldostero… Steroids      FALSE                                361.
#> 5 SBLK1       Aldostero… Steroids      FALSE                                363.
#> 6 SBLK1       Aldostero… Steroids      FALSE                                363.
#> # ℹ 5 more variables: method_precursor_name <chr>, method_product_mz <dbl>,
#> #   method_product_name <chr>, feature_rt <dbl>, feature_area <dbl>
```
