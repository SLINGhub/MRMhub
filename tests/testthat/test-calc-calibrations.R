# library(testthat)
# library(dplyr)

mexp <- quant_lcms_dataset
mexp_norm <- normalize_by_istd(mexp)

test_that("calc_calibration_results works", {
  expect_message(
    mexp_res <- calc_calibration_results(
      mexp_norm,
      fit_overwrite = TRUE,
      fit_model = "linear",
      fit_weighting = "1/x"
    ),
    "Calibration curve fits calculated for all 4 quantifier and 4 qualifier features"
  )

  res <- mexp_res@metrics_calibration
  expect_equal(dim(res), c(8, 15))
  expect_equal(unique(res$fit_model), "linear")
  expect_equal(unique(res$fit_weighting), "1/x")

  expect_message(
    mexp_res <- calc_calibration_results(
      mexp_norm,
      include_qualifier = FALSE,
      fit_overwrite = TRUE,
      fit_model = "linear",
      fit_weighting = "1/x"
    ),
    "Calibration curve fits calculated for all 4 quantifier features"
  )

  res <- mexp_res@metrics_calibration
  expect_equal(dim(res), c(4, 15))
  expect_equal(unique(res$fit_model), "linear")
  expect_equal(unique(res$fit_weighting), "1/x")

  mexp_res <- calc_calibration_results(
    mexp_norm,
    fit_overwrite = FALSE,
    fit_model = "linear",
    fit_weighting = "1/x"
  )
  res <- mexp_res@metrics_calibration
  expect_equal(unique(res$fit_model), c("quadratic", "linear"))
  expect_equal(unique(res$fit_weighting), "1/x")
  # Corticosterone: quadratic through its 3 included calibrators, no R2
  expect_true(is.na(res$r2_cal_1[res$feature_id == "Corticosterone"]))
  expect_equal(mean(res$r2_cal_1, na.rm = TRUE), 0.97663709)
  expect_equal(mean(res$lowest_cal_cal_1), 3.34825)
  expect_equal(mean(res$loq_cal_1, na.rm = T), 7.911120433)

  # Missing fit parameter replaced with defauls provided with fit_ args.
  mexp_temp <- mexp_norm
  mexp_temp@annot_features$curve_fit_model[c(1, 3, 5, 7)] <- NA
  mexp_temp@annot_features$curve_fit_weighting[c(1, 3, 5, 7)] <- NA

  mexp_res <- calc_calibration_results(
    mexp_temp,
    fit_overwrite = FALSE,
    fit_model = "linear",
    fit_weighting = "none"
  )
  res <- mexp_res@metrics_calibration
  expect_equal(unique(res$fit_model[c(1, 2, 3, 4)]), c("linear"))
  expect_equal(unique(res$fit_weighting[c(1, 2, 3, 4)]), c("none", "1/x"))
})

test_that("a duplicated QC-concentration row is rejected by the calibration fit, not used twice", {
  # A duplicated (sample_id, analyte_id) concentration would silently weight a
  # calibrator level twice and bias every back-calculated concentration. The
  # pre-flight uniqueness guard turns that into a clear, actionable error before
  # the join, instead of a plausible-but-wrong curve or a raw dplyr message.
  mexp_dup <- mexp_norm
  mexp_dup@annot_qcconcentrations <- dplyr::bind_rows(
    mexp_dup@annot_qcconcentrations,
    mexp_dup@annot_qcconcentrations
  )

  expect_error(
    calc_calibration_results(
      mexp_dup,
      fit_overwrite = TRUE,
      fit_model = "linear",
      fit_weighting = "none"
    ),
    "Duplicated .*sample_id, analyte_id"
  )
})

