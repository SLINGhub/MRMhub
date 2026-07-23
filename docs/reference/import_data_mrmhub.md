# Import MRMhub peak integration results

Imports tabular data files (\*.tsv) generated from `MRMhub` containing
peak integration results. The input files must be in a long format with
columns for the raw data file name, feature ID, peak intensity, and
other columns. Additional information, such as retention time, FWHM,
precursor/product m/z, and CE will also be imported and made available
in the `MRMhubExperiment` object for downstream analyses.

When a directory path is provided, all matching files in that directory
will be imported and merged into a single dataset. This is useful when
importing datasets that were pre-processed in blocks, resulting in
multiple files. Each unique combination of feature and raw data file
must only occur once across all source data files. Duplicate
combinations will result in an error.

## Usage

``` r
import_data_mrmhub(data = NULL, path, import_metadata = TRUE, silent = FALSE)
```

## Arguments

- data:

  [`MRMhubExperiment`](https://slinghub.github.io/MRMhub/quant/reference/MRMhubExperiment-class.md)
  object

- path:

  One or more file paths, or a directory path (in which case all
  matching files will be imported)

- import_metadata:

  Logical, whether to import additional metadata columns (e.g.,
  `batch_id`, `qc_type`)

- silent:

  Logical, whether to suppress most notifications

## Value

[`MRMhubExperiment`](https://slinghub.github.io/MRMhub/quant/reference/MRMhubExperiment-class.md)
object with the imported data

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

file_path = system.file("extdata", "MRMhub_demo.tsv", package = "mrmhub")

mexp <- import_data_mrmhub(
  data = mexp,
  path = file_path,
  import_metadata = TRUE)
#> ✔ Imported 499 analyses with 28 features.
#> ℹ feature_area selected as default feature intensity. Modify with `set_intensity_var()`.
#> ✔ Analysis metadata associated with 499 analyses.
#> ✔ Feature metadata associated with 28 features.
print(mexp)
#> 
#> ── MRMhubExperiment:  ──────────────────────────────────────────────────────────
#> NA | 499 analyses and 28 features | signal: feature_area
#> Last step: Annotated raw AREA values
#> Normalized ✖ Quantitated ✖ Drift/batch ✖ Filtered ✖
#> ℹ Use `status()` for the full processing and metadata report
```
