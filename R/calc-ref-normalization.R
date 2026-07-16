#' Calibrate feature values using a reference sample
#'
#' @description
#' This function calibrates feature abundances based on a specified reference sample.
#' Calibration can be applied to the entire dataset using one or more reference samples,
#' or batch-wise using reference sample analyses present within each batch.
#' For both approaches, multiple measurements of the same reference sample are
#' summarized using either `mean` (default) or `median` (set by the `summarize_fun` argument).
#'
#' @details
#' Calibration can be performed in two ways, either absolute, resulting in
#' concentrations, or relative, resulting in ratios:
#'
#' 1. Absolute calibration (when `absolute_calibration = TRUE`)
#'
#'    Calibrates (or re-calibrates) feature abundances based on known concentrations of the corresponding features
#'    defined for a reference sample. The calibrated concentration for a given analyte is calculated as:
#'
#'    \deqn{c_\textrm{cal}^\textrm{Analyte} = \frac{c_\textrm{sample}^\textrm{Analyte}}{c_\textrm{ref}^\textrm{Analyte}} \times c_\textrm{known}^\textrm{Analyte}}
#'
#'    The input variable can either `conc`, `norm_intensity`, or `intensity, whereas the result will
#'    always be stored under the variable`conc` (concentration), in the unit defined
#'    for the feature concentrations in the reference sample.
#'
#'    Metadata requirements:
#'    - `sample_id` and `analyte_id` must be defined for the reference sample and features in the analysis and feature metadata, respectively.
#'    - Known analyte concentrations must be defined in the `QC concentration` metadata for the for the reference sample
#'    - An error will be raised  if no concentrations are defined for any features
#'
#'    Missing analyte concentrations for the reference sample can be handled via `undefined_conc_action` with following options:
#'    - `original`: Keep original feature values, i.e. the non-calibrated values will be returned. *Note*: this is only available when `variable = conc`. Use with caution to avoid mixing units.
#'    - `na`: Set affected features values to `NA`
#'    - `error`: The function stops with error in case of any undefined reference sample feature concentration.
#'    - In case all feature concentrations are undefined, the function will stop with an error.
#'
#'    The re-calibrated feature concentrations are stored as `conc`, overwriting existing `conc` values.
#'    The original `conc` values are stored as `conc_beforecal`.
#'
#'    The ratio between the measured and expected (known) concentrations in the
#'    reference sample is available via the feature variable `feature_conc_ratio`
#'    and is calculated as follows:
#'
#'    \deqn{c_\textrm{ratio}^\textrm{Analyte} = \frac{c_\textrm{measured}^\textrm{Analyte}}{c_\textrm{expected}^\textrm{Analyte}}}
#'
#'    where \eqn{c_\textrm{measured}} is the measured (non-calibrated) concentration, and
#'    \eqn{c_\textrm{expected}} is the known or reference concentration for the same analyte.
#'     A bias value of 1 indicates perfect agreement; values above or below 1 indicate over- or underestimation.
#'
#'    To export the calibrated concentrations use `save_dataset_csv()` with `variable = "conc",
#'    or to export non-calibrated values with `variable = "conc_beforecal"`.
#'    When saving the MRMhub XLSX report, the calibrated concentrations will also be stored as `conc`.
#'
#' 2. Normalization (relative calibration, `absolute_calibration = FALSE`)
#'
#'    Normalizes features abundances with corresponding feature abundances in a reference sample,
#'    resulting in ratios. Any available feature abundance variable
#'    (i.e., `conc`, `norm_intensity`, or `intensity`) can be used as input. The normalization is calculate for all present features.
#'    The resulting output will be stored as `[VARIABLE]_normalized`, whereby `[VARIABLE]` is the input variable, e.g., `conc_normalized`.

