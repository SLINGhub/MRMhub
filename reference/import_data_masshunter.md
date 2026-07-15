# Import Agilent MassHunter Quantitative Analysis CSV files

Imports .csv files exported from Agilent MassHunter Quantitative
Analysis software, containing peak integration results. The input files
must have anlyses (samples) in rows, features/compounds in columns, and
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

  MRMhubExperiment object

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
  "Calc. Conc." and "Final. Conc." are present. Default is "conc_final".
  Must be one of "conc_calc" or "conc_final" (default).

- silent:

  Logical, whether to suppress most notifications

## Value

MRMhubExperiment object with the imported data

## Examples

``` r
mexp <- MRMhubExperiment()
file_path = system.file("extdata", "MHQuant_demo.csv", package = "mrmhub")

mexp <- import_data_masshunter(
  data = mexp,
  path = file_path,
  import_metadata = TRUE,
  expand_qualifier_names = TRUE)
#> ✔ Imported 38 analyses with 31 features
#> ℹ `feature_area` selected as default feature intensity. Modify with `set_intensity_var()`.
#> ✔ Analysis metadata associated with 38 analyses.
#> ✔ Feature metadata associated with 31 features.

print(mexp)
#> 
#> ── MRMhubExperiment ────────────────────────────────────────────────────────────
#> Title:
#> 
#> Processing status: Annotated raw AREA values
#> 
#> ── Annotated Raw Data ──
#> 
#> • Analyses: 38
#> • Features: 31
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
