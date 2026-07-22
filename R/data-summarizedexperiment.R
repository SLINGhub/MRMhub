# ---- helpers ----------------------------------------------------------------

# tibble -> DataFrame, reindexed to `ids` and carrying them as rownames.
# `as(tbl, "DataFrame")` silently drops rownames, which would leave the
# annotation bound to the assay positionally only.
.se_annot_dataframe <- function(tbl, id_col, ids) {
  tbl <- tbl[match(ids, tbl[[id_col]]), , drop = FALSE]
  S4Vectors::DataFrame(as.data.frame(tbl), row.names = ids)
}

# ---- main exporter ----------------------------------------------------------

#' Export an experiment to a Bioconductor SummarizedExperiment
#'
#' Converts an [`MRMhubExperiment`][MRMhubExperiment-class] to a
#' [SummarizedExperiment](https://bioconductor.org/packages/SummarizedExperiment/),
#' the Bioconductor container for feature x sample data, and optionally to a
#' `LipidomicsExperiment` for use with
#' [lipidr](https://www.lipidr.org). This opens the experiment to the
#' Bioconductor ecosystem - `limma` for differential abundance, `POMA` and `pmp`
#' for preprocessing, `ComplexHeatmap` for visualization.
#'
#' @details
#' **Layout.** Features are rows and analyses are columns, following the
#' SummarizedExperiment convention. Each feature variable becomes one assay, so
#' `feature_intensity`, `feature_norm_intensity` and `feature_conc` sit
#' side-by-side in the same object and are addressed with
#' `SummarizedExperiment::assay(se, "conc")`. Assay names drop the `feature_`
#' prefix. `annot_features` becomes `rowData()`, `annot_analyses` becomes
#' `colData()`, and the processing state (status, flags, concentration unit)
#' becomes `metadata()`.
#'
#' **Everything is exported.** Internal standards, QC samples, blanks and
#' calibrants are all included and flagged rather than dropped, because
#' downstream tools need them: `lipidr` requires the `istd` annotation and
#' `pmp`'s blank filter needs blanks present. Subset when you need to:
#'
#' ```r
#' se[!rowData(se)$is_istd, se$qc_type == "SPL"]
#' ```
#'
#' Most statistical tools will otherwise happily include blanks and calibrants
#' and return nonsense.
#'
#' **QC metrics** are not written to `rowData()`. To filter features by QC
#' criteria, use [filter_features_qc()] and export with `filter_data = TRUE`.
#' [save_feature_qc_metrics()] exports the metrics themselves.
#'
#' @param data An [`MRMhubExperiment`][MRMhubExperiment-class] object.
#' @param path Optional file path. When given, the object is written there with
#'   [saveRDS()] and returned invisibly; a `.rds` extension is appended if
#'   missing. When `NULL` (default) the object is returned.
#' @param variable Feature variables to export as assays, e.g. `"conc"` or
#'   `c("intensity", "conc")`. `NULL` (default) exports every `feature_*`
#'   variable present in the data.
#' @param as Class to produce. `"SummarizedExperiment"` (default) or
#'   `"LipidomicsExperiment"`, which additionally requires the `lipidr` package
#'   and is only meaningful for lipidomics data.
#' @param filter_data Use QC-filtered data (`dataset_filtered`, see
#'   [filter_features_qc()]) instead of the full dataset. Default `FALSE`.
#' @param overwrite Overwrite an existing file at `path`. Default `TRUE`.
#'
#' @return A `SummarizedExperiment` (or `LipidomicsExperiment`). Returned
#'   invisibly when `path` is given.
#'
#' @references
#' Morgan M, Obenchain V, Hester J, & Pagès H (2026). SummarizedExperiment: A
#' container (S4 class) for matrix-like assays. R package version 1.42.0.
#' \doi{10.18129/B9.bioc.SummarizedExperiment}
#' \url{https://bioconductor.org/packages/SummarizedExperiment}
#'
#' Mohamed A, Molendijk J, & Hill MM (2020). lipidr: A Software Tool for Data
#' Mining and Analysis of Lipidomics Datasets. *Journal of Proteome Research*,
#' 19(7), 2890-2897. \doi{10.1021/acs.jproteome.0c00082}
#'
#' @seealso [save_dataset_csv()], [save_dataset_mztab()], [save_report_xlsx()]
#'
#' @examplesIf rlang::is_installed("SummarizedExperiment")
#' mexp <- normalize_by_istd(lipidomics_dataset)
#' mexp <- quantify_by_istd(mexp)
#'
#' se <- save_dataset_summarizedexperiment(mexp)
#' SummarizedExperiment::assayNames(se)
#'
#' # study samples only, internal standards dropped
#' se[!SummarizedExperiment::rowData(se)$is_istd, se$qc_type == "SPL"]
#'
#' @export
save_dataset_summarizedexperiment <- function(
  data = NULL,
  path = NULL,
  variable = NULL,
  as = c("SummarizedExperiment", "LipidomicsExperiment"),
  filter_data = FALSE,
  overwrite = TRUE
) {
  check_data(data)
  as <- rlang::arg_match(as)
  check_installed(
    "SummarizedExperiment",
    reason = "to export an experiment as a SummarizedExperiment."
  )

  if (nrow(data@dataset) == 0) {
    cli_abort(
      "No annotated data available. Import and process data before exporting."
    )
  }

  d <- get_dataset_subset(data, filter_data = filter_data)

  # --- resolve which feature variables become assays -----------------------
  available <- names(d)[
    stringr::str_starts(names(d), "feature_") &
      vapply(d, is.numeric, logical(1))
  ]

  if (is.null(variable)) {
    variables <- available
  } else {
    variables <- stringr::str_c("feature_", str_remove(variable, "^feature_"))
    for (v in variables) {
      check_var_in_dataset(d, v)
    }
    missing_vars <- str_remove(setdiff(variables, available), "^feature_")
    if (length(missing_vars) > 0) {
      cli_abort(
        "Feature variable {.val {missing_vars}} not available. Available variables: {.val {str_remove(available, '^feature_')}}."
      )
    }
  }

  # --- canonical dimensions ------------------------------------------------
  feature_ids <- data@annot_features$feature_id
  feature_ids <- feature_ids[feature_ids %in% unique(d$feature_id)]
  analysis_ids <- data@annot_analyses$analysis_id
  analysis_ids <- analysis_ids[analysis_ids %in% unique(d$analysis_id)]

  i <- match(d$feature_id, feature_ids)
  j <- match(d$analysis_id, analysis_ids)
  if (anyNA(i) || anyNA(j)) {
    cli_abort(
      "The data contain analyses or features that are missing from the metadata. Please verify the annotations."
    )
  }

  # Position of each long-format row in the (column-major) assay matrix. Filling
  # by index rather than pivoting keeps every assay on one set of dimnames by
  # construction, which is what SummarizedExperiment requires across assays.
  idx <- i + (j - 1L) * length(feature_ids)
  if (anyDuplicated(idx) > 0) {
    cli_abort(
      "More than one value per analysis and feature found. Please verify the data."
    )
  }

  assay_list <- lapply(variables, \(v) {
    m <- matrix(
      NA_real_,
      nrow = length(feature_ids),
      ncol = length(analysis_ids),
      dimnames = list(feature_ids, analysis_ids)
    )
    m[idx] <- d[[v]]
    m
  })
  names(assay_list) <- str_remove(variables, "^feature_")
  assay_list <- S4Vectors::SimpleList(assay_list)

  row_data <- .se_annot_dataframe(
    data@annot_features,
    "feature_id",
    feature_ids
  )
  col_data <- .se_annot_dataframe(
    data@annot_analyses,
    "analysis_id",
    analysis_ids
  )

  se <- SummarizedExperiment::SummarizedExperiment(
    assays = assay_list,
    rowData = row_data,
    colData = col_data,
    metadata = .se_metadata(data, filter_data)
  )

  if (as == "LipidomicsExperiment") {
    se <- .se_as_lipidomics_experiment(se)
  }

  if (is.null(path)) {
    return(se)
  }

  if (!str_detect(path, "\\.rds$")) {
    path <- paste0(path, ".rds")
  }
  if (fs::file_exists(path) && !overwrite) {
    cli_abort(
      "File '{path}' already exists. Use `overwrite = TRUE` to replace it."
    )
  }
  saveRDS(se, file = path)

  mh_success(
    "{as} with {nrow(se)} feature{?s} and {ncol(se)} analys{?is/es} was saved to '{path}'."
  )
  invisible(se)
}

