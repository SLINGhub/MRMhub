# library(testthat)
# library(dplyr)

mexp_orig <- lipidomics_dataset
mexp <- exclude_analyses(
  mexp_orig,
  analyses = "Longit_batch6_51",
  clear_existing = TRUE
)
mexp <- normalize_by_istd(mexp_orig)
mexp <- quantify_by_istd(mexp)
mexp_proc <- calc_qc_metrics(mexp, use_batch_medians = FALSE)


test_that("calc_qc_metrics column names and order are stable", {
  expect_snapshot(names(mexp_proc@metrics_qc))
  expect_snapshot(names(
    suppressMessages(calc_qc_metrics(mexp, use_batch_medians = TRUE))@metrics_qc
  ))
})

test_that("calc_qc_metrics works for all qc groups", {
  mexp_res <- calc_qc_metrics(mexp, use_batch_medians = FALSE)

  expect_s4_class(mexp_res, "MRMhubExperiment")
  expect_equal(dim(mexp_res@metrics_qc), c(29, 82))

  expect_equal(max(mexp_res@metrics_qc$product_mz), 829.4)
  expect_equal(min(mexp_res@metrics_qc$missing_intensity_prop_spl), 0)
  expect_equal(sum(mexp_res@metrics_qc$in_data), 29)
  expect_equal(sum(mexp_res@metrics_qc$is_quantifier), 28)
  expect_equal(sum(mexp_res@metrics_qc$is_istd), 9)
  expect_equal(sum(mexp_res@metrics_qc$valid_feature), 29)
  expect_equal(max(mexp_res@metrics_qc$collision_energy), 30)
  expect_equal(sum(mexp_res@metrics_qc$na_in_all), 0)
  expect_equal(max(mexp_res@metrics_qc$rt_median_spl), 7.311)
  expect_equal(max(mexp_res@metrics_qc$intensity_median_spl), 38240524)
  expect_equal(max(mexp_res@metrics_qc$intensity_min_spl), 3678267.3)
  expect_equal(max(mexp_res@metrics_qc$intensity_max_spl), 50621380.0)
  expect_equal(max(mexp_res@metrics_qc$intensity_cv_spl), 76.06928681)
  expect_equal(max(mexp_res@metrics_qc$intensity_cv_tqc), 30.1009462)
  expect_equal(max(mexp_res@metrics_qc$intensity_cv_bqc), 30.29650738)
  expect_equal(max(mexp_res@metrics_qc$norm_intensity_cv_spl), 103.7784475)
  expect_equal(max(mexp_res@metrics_qc$conc_cv_spl), 103.7784475)
  expect_equal(
    max(mexp_res@metrics_qc$norm_intensity_cv_tqc, na.rm = T),
    32.9608359974
  )
  expect_equal(max(mexp_res@metrics_qc$conc_cv_tqc, na.rm = T), 32.9608359974)
  expect_equal(
    max(mexp_res@metrics_qc$norm_intensity_cv_bqc, na.rm = T),
    31.93429867
  )
  expect_equal(max(mexp_res@metrics_qc$conc_cv_bqc, na.rm = T), 31.93429867)
  expect_equal(
    median(mexp_res@metrics_qc$conc_dratio_sd_bqc, na.rm = T),
    0.5136919558
  )
  expect_equal(
    median(mexp_res@metrics_qc$normint_dratio_sd_bqc, na.rm = T),
    0.5136919558
  )
  expect_equal(
    median(mexp_res@metrics_qc$conc_dratio_sd_tqc, na.rm = T),
    0.5077020488
  )
  expect_equal(
    median(mexp_res@metrics_qc$conc_dratio_mad_bqc, na.rm = T),
    0.6261527021
  )
  expect_equal(min(mexp_res@metrics_qc$r2_rqc_A), 0.91931047)
  expect_equal(min(mexp_res@metrics_qc$r2_rqc_B), 0.85693787)
  expect_equal(min(mexp_res@metrics_qc$slopenorm_rqc_A), 0.69281368)
  expect_equal(min(mexp_res@metrics_qc$slopenorm_rqc_B), 0.65001359)
})

test_that("na_in_all is scoped by the canonical QC-type list (regression)", {
  # The missing-value QC-type scope used to be a hardcoded subset that omitted
  # valid canonical types (e.g. "QC"). A feature whose only signal falls in such
  # a type must not be flagged all-missing. Relabel a few analyses to "QC" and
  # keep the feature's signal only there.
  feat <- unique(mexp@dataset$feature_id)[[1]]
  qc_ids <- unique(mexp@dataset$analysis_id[mexp@dataset$qc_type == "RQC"])[1:5]

  mexp_qc <- mexp
  ds <- mexp_qc@dataset
  ds$qc_type <- as.character(ds$qc_type)
  ds$qc_type[ds$analysis_id %in% qc_ids] <- "QC"
  ds$feature_intensity[ds$feature_id == feat] <- NA_real_
  ds$feature_intensity[
    ds$feature_id == feat & ds$analysis_id %in% qc_ids
  ] <- 1000
  mexp_qc@dataset <- ds

  res <- calc_qc_metrics(mexp_qc)
  expect_false(res@metrics_qc$na_in_all[res@metrics_qc$feature_id == feat])
})

test_that("calc_qc_metrics floors QC %CV below 3 replicates and surfaces it", {
  # Reduce TQC to 2 non-missing intensity replicates per feature: a %CV over
  # fewer than 3 values is not a meaningful precision estimate, so it must be
  # NA (it was a value before the floor) and the omission surfaced.
  tqc_keep <- mexp@dataset |>
    dplyr::filter(qc_type == "TQC") |>
    dplyr::distinct(analysis_id) |>
    dplyr::pull(analysis_id)
  tqc_keep <- tqc_keep[1:2]
  mexp_low <- mexp
  mexp_low@dataset <- mexp@dataset |>
    dplyr::mutate(
      feature_intensity = dplyr::if_else(
        qc_type == "TQC" & !(analysis_id %in% tqc_keep),
        NA_real_,
        feature_intensity
      )
    )

  expect_message(
    mexp_res <- calc_qc_metrics(mexp_low, use_batch_medians = FALSE),
    "%CV and D-ratio not computed"
  )
  # the floored QC type -> all NA
  expect_true(all(is.na(mexp_res@metrics_qc$intensity_cv_tqc)))
  # a well-replicated QC type is unaffected
  expect_false(all(is.na(mexp_res@metrics_qc$intensity_cv_spl)))
  # only feature_intensity was reduced, so the norm-intensity CV still computes
  expect_false(all(is.na(mexp_res@metrics_qc$norm_intensity_cv_tqc)))
})

test_that("calc_qc_metrics batch-wise works for all qc groups", {
  mexp_res <- calc_qc_metrics(mexp, use_batch_medians = TRUE)

  expect_s4_class(mexp_res, "MRMhubExperiment")
  expect_equal(dim(mexp_res@metrics_qc), c(29, 82))

  expect_equal(max(mexp_res@metrics_qc$product_mz), 829.4)
  expect_equal(min(mexp_res@metrics_qc$missing_intensity_prop_spl), 0)
  expect_equal(sum(mexp_res@metrics_qc$in_data), 29)
  expect_equal(sum(mexp_res@metrics_qc$is_quantifier), 28)
  expect_equal(sum(mexp_res@metrics_qc$is_istd), 9)
  expect_equal(sum(mexp_res@metrics_qc$valid_feature), 29)
  expect_equal(max(mexp_res@metrics_qc$collision_energy), 30)
  expect_equal(sum(mexp_res@metrics_qc$na_in_all), 0)
  expect_equal(max(mexp_res@metrics_qc$rt_median_spl), 7.311)
  expect_equal(max(mexp_res@metrics_qc$intensity_median_spl), 37547322)
  expect_equal(max(mexp_res@metrics_qc$intensity_min_spl), 25756142)
  expect_equal(max(mexp_res@metrics_qc$intensity_max_spl), 45840582)
  expect_equal(max(mexp_res@metrics_qc$intensity_cv_spl), 71.0697513)
  expect_equal(max(mexp_res@metrics_qc$intensity_cv_tqc), 20.4880956525)
  expect_equal(max(mexp_res@metrics_qc$intensity_cv_bqc), 16.3277340356)
  expect_equal(max(mexp_res@metrics_qc$norm_intensity_cv_spl), 96.9355336955)
  expect_equal(max(mexp_res@metrics_qc$conc_cv_spl), 96.9355336955)
  expect_equal(max(mexp_res@metrics_qc$norm_intensity_cv_tqc), 22.8694786877)
  expect_equal(max(mexp_res@metrics_qc$conc_cv_tqc), 22.8694786877)
  expect_equal(max(mexp_res@metrics_qc$norm_intensity_cv_bqc), 16.64318769)
  expect_equal(max(mexp_res@metrics_qc$conc_cv_bqc), 16.64318769)
  expect_equal(
    median(mexp_res@metrics_qc$conc_dratio_sd_bqc, na.rm = T),
    0.3984480619
  )
  expect_equal(
    median(mexp_res@metrics_qc$normint_dratio_sd_bqc, na.rm = T),
    0.3984480619
  )
  expect_equal(
    median(mexp_res@metrics_qc$conc_dratio_sd_tqc, na.rm = T),
    0.4245940972
  )
  expect_equal(
    median(mexp_res@metrics_qc$conc_dratio_mad_bqc, na.rm = T),
    0.4060582407
  )
  expect_equal(min(mexp_res@metrics_qc$r2_rqc_A), 0.91931047)
  expect_equal(min(mexp_res@metrics_qc$r2_rqc_B), 0.85693787)
  expect_equal(min(mexp_res@metrics_qc$slopenorm_rqc_A), 0.69281368)
  expect_equal(min(mexp_res@metrics_qc$slopenorm_rqc_B), 0.65001359)
})