test_that("a zero-concentration blank is dropped from a weighted fit and reported", {
  # A blank (concentration 0) cannot be inverse-weighted (1/0 = Inf), which makes
  # the weighted lm() fail (previously a silent generic "fit failed"). It must be
  # dropped so the fit succeeds over the real standards, and the exclusion
  # surfaced so it is attributable.
  mexp_blank <- mexp_norm
  qc <- mexp_blank@annot_qcconcentrations
  low_sample <- qc |>
    dplyr::slice_min(concentration, n = 1, with_ties = FALSE) |>
    dplyr::pull(sample_id)
  mexp_blank@annot_qcconcentrations <- qc |>
    dplyr::mutate(
      concentration = dplyr::if_else(sample_id == low_sample, 0, concentration)
    )

  expect_message(
    mexp_res <- calc_calibration_results(
      mexp_blank,
      fit_overwrite = TRUE,
      fit_model = "linear",
      fit_weighting = "1/x"
    ),
    "Zero-concentration calibrator excluded"
  )
  # the weighted fit now succeeds over the real standards (would fail on 1/0=Inf)
  r <- mexp_res@metrics_calibration
  reg_failed <- unlist(r[grepl("reg_failed", names(r))])
  expect_false(any(reg_failed, na.rm = TRUE))
  expect_true(all(is.finite(r$r2_cal_1)))
})

test_that("calc_calibration_results LoD/LoQ use the slope at zero (ICH Q2)", {
  # LoD/LoQ use the slope of the calibration curve at zero concentration, i.e.
  # the linear coefficient (coef_b), for both linear and quadratic fits. The
  # quadratic term (coef_c) must not affect the slope used here.
  res <- calc_calibration_results(
    mexp_norm,
    fit_overwrite = TRUE,
    fit_model = "quadratic",
    fit_weighting = "none",
    ignore_missing_annotation = TRUE
  )@metrics_calibration |>
    filter(fit_model == "quadratic", !reg_failed_cal_1)

  expect_equal(res$lod_cal_1, 3.3 * res$sigma_cal_1 / res$coef_b_cal_1)
  expect_equal(res$loq_cal_1, 10 * res$sigma_cal_1 / res$coef_b_cal_1)
})

test_that("calc_calibration_results maps coef_a/b/c to intercept/linear/quadratic (ascending)", {
  # Guard the stored coefficient order: a fitted quadratic is
  # `response = coef_a + coef_b*x + coef_c*x^2` (ascending power, R's lm/poly
  # convention). Truth values are deliberately distinct and non-swappable
  # (intercept 0.1, slope 5, curvature 0.02) so a silent x^2 <-> intercept flip
  # (the descending vendor-export convention) cannot slip through: the linear
  # term and R^2 would still match, but coef_a/coef_c would not.
  a0 <- 0.1
  b1 <- 5
  c2 <- 0.02

  mexp_known <- mexp_norm
  target <- mexp_norm@dataset |>
    dplyr::filter(qc_type == "CAL", !is_istd, is_quantifier) |>
    dplyr::slice(1) |>
    dplyr::pull(feature_id)

  ds <- mexp_known@dataset
  cal_idx <- which(ds$feature_id == target & ds$qc_type == "CAL" & !ds$is_istd)
  conc <- dplyr::inner_join(
    ds[cal_idx, c("sample_id", "analyte_id")],
    mexp_known@annot_qcconcentrations,
    by = c("sample_id", "analyte_id")
  )$concentration
  # Overwrite the CAL responses so they lie exactly on the known parabola.
  ds$feature_norm_intensity[cal_idx] <- a0 + b1 * conc + c2 * conc^2
  mexp_known@dataset <- ds

  res <- suppressMessages(calc_calibration_results(
    mexp_known,
    fit_overwrite = TRUE,
    fit_model = "quadratic",
    fit_weighting = "none",
    ignore_missing_annotation = TRUE
  ))
  coefs <- get_calibration_metrics(res) |>
    dplyr::filter(feature_id == target)

  expect_equal(coefs$coef_a, a0) # intercept, NOT the x^2 term
  expect_equal(coefs$coef_b, b1) # 1st-order (linear) term
  expect_equal(coefs$coef_c, c2) # 2nd-order (quadratic) term
})

