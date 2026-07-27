# mrmhub 0.9.8

This release focuses on usability, robustness, and new analysis capabilities.

## Highlights

* **Considerably enhanced console output and error messages**: clearer, more
  actionable messages, up-front argument validation, and truthful processing
  summaries make each step easier to follow and debug.

* **Substantially improved data and metadata import**: more robust sample and
  feature ID normalization and matching, deduplication, and stronger schema
  validation greatly reduce silent input errors.

* **Consistent, configurable plotting**: shared appearance arguments (font
  sizes, colours, legend placement and sizing) with a refined house theme, now
  settable globally via the new `mrmhub_set_plot_defaults()`.

* **MS1 and MS2 (MRM) isotope interference correction**: a full correction
  engine for both precursor (MS1) and transition-level (MRM) isotopic
  interferences, with MRM patterns based on the LICAR method (Gao et al.,
  *Anal. Chem.*, 2021).

* **Export to SummarizedExperiment and LipidomicsExperiment**: results convert
  directly to Bioconductor `SummarizedExperiment` and `lipidr`
  `LipidomicsExperiment` objects for downstream analysis.

* **Further new features**: mzTab-M import and export, and a status dashboard
  (`mrmhub_status()`) with compact object printing for a quick overview.

* **Improved robustness, speed, and stability**: better handling of missing
  values and analytical-sequence gaps, faster QC-metric computation, and many
  bug fixes based on user feedback.

* **Fully revised documentation**: a rewritten, task-oriented site with
  tutorials, manual, and recipes.

# mrmhub 0.9.2

Initial public version.