test_that("calc_qc_metrics batch-wise works for with calibration metrics ", {
  mexp_quant <- quant_lcms_dataset
  mexp_quant_norm <- normalize_by_istd(mexp_quant)
  mexp_quant_norm <- calc_calibration_results(
    mexp_quant_norm,
    fit_overwrite = FALSE,
    fit_model = "quadratic",
    fit_weighting = "1/x"
  )

  mexp_res <- calc_qc_metrics(
    mexp_quant_norm,
    use_batch_medians = TRUE,
    include_norm_intensity_stats = FALSE,
    include_conc_stats = FALSE,
    include_response_stats = FALSE,
    include_calibration_results = TRUE
  )

  expect_true(all(
    c("fit_model", "fit_weighting", "reg_failed_cal", "r2_cal") %in%
      names(mexp_res@metrics_qc)
  ))
})


test_that("calc_qc_metrics batch-wise works for all with all incl FALSE ", {
  mexp_res <- calc_qc_metrics(
    mexp,
    use_batch_medians = TRUE,
    include_norm_intensity_stats = FALSE,
    include_conc_stats = FALSE,
    include_response_stats = FALSE,
    include_calibration_results = FALSE
  )

  expect_s4_class(mexp_res, "MRMhubExperiment")
  expect_equal(dim(mexp_res@metrics_qc), c(29, 53))

  expect_false("norm_intensity_cv_spl" %in% colnames(mexp_res@metrics_qc))
  expect_false("conc_cv_spl" %in% colnames(mexp_res@metrics_qc))
  expect_false("r2_rqc_A" %in% colnames(mexp_res@metrics_qc))
  expect_false("fit_model" %in% colnames(mexp_res@metrics_qc))
})

test_that("calc_qc_metrics batch-wise works for all with all incl FALSE across batches ", {
  mexp_res <- calc_qc_metrics(
    mexp,
    use_batch_medians = FALSE,
    include_norm_intensity_stats = FALSE,
    include_conc_stats = FALSE,
    include_response_stats = FALSE,
    include_calibration_results = FALSE
  )

  expect_equal(dim(mexp_res@metrics_qc), c(29, 53))

  expect_false("norm_intensity_cv_spl" %in% colnames(mexp_res@metrics_qc))
  expect_false("conc_cv_spl" %in% colnames(mexp_res@metrics_qc))
  expect_false("r2_rqc_A" %in% colnames(mexp_res@metrics_qc))
  expect_false("fit_model" %in% colnames(mexp_res@metrics_qc))
})

test_that("calc_qc_metrics batch-wise works for some incl FALSE ", {
  mexp_res <- calc_qc_metrics(
    mexp,
    use_batch_medians = TRUE,
    include_norm_intensity_stats = TRUE,
    include_conc_stats = FALSE,
    include_response_stats = TRUE,
    include_calibration_results = FALSE
  )
  expect_equal(dim(mexp_res@metrics_qc), c(29, 68))

  expect_true("norm_intensity_cv_spl" %in% colnames(mexp_res@metrics_qc))
  expect_false("conc_cv_spl" %in% colnames(mexp_res@metrics_qc))
  expect_true("r2_rqc_A" %in% colnames(mexp_res@metrics_qc))
  expect_false("fit_model" %in% colnames(mexp_res@metrics_qc))
})

test_that("calc_qc_metrics batch-wise works for some other incl FALSE ", {
  mexp_res <- calc_qc_metrics(
    mexp,
    use_batch_medians = TRUE,
    include_norm_intensity_stats = FALSE,
    include_conc_stats = TRUE,
    include_response_stats = TRUE,
    include_calibration_results = FALSE
  )
  expect_equal(dim(mexp_res@metrics_qc), c(29, 73))

  expect_false("norm_intensity_cv_spl" %in% colnames(mexp_res@metrics_qc))
  expect_true("conc_cv_spl" %in% colnames(mexp_res@metrics_qc))
  expect_true("r2_rqc_A" %in% colnames(mexp_res@metrics_qc))
  expect_false("fit_model" %in% colnames(mexp_res@metrics_qc))
})


test_that("calc_qc_metrics batch-wise works at different processing status ", {
  mexp_temp <- mexp
  mexp_temp@dataset$feature_conc <- NULL
  mexp_temp@dataset$feature_norm_intensity <- NULL
  # delete all rows of tibble below

  #mexp_temp@annot_responsecurves <- mexp_temp@annot_responsecurves[0,]
  mexp_res <- calc_qc_metrics(mexp_temp, use_batch_medians = TRUE)
  expect_equal(dim(mexp_res@metrics_qc), c(29, 59))
  expect_false("norm_intensity_cv_spl" %in% colnames(mexp_res@metrics_qc))
  expect_false("conc_cv_spl" %in% colnames(mexp_res@metrics_qc))
})

test_that("calc_qc_metrics no method data works", {
  mexp_temp <- mexp
  mexp_temp@dataset_orig$method_precursor_mz <- NULL
  mexp_temp@dataset_orig$method_product_mz <- NULL
  mexp_temp@dataset_orig$method_collision_energy <- NULL

  #mexp_temp@annot_responsecurves <- mexp_temp@annot_responsecurves[0,]
  mexp_res <- calc_qc_metrics(mexp_temp, use_batch_medians = TRUE)
  expect_true(all(is.na(mexp_res@metrics_qc$precursor_mz)))
  expect_type(mexp_res@metrics_qc$precursor_mz, "double")
})

test_that("calc_qc_metrics warns on inconsistent method values, ignores NA", {
  mexp_temp <- mexp
  ids <- unique(mexp_temp@dataset_orig$feature_id)[1:2]
  i <- which(mexp_temp@dataset_orig$feature_id == ids[1])[1]
  j <- which(mexp_temp@dataset_orig$feature_id == ids[2])[1]
  mz_ok <- mexp_temp@dataset_orig$method_precursor_mz[j]
  mexp_temp@dataset_orig$method_product_mz[i] <-
    mexp_temp@dataset_orig$method_product_mz[i] + 1
  mexp_temp@dataset_orig$method_precursor_mz[j] <- NA

  expect_warning(
    mexp_res <- calc_qc_metrics(mexp_temp, use_batch_medians = FALSE),
    "differ between analyses"
  )
  m <- mexp_res@metrics_qc
  expect_true(is.na(m$product_mz[m$feature_id == ids[1]]))
  expect_equal(m$precursor_mz[m$feature_id == ids[2]], mz_ok)
  expect_equal(nrow(m), 29)
})

test_that("calc_qc_metrics batch-wise raise error correctly when data missing ", {
  mexp_temp <- mexp
  mexp_temp@dataset$feature_norm_intensity <- NULL
  mexp_temp@dataset$feature_conc <- NULL
  # delete all rows of tibble below

  #mexp_temp@annot_responsecurves <- mexp_temp@annot_responsecurves[0,]
  expect_error(
    calc_qc_metrics(
      mexp_temp,
      use_batch_medians = TRUE,
      include_norm_intensity_stats = TRUE,
      include_conc_stats = TRUE,
      include_response_stats = TRUE,
      include_calibration_results = TRUE
    ),
    "Normalized intensity data is missing"
  )

  expect_error(
    calc_qc_metrics(
      mexp_temp,
      use_batch_medians = TRUE,
      include_norm_intensity_stats = NA,
      include_conc_stats = TRUE,
      include_response_stats = TRUE,
      include_calibration_results = TRUE
    ),
    "Concentration data is missing"
  )

  mexp_temp@is_istd_normalized <- TRUE
  expect_error(
    calc_qc_metrics(
      mexp_temp,
      use_batch_medians = TRUE,
      include_norm_intensity_stats = FALSE,
      include_conc_stats = TRUE,
      include_response_stats = TRUE,
      include_calibration_results = TRUE
    ),
    "Concentration data is missing"
  )

  expect_error(
    calc_qc_metrics(
      mexp_temp,
      use_batch_medians = TRUE,
      include_norm_intensity_stats = FALSE,
      include_conc_stats = TRUE,
      include_response_stats = TRUE,
      include_calibration_results = TRUE
    ),
    "Concentration data is missing"
  )

  mexp_temp@is_istd_normalized <- FALSE
  mexp_temp@is_quantitated <- TRUE

  expect_error(
    calc_qc_metrics(
      mexp_temp,
      use_batch_medians = TRUE,
      include_norm_intensity_stats = TRUE,
      include_conc_stats = TRUE,
      include_response_stats = TRUE,
      include_calibration_results = TRUE
    ),
    "Normalized intensity data is missing"
  )
})