test_that("calc_calibration_results lod_sigma = 'intercept' uses the intercept SE", {
  # Default (residual SE, Sy/x): current behaviour.
  res_resid <- calc_calibration_results(
    mexp_norm,
    fit_overwrite = TRUE,
    fit_model = "quadratic",
    fit_weighting = "none",
    ignore_missing_annotation = TRUE
  )@metrics_calibration |>
    filter(fit_model == "quadratic", !reg_failed_cal_1)

  # Intercept SE (SDa), with the fit objects retained so we can read the exact
  # standard error of the intercept used internally.
  res_int <- calc_calibration_results(
    mexp_norm,
    fit_overwrite = TRUE,
    fit_model = "quadratic",
    fit_weighting = "none",
    ignore_missing_annotation = TRUE,
    lod_sigma = "intercept",
    include_fit_object = TRUE
  )@metrics_calibration |>
    filter(fit_model == "quadratic", !reg_failed_cal_1)

  sda <- vapply(
    res_int$fit_cal_1,
    function(f) summary(f)$coefficients["(Intercept)", "Std. Error"],
    numeric(1)
  )

  # LoD/LoQ use the intercept SE over the slope at zero (coef_b).
  expect_equal(res_int$lod_cal_1, 3.3 * sda / res_int$coef_b_cal_1)
  expect_equal(res_int$loq_cal_1, 10 * sda / res_int$coef_b_cal_1)

  # The reported `sigma` column is always the residual SE, independent of choice.
  expect_equal(res_int$sigma_cal_1, res_resid$sigma_cal_1)

  # The two sigma sources give different detection limits here.
  expect_false(isTRUE(all.equal(res_int$lod_cal_1, res_resid$lod_cal_1)))
})

test_that("calc_calibration_results rejects an invalid lod_sigma", {
  expect_error(
    calc_calibration_results(
      mexp_norm,
      fit_overwrite = TRUE,
      fit_model = "linear",
      fit_weighting = "1/x",
      lod_sigma = "bogus"
    )
  )
})

test_that("calc_calibration_results error handling works", {
  mexp_temp <- mexp_norm

  # All calibrator concentrations missing (kept numeric): every fit fails.
  mexp_temp@annot_qcconcentrations$concentration <- NA_real_

  expect_error(
    mexp_res <- calc_calibration_results(
      mexp_temp,
      fit_overwrite = TRUE,
      fit_model = "linear",
      fit_weighting = "1/x"
    ),
    "All calibration curve fits for quantifier features"
  )

  expect_error(
    mexp_res <- calc_calibration_results(
      mexp_temp,
      fit_overwrite = TRUE,
      include_qualifier = FALSE,
      fit_model = "linear",
      fit_weighting = "1/x"
    ),
    "All calibration curve fits failed"
  )
})

test_that("the calibrated range spans only calibrators with a response", {
  # In the fixture, CalA has no response for the Aldosterone qualifier, nor
  # CalE/CalF for the Cortisone qualifier.
  res <- suppressMessages(calc_calibration_results(
    mexp_norm,
    fit_overwrite = TRUE,
    fit_model = "linear",
    fit_weighting = "1/x"
  ))@metrics_calibration
  qc <- mexp_norm@annot_qcconcentrations
  conc <- function(sample, analyte) {
    qc$concentration[qc$sample_id == sample & qc$analyte_id == analyte]
  }
  expect_equal(
    res$lowest_cal_cal_1[res$feature_id == "Aldosterone [QUAL 361.2 -> 343.1]"],
    conc("CAL-B", "Aldosterone")
  )
  expect_equal(
    res$highest_cal_cal_1[res$feature_id == "Cortisone [QUAL 361.2 -> 121.1]"],
    conc("CAL-D", "Cortisone")
  )
})

test_that("calc_calibration_results names the missing calibration input", {
  calib <- function(m) {
    suppressMessages(calc_calibration_results(
      m,
      fit_overwrite = FALSE,
      fit_model = "linear",
      fit_weighting = "1/x"
    ))
  }

  no_targets <- mexp_norm
  no_targets@annot_qcconcentrations <- no_targets@annot_qcconcentrations[0, ]
  expect_error(calib(no_targets), "QC-concentration")

  no_cal <- mexp_norm
  no_cal@dataset$qc_type[no_cal@dataset$qc_type == "CAL"] <- "SPL"
  expect_error(calib(no_cal), "No calibration .*CAL")

  no_match <- mexp_norm
  no_match@annot_qcconcentrations$sample_id <- paste0(
    no_match@annot_qcconcentrations$sample_id,
    "_x"
  )
  expect_error(calib(no_match), "matched")

  all_excluded <- mexp_norm
  all_excluded@annot_qcconcentrations$include_in_analysis <- FALSE
  expect_error(calib(all_excluded), "matched")
})

