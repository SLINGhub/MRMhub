#' Write a data-processing report (Excel)
#'
#' Generates a data processing report from a `MRMhubExperiment` object and writes it to an Excel file.
#' The report includes information on the data processing steps, quality control metrics, feature concentrations, and metadata.
#' Following tables will be created as sheets in the EXCEL file:
#'
#' - Info: General  information including date, author, and MRMhub version, processing status and feature concentration unit.
#' - Feature_QC_metrics: Quality control metrics of all features.
#' - QCfilt_x_StudySamples: Feature (QC)-filtered data (variable defined via `filtered_variable`) in study samples ('SPL'). Filter have to be set via [filter_features_qc()]. The _x_ corresponds to the `filtered_variable` argument.
#' - QCfilt_x_AllSamples: Feature (QC)-filtered data (variable defined via `filtered_variable`) in all samples. Filter have to be set via [filter_features_qc()]. The _x_ corresponds to the `filtered_variable` argument.
#' - Conc_FullDataset: Final feature concentrations from the full, non-filtered dataset.
#' - Raw_Intensity_FullDataset: Raw feature intensities from the full, non-filtered dataset.
#' - Norm_Intensity_FullDataset: Normalized feature intensities from the full, non-filtered dataset.
#' - SampleMetadata:  Analysis metadata that was imported and used for processing steps
#' - FeatureMetadata: Feature metadata that was imported and used for processing steps
#' - InternalStandards: Internal standards metadata with concentrations
#' - BatchInfo: Information on batches and positions of first and last analysis/sample
#' in each batch
#' - Interferences: Derived and declared interference relationships (interfering
#' feature, contribution factor, overlap type, source) with the per-feature
#' correction impact when the correction has been applied.
#'
#'
#' @param data A `MRMhubExperiment` object containing original and processed data and metadata.
#' @param path A character string specifying the file name and path for the Excel file.
#' If the path does not include an `.xlsx` extension, it is added automatically.
#' @param filtered_variable A character string specifying the variable name in the
#' filtered data to be exported. It must be one of "conc", "intensity", "norm_intensity",
#' "response", "area", "height", "conc_raw", "rt", or "fwhm". The defined variable
#' name will be included in the sheet name. Default is "conc".
#' @param normalized_variable A character string indicating if and which normalized feature values  (by reference sample) to include in the report.See also `[calibrate_by_reference()]`.
#' @param overwrite A logical value indicating whether to overwrite the file if it already exists. Default is `TRUE`.
#' @details
#' If certain data sets are not available, the function includes empty tables for the corresponding dataset.
#'
#' Concentration corresponds to the final concentration values after applying isotope correction, and drift and batch correction, if applicable.
#' If any corrections, such as drift or batch correction, were applied to raw or normalized intensities, the exported values will reflect these corrections.
#'
#' @seealso
#' [normalize_by_istd()], [quantify_by_istd()], [quantify_by_calibration()], [calibrate_by_reference()]
#'
#' @return The function does not return a value. It writes the report to the specified Excel file.
#'
#'
#'
#' @examples
#' \dontrun{
#' # Assuming `mrmhubexp` is a MRMhubExperiment object and `output_path` is a valid path
#' save_report_xlsx(data = mrmhubexp, path = "output_path/report.xlsx")
#' }
#'
#' @export

