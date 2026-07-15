# Changelog

## mrmhub 0.9.2

### New features

#### Handling of analytical sequence gaps in `plot_runscatter()` and `plot_rla_boxplot()`

These functions gain the following new arguments to handle gaps in the
analytical sequence:

- `remove_gaps` — if `TRUE`, gaps in the data (mainly caused by
  unannotated analysis results) are removed and indicated by vertical
  lines and index labels. The gap lines can be customised via
  `gap_line_color`, `gap_line_width`, `gap_label_size`, and `gap_scale`.

- `collapse_excluded` — if `TRUE`, gaps in the x-axis caused by QC types
  that were not selected are collapsed. This is useful when plotting
  only samples or a subset of QC types.

#### Support for long feature names in `plot_runscatter()` and `plot_responsecurves()`

- `label_wrap` and `label_wrap_width` allow long `feature_id` strip
  labels to be wrapped across multiple lines. Set `label_wrap = TRUE` to
  enable wrapping; use `label_wrap_width` to control the maximum line
  width in characters (default: `25`).

#### Plotting multiple response curves per feature in `plot_responsecurves()`

[`plot_responsecurves()`](https://slinghub.github.io/MRMhub/reference/plot_responsecurves.md)
gains the following new arguments:

- `curve_layout` — one of `"overlay"`, `"rows"`, or `"cols"`.
  `"overlay"` plots all curves in the same panel; `"rows"` splits each
  curve into a separate row with features in columns; `"cols"` splits
  each curve into a separate column with features in rows. Use
  `fixed_scale_curves = TRUE` to fix the y-axis upper limit to the
  maximum value across all curves for each feature.

- `r2_vstep` — adjusts the vertical spacing between R² labels of
  different curves when `curve_layout = "overlay"`.

## mrmhub 0.9.1

## mrmhub 0.2.5

## mrmhub 0.2.4

## mrmhub 0.2.3

## mrmhub 0.2.2

## mrmhub 0.2.1

## mrmhub 0.2.0

Fully revised and extended functions, data classes, unit tests, and
documentation.

## mrmhub 0.1.0

Initial version
