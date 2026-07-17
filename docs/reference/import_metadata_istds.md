# Import internal standards (ISTD) metadata

Imports ISTD metadata (annotation) from a preloaded data frame or tibble
via the `data` argument, or from data from a file (CSV or Excel) via the
`path` argument. The analysis metadata must contain following columns:
`istd_feature_id` and one of `istd_conc_nmolar` or `istd_conc_ngml`.

## Usage

``` r
import_metadata_istds(
  data = NULL,
  table = NULL,
  path = NULL,
  sheet = NULL,
  ignore_warnings = FALSE
)
```

## Arguments

- data:

  A `MRMhubExperiment` object

- table:

  A data frame or tibble with analysis (sample) metadata. If `path` is
  also provided, an error will be raised.

- path:

  A character string specifying the path to a CSV (.csv) or Excel
  (.xlsx) file. If `table` is also provided, an error will be raised.

- sheet:

  Defines the sheet name in case an Excel file is provided.

- ignore_warnings:

  Ignore warnings from data validation and proceed with importing
  metadata

## Value

An updated `MRMhubExperiment` object
