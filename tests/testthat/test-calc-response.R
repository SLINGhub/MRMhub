# library(testthat)
# library(dplyr)

mexp_orig <- lipidomics_dataset
mexp <- normalize_by_istd(mexp_orig)
mexp <- quantify_by_istd(mexp)
mexp_proc <- calc_qc_metrics(mexp, use_batch_medians = FALSE)


test_that("get_response_curve_stats works", {
  res <- get_response_curve_stats(mexp)
  expect_s3_class(res, "tbl_df")
  expect_equal(dim(res), c(29, 7))

  res <- get_response_curve_stats(mexp, limit_to_rqc = TRUE)
  expect_s3_class(res, "tbl_df")
  expect_equal(dim(res), c(29, 7))

  res <- get_response_curve_stats(mexp, with_saturation_stats = TRUE)
  expect_equal(dim(res), c(29, 17))
})

test_that("get_response_curve_stats missing data correctly handled", {
  mexp_temp <- mexp
  mexp_temp@annot_responsecurves <- mexp_temp@annot_responsecurves[0, ]

  expect_error(
    get_response_curve_stats(mexp_temp),
    "No response curve metadata found"
  )

  # A response-curve analysis_id missing from the data no longer aborts: the
  # present series are still fitted and a warning names the missing IDs + curves.
  mexp_temp <- mexp
  mexp_temp@annot_responsecurves$analysis_id[1] <- "unknown1"
  mexp_temp@annot_responsecurves$analysis_id[3] <- "unknown2"

  expect_warning(
    res <- get_response_curve_stats(mexp_temp),
    "absent from the dataset"
  )
  expect_s3_class(res, "tbl_df")
  # Curve B is intact; curve A lost 2 of its 6 points but is still fitted.
  expect_true(all(c("r2_rqc_A", "r2_rqc_B") %in% names(res)))
  expect_false(any(is.na(res$r2_rqc_B)))

  # silent_invalid_data suppresses the warning and still returns present series.
  expect_no_warning(
    res <- get_response_curve_stats(mexp_temp, silent_invalid_data = TRUE)
  )
  expect_s3_class(res, "tbl_df")

  # No matching series at all still aborts.
  mexp_temp2 <- mexp
  mexp_temp2@annot_responsecurves$analysis_id <-
    paste0("unknown_", seq_len(nrow(mexp_temp2@annot_responsecurves)))
  expect_error(
    get_response_curve_stats(mexp_temp2),
    "match the dataset"
  )

  mexp_temp <- mexp
  mexp_temp@dataset <- mexp_temp@dataset |>
    mutate(qc_type = if_else(qc_type == "RQC", "SPL", qc_type))

  expect_error(
    get_response_curve_stats(mexp_temp, limit_to_rqc = TRUE),
    "No analyses/samples of QC type \\`RQC"
  )

  # check error handler of lm
  mexp_temp <- mexp
  mexp_temp@annot_responsecurves$analyzed_amount[1:6] <- Inf

  res <- get_response_curve_stats(mexp_temp, limit_to_rqc = TRUE)
  expect_true(all(is.na(res$r2_rqc_A)))
  expect_false(any(is.na(res$r2_rqc_B)))
  expect_true(all(is.na(res$slopenorm_rqc_A)))
  expect_false(any(is.na(res$slopenorm_rqc_B)))
  expect_true(all(is.na(res$y0norm_rqc_A)))
  expect_false(any(is.na(res$y0norm_rqc_B)))
})

test_that("a single missing curve point does not void the curve fit", {
  rqc <- mexp@annot_responsecurves
  first_point <- rqc$analysis_id[rqc$curve_id == rqc$curve_id[1]][1]
  mexp_na <- mexp
  mexp_na@dataset$feature_intensity[
    mexp_na@dataset$analysis_id == first_point &
      mexp_na@dataset$feature_id == "PC 32:1"
  ] <- NA
  expect_warning(
    res <- get_response_curve_stats(mexp_na),
    "missing points"
  )
  r2_col <- paste0("r2_rqc_", rqc$curve_id[1])
  r2 <- res[[r2_col]][res$feature_id == "PC 32:1"]
  expect_false(is.na(r2))
  expect_gt(r2, 0.5)
})

