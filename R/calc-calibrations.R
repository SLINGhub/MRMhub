#' Calculate concentrations based on external calibration
#'
#' Concentrations of all features in all analyses are determined using ISTD-normalized intensities and corresponding external calibration curves.
#' Calibration curves are calculated for each feature based on calibration sample concentrations defined in the `qc_concentrations` metadata.
#' The regression fit model (linear or quadratic) and the weighting method (either "none", "1/x", or "1/x^2") can be defined globally via
#' the arguments `fit_model` and `fit_weighting` for all features, if `fit_overwrite` is `TRUE`.
#' Alternatively, the model and weighting can be defined individually for each feature in the `feature` metadata (columns `curve_fit_model` and `curve_fit_weighting`).
#' If these details are missing in the metadata, the default values provided via `fit_model` and `fit_weighting` will be used.
#'
#' The concentrations are added to the `dataset` table as `feature_conc` column. The results of the regression and the calculated LoD and LoQ values are stored in the `metrics_calibration` table of the returned `MRMhubExperiment` object.

#' @param data A [`MRMhubExperiment`][MRMhubExperiment-class] object
#' @param include_qualifier A logical value. If `TRUE`, the function will include qualifier features in the calibration curve calculations.
#' @param fit_overwrite If `TRUE`,
#'   the function will use the provided `fit_model` and `fit_weighting` values
#'   for all analytes and ignore any fit method and weighting settings defined in
#'   the metadata.
#' @param fit_model A character string specifying the default regression fit
#'   method to use for the calibration curve. Must be one of `"linear"` or
#'   `"quadratic"`. This method will be applied if no specific fit method is
#'   defined for a feature in the metadata, or
#'   when `fit_overwrite = TRUE`.
#' @param fit_weighting A character string specifying the default weighting
#'   method for the regression points in the calibration curve. Must be one of
#'   `"none"`, `"1/x"`, or `"1/x^2"`. This method will be applied if no
#'   specific weighting method is defined for a feature in the metadata, or
#'   when `fit_overwrite = TRUE`.
#'@param ignore_failed_calibration If `FALSE`, raises error if calibration curve fit fails for any feature. If `TRUE`, failed fits will be ignored, and resulting feature concentration will be `NA`.
#'@param ignore_missing_annotation If `FALSE`, raises error if any of the following information is missing: calibration curve data, ISTD mix volume and sample amounts for any feature.
#'   If `TRUE`, missing annotations will be ignored, and resulting feature concentration will be `NA`
#' @param lod_sigma A character string selecting the standard deviation of the
#'   response (sigma) used in the ICH Q2 LoD/LoQ formulas. Must be one of
#'   `"residual"` (the residual standard error of the regression, Sy/x; the
#'   default) or `"intercept"` (the standard error of the intercept). See
#'   [calc_calibration_results()] for details.
#' @return A modified [`MRMhubExperiment`][MRMhubExperiment-class] object with updated concentration values.
#'
#' @seealso [calc_calibration_results()] for calculating the calibration curve results including LoD and LoQ.
#' @seealso [quantify_by_istd()] for calculation of concentrations based on spiked-in internal standard concentration.
#' @export
quantify_by_calibration <- function(
  data = NULL,
  include_qualifier = TRUE,
  fit_overwrite,
  fit_model = c("linear", "quadratic"),
  fit_weighting = c("none", "1/x", "1/x^2"),
  ignore_failed_calibration = FALSE,
  ignore_missing_annotation = FALSE,
  lod_sigma = c("residual", "intercept")
) {
  check_data(data)

  fit_model <- rlang::arg_match(fit_model)
  fit_weighting <- rlang::arg_match(fit_weighting)
  lod_sigma <- rlang::arg_match(lod_sigma)

  data <- calc_calibration_results(
    data = data,
    variable = "feature_norm_intensity",
    include_qualifier = include_qualifier,
    fit_overwrite = fit_overwrite,
    fit_model = fit_model,
    fit_weighting = fit_weighting,
    ignore_missing_annotation = ignore_missing_annotation,
    lod_sigma = lod_sigma
  )
  d_calib <- data@metrics_calibration

  features_no_calib <- setdiff(
    get_featurelist(
      data,
      is_istd = FALSE,
      is_quantifier = ifelse(include_qualifier, NA, TRUE)
    ),
    d_calib$feature_id
  )
  # Check if calibration curve data is missing for any feature
  if (length(features_no_calib) > 0) {
    if (ignore_missing_annotation) {
      mh_warn(
        "Calibration curve annotations for {length(features_no_calib)} features are missing. Calculated concentrations for these features will be `NA`."
      )
    } else {
      cli::cli_abort(
        "Calibration curve annotations for {length(features_no_calib)} features are missing. Please verify data and QC-concentration metadata, or ignore by setting `ignore_missing_annotation = TRUE`."
      )
    }
  }

  features_failed_calib <- sum(d_calib$reg_failed_cal_1)
  # Check if calibration curve data is missing for any feature
  if (features_failed_calib > 0) {
    if (ignore_failed_calibration) {
      mh_warn(
        "Calibration curve fit failed for {features_failed_calib} features. Calculated concentrations for these features will be `NA`."
      )
    } else {
      cli::cli_abort(
        "Calibration curve fit failed for {features_failed_calib} features. Please verify data and QC-concentration metadata, or ignore by setting `ignore_failed_calibration = TRUE`."
      )
    }
  }

  d_stats_calc <- d_calib |>
    dplyr::select(
      "feature_id",
      "fit_model",
      "coef_a_cal_1",
      "coef_b_cal_1",
      "coef_c_cal_1",
      "lowest_cal_cal_1",
      "highest_cal_cal_1"
    )

  d_conc <- data@dataset |>
    left_join(
      d_stats_calc,
      by = c("feature_id" = "feature_id")
    ) |>
    mutate(
      # Linear back-calculation: conc = (response - intercept) / slope.
      # Guard a zero or missing slope, which would otherwise yield `Inf`.
      # Quadratic-fit rows are overwritten below; solving each quadratic with
      # `polyroot` is costly, so it is applied only to those rows instead of to
      # every row (the previous `case_when` evaluated it eagerly for all rows).
      feature_conc = if_else(
        !is.na(.data$coef_b_cal_1) & .data$coef_b_cal_1 != 0,
        (.data$feature_norm_intensity - .data$coef_a_cal_1) /
          .data$coef_b_cal_1,
        NA_real_
      )
    )

  # Quadratic back-calculation: solve a + b*conc + c*conc^2 = response, for the
  # quadratic-fit rows only. A quadratic has two roots; the calibrated range is
  # used only to *select* the physical root (the one on the monotonic branch),
  # which is then returned even if the sample lies outside the range (matching
  # the prior behaviour). Only a genuinely complex root (no real solution) or
  # the degenerate `c == 0` / `b == 0` case yields NA. (Rows without a
  # calibration have NA coefficients, so the linear branch already yields NA and
  # they need not be revisited here.)
  quad_rows <- which(d_conc$fit_model == "quadratic")
  if (length(quad_rows) > 0) {
    d_conc$feature_conc[quad_rows] <- purrr::pmap_dbl(
      list(
        d_conc$coef_a_cal_1[quad_rows],
        d_conc$coef_b_cal_1[quad_rows],
        d_conc$coef_c_cal_1[quad_rows],
        d_conc$feature_norm_intensity[quad_rows],
        d_conc$lowest_cal_cal_1[quad_rows],
        d_conc$highest_cal_cal_1[quad_rows]
      ),
      function(coef_a, coef_b, coef_c, x, lo, hi) {
        if (is.na(coef_a) || is.na(coef_b) || is.na(coef_c) || is.na(x)) {
          return(NA_real_)
        }
        # Degenerate quadratic term: the curve is effectively linear.
        if (coef_c == 0) {
          if (coef_b == 0) {
            return(NA_real_)
          }
          return((x - coef_a) / coef_b)
        }
        roots <- tryCatch(
          polyroot(c(coef_a - x, coef_b, coef_c)),
          error = function(e) complex(0)
        )
        # Keep only (near-)real roots.
        real_roots <- Re(roots)[abs(Im(roots)) < 1e-6]
        if (length(real_roots) == 0) {
          return(NA_real_) # no real solution (response beyond the curve)
        }
        if (length(real_roots) == 1) {
          return(real_roots)
        }
        # Two real roots: pick the one nearest the calibrated range (0 when
        # inside it) so out-of-range samples still get the physical root.
        if (!is.na(lo) && !is.na(hi)) {
          dist_to_range <- pmax(lo - real_roots, real_roots - hi, 0)
          return(real_roots[which.min(dist_to_range)])
        }
        # No range available: prefer the non-negative root.
        nonneg <- real_roots[real_roots >= 0]
        if (length(nonneg) >= 1) {
          return(nonneg[1])
        }
        real_roots[1]
      }
    )
  }
  data@dataset <- d_conc

  # Flag concentrations that fall outside the calibrated range (below the lowest
  # or above the highest calibrator). The value is retained as an extrapolation;
  # this column records the fact so it travels with the data. Applies uniformly
  # to linear and quadratic fits.
  data@dataset <- data@dataset |>
    mutate(
      feature_conc_out_of_range = !is.na(.data$feature_conc) &
        (.data$feature_conc < .data$lowest_cal_cal_1 |
          .data$feature_conc > .data$highest_cal_cal_1)
    )

  n_out_of_range <- sum(
    data@dataset$feature_conc_out_of_range & !data@dataset$is_istd,
    na.rm = TRUE
  )
  if (n_out_of_range > 0) {
    cli::cli_alert_info(cli::col_grey(
      "{n_out_of_range} concentration value{?s} {?falls/fall} outside the calibrated range (retained, flagged in {.field feature_conc_out_of_range})."
    ))
  }

  # Warn when a value with a valid calibration could not be back-calculated at
  # all (no real solution on the curve, or a zero/degenerate slope) and was
  # therefore set to `NA`.
  d_backcalc_na <- data@dataset |>
    filter(
      !.data$is_istd,
      !is.na(.data$feature_norm_intensity),
      !is.na(.data$coef_b_cal_1),
      is.na(.data$feature_conc)
    )
  if (nrow(d_backcalc_na) > 0) {
    affected_features <- unique(d_backcalc_na$feature_id)
    cli::cli_warn(c(
      "!" = "{nrow(d_backcalc_na)} concentration value{?s} could not be back-calculated from the calibration curve and {?was/were} set to {.val {NA_real_}}.",
      "i" = "This occurs when the response has no real solution on the curve or the slope is zero.",
      "i" = "Affected feature{?s}: {.val {mh_vec(affected_features)}}"
    ))
  }

  data@dataset <- data@dataset |>
    select(
      -c(
        "coef_a_cal_1",
        "coef_b_cal_1",
        "coef_c_cal_1",
        "lowest_cal_cal_1",
        "highest_cal_cal_1"
      )
    )

  n_features_with_conc <- data@dataset |>
    filter(!.data$is_istd, !is.na(.data$feature_conc)) |>
    select("feature_id") |>
    distinct() |>
    nrow()

  conc_unit <- unique(data@annot_qcconcentrations$concentration_unit)
  if (length(conc_unit) > 1) {
    cli::cli_abort(
      "Multiple concentration units found in `qc_concentrations` metadata. Please verify and correct QC-concentration metadata."
    )
  }

  # Calibrants already carry a concentration, so this is what `feature_conc` is
  # in; `get_conc_unit()` passes such a unit through unchanged.
  data@conc_analyte_unit <- conc_unit
  conc_unit <- get_conc_unit(data@annot_analyses$sample_amount_unit, conc_unit)

  n_analyses_with_conc <- data@dataset |>
    filter(!.data$is_istd, !is.na(.data$feature_conc)) |>
    dplyr::distinct(.data$analysis_id) |>
    nrow()

  mh_success(
    "Concentrations calculated for {n_features_with_conc} feature{?s} in {n_analyses_with_conc} analys{?is/es}."
  )

  mh_success("Concentrations are given in {conc_unit}.")

  data@status_processing <- "Calibration-quantitated data"

  data <- update_after_normalization(data, TRUE)
  data <- update_after_quantitation(data, TRUE)
  data@is_filtered <- FALSE

  data@metrics_qc <- data@metrics_qc[FALSE, ]

  data
}


