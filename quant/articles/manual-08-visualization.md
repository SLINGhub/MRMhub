# Visualisation Functions

MRMhub provides plotting functions covering every stage of the workflow.
All functions return `ggplot2` objects (or, for paged outputs, a list of
`ggplot2` objects), so the standard ggplot2 grammar can be used to
further customise titles, themes, scales, and facets. This reference
groups the functions by the workflow stage at which they are most
useful.

### Setup

``` r

library(mrmhub)
library(ggplot2)

mexp <- readRDS("results/mexp_processed.rds")
```

### Overview

| Function | Stage | Purpose |
|----|----|----|
| [`plot_runsequence()`](https://slinghub.github.io/MRMhub/quant/reference/plot_runsequence.md) | Acquisition design | Run-order overview of QC types and batches |
| [`plot_runscatter()`](https://slinghub.github.io/MRMhub/quant/reference/plot_runscatter.md) | Drift / batch QC | Per-feature scatter of values vs analysis order |
| [`plot_abundanceprofile()`](https://slinghub.github.io/MRMhub/quant/reference/plot_abundanceprofile.md) | Abundance overview | Feature abundance distribution per class |
| [`plot_rla_boxplot()`](https://slinghub.github.io/MRMhub/quant/reference/plot_rla_boxplot.md) | Normalisation QC | Relative log-abundance boxplots per analysis |
| [`plot_normalization_qc()`](https://slinghub.github.io/MRMhub/quant/reference/plot_normalization_qc.md) | Normalisation QC | Before/after ISTD normalisation comparison |
| [`plot_pca()`](https://slinghub.github.io/MRMhub/quant/reference/plot_pca.md) | Multivariate QC | PCA score plot |
| [`plot_pca_loading()`](https://slinghub.github.io/MRMhub/quant/reference/plot_pca_loading.md) | Multivariate QC | PCA loadings |
| [`plot_feature_correlations()`](https://slinghub.github.io/MRMhub/quant/reference/plot_feature_correlations.md) | Multivariate QC | Feature-feature correlation heatmap |
| [`plot_qcmetrics_comparison()`](https://slinghub.github.io/MRMhub/quant/reference/plot_qcmetrics_comparison.md) | QC metrics | CV / bias comparison across QC types |
| [`plot_qc_summary_byclass()`](https://slinghub.github.io/MRMhub/quant/reference/plot_qc_summary_byclass.md) | QC filtering | Pass/fail summary by feature class |
| [`plot_qc_summary_overall()`](https://slinghub.github.io/MRMhub/quant/reference/plot_qc_summary_overall.md) | QC filtering | Pass/fail summary across the whole dataset |
| [`plot_calibrationcurves()`](https://slinghub.github.io/MRMhub/quant/reference/plot_calibrationcurves.md) | External calibration | Calibration curves with fit and residuals |
| [`plot_responsecurves()`](https://slinghub.github.io/MRMhub/quant/reference/plot_responsecurves.md) | Response curves | Linearity check from a dilution series |
| [`plot_rt_vs_chain()`](https://slinghub.github.io/MRMhub/quant/reference/plot_rt_vs_chain.md) | Method check (lipidomics) | RT vs chain length / unsaturation |
| [`plot_matrixeffects()`](https://slinghub.github.io/MRMhub/quant/reference/plot_matrixeffects.md) | Method check | Matrix-effect QC |
| [`plot_interference_correction()`](https://slinghub.github.io/MRMhub/quant/reference/plot_interference_correction.md) | Interference correction | QC overview for interference annotations |

## Acquisition design

### `plot_runsequence()` — sequence overview

The run-sequence plot summarises the acquisition design: QC type
positions, batch boundaries, and the analysis timeline. It is an
experiment-level plot (no per-feature dimension).

``` r

plot_runsequence(mexp,
                 qc_types = NA,
                 show_batches = TRUE,
                 batch_zebra_stripe = TRUE,
                 show_timestamp = FALSE)
```

Set `show_timestamp = TRUE` to use the acquisition timestamp on the
x-axis; this helps identify interruptions between or within batches that
would not be visible against the analysis sequence number.

## Drift, batch, and per-feature inspection

### `plot_runscatter()` — values vs analysis order

The primary plot for drift and batch QC. Plots a feature variable
(intensity, normalised intensity, concentration) against the analysis
order, optionally with fitted drift trends from the correction
functions. Returns one panel per feature (paged).

``` r

plot_runscatter(mexp,
                variable = "norm_intensity",
                qc_types = c("BQC", "SPL"),
                rows_page = 1,
                cols_page = 3,
                show_trend = TRUE)
```

Use `variable = "intensity_before"` / `"conc_before"` to inspect
pre-correction values, and `variable = "intensity"` / `"conc"` for
post-correction. Setting `output_pdf = TRUE` and a `path` writes a
multi-page PDF, which is practical for large feature lists.

### `plot_abundanceprofile()` — feature abundance distribution

Shows the abundance distribution of each feature, grouped by class.
Useful for inspecting class coverage and identifying features at the
limits of the dynamic range.

``` r

plot_abundanceprofile(mexp,
                      variable = "intensity",
                      qc_types = "SPL",
                      log_scale = TRUE)
```

When `use_qc_metrics = TRUE`, the function reads from the pre-computed
`metrics_qc` table (much faster on large feature lists) and `qc_types`
must specify a single QC type.

## Normalisation QC

### `plot_rla_boxplot()` — relative log-abundance per analysis

A boxplot per analysis of `log2(value / median_across_analyses)`. Width
and centring of the box reflect injection-level variability. Useful
before and after normalisation to confirm that ISTD correction removes
injection-level bias.

``` r

plot_rla_boxplot(mexp,
                 variable = "norm_intensity",
                 qc_types = c("BQC", "SPL"))
```

### `plot_normalization_qc()` — before-vs-after comparison

Compares pre- and post-normalisation values for QC samples in three
layouts (`plot_type`): `"scatter"` (point cloud), `"diff"` (signed
difference), `"ratio"` (after / before). CV of QC samples should
decrease after normalisation; an increase typically indicates an
incorrect ISTD pairing.

``` r

plot_normalization_qc(mexp,
                      before_norm_var = "intensity",
                      after_norm_var  = "norm_intensity",
                      plot_type       = "scatter",
                      qc_types        = c("BQC", "SPL"),
                      facet_by_class  = TRUE,
                      cv_threshold_value = 25)
```

## Multivariate QC

### `plot_pca()` — score plot

Two-dimensional PCA score plot with confidence ellipses grouped by
`qc_type`, `batch_id`, or `"none"`. See [QC Exploration with
PCA](https://slinghub.github.io/MRMhub/quant/articles/tutorial-05-run-scatter.md)
for an interpretation walk-through.

``` r

plot_pca(mexp,
         variable          = "norm_intensity",
         qc_types          = c("BQC", "SPL"),
         ellipse_variable  = "qc_type")
```

### `plot_pca_loading()` — loadings

Loadings on the first two PCs. Features at the extremes drive sample
separation; a single feature dominating PC1 should be inspected with
[`plot_runscatter()`](https://slinghub.github.io/MRMhub/quant/reference/plot_runscatter.md)
before being attributed to biology.

``` r

plot_pca_loading(mexp,
                 variable = "norm_intensity",
                 qc_types = c("BQC", "SPL"))
```

### `plot_feature_correlations()` — correlation heatmap

Pairwise correlation matrix across features, useful for identifying
redundant transitions and flagging candidate isobaric interferences.

``` r

plot_feature_correlations(mexp,
                          variable = "norm_intensity",
                          qc_types = "SPL")
```

## QC metrics and filtering

### `plot_qcmetrics_comparison()` — pairwise QC-metric scatter

Plots one QC metric against another, computed across features. The
variable names follow the pattern `{variable}_cv_{qctype}`
(e.g. `intensity_cv_bqc`, `norm_intensity_cv_tqc`) and live in
`mexp@metrics_qc` after
[`calc_qc_metrics()`](https://slinghub.github.io/MRMhub/quant/reference/calc_qc_metrics.md)
is run.

``` r

mexp <- calc_qc_metrics(mexp)

plot_qcmetrics_comparison(mexp,
                          plot_type        = "scatter",
                          x_variable       = "intensity_cv_bqc",
                          y_variable       = "norm_intensity_cv_bqc",
                          equality_line    = TRUE,
                          threshold_values = 25,
                          log_scale        = FALSE)
```

Points below the equality line indicate features for which CV was
reduced by normalisation; points above indicate features made worse,
typically a misassigned ISTD.

### `plot_qc_summary_byclass()` / `plot_qc_summary_overall()` — filter outcome

After
[`filter_features_qc()`](https://slinghub.github.io/MRMhub/quant/reference/filter_features_qc.md),
these two functions summarise how many features passed each filter rule,
broken down by feature class (`_byclass`) or aggregated (`_overall`).

``` r

plot_qc_summary_overall(mexp)
plot_qc_summary_byclass(mexp)
```

## External calibration and response curves

### `plot_calibrationcurves()` — calibration fits

After
[`quantify_by_calibration()`](https://slinghub.github.io/MRMhub/quant/reference/quantify_by_calibration.md),
plots calibration response vs concentration with the fitted model, the
calibration points, and points excluded from the fit. Returns a paged
grid of features.

``` r

plot_calibrationcurves(mexp,
                       variable = "norm_intensity",
                       qc_types = NA)
```

The fit model is taken from the calibration setup unless overridden with
`fit_overwrite = "linear"` or `"quadratic"`.

### `plot_responsecurves()` — RQC linearity

Plots feature response across an RQC dilution series. The fitted slope
and R² values report on the linearity of the assay in the range of the
QC pool. See
[`get_response_curve_stats()`](https://slinghub.github.io/MRMhub/quant/reference/get_response_curve_stats.md)
for the numeric summary.

``` r

plot_responsecurves(mexp,
                    variable = "intensity")
```

## Method-specific checks

### `plot_rt_vs_chain()` — retention time vs chain length (lipidomics)

For lipidomics methods using class-based chromatography, plots RT
against carbon number, separated by class. Outliers from the expected
linear relationship within a class point to mis-identified features.

``` r

plot_rt_vs_chain(mexp)
```

### `plot_matrixeffects()` — matrix-effect overview

Compares ISTD response in matrix-containing QCs against solvent-only
injections to flag matrix-effect outliers.

``` r

plot_matrixeffects(mexp)
```

### `plot_interference_correction()` — interference annotations

QC overview for features with interference annotations (see
[Interference
Correction](https://slinghub.github.io/MRMhub/quant/articles/tutorial-11-interference-correction.md)).

``` r

plot_interference_correction(mexp)
```

## Customisation and export

### ggplot2 layering

All functions return `ggplot2` objects, so themes, scales, and titles
can be appended in the usual way.

``` r

plot_runscatter(mexp, variable = "norm_intensity", qc_types = c("BQC", "SPL")) +
  ggplot2::theme_minimal(base_size = 9) +
  ggplot2::labs(title = "Normalised intensity (BQC vs SPL)")
```

### Saving plots

For a single plot:

``` r

p <- plot_pca(mexp,
              variable = "norm_intensity",
              qc_types = c("BQC", "SPL"),
              ellipse_variable = "batch_id")
ggplot2::ggsave("figures/pca_batch.png", p, width = 8, height = 6, dpi = 300)
```

For paged outputs
([`plot_runscatter()`](https://slinghub.github.io/MRMhub/quant/reference/plot_runscatter.md),
[`plot_calibrationcurves()`](https://slinghub.github.io/MRMhub/quant/reference/plot_calibrationcurves.md)),
use the function’s built-in `output_pdf = TRUE` and `path` arguments to
write a multi-page PDF directly, rather than iterating in user code.

``` r

plot_runscatter(mexp,
                variable   = "norm_intensity",
                qc_types   = c("BQC", "SPL"),
                output_pdf = TRUE,
                path       = "figures/runscatter_all.pdf")
```

### Combining plots

`patchwork` composes multiple panels into a single figure:

``` r

library(patchwork)

p_seq  <- plot_runsequence(mexp)
p_pca  <- plot_pca(mexp, variable = "norm_intensity",
                   qc_types = c("BQC", "SPL"), ellipse_variable = "batch_id")
p_rla  <- plot_rla_boxplot(mexp, variable = "norm_intensity",
                           qc_types = c("BQC", "SPL"))

p_seq / (p_pca | p_rla)
```

### Next steps

- [Exploring QC: RunScatter and
  PCA](https://slinghub.github.io/MRMhub/quant/articles/tutorial-05-run-scatter.md)
  —
  [`plot_runscatter()`](https://slinghub.github.io/MRMhub/quant/reference/plot_runscatter.md),
  [`plot_pca()`](https://slinghub.github.io/MRMhub/quant/reference/plot_pca.md)
  and outlier screening
- [Drift and Batch Correction
  (tutorial)](https://slinghub.github.io/MRMhub/quant/articles/tutorial-04-drift-correction.md)
  —
  [`plot_runscatter()`](https://slinghub.github.io/MRMhub/quant/reference/plot_runscatter.md)
  in context
- [External Calibration & QC
  (recipe)](https://slinghub.github.io/MRMhub/quant/articles/recipe-01-ext-calibration-qc.md)
  — calibration plots in workflow
- [Custom QC Report
  (recipe)](https://slinghub.github.io/MRMhub/quant/articles/recipe-02-custom-qc-report.md)
  — combine plots in a report
