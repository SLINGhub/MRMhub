#' Manual isotopic interference correction
#'
#' @description The interference is subtracted using following formula:
#' \deqn{Value_{Corrected} = Value_{Feature} - Factor_{Contribution} *
#' Value_{Interfering Feature}}
#'
#' @param data MRMhubExperiment object
#' @param variable Name of the variable to be corrected, e.g.
#'   `feature_intensity`.
#' @param feature Name of feature to be corrected
#' @param interfering_feature Name of feature that is interfering, i.e.
#'   contributing to the signal of `feature`
#' @param interference_contribution Relative portion of the interfering feature
#'   contributing to the feature signal. Must be greater than 0; values are
#'   usually between 0 and 1, and values above 1 trigger a warning.
#' @param neg_to_na If `TRUE`, negative or zero values after correction will be replaced with `NA`. Default: `FALSE`.
#' @param updated_feature_id Optional. New name of corrected feature. If empty
#'   then feature name will not change.
#' @return MRMhubExperiment object
#' @export

#  Example:  mexp <- correct_interference_manual(mexp, "feature_intensity", "PC 32:0 | SM 36:1 M+3", "SM 36:1", 0.0106924, "PC 32:0")

correct_interference_manual <- function(
  data = NULL,
  variable,
  feature,
  interfering_feature,
  interference_contribution,
  neg_to_na = FALSE,
  updated_feature_id = NA
) {
  check_data(data)
  variable_var <- rlang::ensym(variable)

  if (is.null(updated_feature_id) || is.na(updated_feature_id)) {
    updated_feature_id <- NA_character_
  }

  # Validate input
  if (is.na(feature) | !feature %in% data@annot_features$feature_id) {
    cli::cli_abort(col_red(
      "Selected feature is not present in the dataset. Please verify data and `feature` argument."
    ))
  }
  if (
    is.na(interfering_feature) |
      !interfering_feature %in% data@annot_features$feature_id
  ) {
    cli::cli_abort(col_red(
      "Selected interfering feature is not present in the dataset. Please verify data and `feature` argument."
    ))
  }
  if (is.na(variable) | !variable %in% names(data@dataset)) {
    cli::cli_abort(col_red(
      "Variable `{variable}` is not defined in the dataset"
    ))
  }
  if (
    is.na(interference_contribution) |
      !is.numeric(interference_contribution) |
      interference_contribution <= 0
  ) {
    cli::cli_abort(col_red(
      "`interference_contribution` must be a number larger than 0"
    ))
  }
  if (interference_contribution > 1) {
    cli_alert_warning(col_yellow(
      "`interference_contribution` is {interference_contribution}, i.e. greater than 1. Values above 1 are unusual for a signal-contribution factor; please verify."
    ))
  }
  if (
    !is.na(updated_feature_id) &&
      updated_feature_id %in% data@annot_features$feature_id
  ) {
    cli::cli_abort(col_red(
      "Selected new feature id `{updated_feature_id}` is already present in the dataset. Please chose a new unique ID."
    ))
  }

  if (!"interference_corrected" %in% names(data@dataset)) {
    data@dataset <- data@dataset |>
      mutate(interference_corrected = FALSE)
  }

  # Correction
  data@dataset <- data@dataset |>
    group_by(.data$analysis_id) |>
    mutate(
      !!variable_var := if_else(
        .data$feature_id == feature,
        (!!variable_var)[.data$feature_id == feature] -
          interference_contribution *
            (!!variable_var)[.data$feature_id == interfering_feature],
        !!variable_var
      ),
      interference_corrected = if_else(
        .data$feature_id == feature,
        TRUE,
        .data$interference_corrected
      )
    )

  neg_zero_sum <- data@dataset |>
    filter(.data$interference_corrected) |>
    group_by(.data$feature_id, .data$qc_type) |>
    # na.rm: a corrected value can legitimately be NA; without it the count
    # becomes NA and the `if (sum(...) > 0)` below errors with `if (NA)`.
    summarise(negative_count = sum(!!variable_var <= 0, na.rm = TRUE)) |>
    filter(!str_detect(.data$qc_type, "BLK"))

  if (sum(neg_zero_sum$negative_count, na.rm = TRUE) > 0) {
    if (neg_to_na) {
      cli_alert_warning(col_yellow(
        "Interference correction led to {sum(neg_zero_sum$negative_count)} negative or zero values in samples/QCs. All negative/zero values (incl. in Blanks) were replaced with `NA`."
      ))
    } else {
      cli_alert_warning(col_yellow(
        "Interference correction led to {sum(neg_zero_sum$negative_count)} negative or zero values in samples/QCs. Please verify the correction, or set `neg_to_na = TRUE`"
      ))
    }
  }

  data@dataset <- data@dataset |>
    mutate(
      !!variable_var := if_else(
        neg_to_na & .data$interference_corrected & !!variable_var <= 0,
        NA_real_,
        !!variable_var
      )
    )

  if (!is.na(updated_feature_id)) {
    data@dataset <- data@dataset |>
      mutate(
        feature_id = if_else(
          .data$feature_id == feature & .data$interference_corrected,
          updated_feature_id,
          .data$feature_id
        )
      )
  }

  data@is_isotope_corr <- TRUE
  data@status_processing <- "Isotope-corrected raw data"
  data <- update_after_normalization(data, FALSE)
  # The correction rewrites `variable`, so any previous drift *and* batch
  # correction of it no longer applies. Leaving `var_batch_corrected` set made a
  # subsequent `correct_batch_centering()` take its `replace_previous` path and
  # restore the variable from the now-stale `_before` snapshot, silently
  # discarding this correction.
  data@var_drift_corrected <- c(
    feature_intensity = FALSE,
    feature_norm_intensity = FALSE,
    feature_conc = FALSE
  )
  data@var_batch_corrected <- c(
    feature_intensity = FALSE,
    feature_norm_intensity = FALSE,
    feature_conc = FALSE
  )
  data@is_filtered <- FALSE
  data@metrics_qc <- data@metrics_qc[FALSE, ]

  cli_alert_success(col_green(glue::glue(
    "Interference-correction was manually applied to the feature `{variable}`."
  )))

  data
}


