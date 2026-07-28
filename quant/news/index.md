# Changelog

## mrmhub 0.9.9 (development)

- **New
  [`save_plot()`](https://slinghub.github.io/MRMhub/quant/reference/save_plot.md)**:
  writes any plot from a `plot_*()` function to a file at a defined
  physical size and resolution, replacing hand-written
  [`ggplot2::ggsave()`](https://ggplot2.tidyverse.org/reference/ggsave.html)
  calls. Sizes are given in `mm` (default), `cm`, `in`, `pt` or `px`;
  formats are `pdf`, `svg`, `png`, `tiff` and `jpeg`, taken from the
  file extension or from an explicit `format`, which may name several
  formats to write in one call. It accepts a `ggplot`, a `patchwork`
  composition, the result list of
  [`plot_rla_boxplot()`](https://slinghub.github.io/MRMhub/quant/reference/plot_rla_boxplot.md),
  and a list of plots, which becomes a multi-page PDF. The plot is
  returned visibly, so `plot_*() |> save_plot()` still renders the
  figure in a Quarto or R Markdown chunk; `show_plot = FALSE` skips the
  re-draw and returns the written paths instead. The optional `ragg` and
  `svglite` packages are used automatically when installed, and PDF
  output uses the cairo device where available so that non-ASCII text
  (`µmol/L`, en dashes, `≥`) survives; plain `grDevices` devices are the
  fallback throughout.

- **Page size on the paged plot functions**:
  [`plot_runscatter()`](https://slinghub.github.io/MRMhub/quant/reference/plot_runscatter.md),
  [`plot_calibrationcurves()`](https://slinghub.github.io/MRMhub/quant/reference/plot_calibrationcurves.md),
  [`plot_responsecurves()`](https://slinghub.github.io/MRMhub/quant/reference/plot_responsecurves.md)
  and
  [`plot_feature_correlations()`](https://slinghub.github.io/MRMhub/quant/reference/plot_feature_correlations.md)
  gain `page_width`, `page_height` and `page_units`, replacing the
  previously hardcoded 28 x 20 cm A4 page. Left unset, the A4 default
  and `page_orientation` behave exactly as before.

- **[`mrmhub_set_plot_defaults()`](https://slinghub.github.io/MRMhub/quant/reference/mrmhub_set_plot_defaults.md)**
  gains `units` and `dpi`, so the unit and resolution used by
  [`save_plot()`](https://slinghub.github.io/MRMhub/quant/reference/save_plot.md)
  can be set once for a whole notebook. Figure width and height remain
  explicit at each call.

- **New batch-correction methods (experimental)**:
  [`correct_batch_combat()`](https://slinghub.github.io/MRMhub/quant/reference/correct_batch_combat.md)
  applies empirical-Bayes ComBat (Johnson et al. 2007, via the optional
  `sva` package) and
  [`correct_batch_serrf()`](https://slinghub.github.io/MRMhub/quant/reference/correct_batch_serrf.md)
  applies SERRF random-forest normalization (Fan et al. 2019, via the
  optional `ranger` package), complementing the existing
  [`correct_batch_centering()`](https://slinghub.github.io/MRMhub/quant/reference/correct_batch_centering.md).
  All three now share the same correction scaffolding.

## mrmhub 0.9.8

This release focuses on usability, robustness, and new analysis
capabilities.

### Highlights

- **Considerably enhanced console output and error messages**: clearer,
  more actionable messages, up-front argument validation, and truthful
  processing summaries make each step easier to follow and debug.

- **Substantially improved data and metadata import**: more robust
  sample and feature ID normalization and matching, deduplication, and
  stronger schema validation greatly reduce silent input errors.

- **Consistent, configurable plotting**: shared appearance arguments
  (font sizes, colours, legend placement and sizing) with a refined
  house theme, now settable globally via the new
  [`mrmhub_set_plot_defaults()`](https://slinghub.github.io/MRMhub/quant/reference/mrmhub_set_plot_defaults.md).

- **MS1 and MS2 (MRM) isotope interference correction**: a full
  correction engine for both precursor (MS1) and transition-level (MRM)
  isotopic interferences, with MRM patterns based on the LICAR method
  (Gao et al., *Anal. Chem.*, 2021).

- **Export to SummarizedExperiment and LipidomicsExperiment**: results
  convert directly to Bioconductor `SummarizedExperiment` and `lipidr`
  `LipidomicsExperiment` objects for downstream analysis.

- **Save and reload complete experiments**:
  [`save_dataset_rds()`](https://slinghub.github.io/MRMhub/quant/reference/save_dataset_rds.md)
  and
  [`read_dataset_rds()`](https://slinghub.github.io/MRMhub/quant/reference/read_dataset_rds.md)
  write and read a whole `MRMhubExperiment` as a self-contained `.rds`
  snapshot, with a content fingerprint embedded on save and verified on
  load.

- **Further new features**: mzTab-M import and export, and a status
  dashboard
  ([`mrmhub_status()`](https://slinghub.github.io/MRMhub/quant/reference/mrmhub_status.md))
  with compact object printing for a quick overview.

- **Improved robustness, speed, and stability**: better handling of
  missing values and analytical-sequence gaps, faster QC-metric
  computation, and many bug fixes based on user feedback.

- **Fully revised documentation**: a rewritten, task-oriented site with
  tutorials, manual, and recipes.

## mrmhub 0.9.2

Initial public version.
