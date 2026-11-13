# Import analysis metadata

Imports analysis metadata (annotation) from a preloaded data frame or
tibble via the `data` argument, or from data from a file (CSV or Excel)
via the `path` argument. The analysis metadata must contain following
columns: `analysis_id` and `qc_type`. Additional analysis metadata
columns are described under details below.

## Usage

``` r
import_metadata_analyses(
  data = NULL,
  table = NULL,
  path = NULL,
  sheet = NULL,
  ignore_warnings = FALSE,
  excl_unmatched_analyses = FALSE
)
```

## Arguments

- data:

  A
  [`MRMhubExperiment`](https://slinghub.github.io/MRMhub/quant/reference/MRMhubExperiment-class.md)
  object

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

- excl_unmatched_analyses:

  Exclude analyses (samples) that have no matching metadata

## Value

An updated
[`MRMhubExperiment`](https://slinghub.github.io/MRMhub/quant/reference/MRMhubExperiment-class.md)
object

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
mexp <- MRMhubExperiment()
file_path = system.file("extdata", "MHQuant_demo.csv", package = "mrmhub")
mexp <- import_data_masshunter(
  data = mexp,
  path = file_path,
  import_metadata = FALSE)
#> ✔ Imported 38 analyses with 31 features.
#> ℹ feature_area selected as default feature intensity. Modify with `set_intensity_var()`.

meta_path = system.file("extdata", "MHQuant_demo_metadata_analyses.csv", package = "mrmhub")

mexp <- import_metadata_analyses(
  data = mexp,
  path = meta_path,
  excl_unmatched_analyses = TRUE)
#> ✔ Analysis metadata associated with 38 analyses.

print(mexp)
#> 
#> ── MRMhubExperiment:  ──────────────────────────────────────────────────────────
#> NA | 38 analyses and 31 features | signal: feature_area
#> Last step: Annotated raw AREA values
#> Normalized ✖ Quantitated ✖ Drift/batch ✖ Filtered ✖
#> ℹ Use `mrmhub_status()` for the full processing and metadata report
```
