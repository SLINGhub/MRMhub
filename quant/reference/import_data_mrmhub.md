# Import MRMhub peak integration results

Imports tabular data files (\*.tsv) generated from `MRMhub` containing
peak integration results. The input files must be in a long format with
columns for the raw data file name, feature ID, peak intensity, and
other arguments Additional information, such as retention time, FWHM,
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

  MRMhubExperiment object

- path:

  One or more file paths, or a directory path (in which case all
  matching files will be imported)

- import_metadata:

  Logical, whether to import additional metadata columns (e.g.,
  `batch_id`, `qc_type`)

- silent:

  Logical, whether to suppress most notifications

## Value

MRMhubExperiment object with the imported data

## Examples

``` r
mexp <- MRMhubExperiment()

file_path = system.file("extdata", "MRMhub_demo.tsv", package = "mrmhub")

mexp <- import_data_mrmhub(
  data = mexp,
  path = file_path,
  import_metadata = TRUE)
#> ✔ Imported 499 analyses with 28 features
#> ℹ `feature_area` selected as default feature intensity. Modify with `set_intensity_var()`.
#> ✔ Analysis metadata associated with 499 analyses.
#> ✔ Feature metadata associated with 28 features.
print(mexp)
#> 
#> ── MRMhubExperiment ────────────────────────────────────────────────────────────
#> Title:
#> 
#> Processing status: Annotated raw AREA values
#> 
#> ── Annotated Raw Data ──
#> 
#> • Analyses: 499
#> • Features: 28
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
