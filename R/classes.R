#' S4 class representing the MRMhub dataset
#'
#' @description
#'
#' The `MRMhubExperiment` object is the core data structure utilized within the MRMhub workflow, encapsulating all relevant experimental data and metadata.
#' It also includes processing results, details of the applied processing steps, and the current status of the data.
#'
#'
#' @docType class
#'
#' @slot title Title of the experiment
#' @slot analysis_type Analysis type, one of "lipidomics", "metabolomics", "externalcalib", "others"
#' @slot feature_intensity_var Feature variable used as default for calculations
#' @slot conc_analyte_unit Unit of the analyte amount underlying `feature_conc`,
#'   set when the data are quantitated. `"pmol"` or `"ng"` for ISTD quantitation
#'   (see [quantify_by_istd()]), or the calibrant concentration unit (e.g.
#'   `"nmol/L"`) for calibration quantitation. Divided by `sample_amount_unit` by
#'   `get_conc_unit()` to name the unit of `feature_conc`. `NA` when not quantitated.
#' @slot dataset_orig Original imported analysis data.
#' @slot dataset Processed analysis data.
#' @slot dataset_filtered QC-filtered processed analysis data.
#' @slot annot_analyses Annotation of analyses/runs
#' @slot annot_features Annotation of measured features.
#' @slot annot_istds Annotation of Internal Standard concs.
#' @slot annot_responsecurves Annotation of response curves (RQC).
#' @slot annot_qcconcentrations Annotation of calibration curves.
#' @slot annot_studysamples Annotation of study samples.
#' @slot annot_batches Annotation of batches.
#' @slot annot_interferences Interference relationships (`feature_id`, `interference_feature_id`, `interference_contribution`, `overlap_type`, `source`) feeding the correction engine; derived (auto) and/or manual.
#' @slot metrics_qc QC information for each measured feature
#' @slot metrics_calibration Calibration metrics calculated from external calibration curves for each measured feature
#' @slot status_processing Status within the data processing workflow
#' @slot is_istd_normalized Flag if data has been ISTD normalized
#' @slot is_quantitated Flag if data has been quantitated using ISTD and sample amount
#' @slot is_filtered Flag if data has been filtered based on QC parameters
#' @slot is_isotope_corr Flag if one or more features have been isotope corrected
#' @slot analyses_excluded Analyses excluded from processing, plots and reporting, unless explicitly requested
#' @slot features_excluded Features excluded from processing, plots and reporting, unless explicitly requested
#' @slot var_drift_corrected List indicating which variables are drift corrected
#' @slot var_batch_corrected List indicating which variables are batch corrected

#' @include mrmhub-global-definitions.R
#' @export

setClass(
  "MRMhubExperiment",
  slots = c(
    title = "character",
    analysis_type = "character",
    feature_intensity_var = "character",
    conc_analyte_unit = "character",
    dataset_orig = "tbl_df",
    dataset = "tbl_df",
    dataset_filtered = "tbl_df",
    annot_analyses = "tbl_df",
    annot_features = "tbl_df",
    annot_istds = "tbl_df",
    annot_responsecurves = "tbl_df",
    annot_qcconcentrations = "tbl_df",
    annot_studysamples = "tbl_df",
    annot_batches = "tbl_df",
    annot_interferences = "tbl_df",
    metrics_qc = "tbl_df",
    metrics_calibration = "tbl_df",
    status_processing = "character",
    is_istd_normalized = "logical",
    is_quantitated = "logical",
    is_filtered = "logical",
    is_isotope_corr = "logical",
    analyses_excluded = "vector",
    features_excluded = "vector",
    var_drift_corrected = "vector",
    var_batch_corrected = "vector"
  ),
  prototype = list(
    title = "",
    analysis_type = "",
    feature_intensity_var = "",
    conc_analyte_unit = NA_character_,
    dataset_orig = pkg.env$table_templates$dataset_orig_template,
    dataset = pkg.env$table_templates$dataset_template,
    dataset_filtered = pkg.env$table_templates$dataset_template,
    annot_analyses = pkg.env$table_templates$annot_analyses_template,
    annot_features = pkg.env$table_templates$annot_features_template,
    annot_istds = pkg.env$table_templates$annot_istds_template,
    annot_responsecurves = pkg.env$table_templates$annot_responsecurves_template,
    annot_qcconcentrations = pkg.env$table_templates$annot_qcconcentrations_template,
    annot_studysamples = dplyr::tibble(),
    annot_batches = dplyr::tibble(),
    annot_interferences = pkg.env$table_templates$annot_interferences_template,
    metrics_qc = dplyr::tibble(),
    metrics_calibration = dplyr::tibble(),
    status_processing = "No Data",
    is_isotope_corr = FALSE,
    is_istd_normalized = FALSE,
    is_quantitated = FALSE,
    var_drift_corrected = c(
      feature_intensity = FALSE,
      feature_norm_intensity = FALSE,
      feature_conc = FALSE
    ),
    var_batch_corrected = c(
      feature_intensity = FALSE,
      feature_norm_intensity = FALSE,
      feature_conc = FALSE
    ),
    is_filtered = FALSE,
    analyses_excluded = NA,
    features_excluded = NA
  )
)