# Processing state that has no typed home in SummarizedExperiment.
.se_metadata <- function(data, filter_data) {
  list(
    title = data@title,
    analysis_type = data@analysis_type,
    status_processing = data@status_processing,
    conc_unit = get_conc_unit(
      data@annot_analyses$sample_amount_unit,
      get_conc_analyte_unit(data)
    ),
    is_istd_normalized = data@is_istd_normalized,
    is_quantitated = data@is_quantitated,
    is_filtered = filter_data,
    is_isotope_corr = data@is_isotope_corr,
    var_drift_corrected = data@var_drift_corrected,
    var_batch_corrected = data@var_batch_corrected,
    mrmhub_version = as.character(utils::packageVersion("mrmhub"))
  )
}

# ---- lipidr ------------------------------------------------------------------

# `LipidomicsExperiment` adds no slots to SummarizedExperiment; it is defined
# entirely by a validity method requiring `filename`/`Molecule`/`Class`/`istd`
# in rowData plus `dimnames`/`summarized` in metadata. The `logged` and
# `normalized` flags live in `mcols(assays())` and are *not* covered by that
# validity check, so an object missing them constructs cleanly and then
# misbehaves. Everything needed is already in the MRMhubExperiment.
.se_as_lipidomics_experiment <- function(se) {
  check_installed(
    "lipidr",
    reason = "to export an experiment as a LipidomicsExperiment."
  )

  row_data <- SummarizedExperiment::rowData(se)
  row_data$filename <- "mrmhub"
  row_data$Molecule <- rownames(se)
  row_data$Class <- row_data$feature_class
  row_data$istd <- row_data$is_istd

  assay_list <- SummarizedExperiment::assays(se)
  S4Vectors::mcols(assay_list) <- S4Vectors::DataFrame(
    logged = rep(FALSE, length(assay_list)),
    normalized = rep(FALSE, length(assay_list))
  )

  .lipidr_warn_sub_one(assay_list)

  lipidr::LipidomicsExperiment(
    assay_list = assay_list,
    metadata = c(
      S4Vectors::metadata(se),
      list(dimnames = c("MoleculeId", "Sample"), summarized = TRUE)
    ),
    colData = SummarizedExperiment::colData(se),
    rowData = row_data
  )
}