test_that("calc_calibration_results aborts on an unknown per-feature fit model or weighting", {
  mexp_temp <- mexp_norm
  mexp_temp@annot_features$curve_fit_model[
    mexp_temp@annot_features$feature_id == "Cortisol"
  ] <- "cubic"
  expect_error(
    calc_calibration_results(
      mexp_temp,
      fit_overwrite = FALSE,
      fit_model = "linear",
      fit_weighting = "1/x"
    ),
    "Cortisol.*cubic"
  )

  mexp_temp <- mexp_norm
  mexp_temp@annot_features$curve_fit_weighting[
    mexp_temp@annot_features$feature_id == "Cortisone"
  ] <- "1/y"
  expect_error(
    calc_calibration_results(
      mexp_temp,
      fit_overwrite = FALSE,
      fit_model = "linear",
      fit_weighting = "1/x"
    ),
    "Cortisone.*1/y"
  )
})

test_that("the 1/sqrt(x) weighting is accepted and applied", {
  res <- suppressMessages(calc_calibration_results(
    mexp_norm,
    fit_overwrite = TRUE,
    fit_model = "linear",
    fit_weighting = "1/sqrt(x)",
    include_fit_object = TRUE
  ))@metrics_calibration
  expect_equal(unique(res$fit_weighting), "1/sqrt(x)")
  fit <- res$fit_cal_1[[1]]
  expect_equal(unname(weights(fit)), 1 / sqrt(unname(model.matrix(fit)[, 2])))

  expect_no_error(suppressMessages(quantify_by_calibration(
    mexp_norm,
    fit_overwrite = TRUE,
    fit_model = "linear",
    fit_weighting = "1/sqrt(x)"
  )))
})


test_that("quantify_by_calibration works", {
  expect_message(
    mexp_res <- quantify_by_calibration(
      mexp_norm,
      fit_overwrite = FALSE,
      include_qualifier = TRUE,
      fit_model = "quadratic",
      fit_weighting = "1/x"
    ),
    "Concentrations calculated for 8 features in 25 analyses"
  )

  res <- mexp_res@dataset |> filter(analysis_id == "CalE", !is_istd)
  # Mean over quantifier + qualifier features; qualifiers here use linear fits,
  # so the linear back-calculation (feature_conc = (norm_int - intercept)/slope)
  # feeds into this value.
  expect_equal(mean(res$feature_conc, na.rm = TRUE), 101.4036661)

  # below is the original conc from Corticosterone CAL-E as r2 = 1
  expect_equal(res$feature_conc[1], 42.2)

  res <- mexp_res@metrics_calibration
  expect_equal(unique(res$fit_model), c("quadratic", "linear"))

  expect_message(
    mexp_res <- quantify_by_calibration(
      mexp_norm,
      fit_overwrite = FALSE,
      include_qualifier = FALSE,
      fit_model = "quadratic",
      fit_weighting = "1/x"
    ),
    "Concentrations calculated for 4 features in 25 analyses"
  )

  res <- mexp_res@dataset |> filter(analysis_id == "CalE", !is_istd)
  expect_equal(mean(res$feature_conc, na.rm = TRUE), 101.4981448)
})

test_that("quantify_by_calibration linear back-calculation recovers known concentrations", {
  # Force an all-linear fit so the linear back-calc branch is exercised. This is a
  # truth-based guard against a slope/intercept swap in the back-calculation, which
  # produced negative concentrations for a well-fitting linear calibration.
  mexp_lin <- quantify_by_calibration(
    mexp_norm,
    fit_overwrite = TRUE,
    include_qualifier = TRUE,
    fit_model = "linear",
    fit_weighting = "none",
    ignore_missing_annotation = TRUE,
    ignore_failed_calibration = TRUE
  )

  # A well-fitting linear feature: back-calculating the calibration samples must
  # recover their known nominal concentrations.
  rec <- mexp_lin@dataset |>
    filter(
      feature_id == "Cortisol [QUAL 363.2 -> 97.1]",
      qc_type == "CAL",
      !is_istd
    ) |>
    inner_join(
      mexp_lin@annot_qcconcentrations,
      by = c("sample_id", "analyte_id")
    ) |>
    filter(concentration > 0) |>
    arrange(desc(concentration))

  nominal <- rec$concentration
  recovered <- rec$feature_conc

  expect_gt(min(recovered), 0) # never negative (the swap bug)
  expect_gt(cor(nominal, recovered), 0.99) # tracks the calibration line
  expect_equal(recovered[1], nominal[1], tolerance = 0.05) # top point within 5%
})

