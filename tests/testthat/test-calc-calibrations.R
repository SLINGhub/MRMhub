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
  expect_equal(mean(res$r2_cal_1), 0.97955745)
  expect_equal(mean(res$lowest_cal_cal_1), 3.30675)
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

test_that("calc_calibration_results error handling works", {
  mexp_temp <- mexp_norm

  mexp_temp@annot_qcconcentrations$concentration <- NA

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


test_that("quantify_by_calibration works", {
  expect_message(
    mexp_res <- quantify_by_calibration(
      mexp_norm,
      fit_overwrite = FALSE,
      include_qualifier = TRUE,
      fit_model = "quadratic",
      fit_weighting = "1/x"
    ),
    "Concentrations of these features were calculated for 25 analyses"
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
    "Concentrations of these features were calculated for 25 analyses"
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
    "Concentrations of the other features were calculated"
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
      "bias"
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
  expect_equal(names(result), c("feature_id", "sample_id", "qc_type", "n"))
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