#' Calculate external calibration curve results
#'
#' Calibration curves are calculated for each feature using ISTD-normalized
#' intensities and the corresponding concentrations of calibration samples, as
#' defined in the `qc_concentrations` metadata. The regression fit model (linear
#' or quadratic) and the weighting method (either "none", "1/x", or "1/x^2")
#' can be defined globally via the arguments `fit_model` and `fit_weighting`
#' for all features, if `fit_overwrite` is `TRUE`. Alternatively, the
#' model and weighting can be defined individually for each feature in the
#' `feature` metadata (columns `curve_fit_model` and `curve_fit_weighting`). If
#' these details are missing in the metadata, the default values provided via
#' `fit_model` and `fit_weighting` will be used.
#'
#' Additionally, the limit of detection (LoD) and limit of quantification (LoQ)
#' are calculated for each feature based on the calibration curve, following the
#' ICH Q2(R1/R2) approach (LoD = 3.3 sigma / S, LoQ = 10 sigma / S). Here S is
#' the slope of the calibration curve, taken at zero concentration (the linear
#' coefficient `coef_b`). For a quadratic fit the true slope is `b + 2 c x`,
#' which reduces to `coef_b` at zero concentration, so the quadratic term does
#' not contribute to the slope used here. ICH Q2 specifies the slope formula for
#' linear responses only; using the low-concentration tangent slope for a
#' quadratic fit is an approximation beyond the guideline (adequate when the
#' curvature near zero is small).
#'
#' The response standard deviation `sigma` is selected via `lod_sigma`, following
#' the ICH-acceptable choices: `"residual"` uses the residual standard error of
#' the regression (Sy/x; the default and prior behaviour), while `"intercept"`
#' uses the standard error of the intercept. The `sigma` column reported in
#' `metrics_calibration` is always the residual standard error, independent of
#' this choice.
#'
#' The results of the regression and the calculated LoD and LoQ values are
#' stored in the `metrics_calibration` table of the returned `MRMhubExperiment`
#' object.
#'
#' @param data A [`MRMhubExperiment`][MRMhubExperiment-class] object containing the data to be used for
#'   calibration.
#' @param variable A character string specifying the variable for calibration.
#'   Use `"feature_norm_intensity"` for typical scenarios involving internal
#'   standardization. When performing only external standardization, without
#'   internal standardization, use `"feature_intensity"`.
#' @param include_qualifier A logical value. If `TRUE`, the function will
#'   include qualifier features in the calibration curve calculations.
#' @param fit_overwrite If `TRUE`,
#'   the function will use the provided `fit_model` and `fit_weighting` values
#'   for all analytes and ignore any fit method and weighting settings defined in
#'   the metadata.
#' @param fit_model A character string specifying the default regression fit
#'   method to use for the calibration curve. Must be one of `"linear"` or
#'   `"quadratic"`. This method will be applied if no specific fit method is
#'   defined for a feature in the metadata, or
#'   when `fit_overwrite = TRUE`.
#' @param fit_weighting A character string specifying the default weighting
#'   method for the regression points in the calibration curve. Must be one of
#'   `"none"`, `"1/x"`, or `"1/x^2"`. This method will be applied if no
#'   specific weighting method is defined for a feature in the metadata, or
#'   when `fit_overwrite = TRUE`.
#' @param ignore_missing_annotation If `FALSE`, an error will be raised if
#'   calibration curve data is missing for any feature.
#' @param include_fit_object If `TRUE`, the function will return the full
#'   regression fit objects for each feature in the `metrics_calibration` table.
#' @param lod_sigma A character string selecting the response standard deviation
#'   (sigma) used in the ICH Q2 LoD/LoQ formulas. Must be one of `"residual"`
#'   (the residual standard error of the regression, Sy/x; the default) or
#'   `"intercept"` (the standard error of the intercept). No averaging of the two
#'   is performed.
#'
#' @return A modified [`MRMhubExperiment`][MRMhubExperiment-class] object with an updated
#'   `metrics_calibration` table containing the calibration curve results,
#'   including concentrations, LoD, and LoQ values for each feature.
#'
#' @seealso [quantify_by_calibration()] for calculating concentrations based on
#'   external calibration curves.
#'
#' @references
#' ICH Harmonised Tripartite Guideline. Validation of Analytical Procedures:
#' Text and Methodology Q2(R1) (2005); Q2(R2) (2023). International Council for
#' Harmonisation of Technical Requirements for Pharmaceuticals for Human Use.
#'
#' @export