#' Constructor for the `MRMhubExperiment` object
#' @importFrom methods new
#' @param title Title of experiment
#' @param analysis_type Analysis type, one of "lipidomics", "metabolomics", "externalcalib", "others"
#' @return [`MRMhubExperiment`][MRMhubExperiment-class] object
#' @export
MRMhubExperiment <- function(title = "", analysis_type = NA_character_) {
  # NA (unspecified) is allowed; a supplied value is matched against the set
  # documented on @slot/@param. arg_match() supplies the "did you mean" hint.
  if (!is.na(analysis_type)) {
    analysis_type <- rlang::arg_match(
      analysis_type,
      c("lipidomics", "metabolomics", "externalcalib", "others")
    )
  }

  methods::new("MRMhubExperiment", title = title, analysis_type = analysis_type)
}


# TODODO: ALIGN WITH ASSERTION and DEFINE WHERE WHEN TO RUN THIS
check_integrity_analyses <- function(
  data = NULL,
  excl_unmatched_analyses,
  silent,
  max_num_print = 10
) {
  check_data(data)
  if (nrow(data@dataset_orig) > 0 & nrow(data@annot_analyses) > 0) {
    d_xy <- length(setdiff(
      data@dataset_orig$analysis_id |> unique(),
      data@annot_analyses$analysis_id
    ))
    d_yx <- length(setdiff(
      data@annot_analyses$analysis_id,
      data@dataset_orig$analysis_id |> unique()
    ))
    if (d_xy > 0) {
      if (d_xy == length(data@dataset_orig$analysis_id |> unique())) {
        if (!silent) {
          cli::cli_abort(
            "Error: None of the measurements/samples have matching metadata. Please verify data and metadata files."
          )
        } else {
          return(FALSE)
        }
      }
      if (!excl_unmatched_analyses) {
        if (!silent) {
          unmatched <- unique(setdiff(
            unique(data@dataset_orig$analysis_id),
            data@annot_analyses$analysis_id
          ))
          n_total <- length(unique(data@dataset_orig$analysis_id))
          if (d_xy < max_num_print) {
            cli::cli_abort(
              call = NULL,
              "No metadata present for {d_xy} of {n_total} analyses: {stringr::str_flatten_comma(unmatched)}."
            )
          } else {
            cli::cli_abort(
              call = NULL,
              "{d_xy} of {n_total} analyses have no matching metadata."
            )
          }
        } else {
          return(FALSE)
        }
      } else {
        return(TRUE)
      }
    } else if (d_yx > 0) {
      if (!silent) {
        missing_in_data <- unique(setdiff(
          data@annot_analyses$analysis_id,
          unique(data@dataset_orig$analysis_id)
        ))
        n_meta <- length(unique(data@annot_analyses$analysis_id))
        if (d_yx < max_num_print) {
          cli::cli_abort(
            "The following {d_yx} analyses defined in the metadata are not present in the measurement data: {stringr::str_flatten_comma(missing_in_data)}."
          )
        } else {
          cli::cli_abort(
            "{d_yx} of {n_meta} analyses defined in the metadata are not present in the measurement data."
          )
        }
      } else {
        return(FALSE)
      }
    } else {
      data@status_processing <- "check_integrity_analyses pass"
      return(TRUE)
    }
  } else {
    return(TRUE)
  }
}

#' @noRd
get_status_flag <- function(x) {
  ifelse(
    x,
    {
      cli::col_green(cli::symbol$tick)
    },
    {
      cli::col_red(cli::symbol$cross)
    }
  )
}


