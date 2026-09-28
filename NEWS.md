# mrmhub 0.9.11 (development)

## Breaking changes

* Plot and export functions with a `qc_types` argument: a single QC type such
  as `"QC"` or `"BLK"` is now matched exactly instead of as a regular expression
  that also selected BQC, TQC or PBLK, SBLK, ... Patterns such as `"QC|SPL"`
  still work.

* `calc_qc_metrics()` and `filter_features_qc()`: the columns of `metrics_qc`,
  and of the report's Feature_QC_metrics sheet, change. `n_bqc`, `n_tqc` and
  `n_spl` are inserted among the existing columns; `filter_features_qc()`
  includes the response-curve statistics whenever response-curve data exist,
  not only when a response-curve criterion is set, and always adds
  `pass_linearity` and `filter_linearity`. Code selecting columns by position
  needs updating.

* `import_data_mztab()` no longer imports `study_variable` groups as `batch_id`;
  all analyses are in one batch. Since `save_dataset_mztab()` writes the QC
  types as study variables, a round trip turned QC types into batches. Supply
  batches with `add_metadata()`.

* `calc_qc_metrics()`: the column `sb_ratio_q10_pbk` is renamed to
  `sb_ratio_q10_pblk`.

* `calc_qc_metrics()` no longer replaces `feature_class` in the dataset with
  lipid classes parsed from the feature names for lipidomics experiments. The
  classes from the feature metadata are now always kept.

* `calc_qc_metrics()` and `filter_features_qc()`: a feature not detected in a
  blank now counts as zero intensity in that blank, so its signal-to-blank ratio
  is `Inf` and it passes a signal-to-blank criterion; before, a missing blank
  value failed the feature while a zero blank value passed it. This also applies
  to a blank analysis without a row for the feature, which previously was left
  out of the blank median. A feature not detected in the study samples still
  fails. The blank medians (`intensity_median_pblk`, `_ublk`, `_sblk`) change
  accordingly. A signal-to-blank criterion for a blank type with no analyses in
  the dataset raises a clearer error. With `use_batch_medians = TRUE`,
  signal-to-blank ratios take the lower median over batches, so a single batch
  with a ratio of `Inf` no longer makes it `Inf` (e.g. with blanks in 2
  batches).

* `calc_qc_metrics()`: D-ratios are `NA` when the QC or the study samples have
  fewer than 3 non-missing values, or a spread that is zero or not finite,
  matching the existing 3-replicate floor for %CV. A zero MAD from tied values
  previously gave a D-ratio of 0, which passed any D-ratio criterion.

* `correct_batch_combat()` and `correct_batch_serrf()` fit only study samples
  and routine QCs (SPL, TQC, BQC, HQC, MQC, LQC, QC, NIST, LTR) plus the
  `ref_qc_types`. Blanks, response curves, calibrants and other analyses are
  left out of the fit and keep their uncorrected values; before, their presence
  changed the corrected study-sample values. ComBat `covariates` need the
  analysis IDs as row names and are matched to analyses by name.

* `data_sum_features()`: a sum is `NA` in analyses where one of the summed
  transitions is missing (with a warning), instead of a partial sum. Summing
  internal standards together with analytes, or transitions with different
  ISTDs, response factors or interference features, is an error, as is a summed
  id that equals the `feature_id` of another feature. With
  `qualifier_action = "exclude"`, qualifiers are kept as they are instead of
  being dropped from the dataset. Excluding analyses or features, setting the
  analysis order or intensity variable, and importing metadata after summing
  now stop with an error; they previously dropped the summed analytes silently.

* `filter_features_qc()`: the minimum-intensity criterion columns in
  `metrics_qc` are renamed from `pass_lod`/`filter_lod` to
  `pass_minint`/`filter_minint`, and the summary-plot category from
  `below_lod` to `below_minint`. The criterion is a floor on the
  `min.intensity.*` values, not a limit-of-detection determination.

* `filter_features_qc()`: when a response-curve criterion is set, a feature
  whose response-curve results are missing now fails linearity with a warning,
  as for all other criteria; before, it silently passed. ISTDs without results
  are not failed. The warning lists only features in the data that are not
  already removed as ISTDs or qualifiers.

* `plot_matrixeffects()` shows each ISTD signal as a percentage of its median
  over the plotted non-blank analyses (per batch by default), instead of the
  mean over all plotted analyses including blanks, which pulled the 100% line
  down. The y-axis label says so.

* `plot_pca()` labels a sample as an outlier when its score lies more than
  `labels_threshold_mad` MADs from the median, on either side. The previous
  rule compared the absolute score with `median + k * MAD`, which labelled
  samples asymmetrically when the median was not zero. By default
  (`qc_types = NA`), the PCA also includes samples of QC type `QC`, like the
  other QC overview plots.

* `plot_qcmetrics_comparison()` and `plot_normalization_qc()` gain
  `include_istd` and hide ISTDs by default (`include_istd = FALSE`), also in
  metrics other than the normalized CV. ISTDs were previously hidden only there,
  because their normalized CV of 0 was removed as a zero value.

