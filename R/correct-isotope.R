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
    cli::cli_abort(
      "Selected feature is not present in the dataset. Please verify data and `feature` argument."
    )
  }
  if (
    is.na(interfering_feature) |
      !interfering_feature %in% data@annot_features$feature_id
  ) {
    cli::cli_abort(
      "Selected interfering feature is not present in the dataset. Please verify data and `feature` argument."
    )
  }
  if (is.na(variable) | !variable %in% names(data@dataset)) {
    cli::cli_abort(
      "Variable `{variable}` is not defined in the dataset"
    )
  }
  if (
    is.na(interference_contribution) |
      !is.numeric(interference_contribution) |
      interference_contribution <= 0
  ) {
    cli::cli_abort(
      "`interference_contribution` must be a number larger than 0"
    )
  }
  if (interference_contribution > 1) {
    mh_warn(
      "`interference_contribution` is {interference_contribution}, i.e. greater than 1. Values above 1 are unusual for a signal-contribution factor; please verify."
    )
  }
  if (
    !is.na(updated_feature_id) &&
      updated_feature_id %in% data@annot_features$feature_id
  ) {
    cli::cli_abort(
      "Selected new feature id `{updated_feature_id}` is already present in the dataset. Please chose a new unique ID."
    )
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

  n_neg_values <- sum(neg_zero_sum$negative_count, na.rm = TRUE)
  n_neg_features <- neg_zero_sum |>
    filter(.data$negative_count > 0) |>
    dplyr::distinct(.data$feature_id) |>
    nrow()
  if (n_neg_values > 0) {
    if (neg_to_na) {
      mh_warn(
        "Interference correction led to {n_neg_values} negative or zero value{?s} in {n_neg_features} feature{?s} (samples/QCs). All negative/zero values (incl. in Blanks) were replaced with `NA`."
      )
    } else {
      mh_warn(
        "Interference correction led to {n_neg_values} negative or zero value{?s} in {n_neg_features} feature{?s} (samples/QCs). Please verify the correction, or set `neg_to_na = TRUE`."
      )
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

  mh_success(
    "Interference-correction was manually applied to the feature `{variable}`."
  )

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
    mh_warn(
      "Data was already interference-corrected. Corrections will be reapplied to raw intensities."
    )
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

  # Assemble the interference edge list (long): the derived (auto) table unioned
  # with the legacy per-feature manual columns on annot_features. Both feed the
  # same engine; `source` gates the LICAR-style negative handling below. A
  # feature can carry two edges (front + back), so this is not a 1:1 join.
  legacy_edges <- data@annot_features |>
    filter(!is.na(.data$interference_feature_id)) |>
    select(
      "feature_id",
      "interference_feature_id",
      "interference_contribution"
    ) |>
    mutate(overlap_type = "manual", source = "manual")
  edges <- bind_rows(data@annot_interferences, legacy_edges) |>
    distinct()

  if (nrow(edges) == 0) {
    mh_warn(
      "No interferences are defined (neither derived nor in the feature metadata). Nothing to correct."
    )
    return(data)
  }

  # Warn when a feature carries both an auto-derived and a manual edge -- the
  # manual M+2 may now be redundant with the derived correction.
  both_src <- edges |>
    group_by(.data$feature_id) |>
    filter(any(.data$source == "auto") & any(.data$source == "manual")) |>
    ungroup()
  if (nrow(both_src) > 0) {
    mh_warn(
      "{length(unique(both_src$feature_id))} feature(s) have both auto-derived and manual interference edges; both are subtracted. Please verify a manual M+2 is not redundant."
    )
  }

  # Order the edges so every interferer that is itself corrected is processed
  # before the feature(s) depending on it (upstream-first). Detects circular
  # chains (e.g. LPC 18:2 > 18:1 > 18:0 > 18:2). The friendly abort message must
  # survive the tryCatch grep.
  features_to_correct <- tryCatch(
    order_interference_edges(edges),
    error = function(e) {
      if (grepl("Circular dependency", conditionMessage(e), fixed = TRUE)) {
        cli_abort(
          "One or more circular correction(s) detected. Please verify the interference correction details."
        )
      }
      stop(e)
    }
  )

  # Check for incomplete interference data
  if (
    !all(stats::complete.cases(features_to_correct[, c(
      "feature_id",
      "interference_feature_id",
      "interference_contribution"
    )]))
  ) {
    cli_abort(
      "Some interferences have incomplete information (`interference_feature_id` or `interference_contribution` missing). Please verify the interference metadata."
    )
  }

  if (any(features_to_correct$interference_contribution <= 0)) {
    cli_abort(
      "`interference_contribution` must be greater than 0. Please verify the interference metadata."
    )
  }
  if (any(features_to_correct$interference_contribution > 1)) {
    mh_warn(
      "{sum(features_to_correct$interference_contribution > 1)} interference(s) have a contribution greater than 1. Values above 1 are unusual; please verify."
    )
  }

  # Interferers must exist as features in the dataset.
  missing_interferers <- setdiff(
    features_to_correct$interference_feature_id,
    unique(data@dataset$feature_id)
  )
  if (length(missing_interferers) > 0) {
    cli_abort(
      "Interfering feature(s) not present in the dataset: {glue::glue_collapse(missing_interferers, sep = ', ')}. Please verify the interference metadata."
    )
  }

  # sequential_correction = TRUE: correct each feature using its already-corrected
  # interferer (propagate along the chain) = the upstream-first order from
  # order_interference_edges(). FALSE: correct from the raw interferer =
  # downstream-first (reverse), so an interferer is still raw when its dependent
  # is processed.
  if (!sequential_correction) {
    features_to_correct <- features_to_correct |>
      arrange(desc(row_number()))
  }

  # Apply the correction for one edge in features_to_correct. `is_auto` (an
  # auto-derived M+2 edge) enables LICAR-parity negative handling: skip the
  # subtraction when the (running-corrected) interferer is <= 0, then clamp the
  # corrected value to 0. The manual path keeps its original unclamped behaviour.
  correct_feature_intensity <- function(data, features_to_correct, i) {
    fid <- features_to_correct$feature_id[i]
    iid <- features_to_correct$interference_feature_id[i]
    fac <- features_to_correct$interference_contribution[i]
    is_auto <- identical(features_to_correct$source[i], "auto")
    data |>
      group_by(.data$analysis_id) |>
      mutate(
        raw_target = if_else(
          .data$feature_id == fid,
          .data$feature_intensity_orig[.data$feature_id == fid],
          NA_real_
        ),
        raw_source = if_else(
          .data$feature_id == fid,
          .data$feature_intensity_orig[.data$feature_id == iid],
          NA_real_
        ),
        corr_intensity = if_else(
          .data$feature_id == fid,
          {
            src <- if (is_auto) pmax(.data$raw_source, 0) else .data$raw_source
            v <- .data$raw_target - src * fac
            if (is_auto) pmax(v, 0) else v
          },
          NA_real_
        )
      ) |>
      ungroup() |>
      select(-"raw_target", -"raw_source") |>
      mutate(
        feature_intensity_orig = if_else(
          !is.na(.data$corr_intensity),
          .data$corr_intensity,
          .data$feature_intensity_orig
        )
      ) |>
      select(-"corr_intensity")
  }

  # Apply corrections iteratively, using the result from the previous iteration
  d_corrected <- data@dataset
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

  n_neg_values <- sum(neg_zero_sum$negative_count)
  n_neg_features <- length(unique(neg_zero_sum$feature_id))
  if (n_neg_values > 0) {
    if (neg_to_na) {
      mh_warn(
        "Interference correction led to {n_neg_values} negative or zero value{?s} in {n_neg_features} feature{?s} (samples/QCs). All negative/zero values (incl. in Blanks) were replaced with `NA`."
      )
    } else {
      mh_warn(
        "Interference correction led to {n_neg_values} negative or zero value{?s} in {n_neg_features} feature{?s} (samples/QCs). Please verify the correction, or set `neg_to_na = TRUE`."
      )
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

  n_corr <- length(unique(features_to_correct$feature_id))
  mh_success(
    "Interference-correction has been applied to {n_corr} of the {get_feature_count(data)} features."
  )

  data
}


#' Order interference edges upstream-first (topological sort)
#'
#' @description Orders a long interference edge table so that every interferer
#' that is itself corrected appears before the feature(s) depending on it, so a
#' sequential correction propagates along the chain. Tolerates two parents per
#' feature (front + back) and detects circular chains via Kahn's algorithm.
#'
#' @param edges A tibble with at least `feature_id` (the corrected feature) and
#'   `interference_feature_id` (its interferer).
#' @return `edges`, row-reordered upstream-first. Errors with a message
#'   containing "Circular dependency" if the graph has a cycle.
#' @keywords internal
#' @noRd
order_interference_edges <- function(edges) {
  nodes <- unique(edges$feature_id)
  # Dependency among corrected features: an interferer that is itself corrected
  # (a node) must be processed first. parent = interferer, child = dependent.
  dep <- edges |>
    filter(.data$interference_feature_id %in% nodes) |>
    distinct(
      parent = .data$interference_feature_id,
      child = .data$feature_id
    )
  indeg <- stats::setNames(rep(0L, length(nodes)), nodes)
  for (ch in dep$child) indeg[[ch]] <- indeg[[ch]] + 1L
  children <- split(dep$child, dep$parent)
  queue <- nodes[indeg[nodes] == 0L]
  ordered <- character(0)
  while (length(queue) > 0) {
    n <- queue[[1]]
    queue <- queue[-1]
    ordered <- c(ordered, n)
    for (ch in children[[n]]) {
      indeg[[ch]] <- indeg[[ch]] - 1L
      if (indeg[[ch]] == 0L) {
        queue <- c(queue, ch)
      }
    }
  }
  if (length(ordered) < length(nodes)) {
    stop("Circular dependency detected in the interference chain.")
  }
  edges[order(match(edges$feature_id, ordered)), , drop = FALSE]
}
