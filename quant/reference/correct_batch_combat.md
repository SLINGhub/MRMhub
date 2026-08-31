# ComBat batch correction

**\[experimental\]**

Adjusts batch effects with the empirical-Bayes ComBat method (Johnson et
al. 2007), applied to one of "intensity", "norm_intensity", or "conc".
ComBat models a location and scale batch effect per feature and shrinks
those estimates across features, which can stabilise many small batches
better than simple median centering.

Unlike
[`correct_batch_centering()`](https://slinghub.github.io/MRMhub/quant/reference/correct_batch_centering.md)
and
[`correct_batch_serrf()`](https://slinghub.github.io/MRMhub/quant/reference/correct_batch_serrf.md),
ComBat estimates batch effects from **all** samples (optionally
protecting biology via `covariates`), not from the reference QCs. On
strongly unbalanced designs this can remove genuine biological signal,
so supply `covariates` when the biological grouping is not balanced
across batches. `ref_qc_types` is used only for the before/after QC-CV
report and the plotting trend curves.

Batch correction is performed **after** normalization and drift
correction in the recommended pipeline. Features with any missing or
non-finite values in the selected variable are left uncorrected (ComBat
requires complete data).

## Usage

``` r
correct_batch_combat(
  data = NULL,
  variable,
  ref_qc_types,
  covariates = NULL,
  ref_batch = NULL,
  parametric = TRUE,
  ignore_istd = TRUE,
  replace_previous = TRUE,
  log_transform_internal = TRUE,
  feature_list = NULL,
  replace_exisiting_trendcurves = FALSE
)
```

## Arguments

- data:

  A
  [`MRMhubExperiment`](https://slinghub.github.io/MRMhub/quant/reference/MRMhubExperiment-class.md)
  object.

- variable:

  The variable to correct: one of "intensity", "norm_intensity", or
  "conc".

- ref_qc_types:

  Character vector of QC types used for the QC-CV report and trend
  curves (not for the ComBat fit itself).

- covariates:

  Optional model matrix of biological covariates to preserve (passed to
  [`sva::ComBat()`](https://rdrr.io/pkg/sva/man/ComBat.html) as `mod`).
  Defaults to `NULL` (no covariates).

- ref_batch:

  Optional reference batch to adjust the others towards (passed to
  [`sva::ComBat()`](https://rdrr.io/pkg/sva/man/ComBat.html) as
  `ref.batch`). Defaults to `NULL`.

- parametric:

  Use the parametric empirical-Bayes prior (`TRUE`, default) or the
  non-parametric prior (`FALSE`).

- ignore_istd:

  Logical. Exclude internal standards (ISTDs) from correction if `TRUE`
  (the default). Their values are left unchanged, and they do not
  contribute to the empirical-Bayes prior.

- replace_previous:

  Replace a previous batch correction (`TRUE`, default) or apply on top
  of it.

- log_transform_internal:

  Fit ComBat in log10 space (`TRUE`, default, appropriate for
  multiplicatively-scaling MS data). Returned data are always
  back-transformed to the raw scale.

- feature_list:

  Optional feature selection (character vector or a single regular
  expression); `NULL` (default) selects all features.

- replace_exisiting_trendcurves:

  Reseed the plotting trend curves. Default `FALSE`.

## Value

A
[`MRMhubExperiment`](https://slinghub.github.io/MRMhub/quant/reference/MRMhubExperiment-class.md)
with corrected data.

## References

Johnson WE, Li C, Rabinovic A (2007). Adjusting batch effects in
microarray expression data using empirical Bayes methods.
*Biostatistics*, 8(1), 118-127.
[doi:10.1093/biostatistics/kxj037](https://doi.org/10.1093/biostatistics/kxj037)

Applied through
[`sva::ComBat()`](https://rdrr.io/pkg/sva/man/ComBat.html) from the
`sva` package. See also Broadhurst D, et al. (2018), *Metabolomics*, 14,
72
([doi:10.1007/s11306-018-1367-3](https://doi.org/10.1007/s11306-018-1367-3)
) on QC-based signal correction.

## See also

[`correct_batch_centering()`](https://slinghub.github.io/MRMhub/quant/reference/correct_batch_centering.md),
[`correct_batch_serrf()`](https://slinghub.github.io/MRMhub/quant/reference/correct_batch_serrf.md),
[`correct_drift_loess()`](https://slinghub.github.io/MRMhub/quant/reference/correct_drift_loess.md)
and
[`plot_runscatter()`](https://slinghub.github.io/MRMhub/quant/reference/plot_runscatter.md)
for visualisation. The [drift and batch correction
manual](https://slinghub.github.io/MRMhub/quant/articles/manual-07-corrections.html).

## Examples

``` r
# mexp <- correct_batch_combat(mexp, variable = "conc", ref_qc_types = "BQC")
```
