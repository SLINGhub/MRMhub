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

  MRMhubExperiment object

- path:

  One or more file names with path, or a folder path, which case all
  \*.csv files in this folder will be read.

- variable_name:

  Variable type representing the values in the table. Must be one of
  "intensity", "norm_intensity", "conc", "area", "height", "response")

- analysis_id_col:

  Column to be used as analysis_id. `NA` (default) used 'analysis_id' if
  present, or the first column if it contains unique values.

- import_metadata:

  Import additional metadata columns (e.g. batch ID, sample type) and
  add to the `MRMhubExperiment` object. Only following metadata column
  names are supported: "qc_type", "batch_id", "is_quantifier",
  "is_istd", "analysis_order"

- first_feature_column:

  Column number of the first column representing the feature values

- na_strings:

  A character vector of strings which are to be interpreted as NA
  values. Blank fields are also considered to be missing values.

## Value

MRMhubExperiment object

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
#> ── MRMhubExperiment ────────────────────────────────────────────────────────────
#> Title:
#> 
#> Processing status: Annotated raw CONC values
#> 
#> ── Annotated Raw Data ──
#> 
#> • Analyses: 87
#> • Features: 5
#> • Raw signal used for processing: `feature_conc`
#> 
#> ── Metadata ──
#> 
#> • Analyses/samples: ✔
#> • Features/analytes: ✔
#> • Internal standards: ✖
#> • Response curves: ✖
#> • Calibrants/QC concentrations: ✖
#> • Study samples: ✖
#> • Interferences: ✖
#> 
#> ── Processing Status ──
#> 
#> • Isotope corrected: ✖
#> • ISTD normalized: ✖
#> • ISTD quantitated: ✔
#> • Drift corrected variables: ✖
#> • Batch corrected variables: ✖
#> • Feature filtering applied: ✖
#> 
#> ── Exclusion of Analyses and Features ──
#> 
#> • Analyses manually excluded (`analysis_id`): ✖
#> • Features manually excluded (`feature_id`): ✖
```
