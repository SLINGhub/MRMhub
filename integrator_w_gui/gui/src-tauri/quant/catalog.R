# A GUI adapter only: all scientific operations remain in the bundled package.
# Defaults below mirror tutorial-03; sample-specific IDs are deliberately absent.
quant_catalog <- function() {
  op <- function(id, label, stage, kind = "process", defaults = list(), note = "", packages = character()) {
    list(id = id, label = label, stage = stage, kind = kind, defaults = defaults, note = note, packages = packages)
  }
  list(
    op("import_data_mrmhub", "Import MRMhub results", "1 · Import", "import", list(import_metadata = TRUE), "Use the integrator's long.csv, or an MRMhub CSV/TSV export. Original files are never modified."),
    op("import_data_masshunter", "Import MassHunter results", "1 · Import", "import"),
    op("import_data_skyline", "Import Skyline results", "1 · Import", "import"),
    op("import_data_csv_long", "Import generic long-format CSV", "1 · Import", "import", note = "Map nonstandard columns with a JSON object: {\"analysis_id\":\"your_sample_column\",\"feature_id\":\"your_feature_column\",\"feature_area\":\"your_area_column\"}. No R expressions are evaluated."),
    op("import_data_csv_wide", "Import generic wide-format CSV", "1 · Import", "import", list(variable_name = "area")),
    op("read_dataset_rds", "Open saved MRMhub experiment", "1 · Import", "import", note = "Open an RDS archive made with save_dataset_rds(). Its embedded fingerprint is checked by the original R function. QUANT 1.0.1 can report a fingerprint mismatch across R processes even for unchanged data; the warning is preserved, and loading still proceeds. Verify the source of any archive before trusting it."),
    op("data_load_example", "Load bundled demo data", "1 · Import", "import"),
    op("import_metadata_msorganiser", "Import metadata workbook", "2 · Annotate", "metadata", note = "Use an MSorganiser workbook. For separate metadata tables, choose the corresponding import below. Metadata changes reset downstream processing in QUANT; rerun it afterwards."),
    op("import_metadata_analyses", "Import sample / run metadata", "2 · Annotate", "metadata"),
    op("import_metadata_features", "Import feature metadata", "2 · Annotate", "metadata"),
    op("import_metadata_istds", "Import internal-standard concentrations", "2 · Annotate", "metadata"),
    op("import_metadata_responsecurves", "Import response-curve metadata", "2 · Annotate", "metadata"),
    op("import_metadata_qcconcentrations", "Import QC concentrations", "2 · Annotate", "metadata"),
    op("import_metadata_from_data", "Extract embedded metadata", "2 · Annotate", "metadata"),
    op("set_lipid_class", "Derive lipid classes from names", "2 · Annotate", note = "Uses the original Goslin parser. Existing classes are kept unless you enable overwrite; non-lipid features should not use this operation.", packages = "rgoslin"),
    op("set_analysis_order", "Set run order", "2 · Annotate", defaults = list(order_by = "timestamp")),
    op("set_intensity_var", "Choose intensity measure", "2 · Annotate", defaults = list(variable_name = "area")),
    op("plot_runsequence", "Run sequence", "3 · Inspect", "plot", list(show_batches = TRUE, batch_zebra_stripe = TRUE, batch_fill_color = "#fffbdb", segment_linewidth = .5, show_timestamp = FALSE)),
    op("plot_abundanceprofile", "Retention-time / abundance profile", "3 · Inspect", "plot", list(variable = "rt", qc_types = "SPL", log_scale = FALSE, density_strip = TRUE, show_sum = FALSE, feature_map = "lipidomics")),
    op("plot_rt_vs_chain", "Retention time vs lipid chain", "3 · Inspect", "plot", list(qc_types = "SPL", x_var = "total_c", outlier_residual_min = .3, font_base_size = 8, point_size = 1)),
    op("plot_runscatter", "Feature intensities across runs", "3 · Inspect", "plot", list(variable = "intensity", qc_types = c("BQC", "TQC", "SPL", "PBLK", "SBLK"), cap_outliers = TRUE, log_scale = FALSE, show_batches = TRUE, font_base_size = 5, cols_page = 4, rows_page = 3)),
    op("plot_rla_boxplot", "Relative log abundance", "3 · Inspect", "plot", list(variable = "intensity", rla_type_batch = "within", qc_types = c("BQC", "SPL", "RQC", "TQC", "PBLK"), filter_data = FALSE, show_timestamp = FALSE, outlier_exclude = FALSE, x_gridlines = FALSE, batch_zebra_stripe = FALSE, linewidth = .1)),
    op("plot_pca", "Principal component analysis", "3 · Inspect", "plot", list(variable = "feature_intensity", qc_types = c("SPL", "BQC", "TQC"), filter_data = FALSE, log_transform = TRUE, include_istd = FALSE, point_size = 2, ellipse_alpha = .3, font_base_size = 8)),
    op("exclude_analyses", "Exclude samples / analyses", "3 · Inspect", defaults = list(clear_existing = FALSE), note = "Select rows in Data & metadata → annot_analyses, or enter exact analysis IDs here. Existing exclusions are kept by default. Use NA and Clear existing = Yes to restore all. Exclusions reset downstream processing; rerun it afterwards."),
    op("exclude_features", "Exclude features", "3 · Inspect", defaults = list(clear_existing = FALSE), note = "Select rows in Data & metadata → annot_features, or enter exact feature IDs here. Existing exclusions are kept by default. Use NA and Clear existing = Yes to restore all. Original measurements are never deleted."),
    op("plot_pca_loading", "PCA feature loadings", "3 · Inspect", "plot", list(variable = "intensity")),
    op("plot_feature_correlations", "Feature correlations", "3 · Inspect", "plot", list(variable = "intensity", cor_min = .9)),
    op("plot_matrixeffects", "Matrix effects / standard response", "3 · Inspect", "plot"),
    op("calc_qc_metrics", "Calculate QC metrics", "4 · QC & interference"),
    op("filter_features_qc", "Filter features by QC", "4 · QC & interference", defaults = list(include_qualifier = FALSE, include_istd = TRUE, min.intensity.median.spl = 200), note = "Initial tutorial filter: intensity ≥200, keep ISTDs. For final filtering, edit thresholds and turn off include ISTD. Response filters require annotated response curves; concentration CV requires quantitation."),
    op("plot_responsecurves", "Response curves", "4 · QC & interference", "plot", list(variable = "intensity", filter_data = TRUE, cols_page = 5, rows_page = 4)),
    op("correct_custom_interferences", "Correct annotated interferences", "4 · QC & interference", note = "Requires interference annotations. Do not run unless applicable to this dataset."),
    op("calc_isotopic_interferences", "Calculate isotope interferences (LICAR)", "4 · QC & interference", note = "Requires precursor/product chemical formulas and compatible acquisition metadata. MS1 is not a fallback for incomplete MRM annotations. Uses original LICAR; enviPat 2.8 is its reference version.", packages = "enviPat"),
    op("correct_isotopic_interferences", "Apply isotope interference correction", "4 · QC & interference"),
    op("plot_qc_interference_impact", "Isotope correction impact", "4 · QC & interference", "plot"),
    op("plot_interference_correction", "Review interference correction", "4 · QC & interference", "plot", list(qc_types = c("BQC", "SPL", "TQC", "LTR"))),
    op("normalize_by_istd", "Normalize by internal standards", "5 · Quantitate", note = "Requires feature-to-ISTD assignments and the matching standards in your measurements."),
    op("quantify_by_istd", "Calculate concentrations", "5 · Quantitate", note = "Normalize first. Requires ISTD concentrations, sample amounts, and ISTD volumes. Missing values are reported by QUANT, never guessed."),
    op("calc_calibration_results", "Fit external calibration curves", "5 · Quantitate", defaults = list(fit_overwrite = FALSE, fit_model = "linear", fit_weighting = "none"), note = "Use QC concentration metadata and ISTD-normalized intensities. Model and weighting can be set per feature, including 1/sqrt(x); one- and two-level fits follow the original engine."),
    op("quantify_by_calibration", "Quantify by external calibration", "5 · Quantitate", defaults = list(fit_overwrite = FALSE), note = "For assays such as Dataset4. Requires calibration/QC concentration annotations and normalized intensities; review model and weighting for your assay."),
    op("plot_calibrationcurves", "External calibration curves", "5 · Quantitate", "plot", list(fit_overwrite = FALSE)),
    op("calibrate_by_reference", "Calibrate against reference samples", "5 · Quantitate", defaults = list(variable = "conc", absolute_calibration = TRUE)),
    op("plot_normalization_qc", "Review normalization", "5 · Quantitate", "plot", list(before_norm_var = "intensity", after_norm_var = "norm_intensity", plot_type = "diff", qc_types = c("TQC", "BQC", "SPL"), facet_by_class = TRUE, point_size = 2, y_lim = c(-5, 15))),
    op("correct_drift_gaussiankernel", "Correct within-batch drift", "6 · Correct & review", defaults = list(variable = "conc", ref_qc_types = "SPL", ignore_istd = TRUE, batch_wise = TRUE, replace_previous = TRUE, recalc_trend_after = TRUE, kernel_size = 10, outlier_filter = FALSE, outlier_ksd = 5, location_smooth = TRUE, scale_smooth = FALSE), note = "Tutorial uses study samples as reference. Choose reference QC types appropriate to your design."),
    op("correct_batch_centering", "Correct between-batch differences", "6 · Correct & review", defaults = list(variable = "conc", ref_qc_types = "SPL", replace_previous = TRUE, correct_scale = TRUE, log_transform_internal = TRUE)),
    op("correct_drift_loess", "Correct drift · LOESS", "6 · Correct & review", defaults = list(variable = "conc", ref_qc_types = "BQC")),
    op("correct_drift_cubicspline", "Correct drift · cubic spline", "6 · Correct & review", defaults = list(variable = "conc", ref_qc_types = "BQC")),
    op("correct_drift_gam", "Correct drift · GAM", "6 · Correct & review", defaults = list(variable = "conc", ref_qc_types = "BQC")),
    op("correct_batch_combat", "Batch correction · ComBat (experimental)", "6 · Correct & review", defaults = list(variable = "conc", ref_qc_types = "BQC"), packages = "sva"),
    op("correct_batch_serrf", "Batch correction · SERRF (experimental)", "6 · Correct & review", defaults = list(variable = "conc", ref_qc_types = "BQC"), packages = "ranger"),
    op("data_sum_features", "Sum transitions into analytes", "6 · Correct & review", note = "Uses the original feature-to-analyte mapping and qualifier policy. Review metadata first; this changes the feature structure."),
    op("plot_qc_summary_byclass", "QC summary by class", "7 · Final QC & export", "plot"),
    op("plot_qc_summary_overall", "Overall QC summary", "7 · Final QC & export", "plot"),
    op("plot_qcmetrics_comparison", "Compare feature QC metrics", "7 · Final QC & export", "plot"),
    op("save_report_xlsx", "Export Excel report", "7 · Final QC & export", "export", list(filtered_variable = "conc")),
    op("save_dataset_csv", "Export processed dataset", "7 · Final QC & export", "export", list(variable = "conc", qc_types = "SPL", include_qualifier = FALSE, filter_data = TRUE)),
    op("save_dataset_rds", "Archive full experiment (RDS)", "7 · Final QC & export", "export", note = "Explicit archive, including the original function's content fingerprint. This extra copy is kept until you delete its saved run; use Save to keep it outside rolling session storage."),
    op("save_feature_qc_metrics", "Export feature QC metrics", "7 · Final QC & export", "export"),
    op("save_metadata_templates", "Export editable metadata templates", "2 · Annotate", "export"),
    op("save_metadata_msorganiser_template", "Export metadata workbook template", "2 · Annotate", "export")
  )
}