test_that("calc_qc_metrics handles missing/missmatching info for response curve stats ", {
  mexp_temp <- mexp
  mexp_temp@annot_responsecurves <- mexp_temp@annot_responsecurves[0, ]

  expect_s4_class(
    calc_qc_metrics(
      mexp_temp,
      use_batch_medians = TRUE,
      include_norm_intensity_stats = TRUE,
      include_conc_stats = TRUE,
      include_response_stats = NA,
      include_calibration_results = NA
    ),
    "MRMhubExperiment"
  )

  expect_error(
    calc_qc_metrics(
      mexp_temp,
      use_batch_medians = TRUE,
      include_norm_intensity_stats = TRUE,
      include_conc_stats = TRUE,
      include_response_stats = TRUE,
      include_calibration_results = FALSE
    ),
    "No response curve metadata found"
  )

  expect_error(
    calc_qc_metrics(
      mexp_temp,
      use_batch_medians = TRUE,
      include_norm_intensity_stats = TRUE,
      include_conc_stats = TRUE,
      include_response_stats = FALSE,
      include_calibration_results = TRUE
    ),
    "Calibration metrics are missing"
  )

  mexp_temp <- mexp
  mexp_temp@annot_responsecurves$analysis_id[1] <- "unknown1"
  mexp_temp@annot_responsecurves$analysis_id[3] <- "unknown2"

  expect_s4_class(
    calc_qc_metrics(
      mexp_temp,
      use_batch_medians = TRUE,
      include_norm_intensity_stats = TRUE,
      include_conc_stats = TRUE,
      include_response_stats = NA,
      include_calibration_results = NA
    ),
    "MRMhubExperiment"
  )

  # A partly-mismatched response-curve series warns and computes present-series
  # metrics rather than aborting the whole QC metric calculation.
  expect_warning(
    mexp_resp <- calc_qc_metrics(
      mexp_temp,
      use_batch_medians = TRUE,
      include_norm_intensity_stats = TRUE,
      include_conc_stats = TRUE,
      include_response_stats = TRUE,
      include_calibration_results = NA
    ),
    "absent from the dataset"
  )
  expect_s4_class(mexp_resp, "MRMhubExperiment")
  expect_true("r2_rqc_B" %in% names(mexp_resp@metrics_qc))
})

test_that("filter_features_qc adds no rows for metadata-only features", {
  mexp_temp <- mexp
  extra <- mexp_temp@annot_features[1, ]
  extra$feature_id <- "Metadata only"
  mexp_temp@annot_features <- dplyr::bind_rows(mexp_temp@annot_features, extra)
  mexp_temp <- calc_qc_metrics(mexp_temp, use_batch_medians = FALSE)
  mexp_res <- suppressMessages(
    filter_features_qc(mexp_temp, include_qualifier = TRUE, include_istd = TRUE)
  )
  expect_false("Metadata only" %in% mexp_res@dataset_filtered$feature_id)
  expect_false(anyNA(mexp_res@dataset_filtered$analysis_id))
  expect_equal(nrow(mexp_res@dataset_filtered), nrow(mexp_res@dataset))
})

test_that("filter_features_qc works with istd and qualifier subsetting", {
  expect_message(
    mexp_res <- filter_features_qc(
      mexp_proc,
      clear_existing = TRUE,
      include_qualifier = FALSE,
      include_istd = FALSE,
      min.intensity.median.bqc = 0
    ),
    "19 of 19 quantifier features meet QC criteria \\(not including the 9 quantifier ISTD features\\)"
  )
  expect_equal(length(unique(mexp_res@dataset_filtered$feature_id)), 19)

  expect_message(
    mexp_res <- filter_features_qc(
      mexp_proc,
      clear_existing = TRUE,
      include_qualifier = TRUE,
      include_istd = FALSE,
      min.intensity.median.bqc = 0
    ),
    "19 of 19 quantifier and 1 of 1 qualifier features meet QC criteria \\(not including the 9 quantifier and 0 qualifier ISTD features\\)"
  )
  expect_equal(length(unique(mexp_res@dataset_filtered$feature_id)), 20)

  expect_message(
    mexp_res <- filter_features_qc(
      mexp_proc,
      clear_existing = TRUE,
      include_qualifier = FALSE,
      include_istd = TRUE,
      min.intensity.median.bqc = 0
    ),
    "28 of 28 quantifier features meet QC criteria \\(including the 9 quantifier ISTD features\\)"
  )
  expect_equal(length(unique(mexp_res@dataset_filtered$feature_id)), 28)

  expect_message(
    mexp_res <- filter_features_qc(
      mexp_proc,
      clear_existing = TRUE,
      include_qualifier = TRUE,
      include_istd = TRUE,
      min.intensity.median.bqc = 0
    ),
    "28 of 28 quantifier and 1 of 1 qualifier features meet QC criteria \\(including the 9 quantifier and 0 qualifier ISTD features\\)"
  )
  expect_equal(length(unique(mexp_res@dataset_filtered$feature_id)), 29)
})


# Regression: the S/B ratio is computed against the process blank (PBLK), into
# which ISTDs are spiked, so an ISTD's S/B-vs-PBLK is ~1 by construction. When
# the user keeps ISTDs (`include_istd = TRUE`), a PBLK-based S/B threshold must
# not exclude them. Operator precedence had made the exemption fire only for
# `include_istd = FALSE` (where ISTDs are already removed), so every kept ISTD
# was wrongly dropped by the S/B filter.
test_that("ISTDs are exempt from the S/B filter when kept (include_istd = TRUE)", {
  istd_ids <- mexp_proc@metrics_qc |>
    dplyr::filter(.data$is_istd) |>
    dplyr::pull(.data$feature_id)
  # a non-ISTD below the same threshold, to guard against over-exemption
  low_sb_quant <- mexp_proc@metrics_qc |>
    dplyr::filter(!.data$is_istd, .data$sb_ratio_pblk < 100) |>
    dplyr::pull(.data$feature_id)
  expect_gt(length(low_sb_quant), 0)

  mexp_res <- filter_features_qc(
    mexp_proc,
    clear_existing = TRUE,
    include_qualifier = FALSE,
    include_istd = TRUE,
    min.signalblank.median.spl.pblk = 100
  )
  kept <- unique(mexp_res@dataset_filtered$feature_id)

  # every kept ISTD survives the S/B filter ...
  expect_true(all(istd_ids %in% kept))
  expect_equal(sum(istd_ids %in% kept), 9L)
  # ... while non-ISTDs below the threshold are still dropped
  expect_false(any(low_sb_quant %in% kept))
})


