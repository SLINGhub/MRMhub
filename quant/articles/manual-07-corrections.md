# Drift and batch correction

Manual

`MRMhub` provides functions for run-order drift and batch correction.
The correction is based on user-selected reference sample types
(`ref_qc_types`), relative to which all other samples are adjusted. The
corrections can be applied to `intensity`, `norm_intensity`, or `conc`
data.

Which samples a correction is fitted on depends on the modelling method.
The QC-based smoothers
([`correct_drift_loess()`](https://slinghub.github.io/MRMhub/quant/reference/correct_drift_loess.md),
[`correct_drift_cubicspline()`](https://slinghub.github.io/MRMhub/quant/reference/correct_drift_cubicspline.md))
are fitted on the reference sample types selected with `ref_qc_types`,
typically QC samples, i.e. the batch QC (`BQC`), or the technical QC
(`TQC`) in case of clear instrument drifts, following the QC-based
paradigm (Broadhurst et al. 2018). The gaussian-kernel method
([`correct_drift_gaussiankernel()`](https://slinghub.github.io/MRMhub/quant/reference/correct_drift_gaussiankernel.md))
instead fits on the study samples and is only appropriate for large,
well-randomised cohorts.

## Drift correction (smoothing)

The following drift correction methods are available in `MRMhub`, two of
which are typically used for QC samples and one (gaussian kernel-based)
for study samples.

Corrections can be applied on a batch-by-batch basis
(`batch_wise = TRUE`, default) or across all batches
(`batch_wise = FALSE`). The correction can either replace existing drift
or batch corrections (`replace_previous = TRUE`, default) or applied on
top of existing corrections (`replace_previous = FALSE`).

Drift correction can be applied to all features
(`conditional_correction = FALSE`) or conditionally, based on whether
the sample CV difference before and after correction is below a defined
threshold (`cv_diff_threshold`). The conditional correction is applied
separately for each batch if `batch_wise = TRUE`.

It is recommended to visually inspect the correction using the
[`plot_runscatter()`](https://slinghub.github.io/MRMhub/quant/reference/plot_runscatter.md)
function. Set the argument `recalc_trend_after = TRUE` so that the
trends after correction are also available for plotting. For further
details, refer to the description of
[`plot_runscatter()`](https://slinghub.github.io/MRMhub/quant/reference/plot_runscatter.md).
This, however, doubles the processing time.

**Note**: The function outputs a message indicating the median CV change
and the mean absolute CV before and after correction for all samples.
However, these metrics are experimental and should not be used as
definitive criteria for correction (see function documentation).

| Method | Function | Details |
|----|----|----|
| Cubic Spline | [`correct_drift_cubicspline()`](https://slinghub.github.io/MRMhub/quant/reference/correct_drift_cubicspline.md) | Smoothing parameter determined via cross-validation or set as fixed. Typically used with QC samples as reference. |
| Loess | [`correct_drift_loess()`](https://slinghub.github.io/MRMhub/quant/reference/correct_drift_loess.md) | Loess smoothing with fixed span. Typically used with QC samples as reference. |
| Gaussian Kernel | [`correct_drift_gaussiankernel()`](https://slinghub.github.io/MRMhub/quant/reference/correct_drift_gaussiankernel.md) | Fixed kernel size. Option to smooth scale (variability). Typically used with study samples as reference. Only suitable for large, well-randomized sample sets. |

The cubic spline smoothing approach, particularly when used with the
regularization parameter `lambda`, is similar but not identical to
previously described QC-based drift correction methods, such as **QC-RSC
(Quality Control Regularized Spline Correction)**, described in Dunn et
al. (2011) and Kirwan et al. (2013).

See the tutorial [Drift and batch
correction](https://slinghub.github.io/MRMhub/quant/articles/tutorial-04-drift-correction.md)
for more information on how to use these functions and plot the results.

## Batch-effect correction

`MRMhub` provides three batch-correction methods. Batch correction is
applied after normalization and, where used, drift correction.

- **Median centering**
  ([`correct_batch_centering()`](https://slinghub.github.io/MRMhub/quant/reference/correct_batch_centering.md))
  aligns the per-batch medians of the selected QC types
  (`ref_qc_types`), following the QC-based paradigm (Broadhurst et al.
  2018); the scale of the batches can optionally also be equalized. This
  is the default, most robust choice.
- **ComBat**
  ([`correct_batch_combat()`](https://slinghub.github.io/MRMhub/quant/reference/correct_batch_combat.md))
  applies the empirical-Bayes location and scale model of Johnson et al.
  (2007), shrinking the batch estimates across features. Unlike the
  other two methods, ComBat estimates batch effects from all samples
  rather than from the reference QCs; supply `covariates` to protect
  biological signal on unbalanced designs.
- **SERRF**
  ([`correct_batch_serrf()`](https://slinghub.github.io/MRMhub/quant/reference/correct_batch_serrf.md))
  removes systematic error with per-feature random forests trained on
  the reference QCs, using each feature’s most correlated features as
  predictors (Fan et al. 2019). It captures non-linear batch and drift
  effects jointly and is best suited to larger panels with dense QC
  coverage.

[`correct_batch_combat()`](https://slinghub.github.io/MRMhub/quant/reference/correct_batch_combat.md)
and
[`correct_batch_serrf()`](https://slinghub.github.io/MRMhub/quant/reference/correct_batch_serrf.md)
are **experimental**. ComBat requires the optional `sva` package and
SERRF the optional `ranger` package. The SERRF implementation adapts the
reference code in the `malbacR` package (Leach et al. 2023); validate
results against the reference implementation for your data.

See the tutorial [Drift and batch
correction](https://slinghub.github.io/MRMhub/quant/articles/tutorial-04-drift-correction.md)
for more information.

## Next steps

- [Drift and batch correction
  (tutorial)](https://slinghub.github.io/MRMhub/quant/articles/tutorial-04-drift-correction.md):
  worked examples of both corrections
- [Exploring QC: RunScatter and
  PCA](https://slinghub.github.io/MRMhub/quant/articles/tutorial-05-run-scatter.md):
  visualise run-order and batch effects

## References

Broadhurst, David, Royston Goodacre, Stacey N. Reinke, et al. 2018.
“Guidelines and Considerations for the Use of System Suitability and
Quality Control Samples in Mass Spectrometry Assays Applied in
Untargeted Clinical Metabolomic Studies.” *Metabolomics* 14 (6): 72.
<https://doi.org/10.1007/s11306-018-1367-3>.

Dunn, Warwick B., David Broadhurst, Paul Begley, et al. 2011.
“Procedures for Large-Scale Metabolic Profiling of Serum and Plasma
Using Gas Chromatography and Liquid Chromatography Coupled to Mass
Spectrometry.” *Nature Protocols* 6 (7): 1060–83.
<https://doi.org/10.1038/nprot.2011.335>.

Fan, Sili, Tobias Kind, Tomas Cajka, et al. 2019. “Systematic Error
Removal Using Random Forest for Normalizing Large-Scale Untargeted
Lipidomics Data.” *Analytical Chemistry* 91 (5): 3590–96.
<https://doi.org/10.1021/acs.analchem.8b05592>.

Johnson, W. Evan, Cheng Li, and Ariel Rabinovic. 2007. “Adjusting Batch
Effects in Microarray Expression Data Using Empirical Bayes Methods.”
*Biostatistics* 8 (1): 118–27.
<https://doi.org/10.1093/biostatistics/kxj037>.

Kirwan, J. A., D. I. Broadhurst, R. L. Davidson, and M. R. Viant. 2013.
“Characterising and Correcting Batch Variation in an Automated Direct
Infusion Mass Spectrometry (DIMS) Metabolomics Workflow.” *Analytical
and Bioanalytical Chemistry* 405 (15): 5147–57.
<https://doi.org/10.1007/s00216-013-6856-7>.

Leach, Damon L., Kelly A. Trujillo, Rachel A. Richardson, et al. 2023.
“malbacR: A Package for Standardized Implementation of Batch Correction
Methods for Omics Data.” *Metabolites* 13 (11): 1130.
<https://doi.org/10.3390/metabo13111130>.