#' Access slots of a `MRMhubExperiment` object via $ syntax
#'
#' $ syntax can be used to as a shortcut for getting specific variables and results from a `MRMhubExperiment` object
#' @return Value with a variable or a tibble
#' @param x [`MRMhubExperiment`][MRMhubExperiment-class] object
#' @param name [`MRMhubExperiment`][MRMhubExperiment-class] slot
#' @examples
#' mexp <- MRMhubExperiment(title = "Test Experiment", analysis_type = "lipidomics")
#' mexp$analysis_type
#' mexp$title
#' mexp$annot_analyses
#' @importFrom methods slot
#' @export
setMethod(
  f = "$",
  signature = c("MRMhubExperiment"),
  definition = function(x, name) {
    # Define valid slot names
    valid <- c(
      "title",
      "analysis_type",
      "dataset",
      "dataset_orig",
      "annot_analyses",
      "annot_features",
      "annot_istds",
      "annot_responsecurves",
      "annot_qcconcentrations",
      "annot_studysamples",
      "metrics_qc",
      "annot_batches",
      "annot_interferences",
      "dataset_filtered",
      "is_istd_normalized",
      "var_drift_corrected",
      "var_batch_corrected"
    )

    # Check for valid slot name and return value or throw error
    if (!name %in% valid) {
      cli::cli_abort(c(
        "x" = "{.field {name}} is not valid for this object: {.cls {class(x)[1]}}"
      ))
    }

    methods::slot(x, name)
  }
)


#' Check integrity of `MRMhubExperiment` data object
#'
#' @description
#' Helper function that checks the structure and contents of
#' a `MRMhubExperiment` object
#'
#' @param data [`MRMhubExperiment`][MRMhubExperiment-class] object
#' @return silent on success, prints abort message on fail
#' @noRd
check_data <- function(data = NULL) {
  if (is.null(data)) {
    cli::cli_abort(c(
      "x" = "{.arg data} cannot be {.code NULL}, please supply an {.cls MRMhubExperiment}."
    ))
  }
  if (!is(data, "MRMhubExperiment")) {
    cli::cli_abort(c(
      "x" = "{.arg data} must be an {.cls MRMhubExperiment}, not {.cls {class(data)[1]}}."
    ))
  }
}

# Compact one-screen overview shown when a MRMhubExperiment is printed. The full
# dashboard (sample/feature composition, metadata, per-step status) lives in
# `mrmhub_status()`.
setMethod("show", "MRMhubExperiment", function(object) {
  n_analyses <- length(unique(object@dataset$analysis_id))
  n_features <- length(unique(object@dataset$feature_id))
  signal <- if (object@feature_intensity_var == "") {
    "not set"
  } else {
    object@feature_intensity_var
  }
  corrected <- any(object@var_drift_corrected) ||
    any(object@var_batch_corrected)

  cli::cli_h1("{is(object)[[1]]}: {.strong {object@title}}")
  cli::cli_text(
    "{.emph {object@analysis_type}} | {n_analyses} analys{?is/es} and {n_features} feature{?s} | signal: {.field {signal}}"
  )
  cli::cli_text(cli::col_blue(
    "Last step: {.strong {object@status_processing}}"
  ))
  cli::cli_text(
    "Normalized {get_status_flag(object@is_istd_normalized)}  Quantitated {get_status_flag(object@is_quantitated)}  Drift/batch {get_status_flag(corrected)}  Filtered {get_status_flag(object@is_filtered)}"
  )
  cli::cli_text(cli::col_grey(
    "{cli::symbol$info} Use {.code mrmhub_status()} for the full processing and metadata report"
  ))
  invisible(object)
})

