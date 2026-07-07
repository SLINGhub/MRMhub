# Multi-Batch Study

**Time:** ~15 min  \|  **Level:** Advanced  \|  **Prerequisites:**
[Basic
workflow](https://slinghub.github.io/MRMhub/quant/articles/tutorial-02-basic-workflow.md)

## Overview

Most targeted MS studies span multiple analytical batches. This tutorial
covers the complete workflow for a 3-batch lipidomics study:

1.  Import data from all batches
2.  Assign analysis order and batch labels
3.  Drift correction within each batch
4.  Batch correction across batches
5.  ISTD normalization and quantification
6.  QC assessment and feature filtering
7.  Export final results

## Scenario

- **3 batches**, each with ~80 samples
- **QC pool** injected every 10 samples within each batch
- **15 lipid features** measured via MRM
- Same QC pool used across all batches

## Step 1: Import and Combine Data

``` r

library(mrmhub)
library(dplyr)

# Import the combined long CSV (all batches in one file)
mexp <- MRMhubExperiment(analysis_type = "lipidomics") |>
  import_data_csv_long(path = "data/study_all_batches.csv")

# Check dimensions
get_analysis_count(mexp)
get_feature_count(mexp)
```

## Step 2: Link Metadata

The analysis annotation must include `batch_id` and `analysis_order`
columns:

``` r

annot <- readr::read_csv("data/annotation_analyses.csv")
feat  <- readr::read_csv("data/annotation_features.csv")
istds <- readr::read_csv("data/annotation_istds.csv")

mexp <- add_metadata(mexp,
                     metadata = list(annot_analyses = annot,
                                     annot_features = feat))
mexp@annot_istds <- istds
```

**Expected annotation structure**

    | analysis_id | qc_type | batch_id | analysis_order |
    |-------------|---------|----------|----------------|
    | Sample_001  | SPL     | Batch_1  | 1              |
    | QC_001      | BQC     | Batch_1  | 2              |
    | Sample_002  | SPL     | Batch_1  | 3              |

See [Sample
Types](https://slinghub.github.io/MRMhub/quant/articles/manual-00-sample-types.md)
for valid `qc_type` labels.

## Step 3: Set Analysis Order

``` r

mexp <- set_analysis_order(mexp)

# Verify batch structure
get_batch_boundaries(mexp)
```

## Step 4: Drift Correction (Within-Batch)

Drift correction models the signal trend using QC samples and removes
systematic within-batch drift.

``` r

# Visualise drift in a representative feature
plot_runscatter(mexp, variable = "intensity", include_feature_filter = "LPC_18:1")

# Apply loess drift correction
mexp <- correct_drift_loess(mexp, variable = "norm_intensity", ref_qc_types = "BQC")
```

**Before vs After comparison**

After correction, QC samples should show a flat trend:

``` r

plot_runscatter(mexp, variable = "intensity", include_feature_filter = "LPC_18:1")
```

If QCs are still trending, consider:

- Increasing loess span (`span = 0.75`)
- Using GAM: `correct_drift_gam(mexp)`
- Checking if you have enough QC points (≥ 5 per batch)

## Step 5: Batch Correction (Between-Batch)

Batch centering aligns the median QC intensity across batches.

``` r

mexp <- correct_batch_centering(mexp, variable = "norm_intensity", ref_qc_types = "BQC")
```

**Validation: QC medians per batch**

``` r

# QC medians per batch should now be approximately equal
get_analyticaldata(mexp, annotated = TRUE) |>
  filter(qc_type == "BQC") |>
  group_by(batch_id, feature_id) |>
  summarise(median_intensity = median(feature_intensity, na.rm = TRUE), .groups = "drop") |>
  tidyr::pivot_wider(names_from = batch_id, values_from = median_intensity)
```

## Step 6: ISTD Normalization and Quantification

``` r

mexp <- normalize_by_istd(mexp)
mexp <- quantify_by_istd(mexp)
```

## Step 7: QC Assessment

``` r

mexp <- calc_qc_metrics(mexp)

# View metrics sorted by worst CV
mexp@metrics_qc |>
  select(feature_id, cv_percent, bias_percent, n_detected) |>
  arrange(desc(cv_percent))
```

| CV Range | Interpretation                      |
|----------|-------------------------------------|
| \< 15%   | Excellent reproducibility           |
| 15–30%   | Acceptable for most applications    |
| \> 30%   | Consider excluding or investigating |

## Step 8: Feature Filtering

``` r

mexp <- filter_features_qc(
  mexp,
  include_qualifier = FALSE,
  include_istd = FALSE,
  max.cv.conc.bqc = 30,
  max.prop.missing.conc.spl = 0.33
)

# The filtered dataset (features passing all QC criteria) is in @dataset_filtered
get_feature_count(mexp)

# Which features failed one or more QC criteria? filter_features_qc() records
# pass/fail in @metrics_qc and keeps only passing features in @dataset_filtered.
# (The @features_excluded slot is populated by exclude_features(), not QC filtering.)
mexp@metrics_qc |>
  filter(!all_filter_pass) |>
  pull(feature_id)
```

## Step 9: Export Final Results

``` r

# Export for downstream analysis
save_dataset_csv(mexp, path = "results/quantified_filtered.csv", variable = "norm_intensity")

# Save the full object for reproducibility
saveRDS(mexp, "results/mexp_processed.rds", compress = TRUE)
```

## Complete Pipeline Summary

``` r

# Full pipeline in one block:
mexp <- MRMhubExperiment(analysis_type = "lipidomics") |>
  import_data_csv_long(path = "data/study_all_batches.csv")
mexp <- add_metadata(mexp, metadata = list(annot_analyses = annot,
                                           annot_features = feat))
mexp@annot_istds <- istds
mexp <- set_analysis_order(mexp)
mexp <- correct_drift_loess(mexp, variable = "norm_intensity", ref_qc_types = "BQC")
mexp <- correct_batch_centering(mexp, variable = "norm_intensity", ref_qc_types = "BQC")
mexp <- normalize_by_istd(mexp)
mexp <- quantify_by_istd(mexp)
mexp <- calc_qc_metrics(mexp)
mexp <- filter_features_qc(mexp, include_qualifier = FALSE, include_istd = FALSE,
                           max.cv.conc.bqc = 30, max.prop.missing.conc.spl = 0.33)
```

## Tips for Multi-Batch Studies

1.  **Always use the same QC pool** across batches; batch correction
    assumes this
2.  **Inject QCs regularly** (every 8–12 samples) for reliable drift
    estimation
3.  **Check QC trends visually** before applying correction; not all
    features drift
4.  **Process all batches together**; QUANT handles batch boundaries
    internally
5.  **Save intermediate objects** with
    [`saveRDS()`](https://rdrr.io/r/base/readRDS.html) at key steps

## Next Steps

- [Drift
  Correction](https://slinghub.github.io/MRMhub/quant/articles/tutorial-04-drift-correction.md)
  — detailed drift correction options
- [Batch
  Correction](https://slinghub.github.io/MRMhub/quant/articles/tutorial-06-batch-correction.md)
  — alternatives to centering
- [External Calibration and
  QC](https://slinghub.github.io/MRMhub/quant/articles/recipe-01-ext-calibration-qc.md)
  — absolute quantification
- [Troubleshooting](https://slinghub.github.io/MRMhub/quant/articles/manual-09-troubleshooting.md)
  — common errors and fixes
