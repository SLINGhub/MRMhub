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
#' @slot dataset_orig Original imported analysis data. Required fields:
#' @slot dataset Processed analysis data. Required fields:
#' @slot dataset_filtered Processed analysis data. Required fields:
#' @slot annot_analyses Annotation of analyses/runs
#' @slot annot_features Annotation of measured features.
#' @slot annot_istds Annotation of Internal Standard concs.
#' @slot annot_responsecurves Annotation of response curves (RQC). Required fields
#' @slot annot_qcconcentrations Annotation of calibration curves. Required fields
#' @slot annot_studysamples Annotation of study samples. Required fields:
#' @slot annot_batches Annotation of batches. Required fields:
#' @slot metrics_qc QC information for each measured feature
#' @slot metrics_calibration Calibration metrics calculated from external calibration curves for each measured feature
#' @slot status_processing Status within the data processing workflow
#' @slot is_istd_normalized Flag if data has been ISTD normalized
#' @slot is_quantitated Flag if data has been quantitated using ISTD and sample amount
#' @slot is_filtered Flag if data has been filtered based on QC parameters
#' @slot is_isotope_corr Flag if one or more features have been isotope corrected
#' @slot has_outliers_tech Flag if data has technical analysis/sample outliers
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
    metrics_qc = "tbl_df",
    metrics_calibration = "tbl_df",
    status_processing = "character",
    is_istd_normalized = "logical",
    is_quantitated = "logical",
    is_filtered = "logical",
    has_outliers_tech = "logical",
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
    has_outliers_tech = FALSE,
    analyses_excluded = NA,
    features_excluded = NA
  )
)


#' Constructor for the MRMhubExperiment object
#' @importFrom methods new
#' @param title Title of experiment
#' @param analysis_type Analysis type, one of "lipidomics", "metabolomics", "externalcalib", "others"
#' @return `MRMhubExperiment` object
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


#' Access slots of a MRMhubExperiment object via $ syntax
#'
#' $ syntax can be used to as a shortcut for getting specific variables and results from a MRMhubExperiment object
#' @return Value with a variable or a tibble
#' @param x MRMhubExperiment object
#' @param name MRMhubExperiment slot
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


#' Check integrity of MRMhubExperiment data object
#'
#' @description
#' Helper function that checks the structure and contents of
#' a MRMhubExperiment object
#'
#' @param data MRMhubExperiment object
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

setMethod("show", "MRMhubExperiment", function(object) {
  cli::cli_par()
  cli::cli_h1(is(object)[[1]])
  cli::cli_text(cli::col_blue("Title: {.strong {object@title}}"))
  cli::cli_end()

  cli::cli_par()
  cli::cli_text(cli::col_blue(
    "Processing status: {.strong {object@status_processing}}"
  ))
  cli::cli_end()

  cli::cli_h2("Annotated Raw Data")
  cli::cli_ul(id = "A")
  cli::cli_li("Analyses: {length(unique(object@dataset$analysis_id))}")
  cli::cli_li("Features: {length(unique(object@dataset$feature_id))}")
  cli::cli_li(
    "Raw signal used for processing: `{object@feature_intensity_var}`"
  )
  cli::cli_end(id = "A")

  cli::cli_h2("Metadata")
  cli::cli_ul(id = "B")
  cli::cli_li(
    "Analyses/samples: {.strong {get_status_flag(nrow(object@annot_analyses) > 0)}}"
  )
  cli::cli_li(
    "Features/analytes: {.strong {get_status_flag(nrow(object@annot_features) > 0)}}"
  )
  cli::cli_li(
    "Internal standards: {.strong {get_status_flag(nrow(object@annot_istds) > 0)}}"
  )
  cli::cli_li(
    "Response curves:  {.strong {get_status_flag(nrow(object@annot_responsecurves) > 0)}}"
  )
  cli::cli_li(
    "Calibrants/QC concentrations:  {.strong {get_status_flag(nrow(object@annot_qcconcentrations) > 0)}}"
  )
  cli::cli_li(
    "Study samples:  {.strong {get_status_flag(nrow(object@annot_studysamples) > 0)}}"
  )
  cli::cli_end(id = "B")

  cli::cli_h2("Processing Status")
  cli::cli_ul(id = "C")
  cli::cli_li("Isotope corrected: {get_status_flag(object@is_isotope_corr)}")
  cli::cli_li("ISTD normalized: {get_status_flag(object@is_istd_normalized)}")
  cli::cli_li("ISTD quantitated: {get_status_flag(object@is_quantitated)}")

  get_corr_var <- function(vars) {
    vars_names <- names(vars)
    if (length(vars_names) == 0) {
      # Red cross if the vector is empty
      return(cli::col_red(cli::symbol$cross))
    } else {
      return(glue(
        "`",
        stringr::str_flatten_comma(vars_names, last = " and ", na.rm = TRUE),
        "`"
      ))
    }
  }

  cli::cli_li(
    "Drift corrected variables:  {get_corr_var(object@var_drift_corrected[object@var_drift_corrected])}"
  )
  cli::cli_li(
    "Batch corrected variables:  {get_corr_var(object@var_batch_corrected[object@var_batch_corrected])}"
  )
  cli::cli_li(
    "Feature filtering applied:  {get_status_flag(object@is_filtered)}"
  )
  cli::cli_end(id = "C")
  cli::cli_h2("Exclusion of Analyses and Features")
  cli::cli_ul(id = "D")

  if (all(is.na(object@analyses_excluded))) {
    # Red cross if the vector is empty
    str <- cli::col_red(cli::symbol$cross)
  } else {
    str <- glue::glue_collapse(
      object@analyses_excluded,
      sep = ", ",
      width = 80,
      last = ", and "
    )
  }

  cli::cli_li("Analyses manually excluded (`analysis_id`): {col_red(str)}")

  if (all(is.na(object@features_excluded))) {
    # Red cross if the vector is empty
    str <- cli::col_red(cli::symbol$cross)
  } else {
    str <- glue::glue_collapse(
      object@features_excluded,
      sep = ", ",
      width = 80,
      last = ", and "
    )
  }

  cli::cli_li("Features manually excluded (`feature_id`): {col_red(str)}")

  cli::cli_end(id = "D")
})