#'
#'    To export the normalized abundances , use `save_dataset_csv()` with `variable = "[VARIABLE]_normalized"`
#'    For MRMhub XLSX report, use `save_report_xlsx()` with same variable setting as for `save_dataset_csv()` to
#'    When saving the MRMhub XLSX report via `save_report_xlsx()`, availble unfiltered normalized feature abundances
#'    will be included by default. To include filtered normalized feature abundances, set `filtered_variable = "[VARIABLE]_normalized"`.
#'
#'
#' @param data A `MRMhubExperiment` object containing the metabolomics data to be normalized
#' @param variable Character string indicating which data type to calibrate Must be
#'   one of: "intensity", "norm_intensity", or "conc"
#' @param reference_sample_id Character vector specifying the sample ID(s) to use as
#'   reference(s) or standards. When more than one ID is given, all analyses
#'   whose `sample_id` matches any of them are pooled and summarized together
#'   (per feature, and per batch when `batch_wise = TRUE`).
#' @param absolute_calibration Logical indicating whether to perform absolute calibration using
#'   known concentrations of the reference sample (TRUE) or relative calibration (FALSE).
#' @param batch_wise Logical indicating whether to perform calibration for each batch seperately (TRUE) or for all samples together (FALSE).
#' @param summarize_fun Either "mean" or "median". If `absolute_calibration = TRUE`,
#' this function is used to summarize the reference sample concentrations across analyses of specified `reference_sample_id`. Default is "mean".
#' @param store_conc_ratio Logical. Whether to store the ratio of measured
#' (non-calibrated) compared to the expected (known) concentrations. Only applied if `absolute_calibration = TRUE`.
#' This ratio is stored under the feature variable `feature_conc_ratio`. By default it is `TRUE` when `variable = 'conc'`, otherwise `FALSE`.
#' @param undefined_conc_action Character string specifying how to handle features
#'   without defined concentrations in reference samples when `absolute_calibration = TRUE`.
#'   Must be one of `"original"` (keep original values), `"na"` (set to `NA`), or
#'   `"error"`. Required when `absolute_calibration = TRUE` (no default).
#' @param store_normalized Logical indicating whether to keep the normalized values in the dataset
#' when `absolute_calibration = TRUE`. Default is FALSE. These values are then stored
#' as `[VARIABLE]_normalized`, where `[VARIABLE]` is the input variable, e.g., `conc`.
#' @return A `MRMhubExperiment` object with calibrated data
#' @seealso
#' [normalize_by_istd()], [quantify_by_istd()], [quantify_by_calibration()]
#'
#' @export

