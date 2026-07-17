# Export to Bioconductor (SummarizedExperiment)

Recipe

**Level** Intermediate  ·  **Output** A `SummarizedExperiment` object
 ·  **Requires** a processed `MRMhubExperiment`, the
`SummarizedExperiment` package

## Goal

Hand a processed experiment to the Bioconductor ecosystem.
[SummarizedExperiment](https://bioconductor.org/packages/SummarizedExperiment/)
is the standard container for feature × sample data, and is the entry
point for `limma` (differential abundance), `POMA` and `pmp`
(preprocessing), `ComplexHeatmap` (visualization) and `lipidr`
(lipid-specific analysis).

`MRMhubExperiment` remains the authoritative processing record. The
export is a one-way hand-off at the end of the pipeline: no Bioconductor
class models calibration curves, internal-standard relationships, QC
types or batches, which is exactly what `mrmhub` exists to handle. See
[Design
Decisions](https://slinghub.github.io/MRMhub/quant/articles/manual-03-design-decisions.md)
for why the internal representation stays long-format.

## Prerequisites

``` r

library(mrmhub)
library(SummarizedExperiment)

# A processed MRMhubExperiment. Here built from the bundled `lipidomics_dataset`;
# in practice this would be your own processed object.
mexp <- lipidomics_dataset |>
  normalize_by_istd() |>
  quantify_by_istd()
```

`SummarizedExperiment` is a Bioconductor package. Install it once with:

``` r

# install.packages("BiocManager")
BiocManager::install("SummarizedExperiment")
```

## Basic export

``` r

se <- save_dataset_summarizedexperiment(mexp)
se
#> class: SummarizedExperiment
#> dim: 29 499
#> metadata(11): title analysis_type ... var_batch_corrected mrmhub_version
#> assays(9): rt area ... pmol_total conc
#> rownames(29): CE 18:1 CE 18:1 d7 (ISTD) ... TG 48:2 [-18:1] TG 48:2 [SIM]
#> rowData names(17): feature_id feature_class ... remarks feature_label
#> colnames(499): Longit_BLANK-01 (Eluent A) ... Longit_BLANK-07 (Eluent A)
#> colData names(13): analysis_order analysis_id ... annot_order_num remarks
```

Pass a `path` to also write the object to disk as an `.rds`; without
one, the object is simply returned:

``` r

save_dataset_summarizedexperiment(mexp, "experiment.rds")
```

## Anatomy of the exported object

Features are **rows** and analyses are **columns**, per the
SummarizedExperiment convention.

| Component | mrmhub source |
|----|----|
| [`assays()`](https://rdrr.io/pkg/SummarizedExperiment/man/SummarizedExperiment-class.html) | one matrix per feature variable, named without the `feature_` prefix |
| [`rowData()`](https://rdrr.io/pkg/SummarizedExperiment/man/SummarizedExperiment-class.html) | `annot_features` — one row per `feature_id` |
| [`colData()`](https://rdrr.io/pkg/SummarizedExperiment/man/SummarizedExperiment-class.html) | `annot_analyses` — one row per `analysis_id` |
| `metadata()` | title, analysis type, processing status, `is_*` flags, concentration unit, `mrmhub` version |

The parallel feature variables become **parallel assays**, so raw,
normalized and quantified values live side-by-side in one object:

``` r

assayNames(se)
#> [1] "rt"     "area"   "height" "fwhm"   "width"  "intensity"
#> [7] "norm_intensity" "pmol_total" "conc"

assay(se, "conc")[1:3, 1:2]
```

Export a subset with `variable`:

``` r

se_conc <- save_dataset_summarizedexperiment(mexp, variable = "conc")
se_two <- save_dataset_summarizedexperiment(mexp, variable = c("intensity", "conc"))
```

To export QC-filtered data instead of the full dataset, filter first and
pass `filter_data = TRUE`:

``` r

mexp_filt <- mexp |>
  calc_qc_metrics() |>
  filter_features_qc(
    include_qualifier = FALSE,
    include_istd = FALSE,
    max.cv.conc.bqc = 25
  )

se_filt <- save_dataset_summarizedexperiment(mexp_filt, filter_data = TRUE)
```

## Subsetting: study samples only

**Everything is exported** — internal standards, QC samples, blanks and
calibrants are all present and flagged rather than dropped, because
downstream tools need them (`lipidr` requires the internal-standard
annotation, and `pmp`’s blank filter needs blanks). Subsetting is one
line:

``` r

se_spl <- se[!rowData(se)$is_istd, se$qc_type == "SPL"]
dim(se_spl)
#> [1]  20 374
```

**Subset before any statistical analysis.** Most tools will cheerfully
include blanks, calibrants and QC replicates in a PCA, a normalization
or a differential test and return results that look plausible and mean
nothing. Nothing downstream understands `qc_type`.

QC metrics are deliberately *not* written to
[`rowData()`](https://rdrr.io/pkg/SummarizedExperiment/man/SummarizedExperiment-class.html)
— nothing downstream reads them, and QC filtering belongs in `mrmhub`
where it is tested. Use `filter_data = TRUE` as above, or
[`save_feature_qc_metrics()`](https://slinghub.github.io/MRMhub/quant/reference/save_feature_qc_metrics.md)
for the metrics themselves. If you do want them alongside the features:

``` r

rowData(se) <- cbind(
  rowData(se),
  mexp_filt@metrics_qc[match(rownames(se), mexp_filt@metrics_qc$feature_id), ]
)
```

## Differential abundance with limma

[limma](https://bioconductor.org/packages/limma/) works directly on
continuous data such as concentrations. Note that
[`voom()`](https://rdrr.io/pkg/limma/man/voom.html) is **not** used: it
models count data and is invalid here.

The bundled `lipidomics_dataset` carries no phenotype — every study
sample is plasma from the same longitudinal series. The grouping below
is **simulated to demonstrate the interface only**; the p-values are
meaningless by construction. With your own data, the group would come
from your sample metadata and already be present in
[`colData()`](https://rdrr.io/pkg/SummarizedExperiment/man/SummarizedExperiment-class.html).

``` r

library(limma)

set.seed(1)
se_spl$group <- factor(sample(c("ctrl", "trt"), ncol(se_spl), replace = TRUE))

# log-transform: concentrations are right-skewed and limma assumes normality
y <- log2(assay(se_spl, "conc"))

design <- model.matrix(~ 0 + group, data = colData(se_spl))
colnames(design) <- levels(se_spl$group)

fit <- lmFit(y, design)
fit <- contrasts.fit(fit, makeContrasts(trt - ctrl, levels = design))
fit <- eBayes(fit)

topTable(fit, number = 5)
#>                      logFC   AveExpr        t    P.Value adj.P.Val         B
#> LPC 18:1 (a)    0.09562082 -7.678714 1.672959 0.09516504 0.4750705 -4.212455
#> TG 48:2 [SIM]   0.22391165 -3.283165 1.660831 0.09757883 0.4750705 -4.225380
#> TG 48:1 [SIM]   0.22768141 -3.357736 1.616869 0.10674305 0.4750705 -4.271461
#> TG 48:1 [-18:1] 0.21339199 -4.809001 1.533404 0.12601528 0.4750705 -4.355608
#> TG 48:2 [-16:0] 0.20881625 -4.975439 1.480413 0.13959852 0.4750705 -4.406757
```

Because
[`colData()`](https://rdrr.io/pkg/SummarizedExperiment/man/SummarizedExperiment-class.html)
carries the full analysis annotation, covariates are available without
extra joins — for example blocking on batch:

``` r

design <- model.matrix(~ 0 + group + batch_id, data = colData(se_spl))
```

## Lipid-specific analysis with lipidr

[lipidr](https://www.lipidr.org) works on a `LipidomicsExperiment`, a
subclass of `SummarizedExperiment`. Produce one directly:

``` r

le <- save_dataset_summarizedexperiment(
  mexp,
  variable = "intensity",
  as = "LipidomicsExperiment"
)
```

`mrmhub` fills in what lipidr requires: `Molecule` from `feature_id`,
`Class` from the curated `feature_class`, `istd` from `is_istd`, plus
the `summarized` and per-assay `logged` / `normalized` flags that lipidr
reads but does **not** validate — an object missing them constructs
cleanly and then misbehaves.

Using `feature_class` rather than lipidr’s own name parser also keeps
the class assignment correct for mrmhub’s isobaric
(`PC 28:0|SM 32:1 M+3`) and neutral-loss (`PE P-16:0/18:1 [-FA]`)
naming, which lipidr cannot parse.

**Use a peak-area scale variable with lipidr, not concentrations.**
lipidr log-transforms with `log = TRUE` by default and **clamps values
below 1 to 1** first, which assumes Skyline peak-area magnitudes.
Concentrations in µmol/L are mostly below 1, so they are silently
flattened to `log2(1) = 0` —
[`eBayes()`](https://rdrr.io/pkg/limma/man/ebayes.html) then reports
zero residual variances and every fold change collapses. `mrmhub` warns
when you export a mostly-sub-1 assay this way.

The cause is unit scale, not concentration as such: the same values in
nmol/L pass through untouched. If you need concentrations, pass
`log = FALSE` to lipidr, or log-transform them yourself beforehand.

``` r

library(lipidr)

le_spl <- le[!rowData(le)$istd, le$qc_type == "SPL"]
set.seed(1)
le_spl$group <- factor(sample(c("ctrl", "trt"), ncol(le_spl), replace = TRUE))

plot_samples(le_spl, type = "boxplot", measure = "intensity")

le_norm <- normalize_pqn(le_spl, measure = "intensity", log = TRUE)

de_results <- de_analysis(
  le_norm,
  trt - ctrl,
  measure = "intensity",
  group_col = "group"
)
plot_results_volcano(de_results, show.labels = FALSE)
```

[`de_analysis()`](https://rdrr.io/pkg/lipidr/man/de_analysis.html) wraps
limma internally and returns a plain data frame, not a
`LipidomicsExperiment` — the pipeline ends there.

## References

- Morgan M, Obenchain V, Hester J, Pagès H (2026). SummarizedExperiment:
  A container (S4 class) for matrix-like assays.
  <doi:%5B10.18129/B9.bioc.SummarizedExperiment>\](<https://doi.org/10.18129/B9.bioc.SummarizedExperiment>).
  R package version 1.42.0,
  <https://bioconductor.org/packages/SummarizedExperiment>.
- Mohamed A, Molendijk J, Hill MM (2020). lipidr: A Software Tool for
  Data Mining and Analysis of Lipidomics Datasets. *Journal of Proteome
  Research*, 19(7), 2890–2897.
  <doi:%5B10.1021/acs.jproteome.0c00082>\](<https://doi.org/10.1021/acs.jproteome.0c00082>).
- Ritchie ME, Phipson B, Wu D, Hu Y, Law CW, Shi W, Smyth GK (2015).
  limma powers differential expression analyses for RNA-sequencing and
  microarray studies. *Nucleic Acids Research*, 43(7), e47.
  <doi:%5B10.1093/nar/gkv007>\](<https://doi.org/10.1093/nar/gkv007>).

## Next steps

- [Import & export
  mzTab-M](https://slinghub.github.io/MRMhub/quant/articles/recipe-03-mztab-export.md)
  — the standard exchange format for repositories such as MetaboLights.
- [Design
  Decisions](https://slinghub.github.io/MRMhub/quant/articles/manual-03-design-decisions.md)
  — why `MRMhubExperiment` is not itself a Bioconductor class.
- [Lipidomics
  workflow](https://slinghub.github.io/MRMhub/quant/articles/tutorial-03-lipidomics-workflow.md)
  — QC-filter features before exporting.
- [Custom QC
  report](https://slinghub.github.io/MRMhub/quant/articles/recipe-02-custom-qc-report.md)
  — reporting straight from `mrmhub`.