test_that("a curve with fewer than 3 points present is not fitted", {
  rqc <- mexp@annot_responsecurves
  pts <- rqc$analysis_id[rqc$curve_id == rqc$curve_id[1]]
  mexp_na <- mexp
  mexp_na@dataset$feature_intensity[
    mexp_na@dataset$analysis_id %in%
      pts[-(1:2)] &
      mexp_na@dataset$feature_id == "PC 32:1"
  ] <- NA
  res <- suppressWarnings(get_response_curve_stats(mexp_na))
  r2_col <- paste0("r2_rqc_", rqc$curve_id[1])
  expect_true(is.na(res[[r2_col]][res$feature_id == "PC 32:1"]))
})

test_that("a curve missing its top point is scaled to the points present", {
  rqc <- mexp@annot_responsecurves
  crv <- rqc[rqc$curve_id == rqc$curve_id[1], ]
  top <- crv$analysis_id[which.max(crv$analyzed_amount)]
  mexp_na <- mexp
  sel <- mexp_na@dataset$feature_id == "PC 32:1"
  mexp_na@dataset$feature_intensity[
    sel & mexp_na@dataset$analysis_id == top
  ] <- NA
  res <- suppressWarnings(get_response_curve_stats(mexp_na))

  pts <- mexp_na@dataset[sel, c("analysis_id", "feature_intensity")] |>
    dplyr::inner_join(crv, by = "analysis_id") |>
    dplyr::filter(!is.na(.data$feature_intensity))
  fit <- lm(
    I(feature_intensity / max(feature_intensity)) ~
      I(analyzed_amount / max(analyzed_amount)),
    data = pts
  )
  slope_col <- paste0("slopenorm_rqc_", rqc$curve_id[1])
  expect_equal(
    res[[slope_col]][res$feature_id == "PC 32:1"],
    unname(coef(fit)[2])
  )
})

test_that("missing curve points are reported even with silent_invalid_data", {
  rqc <- mexp@annot_responsecurves
  mexp_na <- mexp
  mexp_na@dataset$feature_intensity[
    mexp_na@dataset$analysis_id == rqc$analysis_id[1] &
      mexp_na@dataset$feature_id == "PC 32:1"
  ] <- NA
  expect_warning(
    get_response_curve_stats(mexp_na, silent_invalid_data = TRUE),
    "missing points"
  )
})

rqc_curve_col <- function(stat) {
  paste0(stat, "_rqc_", mexp@annot_responsecurves$curve_id[1])
}
rqc_curve_pts <- function(m) {
  rqc <- m@annot_responsecurves
  m@dataset$feature_id == "PC 32:1" &
    m@dataset$analysis_id %in% rqc$analysis_id[rqc$curve_id == rqc$curve_id[1]]
}

test_that("a flat response curve has no R2", {
  m <- mexp
  m@dataset$feature_intensity[rqc_curve_pts(m)] <- 1000
  res <- get_response_curve_stats(m)
  row <- res$feature_id == "PC 32:1"
  expect_true(is.na(res[[rqc_curve_col("r2")]][row]))
  expect_equal(res[[rqc_curve_col("slopenorm")]][row], 0)
})

test_that("a response curve with equal amounts is not fitted", {
  m <- mexp
  rqc <- m@annot_responsecurves
  m@annot_responsecurves$analyzed_amount[rqc$curve_id == rqc$curve_id[1]] <- 5
  res <- get_response_curve_stats(m)
  expect_true(all(is.na(res[[rqc_curve_col("r2")]])))
  expect_true(all(is.na(res[[rqc_curve_col("slopenorm")]])))
})

test_that("an all-zero or all-missing response curve gives NA and keeps its row", {
  for (value in c(0, NA)) {
    m <- mexp
    m@dataset$feature_intensity[rqc_curve_pts(m)] <- value
    res <- get_response_curve_stats(m)
    expect_equal(nrow(res), 29)
    expect_true(is.na(res[[rqc_curve_col("r2")]][res$feature_id == "PC 32:1"]))
  }
})
