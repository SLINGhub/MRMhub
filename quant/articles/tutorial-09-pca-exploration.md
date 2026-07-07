# QC Exploration with PCA

Principal Component Analysis (PCA) is a routine multivariate check in
targeted MS workflows. In an MRMhub workflow it serves three purposes:
spotting injection outliers, visualising residual batch effects, and
confirming that drift or batch corrections have produced the expected
reduction in unwanted variance.

This tutorial assumes a processed `MRMhubExperiment` with metadata
linked
([`add_metadata()`](https://slinghub.github.io/MRMhub/quant/reference/add_metadata.md)),
ISTD-normalised intensities
([`normalize_by_istd()`](https://slinghub.github.io/MRMhub/quant/reference/normalize_by_istd.md))
and, optionally, drift/batch correction applied. See [The MRMhub
Workflow](https://slinghub.github.io/MRMhub/quant/articles/tutorial-02-basic-workflow.md)
if these steps have not been completed.

**Time:** ~10 min  \|  **Level:** Intermediate  \|  **Prerequisites:**
[Basic
workflow](https://slinghub.github.io/MRMhub/quant/articles/tutorial-02-basic-workflow.md)

## 1. Setup

``` r

library(mrmhub)

# Load a processed experiment (replace with your object)
mexp <- readRDS("results/mexp_processed.rds")
```

## 2. PCA score plot by QC type

The PCA score plot summarises sample variance in two dimensions. As
reference samples, biological QCs (BQC) should cluster tightly near the
centre of the scores plot if normalisation and any corrections
succeeded.

``` r

plot_pca(mexp,
         variable = "norm_intensity",
         qc_types = c("BQC", "TQC", "SPL"),
         ellipse_variable = "qc_type")
```

The `ellipse_variable` controls the grouping of the confidence ellipses
(`qc_type`, `batch_id`, or `"none"`). Study samples (SPL) typically show
wider biological spread; BQC and TQC samples should cluster tighter than
SPL. A markedly dispersed QC cluster suggests insufficient normalisation
or instrument drift remaining in the data.

## 3. PCA score plot by batch

If samples separate along PC1 or PC2 by `batch_id`, batch effects
persist and a centering-based correction is likely warranted.

``` r

plot_pca(mexp,
         variable = "norm_intensity",
         qc_types = c("BQC", "SPL"),
         ellipse_variable = "batch_id")
```

Run the same plot before and after
[`correct_batch_centering()`](https://slinghub.github.io/MRMhub/quant/reference/correct_batch_centering.md)
to confirm that the batch ellipses overlap after correction.

## 4. PCA loadings

The loading plot identifies features driving the principal components.
Features located at the extremes contribute most to sample separation. A
single feature dominating PC1 should be inspected: it is often a
saturated or contaminated transition rather than a biological signal.

``` r

plot_pca_loading(mexp,
                 variable = "norm_intensity",
                 qc_types = c("BQC", "SPL"))
```

## 5. Univariate outlier detection on PC scores

[`detect_outlier_pca()`](https://slinghub.github.io/MRMhub/quant/reference/detect_outlier_pca.md)
flags analyses whose score on a chosen principal component lies outside
a user-defined fence. The fence is defined as either `mean ± k·SD`
(`outlier_detection = "sd"`) or `median ± k·MAD`
(`outlier_detection = "mad"`); `fence_multiplicator` sets *k*.

``` r

outlier_ids <- detect_outlier_pca(
  mexp,
  variable = "norm_intensity",
  filter_data = FALSE,
  pca_component = 1,
  qc_types = c("BQC", "SPL"),
  outlier_detection = "mad",
  fence_multiplicator = 4
)

outlier_ids
```

The function returns a character vector of `analysis_id` values that
exceed the fence on the selected PC, or `NULL` if none are flagged.

**Choice of fence method**

The SD-based fence (`outlier_detection = "sd"`) is sensitive to the very
outliers it tries to detect: a single extreme observation inflates the
SD estimate. The MAD-based fence is robust to a few large deviations and
is generally preferable for QC screening. A typical multiplier is
`fence_multiplicator = 3` (≈99.7% under normality) or `4` for a more
permissive screen. The function evaluates one principal component at a
time — re-run with `pca_component = 2` to screen PC2.

**Important:** A sample flagged by PCA is a candidate for investigation,
not a verdict. Outlier patterns frequently reflect genuine biology
(e.g. a disease group, a sex difference). Only exclude an injection
where a documented technical cause is identified — failed injection,
contamination, instrument fault, or sample-handling error.

## 6. Excluding analyses and features

After visual and documented confirmation, remove the offending
injections or features.
[`exclude_analyses()`](https://slinghub.github.io/MRMhub/quant/reference/exclude_analyses.md)
/
[`exclude_features()`](https://slinghub.github.io/MRMhub/quant/reference/exclude_features.md)
set the affected rows aside for downstream steps; the original data
remain in `mexp@dataset_orig`.

``` r

# Review candidates before excluding
mexp@annot_analyses |>
  dplyr::filter(analysis_id %in% outlier_ids) |>
  dplyr::select(analysis_id, qc_type, batch_id, analysis_order)

# Exclude after technical confirmation
mexp <- exclude_analyses(mexp,
                         analyses = outlier_ids,
                         clear_existing = FALSE)

get_analysis_count(mexp)
```

``` r

# Exclude a known-problematic feature (e.g. saturated transition)
mexp <- exclude_features(mexp,
                         features = c("PC 32:0"),
                         clear_existing = FALSE)

get_feature_count(mexp)
```

Setting `clear_existing = TRUE` replaces any previous exclusion list
rather than appending to it.

## 7. PCA before and after correction

A useful sanity check is to run PCA on the raw and corrected intensities
and compare the spread of the QC and batch groups.

``` r

# Before any correction — switch the working dataset to the original raw values
mexp_raw <- mexp
mexp_raw@dataset <- mexp_raw@dataset_orig
plot_pca(mexp_raw,
         variable = "intensity",
         qc_types = c("BQC", "SPL"),
         ellipse_variable = "batch_id")

# After drift/batch correction (current working dataset)
plot_pca(mexp,
         variable = "norm_intensity",
         qc_types = c("BQC", "SPL"),
         ellipse_variable = "batch_id")
```

After correction, BQC ellipses should contract and batch ellipses should
overlap.

## Interpretation guide

| PCA pattern | Likely cause | Action |
|----|----|----|
| BQC samples dispersed across the score plot | Poor precision; ISTD assignment problem | Inspect [`plot_normalization_qc()`](https://slinghub.github.io/MRMhub/quant/reference/plot_normalization_qc.md); verify ISTD pairing |
| Clear separation by `batch_id` on PC1 or PC2 | Uncorrected batch effect | Apply [`correct_batch_centering()`](https://slinghub.github.io/MRMhub/quant/reference/correct_batch_centering.md) |
| Single injection isolated from all groups | Technical outlier | Investigate cause; exclude only with documented reason |
| One feature dominates loadings on PC1 | Saturation, contamination, or single-transition artefact | Inspect with [`plot_runscatter()`](https://slinghub.github.io/MRMhub/quant/reference/plot_runscatter.md); exclude feature if confirmed |
| BQC tight, SPL spread | Genuine biological variability | Proceed |

## Minimal workflow

``` r

library(mrmhub)
mexp <- readRDS("results/mexp_processed.rds")

# Inspect
plot_pca(mexp, variable = "norm_intensity",
         qc_types = c("BQC", "SPL"), ellipse_variable = "qc_type")
plot_pca(mexp, variable = "norm_intensity",
         qc_types = c("BQC", "SPL"), ellipse_variable = "batch_id")
plot_pca_loading(mexp, variable = "norm_intensity",
                 qc_types = c("BQC", "SPL"))

# Screen for outlier injections
outliers <- detect_outlier_pca(
  mexp, variable = "norm_intensity",
  filter_data = FALSE, pca_component = 1,
  outlier_detection = "mad", fence_multiplicator = 4
)

# Exclude after technical confirmation
if (!is.null(outliers)) {
  mexp <- exclude_analyses(mexp, analyses = outliers, clear_existing = FALSE)
}
```

## Next Steps

- [Drift and Batch Correction
  (reference)](https://slinghub.github.io/MRMhub/quant/articles/manual-07-drift-batch-correction.md)
  — methods used before this PCA check
- [Drift Correction
  (tutorial)](https://slinghub.github.io/MRMhub/quant/articles/tutorial-04-drift-correction.md)
  — how to fit and inspect drift trends
- [Batch Correction
  (tutorial)](https://slinghub.github.io/MRMhub/quant/articles/tutorial-06-batch-correction.md)
  — median-centering across batches
- [Visualisation
  Functions](https://slinghub.github.io/MRMhub/quant/articles/manual-08-visualization.md)
  — full list of plotting functions