test_that("quantifying by calibration twice gives the same concentrations as once", {
  quant <- function(m) {
    suppressMessages(quantify_by_calibration(
      m,
      fit_overwrite = FALSE,
      fit_model = "linear",
      fit_weighting = "1/x"
    ))
  }
  once <- quant(mexp_norm)
  expect_true("quadratic" %in% once@metrics_calibration$fit_model)
  twice <- quant(once)

  expect_equal(twice@dataset$feature_conc, once@dataset$feature_conc)
  expect_false(any(startsWith(names(twice@dataset), "fit_model")))

  # An object saved by an earlier version still carries `fit_model`.
  stale <- once
  stale@dataset$fit_model <- "linear"
  expect_equal(quant(stale)@dataset$feature_conc, once@dataset$feature_conc)
})

test_that("ignore_failed_calibration = TRUE continues when every fit fails", {
  # A single calibrator per curve cannot fit a quadratic: no fit can succeed.
  mexp_temp <- mexp_norm
  qc <- mexp_temp@annot_qcconcentrations
  mexp_temp@annot_qcconcentrations$include_in_analysis <- qc$sample_id ==
    "CAL-A"

  suppressMessages(expect_message(
    res <- quantify_by_calibration(
      mexp_temp,
      fit_overwrite = TRUE,
      fit_model = "quadratic",
      fit_weighting = "1/x",
      ignore_failed_calibration = TRUE,
      ignore_missing_annotation = TRUE
    ),
    "All calibration curve fits"
  ))
  expect_true(all(is.na(res@dataset$feature_conc[!res@dataset$is_istd])))
})

test_that("quantify_by_calibration handles errors", {
  mexp_temp <- mexp_norm
  mexp_temp@annot_qcconcentrations <- mexp_temp@annot_qcconcentrations |>
    mutate(
      concentration = if_else(
        str_detect(analyte_id, "Cortiso"),
        NA_real_,
        concentration
      )
    )

  expect_error(
    mexp_res <- quantify_by_calibration(
      mexp_temp,
      fit_overwrite = FALSE,
      include_qualifier = FALSE,
      ignore_failed_calibration = FALSE,
      fit_model = "quadratic",
      fit_weighting = "1/x"
    ),
    "Calibration curve fit failed for 2 features"
  )

  expect_message(
    mexp_res <- quantify_by_calibration(
      mexp_temp,
      fit_overwrite = FALSE,
      include_qualifier = FALSE,
      ignore_failed_calibration = TRUE,
      fit_model = "quadratic",
      fit_weighting = "1/x"
    ),
    "Calibration curve fit failed for 2 features"
  )

  expect_message(
    mexp_res <- quantify_by_calibration(
      mexp_temp,
      fit_overwrite = FALSE,
      include_qualifier = FALSE,
      ignore_failed_calibration = TRUE,
      fit_model = "quadratic",
      fit_weighting = "1/x"
    ),
    "Concentrations calculated for 2 features in 24 analyses"
  )

  mexp_temp <- mexp_norm
  mexp_temp@annot_qcconcentrations <- mexp_temp@annot_qcconcentrations |>
    filter(!str_detect(analyte_id, "Cortiso"))

  expect_error(
    mexp_res <- quantify_by_calibration(
      mexp_temp,
      fit_overwrite = FALSE,
      include_qualifier = FALSE,
      ignore_failed_calibration = FALSE,
      fit_model = "quadratic",
      fit_weighting = "1/x"
    ),
    "Calibration curve annotations for 2 features are missing."
  )

  expect_message(
    mexp_res <- quantify_by_calibration(
      mexp_temp,
      fit_overwrite = FALSE,
      include_qualifier = FALSE,
      ignore_failed_calibration = FALSE,
      ignore_missing_annotation = TRUE,
      fit_model = "quadratic",
      fit_weighting = "1/x"
    ),
    "Calibration curve annotations for 2 features are missing."
  )
})


mexp_quant <- quant_lcms_dataset
mexp_quant_norm <- normalize_by_istd(mexp_quant)
mexp_quant_norm <- calc_calibration_results(
  mexp_quant_norm,
  fit_overwrite = FALSE,
  fit_model = "quadratic",
  fit_weighting = "1/x"
)
mexp_quant_norm <- quantify_by_calibration(
  mexp_quant_norm,
  fit_overwrite = FALSE,
  fit_model = "quadratic",
  fit_weighting = "1/x"
)


