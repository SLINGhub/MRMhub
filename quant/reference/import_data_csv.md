# (Deprecated) Import wide CSV files

(Deprecated) Import wide CSV files

## Usage

``` r
import_data_csv(
  data = NULL,
  path,
  variable_name,
  analysis_id_col = NA,
  import_metadata = TRUE,
  first_feature_column = NA,
  na_strings = "NA"
)
```

## Arguments

- data:

  [`MRMhubExperiment`](https://slinghub.github.io/MRMhub/quant/reference/MRMhubExperiment-class.md)
  object

- path:

  One or more file names with path, or a folder path, which case all
  \*.csv files in this folder will be read.

- variable_name:

  Variable type representing the values in the table. Must be one of
  "intensity", "norm_intensity", "conc", "area", "height", "response".

- analysis_id_col:

  Column to be used as analysis_id. `NA` (default) used 'analysis_id' if
  present, or the first column if it contains unique values.

- import_metadata:

  Import additional metadata columns (e.g. batch ID, sample type) and
  add to the
  [`MRMhubExperiment`](https://slinghub.github.io/MRMhub/quant/reference/MRMhubExperiment-class.md)
  object. Only following metadata column names are supported:
  `"qc_type"`, `"batch_id"`, `"is_quantifier"`, `"is_istd"`,
  `"analysis_order"`

- first_feature_column:

  Column number of the first column representing the feature values

- na_strings:

  A character vector of strings which are to be interpreted as NA
  values. Blank fields are also considered to be missing values.

## Value

[`MRMhubExperiment`](https://slinghub.github.io/MRMhub/quant/reference/MRMhubExperiment-class.md)
object

## Details

This function is deprecated. Please use
[`import_data_csv_wide()`](https://slinghub.github.io/MRMhub/quant/reference/import_data_csv_wide.md)
instead.

## Examples

``` r
file_path <- system.file("extdata", "plain_wide_dataset.csv", package = "mrmhub")

mexp <- MRMhubExperiment()

mexp <- import_data_csv(
  data = mexp,
  path = file_path,
 variable_name = "conc",
 import_metadata = TRUE)
#> ! The function import_data_csv is deprecated. Please use import_data_csv_wide instead.
#> ✔ Metadata column(s) 'qc_type, batch_id' imported. To ignore, set `import_metadata = FALSE`
#> ✔ Imported 87 analyses with 5 features.
#> ✔ Analysis metadata associated with 87 analyses.
#> ✔ Feature metadata associated with 5 features.
#> ℹ Analysis order was based on `analysis_order` column of imported data. Use `set_analysis_order` to change the order.

print(mexp)
#> 
#> ── MRMhubExperiment:  ──────────────────────────────────────────────────────────
#> NA | 87 analyses and 5 features | signal: feature_conc
#> Last step: Annotated raw CONC values
#> Normalized ✖ Quantitated ✖ Drift/batch ✖ Filtered ✖
#> ℹ Use `status()` for the full processing and metadata report
```