calc_calibration_results <- function(
  data = NULL,
  variable = "feature_norm_intensity",
  include_qualifier = TRUE,
  fit_overwrite,
  fit_model,
  fit_weighting,
  ignore_missing_annotation = FALSE,
  include_fit_object = FALSE,
  lod_sigma = c("residual", "intercept")
) {
  check_data(data)

  if (nrow(data@dataset) == 0) {
    cli::cli_abort(
      "No data to quantify: the dataset is empty. Please import and process data first."
    )
  }

  rlang::arg_match(fit_model, c("linear", "quadratic"))
  rlang::arg_match(fit_weighting, c("none", "1/x", "1/x^2"))
  rlang::arg_match(variable, c("feature_intensity", "feature_norm_intensity"))
  lod_sigma <- rlang::arg_match(lod_sigma)

  if (
    variable == "feature_norm_intensity" &&
      !any("feature_norm_intensity" %in% names(data@dataset))
  ) {
    cli::cli_abort(
      "Data needs to be ISTD-normalized, please run 'normalize_by_istd' before."
    )
  }

  if (
    !any("CAL" %in% data@dataset$qc_type) &
      nrow(data@annot_qcconcentrations) == 0
  ) {
    cli::cli_abort(
      "Calibration curve data missing...Please verify data and correct annotation om `analyis` and `qc_concentration` metadata. See this function's documentation."
    )
  }

  # Pre-flight validation of the QC-concentration table before the calibration
  # join below, so a hand-built or malformed table produces a clear message
  # instead of a cryptic dplyr `many-to-one` or numeric-coercion error deep in
  # the fit. (Import-time validation asserts the same key; this covers objects
  # whose slots were set directly.)
  if (nrow(data@annot_qcconcentrations) > 0) {
    required_cols <- c(
      "sample_id",
      "analyte_id",
      "concentration",
      "include_in_analysis"
    )
    missing_cols <- setdiff(required_cols, names(data@annot_qcconcentrations))
    if (length(missing_cols) > 0) {
      cli::cli_abort(c(
        "QC-concentration metadata is missing required column{?s} {.field {missing_cols}}.",
        "i" = "Provide {?it/them} in the {.code qc_concentration} metadata before quantifying by calibration."
      ))
    }
    assert_unique_ids(
      paste(
        data@annot_qcconcentrations$sample_id,
        data@annot_qcconcentrations$analyte_id,
        sep = " / "
      ),
      "(sample_id, analyte_id)",
      "the QC-concentration metadata"
    )
    if (!is.numeric(data@annot_qcconcentrations$concentration)) {
      cli::cli_abort(c(
        "QC-concentration {.field concentration} must be numeric, but it is {.cls {class(data@annot_qcconcentrations$concentration)}}.",
        "i" = "Check the {.code qc_concentration} metadata for non-numeric concentration values."
      ))
    }
  }

  calc_lm <- function(dt) {
    # Descriptor fields are identical across all four result shapes below
    # (linear/quadratic x success/error), so build them once here.
    base_info <- list(
      feature_id = dt$feature_id[1],
      is_quantifier = dt$is_quantifier[1],
      curve_id = dt$curve_id[1],
      fit_model = dt$fit_model[1],
      fit_weighting = dt$fit_weighting[1],
      lowest_cal = sort(dt$concentration[dt$concentration != 0])[1],
      highest_cal = sort(
        dt$concentration[dt$concentration != 0],
        decreasing = TRUE
      )[1]
    )
    tryCatch(
      {
        dt <- dt |>
          mutate(
            weight = switch(
              fit_weighting[1],
              "none" = 1,
              "1/x" = 1 / .data$concentration,
              "1/x^2" = 1 / .data$concentration^2,
              "1/sqrt(x)" = 1 / sqrt(.data$concentration),
              NA_real_
            )
          ) |>
          # A zero-concentration (blank) calibrator cannot be inverse-weighted
          # (weight = 1/0 = Inf), which makes lm() fail. Drop non-finite-weight
          # rows so the weighted fit succeeds over the real standards. Unweighted
          # fits keep the blank (weight = 1). The exclusion is reported once,
          # aggregated per feature, by the caller before the split.
          filter(is.finite(.data$weight))

        formula <- ifelse(
          dt$fit_model[1] == "linear",
          paste0(variable, " ~ concentration"),
          paste0(variable, " ~ poly(concentration, 2, raw = TRUE)")
        )

        # Warnings (e.g. rank-deficient fit) are intentionally suppressed: a
        # failed fit yields NA coefficients, which `reg_failed` below detects
        # and propagates to the calibration metrics, so the outcome is surfaced
        # structurally rather than as per-curve warning noise.
        res <- suppressWarnings(lm(
          formula = formula,
          weights = weight,
          data = dt,
          na.action = na.exclude
        ))

        summ <- summary(res)
        r.squared <- summ$r.squared
        sigma <- summ$sigma
        # Standard error of the intercept (SDa), the alternative ICH Q2 sigma
        # source. A rank-deficient fit may drop the intercept row, so guard it.
        coef_mat <- summ$coefficients
        sigma_intercept <- if ("(Intercept)" %in% rownames(coef_mat)) {
          coef_mat["(Intercept)", "Std. Error"]
        } else {
          NA_real_
        }

        if (dt$fit_model[1] == "quadratic") {
          reg_failed <- is.na(res$coefficients[[3]]) |
            is.na(res$coefficients[[2]]) |
            is.na(res$coefficients[[1]])
          coef_c <- res$coefficients[[3]]
        } else {
          reg_failed <- is.na(res$coefficients[[2]]) |
            is.na(res$coefficients[[1]])
          coef_c <- NA_real_
        }
        return(c(
          base_info,
          list(
            r.squared = r.squared,
            coef_a = res$coefficients[[1]],
            coef_b = res$coefficients[[2]],
            coef_c = coef_c,
            sigma = sigma,
            sigma_intercept = sigma_intercept,
            reg_failed = reg_failed,
            fit = if (include_fit_object) list(res) else list(NULL)
          )
        ))
      },
      error = function(e) {
        # Linear and quadratic failures produce the same all-NA result.
        c(
          base_info,
          list(
            r.squared = NA_real_,
            coef_a = NA_real_,
            coef_b = NA_real_,
            coef_c = NA_real_,
            sigma = NA_real_,
            sigma_intercept = NA_real_,
            reg_failed = TRUE,
            fit = list(NULL)
          )
        )
      }
    )
  }

  # LoD/LoQ use the slope of the calibration curve at zero concentration, i.e.
  # the linear coefficient `coef_b` (ICH Q2). For a quadratic fit the slope is
  # b + 2*c*conc, which reduces to `coef_b` at conc = 0, so the quadratic term
  # does not contribute to the slope used here. The response sigma is selected by
  # `lod_sigma`: the residual standard error (Sy/x) or the intercept standard
  # error (SDa). The transient `sigma_lod` / `slope_at_conc` helper columns are
  # dropped by the downstream `select()`, so the stored `sigma` column always
  # remains the residual standard error.
  add_quantlimits <- function(data, lod_sigma) {
    data |>
      mutate(
        slope_at_conc = .data$coef_b,
        sigma_lod = if (lod_sigma == "intercept") {
          .data$sigma_intercept
        } else {
          .data$sigma
        },
        lod = 3.3 * .data$sigma_lod / .data$slope_at_conc,
        loq = 10 * .data$sigma_lod / .data$slope_at_conc
      )
  }

  d_calib <- data@dataset |>
    dplyr::ungroup() |>
    dplyr::select(any_of(
      c(
        "analysis_id",
        "sample_id",
        "qc_type",
        "feature_id",
        "analyte_id",
        "is_istd",
        "is_quantifier",
        variable
      )
    )) |>
    filter(.data$qc_type == "CAL", !.data$is_istd)

  if (!include_qualifier) {
    d_calib <- d_calib |> dplyr::filter(.data$is_quantifier)
  }

  d_calib <- d_calib |>
    dplyr::inner_join(
      data@annot_qcconcentrations,
      by = c("sample_id" = "sample_id", "analyte_id" = "analyte_id"),
      relationship = "many-to-one"
    ) |>
    filter(.data$include_in_analysis) |>
    mutate(curve_id = "1")

  if (!fit_overwrite) {
    d_calib <- d_calib |>
      dplyr::left_join(
        data@annot_features |>
          select("feature_id", "curve_fit_model", "curve_fit_weighting"),
        by = c("feature_id" = "feature_id")
      ) |>
      mutate(
        fit_model = if_else(
          is.na(.data$curve_fit_model),
          fit_model,
          .data$curve_fit_model
        ),
        fit_weighting = if_else(
          is.na(.data$curve_fit_weighting),
          fit_weighting,
          .data$curve_fit_weighting
        )
      ) |>
      select(-"curve_fit_model", -"curve_fit_weighting")
  } else {
    d_calib <- d_calib |>
      mutate(fit_model = fit_model, fit_weighting = fit_weighting)
  }

  # A zero-concentration (blank) calibrator cannot be inverse-weighted
  # (weight = 1/0 = Inf) and is dropped from the weighted fit in `calc_lm`.
  # Surface which features are affected so the exclusion is attributable rather
  # than surfacing later as a generic "fit failed".
  zero_cal_weighted <- d_calib |>
    filter(.data$fit_weighting != "none", .data$concentration == 0) |>
    dplyr::distinct(.data$feature_id)
  if (nrow(zero_cal_weighted) > 0) {
    mh_warn(
      "Zero-concentration calibrator excluded from the weighted fit for {nrow(zero_cal_weighted)} feature{?s} ({paste(zero_cal_weighted$feature_id, collapse = ', ')}); a blank cannot be inverse-weighted."
    )
  }

  d_calib <- d_calib |>
    dplyr::group_split(.data$feature_id, .data$curve_id)

  d_stats <- map(d_calib, function(x) calc_lm(x)) |> bind_rows()
  d_stats <- add_quantlimits(d_stats, lod_sigma)

  d_stats <- d_stats |>
    dplyr::select(
      "feature_id",
      "is_quantifier",
      "fit_model",
      "fit_weighting",
      "lowest_cal",
      "curve_id",
      "reg_failed",
      r2 = "r.squared",
      "coef_a",
      "coef_b",
      "coef_c",
      "sigma",
      "lowest_cal",
      "highest_cal",
      "lod",
      "loq",
      "fit"
    ) |>
    tidyr::pivot_wider(
      names_from = "curve_id",
      values_from = c(
        "reg_failed",
        "r2",
        "coef_a",
        "coef_b",
        "coef_c",
        "sigma",
        "lowest_cal",
        "highest_cal",
        "lod",
        "loq",
        "fit"
      ),
      names_prefix = "cal_"
    )
  data@metrics_calibration <- d_stats

  features_no_calib <- setdiff(
    get_featurelist(
      data,
      is_istd = FALSE,
      is_quantifier = ifelse(include_qualifier, NA, TRUE)
    ),
    d_stats$feature_id
  )
  # Check if calibration curve data is missing for any feature
  if (length(features_no_calib) > 0) {
    mh_warn(
      "Calibration curve annotations for {length(features_no_calib)} features are missing."
    )
  }

  text_missing <- ifelse(
    length(features_no_calib) > 0,
    "all annotated ",
    "all "
  )

  count_quant_pass <- sum(!d_stats$reg_failed_cal_1[d_stats$is_quantifier])
  count_qual_pass <- sum(!d_stats$reg_failed_cal_1[!d_stats$is_quantifier])
  count_quant_all <- sum(d_stats$is_quantifier)
  count_qual_all <- sum(!d_stats$is_quantifier)

  text_total_quant <- ifelse(
    count_quant_pass == count_quant_all,
    paste0(text_missing, count_quant_pass),
    paste0(count_quant_pass, " (of ", count_quant_all, ")")
  )
  text_total_qual <- ifelse(
    count_qual_pass == count_qual_all,
    paste0("", count_qual_pass),
    paste0(count_qual_pass, " (of ", count_qual_all, ")")
  )

  if (include_qualifier && any(!d_stats$is_quantifier)) {
    if (count_quant_pass == 0) {
      cli::cli_abort(
        "All calibration curve fits for quantifier features failed. Please check data, and feature/qc-concentration metadata."
      )
    }
    mh_success(
      "Calibration curve fits calculated for {text_total_quant} quantifier and {text_total_qual} qualifier features. Average r-squared: {sprintf('%.4f', mean(d_stats$r2_cal_1[d_stats$is_quantifier], na.rm = TRUE))} and {sprintf('%.4f', mean(d_stats$r2_cal_1[!d_stats$is_quantifier], na.rm = TRUE))}."
    )
  } else {
    if (count_quant_pass == 0) {
      cli::cli_abort(
        "All calibration curve fits failed. Please check data, and feature/qc-concentration metadata."
      )
    }
    mh_success(
      "Calibration curve fits calculated for {text_total_quant} quantifier features. Average r-squared: {sprintf('%.4f', mean(d_stats$r2_cal_1[d_stats$is_quantifier], na.rm = TRUE))}."
    )
  }
  data
}


