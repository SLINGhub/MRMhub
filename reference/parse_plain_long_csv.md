# Parses a plain long CSV file

Parses a CSV table with analysis/samples and feature pairs in rows,
columns representing the feature variables.

## Usage

``` r
parse_plain_long_csv(
  path,
  na_strings = "NA",
  silent = FALSE,
  column_mapping = NULL,
  warn_unrecognized_columns = TRUE,
  ...
)
```

## Arguments

- path:

  File name (\*.tsv or \*.csv)

- na_strings:

  A character vector of strings to be interpreted as NA values. Blank
  fields are also considered to be missing values.

- silent:

  No comments printed

- column_mapping:

  A named character vector with the mapping of the columns in the input
  file to the columns in the output table. If NULL (default), the
  function will use the default mapping. See
  [`import_data_csv_long()`](https://slinghub.github.io/MRMhub/quant/reference/import_data_csv_long.md)
  for details.

- warn_unrecognized_columns:

  Logical indicating whether to issue a warning for unknown columns in
  the dataset.

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

file_path = system.file("extdata", "plain_long_dataset.csv", package = "mrmhub")

tbl <- parse_plain_long_csv(path = file_path)
#> ! Following unrecognized columns present in the data and were ignored: "internal_standard", "batch", "sample_type", "rt_apex", "area_normalized", "concentration", "rt_int_start", and "rt_int_end".
#> ! Use argument `column_mapping` to define column mapping.

head(tbl)
#> # A tibble: 6 × 12
#>   analysis_id      raw_data_filename     acquisition_time_stamp feature_id      
#>   <chr>            <chr>                 <dttm>                 <chr>           
#> 1 Longit_batch1_15 Longit_batch1_15.mzML 2017-10-20 20:07:09    CE 18:1         
#> 2 Longit_batch1_16 Longit_batch1_16.mzML 2017-10-20 20:29:49    CE 18:1         
#> 3 Longit_batch1_17 Longit_batch1_17.mzML 2017-10-20 20:41:10    CE 18:1         
#> 4 Longit_batch1_15 Longit_batch1_15.mzML 2017-10-20 20:07:09    CE 18:1 d7 (IST…
#> 5 Longit_batch1_16 Longit_batch1_16.mzML 2017-10-20 20:29:49    CE 18:1 d7 (IST…
#> 6 Longit_batch1_17 Longit_batch1_17.mzML 2017-10-20 20:41:10    CE 18:1 d7 (IST…
#> # ℹ 8 more variables: integration_qualifier <lgl>, method_precursor_mz <dbl>,
#> #   method_product_mz <dbl>, method_collision_energy <dbl>,
#> #   method_polarity <chr>, feature_area <dbl>, feature_height <dbl>,
#> #   feature_fwhm <dbl>
```