save_report_xlsx <- function(
  data = NULL,
  path,
  filtered_variable = "conc",
  normalized_variable = NA,
  overwrite = TRUE
) {
  check_data(data)

  filtered_variable <- str_remove(filtered_variable, "feature_")
  filtered_variable_strip <- filtered_variable
  rlang::arg_match(
    filtered_variable,
    c(
      "area",
      "height",
      "intensity",
      "intensity_normalized",
      "norm_intensity",
      "norm_intensity_normalized",
      "response",
      "conc",
      "conc_normalized",
      "conc_raw",
      "rt",
      "fwhm"
    )
  )
  filtered_variable <- stringr::str_c("feature_", filtered_variable)
  if (data@is_filtered) {
    check_var_in_dataset(data@dataset, filtered_variable)
  } #TODO dataset_filt?

  normalized_variable <- str_remove(normalized_variable, "feature_")
  normalized_variable <- stringr::str_c("feature_", normalized_variable)

  if (!stringr::str_detect(path, "\\.xlsx$")) {
    path <- paste0(path, ".xlsx")
  }

  if (is.na(normalized_variable)) {
    if ("feature_conc_normalized" %in% names(data@dataset)) {
      normalized_variable <- "feature_conc_normalized"
    }
    if ("feature_norm_intensity_normalized" %in% names(data@dataset)) {
      normalized_variable <- c(
        normalized_variable,
        "feature_norm_intensity_normalized"
      )
    }
    if ("feature_intensity_normalized" %in% names(data@dataset)) {
      normalized_variable <- c(
        normalized_variable,
        "feature_intensity_normalized"
      )
    }

    normalized_variable <- normalized_variable[!is.na(normalized_variable)]

    if (length(normalized_variable) > 1) {
      cli_abort(
        "More than one normalized feature variable found in dataset. Please specify which one to include in the report via `normalized_variable`."
      )
    }
  } else {
    if (!paste0(normalized_variable, "_normalized") %in% names(data@dataset)) {
      cli_abort(
        "Normalized feature variable '{normalized_variable}' not found in dataset. Please check the name or modify `normalized_variable`."
      )
    }
  }

  if (nrow(data@dataset) > 0) {
    d_intensity_wide <- data@dataset |>
      #dplyr::filter(.data$qc_type %in% c("SPL", "TQC", "BQC", "NIST", "LTR", "PBLK", "SBLK", "UBLK", "MBLK")) |>
      dplyr::select(dplyr::any_of(c(
        "analysis_id",
        "qc_type",
        "acquisition_time_stamp",
        "feature_id",
        "feature_intensity"
      ))) |>
      tidyr::pivot_wider(
        names_from = "feature_id",
        values_from = "feature_intensity",
        values_fn = check_single_pivot_value
      )
  } else {
    d_intensity_wide <- tibble(
      "No ISTD-normalized intensities available." = NA
    ) |>
      tibble::add_row()
  }

  if (data@is_istd_normalized) {
    d_norm_intensity_wide <- data@dataset |>
      #dplyr::filter(.data$qc_type %in% c("SPL", "TQC", "BQC", "NIST", "LTR", "PBLK", "SBLK", "UBLK", "MBLK")) |>
      dplyr::select(dplyr::any_of(c(
        "analysis_id",
        "qc_type",
        "acquisition_time_stamp",
        "feature_id",
        "feature_norm_intensity"
      ))) |>
      tidyr::pivot_wider(
        names_from = "feature_id",
        values_from = "feature_norm_intensity",
        values_fn = check_single_pivot_value
      )
  } else {
    d_norm_intensity_wide <- tibble(
      "No ISTD-normalized intensities available." = NA
    ) |>
      tibble::add_row()
  }

  if (data@is_quantitated) {
    d_conc_wide <- data@dataset |>
      #dplyr::filter(!.data$qc_type %in% c("PBLK", "SBLK", "UBLK", "NIST", "LTR")) |>
      dplyr::filter(!str_detect(.data$feature_id, "\\(IS")) |>
      dplyr::select(dplyr::any_of(c(
        "analysis_id",
        "qc_type",
        "acquisition_time_stamp",
        "feature_id",
        "feature_conc"
      ))) |>
      tidyr::pivot_wider(
        names_from = "feature_id",
        values_from = "feature_conc",
        values_fn = check_single_pivot_value
      )
  } else {
    d_conc_wide <- tibble("No concentration data available." = NA) |>
      tibble::add_row()
  }

  if (data@is_filtered) {
    d_conc_wide_QC_SPL <- data@dataset_filtered |>
      dplyr::filter(.data$qc_type %in% c("SPL")) |>
      dplyr::select(dplyr::any_of(c(
        "analysis_id",
        "feature_id",
        filtered_variable
      ))) |>
      dplyr::filter(!str_detect(.data$feature_id, "\\(IS")) |>
      tidyr::pivot_wider(
        names_from = "feature_id",
        values_from = any_of(filtered_variable),
        values_fn = check_single_pivot_value
      )

    d_conc_wide_QC_all <- data@dataset_filtered |>
      dplyr::select(dplyr::any_of(c(
        "analysis_id",
        "qc_type",
        "feature_id",
        filtered_variable
      ))) |>
      dplyr::filter(!str_detect(.data$feature_id, "\\(IS")) |>
      tidyr::pivot_wider(
        names_from = "feature_id",
        values_from = any_of(filtered_variable),
        values_fn = check_single_pivot_value
      )
  } else {
    filtered_variable_strip <- ""
    d_conc_wide_QC_SPL <- tibble("No qc-filtered data available." = NA) |>
      tibble::add_row()
    d_conc_wide_QC_all <- tibble("No qc-filtered data available." = NA) |>
      tibble::add_row()
    #d_wide_QC_SPL_normalized <- tibble("No qc-filtered normalized data available." = NA) |> tibble::add_row()
    #d_wide_QC_all_normalized <- tibble("No qc-filtered normalized data available." = NA) |> tibble::add_row()
  }

  if (length(normalized_variable) > 0) {
    d_wide_all_normalized <- data@dataset |>
      dplyr::filter(.data$qc_type %in% c("SPL")) |>
      dplyr::select(dplyr::any_of(c(
        "analysis_id",
        "feature_id",
        normalized_variable
      ))) |>
      dplyr::filter(!str_detect(.data$feature_id, "\\(IS")) |>
      tidyr::pivot_wider(
        names_from = "feature_id",
        values_from = any_of(normalized_variable),
        values_fn = check_single_pivot_value
      )
  } else {
    d_wide_all_normalized <- tibble(
      "No reference sample normalized data available." = NA
    ) |>
      tibble::add_row()
  }
  # Interference relationships (derived + declared), with per-feature impact when
  # the correction has been applied -- documents the correction in the report.
  edges_report <- assemble_interference_edges(data)
  if (nrow(edges_report) == 0) {
    d_interferences <- tibble("No interferences defined." = NA) |>
      tibble::add_row()
  } else {
    d_interferences <- edges_report
    if (
      all(
        c("feature_intensity_orig", "interference_corrected") %in%
          names(data@dataset)
      )
    ) {
      pct_impact <- data@dataset |>
        dplyr::filter(
          .data$interference_corrected,
          !is.na(.data$feature_intensity_orig),
          .data$feature_intensity_orig > 0
        ) |>
        dplyr::mutate(
          pct = 100 *
            (.data$feature_intensity_orig - .data$feature_intensity) /
            .data$feature_intensity_orig
        ) |>
        dplyr::group_by(.data$feature_id) |>
        dplyr::summarise(
          pct_impact = round(stats::median(.data$pct, na.rm = TRUE), 2),
          .groups = "drop"
        )
      d_interferences <- dplyr::left_join(
        d_interferences,
        pct_impact,
        by = "feature_id"
      )
    }
  }

  d_info <- tibble::tribble(
    ~Info,
    ~Value,
    "Date Report",
    as.character(lubridate::now()),
    "Author",
    Sys.info()[["user"]],
    "MRMhub Version",
    as.character(utils::packageVersion("mrmhub")[[1]]),
    "",
    "",
    "feature_conc Unit",
    get_conc_unit(
      data@annot_analyses$sample_amount_unit,
      get_conc_analyte_unit(data)
    )
  )

  if (nrow(data@metrics_qc) == 0) {
    qc_metrics <- tibble(tibble(
      "Feature qc metrics has not been calculated." = NA
    )) |>
      tibble::add_row()
  } else {
    qc_metrics <- data@metrics_qc
  }

  if (nrow(data@metrics_calibration) == 0) {
    metrics_calibration <- tibble(tibble(
      "Calibration metrics have not been calculated." = NA
    )) |>
      tibble::add_row()
  } else {
    metrics_calibration <- data@metrics_calibration
  }

  if (filtered_variable_strip == "norm_intensity") {
    filtered_variable_strip <- "normInt"
  }
  if (filtered_variable_strip != "") {
    name_filt <- paste0(
      "_",
      paste0(
        toupper(substr(filtered_variable_strip, 1, 1)),
        substr(filtered_variable_strip, 2, nchar(filtered_variable_strip))
      )
    )
  } else {
    name_filt <- ""
  }
  name_filt_spl <- paste0("QCfilt", name_filt, "_StudySamples")
  name_filt_all <- paste0("QCfilt", name_filt, "_AllSamples")
  #name_filt_spl_normalized <- paste0("QCfilt",name_filt,"_RefNorm_StudySpl")
  #name_filt_all_normalized <- paste0("QCfilt",name_filt,"_RefNorm_AllSpl")
  name_all_normalized <- stringr::str_replace(
    str_remove(normalized_variable, "feature_"),
    "_",
    " "
  )
  name_all_normalized <- paste0(
    stringr::str_to_title(name_all_normalized),
    "_NormalizedByRef_Full"
  )
  name_all_normalized <- stringr::str_remove(name_all_normalized, " Normalized")

  table_list <- list(
    "Info" = d_info,
    "Feature_QC_metrics" = qc_metrics,
    "Calibration_metrics" = metrics_calibration,
    name_filt_spl = d_conc_wide_QC_SPL,
    name_filt_all = d_conc_wide_QC_all,
    #name_filt_spl_normalized = d_wide_QC_SPL_normalized,
    #name_filt_all_normalized = d_wide_QC_all_normalized,
    "Raw_Intensity_FullDataset" = d_intensity_wide,
    "Norm_Intensity_FullDataset" = d_norm_intensity_wide,
    "Conc_FullDataset" = d_conc_wide,
    name_all_normalized = d_wide_all_normalized,
    "SampleMetadata" = if (nrow(data@annot_analyses) == 0) {
      data@annot_analyses |> tibble::add_row()
    } else {
      data@annot_analyses
    },
    "FeatureMetadata" = if (nrow(data@annot_features) == 0) {
      data@annot_features |> tibble::add_row()
    } else {
      data@annot_features
    },
    "InternalStandards" = if (nrow(data@annot_istds) == 0) {
      data@annot_istds |> tibble::add_row()
    } else {
      data@annot_istds
    },
    "BatchInfo" = if (nrow(data@annot_batches) == 0) {
      tibble("No batches defined" = NA) |> tibble::add_row()
    } else {
      data@annot_batches
    },
    "Interferences" = d_interferences
  )

  if (length(normalized_variable) == 0) {
    table_list$name_all_normalized <- NULL
    tab_color = c(
      "#d7fc5d",
      "#34fac5",
      "#34fac5",
      "#ff170f",
      "#9e0233",
      "#0A83ad",
      "#0313ad",
      "#7113ad",
      "#c9c9c9",
      "#c9c9c9",
      "#c9c9c9",
      "#c9c9c9",
      "#c9c9c9"
    )
  } else {
    names(table_list)[9] <- c(name_all_normalized)
    tab_color = c(
      "#d7fc5d",
      "#34fac5",
      "#34fac5",
      "#ff170f",
      "#9e0233",
      "#0A83ad",
      "#0313ad",
      "#7113ad",
      "#f7b37c",
      "#c9c9c9",
      "#c9c9c9",
      "#c9c9c9",
      "#c9c9c9",
      "#c9c9c9"
    )
  }

  names(table_list)[4:5] <- c(name_filt_spl, name_filt_all)

  if (rlang::is_interactive()) {
    message("Saving report to disk - please wait...")
  }
  wb <- openxlsx2::write_xlsx(
    x = table_list,
    #file = path,
    na.strings = "",
    # Length-based so adding a sheet needs no parallel-vector bookkeeping: every
    # sheet is a table; only the "Info" sheet (first) omits the first row/col
    # header styling.
    as_table = rep(TRUE, length(table_list)),
    col_names = TRUE,
    grid_lines = FALSE,
    col_widths = "auto",
    first_col = c(FALSE, rep(TRUE, length(table_list) - 1)),
    first_row = c(FALSE, rep(TRUE, length(table_list) - 1)),
    tab_color = tab_color
  )

  # if(length(normalized_variable) == 0){
  #   wb <- openxlsx2::wb_remove_worksheet(wb, 9)
  # }

  openxlsx2::wb_save(
    wb = wb,
    file = path,
    overwrite = overwrite
  )

  txtitle <- if (data@title != "") {
    glue::glue(" of experiment '{data@title}' ")
  } else {
    " "
  }
  mh_success(
    "The data processing report{txtitle}has been saved to {.file {path}}."
  )
}