* `save_report_xlsx()` excludes internal standards from the concentration and
  QC-filtered sheets by `is_istd` instead of by `(IS` in the feature name, so
  an ISTD named differently is no longer included and an analyte named e.g.
  `(ISOMER …)` is no longer dropped. Sheets for reference-normalized variables
  use short names within Excel's 31 characters (e.g.
  `QCfilt_ConcRef_StudySamples`, `NormInt_NormalizedByRef_Full`); these names
  previously exceeded the limit, and some reports failed to save. Infinite QC
  metrics are written as the text `Inf` or `-Inf`, as Excel has no infinity, so
  such a column holds text and numbers in Excel; `save_feature_qc_metrics()`
  (CSV) keeps them numeric.

## New features

* `calc_qc_metrics()` reports the number of replicates behind the %CV and
  D-ratio as `n_bqc`, `n_tqc` and `n_spl`.

* `plot_pca()` and `plot_pca_loading()` accept `variable = "fwhm"`.

* `plot_qc_summary_byclass()` and `plot_qc_summary_overall()` label the QC
  categories in words (e.g. "< min S/B", "> max CV", "passed") instead of
  internal codes such as `below_sb`.

* `plot_qcmetrics_comparison()` notes in a caption when the metrics were
  calculated as robust %CV or as medians of within-batch values.

* New `set_lipid_class()` sets `feature_class` from the lipid names via the
  Goslin parser (`rgoslin`), filling only missing classes unless
  `overwrite = TRUE`. It replaces the parsing that `calc_qc_metrics()` used to
  apply implicitly.

## Bug fixes

* Batch boundaries (`annot_batches`, used for batch shading in run-order
  plots, the BatchInfo report sheet and `get_batch_boundaries()`) are taken
  from the first and last analysis of each batch in analysis order, not in the
  row order of the analysis metadata, and are updated by
  `set_analysis_order()`. Processed values were not affected.

* `correct_drift_*()` with `replace_previous = TRUE` no longer clears the drift
  and batch correction state of the other variables. Re-correcting e.g.
  `feature_norm_intensity` marked drift-corrected intensities as uncorrected, so
  a later intensity drift correction was applied on top of the earlier one and
  overwrote `feature_intensity_raw`.

* `calc_average_molweight()` returns `NA` for a missing formula instead of
  failing. `quantify_by_istd()` therefore works when some features have a
  chemical formula and others only a molecular weight (mass concentrations, or
  ISTD concentrations in ng/mL); the formula takes precedence. An ISTD with
  neither now always raises an error unless `ignore_missing_annotation = TRUE`.

* `import_data_csv_long()` without `column_mapping` now imports `intensity`,
  `response` and `conc` columns (also with the `feature_` prefix), as
  documented; they were dropped, and a file with only one of them failed. The
  default intensity variable is chosen from area, height, intensity, response
  and conc, in that order.

* Imported concentrations (e.g. `import_data_csv_wide(variable_name = "conc")`)
  are now marked as quantitated; the flag was reset at the end of the import, so
  e.g. the report treated the data as having no concentrations.

* Metadata import now detects mixed units within a response curve (the check
  always passed) and reports them for QC concentrations under
  `concentration_unit` instead of `analyzed_amount_unit`. Features with an
  interfering feature but no contribution, or vice versa, are now rejected; the
  check passed whenever at least one feature was complete.