test_that("get_qc_bias_variability returns correct data", {
  result <- get_qc_bias_variability(
    mexp_quant_norm,
    qc_types = c("CAL", "LQC", "HQC")
  )
  expect_s3_class(result, "data.frame")
  expect_equal(
    names(result),
    c(
      "feature_id",
      "sample_id",
      "qc_type",
      "n",
      "conc_target",
      "conc_mean",
      "conc_sd",
      "cv_intra",
      "bias",
      "frac_conc_out_of_range"
    )
  )
  expect_equal(nrow(result), 32)

  result <- get_qc_bias_variability(
    mexp_quant_norm,
    qc_types = NA,
    with_conc = FALSE,
    with_conc_target = FALSE,
    with_bias = FALSE,
    with_bias_abs = FALSE,
    with_cv_intra = FALSE,
    with_conc_ratio = FALSE
  )
  expect_equal(
    names(result),
    c("feature_id", "sample_id", "qc_type", "n", "frac_conc_out_of_range")
  )
  expect_equal(unique(result$qc_type), c("CAL", "HQC", "LQC"))

  result <- get_qc_bias_variability(mexp_quant_norm, include_qualifier = TRUE)
  expect_equal(nrow(result), 64)

  result <- get_qc_bias_variability(mexp_quant_norm, wide_format = "features")
  expect_equal(
    names(result)[1:3],
    c("sample_id", "qc_type", "Aldosterone_bias")
  )
  expect_equal(nrow(result), 8)

  result <- get_qc_bias_variability(mexp_quant_norm, wide_format = "samples")
  expect_equal(
    names(result)[1:3],
    c("feature_id", "CAL-A_bias", "CAL-A_conc_mean")
  )
  expect_equal(nrow(result), 4)
})

test_that("get_qc_bias_variability counts only non-missing replicates in n", {
  # n must match the denominator that feeds conc_mean/conc_sd/cv_intra, so
  # NA-ing exactly one QC concentration lowers the total n by exactly one.
  qc <- c("CAL", "LQC", "HQC")
  base <- get_qc_bias_variability(mexp_quant_norm, qc_types = qc)

  mexp_na <- mexp_quant_norm
  idx <- which(
    !mexp_na@dataset$is_istd &
      mexp_na@dataset$qc_type %in% qc &
      !is.na(mexp_na@dataset$feature_conc)
  )[1]
  mexp_na@dataset$feature_conc[idx] <- NA_real_

  after <- get_qc_bias_variability(mexp_na, qc_types = qc)
  expect_equal(sum(after$n), sum(base$n) - 1L)
})

test_that("get_qc_bias_variability selects by sample_ids", {
  res <- get_qc_bias_variability(mexp_quant_norm, sample_ids = "CAL-C")
  expect_equal(unique(res$sample_id), "CAL-C")

  expect_error(
    get_qc_bias_variability(mexp_quant_norm, sample_ids = "nope"),
    "sample_ids.*nope"
  )

  # A valid sample_id that the qc_types filter excludes is reported by the same
  # check, so no separate "nothing selected" branch is needed.
  expect_error(
    get_qc_bias_variability(
      mexp_quant_norm,
      qc_types = "LQC",
      sample_ids = "CAL-C"
    ),
    "sample_ids.*CAL-C"
  )
})

test_that("get_qc_bias_variability reports the SD of the replicate conc ratios", {
  res <- get_qc_bias_variability(
    mexp_quant_norm,
    qc_types = "HQC",
    with_conc_ratio = TRUE
  )
  expect_true("conc_ratio_sd" %in% names(res))

  target <- mexp_quant_norm@annot_qcconcentrations |>
    filter(sample_id == "HQC", analyte_id == "Cortisol") |>
    pull(concentration)
  ratios <- mexp_quant_norm@dataset |>
    filter(sample_id == "HQC", feature_id == "Cortisol") |>
    pull(feature_conc) /
    target
  expect_equal(
    res$conc_ratio_sd[res$feature_id == "Cortisol"],
    sd(ratios, na.rm = TRUE)
  )
})