#' Export data to a CSV file
#'
#' This function exports specific unprocessed or pr ocessed feature variable
#' (e.g. intensities or concentrations) from a `MRMhubExperiment` object to a CSV file.
#' Allows selection of features and optional QC filtering.
#' @param data MRMhubExperiment object
#' @param path File name with path of exported CSV file
#' @param variable Variable to be exported, must be present in the data and any of "area", "height", "intensity", "norm_intensity", "response", "conc", "conc_raw", "rt", "fwhm".
#' @param qc_types QC types to be plotted. Can be a vector of QC types or a regular expression pattern. `NA` (default) displays all available QC/Sample types.
#' @param filter_data A logical value indicating whether to use all data
#' (default) or only QC-filtered data (filtered via [filter_features_qc()]). Default is `FALSE`.
#' @param include_qualifier A logical value indicating whether to include
#' qualifier features. Default is `NA`, which will be automatically set to `FALSE`
#' if `variable` is `conc` or `conc_raw`, and `FALSE` otherwise.
#' @param include_istd A logical value indicating whether to include internal
#' standard (ISTD) features. Default is `NA`, which will be automatically set to `FALSE`
#' if `variable` is ''norm_intensity`, `conc` or `conc_raw`, and `TRUE` otherwise.
#' @param include_feature_filter Feature(s) to include by `feature_id`, as a
#'   character vector. Each element is matched exactly when it names an existing
#'   feature, otherwise treated as a regex; elements combine with OR. A full ID
#'   (e.g. `"S1P d18:0 [M>60]"`) needs no escaping, while patterns like `"PC|PE"`
#'   still work. `NA` or `""` ignores the filter.
#' @param exclude_feature_filter Feature(s) to exclude by `feature_id`, matched
#'   the same way as `include_feature_filter`. `NA` or `""` ignores the filter.
#' @param add_qctype Add the QC type as column
#'
#' @seealso
#' [normalize_by_istd()], [quantify_by_istd()], [quantify_by_calibration()], [calibrate_by_reference()]
#'
#' @export
save_dataset_csv <- function(
  data = NULL,
  path,
  variable,
  qc_types = NA,
  filter_data = FALSE,
  include_qualifier = NA,
  include_istd = NA,
  include_feature_filter = NA,
  exclude_feature_filter = NA,
  add_qctype = NA
) {
  check_data(data)
  if (missing(path) || !rlang::is_string(path) || is.na(path)) {
    cli::cli_abort(
      "{.arg path} must be a single, non-missing file path (a string)."
    )
  }
  variable <- str_remove(variable, "feature_")
  variable_strip <- variable
  rlang::arg_match(
    variable,
    c(
      "area",
      "height",
      "intensity",
      "norm_intensity",
      "response",
      "conc",
      "intensity_raw",
      "norm_intensity_raw",
      "conc_raw",
      "rt",
      "fwhm",
      "intensity_normalized",
      "norm_intensity_normalized",
      "conc_normalized",
      "conc_beforecal"
    )
  )
  variable <- stringr::str_c("feature_", variable)
  check_var_in_dataset(data@dataset, variable)
  variable_sym = rlang::sym(variable)

  # Auto-choose some arg values if user does not define

  if (is.na(include_qualifier)) {
    if (variable %in% c("feature_conc", "feature_conc_raw")) {
      include_qualifier <- FALSE
    } else {
      include_qualifier <- TRUE
    }
  }

  if (is.na(include_istd)) {
    if (
      variable %in%
        c("feature_conc", "feature_conc_raw", "feature_norm_intensity")
    ) {
      include_istd <- FALSE
    } else {
      include_istd <- TRUE
    }
  }

  if (is.na(add_qctype)) {
    add_qctype <- !(length(qc_types) == 1)
  }

  if (!(variable %in% names(data@dataset))) {
    cli::cli_abort(
      "Variable '{variable}' has not yet been calculated. Please process data or choose other variable."
    )
  }

  if (all(is.na(qc_types))) {
    qc_types <- unique(data$dataset$qc_type)
  }

  # Subset dataset according to arguments
  d_filt <- get_dataset_subset(
    data,
    filter_data = filter_data,
    qc_types = qc_types,
    include_qualifier = include_qualifier,
    include_istd = include_istd,
    include_feature_filter = include_feature_filter,
    exclude_feature_filter = exclude_feature_filter
  )

  if (add_qctype) {
    flds <- c("analysis_id", "qc_type", "feature_id")
  } else {
    flds <- c("analysis_id", "feature_id")
  }

  ds <- d_filt |>
    dplyr::select(all_of(c(flds, variable))) |>
    tidyr::pivot_wider(
      names_from = "feature_id",
      values_from = !!variable_sym,
      values_fn = check_single_pivot_value
    )

  readr::write_csv(ds, file = path, col_names = TRUE)
  if (variable_strip == "conc") {
    variable_strip <- "concentration"
  }
  mh_success(
    "{stringr::str_to_title(variable_strip)} values for {nrow(ds)} analyses and {length(unique(d_filt$feature_id))} features have been exported to '{path}'."
  )
}