#' Apply interference correction
#'
#' @description This function corrects lipidomics feature intensities by
#' subtracting interference (e.g., isotope overlap or in-source fragments). The
#' correction is applied using the following formula: \deqn{value\_corrected =
#' value\_raw - value\_raw\_interfering\_feature \times
#' interference\_contribution}
#'
#' The interfering features and their relative contributions must be defined in
#' the feature metadata.
#'
#' By default, a chain of interferences (e.g., isotopic M+2 interferences of
#' PC 34:2 > PC 34:1 > PC 34:0) is corrected sequentially: each feature is
#' corrected using the already-corrected signal of its interfering feature, so
#' the correction propagates along the chain. To disable this and instead correct
#' each feature independently from the raw (uncorrected) signal of its
#' interfering feature, set `sequential_correction = FALSE`.
#'
#' @details For isotopic interference correction of MRM/PRM data, the relative
#' isotope abundances needed for the calculation (`interference_contribution`) can
#' be calculated using the LICAR application (Gao et al., 2021), see below.
#'
#' @param data MRMhubExperiment object containing lipidomics data.
#' @param variable Name of the variable to be corrected. Default:
#'   `feature_intensity`.
#' @param sequential_correction Logical. If `TRUE` (the default), a chain of
#'   interferences is corrected sequentially, so that each feature is corrected
#'   using the already-corrected signal of its interfering feature (the
#'   correction propagates along the chain). If `FALSE`, each feature is
#'   corrected independently using the raw (uncorrected) signal of its
#'   interfering feature, without propagation.
#' @param neg_to_na If `TRUE`, negative or zero values after correction will be replaced with `NA`. Default: `FALSE`.
#' @return MRMhubExperiment object with feature intensities corrected for
#'   interferences.
#' @export
#' @references Gao L., Ji S, Burla B, Wenk MR, Torta F, Wenk MR, &
#' Cazenave-Gassiot A (2021). LICAR: An Application for Isotopic Correction of
#' Targeted Lipidomic Data Acquired with Class-Based Chromatographic Separations
#' Using Multiple Reaction Monitoring. *Analytical Chemistry*, 93(6), 3163-3171.
#' \url{https://doi.org/10.1021/acs.analchem.0c04565}