quant_schema <- function(entry) {
  labels <- c(path = "Input file", sheet = "Workbook sheet", qc_types = "Sample types to include",
              ref_qc_types = "Reference sample types", variable = "Measurement", variable_name = "Intensity measure",
              include_istd = "Include internal standards", include_qualifier = "Include qualifier transitions",
              include_feature_filter = "Only features matching (regular expression)", exclude_feature_filter = "Exclude features matching (regular expression)",
              filter_data = "Use QC-filtered data", kernel_size = "Drift smoothing window", order_by = "Order runs by",
              import_metadata = "Extract metadata from the results", ignore_warnings = "Allow metadata validation warnings",
              ignore_missing_annotation = "Allow missing annotations", concentration_unit = "Concentration basis",
              "min.intensity.median.spl" = "Minimum median study-sample intensity", "max.cv.conc.bqc" = "Maximum BQC concentration CV (%)",
              "response.curves.selection" = "Response curve IDs", "features.to.keep" = "Always keep these feature IDs",
              analyses = "Analysis IDs to exclude", features = "Feature IDs to exclude", clear_existing = "Clear existing exclusions first",
              excl_unmatched_analyses = "Exclude analyses without matching metadata", fit_overwrite = "Override per-feature calibration settings",
              fit_model = "Calibration model", fit_weighting = "Calibration weighting", overwrite = "Replace existing lipid classes",
              column_mapping = "Column mapping (JSON object)")
  fun <- getExportedValue("mrmhub", entry$id)
  args <- formals(fun)
  hidden <- c("data", "...", "table", "output_pdf", "return_plots", "multithreading", "show_progress", "create_dir", "overwrite")
  if (entry$id == "set_lipid_class") hidden <- setdiff(hidden, "overwrite")
  if (entry$kind == "plot") hidden <- c(hidden, "path")
  if (entry$kind == "export") hidden <- c(hidden, "path")
  fields <- lapply(setdiff(names(args), hidden), function(name) {
    required <- identical(args[[name]], quote(expr = ))
    raw <- paste(deparse(args[[name]]), collapse = "")
    value <- if (name %in% names(entry$defaults)) entry$defaults[[name]] else if (!required) tryCatch(eval(args[[name]], baseenv()), error = function(e) NULL) else NULL
    # Choice defaults in QUANT are vectors consumed by arg_match(). Preserve
    # omission unless the user opts in; do not turn a vector into a wrong default.
    type <- if (is.logical(value) && length(value) == 1 && !is.na(value)) "boolean" else if (is.numeric(value)) "number" else "text"
    if (name %in% c("show_sum", "include_istd", "include_qualifier", "show_legend_title", "add_qctype", "fit_overwrite", "clear_existing", "absolute_calibration", "store_conc_ratio", "include_norm_intensity_stats", "include_conc_stats", "include_response_stats", "include_calibration_results", "ci_show")) type <- "boolean"
    if (grepl("^(min[.]|max[.]|response.curves.selection$)|(_size|_alpha|_width|_height|_linewidth|_ksd|_threshold|_lim)$", name)) type <- "number"
    if (name %in% c("span", "spar", "lambda", "sp", "cor_min", "min_median_value", "specific_page", "zoom_n_points", "first_feature_column", "binwidth", "min_correction_pct")) type <- "number"
    vector <- length(value) > 1 || name %in% c("qc_types", "ref_qc_types", "analyses", "features", "features.to.keep", "response.curves.selection", "feature_list", "pca_dims", "y_lim", "x_lim", "include_feature_filter", "exclude_feature_filter", "reference_sample_id", "covariates", "na_strings", "threshold_values")
    choices <- switch(name, fit_model = c("linear", "quadratic"), fit_weighting = c("none", "1/x", "1/x^2", "1/sqrt(x)"),
      lod_sigma = c("residual", "intercept"), transition_id_columns = c("name", "mz", "none"),
      qualifier_action = c("include", "exclude", "separate"), NULL)
    if (name == "level" && entry$id == "calc_isotopic_interferences") choices <- c("MRM", "MS1")
    if (!is.null(choices)) { type <- "choice"; vector <- FALSE; value <- if (length(value)) value[[1]] else choices[[1]] }
    if (name == "column_mapping") { type <- "mapping"; vector <- FALSE }
    list(name = name, label = if (name %in% names(labels)) unname(labels[[name]]) else gsub("[_.]", " ", name), type = type, vector = vector,
         required = required, enabled = name %in% names(entry$defaults),
         value = value, original = raw, choices = choices,
         lineSeparated = name %in% c("analyses", "features", "include_feature_filter", "exclude_feature_filter", "features.to.keep", "feature_list", "reference_sample_id"))
  })
  entry$fields <- fields
  entry$missingPackages <- unname(as.list(entry$packages[!vapply(entry$packages, requireNamespace, logical(1), quietly = TRUE)]))
  entry$defaults <- NULL
  entry
}