#' Detailed processing and metadata report for a `MRMhubExperiment`
#'
#' @description
#' Prints the full status dashboard for a [`MRMhubExperiment`][MRMhubExperiment-class]: sample and feature
#' composition, which metadata tables are populated, the state of each processing
#' step, and any manually excluded analyses or features. Printing the object
#' directly gives the compact one-screen overview instead.
#'
#' @param object A [`MRMhubExperiment`][MRMhubExperiment-class] object.
#' @return The `object`, invisibly.
#' @examples
#' mrmhub_status(MRMhubExperiment(title = "Test", analysis_type = "lipidomics"))
#' @export
mrmhub_status <- function(object) {
  check_data(object)

  d <- object@dataset
  ana <- if (nrow(d) > 0) d[!duplicated(d$analysis_id), ] else d
  n_analyses <- dplyr::n_distinct(d$analysis_id[!is.na(d$analysis_id)])
  signal <- if (object@feature_intensity_var == "") {
    "not set"
  } else {
    object@feature_intensity_var
  }

  # `TYPE n` counts for the qc_types present, ordered by the global level order.
  fmt_qc <- function(qt) {
    tab <- table(factor(
      qt[!is.na(qt)],
      levels = pkg.env$qc_type_annotation$qc_type_levels
    ))
    tab <- tab[tab > 0]
    if (length(tab) == 0) {
      return("")
    }
    paste0(names(tab), " ", as.integer(tab), collapse = ", ")
  }
  # Tick/cross plus the row count when a metadata table is populated.
  flag_n <- function(n) {
    if (n > 0) {
      paste0(get_status_flag(TRUE), " (", n, ")")
    } else {
      get_status_flag(FALSE)
    }
  }
  get_corr_var <- function(vars) {
    vars_names <- names(vars)
    if (length(vars_names) == 0) {
      cli::col_red(cli::symbol$cross)
    } else {
      glue(
        "`",
        stringr::str_flatten_comma(vars_names, last = " and ", na.rm = TRUE),
        "`"
      )
    }
  }
  excl <- function(v) {
    if (all(is.na(v))) {
      cli::col_red(cli::symbol$cross)
    } else {
      glue::glue_collapse(v, sep = ", ", width = 80, last = ", and ")
    }
  }

  cli::cli_h1(is(object)[[1]])
  cli::cli_text(cli::col_blue("Title: {.strong {object@title}}"))
  conc <- if (
    isTRUE(object@is_quantitated) && !is.na(object@conc_analyte_unit)
  ) {
    paste0(" | concentrations: ", object@conc_analyte_unit)
  } else {
    ""
  }
  cli::cli_text(
    "Last step: {.strong {object@status_processing}} | signal: {.field {signal}}{conc}"
  )

  n_batches <- if ("batch_id" %in% names(ana)) {
    dplyr::n_distinct(ana$batch_id[!is.na(ana$batch_id)])
  } else {
    0
  }
  cli::cli_h2("Samples ({n_analyses} analys{?is/es}, {n_batches} batch{?es})")
  cli::cli_ul(id = "S")
  if ("qc_type" %in% names(ana) && nrow(ana) > 0) {
    in_nb <- ana$qc_type %in%
      pkg.env$qc_type_annotation$qc_type_levels_nonblank &
      !is.na(ana$qc_type)
    rest <- !in_nb & !is.na(ana$qc_type)
    cli::cli_li(
      "Study samples & QCs ({sum(in_nb)}):  {fmt_qc(ana$qc_type[in_nb])}"
    )
    if (any(rest)) {
      cli::cli_li("Blanks & other ({sum(rest)}):  {fmt_qc(ana$qc_type[rest])}")
    }
  } else {
    cli::cli_li("No annotated samples")
  }
  cli::cli_end(id = "S")

  n_feat <- dplyr::n_distinct(d$feature_id[!is.na(d$feature_id)])
  n_istd <- if ("is_istd" %in% names(d)) {
    dplyr::n_distinct(d$feature_id[d$is_istd])
  } else {
    0
  }
  n_quant <- if ("is_quantifier" %in% names(d)) {
    dplyr::n_distinct(d$feature_id[d$is_quantifier])
  } else {
    0
  }
  cli::cli_h2("Features ({n_feat})")
  cli::cli_ul(id = "F")
  cli::cli_li("Analytes: {n_feat - n_istd}   Internal standards: {n_istd}")
  cli::cli_li("Quantifiers: {n_quant}   Qualifiers: {n_feat - n_quant}")
  cli::cli_end(id = "F")

  cli::cli_h2("Metadata")
  cli::cli_ul(id = "M")
  cli::cli_li(
    "Analyses/samples: {flag_n(nrow(object@annot_analyses))}   Features/analytes: {flag_n(nrow(object@annot_features))}   Internal standards: {flag_n(nrow(object@annot_istds))}"
  )
  cli::cli_li(
    "Response curves: {flag_n(nrow(object@annot_responsecurves))}   Calibrants/QC concentrations: {flag_n(nrow(object@annot_qcconcentrations))}   Study samples: {flag_n(nrow(object@annot_studysamples))}   Interferences: {flag_n(nrow(object@annot_interferences))}"
  )
  cli::cli_end(id = "M")

  cli::cli_h2("Processing Status")
  cli::cli_ul(id = "P")
  cli::cli_li(
    "Isotope / interference corrected: {get_status_flag(object@is_isotope_corr)}"
  )
  cli::cli_li(
    "ISTD normalized: {get_status_flag(object@is_istd_normalized)}   Quantitated: {get_status_flag(object@is_quantitated)}"
  )
  cli::cli_li(
    "Drift corrected variables:  {get_corr_var(object@var_drift_corrected[object@var_drift_corrected])}"
  )
  cli::cli_li(
    "Batch corrected variables:  {get_corr_var(object@var_batch_corrected[object@var_batch_corrected])}"
  )
  cli::cli_li(
    "QC metrics calculated: {get_status_flag(nrow(object@metrics_qc) > 0)}   Feature filtering applied: {get_status_flag(object@is_filtered)}"
  )
  cli::cli_end(id = "P")

  cli::cli_h2("Exclusion of Analyses and Features")
  cli::cli_ul(id = "E")
  cli::cli_li(
    "Analyses manually excluded (`analysis_id`): {col_red(excl(object@analyses_excluded))}"
  )
  cli::cli_li(
    "Features manually excluded (`feature_id`): {col_red(excl(object@features_excluded))}"
  )
  cli::cli_end(id = "E")

  invisible(object)
}