#' Retrieve QC bias and variability metrics
#'
#' This function retrieves quality control (QC) bias and variability metrics from a `MRMhubExperiment` object.
#' It returns a summary of QC metrics for specified QC samples,
#' including bias, absolute bias, and intra-assay coefficient of variation (CV).
#' The standard deviation of the concentration ratio is also included unless
#' it is `NA` for all analytes, i.e. when no replicates were measured.
#'
#' The standard deviation of concentration is also included unless the number of replicates was 1.
#'
#' @param data A [`MRMhubExperiment`][MRMhubExperiment-class] object containing the dataset and necessary annotations for calibration analysis.
#' @param qc_types A character vector specifying the QC types to include in the results, in addition to `CAL`. If not specified, all applicable QC types are included by default.
#' @param sample_ids A character vector specifying the sample IDs to include in the results. If not specified, all analyses regardless of their sample IDs are included by default.
#' @param wide_format Format of the output table. Must be one of `"none"`, `"features"`, or `"samples"`.
#' If `"none"`, the output is in long format. If `"features"`, the output is in wide format with features as columns.
#' If `"samples"`, the output is in wide format with samples as columns.
#' @param include_qualifier Logical. If `TRUE`, includes qualifier features in the results. Defaults to `FALSE`.
#' @param with_conc Logical. If `TRUE`, includes target and measured mean concentrations in the results. Defaults to `TRUE`.
#' @param with_conc_target Logical. If `TRUE`, includes target (known) concentration of the QC sample in the results. Defaults to `TRUE`.
#' @param with_bias Logical. If `TRUE`, includes percentage bias in the results. Defaults to `TRUE`.
#' @param with_bias_abs Logical. If `TRUE`, includes absolute bias in concentration units in the results. Defaults to `FALSE`.
#' @param with_conc_ratio Logical. If `TRUE`, includes the ratio of measured to target concentration in the results. Defaults to `FALSE`.
#' @param with_cv_intra Logical. If `TRUE`, includes intra-assay coefficient of variation (CV) in the results. Defaults to `TRUE`.
#' @param with_conc_out_of_range Logical. If `TRUE` (and the dataset carries the
#'   `feature_conc_out_of_range` flag from [`quantify_by_calibration()`]), includes
#'   the fraction of replicate measurements whose concentration fell outside the
#'   calibrated range (`frac_conc_out_of_range`). Defaults to `TRUE`.
#'
#' @return A data frame containing the calibration results, including metrics such as bias, percentage bias, and intra-assay CV based on specified parameters.
#'
#' @details
#' The function uses data from the `MRMhubExperiment` object and filters it according to the specified QC types and other parameters. It then calculates summary statistics for each feature, such as bias and CV, and organizes the data into a user-specified format.
#'
#' @export
get_qc_bias_variability <- function(
  data,
  qc_types = NA,
  sample_ids = NA,
  wide_format = "none",
  include_qualifier = FALSE,
  with_conc = TRUE,
  with_conc_target = TRUE,
  with_bias = TRUE,
  with_bias_abs = FALSE,
  with_conc_ratio = FALSE,
  with_cv_intra = TRUE,
  with_conc_out_of_range = TRUE
) {
  check_data(data)

  has_conc_out_of_range <- "feature_conc_out_of_range" %in%
    names(data@dataset)

  if (!is.character(wide_format) || length(wide_format) != 1) {
    cli::cli_abort(
      "`wide_format` must be one of {.val none}, {.val features}, or {.val samples}."
    )
  }
  rlang::arg_match(wide_format, c("none", "features", "samples"))

  d_qc_summary <- data@dataset |>
    filter(!.data$is_istd) |>
    select(
      "analysis_id",
      "qc_type",
      "sample_id",
      "feature_id",
      "is_quantifier",
      "analyte_id",
      "feature_conc",
      dplyr::any_of("feature_conc_out_of_range")
    ) |>
    inner_join(
      data@annot_qcconcentrations |>
        select(
          "sample_id",
          "analyte_id",
          target_concentration = "concentration"
        ),
      by = c("sample_id", "analyte_id"),
      relationship = "many-to-one"
    )

  if (all(is.na(qc_types))) {
    qc_types <- unique(d_qc_summary$qc_type)
  } else {
    if (length(setdiff(qc_types, unique(d_qc_summary$qc_type))) > 0) {
      cli::cli_abort(paste(
        "One or more selected `qc_types` are not present in the data or have no defined analyte concentrations. Please verify the analyses, feature and QC-concentration metadata, or select other `qc_types`."
      ))
    }
  }

  d_qc_summary <- d_qc_summary |> filter(.data$qc_type %in% qc_types)

  if (!all(is.na(sample_ids))) {
    if (length(setdiff(sample_ids, unique(d_qc_summary$qc_type))) > 0) {
      cli::cli_abort(paste(
        "One or more selected `sample_id` are not present in the data or have no defined analyte concentrations. Please verify the analyses, feature and QC-concentration metadata, or select other `qc_types`."
      ))
    }
  }

  # Check if qc type and sample id are not paired resulting in no selected analyses
  if (!all(is.na(sample_ids))) {
    d_qc_summary <- d_qc_summary |> filter(.data$sample_id %in% sample_ids)
    if (nrow(d_qc_summary) == 0) {
      cli::cli_abort(paste(
        "No analyses with the selected `sample_id` and `qc_types` were found. Please verify the argument values, and corresponding feature metadata."
      ))
    }
  }

  if (!include_qualifier) {
    d_qc_summary <- d_qc_summary |> filter(.data$is_quantifier)
  }

  d_qc_summary <- d_qc_summary |>
    relocate("target_concentration", .after = "analyte_id") |>
    mutate(
      bias_abs_val = .data$feature_conc - .data$target_concentration,
      bias_val = (.data$feature_conc - .data$target_concentration) /
        .data$target_concentration *
        100,
      conc_ratio = .data$feature_conc / .data$target_concentration,
    ) |>
    summarise(
      # Count the non-missing replicates that actually feed conc_mean/sd/cv_intra,
      # so the reported n matches the CV denominator.
      n = sum(!is.na(.data$feature_conc)),
      conc_target = mean(.data$target_concentration, na.rm = FALSE),
      conc_mean = mean(.data$feature_conc, na.rm = TRUE),
      conc_sd = sd(.data$feature_conc, na.rm = TRUE),
      cv_intra = .data$conc_sd / .data$conc_mean * 100,
      bias = mean(.data$bias_val, na.rm = TRUE),
      bias_abs = mean(.data$bias_abs_val, na.rm = TRUE),
      conc_ratio = mean(.data$conc_ratio, na.rm = TRUE),
      conc_ratio_sd = sd(.data$conc_ratio, na.rm = TRUE),
      frac_conc_out_of_range = if (has_conc_out_of_range) {
        mean(.data$feature_conc_out_of_range, na.rm = TRUE)
      } else {
        NA_real_
      },
      .by = c("sample_id", "qc_type", "feature_id")
    )
  d_qc_summary <- d_qc_summary |>
    select(
      "feature_id",
      "qc_type",
      "sample_id",
      "n",
      if (with_conc_target) "conc_target",
      if (with_conc) "conc_mean",
      if (with_conc && !all(is.na(d_qc_summary$conc_sd))) "conc_sd",
      if (with_cv_intra) "cv_intra",
      if (with_bias) "bias",
      if (with_bias_abs) "bias_abs",
      if (with_conc_ratio) "conc_ratio",
      if (with_conc_ratio && !all(is.na(d_qc_summary$conc_ratio_sd))) {
        "conc_ratio_sd"
      },
      if (with_conc_out_of_range && has_conc_out_of_range) {
        "frac_conc_out_of_range"
      }
    )

  if (wide_format != "none") {
    optinal_columns <- c(
      "n",
      "conc_target",
      "conc_mean",
      "conc_sd",
      "cv_intra",
      "bias",
      "bias_abs",
      "conc_ratio",
      "conc_ratio_sd",
      "frac_conc_out_of_range"
    )
    available_columns <- intersect(optinal_columns, names(d_qc_summary))

    if (wide_format == "features") {
      d_qc_summary <- d_qc_summary |>
        tidyr::pivot_wider(
          names_from = "feature_id",
          values_from = any_of(available_columns),
          names_sort = TRUE,
          names_glue = "{feature_id}_{.value}"
        )
      d_qc_summary <- d_qc_summary |>
        select(order(colnames(d_qc_summary))) |>
        relocate("sample_id", "qc_type", .before = 1)
    } else {
      d_qc_summary <- d_qc_summary |>
        select(-"qc_type") |>
        tidyr::pivot_wider(
          names_from = "sample_id",
          values_from = any_of(available_columns),
          names_sort = TRUE,
          names_glue = "{sample_id}_{.value}"
        )
      d_qc_summary <- d_qc_summary |>
        select(order(colnames(d_qc_summary))) |>
        relocate("feature_id", .before = 1) |>
        arrange(.data$feature_id)
    }
  } else {
    d_qc_summary <- d_qc_summary |>
      relocate("feature_id", "sample_id", "qc_type", .before = 1) |>
      arrange(.data$feature_id)
  }
}

