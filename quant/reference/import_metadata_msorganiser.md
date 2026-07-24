# Import metadata from a MRMhub Metadata Organizer file

Imports metadata from a 'MRMhub Metadata Organizer' file (.xlsx) file
and associates it with analysis data.

## Usage

``` r
import_metadata_msorganiser(
  data = NULL,
  path,
  ignore_warnings = FALSE,
  excl_unmatched_analyses = FALSE
)
```

## Arguments

- data:

  A
  [`MRMhubExperiment`](https://slinghub.github.io/MRMhub/quant/reference/MRMhubExperiment-class.md)
  object

- path:

  File name and path of the 'MRMhub Metadata Organizer' file (.xlsx)
  file

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

mexp <- import_data_mrmhub(
  data = mexp,
  path = system.file("extdata", "MRMhub_demo.tsv", package = "mrmhub"),
  import_metadata = TRUE)
#> ✔ Imported 499 analyses with 28 features.
#> ℹ feature_area selected as default feature intensity. Modify with `set_intensity_var()`.
#> ✔ Analysis metadata associated with 499 analyses.
#> ✔ Feature metadata associated with 28 features.

mexp <- import_metadata_msorganiser(
 data = mexp,
 path = system.file("extdata", "Example_Metadata_1.xlsx", package = "mrmhub"),
 excl_unmatched_analyses = FALSE,
 ignore_warnings = TRUE)
#> Found no errors, 4 warnings, and no notes in the metadata.
#> ----------------------------------------------------------------------------
#>   Type  Table    Column                Issue                           Count
#> 1 W*    Analyses analysis_id           Analyses not in analysis data      15
#> 2 W*    Features feature_id            Feature(s) without metadata         1
#> 3 W*    Features feature_id            Feature(s) not in analysis data   321
#> 4 W*    ISTDs    quant_istd_feature_id Internal standard(s) not used       2
#> 
#> ----------------------------------------------------------------------------
#> E = Error, W = Warning, W* = Suppressed Warning, N = Note
#> ----------------------------------------------------------------------------
#> ✔ Analysis metadata associated with 499 analyses.
#> ✔ Feature metadata associated with 27 features.
#> ✔ Internal Standard metadata associated with 15 ISTDs.
#> ✔ Response curve metadata associated with 12 annotated analyses.

print(mexp)
#> 
#> ── MRMhubExperiment:  ──────────────────────────────────────────────────────────
#> NA | 499 analyses and 27 features | signal: feature_area
#> Last step: Annotated raw AREA values
#> Normalized ✖ Quantitated ✖ Drift/batch ✖ Filtered ✖
#> ℹ Use `status()` for the full processing and metadata report
```
