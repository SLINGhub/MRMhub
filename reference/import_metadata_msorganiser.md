# Import Metadata from a MRMhub Metadata Organizer file

Imports metadata from a 'MRMhub Metadata Organizer' file (.xlsm/.xlsx)
file and associates it with analysis data.

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

  A `MRMhubExperiment` object

- path:

  File name and path of the 'MRMhub Metadata Organizer' file
  (.xlsm/.xlsx) file

- ignore_warnings:

  Ignore warnings from data validation and proceed with importing
  metadata

- excl_unmatched_analyses:

  Exclude analyses (samples) that have no matching metadata

## Value

An updated `MRMhubExperiment` object

## Examples

``` r
mexp <- MRMhubExperiment()

mexp <- import_data_mrmhub(
  data = mexp,
  path = system.file("extdata", "MRMhub_demo.tsv", package = "mrmhub"),
  import_metadata = TRUE)
#> ✔ Imported 499 analyses with 28 features
#> ℹ `feature_area` selected as default feature intensity. Modify with `set_intensity_var()`.
#> ✔ Analysis metadata associated with 499 analyses.
#> ✔ Feature metadata associated with 28 features.

mexp <- import_metadata_msorganiser(
 data = mexp,
 path = system.file("extdata", "Example_Metadata_1.xlsm", package = "mrmhub"),
 excl_unmatched_analyses = FALSE,
 ignore_warnings = TRUE)
#> ! Metadata has following warnings and notifications:
#> --------------------------------------------------------------------------------------------
#>   Type Table    Column                Issue                           Count
#> 1 W*   Analyses analysis_id           Analyses not in analysis data      15
#> 2 W*   Features feature_id            Feature(s) not in analysis data   321
#> 3 W*   Features feature_id            Feature(s) without metadata         1
#> 4 W*   ISTDs    quant_istd_feature_id Internal standard(s) not used       2
#> --------------------------------------------------------------------------------------------
#> E = Error, W = Warning, W* = Supressed Warning, N = Note
#> --------------------------------------------------------------------------------------------
#> ✔ Analysis metadata associated with 499 analyses.
#> ✔ Feature metadata associated with 27 features.
#> ✔ Internal Standard metadata associated with 15 ISTDs.
#> ✔ Response curve metadata associated with 12 annotated analyses.

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
#> • Features: 27
#> • Raw signal used for processing: `feature_area`
#> 
#> ── Metadata ──
#> 
#> • Analyses/samples: ✔
#> • Features/analytes: ✔
#> • Internal standards: ✔
#> • Response curves: ✔
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
