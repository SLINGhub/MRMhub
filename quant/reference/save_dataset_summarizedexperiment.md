# Export an experiment to a Bioconductor SummarizedExperiment

Converts an
[`MRMhubExperiment`](https://slinghub.github.io/MRMhub/quant/reference/MRMhubExperiment-class.md)
to a
[SummarizedExperiment](https://bioconductor.org/packages/SummarizedExperiment/),
the Bioconductor container for feature x sample data, and optionally to
a `LipidomicsExperiment` for use with [lipidr](https://www.lipidr.org).
This opens the experiment to the Bioconductor ecosystem - `limma` for
differential abundance, `POMA` and `pmp` for preprocessing.

## Usage

``` r
save_dataset_summarizedexperiment(
  data = NULL,
  path = NULL,
  variable = NULL,
  as = c("SummarizedExperiment", "LipidomicsExperiment"),
  filter_data = FALSE,
  overwrite = TRUE
)
```

## Arguments

- data:

  An
  [`MRMhubExperiment`](https://slinghub.github.io/MRMhub/quant/reference/MRMhubExperiment-class.md)
  object.

- path:

  Optional file path. When given, the object is written there with
  [`saveRDS()`](https://rdrr.io/r/base/readRDS.html) and returned
  invisibly; a `.rds` extension is appended if missing. When `NULL`
  (default) the object is returned.

- variable:

  Feature variables to export as assays, e.g. `"conc"` or
  `c("intensity", "conc")`. `NULL` (default) exports every `feature_*`
  variable present in the data.

- as:

  Class to produce. `"SummarizedExperiment"` (default) or
  `"LipidomicsExperiment"`, which additionally requires the `lipidr`
  package and is only meaningful for lipidomics data.

- filter_data:

  Use QC-filtered data (`dataset_filtered`, see
  [`filter_features_qc()`](https://slinghub.github.io/MRMhub/quant/reference/filter_features_qc.md))
  instead of the full dataset. Default `FALSE`.

- overwrite:

  Overwrite an existing file at `path`. Default `TRUE`.

## Value

A `SummarizedExperiment` (or `LipidomicsExperiment`). Returned invisibly
when `path` is given.

## Details

**Layout.** Features are rows and analyses are columns, following the
SummarizedExperiment convention. Each feature variable becomes one
assay, so `feature_intensity`, `feature_norm_intensity` and
`feature_conc` sit side-by-side in the same object and are addressed
with `SummarizedExperiment::assay(se, "conc")`. Assay names drop the
`feature_` prefix. `annot_features` becomes `rowData()`,
`annot_analyses` becomes `colData()`, and the processing state (status,
flags, concentration unit) becomes `metadata()`.

**Everything is exported.** Internal standards, QC samples, blanks and
calibrants are all included and flagged rather than dropped, because
downstream tools need them: `lipidr` requires the `istd` annotation and
`pmp`'s blank filter needs blanks present. Subset when you need to:

    se[!rowData(se)$is_istd, se$qc_type == "SPL"]

Most statistical tools will otherwise happily include blanks and
calibrants and return nonsense.

**QC metrics** are not written to `rowData()`. To filter features by QC
criteria, use
[`filter_features_qc()`](https://slinghub.github.io/MRMhub/quant/reference/filter_features_qc.md)
and export with `filter_data = TRUE`.
[`save_feature_qc_metrics()`](https://slinghub.github.io/MRMhub/quant/reference/save_feature_qc_metrics.md)
exports the metrics themselves.

## References

Morgan M, Obenchain V, Hester J, & Pagès H (2026). SummarizedExperiment:
A container (S4 class) for matrix-like assays. R package version 1.42.0.
[doi:10.18129/B9.bioc.SummarizedExperiment](https://doi.org/10.18129/B9.bioc.SummarizedExperiment)
<https://bioconductor.org/packages/SummarizedExperiment>

Mohamed A, Molendijk J, & Hill MM (2020). lipidr: A Software Tool for
Data Mining and Analysis of Lipidomics Datasets. *Journal of Proteome
Research*, 19(7), 2890-2897.
[doi:10.1021/acs.jproteome.0c00082](https://doi.org/10.1021/acs.jproteome.0c00082)

## See also

[`save_dataset_csv()`](https://slinghub.github.io/MRMhub/quant/reference/save_dataset_csv.md),
[`save_dataset_mztab()`](https://slinghub.github.io/MRMhub/quant/reference/save_dataset_mztab.md),
[`save_report_xlsx()`](https://slinghub.github.io/MRMhub/quant/reference/save_report_xlsx.md)

## Examples

``` r
mexp <- normalize_by_istd(lipidomics_dataset)
#> ! Interfering features defined in metadata, but no correction was applied. Use `correct_custom_interferences()` to correct.
#> ✔ 20 features normalized with 9 ISTDs in 499 analyses.
mexp <- quantify_by_istd(mexp)
#> ✔ 20 feature concentrations calculated based on 9 ISTDs and sample amounts of 499 analyses.
#> ✔ Concentrations are given in μmol/L.

se <- save_dataset_summarizedexperiment(mexp)
SummarizedExperiment::assayNames(se)
#> [1] "rt"             "area"           "height"         "fwhm"          
#> [5] "width"          "intensity"      "norm_intensity" "pmol_total"    
#> [9] "conc"          

# study samples only, internal standards dropped
se[!SummarizedExperiment::rowData(se)$is_istd, se$qc_type == "SPL"]
#> class: SummarizedExperiment 
#> dim: 20 374 
#> metadata(11): title analysis_type ... var_batch_corrected
#>   mrmhub_version
#> assays(9): rt area ... pmol_total conc
#> rownames(20): CE 18:1 Cer d18:1/16:0 ... TG 48:2 [-18:1] TG 48:2 [SIM]
#> rowData names(18): feature_id feature_class ... remarks feature_label
#> colnames(374): Longit_batch1_1 Longit_batch1_2 ... Longit_batch6_52
#>   Longit_batch6_53
#> colData names(13): analysis_order analysis_id ... annot_order_num
#>   remarks
```