test_that("filter_features_qc works on selected criteria", {
  mexp_res <- filter_features_qc(
    mexp_proc,
    clear_existing = TRUE,
    include_qualifier = FALSE,
    include_istd = FALSE,
    min.intensity.median.bqc = 1E5
  )
  expect_equal(length(unique(mexp_res@dataset_filtered$feature_id)), 16)

  mexp_res <- filter_features_qc(
    mexp_proc,
    clear_existing = TRUE,
    include_qualifier = FALSE,
    include_istd = FALSE,
    min.intensity.median.tqc = 1E5
  )
  expect_equal(length(unique(mexp_res@dataset_filtered$feature_id)), 16)

  mexp_res <- filter_features_qc(
    mexp_proc,
    clear_existing = TRUE,
    include_qualifier = FALSE,
    include_istd = FALSE,
    min.intensity.median.bqc = 1E5,
    min.intensity.median.tqc = 1E5
  )
  expect_equal(length(unique(mexp_res@dataset_filtered$feature_id)), 16)

  mexp_res <- filter_features_qc(
    mexp_proc,
    clear_existing = TRUE,
    include_qualifier = FALSE,
    include_istd = FALSE,
    min.signalblank.median.spl.pblk = 100
  )
  expect_equal(length(unique(mexp_res@dataset_filtered$feature_id)), 12)

  mexp_res <- filter_features_qc(
    mexp_proc,
    clear_existing = TRUE,
    include_qualifier = FALSE,
    include_istd = FALSE,
    min.intensity.median.bqc = 1E5,
    min.signalblank.median.spl.pblk = 100
  )
  expect_equal(length(unique(mexp_res@dataset_filtered$feature_id)), 10)

  mexp_res <- filter_features_qc(
    mexp_proc,
    clear_existing = TRUE,
    include_qualifier = FALSE,
    include_istd = FALSE,
    max.cv.conc.bqc = 20
  )
  expect_equal(length(unique(mexp_res@dataset_filtered$feature_id)), 18)

  mexp_res <- filter_features_qc(
    mexp_proc,
    clear_existing = TRUE,
    include_qualifier = FALSE,
    include_istd = FALSE,
    min.signalblank.median.spl.pblk = 100,
    max.cv.conc.bqc = 20
  )
  expect_equal(length(unique(mexp_res@dataset_filtered$feature_id)), 11)

  mexp_res <- filter_features_qc(
    mexp_proc,
    clear_existing = TRUE,
    include_qualifier = FALSE,
    include_istd = FALSE,
    min.signalblank.median.spl.pblk = 100,
    max.cv.normintensity.bqc = 20
  )
  expect_equal(length(unique(mexp_res@dataset_filtered$feature_id)), 11)

  mexp_res <- filter_features_qc(
    mexp_proc,
    clear_existing = TRUE,
    include_qualifier = FALSE,
    include_istd = FALSE,
    max.dratio.sd.conc.bqc = 0.5
  )
  expect_equal(length(unique(mexp_res@dataset_filtered$feature_id)), 10)

  mexp_res <- filter_features_qc(
    mexp_proc,
    clear_existing = TRUE,
    include_qualifier = FALSE,
    include_istd = FALSE,
    max.prop.missing.conc.spl = 0
  )
  expect_equal(length(unique(mexp_res@dataset_filtered$feature_id)), 19)

  mexp_res <- filter_features_qc(
    mexp_proc,
    clear_existing = TRUE,
    include_qualifier = FALSE,
    include_istd = FALSE,
    response.curves.selection = 1,
    response.curves.summary = "mean",
    min.rsquare.response = 0.98
  )
  expect_equal(length(unique(mexp_res@dataset_filtered$feature_id)), 8)

  mexp_res <- filter_features_qc(
    mexp_proc,
    clear_existing = TRUE,
    include_qualifier = FALSE,
    include_istd = FALSE,
    response.curves.selection = 2,
    response.curves.summary = "mean",
    min.rsquare.response = 0.98
  )
  expect_equal(length(unique(mexp_res@dataset_filtered$feature_id)), 9)

  mexp_res <- filter_features_qc(
    mexp_proc,
    clear_existing = TRUE,
    include_qualifier = FALSE,
    include_istd = FALSE,
    response.curves.selection = c(1, 2),
    response.curves.summary = "mean",
    min.rsquare.response = 0.98
  )
  expect_equal(length(unique(mexp_res@dataset_filtered$feature_id)), 6)

  mexp_res <- filter_features_qc(
    mexp_proc,
    clear_existing = TRUE,
    include_qualifier = FALSE,
    include_istd = FALSE,
    response.curves.selection = c("A", "B"),
    response.curves.summary = "mean",
    min.rsquare.response = 0.98
  )
  expect_equal(length(unique(mexp_res@dataset_filtered$feature_id)), 6)

  mexp_res <- filter_features_qc(
    mexp_proc,
    clear_existing = TRUE,
    include_qualifier = FALSE,
    include_istd = FALSE,
    response.curves.selection = c(1, 2),
    response.curves.summary = "median",
    min.rsquare.response = 0.98
  )
  expect_equal(length(unique(mexp_res@dataset_filtered$feature_id)), 6)

  mexp_res <- filter_features_qc(
    mexp_proc,
    clear_existing = TRUE,
    include_qualifier = FALSE,
    include_istd = FALSE,
    response.curves.selection = c(1, 2),
    response.curves.summary = "best",
    min.rsquare.response = 0.98
  )
  expect_equal(length(unique(mexp_res@dataset_filtered$feature_id)), 12)

  mexp_res <- filter_features_qc(
    mexp_proc,
    clear_existing = TRUE,
    include_qualifier = FALSE,
    include_istd = FALSE,
    response.curves.selection = c(1, 2),
    response.curves.summary = "worst",
    min.rsquare.response = 0.98
  )
  expect_equal(length(unique(mexp_res@dataset_filtered$feature_id)), 5)

  mexp_res <- filter_features_qc(
    mexp_proc,
    clear_existing = TRUE,
    include_qualifier = FALSE,
    include_istd = FALSE,
    response.curves.selection = c(1, 2),
    response.curves.summary = "mean",
    min.slope.response = 0.9
  )
  expect_equal(length(unique(mexp_res@dataset_filtered$feature_id)), 11)

  mexp_res <- filter_features_qc(
    mexp_proc,
    clear_existing = TRUE,
    include_qualifier = FALSE,
    include_istd = FALSE,
    response.curves.selection = c(1, 2),
    response.curves.summary = "worst",
    min.slope.response = 0.9
  )
  expect_equal(length(unique(mexp_res@dataset_filtered$feature_id)), 9)

  mexp_res <- filter_features_qc(
    mexp_proc,
    clear_existing = TRUE,
    include_qualifier = FALSE,
    include_istd = FALSE,
    response.curves.selection = c(1, 2),
    response.curves.summary = "best",
    max.slope.response = 1.005
  )
  expect_equal(length(unique(mexp_res@dataset_filtered$feature_id)), 17)

  mexp_res <- filter_features_qc(
    mexp_proc,
    clear_existing = TRUE,
    include_qualifier = FALSE,
    include_istd = FALSE,
    response.curves.selection = c(1, 2),
    response.curves.summary = "worst",
    max.slope.response = 1.005
  )
  expect_equal(length(unique(mexp_res@dataset_filtered$feature_id)), 12)
})


# Regression: selecting one response curve leaves `response.curves.summary` at its
# NA default, because only the multi-curve branch requires it. `switch(NA, ...)`
# returns NULL rather than its default arm, which used to crash the filter.
test_that("response filtering works for one curve without an explicit summary", {
  mexp_res <- filter_features_qc(
    mexp_proc,
    clear_existing = TRUE,
    include_qualifier = FALSE,
    include_istd = FALSE,
    response.curves.selection = 1,
    min.rsquare.response = 0.98
  )

  # a single curve has nothing to summarize across, so the result must match the
  # same call made with the summary spelled out (the sibling test above pins 8)
  mexp_explicit <- filter_features_qc(
    mexp_proc,
    clear_existing = TRUE,
    include_qualifier = FALSE,
    include_istd = FALSE,
    response.curves.selection = 1,
    response.curves.summary = "mean",
    min.rsquare.response = 0.98
  )

  expect_equal(length(unique(mexp_res@dataset_filtered$feature_id)), 8)
  expect_equal(mexp_res@dataset_filtered, mexp_explicit@dataset_filtered)
})


# `response.curves.summary` is consumed by a `switch()` on every path, so it must
# be validated on every path. It previously was not for a single curve, and an
# unrecognized value became a bogus function name that crashed further down.
test_that("an invalid response.curves.summary is rejected for one curve too", {
  expect_error(
    filter_features_qc(
      mexp_proc,
      clear_existing = TRUE,
      include_qualifier = FALSE,
      include_istd = FALSE,
      response.curves.selection = 1,
      response.curves.summary = "meen",
      min.rsquare.response = 0.98
    ),
    # the arg_match message, not merely "meen": the unvalidated value also errored
    # before this fix, but as a cryptic `meen()` not-found deep inside pmap_dbl.
    # `\\s+` absorbs the line break cli inserts.
    regexp = "must\\s+be\\s+one\\s+of"
  )
})


# Regression: a min-intensity filter enabled on a clear_existing = FALSE
# re-run, when it was not enabled in the previous run, used to be silently
# discarded (the previous, disabled state was restored). It must now apply.
test_that("Min-intensity filter applies on clear_existing = FALSE re-run (regression)", {
  thr <- 5e5
  fresh <- filter_features_qc(
    mexp_proc,
    clear_existing = TRUE,
    include_qualifier = TRUE,
    include_istd = FALSE,
    min.intensity.median.spl = thr
  )
  run1 <- filter_features_qc(
    mexp_proc,
    clear_existing = TRUE,
    include_qualifier = TRUE,
    include_istd = FALSE
  )
  reconciled <- filter_features_qc(
    run1,
    clear_existing = FALSE,
    include_qualifier = TRUE,
    include_istd = FALSE,
    min.intensity.median.spl = thr
  )

  # the min-intensity filter must fail some features in a fresh run ...
  expect_gt(sum(!fresh@metrics_qc$pass_minint, na.rm = TRUE), 0)
  # ... and the reconciled re-run must apply it identically (not revert it)
  expect_true(all(reconciled@metrics_qc$filter_minint))
  expect_equal(
    sort(reconciled@metrics_qc$pass_minint),
    sort(fresh@metrics_qc$pass_minint)
  )
})


