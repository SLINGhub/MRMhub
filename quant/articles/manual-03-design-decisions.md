# Design decisions behind MRMhub QUANT

Manual

This article documents the main architectural choices behind MRMhub
QUANT and the reasoning for each. It is written for contributors and for
users who want to understand how the package is structured before
extending it. For a task-oriented introduction to running an analysis,
see [Your first
analysis](https://slinghub.github.io/MRMhub/quant/articles/tutorial-00-first-analysis.md).

## One S4 object holds data, metadata, and state

All data, metadata, and processing state for an experiment live in a
single S4 object, `MRMhubExperiment`, rather than in loose tibbles
passed between functions.

**Alternatives considered**

| Alternative | Why not |
|----|----|
| Pure tibble workflow (tidyverse) | No built-in integrity checks; too easy to desync data and metadata |
| SummarizedExperiment (Bioconductor) | Models a feature × sample matrix, not a processing pipeline: no *typed* home for the original data, the processing state, or the non-rectangular annotation tables. Supported as an **export target** instead |
| R6 class | Less formal than S4; no validity checking; mutable-by-reference is error-prone for data analysis |

Three properties motivate this. The object keeps the original data, the
processed data, the annotation tables, and the processing flags
together, so an analysis is traceable from raw import to final result.
S4 validity methods check that data and metadata stay consistent, so
analyses cannot be dropped from `dataset` without the corresponding
annotations being accounted for. And the status flags
(`is_istd_normalized`, `var_drift_corrected`, and the rest) record what
has been applied, which lets later functions detect and refuse
accidental double-processing.

QUANT does not use `SummarizedExperiment` as its internal
representation, though it exports to one. SE models a feature × sample
matrix and offers no typed home for `dataset_orig`, for the processing
state, or for the annotation tables that are not one row per feature
(`annot_responsecurves`, `annot_qcconcentrations`,
`metrics_calibration`); those can only ride along in an untyped
`metadata()` list. While `colData` can carry `qc_type` and `batch_id`,
no Bioconductor class models them, nor calibration curves or
internal-standard relationships. The distinction concerns only the
internal representation: once an experiment is processed,
[`save_dataset_summarizedexperiment()`](https://slinghub.github.io/MRMhub/quant/articles/tutorial-08-summarizedexperiment.md)
hands it to the Bioconductor ecosystem (`limma`, `lipidr`, `POMA`),
where the several parallel intensity variables map onto parallel assays.

``` r

# The object structure:
slotNames("MRMhubExperiment")
#>  [1] "title"                  "analysis_type"          "feature_intensity_var"
#>  [4] "conc_analyte_unit"      "dataset_orig"           "dataset"
#>  [7] "dataset_filtered"       "annot_analyses"         "annot_features"
#> [10] "annot_istds"            "annot_responsecurves"   "annot_qcconcentrations"
#> [13] "annot_studysamples"     "annot_batches"          "annot_interferences"
#> [16] "metrics_qc"             "metrics_calibration"    "status_processing"
#> [19] "is_istd_normalized"     "is_quantitated"         "is_filtered"
#> [22] "is_isotope_corr"        "analyses_excluded"      "features_excluded"
#> [25] "var_drift_corrected"    "var_batch_corrected"
```

## Long-format data exchange

The canonical exchange format between INTEGRATOR and QUANT is a long CSV
with one row per feature per sample.

**Alternatives considered**

| Alternative | Why not |
|----|----|
| Wide format (features as columns) | Scales poorly with many features; ambiguous NA meaning; awkward for filtering |
| HDF5 / Parquet | Adds binary dependency; not human-inspectable at handoff point |
| Database (SQLite) | Overkill for typical study sizes; adds complexity |

| Long format                               | Wide format                     |
|-------------------------------------------|---------------------------------|
| Handles variable feature counts naturally | Requires NA padding             |
| Easy to filter, group, join               | Awkward for row-wise operations |
| Natural for ggplot2                       | Requires pivot before plotting  |
| Explicit about missing vs zero            | Ambiguous NA meaning            |

Long format handles a variable number of features per study without NA
padding, is straightforward to filter, group, and join, and feeds
directly into ggplot2 without an intermediate pivot. It also keeps the
distinction between a missing value and a true zero explicit.

``` r

# Expected long format:
# | analysis_id | feature_id | area   | rt   |
# |-------------|------------|--------|------|
# | Sample_001  | LPC_18:1   | 12345  | 2.31 |
# | Sample_001  | LPC_16:0   | 23456  | 1.98 |
# | Sample_002  | LPC_18:1   | 11234  | 2.30 |
```

## Feature and analyte as distinct identifiers

`feature_id` identifies a distinct signal extracted from the MS data;
`analyte_id` identifies the compound that signal measures. The two are
kept separate because they are not one-to-one.

**Alternatives considered**

| Alternative | Why not |
|----|----|
| A single ID equating feature and compound | Cannot express one analyte measured by several features, nor one feature shared by isobaric analytes |
| Transition-level IDs only | Loses the compound-level grouping needed for QC concentrations and reporting |

One analyte can produce several features (isotopes, adducts,
transitions), and one feature can carry several analytes when they are
isobaric or isomeric, as with SM and PC species. INTEGRATOR selects one
quantifier signal per feature, so by the time data reaches QUANT each
`feature_id` holds one value per sample, while `analyte_id` links the
features that measure the same compound.

## Immutable original data

`dataset_orig` is never modified after import; all processing operates
on `dataset`. Keeping the imported data untouched means any step can be
re-run without re-importing, the processed values can be compared
against the originals to verify a correction, and the raw data remains
available for review at any point.

``` r

# You can always reset:
mexp@dataset <- mexp@dataset_orig

# Or compare before/after:
original <- mexp@dataset_orig |> dplyr::filter(feature_id == "LPC_18:1")
processed <- mexp@dataset |> dplyr::filter(feature_id == "LPC_18:1")
```

## QC-based drift and batch correction

Drift and batch corrections are typically fitted on QC samples; the
gaussian-kernel method is the exception, fitting on study samples for
large, well-randomised cohorts.

**Alternatives considered**

| Alternative | Why not |
|----|----|
| Study sample–based correction (e.g., median centering on all) | Removes real biological signal |
| External reference only | Not always available; less responsive to within-run drift |

Reference: Broadhurst et al. (2018). *Metabolomics*, 14, 72.

Fitting on study samples would remove real biological variation together
with the analytical trend, and an external reference alone is not always
available and responds poorly to within-run drift. Fitting on QC samples
therefore requires enough of them per batch (as a rule of thumb at least
five, evenly distributed across the run) for the correction to be
stable.

## Processing order by convention, not enforcement

Functions are intended to be called in a set order, but the package
signals that order through status flags rather than enforcing it with
hard errors.

``` r

# Recommended order:
# 1. import
# 2. add_metadata
# 3. set_analysis_order
# 4. normalize_by_istd
# 5. correct_drift_*
# 6. correct_batch_*
# 7. quantify_by_*
# 8. calc_qc_metrics
# 9. filter_features_qc
```

Strict enforcement is avoided because valid workflows legitimately skip
steps: an assay without internal standards omits normalization, and a
short single-batch run needs no drift correction. Hard errors would
obstruct such exploratory reprocessing. The status flags record what has
run and let each function warn when a prerequisite is missing, without
blocking.

## Separation of INTEGRATOR and QUANT

Raw-data processing (peak detection and integration) and post-processing
(normalization, quantitation, QC) are separate tools written in
different languages.

| INTEGRATOR                | QUANT (R)                |
|---------------------------|--------------------------|
| Automated, batch-oriented | Interactive, exploratory |
| Computationally intensive | Statistically intensive  |
| Run once per study        | Run iteratively          |
| No user decisions needed  | Many user decisions      |

The interface between them is a CSV file, so either tool can be replaced
independently and the data can be inspected at the handoff point.

## Why QUANT is an R package

QUANT is implemented in R rather than Python because the bulk of its
work is statistical and visual: smoothing, robust regression,
multivariate QC, and ggplot2-driven inspection plots. R provides
established, audit-friendly implementations of these primitives (loess,
cubic splines, `prcomp`, kernel smoothers) and a large neighbouring
ecosystem (`tidyverse`, Bioconductor, `shiny`) familiar to most academic
mass spectrometry and bioinformatics groups. Literate `.Rmd` / `.qmd`
notebooks make the final analysis self-documenting: the same file
produces the figures, the report, and the audit trail.

## Extending MRMhub

All processing functions follow the same contract: they take an
`MRMhubExperiment` as the first argument, return an `MRMhubExperiment`
(pipeline functions) or a result object, update the relevant status
flags, and never modify `dataset_orig`. New code extends one of a few
established patterns.

| Extension type | Pattern |
|----|----|
| New correction method | `R/correct-*.R`: takes and returns `MRMhubExperiment` |
| New importer | Add `parse_*` function, register in `import_data_main()` |
| New plot | Follow `R/plots-*.R`: takes mexp, returns ggplot |
| New QC metric | Extend [`calc_qc_metrics()`](https://slinghub.github.io/MRMhub/quant/reference/calc_qc_metrics.md) or add a helper |

## References

- Broadhurst et al. (2018). Guidelines and considerations for the use of
  system suitability and quality control samples in mass spectrometry
  assays. *Metabolomics*, 14, 72.

## Next steps

- [The MRMhubExperiment data
  object](https://slinghub.github.io/MRMhub/quant/articles/manual-02-data-object.md):
  the object and its slots in detail
- [MRMhub
  overview](https://slinghub.github.io/MRMhub/quant/articles/manual-01-key-concepts.md):
  the vocabulary used throughout
- [Drift and batch
  correction](https://slinghub.github.io/MRMhub/quant/articles/manual-07-corrections.md):
  the QC-based correction in practice