#' Get calibration metrics
#'
#' Extracts calibration fit metrics from a `MRMhubExperiment` object.
#'
#' Requires prior computation of regression results using [`calc_calibration_results()`].
#' See its documentation for details.
#'
#' ## Returned Details and Metrics
#' - `feature_id`: Feature identifier.
#' - `is_quantifier`: Logical, indicates if the feature is a quantifier.
#' - `fit_model`: Regression model used for fitting.
#' - `fit_weighting`: Weighting method used in fitting.
#' - `lowest_cal`: Lowest nonzero calibration concentration.
#' - `highest_cal`: Highest calibration concentration.
#' - `r2`: R-squared value, indicating goodness of fit. For a **weighted**
#'   fit this is the weighted coefficient of determination (computed from weighted
#'   sums of squares), matching the value reported by vendor software such as
#'   Agilent MassHunter for the same weighted curve.
#' - `coef_a`: Intercept of the regression line
#' - `coef_b`: Slope of the regression line in **linear** models, or coefficient of the linear term (`x`) in **quadratic** models.
#' - `coef_c`: Coefficient of the quadratic term (`x^2`) in **quadratic** models. Returns `NA` for **linear** models.
#' - `sigma`: Standard deviation of residuals.
#' - `reg_failed`: `TRUE` if regression fitting failed.
#' - `LoD` = 3.3× the sample standard error of residuals / slope of the regression (see Notes).
#' - `LoQ` = 10× the sample standard error of residuals / slope of the regression (see Notes).
#'
#' **Note:** LoD/LoQ follow the ICH Q2(R1/R2) approach (3.3 sigma / S and
#' 10 sigma / S). The slope `S` is the slope of the calibration curve at zero
#' concentration (the linear coefficient `coef_b`); for a **quadratic** fit the
#' quadratic term does not contribute to this slope. The response `sigma` is
#' selectable in [`calc_calibration_results()`] via `lod_sigma` (residual
#' standard error, the default, or the standard error of the intercept); the
#' `sigma` column reported here is always the residual standard error.
#'
#' For a **weighted** fit (`1/x`, `1/x^2`, `1/sqrt(x)`) `sigma` is R's weighted
#' residual standard error, which is not on the raw response scale that the ICH
#' `3.3 sigma / S` formula assumes, so the reported LoD/LoQ are approximate
#' (typically slightly optimistic for `1/x`). Use `fit_weighting = "none"` if you
#' require the strict ICH response-scale `Sy/x`; the back-calculated
#' concentrations themselves are unaffected.

