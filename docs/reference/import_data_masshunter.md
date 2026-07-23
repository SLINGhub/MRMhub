# Import Agilent MassHunter Quantitative Analysis CSV files

Imports .csv files exported from Agilent MassHunter Quantitative
Analysis software, containing peak integration results. The input files
must have analyses (samples) in rows, features/compounds in columns, and
either peak areas, peak heights, or response as the values. Additional
columns, such as retention time (RT), full-width at half-maximum (FWHM),
precursor m/z (PrecursorMZ), and collision energy (CE), will also be
imported and made available in the `MRMhubExperiment` object for
downstream analyses.

When a directory path is provided, all matching .csv files in that
directory will be imported and merged into a single dataset. This is
useful when importing datasets that were pre-processed in blocks,
resulting in multiple files. Each unique combination of feature and raw
data file must only occur once across all source data files. Duplicate
combinations will result in an error.

## Usage

``` r
import_data_masshunter(
  data = NULL,
  path,
  import_metadata = TRUE,
  expand_qualifier_names = TRUE,
  conc_column = "conc_final",
  silent = FALSE
)
```

## Arguments

- data:

  [`MRMhubExperiment`](https://slinghub.github.io/MRMhub/quant/reference/MRMhubExperiment-class.md)
  object

- path:

  One or more file paths, or a directory path (in which case all
  matching files will be imported)

- import_metadata:

  Logical, whether to extract and add metadata from the analysis result
  file

- expand_qualifier_names:

  Logical, whether to add the quantifier name in front of the qualifier
  name (the latter only has the m/z transition values)

- conc_column:

  Which concentration field of the masshunter data to use, in case
  "Calc. Conc." and "Final Conc" are present. Default is "conc_final".
  Must be one of "conc_calc" or "conc_final" (default).

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
file_path = system.file("extdata", "MHQuant_demo.csv", package = "mrmhub")

mexp <- import_data_masshunter(
  data = mexp,
  path = file_path,
  import_metadata = TRUE,
  expand_qualifier_names = TRUE)
#> ✔ Imported 38 analyses with 31 features.
#> ℹ feature_area selected as default feature intensity. Modify with `set_intensity_var()`.
#> ✔ Analysis metadata associated with 38 analyses.
#> ✔ Feature metadata associated with 31 features.

print(mexp)
#> 
#> ── MRMhubExperiment:  ──────────────────────────────────────────────────────────
#> NA | 38 analyses and 31 features | signal: feature_area
#> Last step: Annotated raw AREA values
#> Normalized ✖ Quantitated ✖ Drift/batch ✖ Filtered ✖
#> ℹ Use `status()` for the full processing and metadata report
```