test_that("ISTDs get no S/B verdict when no S/B criterion is set", {
  mexp_res <- filter_features_qc(
    mexp_proc,
    include_qualifier = FALSE,
    include_istd = TRUE,
    max.cv.conc.bqc = 20
  )
  expect_equal(unique(mexp_res@metrics_qc$pass_sb), NA)
})


test_that("a feature without response-curve results fails linearity, ISTDs excepted", {
  m <- mexp_proc@metrics_qc
  ids <- c(m$feature_id[!m$is_istd][1], m$feature_id[m$is_istd][1])
  mexp_na <- mexp_proc
  mexp_na@metrics_qc <- m |>
    dplyr::mutate(dplyr::across(
      dplyr::contains("_rqc_"),
      \(x) dplyr::if_else(.data$feature_id %in% ids, NA, x)
    ))

  expect_message(
    mexp_res <- filter_features_qc(
      mexp_na,
      include_qualifier = FALSE,
      include_istd = TRUE,
      response.curves.selection = 1,
      min.rsquare.response = 0.5
    ),
    ids[1],
    fixed = TRUE
  )
  pass <- rlang::set_names(
    mexp_res@metrics_qc$pass_linearity,
    mexp_res@metrics_qc$feature_id
  )
  expect_identical(pass[[ids[1]]], FALSE)
  expect_identical(pass[[ids[2]]], NA)
})


test_that("chained filter steps accumulate CV, linearity and S/B criteria", {
  step1 <- filter_features_qc(
    mexp,
    max.cv.conc.bqc = 20,
    include_qualifier = FALSE,
    include_istd = FALSE
  )
  step2 <- filter_features_qc(
    step1,
    clear_existing = FALSE,
    include_qualifier = FALSE,
    include_istd = FALSE,
    response.curves.selection = 1,
    min.rsquare.response = 0.95
  )
  step3 <- filter_features_qc(
    step2,
    clear_existing = FALSE,
    include_qualifier = FALSE,
    include_istd = FALSE,
    min.signalblank.median.spl.pblk = 10
  )

  m <- step3@metrics_qc
  expect_equal(unique(m$filter_cva), TRUE)
  expect_equal(unique(m$filter_linearity), TRUE)
  expect_equal(unique(m$filter_sb), TRUE)
  expect_equal(m$pass_cva, step1@metrics_qc$pass_cva)
  expect_equal(m$pass_linearity, step2@metrics_qc$pass_linearity)
  expect_lt(sum(m$all_filter_pass), sum(step1@metrics_qc$all_filter_pass))
})


test_that("filter_features_qc keeps the CV settings of stored metrics unless asked", {
  robust <- calc_qc_metrics(mexp, use_robust_cv = TRUE)
  mexp_res <- filter_features_qc(
    robust,
    max.cv.conc.bqc = 20,
    include_qualifier = FALSE,
    include_istd = FALSE
  )
  expect_equal(mexp_res@metrics_qc$conc_cv_bqc, robust@metrics_qc$conc_cv_bqc)

  expect_message(
    mexp_res <- filter_features_qc(
      mexp_proc,
      use_robust_cv = TRUE,
      include_qualifier = FALSE,
      include_istd = FALSE,
      max.cv.conc.bqc = 20
    ),
    "recalculated"
  )
  expect_equal(mexp_res@metrics_qc$conc_cv_bqc, robust@metrics_qc$conc_cv_bqc)
})


test_that("calc_qc_metrics leaves the feature classes unchanged", {
  mexp_res <- calc_qc_metrics(mexp)
  expect_equal(mexp_res@dataset, mexp@dataset)
})


test_that("S/B treats an undetected blank as zero and passes the feature", {
  ids <- mexp_proc@metrics_qc |>
    dplyr::filter(!.data$is_istd) |>
    dplyr::pull(.data$feature_id)
  pblk_ids <- mexp@dataset |>
    dplyr::filter(.data$qc_type == "PBLK") |>
    dplyr::distinct(.data$analysis_id) |>
    dplyr::pull()
  mexp_blk <- mexp
  mexp_blk@dataset <- mexp_blk@dataset |>
    dplyr::mutate(
      feature_intensity = dplyr::case_when(
        # not detected in any PBLK
        .data$feature_id == ids[1] & .data$qc_type == "PBLK" ~ NA,
        # detected in only one of the three PBLKs
        .data$feature_id == ids[2] &
          .data$analysis_id %in% pblk_ids[-1] ~
          NA,
        # blank reported as zero
        .data$feature_id == ids[3] & .data$qc_type == "PBLK" ~ 0,
        # not detected in the study samples either
        .data$feature_id == ids[4] &
          .data$qc_type %in% c("PBLK", "SPL") ~
          NA,
        .default = .data$feature_intensity
      )
    )
  mexp_blk <- calc_qc_metrics(mexp_blk)
  sb <- rlang::set_names(
    mexp_blk@metrics_qc$sb_ratio_pblk,
    mexp_blk@metrics_qc$feature_id
  )
  expect_equal(unname(sb[ids[1:3]]), rep(Inf, 3))
  expect_identical(sb[[ids[4]]], NA_real_)

  mexp_res <- filter_features_qc(
    mexp_blk,
    include_qualifier = FALSE,
    include_istd = FALSE,
    min.signalblank.median.spl.pblk = 10
  )
  pass <- rlang::set_names(
    mexp_res@metrics_qc$pass_sb,
    mexp_res@metrics_qc$feature_id
  )
  expect_equal(unname(pass[ids[1:4]]), c(TRUE, TRUE, TRUE, FALSE))
})


test_that("an S/B criterion for a blank type absent from the data aborts", {
  ublk_ids <- mexp@annot_analyses$analysis_id[
    mexp@annot_analyses$qc_type == "UBLK"
  ]
  mexp_noublk <- exclude_analyses(mexp, ublk_ids, clear_existing = TRUE)
  expect_error(
    filter_features_qc(
      mexp_noublk,
      include_qualifier = FALSE,
      include_istd = FALSE,
      min.signalblank.median.spl.ublk = 10
    ),
    "No UBLK analyses"
  )
})


test_that("D-ratios need 3 replicates and a non-zero spread", {
  ids <- mexp_proc@metrics_qc |>
    dplyr::filter(!.data$is_istd) |>
    dplyr::pull(.data$feature_id)
  bqc_ids <- mexp@dataset |>
    dplyr::filter(.data$qc_type == "BQC") |>
    dplyr::distinct(.data$analysis_id) |>
    dplyr::pull()
  mexp_dr <- mexp
  mexp_dr@dataset <- mexp_dr@dataset |>
    dplyr::mutate(
      feature_conc = dplyr::case_when(
        # only two BQC replicates
        .data$feature_id == ids[1] & .data$analysis_id %in% bqc_ids[-(1:2)] ~
          NA,
        # identical BQC values: zero spread
        .data$feature_id == ids[2] & .data$qc_type == "BQC" ~ 1,
        .default = .data$feature_conc
      ),
      feature_intensity = dplyr::if_else(
        .data$feature_id == ids[1] & .data$analysis_id %in% bqc_ids[-(1:2)],
        NA,
        .data$feature_intensity
      )
    )
  expect_message(
    mexp_dr <- calc_qc_metrics(mexp_dr),
    "D-ratio not computed"
  )
  m <- mexp_dr@metrics_qc |> dplyr::filter(.data$feature_id %in% ids[1:3])
  expect_equal(m$n_bqc, c(2, length(bqc_ids), length(bqc_ids)))
  expect_equal(is.na(m$conc_dratio_sd_bqc), c(TRUE, TRUE, FALSE))
  expect_equal(is.na(m$conc_dratio_mad_bqc), c(TRUE, TRUE, FALSE))
})


# Confirm overwriting of QC criteria works