* `filter_features_qc()` no longer adds an empty row to `dataset_filtered`
  (and the report's filtered sheets) for each feature that is only in the
  feature metadata.

* `calc_qc_metrics()`: `precursor_mz`, `product_mz` and `collision_energy` that
  differ between analyses of a feature are still `NA`, but now with a warning
  naming the features; missing values in some analyses are ignored instead of
  making the value `NA`. Without method data, these columns are numeric.

* `correct_interference_manual()` no longer leaves the dataset grouped, which
  made later steps such as `calc_qc_metrics()` fail, and no longer fails when the
  interfering feature is missing from an analysis; the corrected value is `NA`
  there.

* `data_sum_features()` keeps the dataset and the feature metadata consistent:
  in `"separate"` mode the qualifier sum now also exists in the feature
  metadata, a quantifier-qualifier pair is no longer renamed in one table only,
  an empty `analyte_id` no longer merges unrelated features, and summed ISTD
  transitions are updated in the ISTD, feature and interference metadata. An
  excluded transition, or one listed only in the metadata, no longer sets all
  sums of its analyte to `NA`. References to summed features in
  `interference_feature_id` of the feature metadata are updated, and an
  interference between transitions summed into one feature is removed.
  `feature_int_start` and `feature_int_end` are `NA` for merged analytes, like
  the peak widths.

* `detect_outlier_pca()` drops features with zero variance across the selected
  samples, with a warning, as `plot_pca()` does; they previously stopped the PCA
  with "cannot rescale a constant/zero column".

* `filter_features_qc()`: chained calls with `clear_existing = FALSE` can now
  add response-curve criteria in a later step (this aborted with "There are
  only 0 response curves"), and a linearity criterion from an earlier step is
  kept when a later step does not set one.

* `filter_features_qc()`: `use_robust_cv` and `use_batch_medians` are no longer
  silently ignored when QC metrics already exist. Settings not given follow the
  stored metrics; explicitly different settings recalculate them.

* `filter_features_qc()`: ISTDs no longer get a signal-to-blank verdict when no
  signal-to-blank criterion is set.

* `get_response_curve_stats()` (and the response-curve metrics of
  `calc_qc_metrics()`): a single missing point no longer makes r², slope and
  intercept of the whole curve `NA`; the curve is fitted on the points present,
  scaled to the largest amount among them, with a warning (also in
  `calc_qc_metrics()`). A curve with fewer than 3 points present gives `NA`
  instead of a perfect r² from 2 points.

* `plot_abundanceprofile()`: features whose class is missing or not in
  `feature_map` are shown as `Other` instead of being silently dropped, in the
  colour of an `Other` entry in `feature_map` if there is one. On a
  linear scale, class ranges are padded by the data range, so negative values
  are covered; on a log scale, non-positive values are removed with a message.
  With `use_qc_metrics = TRUE`, the feature filters are applied, and a set
  `analysis_range` is reported as ignored.

* `plot_feature_correlations()`: a feature with a single missing value no
  longer silently drops out of every pair; correlations use the analyses where
  both features have values, for pairs sharing values in at least half of the
  analyses. Non-positive values are removed only on log axes (for x and y), and
  pairs with the same |r| no longer split across pages.

* `plot_matrixeffects()` no longer plots QC types outside a fixed list (e.g.
  SBLK, UBLK, QC) as one unlabelled `NA` group, applies `min_median_value` to
  the plotted ISTDs only, and labels the x-axis "Feature" when non-ISTDs are
  shown.

* `plot_pca_loading()` drops features with zero variance, with a warning, as
  `plot_pca()` does; a constant feature previously appeared as the top loading.
  Features with missing or non-positive values are now reported when excluded,
  and the horizontal layout's axis titles are no longer swapped.

* `plot_qc_summary_byclass()` and `plot_qc_summary_overall()` count each
  feature once. Features retained via `features.to.keep` despite failing QC
  are shown as a separate "QC failed, kept" category instead of being counted
  both as failed and as passed, which inflated totals and per-class
  percentages. Features with only missing values are no longer also counted as
  passed.

* `plot_qc_summary_overall()`: the Venn diagram now covers the same features as
  the bars (no ISTDs or qualifiers when these are excluded) and also requires
  the missing-value criterion to be passed.

* `plot_qcmetrics_comparison()`: a comparison of metrics from different QC
  types with `qc_types` set no longer gives an empty plot (`qc_types` is
  ignored with a warning); zero values are kept on linear axes and removed only
  for log axes and ratio plots; only the named metric columns are selected;
  with `y_shared = TRUE` and one `y_lim` bound missing, the x-axis is free.

* `plot_responsecurves()` and `plot_feature_correlations()` with
  `output_pdf = TRUE` and `return_plots = TRUE` write the pages to the PDF; the
  file was empty. `plot_feature_correlations(output_pdf = TRUE)` without a
  `path` is an error, as in `plot_responsecurves()`; it previously closed the
  current graphics device.

* `plot_interference_correction()` labels all QC types correctly; types such as
  SBLK, RQC or UBLK were shown as `NA`. `qc_types = NA` selects the non-blank QC
  types, as documented; it previously also included PBLK and SBLK.

* `plot_runscatter()` assigns features to pages by feature, so features with
  missing analyses no longer split across pages or make the plot fail.
  `specific_page` builds, draws and saves only the selected page instead of
  all pages; a page number beyond the last page is an error.

* `plot_runscatter()`: infinite values are treated as missing, as intended;
  they were drawn at the panel edge and entered the outlier caps and reference
  lines. `log_scale = TRUE` no longer fails when a value is missing, and a zero
  next to missing values is no longer dropped. `y_label_text` is also used
  without `cap_outliers`.

* `plot_runscatter(show_reference_lines = TRUE)`: the upper reference line and
  the top of the SD band are drawn at mean + k × SD. They were cut off at the
  highest reference-QC value, which lowered most batch-wise lines. With
  `cap_outliers = TRUE` they are limited to the capped y-range.

* `plot_rla_boxplot(show_timestamp = TRUE)`: the time labels on the x-axis
  belong to the analyses at their positions. They were shifted after excluding
  analyses, wrong when the analysis order is not chronological, and duplicate
  timestamps caused an error.

* `save_report_xlsx()`: an explicit `normalized_variable` (e.g. `"conc"`)
  now exports the reference-normalized values instead of the unnormalized ones,
  and infinite QC metrics no longer appear as an Excel error.

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
