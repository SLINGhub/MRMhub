# Import analysis results from plain wide-format CSV files

Imports analysis result data from wide-format `.csv` files, where each
row corresponds to a single analysis and each feature is stored in its
own column. All feature columns hold the same variable type, given by
`variable_name`.

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
  Must be one of `"area"`, `"height"`, `"intensity"`,
  `"norm_intensity"`, `"response"`, `"conc"`, `"conc_raw"`, `"rt"`, or
  `"fwhm"`.

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

Each row must be identified by an `"analysis_id"` column (or, if absent,
the first column, provided it holds unique values). Every feature is
stored in a separate column; the feature columns all contain the single
variable type specified by `variable_name`. Use `first_feature_column`
to mark where the feature columns begin so that leading metadata columns
are not mistaken for features.

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

## Identifier normalization

All imported identifiers are whitespace-normalized on import: leading
and trailing spaces are removed and internal runs of whitespace are
collapsed to a single space (for example `"QC 01"` becomes `"QC 01"`).
Raw-data file extensions (`.mzML`, `.d`, `.raw`, `.wiff`, `.wiff2`,
`.lcd`, `.chrom`, case-insensitive) are stripped from `analysis_id`.

The same normalization is applied to both the data and the metadata,
which is what lets an `analysis_id` typed into metadata match the one
derived from a data-file name instead of silently failing to join. A
consequence is that two identifiers differing only by whitespace
collapse to one and are then reported as duplicates.

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
#> ✔ Metadata column(s) 'qc_type, batch_id' imported. To ignore, set `import_metadata = FALSE`
#> ✔ Imported 87 analyses with 5 features.
#> Warning: Unknown or uninitialised column: `valid_feature`.
#> Warning: Unknown or uninitialised column: `is_quantifier`.
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