test_that("Confirm overwriting of QC criteria works", {
  mexp_res <- filter_features_qc(
    mexp_proc,
    clear_existing = FALSE,
    include_qualifier = FALSE,
    include_istd = FALSE,
    min.signalblank.median.spl.pblk = 300
  )

  expect_equal(length(unique(mexp_res@dataset_filtered$feature_id)), 9)

  expect_message(
    mexp_res <- filter_features_qc(
      mexp_res,
      clear_existing = FALSE,
      include_qualifier = FALSE,
      include_istd = FALSE,
      min.signalblank.median.spl.pblk = 100
    ),
    "Replaced following previously defined QC filters: Signal-to-Blank"
  )
  expect_equal(length(unique(mexp_res@dataset_filtered$feature_id)), 12)

  expect_message(
    mexp_res <- filter_features_qc(
      mexp_res,
      include_qualifier = FALSE,
      include_istd = FALSE,
      clear_existing = FALSE,
      max.cv.conc.bqc = 20
    ),
    "Feature QC filters were updated\\: 11 \\(before 12\\)"
  )
  expect_equal(length(unique(mexp_res@dataset_filtered$feature_id)), 11)

  expect_message(
    mexp_res <- filter_features_qc(
      mexp_res,
      include_qualifier = FALSE,
      include_istd = FALSE,
      clear_existing = FALSE,
      max.dratio.sd.conc.bqc = 0.5
    ),
    "Feature QC filters were updated\\: 4 \\(before 11\\)"
  )
  expect_equal(length(unique(mexp_res@dataset_filtered$feature_id)), 4)

  expect_message(
    mexp_res <- filter_features_qc(
      mexp_res,
      clear_existing = FALSE,
      include_qualifier = FALSE,
      include_istd = FALSE,
      max.cv.conc.bqc = 25
    ),
    "Replaced following previously defined QC filters\\: \\%CV"
  )
  expect_equal(length(unique(mexp_res@dataset_filtered$feature_id)), 4)

  mexp_res <- filter_features_qc(
    mexp_res,
    clear_existing = TRUE,
    include_qualifier = FALSE,
    include_istd = FALSE,
    min.signalblank.median.spl.pblk = 100,
    max.dratio.sd.conc.bqc = 0.8,
    max.cv.conc.bqc = 20
  )
  expect_equal(length(unique(mexp_res@dataset_filtered$feature_id)), 11)

  mexp_res <- filter_features_qc(
    mexp_res,
    clear_existing = TRUE,
    include_qualifier = FALSE,
    include_istd = FALSE,
    min.signalblank.median.spl.pblk = 100,
    max.dratio.sd.conc.bqc = 0.8,
    max.cv.conc.bqc = 25
  )

  expect_equal(length(unique(mexp_res@dataset_filtered$feature_id)), 11)

  mexp_res <- filter_features_qc(
    mexp_res,
    clear_existing = FALSE,
    include_qualifier = FALSE,
    include_istd = FALSE,
    max.cv.conc.bqc = 15
  )
  expect_equal(length(unique(mexp_res@dataset_filtered$feature_id)), 5)

  mexp_res <- filter_features_qc(
    mexp_proc,
    clear_existing = FALSE,
    include_qualifier = FALSE,
    include_istd = FALSE,
    min.signalblank.median.spl.pblk = 100,
    max.cv.conc.bqc = 23
  )
  expect_equal(length(unique(mexp_res@dataset_filtered$feature_id)), 11)

  mexp_res <- filter_features_qc(
    mexp_res,
    clear_existing = FALSE,
    include_qualifier = FALSE,
    include_istd = FALSE,
    response.curves.selection = c(1, 2),
    response.curves.summary = "worst",
    max.slope.response = 1.005
  )
  expect_equal(length(unique(mexp_res@dataset_filtered$feature_id)), 5)

  mexp_res <- filter_features_qc(
    mexp_res,
    clear_existing = FALSE,
    include_qualifier = FALSE,
    include_istd = FALSE,
    response.curves.selection = c(1, 2),
    response.curves.summary = "best",
    max.slope.response = 1.005
  )
  expect_equal(length(unique(mexp_res@dataset_filtered$feature_id)), 9)

  mexp_res <- filter_features_qc(
    mexp_res,
    clear_existing = FALSE,
    include_qualifier = FALSE,
    include_istd = FALSE,
    response.curves.selection = c(1, 2),
    response.curves.summary = "best",
    max.slope.response = 1.002
  )
  expect_equal(length(unique(mexp_res@dataset_filtered$feature_id)), 9)
})

# Confirm clearing QC filter works
test_that("Confirm clearing QC filter works", {
  mexp_res2 <- filter_features_qc(
    mexp,
    include_qualifier = FALSE,
    include_istd = FALSE,
    clear_existing = TRUE,
    min.signalblank.median.spl.pblk = 40,
    min.intensity.median.bqc = 1E2,
    max.cv.conc.bqc = 26,
    max.dratio.sd.conc.bqc = 0.8,
    max.prop.missing.conc.spl = 0.2,
    response.curves.selection = c(1),
    response.curves.summary = "mean",
    max.slope.response = 1.05
  )

  expect_message(
    mexp_res3 <- filter_features_qc(
      mexp_res2,
      clear_existing = TRUE,
      include_qualifier = FALSE,
      include_istd = FALSE
    ),
    "all feature QC filters\\! All 19 quantifier"
  )
  expect_equal(length(unique(mexp_res3@dataset_filtered$feature_id)), 19)
})

test_that("Confirm replace QC criteria category works", {
  expect_message(
    mexp_res2 <- filter_features_qc(
      mexp_proc,
      include_qualifier = FALSE,
      include_istd = FALSE,
      clear_existing = FALSE,
      min.signalblank.median.spl.pblk = 100,
      min.intensity.median.bqc = 1E3,
      max.cv.conc.bqc = 23,
      max.dratio.sd.conc.bqc = 0.7,
      max.prop.missing.conc.spl = 0.1,
      response.curves.selection = c(1, 2),
      response.curves.summary = "best",
      max.slope.response = 1.05
    ),
    "New feature QC filters were defined: 10 of 19 quantifier"
  )
  expect_equal(length(unique(mexp_res2@dataset_filtered$feature_id)), 10)

  expect_message(
    mexp_res3 <- filter_features_qc(
      mexp_res2,
      include_qualifier = FALSE,
      include_istd = FALSE,
      clear_existing = FALSE,
      min.signalblank.median.spl.pblk = 40,
      min.intensity.median.bqc = 1E2,
      max.cv.conc.bqc = 26,
      max.dratio.sd.conc.bqc = 0.8,
      max.prop.missing.conc.spl = 0.2,
      response.curves.selection = c(1),
      response.curves.summary = "mean",
      max.slope.response = 1.05
    ),
    "Replaced following previously defined QC filters\\: Missing Values, Min-Intensity, Signal-to-Blank, \\%CV, D-ratio, and Linearity"
  )

  expect_equal(length(unique(mexp_res3@dataset_filtered$feature_id)), 10)

  expect_message(
    mexp_res4 <- filter_features_qc(
      mexp_res3,
      include_qualifier = TRUE,
      include_istd = TRUE,
      clear_existing = FALSE,
      min.signalblank.median.spl.pblk = 40,
      min.intensity.median.bqc = 1E2,
      max.cv.conc.bqc = 26,
      max.dratio.sd.conc.bqc = 0.8,
      max.prop.missing.conc.spl = 0.2,
      response.curves.selection = c(1),
      response.curves.summary = "mean",
      max.slope.response = 1.05
    ),
    "Replaced following previously defined QC filters\\: Missing Values, Min-Intensity, Signal-to-Blank, \\%CV, D-ratio, Linearity, ISTD, and Qualifier"
  )

  expect_message(
    mexp_res4 <- filter_features_qc(
      mexp_res3,
      include_qualifier = TRUE,
      include_istd = FALSE,
      clear_existing = FALSE,
      min.signalblank.median.spl.pblk = 40,
      min.intensity.median.bqc = 1E2,
      max.cv.conc.bqc = 26,
      max.dratio.sd.conc.bqc = 0.8,
      max.prop.missing.conc.spl = 0.2,
      response.curves.selection = c(1),
      response.curves.summary = "mean",
      max.slope.response = 1.05
    ),
    "10 \\(before 10\\) of 19 quantifier and 1 of 1 qualifier features meet QC criteria \\(not including the 9 quantifier and 0 qualifier ISTD features"
  )

  expect_message(
    mexp_res2 <- filter_features_qc(
      mexp_proc,
      include_qualifier = TRUE,
      include_istd = FALSE,
      clear_existing = TRUE,
      min.signalblank.median.spl.pblk = 100,
      min.intensity.median.bqc = 1E3,
      max.cv.conc.bqc = 23,
      max.dratio.sd.conc.bqc = 0.7,
      max.prop.missing.conc.spl = 0.1,
      response.curves.selection = c(1, 2),
      response.curves.summary = "best",
      max.slope.response = 1.05
    ),
    "New feature QC filters were defined\\: 10 of 19 quantifier and 1 of 1 qualifier"
  )
  expect_equal(length(unique(mexp_res2@dataset_filtered$feature_id)), 11)

  expect_message(
    mexp_res3 <- filter_features_qc(
      mexp_res2,
      clear_existing = FALSE,
      include_qualifier = FALSE,
      include_istd = TRUE,
      min.signalblank.median.spl.pblk = 40,
      min.intensity.median.bqc = 1E2,
      max.cv.conc.bqc = 26,
      max.dratio.sd.conc.bqc = 0.8,
      max.prop.missing.conc.spl = 0.2,
      response.curves.selection = c(1),
      response.curves.summary = "mean",
      max.slope.response = 1.05
    ),
    "Replaced following previously defined QC filters\\: Missing Values, Min-Intensity, Signal-to-Blank, \\%CV, D-ratio, Linearity, ISTD, and Qualifier"
  )

  expect_equal(length(unique(mexp_res3@dataset_filtered$feature_id)), 10)

  expect_message(
    mexp_res3 <- filter_features_qc(
      mexp_res2,
      include_istd = FALSE,
      include_qualifier = TRUE,
      clear_existing = FALSE,
      min.signalblank.median.spl.pblk = 40,
      min.intensity.median.bqc = 1E2,
      max.cv.conc.bqc = 14,
      max.dratio.sd.conc.bqc = 0.8,
      max.prop.missing.conc.spl = 0.2,
      response.curves.selection = c(1),
      response.curves.summary = "mean",
      max.slope.response = 1.05
    ),
    "4 (before 10) of 19 quantifier and 0 of 1 qualifier",
    fixed = TRUE
  )

  expect_equal(length(unique(mexp_res3@dataset_filtered$feature_id)), 4)

  #clear all filters
  expect_message(
    mexp_res_cleared <- filter_features_qc(
      mexp_res2,
      clear_existing = TRUE,
      include_istd = FALSE,
      include_qualifier = TRUE
    ),
    "all feature QC filters\\! All 19 quantifier and all 1 qualifier"
  )

  expect_equal(length(unique(mexp_res_cleared@dataset_filtered$feature_id)), 20)
})


