# Changelog

## mrmhub 0.9.2

### New features

#### mzTab-M import & export

- New
  [`save_dataset_mztab()`](https://slinghub.github.io/MRMhub/quant/reference/save_dataset_mztab.md)
  writes a processed `MRMhubExperiment` to the HUPO-PSI
  [mzTab-M](https://github.com/HUPO-PSI/mzTab-M) 2.0.0-M standard format
  (the format expected by repositories such as MetaboLights). Each
  analysis becomes an assay, each feature a Small Molecule Feature
  (`SMF`) row grouped into Small Molecule Summary (`SML`) rows by
  analyte. The abundance variable is selectable via `variable` (default
  `"conc"`, with fall-back to raw intensity for unquantified data), and
  the metadata header can be enriched with `instrument`, `contact` and
  `publication`. Output is validator-passing against the official LIFS
  mzTab-M validator.

- New
  [`import_data_mztab()`](https://slinghub.github.io/MRMhub/quant/reference/import_data_mztab.md)
  imports mzTab-M files produced by other tools (e.g. Lipid Data
  Analyzer, MS-DIAL, MZmine). Each `SMF` becomes a feature and each
  assay an analysis; per-assay abundances are imported as
  `feature_intensity`, with feature identities and `study_variable`
  grouping (as `batch_id`) carried over where available.

- Both directions are pure R and add **no runtime dependency**. See the
  *Import & Export mzTab-M* recipe article.

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

[`plot_responsecurves()`](https://slinghub.github.io/MRMhub/quant/reference/plot_responsecurves.md)
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