#' Save feature QC metrics to CSV
#'
#' This function exports the feature information and QC (Quality Control) metrics
#' from a MRMhubExperiment object to a CSV file.
#'
#' @param data A MRMhubExperiment object containing the QC metrics.
#' @param path A string specifying the file path where the CSV file will be saved.
#' @return A tibble with the QC metrics that have been exported.
#' @export
#'
save_feature_qc_metrics <- function(data = NULL, path) {
  check_data(data)
  if (missing(path) || !rlang::is_string(path) || is.na(path)) {
    cli::cli_abort(
      "{.arg path} must be a single, non-missing file path (a string)."
    )
  }

  # Verify that the QC metrics have been calculated
  if (nrow(data@metrics_qc) == 0) {
    cli::cli_abort(
      "Feature QC metrics has not yet been calculated. Please run 'calc_qc_metrics()' first."
    )
  }

  # Write the QC metrics to a CSV file
  readr::write_csv(data@metrics_qc, file = path, col_names = TRUE)

  mh_success(
    "Feature QC metrics table was saved to '{path}'."
  )

  # Return the QC metrics invisibly as a side-effect
  invisible(data@metrics_qc)
}

#' Saves a Excel (xlsx) file with metadata templates
#'
#' This function saves a XLSX file with metadata template to the specified location.
#'
#' @param path File path where the XLSX file with templates will be saved.
#' If left empty (default), the file will be saved in the current working directory
#' under the file "metadata_template.xlsx"
#' @export
#'