test_that("using filters without underlying data", {
  mexp_orig <- lipidomics_dataset
  mexpp <- calc_qc_metrics(mexp_orig, use_batch_medians = FALSE)
  expect_error(
    mexp_res <- filter_features_qc(
      mexpp,
      include_qualifier = TRUE,
      include_istd = FALSE,
      clear_existing = FALSE,
      max.cv.conc.bqc = 20
    ),
    "Cannot filter by max.cv.conc.bqc because concentration data"
  )
})

test_that("using filters correctly features when values are NA", {
  mexpt <- mexp
  mexpt@dataset <- mexpt@dataset |>
    mutate(
      feature_intensity = if_else(
        feature_id == "PC 32:1",
        NA,
        feature_intensity
      )
    )
  mexpt <- normalize_by_istd(mexpt)
  mexpt <- quantify_by_istd(mexpt)
  mexpt_proc <- calc_qc_metrics(mexpt, use_batch_medians = FALSE)

  expect_message(
    mexp_res <- filter_features_qc(
      mexpt_proc,
      include_qualifier = TRUE,
      include_istd = FALSE,
      clear_existing = FALSE,
      max.cv.conc.bqc = 33
    ),
    "New feature QC filters were defined: 18 of 19 quantifier",
    fixed = TRUE
  )

  expect_message(
    mexp_res <- filter_features_qc(
      mexpt_proc,
      include_qualifier = TRUE,
      include_istd = FALSE,
      clear_existing = FALSE,
      max.cv.conc.bqc = 33
    ),
    "The QC parameter max.cv.conc.bqc contains NAs for the following features: PC 32:1.",
    fixed = TRUE
  )
})


test_that("filter_features_qc requires handles inconistent reponse filter setttings", {
  expect_error(
    mexp_res <- filter_features_qc(
      mexp,
      include_qualifier = TRUE,
      include_istd = FALSE,
      clear_existing = FALSE,
      min.rsquare.response = 0.8
    ),
    "No response curves selected"
  )

  expect_error(
    mexp_res <- filter_features_qc(
      mexp,
      include_qualifier = TRUE,
      include_istd = FALSE,
      clear_existing = FALSE,
      response.curves.selection = 1
    ),
    "No response filters were defined"
  )

  expect_error(
    mexp_res <- filter_features_qc(
      mexp,
      include_qualifier = TRUE,
      include_istd = FALSE,
      clear_existing = FALSE,
      response.curves.selection = 111,
      min.rsquare.response = 0.8
    ),
    "The specified response curve index exceeds"
  )

  expect_error(
    mexp_res <- filter_features_qc(
      mexp,
      include_qualifier = TRUE,
      include_istd = FALSE,
      clear_existing = FALSE,
      response.curves.selection = c(1, 2),
      min.rsquare.response = 0.8
    ),
    "Please set `response.curves.summary` to define curve"
  )

  expect_error(
    mexp_res <- filter_features_qc(
      mexp,
      include_qualifier = TRUE,
      include_istd = FALSE,
      clear_existing = FALSE,
      response.curves.selection = "NotAValidSelection",
      min.rsquare.response = 0.8
    ),
    "The following response curves are not defined in the metadata\\: NotAValidSelection"
  )

  mexp_temp <- mexp
  mexp_temp@annot_responsecurves <- mexp_temp@annot_responsecurves[0, ]
  expect_error(
    mexp_res <- filter_features_qc(
      mexp_temp,
      include_qualifier = TRUE,
      include_istd = FALSE,
      clear_existing = FALSE,
      response.curves.selection = 1,
      min.rsquare.response = 0.8
    ),
    "No response curve metadata found."
  )

  expect_no_error(
    mexp_temp2 <- filter_features_qc(
      mexp_temp,
      include_qualifier = TRUE,
      include_istd = TRUE,
      clear_existing = FALSE
    )
  )
})

test_that("filter_features_qc requires specific args set", {
  expect_error(
    mexp_res <- filter_features_qc(
      mexp,
      clear_existing = FALSE,
      max.cv.conc.bqc = 20
    ),
    "Argument `include_qualifier` is missing"
  )

  expect_error(
    mexp_res <- filter_features_qc(
      mexp,
      include_qualifier = TRUE,
      clear_existing = FALSE,
      max.cv.conc.bqc = 20
    ),
    "Argument `include_istd` is missing"
  )

  expect_error(
    mexp_res <- filter_features_qc(
      mexp,
      include_istd = TRUE,
      clear_existing = FALSE,
      max.cv.conc.bqc = 20
    ),
    "Argument `include_qualifier` is missing"
  )
})


test_that("filter_features_qc handles user_defined_keepers", {
  expect_error(
    mexp_res <- filter_features_qc(
      mexp,
      include_qualifier = TRUE,
      include_istd = FALSE,
      clear_existing = TRUE,
      max.cv.conc.bqc = 10,
      features.to.keep = c("CE 18:3")
    ),
    "Following features defined via `features.to.keep` are not present in this dataset\\: CE 18\\:3"
  )

  expect_error(
    mexp_res <- filter_features_qc(
      mexp,
      include_qualifier = TRUE,
      include_istd = FALSE,
      clear_existing = TRUE,
      max.cv.conc.bqc = 10,
      features.to.keep = c("CE 18:1", "CE 18:3", "PC 40:6", "PC 40:9")
    ),
    "Following features defined via `features\\.to\\.keep` are not present in this dataset\\: CE 18\\:3\\, and PC 40\\:9"
  )

  expect_no_error(
    mexp_res <- filter_features_qc(
      mexp,
      include_qualifier = TRUE,
      include_istd = FALSE,
      clear_existing = TRUE,
      max.cv.conc.bqc = 18,
      features.to.keep = NA
    )
  )

  expect_equal(length(unique(mexp_res@dataset_filtered$feature_id)), 14)
  expect_false("CE 18:3" %in% mexp_res@dataset_filtered$feature_id)

  mexp_res <- filter_features_qc(
    mexp,
    include_qualifier = TRUE,
    include_istd = FALSE,
    clear_existing = TRUE,
    max.cv.conc.bqc = 18,
    features.to.keep = c("CE 18:1")
  )

  expect_equal(length(unique(mexp_res@dataset_filtered$feature_id)), 14)
  expect_true("CE 18:1" %in% mexp_res@dataset_filtered$feature_id)

  expect_message(
    mexp_res2 <- filter_features_qc(
      mexp_res,
      include_qualifier = TRUE,
      include_istd = FALSE,
      clear_existing = FALSE,
      max.cv.conc.bqc = 18,
      features.to.keep = c("PC 40:6")
    ),
    "Replaced following previously defined QC filters\\: \\%CV\\, and Keepers"
  )

  expect_message(
    mexp_res2 <- filter_features_qc(
      mexp_res2,
      include_qualifier = TRUE,
      include_istd = FALSE,
      clear_existing = FALSE,
      max.cv.conc.bqc = 19,
      features.to.keep = c("PC 40:6")
    ),
    "Replaced following previously defined QC filters\\: \\%CV"
  )

  expect_message(
    mexp_res2 <- filter_features_qc(
      mexp,
      include_qualifier = TRUE,
      include_istd = FALSE,
      clear_existing = TRUE,
      max.cv.conc.bqc = 12,
      features.to.keep = c("CE 18:1", "PC 40:6")
    ),
    "The following features were forced to be retained despite not meeting filtering criteria\\: CE 18\\:1\\, and PC 40\\:6"
  )

  expect_equal(length(unique(mexp_res2@dataset_filtered$feature_id)), 5)
  expect_true(all(
    c("CE 18:1", "PC 40:6") %in% mexp_res2@dataset_filtered$feature_id
  ))

  messages <- capture.output(
    mexp_res2 <- filter_features_qc(
      mexp,
      include_qualifier = TRUE,
      include_istd = FALSE,
      clear_existing = TRUE,
      max.cv.conc.bqc = 19999,
      features.to.keep = c("CE 18:1", "PC 40:6")
    ),
    type = "message"
  )
  expect_false(any(grepl(
    "The following features were forced to be retained despite n",
    messages
  )))

  expect_equal(length(unique(mexp_res2@dataset_filtered$feature_id)), 20)
  expect_true(all(
    c("CE 18:1", "PC 40:6") %in% mexp_res2@dataset_filtered$feature_id
  ))

  expect_message(
    mexp_res3 <- filter_features_qc(
      mexp_res2,
      include_qualifier = TRUE,
      include_istd = FALSE,
      clear_existing = FALSE,
      max.cv.conc.bqc = 18
    ),
    "Replaced following previously defined QC filters\\: \\%CV\\, and Keepers"
  )

  expect_message(
    mexp_res3 <- filter_features_qc(
      mexp_res2,
      include_qualifier = TRUE,
      include_istd = FALSE,
      clear_existing = FALSE,
      max.cv.conc.bqc = 11
    ),
    "1 \\(before 19\\) of 19 quantifier and 0 of 1 qualifier features meet QC criteria \\(not including the 9 quantifier and 0 qualifier ISTD features\\)"
  )

  expect_equal(length(unique(mexp_res3@dataset_filtered$feature_id)), 1)
  expect_false(any(
    c("CE 18:1", "PC 40:6") %in% mexp_res3@dataset_filtered$feature_id
  ))
})

