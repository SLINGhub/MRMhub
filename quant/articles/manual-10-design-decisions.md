# Design Decisions: Why This Architecture?

## Audience

This article is for:

- Power users who want to understand *why* QUANT works the way it does
- Contributors who want to extend the package
- Developers building tools on top of MRMhub

If you just want to process data, see the [Design
Overview](https://slinghub.github.io/MRMhub/quant/articles/manual-00-architecture.md)
instead.

## Decision 1: S4 Class (MRMhubExperiment) vs Tidy Tibbles

**Choice:** A single S4 object holds all data, metadata, and processing
state.

**Alternatives considered**

| Alternative | Why not |
|----|----|
| Pure tibble workflow (tidyverse) | No built-in integrity checks; too easy to desync data and metadata |
| SummarizedExperiment (Bioconductor) | Requires rectangular matrix; targeted MS data is naturally long with structural missingness |
| R6 class | Less formal than S4; no validity checking; mutable-by-reference is error-prone for data analysis |

**Rationale:**

1.  **Traceability** — The S4 object bundles original data, processed
    data, annotations, and processing flags in one place.

2.  **Integrity checking** — S4 validity methods ensure data and
    metadata stay in sync. You cannot accidentally delete analyses
    without updating annotations.

3.  **Pipeline state** — Flags like `is_istd_normalized`,
    `var_drift_corrected` prevent accidental double-processing.

4.  **Not SummarizedExperiment** — SE requires rectangular matrix layout
    (features × samples). Targeted MS data is naturally long-format with
    varying features per sample and multiple intensity variables per
    measurement.

``` r

# The object structure:
slotNames("MRMhubExperiment")
#>  [1] "title"                "analysis_type"        "feature_intensity_var"
#>  [4] "dataset_orig"         "dataset"              "dataset_filtered"     
#>  [7] "annot_analyses"       "annot_features"       "annot_istds"          
#> [10] "annot_responsecurves" "annot_qcconcentrations" "annot_studysamples"
#> [13] "annot_batches"        "metrics_qc"           "metrics_calibration"  
#> [16] "parameters_processing" "status_processing"   "is_istd_normalized"   
#> [19] "is_quantitated"       "is_filtered"          "has_outliers_tech"    
#> [22] "is_isotope_corr"      "analyses_excluded"    "features_excluded"    
#> [25] "var_drift_corrected"  "var_batch_corrected"
```

## Decision 2: Long-Format Data Exchange

**Choice:** The canonical data exchange format is a long CSV with one
row per feature per sample.

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

``` r

# Expected long format:
# | analysis_id | feature_id | area   | rt   |
# |-------------|------------|--------|------|
# | Sample_001  | LPC_18:1   | 12345  | 2.31 |
# | Sample_001  | LPC_16:0   | 23456  | 1.98 |
# | Sample_002  | LPC_18:1   | 11234  | 2.30 |
```

## Decision 3: Feature Identifiers are Compound-Level

**Choice:** `feature_id` represents a unique compound (or compound +
adduct), not a transition.

**Alternatives considered**

| Alternative | Why not |
|----|----|
| Transition-level IDs | Creates many-to-one mapping for quantification; complicates normalization and reporting |
| Compound + transition as composite key | Over-complex for downstream stats; INTEGRATOR already selects best quantifier |

**Rationale:** In MRM, a compound may have multiple transitions
(quantifier + qualifiers). Peak integration (in INTEGRATOR) selects the
best quantifier. By the time data reaches QUANT, each feature is one
number per sample.

## Decision 4: Immutable Original Data

**Choice:** `dataset_orig` is never modified after import. All
processing operates on `dataset`.

**Why this matters**

- **Reproducibility:** re-run any step without re-importing
- **Debugging:** compare original vs processed to verify corrections
- **Auditability:** the raw data is always accessible for review

``` r

# You can always reset:
mexp@dataset <- mexp@dataset_orig

# Or compare before/after:
original <- mexp@dataset_orig |> dplyr::filter(feature_id == "LPC_18:1")
processed <- mexp@dataset |> dplyr::filter(feature_id == "LPC_18:1")
```

## Decision 5: QC-Centric Correction

**Choice:** Drift and batch correction are exclusively based on QC
samples, never study samples.

**Alternatives considered**

| Alternative | Why not |
|----|----|
| Study sample–based correction (e.g., median centering on all) | Removes real biological signal |
| External reference only | Not always available; less responsive to within-run drift |

Reference: Broadhurst et al. (2018). *Metabolomics*, 14, 72.

**Implication:** You must have sufficient QC samples (≥ 5 per batch,
evenly distributed) for correction to work well.

## Decision 6: Explicit Processing Order

**Choice:** Functions should be called in a specific order. The package
communicates via status flags rather than enforcing with hard errors.

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

**Why not enforce strict order?**

- Some workflows skip steps (no ISTD, no drift correction)
- Researchers need flexibility to experiment
- Hard errors would frustrate exploratory analysis
- Status flags provide guidance without blocking

## Decision 7: Separation of INTEGRATOR and QUANT

**Choice:** Raw data processing (peak integration) and post-processing
(normalization, QC) are separate tools in different languages.

| INTEGRATOR (Python)       | QUANT (R)                |
|---------------------------|--------------------------|
| Automated, batch-oriented | Interactive, exploratory |
| Computationally intensive | Statistically intensive  |
| Run once per study        | Run iteratively          |
| No user decisions needed  | Many user decisions      |

**The interface is a CSV file.** This means either tool can be replaced
independently, and data can be inspected at the handoff point.

## Extending MRMhub

**Guidelines for new functions**

All functions should:

1.  Accept `MRMhubExperiment` as first argument
2.  Return `MRMhubExperiment` (for pipeline functions) or a result
    object
3.  Update relevant status flags
4.  Not modify `dataset_orig`

| Extension type | Pattern |
|----|----|
| New correction method | `R/correct-*.R` — takes and returns `MRMhubExperiment` |
| New importer | Add `parse_*` function, register in `import_data_main()` |
| New plot | Follow `R/plots-*.R` — takes mexp, returns ggplot |
| New QC metric | Extend [`calc_qc_metrics()`](https://slinghub.github.io/MRMhub/quant/reference/calc_qc_metrics.md) or add a helper |

## References

- Broadhurst et al. (2018). Guidelines and considerations for the use of
  system suitability and quality control samples in mass spectrometry
  assays. *Metabolomics*, 14, 72.

## Next Steps

- [Design
  Overview](https://slinghub.github.io/MRMhub/quant/articles/manual-00-architecture.md)
  — the pipeline at a high level
- [Data
  Structures](https://slinghub.github.io/MRMhub/quant/articles/manual-01-data-structure.md)
  — detailed slot documentation
- [MRMhubExperiment
  Object](https://slinghub.github.io/MRMhub/quant/articles/manual-04-mrmhub-experiment.md)
  — creating and using the object
