# Changelog

## mrmhub 0.9.9 (development)

This release focuses on usability, robustness, and new functions.

### Highlights

- **Considerably enhanced console output and error messages**: clearer,
  more actionable messages, up-front argument validation, and truthful
  processing summaries make each step easier to follow and debug.

- **Substantially improved data and metadata import**: more robust
  sample and feature ID normalization and matching, deduplication, and
  stronger schema validation greatly reduce silent input errors.

- **Consistent, configurable plotting**: shared appearance arguments
  (font sizes, colours, legend placement and sizing) with a refined
  house theme, now settable globally via
  [`mrmhub_set_plot_defaults()`](https://slinghub.github.io/MRMhub/quant/reference/mrmhub_set_plot_defaults.md).

- **Flexible figure export**: the new
  [`save_plot()`](https://slinghub.github.io/MRMhub/quant/reference/save_plot.md)
  writes any `plot_*()` figure to a file at a defined physical size and
  format, including multi-page PDFs, and the paged plot functions gain
  configurable page dimensions.

- **MS1 and MS2 (MRM) isotope interference correction**: a full
  correction engine for both precursor (MS1) and transition-level (MRM)
  isotopic interferences, with MRM patterns based on the LICAR method
  (Gao et al., *Anal. Chem.*, 2021).

- **New batch-correction methods (experimental)**: empirical-Bayes
  ComBat
  ([`correct_batch_combat()`](https://slinghub.github.io/MRMhub/quant/reference/correct_batch_combat.md),
  Johnson et al. 2007) and SERRF random-forest normalization
  ([`correct_batch_serrf()`](https://slinghub.github.io/MRMhub/quant/reference/correct_batch_serrf.md),
  Fan et al. 2019), complementing the existing
  [`correct_batch_centering()`](https://slinghub.github.io/MRMhub/quant/reference/correct_batch_centering.md).

- **Export to SummarizedExperiment and LipidomicsExperiment**: results
  convert directly to Bioconductor `SummarizedExperiment` and `lipidr`
  `LipidomicsExperiment` objects for downstream analysis.

- **Save, share, and reload complete experiments**:
  [`save_dataset_rds()`](https://slinghub.github.io/MRMhub/quant/reference/save_dataset_rds.md)
  and
  [`read_dataset_rds()`](https://slinghub.github.io/MRMhub/quant/reference/read_dataset_rds.md)
  serialize a whole `MRMhubExperiment` to a single, self-contained
  `.rds` file, making complete datasets easy to archive and share; a
  content hash is embedded on save and verified on load.

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
