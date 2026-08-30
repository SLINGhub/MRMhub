# Batch-correction methods and the shared scaffolding they run through.
#
# All batch-correction entry points (`correct_batch_centering()`,
# `correct_batch_combat()`, `correct_batch_serrf()`) are `mexp -> mexp`
# transforms that share the same three-part shape:
#   1. `prepare_batch_correction()` - validate, derive the `feature_*` column
#      names, run the drift/batch state machine that picks the starting data,
#      and build the long `ds` handed to the engine.
#   2. a method-specific engine that maps `ds` to a `d_res` tibble carrying
#      `y`, `y_adj`, `y_fit_after`, `y_fit_after_adj`, `was_corrected`.
#   3. `finalize_batch_correction()` - report the QC-CV change, snapshot the
#      `_before`/`_fit` columns, write the corrected values back, and flip the
#      status flags so downstream steps stay compatible.
# Centering keeps a per-feature engine (`fun_batch.correction`, in
# correct-drift-batch.R); ComBat and SERRF are cross-feature matrix methods.

# ---- Shared scaffolding ------------------------------------------------------

#' Prepare a batch correction: validate, pick starting data, build `ds`
#'
#' Internal helper shared by all `correct_batch_*()` functions. Runs the
#' drift/batch state machine (mirroring the recommended pipeline order) to decide
#' which data the correction starts from, snapshots raw values on the first
#' correction, and returns the long tibble the engine operates on plus the
#' derived column names the finalizer needs.
#'
#' @param data A [`MRMhubExperiment`][MRMhubExperiment-class] object.
#' @param variable One of "intensity", "norm_intensity", or "conc" (with or
#'   without the `feature_` prefix).
#' @param ref_qc_types Character vector of QC types used as batch references.
#' @param feature_list Optional feature selection (character vector or a single
#'   regular expression); `NULL` selects all features.
#' @param log_transform_internal Whether the guard should treat the data as
#'   log-transformed (drops non-positive values before a log step).
#' @param replace_previous Replace a previous batch correction or add on top.
#' @param replace_exisiting_trendcurves Reseed the plotting trend curves.
#' @return A list (`ctx`) with the mutated `data`, the long `ds`, the derived
#'   `variable_*` names, `is_first_correction`, `var_names`, `feature_list`,
#'   `ref_qc_types` and `nbatches`.
#' @keywords internal
#' @noRd
prepare_batch_correction <- function(
  data,
  variable,
  ref_qc_types,
  feature_list = NULL,
  log_transform_internal = TRUE,
  replace_previous = TRUE,
  replace_exisiting_trendcurves = FALSE
) {
  check_data(data)

  if (!all(ref_qc_types %in% unique(data@dataset$qc_type))) {
    cli::cli_abort(
      "One or more specified `qc_types` are not present in the dataset. Please verify data or analysis metadata."
    )
  }

  variable_strip <- str_remove(variable, "feature_")
  rlang::arg_match(variable_strip, c("intensity", "norm_intensity", "conc"))
  variable <- stringr::str_c("feature_", variable_strip)
  variable_sym <- rlang::sym(variable)
  variable_raw <- paste0(variable, "_raw")
  variable_before <- paste0(variable, "_before")
  variable_fit <- paste0(variable_before, "_fit")
  variable_raw_fit <- paste0(variable_raw, "_fit")
  variable_fit_sym <- rlang::sym(variable_fit)
  variable_fit_after <- paste0(variable, "_fit_after")
  variable_smoothed_fit_after <- paste0(variable, "_smoothed_fit_after")
  variable_smoothed <- paste0(variable, "_smoothed")

  check_var_in_dataset(data@dataset, variable)

  # State machine: decide what the correction starts from, based on whether the
  # variable was already drift- and/or batch-corrected. Identical logic to the
  # original inline `correct_batch_centering()` so all methods behave the same.
  is_first_correction <- FALSE

  if (data@var_drift_corrected[[variable]]) {
    if (data@var_batch_corrected[[variable]]) {
      if (replace_previous) {
        mh_warn(
          "Replacing previous `{variable_strip}` batch correction of drift-corrected data."
        )
        data@dataset[[variable]] <- data@dataset[[variable_smoothed]]
        data@dataset[[variable_fit_after]] <- data@dataset[[
          variable_smoothed_fit_after
        ]]
      } else {
        mh_warn(
          "Adding batch correction on top of previous `{variable_strip}` drift and batch corrections."
        )
      }
    } else {
      data@dataset[[variable_smoothed]] <- data@dataset[[variable]]
      data@dataset[[variable_smoothed_fit_after]] <- data@dataset[[
        variable_fit_after
      ]]
      mh_warn(
        "Adding batch correction on top of `{variable_strip}` drift-correction."
      )
    }
  } else {
    if (data@var_batch_corrected[[variable]]) {
      if (replace_previous) {
        mh_warn("Replacing previous `{variable_strip}` batch correction.")
        data@dataset[[variable]] <- data@dataset[[variable_before]]
        data@dataset[[variable_fit_after]] <- data@dataset[[variable_fit]]
      } else {
        mh_warn(
          "Adding batch correction on top of previous `{variable_strip}` batch correction."
        )
      }
    } else {
      mh_warn("Adding batch correction to `{variable_strip}` data.")
      is_first_correction <- TRUE
      data@dataset[[variable_raw]] <- data@dataset[[variable]]

      # Seed horizontal per-batch reference-QC medians as the "fit" so
      # plot_runscatter() has trend curves even without a prior drift correction.
      data@dataset <- data@dataset |>
        mutate(
          !!variable_fit_sym := median(
            .data[[variable]][.data$qc_type %in% ref_qc_types],
            na.rm = TRUE
          ),
          .by = c("feature_id", "batch_id")
        )
      data@dataset[[variable_fit_after]] <- data@dataset[[variable_fit]]
    }
  }

  if (replace_exisiting_trendcurves) {
    data@dataset <- data@dataset |>
      mutate(
        !!variable_fit_sym := median(
          .data[[variable]][.data$qc_type %in% ref_qc_types],
          na.rm = TRUE
        ),
        .by = c("feature_id", "batch_id")
      )
    data@dataset[[variable_fit_after]] <- data@dataset[[variable_fit]]
  }

  ds <- data@dataset |>
    select(any_of(c(
      "analysis_id",
      "feature_id",
      "qc_type",
      "batch_id",
      y_fit_after = variable_fit_after,
      y = variable
    )))

  if (!is.null(feature_list)) {
    if (length(feature_list) == 1) {
      ds <- ds |>
        dplyr::filter(stringr::str_detect(.data$feature_id, feature_list))
      if (nrow(ds) == 0) {
        cli::cli_abort(
          "The feature filter set via `feature_list` does not match any feature in the dataset."
        )
      }
    } else {
      if (!all(feature_list %in% unique(ds$feature_id))) {
        cli::cli_abort(
          "One or more feature(s) specified with `feature_list` are not present in the dataset."
        )
      }
      ds <- ds |> dplyr::filter(.data$feature_id %in% feature_list)
    }
  }

  # Zero/negative values cannot be log-transformed downstream; set them to NA
  # and report (only relevant for the log-space methods).
  if (log_transform_internal) {
    count_negative_or_zero <- ds |>
      group_by(.data$feature_id) |>
      summarise(count = sum(.data$y <= 0, na.rm = TRUE)) |>
      filter(.data$count > 0)
    if (nrow(count_negative_or_zero) > 0) {
      ds$y[ds$y <= 0] <- NA_real_
      mh_warn(
        "{nrow(count_negative_or_zero)} feature(s) contain one or more zero or negative `{variable_strip}` values. Verify your data or use `log_transform_internal = FALSE`."
      )
    }
  }

  nbatches <- length(unique(ds$batch_id))
  if (nbatches < 2) {
    cli_abort("Batch correction was not applied as there is only one batch.")
  }

  var_names <- case_when(
    variable_strip == "conc" ~ "concentrations",
    variable_strip == "norm_intensity" ~ "normalized intensities",
    variable_strip == "intensity" ~ "intensities"
  )

  list(
    data = data,
    ds = ds,
    variable = variable,
    variable_strip = variable_strip,
    var_names = var_names,
    variable_raw = variable_raw,
    variable_before = variable_before,
    variable_fit = variable_fit,
    variable_raw_fit = variable_raw_fit,
    variable_fit_after = variable_fit_after,
    is_first_correction = is_first_correction,
    feature_list = feature_list,
    ref_qc_types = ref_qc_types,
    log_transform_internal = log_transform_internal,
    nbatches = nbatches
  )
}


