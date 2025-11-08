# Import Analysis Results from Plain Wide-Format CSV Files

Imports analysis result data from wide-format `.csv` files, where each
row corresponds to a unique analysis-feature pair and columns contain
analysis- or feature-specific variables.

## Usage

``` r
import_data_csv_wide(
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

  A `MRMhubExperiment` object.

- path:

  A file path or vector of file paths, or a directory path. If a
  directory is provided, all `.csv` files within it will be read.

- variable_name:

  A character string specifying the variable type contained in the data.
  Must be one of `"intensity"`, `"norm_intensity"`, `"conc"`, `"area"`,
  `"height"`, or `"response"`.

- analysis_id_col:

  The column name or index to be used as `analysis_id`. Defaults to
  `NA`, in which case `"analysis_id"` is used if present; otherwise, the
  first column is used if it contains unique values.

- import_metadata:

  Logical indicating whether to import additional metadata columns
  (e.g., batch ID, sample type) into the `MRMhubExperiment` object.
  Supported metadata columns are: `"qc_type"`, `"batch_id"`,
  `"is_quantifier"`, `"is_istd"`, and `"analysis_order"`.

- first_feature_column:

  Integer indicating the column number where feature value columns
  start.

- na_strings:

  Character vector of strings to interpret as NA values. Blank fields
  are also treated as NA.

## Value

A `MRMhubExperiment` object containing the imported dataset.

## Details

The dataset must include two identifier columns: `"analysis_id"` and
`"feature_id"`, with each pair of values unique across the table.
Additionally, the table must contain at least one feature variable
column, such as `"area"`, `"height"`, `"intensity"`, `"norm_intensity"`,
`"response"`, `"conc"`, `"rt"`, or `"fwhm"`. Some downstream functions
may require specific columns among these to be present.

The `variable_name` argument specifies the data type represented in the
table, which must be one of: `"area"`, `"height"`, `"intensity"`,
`"norm_intensity"`, `"response"`, `"conc"`, `"conc_raw"`, `"rt"`, or
`"fwhm"`.

If there is no column named `analysis_id`, it will be inferred from the
first column, provided it contains unique values.

When `import_metadata` is set to `TRUE`, the following metadata columns
will be imported if present:

- `analysis_order`

- `qc_type`

- `batch_id`

- `is_quantifier`

To prevent additional non-metadata columns from being misinterpreted as
features, use the `first_feature_column` parameter to specify the column
where feature data starts.

If a directory path is provided to `path`, all `.csv` files in that
directory will be processed and merged into a single dataset. This
facilitates handling datasets split into multiple files during
preprocessing. Ensure each feature and raw data file pair appears only
once to avoid duplication errors.

The `na_strings` parameter allows specifying character strings to be
interpreted as missing values (NA). Blank fields are also treated as
missing.

## Examples

``` r
file_path <- system.file("extdata", "plain_wide_dataset.csv", package = "mrmhub")
mexp <- MRMhubExperiment()
mexp <- import_data_csv_wide(
  data = mexp,
  path = file_path,
  variable_name = "conc",
  import_metadata = TRUE
)
#> ℹ Metadata column(s) 'qc_type, batch_id' imported. To ignore, set `import_metadata = FALSE`
#> ✔ Imported 87 analyses with 5 features
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
