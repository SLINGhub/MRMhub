# Feature Variables in MRMhub

Feature variables represent measurement values associated with a feature
in a specific sample. They describe properties such as peak area,
concentration, retention time, or peak shape.

Feature variables can be accessed in MRMhub functions by their internal
name (starting with `feature_`, e.g., `feature_intensity`) or by their
short name (e.g., `conc`, `intensity`, `norm_intensity`, `rt`).

## Key Feature Variables

These variables are essential for the data processing flow. The
`intensity` variable holds the raw signal (e.g., peak area) and is the
starting point for all downstream processing. All key feature variables
are stored in the `dataset` table of the `MRMhubExperiment` object.

Many processing and plotting functions accept a `variable` argument that
selects which feature variable to use as input.

## Backup Feature Variables

Some processing steps (drift correction, batch correction,
recalibration) overwrite existing values. In these cases, the original
values are saved in a backup variable with a postfix appended to the
variable name.

| Postfix | Example | Created when |
|----|----|----|
| `_orig` | `feature_intensity_orig` | Before interference correction. Always holds the original imported intensity. |
| `_raw` | `feature_conc_raw` | Before any correction step. Holds the uncorrected calculated values. |
| `_before` | `feature_conc_before` | Before the most recent correction step (e.g., after drift correction, before batch correction). |
| `_beforecal` | `feature_conc_beforecal` | Before [`calibrate_by_reference()`](https://slinghub.github.io/MRMhub/quant/reference/calibrate_by_reference.md) was applied. Only for concentration variables. |
| `_fit` | `conc_before_fit` | Model fit data points from drift/batch correction. Used by [`plot_runscatter()`](https://slinghub.github.io/MRMhub/quant/reference/plot_runscatter.md) to show trends. |

## Raw Feature Variables

These variables are stored in the `dataset_orig` table and are never
modified by any MRMhub function. One of them is copied to `intensity` at
import (by default `area` if available, then `height`, `response`, or
`intensity` in that order). You can manually set the source variable
with
[`set_intensity_var()`](https://slinghub.github.io/MRMhub/quant/reference/set_intensity_var.md).

## See Also

- [Data
  Structures](https://slinghub.github.io/MRMhub/quant/articles/manual-01-data-structure.md)
  — overview of all data tables
- [Data
  Identifiers](https://slinghub.github.io/MRMhub/quant/articles/manual-02-data-identifiers.md)
  — ID columns
- [Key Concepts &
  Glossary](https://slinghub.github.io/MRMhub/quant/articles/manual-00-key-concepts.md)
  — terminology reference
