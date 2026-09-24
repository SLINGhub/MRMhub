# mrmhub 0.9.11 (development)

## Breaking changes

* `filter_features_qc()`: the minimum-intensity criterion columns in
  `metrics_qc` are renamed from `pass_lod`/`filter_lod` to
  `pass_minint`/`filter_minint`, and the summary-plot category from
  `below_lod` to `below_minint`. The criterion is a floor on the
  `min.intensity.*` values, not a limit-of-detection determination.

* `calc_qc_metrics()`: the column `sb_ratio_q10_pbk` is renamed to
  `sb_ratio_q10_pblk`.

# mrmhub 0.9.10

## New features

* Calibration curves can be fitted with `1/sqrt(x)` weighting, and
  `plot_calibrationcurves()` no longer requires `fit_overwrite`.

## Bug fixes

* Features with no analyte assigned in the feature metadata are no longer
  given a concentration belonging to an unrelated QC entry.

* `calibrate_by_reference()` now reports concentrations in the reference
  sample's unit, rather than keeping the unit of the preceding quantification.

* `calibrate_by_reference()` now always keeps the previous concentrations as
  `conc_beforecal`, also when calibrating from intensities.

* Calibration results (r², LoD, LoQ) and calculated concentrations are cleared
  when the values they were derived from change, so outdated numbers can no
  longer appear in QC filtering or the report.

* In the analysis and feature metadata, `yes`/`no` entries surrounded by spaces
  are now read correctly, and unrecognized entries raise an error instead of
  being silently treated as `yes`.

* `save_dataset_summarizedexperiment()` no longer exports internal backup and
  drift-model columns as assays; name them explicitly to include them.

# mrmhub 0.9.9

This release focuses on usability, robustness, and new functions.

## Highlights

* **Considerably enhanced console output and error messages**: clearer, more
  actionable messages, up-front argument validation, and truthful processing
  summaries make each step easier to follow and debug.

* **Substantially improved data and metadata import**: more robust sample and
  feature ID normalization and matching, deduplication, and stronger schema
  validation greatly reduce silent input errors.

* **Consistent, configurable plotting**: shared appearance arguments (font
  sizes, colours, legend placement and sizing) with a refined house theme, now
  settable globally via `mrmhub_set_plot_defaults()`.

* **Flexible figure export**: the new `save_plot()` writes any `plot_*()` figure
  to a file at a defined physical size and format, including multi-page PDFs, and
  the paged plot functions gain configurable page dimensions.

* **MS1 and MS2 (MRM) isotope interference correction**: a full correction
  engine for both precursor (MS1) and transition-level (MRM) isotopic
  interferences, with MRM patterns based on the LICAR method (Gao et al.,
  *Anal. Chem.*, 2021).

* **New batch-correction methods (experimental)**: empirical-Bayes ComBat
  (`correct_batch_combat()`, Johnson et al. 2007) and SERRF random-forest
  normalization (`correct_batch_serrf()`, Fan et al. 2019), complementing the
  existing `correct_batch_centering()`.

* **Export to SummarizedExperiment and LipidomicsExperiment**: results convert
  directly to Bioconductor `SummarizedExperiment` and `lipidr`
  `LipidomicsExperiment` objects for downstream analysis.

* **Save, share, and reload complete experiments**: `save_dataset_rds()` and
  `read_dataset_rds()` serialize a whole `MRMhubExperiment` to a single,
  self-contained `.rds` file, making complete datasets easy to archive and share;
  a content hash is embedded on save and verified on load.

* **Further new features**: mzTab-M import and export, and a status dashboard
  (`mrmhub_status()`) with compact object printing for a quick overview.

* **Improved robustness, speed, and stability**: better handling of missing
  values and analytical-sequence gaps, faster QC-metric computation, and many
  bug fixes based on user feedback.

* **Fully revised documentation**: a rewritten, task-oriented site with
  tutorials, manual, and recipes.

# mrmhub 0.9.2

Initial public version.