test_that("a blank sample_id never matches a blank QC-concentration sample_id", {
  # CalA has a blank Sample ID, as do the SPL/SBLK/IBLK analyses.
  base <- mexp_norm
  base@dataset$sample_id[base@dataset$analysis_id == "CalA"] <- NA
  with_blank_target <- base
  with_blank_target@annot_qcconcentrations <- dplyr::bind_rows(
    base@annot_qcconcentrations,
    dplyr::tibble(
      sample_id = NA_character_,
      analyte_id = "Cortisol",
      concentration = 50,
      concentration_unit = "nmol/L",
      include_in_analysis = TRUE
    )
  )
  calib <- function(m) {
    suppressMessages(calc_calibration_results(
      m,
      fit_overwrite = FALSE,
      fit_model = "linear",
      fit_weighting = "1/x"
    ))@metrics_calibration
  }
  expect_equal(calib(with_blank_target), calib(base))

  quantified <- suppressMessages(quantify_by_calibration(
    with_blank_target,
    fit_overwrite = FALSE,
    fit_model = "linear",
    fit_weighting = "1/x"
  ))
  res <- get_qc_bias_variability(quantified)
  expect_false(anyNA(res$sample_id))
})

test_that("get_qc_bias_variability handles errors", {
  expect_error(
    get_qc_bias_variability(
      mexp_quant_norm,
      qc_types = c("CAL", "LQC", "HQC", "EQA")
    ),
    "One or more selected \\`qc_types\\`"
  )

  expect_error(
    get_qc_bias_variability(mexp_quant_norm, wide_format = FALSE),
    "\\`wide_format\\` must be one of"
  )
})

#
#
test_that("get_calibration_metrics returns correct data", {
  result <- get_calibration_metrics(mexp_quant_norm)

  expect_s3_class(result, "data.frame")
  expect_equal(
    names(result),
    c(
      "feature_id",
      "is_quantifier",
      "fit_model",
      "fit_weighting",
      "reg_failed",
      "r2",
      "lowest_cal",
      "highest_cal",
      "coef_a",
      "coef_b",
      "coef_c",
      "lod",
      "loq",
      "sigma"
    )
  )

  result <- get_calibration_metrics(
    mexp_quant_norm,
    with_lod = FALSE,
    with_loq = FALSE,
    with_coefficients = FALSE,
    with_sigma = FALSE
  )

  expect_equal(
    names(result),
    c(
      "feature_id",
      "is_quantifier",
      "fit_model",
      "fit_weighting",
      "reg_failed",
      "r2",
      "lowest_cal",
      "highest_cal"
    )
  )
})


test_that("get_calibration_metrics handles errors", {
  expect_error(
    get_calibration_metrics(mexp_quant),
    "Calibration metrics has not yet been calculated"
  )
})

test_that("quantify_by_calibration guards un-invertible responses as NA, not Inf", {
  # A quadratic calibration cannot invert every response: values off the curve
  # have no real solution. The back-calculation guard sets these to NA (never
  # Inf/NaN) and warns -- the same guard that also protects a zero calibration
  # slope, which is unreachable through a real least-squares fit.
  suppressMessages(
    expect_warning(
      mexp_res <- quantify_by_calibration(
        mexp_norm,
        fit_overwrite = TRUE,
        include_qualifier = TRUE,
        fit_model = "quadratic",
        fit_weighting = "none",
        ignore_missing_annotation = TRUE,
        ignore_failed_calibration = TRUE
      ),
      "could not be back-calculated"
    )
  )

  concs <- mexp_res@dataset$feature_conc
  expect_false(any(is.infinite(concs) | is.nan(concs), na.rm = TRUE))
})

test_that("quantify_by_calibration errors cleanly on empty / zero-row input", {
  # A freshly constructed (empty) experiment
  expect_error(
    quantify_by_calibration(
      mrmhub::MRMhubExperiment(),
      fit_overwrite = TRUE,
      fit_model = "linear",
      fit_weighting = "none"
    ),
    "No data to quantify"
  )

  # A normalized experiment whose dataset has been emptied. This previously
  # crashed with a cryptic "Column `coef_b` not found" inside the LoD/LoQ step,
  # because no calibration rows means the coefficient columns are never built.
  mexp_zero <- mexp_norm
  mexp_zero@dataset <- mexp_zero@dataset[FALSE, ]
  expect_error(
    quantify_by_calibration(
      mexp_zero,
      fit_overwrite = TRUE,
      fit_model = "linear",
      fit_weighting = "none"
    ),
    "No data to quantify"
  )
})