calibrate_by_reference <- function(
  data,
  variable,
  reference_sample_id,
  absolute_calibration,
  batch_wise = FALSE,
  summarize_fun = "mean",
  store_conc_ratio = NULL,
  undefined_conc_action = NULL,
  store_normalized = FALSE
) {
  check_data(data)

  if (absolute_calibration && is.null(undefined_conc_action)) {
    cli::cli_abort(col_red(
      "When using `absolute_calibration = TRUE`, then `undefined_conc_action` must be specified, as either 'original', 'na', or 'error'"
    ))
  }
  if (!is.null(undefined_conc_action)) {
    undefined_conc_action <- rlang::arg_match(
      undefined_conc_action,
      c("original", "na", "error")
    )
  }

  # Check if the reference sample is present in the dataset
  if (!any(data@dataset$sample_id %in% reference_sample_id)) {
    cli::cli_abort(col_red(
      "The specified `reference_sample_id` is not present in the dataset. Please verify `reference_sample_id` and analysis metadata (column `sample_id`)."
    ))
  }

  # collapsed for user-facing messages (reference_sample_id may hold >1 id)
  ref_ids_txt <- glue::glue_collapse(
    reference_sample_id,
    sep = ", ",
    last = " and "
  )

  rlang::arg_match(summarize_fun, c("mean", "median"))

  variable_strip <- str_remove(variable, "feature_")
  rlang::arg_match(variable_strip, c("intensity", "norm_intensity", "conc"))
  variable <- stringr::str_c("feature_", variable_strip)
  variable_sym <- rlang::sym(variable)
  variable_norm <- stringr::str_c("feature_", variable_strip, "_normalized")
  variable_norm_sym <- rlang::sym(variable_norm)
  variable_beforecal_sym <- rlang::sym(stringr::str_c(
    "feature_",
    variable_strip,
    "_beforecal"
  ))
  check_var_in_dataset(data@dataset, variable)

  if (is.null(store_conc_ratio)) {
    store_conc_ratio = (variable == "feature_conc")
  }

  if (
    variable != "feature_conc" &&
      !is.null(undefined_conc_action) &&
      undefined_conc_action == "original"
  ) {
    cli::cli_abort(col_red(
      "When using `undefined_conc_action = 'original'`, the variable 'conc' must be used as input. See the function's documentation for more details."
    ))
  }

  if (store_conc_ratio && variable != "feature_conc") {
    cli::cli_abort(col_red(
      "When using `store_conc_ratio = TRUE`, the variable 'conc' must be used as input. See the function's documentation for more details."
    ))
  }

  if (batch_wise) {
    adj_groups <- c("feature_id", "batch_id")
  } else {
    adj_groups <- c("feature_id")
  }
  txt_batchwise <- ifelse(batch_wise, "batch-wise ", "")

  d_temp <- data@dataset |>
    select(any_of(c(
      "analysis_id",
      "sample_id",
      "batch_id",
      "feature_id",
      "analyte_id",
      variable
    )))

  if (batch_wise) {
    refs_present <- d_temp |>
      dplyr::group_by(.data$batch_id) |>
      summarise(has_ref = any(.data$sample_id %in% reference_sample_id)) |>
      pull() |>
      all()

    if (!refs_present) {
      cli::cli_abort(col_red(
        "The specified reference sample `{ref_ids_txt}` is missing from one or more batches. Please check the batch structure in analysis metadata."
      ))
    }
  }

  d_temp <- d_temp |>
    dplyr::group_by(!!!syms(adj_groups)) |>
    dplyr::mutate(
      ref_divisor = match.fun(summarize_fun)(
        pull(
          filter(
            pick(everything()),
            .data$sample_id %in% reference_sample_id
          ),
          !!variable_sym
        ),
        na.rm = TRUE
      ),
      # A zero, missing, or non-finite reference summary would turn the
      # normalization into Inf/NaN; return NA for those groups instead.
      var_normalized = dplyr::if_else(
        is.finite(.data$ref_divisor) & .data$ref_divisor != 0,
        !!variable_sym / .data$ref_divisor,
        NA_real_
      )
    ) |>
    ungroup()

  # Warn which groups had an unusable (zero/empty/non-finite) reference summary.
  d_bad_ref <- d_temp |>
    dplyr::filter(!is.finite(.data$ref_divisor) | .data$ref_divisor == 0) |>
    dplyr::distinct(!!!syms(adj_groups))
  if (nrow(d_bad_ref) > 0) {
    cli::cli_warn(c(
      "!" = "The reference summary was zero or undefined for {nrow(d_bad_ref)} group{?s}; normalized values there were set to {.val {NA_real_}}.",
      "i" = "Check that reference sample{?s} {.val {reference_sample_id}} have non-zero values for the affected features."
    ))
  }
  d_temp <- d_temp |> dplyr::select(-"ref_divisor")

  if (absolute_calibration) {
    # Check if the reference sample has concentration values
    if (
      absolute_calibration &&
        !any(
          reference_sample_id %in% unique(data@annot_qcconcentrations$sample_id)
        )
    ) {
      cli::cli_abort(col_red(
        "No concentration values found for the reference sample `{ref_ids_txt}`. Please verify QC concentration metadata."
      ))
    }

    # Check if the reference sample has the same concentration unit for all features

    ref_feature_conc_unit <- unique(
      data@annot_qcconcentrations[
        data@annot_qcconcentrations$sample_id %in% reference_sample_id,
      ]$concentration_unit
    )

    if (absolute_calibration && all(is.na(ref_feature_conc_unit))) {
      cli::cli_abort(col_red(
        "No concentration units found for features of reference sample '{ref_ids_txt}'. Please check concentration units in QC concentration metadata."
      ))
    } else if (absolute_calibration && length(ref_feature_conc_unit) > 1) {
      cli::cli_abort(col_red(
        "Different unit used for feature concentrations in reference sample '{ref_ids_txt}'. Please check concentration units in QC concentration metadata."
      ))
    }

    if (
      length(
        setdiff(
          unique(
            data@dataset[
              data@dataset$sample_id %in% reference_sample_id,
            ]$analyte_id
          ),
          unique(
            data@annot_qcconcentrations[
              data@annot_qcconcentrations$sample_id %in% reference_sample_id,
            ]$analyte_id
          )
        ) >
          0
      )
    ) {
      if (undefined_conc_action == "error") {
        cli::cli_abort(col_red(
          "One or more feature concentration are not defined in the reference sample {ref_ids_txt}. Please verify QC concentration metadata or modify `undefined_conc_action` argument"
        ))
      } else if (undefined_conc_action == "na") {
        cli::cli_alert_warning(col_yellow(
          "One or more feature concentration are not defined in the reference sample {ref_ids_txt}. `NA` will be returned for these features. To change this, modify `undefined_conc_action` argument."
        ))
      } else if (undefined_conc_action == "original") {
        cli::cli_alert_warning(col_yellow(
          "One or more feature concentration are not defined in the reference sample {ref_ids_txt}. Original values will be returned for these. To change this, modify `undefined_conc_action` argument."
        ))
      } else {
        cli::cli_abort(col_red(
          "Invalid value for `undefined_conc_action`. Must be one of: 'original', 'na', or 'error'"
        ))
      }
    }

    # Get the reference sample concentrations

    if (data@is_filtered) {
      cli::cli_alert_warning(col_yellow(
        "Previously filtered dataset is no longer valid and has been cleared. Please re-apply feature filtering."
      ))
      data@is_filtered <- FALSE
      data@metrics_qc <- data@metrics_qc[FALSE, ]
    }

    # One known concentration per analyte across the reference sample(s). The
    # signal divisor above already pools the reference samples per group, so the
    # concentration must likewise collapse to a single value per analyte.
    # `distinct()` merges reference samples that agree; genuinely conflicting
    # concentrations for an analyte are ambiguous and would otherwise silently
    # duplicate every measurement of that analyte (a many-to-many join), so we
    # abort - mirroring the concentration-unit consistency check above.
    d_ref_conc <- data@annot_qcconcentrations |>
      filter(.data$sample_id %in% reference_sample_id) |>
      dplyr::select(
        "analyte_id",
        ref_conc = "concentration",
        ref_conc_unit = "concentration_unit"
      ) |>
      dplyr::distinct()

    conflicting_conc <- d_ref_conc |>
      dplyr::count(.data$analyte_id) |>
      dplyr::filter(.data$n > 1)
    if (nrow(conflicting_conc) > 0) {
      cli::cli_abort(col_red(c(
        "Conflicting reference concentrations for {nrow(conflicting_conc)} analyte{?s} across reference sample{?s} {ref_ids_txt}.",
        "i" = "Affected analyte{?s}: {.val {conflicting_conc$analyte_id}}",
        "i" = "Each analyte must have a single reference concentration. Please verify QC concentration metadata."
      )))
    }

    d_temp <- d_temp |>
      dplyr::left_join(
        d_ref_conc,
        by = c("analyte_id"),
        relationship = "many-to-one"
      ) |>
      dplyr::group_by(!!!syms(adj_groups)) |>
      mutate(
        var_calibrated = if_else(
          !is.na(.data$ref_conc),
          .data$var_normalized * .data$ref_conc,
          if (undefined_conc_action == "original") !!variable_sym else NA_real_
        )
      )

    if (store_conc_ratio) {
      n_zero_refconc <- sum(!is.na(d_temp$ref_conc) & d_temp$ref_conc == 0)
      if (n_zero_refconc > 0) {
        cli::cli_warn(
          "{n_zero_refconc} concentration ratio{?s} had a zero reference concentration and {?was/were} set to {.val {NA_real_}}."
        )
      }
      d_temp <- d_temp |>
        # A zero reference concentration would make the ratio Inf; return NA.
        mutate(
          feature_conc_ratio = dplyr::if_else(
            .data$ref_conc == 0,
            NA_real_,
            !!variable_sym / .data$ref_conc
          )
        )
    }

    d_temp <- d_temp |>
      dplyr::select(-"ref_conc") |>
      ungroup()

    if (variable == "feature_conc") {
      data@dataset <- data@dataset |>
        mutate(feature_conc_beforecal = .data$feature_conc)
    }

    data@dataset <- data@dataset |>
      dplyr::select(
        -any_of(c(
          "var_calibrated",
          "var_normalized",
          "feature_conc_ratio",
          variable_norm
        ))
      ) |>
      dplyr::left_join(
        d_temp |>
          dplyr::select(any_of(c(
            "analysis_id",
            "feature_id",
            "var_normalized",
            "var_calibrated",
            "feature_conc_ratio"
          ))),
        by = c("analysis_id", "feature_id")
      ) |>
      dplyr::mutate(feature_conc = .data$var_calibrated)

    if (store_normalized) {
      data@dataset <- data@dataset |>
        rename(!!variable_norm_sym := "var_normalized")
    } else {
      data@dataset <- data@dataset |> dplyr::select(-"var_normalized")
    }
    n_features_with_conc <- data@annot_qcconcentrations |>
      filter(.data$sample_id %in% reference_sample_id) |>
      nrow()

    if (variable_strip == "conc") {
      cli_alert_success(cli::col_green(
        "{n_features_with_conc} feature concentrations were {txt_batchwise}re-calibrated using the reference sample {ref_ids_txt}."
      ))
    } else {
      cli_alert_success(cli::col_green(
        "{n_features_with_conc} feature concentrations were {txt_batchwise}calculated using the defined reference sample concentrations."
      ))
    }

    cli::cli_alert_info(col_green(
      "Concentrations are given in {ref_feature_conc_unit}."
    ))

    data <- update_after_quantitation(data, is_quantitated = TRUE)

    data@is_filtered <- FALSE
    data@metrics_qc <- data@metrics_qc[FALSE, ]

    data@status_processing <- paste0(
      "Re-calibrated",
      " ",
      data@status_processing
    )
  } else {
    # If absolute_calibration is FALSE, create a new variable variable_noncalib to backup values before calibration and then join data@dataset with d_temp and rename var_normalized to variable.
    data@dataset <- data@dataset |>
      dplyr::left_join(
        d_temp |> dplyr::select("feature_id", "analysis_id", "var_normalized"),
        by = c("analysis_id", "feature_id")
      ) |>
      mutate(!!variable_norm_sym := .data$var_normalized) |>
      dplyr::select(-"var_normalized")

    cli_alert_success(cli::col_green(
      "All features were {txt_batchwise}normalized with reference sample {ref_ids_txt} features."
    ))
    cli::cli_alert_info(col_green(
      "Unit is: sample [{variable_strip}] / {ref_ids_txt} [{variable_strip}]"
    ))

    data@status_processing <- paste0(
      "Reference sample normalized",
      " ",
      data@status_processing
    )
  }
  data
}