# Abundance assays, i.e. the ones a user would pass to `lipidr`'s `measure=` and
# that it would log-transform. Retention time and peak shape are exported too but
# are never treated as abundances.
.se_abundance_assays <- c(
  "area",
  "height",
  "intensity",
  "norm_intensity",
  "response",
  "pmol_total",
  "conc"
)

# `lipidr:::.log_data()` clamps values < 1 to 1 before log2(), which assumes
# Skyline peak-area magnitudes (checked against lipidr 2.22.1). Concentrations in
# umol/L are mostly sub-1, so they are silently flattened to log2(1) = 0 and
# every fold change collapses. `log = TRUE` is the default of `normalize_pqn()`
# and `plot_samples()`, so the hazard is on every entry point.
#
# Warn rather than rescale or pre-log: both would mean the assay no longer holds
# what its name says, and would disagree with the SummarizedExperiment path.
# Only abundances are checked - peak widths are sub-1 by nature (minutes) and
# nobody log-transforms them.
.lipidr_warn_sub_one <- function(assay_list) {
  abundances <- assay_list[names(assay_list) %in% .se_abundance_assays]
  prop_sub_one <- vapply(
    abundances,
    \(m) mean(m < 1, na.rm = TRUE),
    numeric(1)
  )
  risky <- names(which(prop_sub_one > 0.5))

  if (length(risky) > 0) {
    mh_warn(
      "Assay {.val {risky}} {?is/are} mostly < 1. `lipidr` clamps values < 1 to 1 before log-transforming, which would silently flatten {?it/them}."
    )
    cli_alert_info(
      "Use an assay on peak-area scale (e.g. {.val intensity}), pass {.code log = FALSE} to `lipidr`, or log-transform beforehand."
    )
  }
  invisible(NULL)
}