save_metadata_templates <- function(path = "metadata_template.xlsx") {
  # Locate the template file inside the package
  template_path <- system.file(
    "extdata",
    "mrmhub_metadata_templates.xlsx",
    package = "mrmhub"
  )

  if (fs::file_exists(path)) {
    cli_abort(
      "A file with this name already exists at the specified location. Please delete it or choose a different filename or location."
    )
  }

  if (template_path == "") {
    cli_abort(
      "Template file not found in package data. Please re-install `mrmhub`."
    )
  }

  # Copy the template to the desired location
  fs::file_copy(template_path, path, overwrite = TRUE)
  mh_success(
    "Metadata table templates were saved to '{path}'."
  )
}


#' Saves a MRMhub Metadata Organizer template
#'
#' This function saves a XLSX file with metadata template to the specified location.
#'
#' @param path File path where the MRMhub Metadata Organizer file will be saved.
#' If left empty (default), the file will be saved in the current working directory
#' under the file "metadata_msorganiser_template.xlsx"
#' @export
#'

save_metadata_msorganiser_template <- function(
  path = "metadata_msorganiser_template.xlsx"
) {
  # Locate the template file inside the package
  template_path <- system.file(
    "extdata",
    "metadata_msorganiser_template.xlsx",
    package = "mrmhub"
  )

  if (fs::file_exists(path)) {
    cli_abort(
      "A file with this name already exists at the specified location. Please delete it or choose a different filename or location."
    )
  }

  if (template_path == "") {
    cli_abort(
      "Template file not found in package data. Please re-install `mrmhub`."
    )
  }

  # Copy the template to the desired location
  fs::file_copy(template_path, path, overwrite = TRUE)
  mh_success(
    "A MRMhub Metadata Organizer template was saved to '{path}'."
  )
}