#' Finalize a batch correction: report, write back, flip flags
#'
#' Internal helper shared by all `correct_batch_*()` functions. Reports the
#' median per-feature QC-CV change in study samples, snapshots the pre-correction
#' `_before`/`_fit` columns, writes the corrected values into the working
#' variable, and invalidates downstream processing so the object stays
#' pipeline-compatible.
#'
#' @param ctx The list returned by `prepare_batch_correction()`.
#' @param d_res Engine output: one row per `analysis_id` x `feature_id` with
#'   `y`, `y_adj`, `y_fit_after`, `y_fit_after_adj`, `was_corrected`.
#' @param method_phrase Human-readable method name for the success message
#'   (e.g. "ComBat batch correction").
#' @param uncorrected_reason Clause describing why some feature/batch
#'   combinations were skipped, inserted into the warning.
#' @return The updated [`MRMhubExperiment`][MRMhubExperiment-class].
#' @keywords internal
#' @noRd
finalize_batch_correction <- function(
  ctx,
  d_res,
  method_phrase,
  uncorrected_reason = "had no usable reference-QC ({.val {ref_qc_types}}) values"
) {
  data <- ctx$data
  variable <- ctx$variable
  var_names <- ctx$var_names
  feature_list <- ctx$feature_list
  ref_qc_types <- ctx$ref_qc_types
  nbatches <- ctx$nbatches
  is_first_correction <- ctx$is_first_correction
  variable_fit <- ctx$variable_fit
  variable_fit_after <- ctx$variable_fit_after

  variable_sym <- rlang::sym(variable)
  variable_before_sym <- rlang::sym(ctx$variable_before)
  variable_fit_sym <- rlang::sym(variable_fit)
  variable_fit_after_sym <- rlang::sym(variable_fit_after)
  variable_raw_fit_sym <- rlang::sym(ctx$variable_raw_fit)

  # Report feature/batch combinations that were left uncorrected but held data.
  d_uncorrected <- d_res |>
    dplyr::ungroup() |>
    dplyr::filter(!.data$was_corrected) |>
    dplyr::filter(any(!is.na(.data$y)), .by = c("feature_id", "batch_id")) |>
    dplyr::distinct(.data$feature_id, .data$batch_id)
  if (nrow(d_uncorrected) > 0) {
    cli::cli_warn(c(
      "!" = paste0(
        "{nrow(d_uncorrected)} feature/batch combination{?s} ",
        uncorrected_reason,
        " and {cli::qty(nrow(d_uncorrected))}{?was/were} left uncorrected; original values were kept."
      ),
      "i" = "Affected feature{?s}: {.val {unique(d_uncorrected$feature_id)}}"
    ))
  }

  d_res_sum <- d_res |>
    group_by(.data$feature_id) |>
    summarise(
      cv_before = cv(.data$y[.data$qc_type == "SPL"], na.rm = TRUE),
      cv_after = cv(.data$y_adj[.data$qc_type == "SPL"], na.rm = TRUE),
      cv_diff = .data$cv_after - .data$cv_before,
    ) |>
    ungroup() |>
    summarise(
      cv_before = median(.data$cv_before, na.rm = TRUE),
      cv_after = median(.data$cv_after, na.rm = TRUE),
      cv_diff_median = median(.data$cv_diff, na.rm = TRUE),
      cv_diff_min = format(
        round(min(.data$cv_diff, na.rm = TRUE), 1),
        nsmall = 2
      ),
      cv_diff_max = format(
        round(max(.data$cv_diff, na.rm = TRUE), 1),
        nsmall = 2
      ),
      cv_diff_text = format(round(.data$cv_diff_median, 1), nsmall = 1)
    ) |>
    ungroup()

  nfeat <- length(unique(d_res$feature_id))

  if (data@var_drift_corrected[[variable]]) {
    mh_success(
      "{method_phrase} of {nbatches} batches was applied to drift-corrected {var_names} of {if_else(all(is.na(feature_list)), 'all', 'the selected')} {nfeat} features."
    )
  } else {
    mh_success(
      "{method_phrase} of {nbatches} batches was applied to raw {var_names} of {if_else(all(is.na(feature_list)), 'all', 'the selected')} {nfeat} features."
    )
  }

  text_change <- case_when(
    round(d_res_sum$cv_after, 2) - round(d_res_sum$cv_before, 2) >= 0.01 ~
      "increased from",
    round(d_res_sum$cv_after, 2) - round(d_res_sum$cv_before, 2) <= -0.01 ~
      "decreased from",
    round(d_res_sum$cv_after, 2) - round(d_res_sum$cv_before, 2) == 0 ~
      "remained the same at",
    TRUE ~ "remained similar at"
  )

  cli_alert_info(cli::col_grey(
    "The median per-feature CV change of all features in study samples was {.strong {formatC(d_res_sum$cv_diff_median, format = 'f', digits = 2)}%} (range: {formatC(d_res_sum$cv_diff_min, format = 'f', digits = 2)}% to {formatC(d_res_sum$cv_diff_max, format = 'f', digits = 2)}%; a positive value means the CV increased).  The median CV across all features {.strong {text_change}} {.strong {formatC(d_res_sum$cv_before, format = 'f', digits = 2)}% {ifelse(str_detect(text_change, 'remained'), '',  paste0('to ', formatC(d_res_sum$cv_after, format = 'f', digits = 2),'%'))}}."
  ))

  data@dataset <- data@dataset |>
    left_join(
      d_res |> select(-"y_fit_after"),
      by = c("analysis_id", "feature_id", "qc_type", "batch_id")
    ) |>
    replace_na(list(was_corrected = FALSE)) |>
    mutate(
      !!variable_raw_fit_sym := if (is_first_correction) {
        .data[[variable_fit_after]]
      } else {
        !!variable_raw_fit_sym
      },
      !!variable_before_sym := if_else(
        .data$was_corrected,
        .data$y,
        !!variable_sym
      ),
      !!variable_fit_after_sym := if_else(
        .data$was_corrected,
        .data$y_fit_after_adj,
        .data[[variable_fit_after]]
      ),
      !!variable_sym := if_else(
        .data$was_corrected,
        .data$y_adj,
        !!variable_sym
      ),
      !!variable_fit_sym := .data[[variable_fit]]
    ) |>
    select(-"y_adj", -"y_fit_after_adj", -"y", -"was_corrected")

  if (variable == "feature_intensity") {
    data <- update_after_normalization(data, FALSE)
  } else if (variable == "feature_norm_intensity") {
    data <- update_after_quantitation(data, FALSE)
  }

  data@status_processing <- if (any(data@var_drift_corrected)) {
    glue::glue("Drift-Batch-corrected {var_names}")
  } else {
    glue::glue("Batch-corrected {var_names}")
  }

  data@var_batch_corrected[[variable]] <- TRUE
  data@is_filtered <- FALSE
  data@metrics_qc <- data@metrics_qc[FALSE, ]
  data
}