test_that("calc_qc_metrics works with only conc present", {
  mexp_temp <- mexp
  mexp_temp@dataset$feature_rt <- NULL
  mexp_temp@dataset$feature_conc <- mexp_temp@dataset$feature_intensity
  mexp_temp@dataset$feature_intensity <- NULL
  mexp_temp@dataset$feature_norm_intensity <- NULL
  mexp_res <- calc_qc_metrics(mexp_temp, use_batch_medians = FALSE)

  expect_message(
    mexp_res4 <- filter_features_qc(
      mexp_res,
      include_qualifier = TRUE,
      include_istd = FALSE,
      clear_existing = FALSE,
      max.cv.conc.bqc = 11
    ),
    "New feature QC filters were defined: 6 of 19 quantifier and 0 of 1 qualifier features meet QC criteria (not including the 9 quantifier and 0 qualifier ISTD features",
    fixed = TRUE
  )
})

test_that("calc_qc_metrics handles empty / zero-row inputs without crashing", {
  # A freshly constructed (fully empty) experiment returns cleanly
  expect_s4_class(
    suppressMessages(calc_qc_metrics(mrmhub::MRMhubExperiment())),
    "MRMhubExperiment"
  )

  # A lipidomics experiment with a zero-row dataset must not crash in the lipid
  # name parser (empty rgoslin parse has no `Grammar` column); it returns
  # cleanly with metrics derived from the feature metadata.
  mexp_zero <- mexp
  mexp_zero@dataset <- mexp_zero@dataset[FALSE, ]
  expect_no_error(
    mexp_res <- suppressMessages(calc_qc_metrics(mexp_zero))
  )
  expect_s4_class(mexp_res, "MRMhubExperiment")
})

test_that("blank analyses without a row for a feature count as zero", {
  id <- mexp_proc@metrics_qc |>
    dplyr::filter(!.data$is_istd, .data$in_data) |>
    dplyr::pull(.data$feature_id) |>
    dplyr::nth(5)
  pblk_ids <- mexp@dataset |>
    dplyr::filter(.data$qc_type == "PBLK") |>
    dplyr::distinct(.data$analysis_id) |>
    dplyr::pull()
  mexp_blk <- mexp
  mexp_blk@dataset <- mexp_blk@dataset |>
    dplyr::filter(
      !(.data$feature_id == id & .data$analysis_id %in% pblk_ids[-1])
    )
  mexp_blk <- calc_qc_metrics(mexp_blk)
  m <- mexp_blk@metrics_qc[mexp_blk@metrics_qc$feature_id == id, ]
  expect_equal(m$intensity_median_pblk, 0)
  expect_equal(m$sb_ratio_pblk, Inf)
})

test_that("batch-median S/B is not Inf when only one of two blank batches is Inf", {
  id <- mexp_proc@metrics_qc |>
    dplyr::filter(!.data$is_istd, .data$in_data) |>
    dplyr::pull(.data$feature_id) |>
    dplyr::nth(5)
  pblk <- mexp@dataset |>
    dplyr::filter(.data$qc_type == "PBLK") |>
    dplyr::distinct(.data$analysis_id, .data$batch_id)
  expect_equal(dplyr::n_distinct(pblk$batch_id), 2)
  mexp_blk <- mexp
  mexp_blk@dataset <- mexp_blk@dataset |>
    dplyr::mutate(
      feature_intensity = dplyr::if_else(
        .data$feature_id == id &
          .data$analysis_id %in%
            pblk$analysis_id[
              pblk$batch_id == pblk$batch_id[1]
            ],
        NA,
        .data$feature_intensity
      )
    )
  mexp_blk <- calc_qc_metrics(mexp_blk, use_batch_medians = TRUE)
  sb <- mexp_blk@metrics_qc$sb_ratio_pblk[mexp_blk@metrics_qc$feature_id == id]
  expect_true(is.finite(sb))
})

test_that("missing response-curve results are not reported for filtered-out features", {
  m <- mexp_proc@metrics_qc
  ids <- m$feature_id[!m$is_istd][1:3]
  mexp_na <- mexp_proc
  mexp_na@metrics_qc <- m |>
    dplyr::mutate(
      dplyr::across(
        dplyr::contains("_rqc_"),
        \(x) dplyr::if_else(.data$feature_id %in% ids, NA, x)
      ),
      is_quantifier = dplyr::if_else(
        .data$feature_id == ids[1],
        FALSE,
        .data$is_quantifier
      ),
      in_data = .data$in_data & .data$feature_id != ids[2]
    )
  msgs <- testthat::capture_messages(
    filter_features_qc(
      mexp_na,
      include_qualifier = FALSE,
      include_istd = TRUE,
      response.curves.selection = 1,
      min.rsquare.response = 0.5
    )
  )
  lin_msg <- paste(
    msgs[grepl("without the response-curve results", msgs)],
    collapse = ""
  )
  expect_false(grepl(ids[1], lin_msg, fixed = TRUE))
  expect_false(grepl(ids[2], lin_msg, fixed = TRUE))
  expect_true(grepl(ids[3], lin_msg, fixed = TRUE))
})

test_that("qc_stat_exprs summarises any QC type, including new or absent ones", {
  d <- mexp@dataset
  ex <- qc_stat_exprs(
    "intensity_median",
    "feature_intensity",
    c("SPL", "HQC", "EQA"),
    median,
    na.rm = TRUE
  )
  expect_named(
    ex,
    c("intensity_median_spl", "intensity_median_hqc", "intensity_median_eqa")
  )

  d$qc_type[d$qc_type == "TQC"] <- "HQC" # stand-in for a new QC type
  res <- dplyr::summarise(d, .by = "feature_id", !!!ex)
  ref <- d |>
    dplyr::filter(.data$qc_type == "HQC") |>
    dplyr::summarise(
      .by = "feature_id",
      m = median(.data$feature_intensity, na.rm = TRUE)
    )
  expect_equal(
    res$intensity_median_hqc[match(ref$feature_id, res$feature_id)],
    ref$m
  )
  expect_true(all(is.na(res$intensity_median_eqa))) # QC type not in the data
})

test_that("dratio_exprs names the SD then MAD D-ratios per QC type", {
  expect_named(
    dratio_exprs("conc", "feature_conc", c("BQC", "TQC"), 3L),
    c(
      "conc_dratio_sd_bqc",
      "conc_dratio_sd_tqc",
      "conc_dratio_mad_bqc",
      "conc_dratio_mad_tqc"
    )
  )
})