correct_interferences <- function(
  data = NULL,
  variable = "feature_intensity",
  sequential_correction = TRUE,
  neg_to_na = FALSE
) {
  check_data(data)

  if (variable != "feature_intensity") {
    cli::cli_abort(
      "Currently only correction for raw intensities supported, thus variable must be set to `feature_intensity` or not defined."
    )
  }
  # Check if data is already interference-corrected
  if (
    data@is_isotope_corr &&
      (c("feature_intensity_orig") %in% names(data@dataset))
  ) {
    cli_alert_info(cli::col_yellow(
      "Data was already interference-corrected. Corrections will be reapplied to raw intensities."
    ))
    data@dataset <- data@dataset |>
      mutate(
        feature_intensity = .data$feature_intensity_orig,
        interference_corrected = FALSE
      )
  } else {
    data@dataset <- data@dataset |>
      mutate(
        feature_intensity_orig = .data$feature_intensity,
        interference_corrected = FALSE,
        .before = "feature_intensity"
      )
  }

  # Join with feature metadata for interference information
  d_correct <- data@dataset |>
    left_join(
      data@annot_features |>
        select(
          "feature_id",
          "interference_feature_id",
          "interference_contribution"
        ),
      by = "feature_id"
    )

  # Get a table with features to correct this table is ordered based on chained
  # relationships between feature_id and interference_feature_id, starting with
  # the most downstream feature in the chain. If the corrections are
  # independent, the order will be based on the order of the features in the
  # dataset. This code also checks for circular dependencies in the interference
  # correction, like LPC 18:2 > LPC 18:1 > LPC 18:0 > LPC 18:2
  # order_chained_columns_tbl() is where a circular interference chain is
  # detected (it stop()s), so the friendly handler must wrap this call, not the
  # arrange() below.
  features_to_correct <- tryCatch(
    d_correct |>
      filter(!is.na(.data$interference_feature_id)) |>
      select(
        "feature_id",
        "interference_feature_id",
        "interference_contribution"
      ) |>
      distinct() |>
      order_chained_columns_tbl(
        "feature_id",
        "interference_feature_id",
        include_chain_id = FALSE,
        disconnected_action = "keep"
      ),
    error = function(e) {
      if (grepl("Circular dependency", conditionMessage(e), fixed = TRUE)) {
        cli_abort(col_red(
          "One or more circular correction(s) detected. Please verify the interference correction details defined in feature metadata."
        ))
      }
      stop(e)
    }
  )

  # Check if there are incomplete interference data
  if (!all(stats::complete.cases(features_to_correct))) {
    cli_abort(
      "Some features have incomplete interference information (i.e., `interference_contribution` or `interference_contribution` missing. Please verify feature metadata."
    )
  }

  if (any(features_to_correct$interference_contribution <= 0)) {
    cli_abort(col_red(
      "`interference_contribution` in the feature metadata must be greater than 0. Please verify feature metadata."
    ))
  }
  if (any(features_to_correct$interference_contribution > 1)) {
    cli_alert_warning(col_yellow(
      "{sum(features_to_correct$interference_contribution > 1)} feature(s) have an `interference_contribution` greater than 1. Values above 1 are unusual; please verify feature metadata."
    ))
  }

  has_overlapping_interferences <- any(
    features_to_correct$interference_feature_id %in%
      features_to_correct$feature_id
  )

  # if sequential_correction is TRUE, reorder features_to_correct to ensure that
  # the most downstream feature is corrected first
  if (sequential_correction) {
    features_to_correct <- features_to_correct |>
      arrange(desc(row_number()))
  }

  # Function to apply correction for each feature set in features_to_correct
  correct_feature_intensity <- function(data, features_to_correct, i) {
    d <- data |>
      group_by(.data$analysis_id) |>
      mutate(
        raw_target = if_else(
          .data$feature_id == features_to_correct$feature_id[i],
          .data$feature_intensity_orig[
            .data$feature_id == features_to_correct$feature_id[i]
          ],
          NA_real_
        ),
        raw_source = if_else(
          .data$feature_id == features_to_correct$feature_id[i],
          .data$feature_intensity_orig[
            .data$feature_id == features_to_correct$interference_feature_id[i]
          ],
          NA_real_
        ),
        rel_interference = if_else(
          .data$feature_id == features_to_correct$feature_id[i],
          features_to_correct$interference_contribution[i],
          NA_real_
        ),
        corr_intensity = if_else(
          .data$feature_id == features_to_correct$feature_id[i],
          .data$raw_target - .data$raw_source * .data$rel_interference,
          NA_real_
        )
      ) |>
      ungroup() |>
      select(-"raw_target", -"raw_source", -"rel_interference") |>
      mutate(
        feature_intensity_orig = if_else(
          !is.na(.data$corr_intensity),
          .data$corr_intensity,
          .data$feature_intensity_orig
        )
      )
    d
  }

  # Apply corrections iteratively, using the result from the previous iteration
  d_corrected <- d_correct
  for (i in seq_len(nrow(features_to_correct))) {
    d_corrected <- correct_feature_intensity(
      d_corrected,
      features_to_correct,
      i
    )
  }

  # copy corrected intensities to original dataset

  data@dataset <- data@dataset |>
    left_join(
      d_corrected |>
        select(
          "analysis_id",
          "feature_id",
          intensity_corrected = "feature_intensity_orig"
        ),
      by = c("analysis_id", "feature_id")
    ) |>
    mutate(
      # A feature is interference-corrected iff it was in the correction set,
      # not iff its value happened to change. Comparing pre/post intensities
      # with `!=` mis-flags zero-effect corrections and returns NA when either
      # intensity is NA. Membership mirrors the single-feature path (see the
      # `if_else(feature_id == feature, TRUE, ...)` above).
      interference_corrected = .data$feature_id %in%
        features_to_correct$feature_id,
      feature_intensity = .data$intensity_corrected
    ) |>
    select(-"intensity_corrected")

  neg_zero_sum <- data@dataset |>
    filter(.data$interference_corrected) |>
    group_by(.data$feature_id, .data$qc_type) |>
    summarise(negative_count = sum(.data$feature_intensity <= 0)) |>
    filter(.data$negative_count > 0)

  if (sum(neg_zero_sum$negative_count) > 0) {
    if (neg_to_na) {
      cli_alert_warning(col_yellow(
        "Interference correction led to negative or zero values in {length(unique(neg_zero_sum$feature_id))} feature(s) in samples/QCs. All negative/zero values (incl. in Blanks) were replaced with `NA`."
      ))
    } else {
      cli_alert_warning(col_yellow(
        "Interference correction led to negative or zero values in {length(unique(neg_zero_sum$feature_id))} feature(s) in samples/QCs. Please verify the correction, or set `neg_to_na = TRUE`"
      ))
    }
  }

  data@dataset <- data@dataset |>
    mutate(
      feature_intensity = if_else(
        neg_to_na & .data$interference_corrected & .data$feature_intensity <= 0,
        NA_real_,
        .data$feature_intensity
      )
    )

  # Update MRMhubExperiment flags

  data@is_isotope_corr <- TRUE
  data@status_processing <- "Isotope-corrected raw data"
  data <- update_after_normalization(data, FALSE)
  # See `correct_interference_manual()`: both drift and batch corrections of
  # `variable` are invalidated by rewriting it.
  data@var_drift_corrected <- c(
    feature_intensity = FALSE,
    feature_norm_intensity = FALSE,
    feature_conc = FALSE
  )
  data@var_batch_corrected <- c(
    feature_intensity = FALSE,
    feature_norm_intensity = FALSE,
    feature_conc = FALSE
  )
  data@is_filtered <- FALSE
  data@metrics_qc <- data@metrics_qc[FALSE, ]

  n_corr <- nrow(features_to_correct)
  cli_alert_success(col_green(glue::glue(
    "Interference-correction has been applied to {n_corr} of the {get_feature_count(data)} features."
  )))

  data
}