test_that("quantify_by_calibration clears values derived from a previous calibration", {
  # calibrate_by_reference() derives feature_conc_ratio and feature_conc_beforecal
  # from the concentrations of that run. Re-deriving feature_conc from the
  # calibration curves invalidates both.
  mexp_cal <- calibrated_experiment()
  # HQC has no usable signal for some features in this dataset; assert that
  # warning rather than suppressing it, so a different one would surface.
  expect_warning(
    mexp_ref <- suppressMessages(calibrate_by_reference(
      mexp_cal,
      variable = "feature_conc",
      reference_sample_id = "HQC",
      absolute_calibration = TRUE,
      store_conc_ratio = TRUE,
      undefined_conc_action = "na"
    )),
    "reference summary was zero or undefined"
  )
  expect_true("feature_conc_ratio" %in% names(mexp_ref@dataset))
  expect_true("feature_conc_beforecal" %in% names(mexp_ref@dataset))

  res <- suppressMessages(quantify_by_calibration(
    mexp_ref,
    fit_overwrite = FALSE
  ))
  expect_false("feature_conc_ratio" %in% names(res@dataset))
  expect_false("feature_conc_beforecal" %in% names(res@dataset))
})

# Keep `n` of the 6 calibrators (CAL-D onwards) and ISTD-normalize
few_cal <- function(n) {
  cal <- unique(mexp@dataset$analysis_id[mexp@dataset$qc_type == "CAL"])
  keep <- cal[3 + seq_len(n)]
  suppressMessages(normalize_by_istd(exclude_analyses(
    mexp,
    analyses = setdiff(cal, keep),
    clear_existing = TRUE
  )))
}
fit_cal <- function(m, model = "linear") {
  suppressMessages(calc_calibration_results(
    m,
    fit_overwrite = TRUE,
    fit_model = model,
    fit_weighting = "none"
  ))@metrics_calibration
}

test_that("a 2-point calibration is fitted without statistics", {
  res <- fit_cal(few_cal(2))
  expect_false(any(res$reg_failed_cal_1))
  expect_false(anyNA(res$coef_b_cal_1))
  expect_true(all(is.na(res$r2_cal_1)))
  expect_true(all(is.na(res$sigma_cal_1)))
  expect_true(all(is.na(res$lod_cal_1)))
  expect_true(all(is.na(res$loq_cal_1)))
})

test_that("a 1-point calibration is a line through the origin", {
  m <- few_cal(1)
  res <- fit_cal(m)
  expect_false(any(res$reg_failed_cal_1))
  expect_true(all(res$coef_a_cal_1 == 0))
  expect_true(all(is.na(res$r2_cal_1)))

  d <- m@dataset[
    m@dataset$qc_type == "CAL" & m@dataset$feature_id == "Aldosterone",
  ]
  conc <- m@annot_qcconcentrations$concentration[
    m@annot_qcconcentrations$sample_id == d$sample_id &
      m@annot_qcconcentrations$analyte_id == "Aldosterone"
  ]
  expect_equal(
    res$coef_b_cal_1[res$feature_id == "Aldosterone"],
    d$feature_norm_intensity / conc
  )
})

test_that("a 3-point quadratic calibration is fitted without statistics", {
  # Corticosterone has only 2 included calibrators here
  expect_message(
    m <- calc_calibration_results(
      few_cal(3),
      fit_overwrite = TRUE,
      fit_model = "quadratic",
      fit_weighting = "none"
    ),
    "at least 3 calibrators"
  )
  res <- m@metrics_calibration
  row <- res$feature_id == "Aldosterone"
  expect_false(res$reg_failed_cal_1[row])
  expect_true(is.na(res$r2_cal_1[row]))
})

test_that("a quadratic calibration with fewer than 3 points fails with a warning", {
  expect_message(
    calc_calibration_results(
      few_cal(2),
      fit_overwrite = TRUE,
      fit_model = "quadratic",
      fit_weighting = "none",
      ignore_failed_calibration = TRUE
    ),
    "at least 3 calibrators"
  )
})