#'
#' @param data A [`MRMhubExperiment`][MRMhubExperiment-class] object with QC metrics.
#' @param with_lod Whether to include LoD in output. Default is `TRUE`.
#' @param with_loq Whether to include LoQ in output. Default is `TRUE`.
#' @param with_coefficients Whether to include regression coefficients. Default is `TRUE`.
#' @param with_sigma Whether to include sigma in output. Default is `TRUE`.
#' @return A tibble with exported calibration metrics.
#' @export

get_calibration_metrics <- function(
  data = NULL,
  with_lod = TRUE,
  with_loq = TRUE,
  with_coefficients = TRUE,
  with_sigma = TRUE
) {
  check_data(data)

  # Verify that the QC metrics have been calculated
  if (nrow(data@metrics_calibration) == 0) {
    cli::cli_abort(
      "Calibration metrics has not yet been calculated. Please run `calc_calibration_results()` first."
    )
  }

  cal <- data@metrics_calibration |>
    dplyr::rename_with(~ str_replace(., "_cal_1", "")) |> # Remove _cal_1 from all column names
    select(
      "feature_id",
      "is_quantifier",
      "fit_model",
      "fit_weighting",
      "reg_failed",
      "r2",
      "lowest_cal",
      "highest_cal",
      if (with_coefficients) "coef_a",
      if (with_coefficients) "coef_b",
      if (with_coefficients) "coef_c",
      if (with_lod) "lod",
      if (with_loq) "loq",
      if (with_sigma) "sigma"
    )

  # Return the metrics
  cal
}
