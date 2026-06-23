# Drift and Batch Correction

`MRMhub` provides functions for run-order drift and batch correction.
The correction is based on user-selected reference sample types
(`qc_types`), based on which all other samples are adjusted. The
corrections can be applied to `intensity`, `norm_intensity`, or `conc`
data.

**Caution.** Drift and batch corrections must be fitted on dedicated
*reference* samples (typically QC pools) — never on study samples
(Broadhurst et al. 2018). The
[`correct_drift_gaussiankernel()`](https://slinghub.github.io/MRMhub/quant/reference/correct_drift_gaussiankernel.md)
option that fits on study samples is the sole exception and is only safe
for large, well-randomised cohorts.

## Drift correction (smoothing)

Following drift correction method are available in `MRMhub`, two of
which are typically used for QC samples and one (gaussian kernel-based)
for study samples.

Corrections can be applied on a batch-by-batch basis
(`batch_wise = TRUE`, default) or across all batches
(`batch_wise = FALSE`). The correction can either replace existing drift
or batch corrections (`⁠replace_previous = ⁠TRUE⁠`, default) or applied on
top of existing corrections (\`⁠replace_previous = FALSE’).

Drift correction can be applied to all features
(`conditional_correction = FALSE`) or conditionally, based on whether
the sample CV difference before and after correction is below a defined
threshold (`cv_diff_threshold)`. The conditional correction is applied
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

See the tutorial [Drift and Batch
Correction](https://slinghub.github.io/MRMhub/quant/articles/tutorial-04-drift-correction.md)
for more information on how to use these functions and plot the results.

## Batch-effect correction (centering)

`MRMhub` currently supports median centering-based batch correction
`correct_batch_centering()\`, whereby the scale of the batches can
optionally also be normalized. The selected QC types (`ref_qc_types`)
are used to calculate the medians, which are then used to align all
other samples.

See the tutorial [Drift and Batch
Correction](https://slinghub.github.io/MRMhub/quant/articles/tutorial-04-drift-correction.md)
for more information.

### See Also

- [Drift Correction
  Tutorial](https://slinghub.github.io/MRMhub/quant/articles/tutorial-04-drift-correction.md)
- [Batch Correction
  Tutorial](https://slinghub.github.io/MRMhub/quant/articles/tutorial-06-batch-correction.md)
- [RunScatter
  Plot](https://slinghub.github.io/MRMhub/quant/articles/tutorial-05-run-scatter.md)
  — visualise run order effects

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

Kirwan, J. A., D. I. Broadhurst, R. L. Davidson, and M. R. Viant. 2013.
“Characterising and Correcting Batch Variation in an Automated Direct
Infusion Mass Spectrometry (DIMS) Metabolomics Workflow.” *Analytical
and Bioanalytical Chemistry* 405 (15): 5147–57.
<https://doi.org/10.1007/s00216-013-6856-7>.
