# Import internal standards (ISTD) metadata

Imports ISTD metadata (annotation) from a preloaded data frame or tibble
via the `data` argument, or from data from a file (CSV or Excel) via the
`path` argument. The ISTD metadata must contain following columns:
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

  A
  [`MRMhubExperiment`](https://slinghub.github.io/MRMhub/quant/reference/MRMhubExperiment-class.md)
  object

- table:

  A data frame or tibble with ISTD metadata. If `path` is also provided,
  an error will be raised.

- path:

  A character string specifying the path to a CSV (.csv) or Excel
  (.xlsx) file. If `table` is also provided, an error will be raised.

- sheet:

  Defines the sheet name in case an Excel file is provided.

- ignore_warnings:

  Ignore warnings from data validation and proceed with importing
  metadata

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
