# Import Analysis Results from Long Format CSV Files

This function imports analysis results from CSV files in long table
format, where each row represents a unique observation of a
feature-value pair for an analysis (sample), along with associated
feature variables and other metadata. See "Details" below for more
information on using this function.

## Usage

``` r
import_data_csv_long(
  data = NULL,
  path,
  import_metadata = TRUE,
  column_mapping = NULL,
  na_strings = "NA",
  warn_unrecognized_columns = TRUE,
  silent = FALSE
)
```

## Arguments

- data:

  A `MRMhubExperiment` object to which the imported data will be added.

- path:

  A single file path, multiple file paths, or a directory path. If a
  directory is provided, all `*.csv` files within will be imported.

- import_metadata:

  Logical indicating whether to import additional metadata columns
  (e.g., batch ID, sample type) into the `MRMhubExperiment` object.
  Supported metadata column names include `"qc_type"`, `"batch_id"`,
  `"is_quantifier"`, `"is_istd"`, and `"analysis_order"`.

- column_mapping:

  A named character vector mapping internal column names to CSV column
  names. Should include keys such as `"analysis_id"`, `"feature_id"`,
  and feature variable names. If `NULL` (default), the function attempts
  automatic detection.

- na_strings:

  Character vector of strings to interpret as missing values (`NA`).
  Blank fields are always treated as missing.

- warn_unrecognized_columns:

  Logical indicating whether to issue a warning when unknown columns are
  encountered in the dataset.

- silent:

  Logical indicating whether to suppress most notifications and
  messages.

## Value

A `MRMhubExperiment` object containing the imported data.

## Details

When no column mapping is provided via the `column_mapping` argument,
the function will automatically detect and import columns with the
following names:

|                   |                       |          |
|-------------------|-----------------------|----------|
| CSV Column Name   | MRMhub Internal Name  | Required |
| `analysis_id`     | `analysis_id`         | Yes      |
| `feature_id`      | `feature_id`          | Yes      |
| `qc_type`         | `qc_type`             | No       |
| `sample_id`       | `sample_id`           | No       |
| `batch_id`        | `batch_id`            | No       |
| `istd_feature_id` | `istd_feature_id`     | No       |
| `feature_class`   | `feature_class`       | No       |
| `analyte_id`      | `analyte_id`          | No       |
| `precursor_mz`    | `method_precursor_mz` | No       |
| `product_mz`      | `method_product_mz`   | No       |
| `area`            | `feature_area`        | No       |
| `height`          | `feature_height`      | No       |
| `intensity`       | `feature_intensity`   | No       |
| `rt`              | `feature_rt`          | No       |
| `fwhm`            | `feature_fwhm`        | No       |
| `width`           | `feature_width`       | No       |

Detection of these columns is case-insensitive. Additionally, if feature
variable columns use the internal naming convention with prefixes
"feature\_" or "method\_" (e.g. `feature_area` instead of `area`), the
function will detect and import them automatically.

To import data with different column names, provide a named vector
mapping CSV column names to the internal column names used by
`MRMhubExperiment`. The mapping should be in the format:
`c("analysis_id" = "[CSV column name for analysis]", "feature_id" = "[CSV column name for feature]", ...)`,
where the right-hand side refers to the exact column name in the CSV
file header. Columns matching internal names do not require mapping and
will be imported automatically. The mapping is case-insensitive.

Note that the dataset must contain an analysis identifier, either as an
`analysis_id` column or via a mapped column.

The function processes all CSV files in the specified directory or the
given file(s), combining them into a single dataset. This supports
datasets split across multiple files during preprocessing. Each feature
and raw data file pair should appear only once to avoid duplication.

The `na_strings` parameter allows specifying character strings that
should be interpreted as `NA`, ensuring proper handling of missing
values.

## Examples

``` r
file_path <- system.file("extdata", "plain_long_dataset.csv", package = "mrmhub")
mexp <- MRMhubExperiment()

# Define the column mapping; right side is the CSV column name
col_map <- c(
  "analysis_id" = "raw_data_filename",
  "qc_type" = "qc_type",
  "feature_id" = "feature_id",
  "feature_class" = "feature_class",
  "istd_feature_id" = "istd_feature_id",
  "feature_rt" = "rt",
  "feature_area" = "area"
)

mexp <- import_data_csv_long(
  data = mexp,
  path = file_path,
  column_mapping = col_map,
  import_metadata = TRUE
)
#> ! Following unrecognized columns present in the data and were ignored: "internal_standard", "time_stamp", "batch", "sample_type", "precursor_mz", "product_mz", "collision_energy", "polarity", "rt_apex", "area_normalized", "concentration", "height", "fwhm", "rt_int_start", and "rt_int_end".
#> ! Use argument `column_mapping` to define column mapping.
#> ✔ Imported 3 analyses with 4 features
#> ℹ `feature_area` selected as default feature intensity. Modify with `set_intensity_var()`.
#> ✔ Analysis metadata associated with 3 analyses.
#> ✔ Feature metadata associated with 4 features.
#> ℹ Analysis order was based on `analysis_order` column of imported data. Use `set_analysis_order` to change the order.

print(mexp)
#> 
#> ── MRMhubExperiment ────────────────────────────────────────────────────────────
#> Title:
#> 
#> Processing status: Annotated raw AREA values
#> 
#> ── Annotated Raw Data ──
#> 
#> • Analyses: 3
#> • Features: 4
#> • Raw signal used for processing: `feature_area`
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
#> • ISTD quantitated: ✖
#> • Drift corrected variables: ✖
#> • Batch corrected variables: ✖
#> • Feature filtering applied: ✖
#> 
#> ── Exclusion of Analyses and Features ──
#> 
#> • Analyses manually excluded (`analysis_id`): ✖
#> • Features manually excluded (`feature_id`): ✖
```
