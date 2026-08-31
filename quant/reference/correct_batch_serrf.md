# SERRF batch correction

**\[experimental\]**

This is an independent re-implementation of SERRF in `mrmhub`, adapted
from the reference code in the `malbacR` package (not the original
authors' package); see Details. Validate results against the reference
SERRF for your data.

Normalises systematic error with SERRF (Systematic Error Removal using
Random Forest; Fan et al. 2019). For each feature and batch a random
forest is trained on the reference QC samples, using the batch's
most-correlated features as predictors, and the learned systematic error
is removed from all samples. Unlike ComBat, SERRF captures non-linear
drift and batch effects jointly and is anchored on the QC samples,
matching the QC-based design of the package; it is best suited to larger
panels with dense QC coverage.

SERRF operates on the raw abundance scale (no log transform). Features
with missing or non-positive values, and batches with fewer than two
reference QCs, are left uncorrected. Batch correction is performed
**after** normalization and drift correction in the recommended
pipeline.

## Usage

``` r
correct_batch_serrf(
  data = NULL,
  variable,
  ref_qc_types,
  n_correlated = 10,
  num_trees = 500,
  seed = 1L,
  num_threads = 1L,
  show_progress = TRUE,
  ignore_istd = TRUE,
  replace_previous = TRUE,
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

  Character vector of QC types used as the SERRF training (reference)
  samples per batch.

- n_correlated:

  Number of most-correlated features used as random-forest predictors
  per feature. Default `10`.

- num_trees:

  Number of trees per random forest. Default `500`.

- seed:

  Random seed for
  [`ranger::ranger()`](http://imbs-hl.github.io/ranger/reference/ranger.md),
  for reproducibility. Default `1`.

- num_threads:

  Threads per random forest passed to
  [`ranger::ranger()`](http://imbs-hl.github.io/ranger/reference/ranger.md).
  Default `1`; kept low because batches are already corrected in
  parallel and each forest trains on a small QC set.

- show_progress:

  Show a progress bar over batches. Default `TRUE`.

- ignore_istd:

  Logical. Exclude internal standards (ISTDs) from correction if `TRUE`
  (the default). Their values are left unchanged, and they are not
  available as random-forest predictors.

- replace_previous:

  Replace a previous batch correction (`TRUE`, default) or apply on top
  of it.

- feature_list:

  Optional feature selection (character vector or a single regular
  expression); `NULL` (default) selects all features.

- replace_exisiting_trendcurves:

  Reseed the plotting trend curves. Default `FALSE`.

## Value

A
[`MRMhubExperiment`](https://slinghub.github.io/MRMhub/quant/reference/MRMhubExperiment-class.md)
with corrected data.

## Details

The implementation adapts the reference SERRF code in the `malbacR`
package, keeping its normalization arithmetic but selecting each
feature's predictors from the per-batch QC-sample Spearman correlation
(a simplification of malbacR's QC/sample correlation intersection).
Random forests are fit with
[`ranger::ranger()`](http://imbs-hl.github.io/ranger/reference/ranger.md)
and a fixed `seed`, so results are reproducible. Users are encouraged to
validate results against the reference SERRF implementation for their
data.

Batches are corrected independently and in parallel via `mirai` (through
[`purrr::in_parallel()`](https://purrr.tidyverse.org/reference/in_parallel.html));
set up workers with
[`mirai::daemons()`](https://mirai.r-lib.org/reference/daemons.html)
beforehand to use them, otherwise the batches are processed
sequentially.

## References

Fan S, Kind T, Cajka T, et al. (2019). Systematic Error Removal Using
Random Forest for Normalizing Large-Scale Untargeted Lipidomics Data.
*Analytical Chemistry*, 91(5), 3590-3596.
[doi:10.1021/acs.analchem.8b05592](https://doi.org/10.1021/acs.analchem.8b05592)

Implementation adapted from the `malbacR` package
(<https://github.com/pmartR/malbacR>); random forests via `ranger`
(Wright MN, Ziegler A, 2017, *Journal of Statistical Software*, 77(1),
[doi:10.18637/jss.v077.i01](https://doi.org/10.18637/jss.v077.i01) ).

## See also

[`correct_batch_centering()`](https://slinghub.github.io/MRMhub/quant/reference/correct_batch_centering.md),
[`correct_batch_combat()`](https://slinghub.github.io/MRMhub/quant/reference/correct_batch_combat.md),
[`correct_drift_loess()`](https://slinghub.github.io/MRMhub/quant/reference/correct_drift_loess.md)
and
[`plot_runscatter()`](https://slinghub.github.io/MRMhub/quant/reference/plot_runscatter.md)
for visualisation. The [drift and batch correction
manual](https://slinghub.github.io/MRMhub/quant/articles/manual-07-corrections.html).

## Examples

``` r
# mexp <- correct_batch_serrf(mexp, variable = "conc", ref_qc_types = "BQC")
```