# ---- ComBat ------------------------------------------------------------------

#' ComBat batch correction
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Adjusts batch effects with the empirical-Bayes ComBat method (Johnson et al.
#' 2007), applied to one of "intensity", "norm_intensity", or "conc". ComBat
#' models a location and scale batch effect per feature and shrinks those
#' estimates across features, which can stabilise many small batches better than
#' simple median centering.
#'
#' Unlike [correct_batch_centering()] and [correct_batch_serrf()], ComBat
#' estimates batch effects from **all** samples (optionally protecting biology
#' via `covariates`), not from the reference QCs. On strongly unbalanced designs
#' this can remove genuine biological signal, so supply `covariates` when the
#' biological grouping is not balanced across batches. `ref_qc_types` is used
#' only for the before/after QC-CV report and the plotting trend curves.
#'
#' Batch correction is performed **after** normalization and drift correction in
#' the recommended pipeline. Features with any missing or non-finite values in
#' the selected variable are left uncorrected (ComBat requires complete data).
#'
#' @param data A [`MRMhubExperiment`][MRMhubExperiment-class] object.
#' @param variable The variable to correct: one of "intensity", "norm_intensity",
#'   or "conc".
#' @param ref_qc_types Character vector of QC types used for the QC-CV report and
#'   trend curves (not for the ComBat fit itself).
#' @param covariates Optional model matrix of biological covariates to preserve
#'   (passed to [sva::ComBat()] as `mod`). Defaults to `NULL` (no covariates).
#' @param ref_batch Optional reference batch to adjust the others towards
#'   (passed to [sva::ComBat()] as `ref.batch`). Defaults to `NULL`.
#' @param parametric Use the parametric empirical-Bayes prior (`TRUE`, default)
#'   or the non-parametric prior (`FALSE`).
#' @param replace_previous Replace a previous batch correction (`TRUE`, default)
#'   or apply on top of it.
#' @param log_transform_internal Fit ComBat in log10 space (`TRUE`, default,
#'   appropriate for multiplicatively-scaling MS data). Returned data are always
#'   back-transformed to the raw scale.
#' @param feature_list Optional feature selection (character vector or a single
#'   regular expression); `NULL` (default) selects all features.
#' @param replace_exisiting_trendcurves Reseed the plotting trend curves. Default
#'   `FALSE`.
#' @return A [`MRMhubExperiment`][MRMhubExperiment-class] with corrected data.
#' @references
#' Johnson WE, Li C, Rabinovic A (2007). Adjusting batch effects in microarray
#' expression data using empirical Bayes methods. *Biostatistics*, 8(1),
#' 118-127. \doi{10.1093/biostatistics/kxj037}
#'
#' Applied through [sva::ComBat()] from the `sva` package. See also
#' Broadhurst D, et al. (2018), *Metabolomics*, 14, 72
#' (\doi{10.1007/s11306-018-1367-3}) on QC-based signal correction.
#' @seealso [correct_batch_centering()], [correct_batch_serrf()],
#'   [correct_drift_loess()] and [plot_runscatter()] for visualisation. The
#'   [drift and batch correction manual](https://slinghub.github.io/MRMhub/quant/articles/manual-07-corrections.html).
#' @examplesIf rlang::is_installed("sva")
#' # mexp <- correct_batch_combat(mexp, variable = "conc", ref_qc_types = "BQC")
#' @export
correct_batch_combat <- function(
  data = NULL,
  variable,
  ref_qc_types,
  covariates = NULL,
  ref_batch = NULL,
  parametric = TRUE,
  replace_previous = TRUE,
  log_transform_internal = TRUE,
  feature_list = NULL,
  replace_exisiting_trendcurves = FALSE
) {
  lifecycle::signal_stage("experimental", "correct_batch_combat()")
  check_pkg_installed("sva", reason = "to apply ComBat batch correction.")
  ctx <- prepare_batch_correction(
    data,
    variable,
    ref_qc_types,
    feature_list = feature_list,
    log_transform_internal = log_transform_internal,
    replace_previous = replace_previous,
    replace_exisiting_trendcurves = replace_exisiting_trendcurves
  )
  d_res <- fun_batch_combat(
    ctx$ds,
    ref_qc_types = ref_qc_types,
    covariates = covariates,
    ref_batch = ref_batch,
    parametric = parametric,
    log_transform_internal = log_transform_internal
  )
  finalize_batch_correction(
    ctx,
    d_res,
    method_phrase = "ComBat batch correction",
    uncorrected_reason = "could not be corrected (missing or non-finite values)"
  )
}

# ComBat engine: pivot `ds` to a feature x analysis matrix, run sva::ComBat on
# the complete features, pivot back to the `d_res` contract.
fun_batch_combat <- function(
  ds,
  ref_qc_types,
  covariates = NULL,
  ref_batch = NULL,
  parametric = TRUE,
  log_transform_internal = TRUE
) {
  meta <- ds |>
    dplyr::distinct(.data$analysis_id, .data$qc_type, .data$batch_id)
  wide <- ds |>
    select("analysis_id", "feature_id", "y") |>
    tidyr::pivot_wider(names_from = "analysis_id", values_from = "y")
  feat <- wide$feature_id
  mat <- as.matrix(wide[, -1])
  rownames(mat) <- feat
  meta <- meta[match(colnames(mat), meta$analysis_id), ]
  batch <- meta$batch_id

  if (any(table(batch) < 2)) {
    cli_abort(
      "ComBat requires at least two analyses per batch. One or more batches are too small."
    )
  }

  if (log_transform_internal) {
    mat <- log10(mat)
  }

  ok <- apply(is.finite(mat), 1, all)
  corrected <- mat
  if (any(ok)) {
    fit <- sva::ComBat(
      dat = mat[ok, , drop = FALSE],
      batch = batch,
      mod = covariates,
      par.prior = parametric,
      ref.batch = ref_batch
    )
    corrected[ok, ] <- fit
  }

  if (log_transform_internal) {
    corrected <- 10^corrected
  }

  # A feature counts as corrected only if every one of its adjusted values is
  # finite (ComBat can return NaN for a zero-variance feature within a batch).
  feat_ok <- feat[ok][apply(is.finite(corrected[ok, , drop = FALSE]), 1, all)]

  corr_long <- tibble::as_tibble(corrected, rownames = "feature_id") |>
    tidyr::pivot_longer(
      -"feature_id",
      names_to = "analysis_id",
      values_to = "y_adj"
    )

  assemble_batch_dres(ds, corr_long, feat_ok, ref_qc_types)
}


# ---- SERRF -------------------------------------------------------------------

#' SERRF batch correction
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' This is an independent re-implementation of SERRF in `mrmhub`, adapted from the
#' reference code in the `malbacR` package (not the original authors' package);
#' see Details. Validate results against the reference SERRF for your data.
#'
#' Normalises systematic error with SERRF (Systematic Error Removal using Random
#' Forest; Fan et al. 2019). For each feature and batch a random forest is
#' trained on the reference QC samples, using the batch's most-correlated
#' features as predictors, and the learned systematic error is removed from all
#' samples. Unlike ComBat, SERRF captures non-linear drift and batch effects
#' jointly and is anchored on the QC samples, matching the QC-based design of the
#' package; it is best suited to larger panels with dense QC coverage.
#'
#' SERRF operates on the raw abundance scale (no log transform). Features with
#' missing or non-positive values, and batches with fewer than two reference
#' QCs, are left uncorrected. Batch correction is performed **after**
#' normalization and drift correction in the recommended pipeline.
#'
#' @details
#' The implementation adapts the reference SERRF code in the `malbacR` package,
#' keeping its normalization arithmetic but selecting each feature's predictors
#' from the per-batch QC-sample Spearman correlation (a simplification of
#' malbacR's QC/sample correlation intersection). Random forests are fit with
#' [ranger::ranger()] and a fixed `seed`, so results are reproducible. Users are
#' encouraged to validate results against the reference SERRF implementation for
#' their data.
#'
#' Batches are corrected independently and in parallel via `mirai` (through
#' [purrr::in_parallel()]); set up workers with [mirai::daemons()] beforehand to
#' use them, otherwise the batches are processed sequentially.
#'
#' @param data A [`MRMhubExperiment`][MRMhubExperiment-class] object.
#' @param variable The variable to correct: one of "intensity", "norm_intensity",
#'   or "conc".
#' @param ref_qc_types Character vector of QC types used as the SERRF training
#'   (reference) samples per batch.
#' @param n_correlated Number of most-correlated features used as random-forest
#'   predictors per feature. Default `10`.
#' @param num_trees Number of trees per random forest. Default `500`.
#' @param seed Random seed for [ranger::ranger()], for reproducibility.
#'   Default `1`.
#' @param num_threads Threads per random forest passed to [ranger::ranger()].
#'   Default `1`; kept low because batches are already corrected in parallel and
#'   each forest trains on a small QC set.
#' @param show_progress Show a progress bar over batches. Default `TRUE`.
#' @param replace_previous Replace a previous batch correction (`TRUE`, default)
#'   or apply on top of it.
#' @param feature_list Optional feature selection (character vector or a single
#'   regular expression); `NULL` (default) selects all features.
#' @param replace_exisiting_trendcurves Reseed the plotting trend curves. Default
#'   `FALSE`.
#' @return A [`MRMhubExperiment`][MRMhubExperiment-class] with corrected data.
#' @references
#' Fan S, Kind T, Cajka T, et al. (2019). Systematic Error Removal Using Random
#' Forest for Normalizing Large-Scale Untargeted Lipidomics Data. *Analytical
#' Chemistry*, 91(5), 3590-3596. \doi{10.1021/acs.analchem.8b05592}
#'
#' Implementation adapted from the `malbacR` package
#' (\url{https://github.com/pmartR/malbacR}); random forests via `ranger`
#' (Wright MN, Ziegler A, 2017, *Journal of Statistical Software*, 77(1),
#' \doi{10.18637/jss.v077.i01}).
#' @seealso [correct_batch_centering()], [correct_batch_combat()],
#'   [correct_drift_loess()] and [plot_runscatter()] for visualisation. The
#'   [drift and batch correction manual](https://slinghub.github.io/MRMhub/quant/articles/manual-07-corrections.html).
#' @examplesIf rlang::is_installed("ranger")
#' # mexp <- correct_batch_serrf(mexp, variable = "conc", ref_qc_types = "BQC")
#' @export
correct_batch_serrf <- function(
  data = NULL,
  variable,
  ref_qc_types,
  n_correlated = 10,
  num_trees = 500,
  seed = 1L,
  num_threads = 1L,
  show_progress = TRUE,
  replace_previous = TRUE,
  feature_list = NULL,
  replace_exisiting_trendcurves = FALSE
) {
  lifecycle::signal_stage("experimental", "correct_batch_serrf()")
  check_pkg_installed("ranger", reason = "to apply SERRF batch correction.")
  ctx <- prepare_batch_correction(
    data,
    variable,
    ref_qc_types,
    feature_list = feature_list,
    log_transform_internal = FALSE,
    replace_previous = replace_previous,
    replace_exisiting_trendcurves = replace_exisiting_trendcurves
  )
  d_res <- fun_batch_serrf(
    ctx$ds,
    ref_qc_types = ref_qc_types,
    n_correlated = n_correlated,
    num_trees = num_trees,
    seed = seed,
    num_threads = num_threads,
    show_progress = show_progress
  )
  finalize_batch_correction(
    ctx,
    d_res,
    method_phrase = "SERRF normalization",
    uncorrected_reason = "could not be corrected (too few reference QCs or non-positive values)"
  )
}

# SERRF engine: correct each batch independently (SERRF's per-batch random
# forests share no state across batches), parallelised over batches with mirai
# via purrr::in_parallel(). Normalization arithmetic follows the malbacR
# reference; predictor selection uses the per-batch QC Spearman correlation.
fun_batch_serrf <- function(
  ds,
  ref_qc_types,
  n_correlated = 10,
  num_trees = 500,
  seed = 1L,
  num_threads = 1L,
  show_progress = TRUE
) {
  meta <- ds |>
    dplyr::distinct(.data$analysis_id, .data$qc_type, .data$batch_id)
  wide <- ds |>
    select("analysis_id", "feature_id", "y") |>
    tidyr::pivot_wider(names_from = "analysis_id", values_from = "y")
  feat <- wide$feature_id
  mat <- as.matrix(wide[, -1])
  rownames(mat) <- feat
  meta <- meta[match(colnames(mat), meta$analysis_id), ]
  is_qc <- meta$qc_type %in% ref_qc_types
  batch <- meta$batch_id
  ubatch <- unique(batch)

  # SERRF needs complete, positive features.
  ok <- apply(is.finite(mat) & mat > 0, 1, all)
  ok_feat <- feat[ok]

  # Pooled (across all batches) per-feature QC / non-QC medians -- the SERRF
  # rescaling anchors, shared by every batch task.
  qc_median <- apply(mat[, is_qc, drop = FALSE], 1, median, na.rm = TRUE)
  nq_median <- apply(mat[, !is_qc, drop = FALSE], 1, median, na.rm = TRUE)

  # One self-contained task per batch, holding only that batch's column slice.
  # Workers are set up by the user with mirai::daemons(); without them
  # purrr::in_parallel() runs the tasks sequentially.
  batch_data <- purrr::map(ubatch, function(b) {
    cols <- which(batch == b)
    list(cols = cols, mat_b = mat[, cols, drop = FALSE], is_qc_b = is_qc[cols])
  })

  results <- batch_data |>
    purrr::map(
      .f = purrr::in_parallel(
        ~ serrf_one_batch(
          .x,
          ok_feat = ok_feat,
          qc_median = qc_median,
          nq_median = nq_median,
          n_correlated = n_correlated,
          num_trees = num_trees,
          seed = seed,
          num_threads = num_threads
        ),
        serrf_one_batch = serrf_one_batch,
        ok_feat = ok_feat,
        qc_median = qc_median,
        nq_median = nq_median,
        n_correlated = n_correlated,
        num_trees = num_trees,
        seed = seed,
        num_threads = num_threads
      ),
      .progress = show_progress
    )

  corrected <- mat
  was_ok <- matrix(FALSE, nrow(mat), ncol(mat), dimnames = dimnames(mat))
  for (res in results) {
    corrected[, res$cols] <- res$corrected
    was_ok[, res$cols] <- res$was_ok
  }

  # Any non-finite result reverts to the original value, flagged uncorrected.
  bad <- !is.finite(corrected)
  corrected[bad] <- mat[bad]
  was_ok[bad] <- FALSE

  corr_long <- tibble::as_tibble(corrected, rownames = "feature_id") |>
    tidyr::pivot_longer(
      -"feature_id",
      names_to = "analysis_id",
      values_to = "y_adj"
    )
  wc_long <- tibble::as_tibble(was_ok, rownames = "feature_id") |>
    tidyr::pivot_longer(
      -"feature_id",
      names_to = "analysis_id",
      values_to = "was_corrected"
    )

  ds |>
    left_join(corr_long, by = c("feature_id", "analysis_id")) |>
    left_join(wc_long, by = c("feature_id", "analysis_id")) |>
    mutate(
      was_corrected = tidyr::replace_na(.data$was_corrected, FALSE),
      y_adj = if_else(.data$was_corrected, .data$y_adj, .data$y)
    ) |>
    group_by(.data$feature_id, .data$batch_id) |>
    mutate(
      y_fit_after_adj = median(
        .data$y_adj[.data$qc_type %in% ref_qc_types],
        na.rm = TRUE
      )
    ) |>
    ungroup() |>
    select(
      "analysis_id",
      "feature_id",
      "qc_type",
      "batch_id",
      "y",
      "y_adj",
      "y_fit_after",
      "y_fit_after_adj",
      "was_corrected"
    )
}


# SERRF worker for a single batch: for each ok feature, pick the top-N
# QC-correlated features as predictors, train a random forest on the batch's
# reference QCs, and remove the predicted systematic error from all of the
# batch's samples. Self-contained (only base + ranger) so it ships to mirai
# workers; operates on the batch column slice `dat$mat_b` with local indices.
serrf_one_batch <- function(
  dat,
  ok_feat,
  qc_median,
  nq_median,
  n_correlated,
  num_trees,
  seed,
  num_threads
) {
  mat_b <- dat$mat_b
  is_qc_b <- dat$is_qc_b
  out <- mat_b
  was <- matrix(FALSE, nrow(mat_b), ncol(mat_b), dimnames = dimnames(mat_b))
  qc_l <- which(is_qc_b)
  nq_l <- which(!is_qc_b)
  if (length(qc_l) < 2 || length(ok_feat) < 2) {
    return(list(cols = dat$cols, corrected = out, was_ok = was))
  }

  # Per-batch feature-feature Spearman correlation on the reference QCs.
  # (Scaling is a no-op for Spearman, so it is omitted.)
  cormat <- suppressWarnings(stats::cor(
    t(mat_b[ok_feat, qc_l, drop = FALSE]),
    method = "spearman"
  ))
  rownames(cormat) <- colnames(cormat) <- ok_feat

  for (f in ok_feat) {
    ord <- order(abs(cormat[, f]), decreasing = TRUE)
    sel <- setdiff(ok_feat[ord], f)
    sel <- sel[seq_len(min(n_correlated, length(sel)))]
    if (length(sel) < 1) {
      next
    }

    x_qc <- scale(t(mat_b[sel, qc_l, drop = FALSE]))
    x_nq <- scale(t(mat_b[sel, nq_l, drop = FALSE]))
    x_qc[!is.finite(x_qc)] <- 0
    x_nq[!is.finite(x_nq)] <- 0
    colnames(x_qc) <- colnames(x_nq) <- paste0("var", seq_len(ncol(x_qc)))

    y_qc <- mat_b[f, qc_l] - mean(mat_b[f, qc_l])
    model <- ranger::ranger(
      y ~ .,
      data = data.frame(y = y_qc, x_qc),
      num.trees = num_trees,
      seed = seed,
      num.threads = num_threads
    )

    pred_qc <- stats::predict(model, data = data.frame(x_qc))$predictions
    norm_qc <- mat_b[f, qc_l] /
      ((pred_qc + mean(mat_b[f, qc_l])) / qc_median[[f]])
    serrf_qc <- norm_qc / (median(norm_qc, na.rm = TRUE) / qc_median[[f]])
    out[f, qc_l] <- serrf_qc
    was[f, qc_l] <- is.finite(serrf_qc)

    if (length(nq_l) > 0) {
      pred_nq <- stats::predict(model, data = data.frame(x_nq))$predictions
      norm_nq <- mat_b[f, nq_l] /
        ((pred_nq + mean(mat_b[f, nq_l])) / nq_median[[f]])
      serrf_nq <- norm_nq / (median(norm_nq, na.rm = TRUE) / nq_median[[f]])
      out[f, nq_l] <- serrf_nq
      was[f, nq_l] <- is.finite(serrf_nq)
    }
  }

  list(cols = dat$cols, corrected = out, was_ok = was)
}


# Shared assembly of the `d_res` contract for matrix engines that produce a long
# `corr_long` (analysis_id, feature_id, y_adj) plus the set of fully-corrected
# features. Recomputes the after-correction reference-QC trend line per batch.
assemble_batch_dres <- function(ds, corr_long, feat_ok, ref_qc_types) {
  ds |>
    left_join(corr_long, by = c("feature_id", "analysis_id")) |>
    mutate(
      was_corrected = .data$feature_id %in% feat_ok & is.finite(.data$y_adj),
      y_adj = if_else(.data$was_corrected, .data$y_adj, .data$y)
    ) |>
    group_by(.data$feature_id, .data$batch_id) |>
    mutate(
      y_fit_after_adj = median(
        .data$y_adj[.data$qc_type %in% ref_qc_types],
        na.rm = TRUE
      )
    ) |>
    ungroup() |>
    select(
      "analysis_id",
      "feature_id",
      "qc_type",
      "batch_id",
      "y",
      "y_adj",
      "y_fit_after",
      "y_fit_after_adj",
      "was_corrected"
    )
}
