#' Manual isotopic interference correction
#'
#' @description Subtract a single, user-specified interference from one feature.
#' Use this for a one-off correction or to validate a factor before trusting the
#' automatic derivation; for the metadata-driven paths use
#' [correct_isotopic_interferences()] (automatic, isotopic) or
#' [correct_custom_interferences()] (declared). The interference is subtracted as:
#' \deqn{Value_{Corrected} = Value_{Feature} - Factor_{Contribution} *
#' Value_{Interfering Feature}}
#'
#' @param data [`MRMhubExperiment`][MRMhubExperiment-class] object
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
#' @return [`MRMhubExperiment`][MRMhubExperiment-class] object
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
  # A feature cannot interfere with itself: the subtraction would scale the
  # feature against itself, zeroing or distorting it.
  if (identical(feature, interfering_feature)) {
    cli::cli_abort(
      "`feature` and `interfering_feature` are identical (`{feature}`). A feature cannot interfere with itself."
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

  # A repeat correction of a feature stacks another subtraction onto an already
  # corrected value -- a silent double-correction. Warn so it is deliberate.
  if (
    any(
      data@dataset$feature_id == feature & data@dataset$interference_corrected,
      na.rm = TRUE
    )
  ) {
    mh_warn(
      "Feature `{feature}` was already interference-corrected; this subtraction is applied on top of the previous one (verify this is intended)."
    )
  }

  # Preserve the raw signal in `feature_intensity_orig` (immutable), matching the
  # metadata-driven correction paths and providing an undo.
  if (
    variable == "feature_intensity" &&
      !"feature_intensity_orig" %in% names(data@dataset)
  ) {
    data@dataset <- data@dataset |>
      mutate(
        feature_intensity_orig = .data$feature_intensity,
        .before = "feature_intensity"
      )
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

  # Correcting an internal standard shifts the normalization of every feature it
  # standardizes -- surface it.
  if (isTRUE_col(is_istd_feature(data, feature))) {
    mh_warn(
      "Corrected feature `{feature}` is an internal standard; this shifts the normalization of every feature it standardizes. Please verify."
    )
  }

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
    "Interference-correction was manually applied to feature `{feature}` (interferer `{interfering_feature}`, factor {interference_contribution})."
  )

  data
}


#' Correct automatically derived isotopic interferences
#'
#' @description Applies the isotopic (M+2) interference corrections previously
#' discovered by [calc_isotopic_interferences()] (and any declared interferences,
#' see [correct_custom_interferences()]) to the raw feature intensities. Aborts
#' with guidance if no interferences have been derived yet.
#'
#' The subtraction is \deqn{value_{corrected} = value_{raw} - K \cdot
#' value_{interferer}} applied on the raw `feature_intensity`. For auto-derived
#' (`source == "auto"`) edges the interferer is clamped at 0 before subtraction
#' and the result clamped at 0 (LICAR parity); declared (`"manual"`) edges are
#' unclamped. See [calc_isotopic_interferences()] for how `K` is computed.
#'
#' A chain (e.g. PC 34:2 > PC 34:1 > PC 34:0) is corrected sequentially by
#' default, each feature using its already-corrected interferer; set
#' `sequential_correction = FALSE` to correct each from the raw interferer. The
#' raw signal is preserved in `feature_intensity_orig`, and the correction is
#' idempotent (re-running restores from raw first).
#'
#' @param data [`MRMhubExperiment`][MRMhubExperiment-class] object.
#' @param variable Name of the variable to correct. Only `"feature_intensity"`
#'   (the raw intensity) is supported. Default: `"feature_intensity"`.
#' @param sequential_correction Logical. If `TRUE` (default), a chain of
#'   interferences is corrected sequentially so each feature uses the
#'   already-corrected signal of its interferer (propagates along the chain). If
#'   `FALSE`, each feature is corrected from the raw interferer, without
#'   propagation.
#' @param neg_to_na If `TRUE`, negative or zero values after correction are
#'   replaced with `NA`. Default: `FALSE`.
#' @return [`MRMhubExperiment`][MRMhubExperiment-class] object with feature intensities corrected.
#' @export
#' @references Gao L., Ji S, Burla B, Wenk MR, Torta F, & Cazenave-Gassiot A
#' (2021). LICAR: An Application for Isotopic Correction of Targeted Lipidomic
#' Data Acquired with Class-Based Chromatographic Separations Using Multiple
#' Reaction Monitoring. *Analytical Chemistry*, 93(6), 3163-3171.
#' \url{https://doi.org/10.1021/acs.analchem.0c04565}
correct_isotopic_interferences <- function(
  data = NULL,
  variable = "feature_intensity",
  sequential_correction = TRUE,
  neg_to_na = FALSE
) {
  check_data(data)
  check_interference_variable(variable)
  edges <- assemble_interference_edges(data)
  if (!any(edges$source == "auto")) {
    cli_abort(c(
      "No isotopic interferences have been derived yet.",
      "i" = "Run {.code calc_isotopic_interferences(mexp, level = ...)} first, then inspect {.code annot_interferences}."
    ))
  }
  apply_interference_edges(data, edges, sequential_correction, neg_to_na)
}


#' Guard: only feature_intensity may be interference-corrected
#' @keywords internal
#' @noRd
check_interference_variable <- function(variable) {
  if (!identical(variable, "feature_intensity")) {
    cli::cli_abort(
      "Currently only correction for raw intensities supported, thus variable must be set to `feature_intensity` or not defined."
    )
  }
}


#' Correct declared (custom) interferences
#'
#' @description Applies the interference corrections you declared in the feature
#' metadata (the legacy `interference_feature_id` / `interference_contribution`
#' columns, and any `source == "manual"` rows in `annot_interferences`) to the raw
#' feature intensities, using the same engine and formula as
#' [correct_isotopic_interferences()]. Use this for in-source fragments,
#' co-eluting isobars or other non-isotopic interferences you know about. Warns
#' and returns the data unchanged if none are defined.
#'
#' @inheritParams correct_isotopic_interferences
#' @return [`MRMhubExperiment`][MRMhubExperiment-class] object with feature intensities corrected.
#' @seealso [correct_isotopic_interferences()], [correct_interference_manual()]
#' @export
correct_custom_interferences <- function(
  data = NULL,
  variable = "feature_intensity",
  sequential_correction = TRUE,
  neg_to_na = FALSE
) {
  check_data(data)
  check_interference_variable(variable)
  edges <- assemble_interference_edges(data)
  if (!any(edges$source != "auto")) {
    mh_warn(
      "No custom (declared) interferences are defined. Nothing to correct. Declare them in the feature metadata or use `correct_interference_manual()`."
    )
    return(data)
  }
  apply_interference_edges(data, edges, sequential_correction, neg_to_na)
}


#' Assemble and de-duplicate the interference edge list
#'
#' Unions the derived (`annot_interferences`) edges with the legacy per-feature
#' manual columns on `annot_features` (tagged `source == "manual"`), then
#' de-duplicates. A feature legitimately carries two edges (front + back) to
#' different overlap types, so the de-dup key is
#' `(feature_id, interference_feature_id, overlap_type)`; when the same triple is
#' defined twice with differing values the manual definition is kept (user
#' override) and a warning is emitted.
#'
#' @param data A [`MRMhubExperiment`][MRMhubExperiment-class].
#' @return A de-duplicated long interference edge tibble.
#' @keywords internal
#' @noRd
assemble_interference_edges <- function(data) {
  legacy_edges <- data@annot_features |>
    filter(!is.na(.data$interference_feature_id)) |>
    select(
      "feature_id",
      "interference_feature_id",
      "interference_contribution"
    ) |>
    mutate(overlap_type = "manual", source = "manual")
  edges <- bind_rows(data@annot_interferences, legacy_edges)
  if (nrow(edges) == 0) {
    return(edges)
  }
  edges <- distinct(edges)
  keyed <- edges |>
    group_by(
      .data$feature_id,
      .data$interference_feature_id,
      .data$overlap_type
    )
  n_conflict <- keyed |>
    summarise(n = dplyr::n(), .groups = "drop") |>
    filter(.data$n > 1) |>
    nrow()
  if (n_conflict > 0) {
    mh_warn(
      "{n_conflict} interference(s) are defined more than once (same feature, interferer and overlap type) with differing values; keeping the manual definition where present."
    )
  }
  keyed |>
    arrange(dplyr::desc(.data$source == "manual")) |>
    slice(1L) |>
    ungroup()
}


#' Apply interference correction (shared engine)
#'
#' Subtracts every edge in `edges` from the raw `feature_intensity`, upstream-first
#' (topological), with LICAR-parity clamping on auto-derived edges. Preserves the
#' raw signal in `feature_intensity_orig` and is idempotent (restores from raw
#' before re-applying). Shared by [correct_isotopic_interferences()] and
#' [correct_custom_interferences()].
#'
#' @param data A [`MRMhubExperiment`][MRMhubExperiment-class].
#' @param edges A de-duplicated interference edge tibble (see
#'   `assemble_interference_edges()`).
#' @param sequential_correction,neg_to_na See the public wrappers.
#' @return The corrected [`MRMhubExperiment`][MRMhubExperiment-class].
#' @keywords internal
#' @noRd
apply_interference_edges <- function(
  data,
  edges,
  sequential_correction = TRUE,
  neg_to_na = FALSE
) {
  # Interference correction operates on raw intensities and runs before
  # normalization/drift/batch. If those already ran, it silently invalidates
  # them (flags reset below) -- warn so the discarded work is not a surprise.
  if (
    data@is_istd_normalized ||
      any(data@var_drift_corrected) ||
      any(data@var_batch_corrected)
  ) {
    mh_warn(
      "Data was already ISTD-normalized/drift/batch-corrected. Interference correction operates on raw intensities and has reset those steps -- re-run them after correcting."
    )
  }

  # `feature_intensity_orig` is the immutable raw snapshot; a re-run restores from
  # it rather than double-correcting (idempotent).
  if (
    data@is_isotope_corr &&
      ("feature_intensity_orig" %in% names(data@dataset))
  ) {
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

  # A feature cannot interfere with itself (would scale it against itself).
  self_edges <- edges |>
    filter(.data$feature_id == .data$interference_feature_id)
  if (nrow(self_edges) > 0) {
    cli_abort(
      "Feature(s) listed as their own interferer: {.val {mh_vec(unique(self_edges$feature_id))}}. A feature cannot interfere with itself; please verify the interference metadata."
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
    # Size-safe per-analysis lookup of one feature's running intensity: a ragged
    # dataset (a feature absent from a given analysis, e.g. a blank) yields a
    # length-0 subset, which `if_else()` cannot recycle. Collapse to a single NA.
    group_value <- function(value, feature_id, wanted) {
      v <- value[feature_id == wanted]
      if (length(v) == 0) NA_real_ else v[1]
    }
    data |>
      group_by(.data$analysis_id) |>
      mutate(
        raw_source = group_value(
          .data$feature_intensity_orig,
          .data$feature_id,
          iid
        ),
        # `feature_intensity_orig` on the target's own row is its running value.
        corr_intensity = if_else(
          .data$feature_id == fid,
          {
            src <- if (is_auto) pmax(.data$raw_source, 0) else .data$raw_source
            v <- .data$feature_intensity_orig - src * fac
            if (is_auto) pmax(v, 0) else v
          },
          NA_real_
        )
      ) |>
      ungroup() |>
      select(-"raw_source") |>
      mutate(
        feature_intensity_orig = if_else(
          !is.na(.data$corr_intensity),
          .data$corr_intensity,
          .data$feature_intensity_orig
        )
      ) |>
      select(-"corr_intensity")
  }

  # Apply corrections iteratively, using the result from the previous iteration.
  # The working copy `d_corrected` accumulates into its own feature_intensity_orig
  # column; data@dataset keeps the immutable raw snapshot.
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
      # not iff its value happened to change.
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

  # Strongly-negative results (below -25% of the raw signal) are unlikely to be
  # measurement noise and usually indicate a mis-defined interference or an
  # unmodeled effect -- distinct from the benign near-zero case above.
  sig_neg_feats <- data@dataset |>
    filter(
      .data$interference_corrected,
      !str_detect(.data$qc_type, "BLK"),
      !is.na(.data$feature_intensity),
      !is.na(.data$feature_intensity_orig),
      .data$feature_intensity_orig > 0,
      .data$feature_intensity < -0.25 * .data$feature_intensity_orig
    ) |>
    dplyr::distinct(.data$feature_id) |>
    dplyr::pull(.data$feature_id)
  if (length(sig_neg_feats) > 0) {
    mh_warn(
      "{length(sig_neg_feats)} feature(s) became strongly negative (below -25% of raw) after correction: {.val {mh_vec(sig_neg_feats)}}. This may indicate a mis-defined interference or an unmodeled effect; please verify."
    )
  }

  data@dataset <- data@dataset |>
    mutate(
      feature_intensity = if_else(
        neg_to_na & .data$interference_corrected & .data$feature_intensity <= 0,
        NA_real_,
        .data$feature_intensity
      )
    )

  # Correcting an internal standard shifts the normalization of every feature it
  # standardizes.
  corrected_istds <- intersect(
    unique(features_to_correct$feature_id),
    data@annot_features$feature_id[isTRUE_col(data@annot_features$is_istd)]
  )
  if (length(corrected_istds) > 0) {
    mh_warn(
      "{length(corrected_istds)} corrected feature(s) are internal standards: {.val {mh_vec(corrected_istds)}}. Correcting an ISTD shifts the normalization of every feature it standardizes; please verify."
    )
  }

  # Update MRMhubExperiment flags
  data@is_isotope_corr <- TRUE
  data@status_processing <- "Isotope-corrected raw data"
  data <- update_after_normalization(data, FALSE)
  # See `correct_interference_manual()`: both drift and batch corrections of
  # `feature_intensity` are invalidated by rewriting it.
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
  n_auto <- sum(features_to_correct$source == "auto")
  n_manual <- nrow(features_to_correct) - n_auto
  mh_success(
    "Interference correction applied to {n_corr} of {get_feature_count(data)} feature(s) ({n_auto} isotopic, {n_manual} custom edge(s))."
  )

  data
}


#' Is a feature an internal standard?
#'
#' @param data A [`MRMhubExperiment`][MRMhubExperiment-class].
#' @param feature_id A feature id.
#' @return `TRUE`/`FALSE`/`NA` from `annot_features$is_istd`.
#' @keywords internal
#' @noRd
is_istd_feature <- function(data, feature_id) {
  data@annot_features$is_istd[
    match(feature_id, data@annot_features$feature_id)
  ]
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
