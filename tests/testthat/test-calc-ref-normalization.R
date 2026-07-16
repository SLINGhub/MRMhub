mexp_raw <- mrmhub::MRMhubExperiment()
mexp_raw <- mrmhub::import_data_masshunter(
  mexp_raw,
  path = testthat::test_path(
    "testdata/masshunter/23_Testdata_MHQuant_DefaultSampleInfo_RT-Areas-FWHM_notInSeq_notimestamp.csv"
  ),
  import_metadata = FALSE
)
mexp <- mrmhub::import_metadata_msorganiser(
  mexp_raw,
  path = testthat::test_path(
    "testdata/metadata/MRMhub_Metadata_HQuant_S1P_forCalib.xlsx"
  ),
  excl_unmatched_analyses = FALSE
)

mexp <- normalize_by_istd(mexp)
mexp <- quantify_by_istd(mexp)

test_that("calibrate_by_reference catches input errors and issues", {
  expect_error(
    calibrate_by_reference(
      data = mexp,
      variable = "feature_intensity",
      reference_sample_id = "NIST_SRM1950",
      absolute_calibration = TRUE,
      undefined_conc_action = "error",
      summarize_fun = "min"
    ),
    "`summarize_fun` must be one of",
    fixed = TRUE
  )

  expect_error(
    calibrate_by_reference(
      data = mexp,
      variable = "feature_intensity",
      reference_sample_id = "NIST_SRM1950",
      absolute_calibration = TRUE,
      undefined_conc_action = "original",
      summarize_fun = "mean"
    ),
    "When using `undefined_conc_action = 'original'`, the variable 'conc' must",
    fixed = TRUE
  )

  expect_error(
    calibrate_by_reference(
      data = mexp,
      variable = "feature_intensity",
      reference_sample_id = "NIST_SRM1950",
      absolute_calibration = TRUE
    ),
    "When using `absolute_calibration = TRUE`, then `undefined_conc_action`",
    fixed = TRUE
  )

  expect_error(
    calibrate_by_reference(
      data = mexp_raw,
      variable = "feature_intensity",
      reference_sample_id = "NIST",
      absolute_calibration = FALSE
    ),
    "The specified `reference_sample_id` is not present in the dataset",
    fixed = TRUE
  )

  mexp_temp <- mexp
  mexp_temp@annot_qcconcentrations$sample_id <- "undefined"

  expect_error(
    calibrate_by_reference(
      data = mexp_temp,
      variable = "feature_intensity",
      reference_sample_id = "NIST_SRM1950",
      absolute_calibration = TRUE,
      undefined_conc_action = "error"
    ),
    "No concentration values found for the reference sample `NIST_SRM1950`",
    fixed = TRUE
  )

  mexp_temp <- mexp
  mexp_temp@annot_qcconcentrations$sample_id[1] <- "undefined"

  expect_error(
    calibrate_by_reference(
      data = mexp_temp,
      variable = "feature_intensity",
      reference_sample_id = "NIST_SRM1950",
      absolute_calibration = TRUE,
      undefined_conc_action = "error"
    ),
    "One or more feature concentration are not defined in the reference sample",
    fixed = TRUE
  )

  mexp_temp <- mexp
  mexp_temp@annot_qcconcentrations$concentration[1] <- NA_real_
  expect_error(
    calibrate_by_reference(
      data = mexp_temp,
      variable = "feature_intensity",
      reference_sample_id = "NIST_SRM1950",
      absolute_calibration = TRUE,
      undefined_conc_action = "error"
    ),
    "One or more feature concentration are not defined in the reference sample",
    fixed = TRUE
  )

  mexp_temp <- mexp
  mexp_temp@annot_qcconcentrations$concentration_unit <- NA_character_
  expect_error(
    calibrate_by_reference(
      data = mexp_temp,
      variable = "feature_intensity",
      reference_sample_id = "NIST_SRM1950",
      absolute_calibration = TRUE,
      undefined_conc_action = "error"
    ),
    "No concentration units found for features of reference sample",
    fixed = TRUE
  )

  mexp_temp <- mexp
  mexp_temp@annot_qcconcentrations$concentration_unit[2] <- "mg/L"
  expect_error(
    calibrate_by_reference(
      data = mexp_temp,
      variable = "feature_intensity",
      reference_sample_id = "NIST_SRM1950",
      absolute_calibration = TRUE,
      undefined_conc_action = "error"
    ),
    "Different unit used for feature concentrations in reference sample",
    fixed = TRUE
  )

  mexp_temp <- mexp
  mexp_temp@annot_qcconcentrations$sample_id[1] <- "undefined"

  expect_message(
    calibrate_by_reference(
      data = mexp_temp,
      variable = "feature_intensity",
      reference_sample_id = "NIST_SRM1950",
      absolute_calibration = TRUE,
      undefined_conc_action = "na"
    ),
    "One or more feature concentration are not defined in the reference sample NIST_SRM1950",
    fixed = TRUE
  )

  expect_message(
    calibrate_by_reference(
      data = mexp,
      variable = "feature_conc",
      reference_sample_id = "NIST_SRM1950",
      absolute_calibration = TRUE,
      undefined_conc_action = "original"
    ),
    "concentration are not defined in the reference sample NIST_SRM1950. Original values will be returned for these",
    fixed = TRUE
  )

  expect_message(
    mexp_res <- calibrate_by_reference(
      data = mexp,
      variable = "feature_intensity",
      reference_sample_id = "NIST_SRM1950",
      absolute_calibration = TRUE,
      undefined_conc_action = "na"
    ),
    "3 feature concentrations were calculated using the defined reference sample concentrations",
    fixed = TRUE
  )

  expect_message(
    mexp_res <- calibrate_by_reference(
      data = mexp,
      variable = "feature_conc",
      reference_sample_id = "NIST_SRM1950",
      absolute_calibration = TRUE,
      undefined_conc_action = "na"
    ),
    "3 feature concentrations were re-calibrated using the reference sample",
    fixed = TRUE
  )

  expect_message(
    mexp_res <- calibrate_by_reference(
      data = mexp,
      variable = "feature_conc",
      reference_sample_id = "NIST_SRM1950",
      absolute_calibration = TRUE,
      undefined_conc_action = "na"
    ),
    "Concentrations are given in umol/L",
    fixed = TRUE
  )

  expect_message(
    mexp_res <- calibrate_by_reference(
      data = mexp,
      variable = "feature_conc",
      reference_sample_id = "NIST_SRM1950",
      absolute_calibration = FALSE,
      undefined_conc_action = "na"
    ),
    "All features were normalized with reference sample NIST_SRM1950 ",
    fixed = TRUE
  )

  expect_message(
    mexp_res <- calibrate_by_reference(
      data = mexp,
      variable = "feature_conc",
      reference_sample_id = "NIST_SRM1950",
      absolute_calibration = FALSE,
      undefined_conc_action = "na"
    ),
    "All features were normalized with reference sample NIST_SRM1950 features",
    fixed = TRUE
  )

  expect_message(
    mexp_res <- calibrate_by_reference(
      data = mexp,
      variable = "feature_conc",
      reference_sample_id = "NIST_SRM1950",
      absolute_calibration = FALSE,
      undefined_conc_action = "na"
    ),
    "sample [conc] / NIST_SRM1950 [conc]",
    fixed = TRUE
  )

  expect_error(
    calibrate_by_reference(
      data = mexp,
      variable = "feature_intensity",
      reference_sample_id = "NIST_SRM1950",
      absolute_calibration = TRUE,
      undefined_conc_action = "dontknow"
    ),
    "must be one of",
    fixed = TRUE
  )

  mexp_temp <- mexp
  mexp_temp@dataset <- mexp_temp@dataset |>
    mutate(
      batch_id = if_else(str_detect(analysis_id, "SPL\\_S08"), "new", batch_id)
    )

  expect_error(
    calibrate_by_reference(
      data = mexp_temp,
      batch_wise = TRUE,
      variable = "feature_intensity",
      reference_sample_id = "NIST_SRM1950",
      absolute_calibration = TRUE,
      undefined_conc_action = "na"
    ),
    "The specified reference sample `NIST_SRM1950` is missing from one or more batches",
    fixed = TRUE
  )

  expect_no_error(
    calibrate_by_reference(
      data = mexp_temp,
      batch_wise = FALSE,
      variable = "feature_intensity",
      reference_sample_id = "NIST_SRM1950",
      absolute_calibration = TRUE,
      undefined_conc_action = "na"
    )
  )
})

test_that("calibrate_by_reference works", {
  mexp_res <- calibrate_by_reference(
    data = mexp,
    variable = "conc",
    reference_sample_id = "NIST_SRM1950",
    absolute_calibration = TRUE,
    batch_wise = FALSE,
    undefined_conc_action = "na"
  )
  n <- sum(
    !(mexp_res@dataset$feature_conc == mexp_res@dataset$feature_conc_beforecal),
    na.rm = TRUE
  )
  expect_equal(n, 389)
  n <- sum(is.na(mexp_res@dataset$feature_conc))
  expect_equal(n, 651) # more than 632 because includes also NA values present before cal

  expect_equal(
    mexp_res@dataset[
      mexp_res@dataset$analysis_id == "020_SPL_S001" &
        mexp_res@dataset$feature_id == "S1P d18:2 [M>60]",
    ]$feature_conc,
    0.075810351
  )

  expect_equal(
    mexp_res@dataset[
      mexp_res@dataset$analysis_id == "020_SPL_S001" &
        mexp_res@dataset$feature_id == "S1P d18:2 [M>60]",
    ]$feature_conc_beforecal,
    0.078142741
  )

  expect_equal(
    mexp_res@dataset[
      mexp_res@dataset$analysis_id == "020_SPL_S001" &
        mexp_res@dataset$feature_id == "S1P d16:1 [M>60]",
    ]$feature_conc,
    NA_real_
  )

  expect_equal(
    mexp_res@dataset[
      mexp_res@dataset$analysis_id == "020_SPL_S001" &
        mexp_res@dataset$feature_id == "S1P d16:1 [M>60]",
    ]$feature_conc_beforecal,
    0.034113950
  )

  mexp_res <- calibrate_by_reference(
    data = mexp,
    variable = "conc",
    reference_sample_id = "NIST_SRM1950",
    absolute_calibration = TRUE,
    batch_wise = FALSE,
    undefined_conc_action = "original"
  )
  n <- sum(
    !(mexp_res@dataset$feature_conc == mexp_res@dataset$feature_conc_beforecal),
    na.rm = TRUE
  )
  expect_equal(n, 389)
  n <- sum(
    mexp_res@dataset$feature_conc == mexp_res@dataset$feature_conc_beforecal,
    na.rm = TRUE
  )
  expect_equal(n, 632) # means those values that were not updated, total 1021

  expect_equal(
    mexp_res@dataset[
      mexp_res@dataset$analysis_id == "020_SPL_S001" &
        mexp_res@dataset$feature_id == "S1P d18:2 [M>60]",
    ]$feature_conc,
    0.075810351
  )

  expect_equal(
    mexp_res@dataset[
      mexp_res@dataset$analysis_id == "020_SPL_S001" &
        mexp_res@dataset$feature_id == "S1P d18:2 [M>60]",
    ]$feature_conc_beforecal,
    0.078142741
  )

  expect_equal(
    mexp_res@dataset[
      mexp_res@dataset$analysis_id == "120_SPL_S086" &
        mexp_res@dataset$feature_id == "S1P d18:2 [M>60]",
    ]$feature_conc,
    0.113832312
  )

  expect_equal(
    mexp_res@dataset[
      mexp_res@dataset$analysis_id == "120_SPL_S086" &
        mexp_res@dataset$feature_id == "S1P d18:2 [M>60]",
    ]$feature_conc_beforecal,
    0.117334491
  )

  expect_equal(
    mexp_res@dataset[
      mexp_res@dataset$analysis_id == "020_SPL_S001" &
        mexp_res@dataset$feature_id == "S1P d16:1 [M>60]",
    ]$feature_conc,
    0.03411395
  )

  expect_equal(
    mexp_res@dataset[
      mexp_res@dataset$analysis_id == "020_SPL_S001" &
        mexp_res@dataset$feature_id == "S1P d16:1 [M>60]",
    ]$feature_conc_beforecal,
    0.034113950
  )

  expect_false("feature_conc_normalized" %in% names(mexp_res@dataset))

  mexp_res <- calibrate_by_reference(
    data = mexp,
    variable = "conc",
    reference_sample_id = "NIST_SRM1950",
    absolute_calibration = FALSE,
    undefined_conc_action = "original"
  )
  n <- sum(
    !(mexp_res@dataset$feature_conc ==
      mexp_res@dataset$feature_conc_normalized),
    na.rm = TRUE
  )
  expect_equal(n, 1021)
  n <- sum(
    mexp_res@dataset$feature_conc == mexp_res@dataset$feature_conc_normalized,
    na.rm = TRUE
  )
  expect_equal(n, 0) # means those values that were not updated, total 1040

  expect_equal(
    mexp_res@dataset[
      mexp_res@dataset$analysis_id == "020_SPL_S001" &
        mexp_res@dataset$feature_id == "S1P d18:2 [M>60]",
    ]$feature_conc,
    0.078142741
  )

  expect_equal(
    mexp_res@dataset[
      mexp_res@dataset$analysis_id == "120_SPL_S086" &
        mexp_res@dataset$feature_id == "S1P d18:2 [M>60]",
    ]$feature_conc,
    0.117334491
  )

  expect_equal(
    mexp_res@dataset[
      mexp_res@dataset$analysis_id == "020_SPL_S001" &
        mexp_res@dataset$feature_id == "S1P d18:2 [M>60]",
    ]$feature_conc_normalized,
    0.75810351
  )

  expect_equal(
    mexp_res@dataset[
      mexp_res@dataset$analysis_id == "120_SPL_S086" &
        mexp_res@dataset$feature_id == "S1P d18:2 [M>60]",
    ]$feature_conc_normalized,
    1.13832312
  )
})


test_that("calibrate_by_reference batch-wise works", {
  # The "check reference sample has non-zero values" warning is asserted in the
  # dedicated tests below; suppress it here where it is incidental.
  expect_message(
    mexp_res <- suppressWarnings(calibrate_by_reference(
      data = mexp,
      variable = "conc",
      reference_sample_id = "NIST_SRM1950",
      absolute_calibration = TRUE,
      batch_wise = TRUE,
      undefined_conc_action = "original",
      store_normalized = FALSE
    )),
    "3 feature concentrations were batch-wise re-calibrated ",
    fixed = TRUE
  )

  expect_false("feature_conc_normalized" %in% names(mexp_res@dataset))

  expect_equal(
    mexp_res@dataset[
      mexp_res@dataset$analysis_id == "020_SPL_S001" &
        mexp_res@dataset$feature_id == "S1P d18:2 [M>60]",
    ]$feature_conc,
    0.075035653
  )

  expect_equal(
    mexp_res@dataset[
      mexp_res@dataset$analysis_id == "120_SPL_S086" &
        mexp_res@dataset$feature_id == "S1P d18:2 [M>60]",
    ]$feature_conc,
    0.115019824
  )

  expect_equal(
    mexp_res@dataset[
      mexp_res@dataset$analysis_id == "020_SPL_S001" &
        mexp_res@dataset$feature_id == "S1P d18:2 [M>60]",
    ]$feature_conc_beforecal,
    0.078142741
  )

  expect_equal(
    mexp_res@dataset[
      mexp_res@dataset$analysis_id == "120_SPL_S086" &
        mexp_res@dataset$feature_id == "S1P d18:2 [M>60]",
    ]$feature_conc_beforecal,
    0.117334491
  )
})


test_that("calibrate_by_reference results are exportable", {
  expect_message(
    mexp_res <- calibrate_by_reference(
      data = mexp,
      variable = "conc",
      reference_sample_id = "NIST_SRM1950",
      batch_wise = FALSE,
      absolute_calibration = FALSE
    ),
    "All features were normalized with reference sample",
    fixed = TRUE
  )

  temp_file <- tempfile(fileext = ".csv")
  expect_message(
    save_dataset_csv(
      data = mexp_res,
      path = temp_file,
      variable = "conc_normalized",
      filter_data = FALSE
    ),
    "Conc_normalized values for 65 analyses and 16 feature"
  )

  exported_data <- readr::read_csv(temp_file)
  expect_equal(exported_data[[1, "S1P d18:2 [M>60]"]], 0.758103511820332)

  temp_file <- tempfile(fileext = ".xlsx")

  save_report_xlsx(data = mexp_res, path = temp_file)

  # Load the workbook and check for sheets
  w_xlm <- openxlsx2::wb_load(temp_file)
  expected_sheets <- c(
    "Info",
    "Feature_QC_metrics",
    "Calibration_metrics",
    "QCfilt_StudySamples",
    "QCfilt_AllSamples",
    "Conc_FullDataset",
    "Conc_NormalizedByRef_Full",
    "Raw_Intensity_FullDataset",
    "Norm_Intensity_FullDataset",
    "SampleMetadata",
    "FeatureMetadata",
    "InternalStandards",
    "BatchInfo"
  )

  expect_setequal(w_xlm$sheet_names, expected_sheets)
  on.exit(unlink(temp_file)) # Clean up

  mexp_res <- calibrate_by_reference(
    data = mexp,
    variable = "intensity",
    reference_sample_id = "NIST_SRM1950",
    absolute_calibration = FALSE
  )

  temp_file <- tempfile(fileext = ".xlsx")

  save_report_xlsx(data = mexp_res, path = temp_file)

  # Load the workbook and check for sheets
  w_xlm <- openxlsx2::wb_load(temp_file)
  expected_sheets <- c(
    "Info",
    "Feature_QC_metrics",
    "Calibration_metrics",
    "QCfilt_StudySamples",
    "QCfilt_AllSamples",
    "Conc_FullDataset",
    "Intensity_NormalizedByRef_Full",
    "Raw_Intensity_FullDataset",
    "Norm_Intensity_FullDataset",
    "SampleMetadata",
    "FeatureMetadata",
    "InternalStandards",
    "BatchInfo"
  )

  expect_setequal(w_xlm$sheet_names, expected_sheets)
  on.exit(unlink(temp_file)) # Clean up

  mexp_res2 <- calibrate_by_reference(
    data = mexp_res,
    variable = "conc",
    reference_sample_id = "NIST_SRM1950",
    absolute_calibration = FALSE
  )

  expect_error(
    save_report_xlsx(data = mexp_res2, path = temp_file),
    "More than one normalized feature variable found in dataset",
    fixed = TRUE
  )

  mexp_res <- calibrate_by_reference(
    data = mexp,
    variable = "intensity",
    reference_sample_id = "NIST_SRM1950",
    absolute_calibration = FALSE
  )

  expect_error(
    save_report_xlsx(
      data = mexp_res,
      path = temp_file,
      normalized_variable = "conc"
    ),
    "Normalized feature variable 'feature_conc' not found in dataset",
    fixed = TRUE
  )

  expect_no_error(
    save_report_xlsx(
      data = mexp_res,
      path = temp_file,
      normalized_variable = "intensity"
    )
  )
})


test_that("calibrate_by_reference with filtered data", {
  mexp_temp <- mrmhub::filter_features_qc(
    mexp,
    include_qualifier = FALSE,
    include_istd = FALSE,
    max.cv.conc.bqc = 20
  )

  expect_message(
    mexp_res <- calibrate_by_reference(
      data = mexp_temp,
      variable = "conc",
      reference_sample_id = "NIST_SRM1950",
      absolute_calibration = TRUE,
      undefined_conc_action = "na"
    ),
    "Previously filtered dataset is no longer valid and has been cleared",
    fixed = TRUE
  )
})


test_that("calibrate_by_reference outputs bias", {
  mexp_res <- calibrate_by_reference(
    data = mexp,
    variable = "conc",
    reference_sample_id = "NIST_SRM1950",
    absolute_calibration = TRUE,
    undefined_conc_action = "na",
    store_conc_ratio = TRUE
  )

  expect_equal(
    mexp_res@dataset[
      mexp_res@dataset$analysis_id == "020_SPL_S001" &
        mexp_res@dataset$feature_id == "S1P d18:2 [M>60]",
    ]$feature_conc_ratio,
    0.78142741
  )

  mexp_res <- calibrate_by_reference(
    data = mexp,
    variable = "conc",
    reference_sample_id = "NIST_SRM1950",
    absolute_calibration = TRUE,
    undefined_conc_action = "na",
    store_conc_ratio = FALSE
  )

  expect_false("feature_conc_ratio" %in% names(mexp_res@dataset))

  expect_error(
    mexp_res <- calibrate_by_reference(
      data = mexp,
      variable = "intensity",
      reference_sample_id = "NIST_SRM1950",
      absolute_calibration = TRUE,
      undefined_conc_action = "na",
      store_conc_ratio = TRUE
    ),
    "When using `store_conc_ratio = TRUE`, the variable 'conc' must be used as input",
    fixed = TRUE
  )
})

test_that("calibrate_by_reference supports multiple reference_sample_id", {
  # Passing more than one reference id previously crashed on the scalar
  # `ref_sample` column assignment. Relabelling the reference analyses under
  # two distinct sample ids and passing both must pool the same analyses and
  # therefore reproduce the single-reference normalization exactly.
  ref_analyses <- unique(
    mexp@dataset$analysis_id[mexp@dataset$sample_id == "NIST_SRM1950"]
  )
  expect_gt(length(ref_analyses), 1)

  mid <- ceiling(length(ref_analyses) / 2)
  mexp_split <- mexp
  mexp_split@dataset$sample_id[
    mexp_split@dataset$analysis_id %in% ref_analyses[seq_len(mid)]
  ] <- "NIST_A"
  mexp_split@dataset$sample_id[
    mexp_split@dataset$analysis_id %in% ref_analyses[-seq_len(mid)]
  ] <- "NIST_B"

  res_multi <- calibrate_by_reference(
    data = mexp_split,
    variable = "conc",
    reference_sample_id = c("NIST_A", "NIST_B"),
    absolute_calibration = FALSE,
    batch_wise = FALSE
  )
  res_single <- calibrate_by_reference(
    data = mexp,
    variable = "conc",
    reference_sample_id = "NIST_SRM1950",
    absolute_calibration = FALSE,
    batch_wise = FALSE
  )

  expect_equal(
    res_multi@dataset$feature_conc_normalized,
    res_single@dataset$feature_conc_normalized
  )
  expect_true(any(!is.na(res_multi@dataset$feature_conc_normalized)))
})

test_that("calibrate_by_reference sets a zero reference summary to NA (not Inf) and warns", {
  refid <- "NIST_SRM1950"
  feat <- "S1P d18:2 [M>60]"

  # Zero the reference sample's intensity for one feature, so its (mean)
  # reference summary is 0 -- without the guard the division would give Inf.
  mexp_zero <- mexp
  mexp_zero@dataset$feature_intensity[
    mexp_zero@dataset$sample_id == refid &
      mexp_zero@dataset$feature_id == feat
  ] <- 0

  suppressMessages(
    expect_warning(
      mexp_res <- calibrate_by_reference(
        data = mexp_zero,
        variable = "intensity",
        reference_sample_id = refid,
        absolute_calibration = FALSE
      ),
      "reference summary was zero or undefined"
    )
  )

  affected <- mexp_res@dataset$feature_intensity_normalized[
    mexp_res@dataset$feature_id == feat
  ]
  expect_true(all(is.na(affected)))
  expect_false(any(
    is.infinite(mexp_res@dataset$feature_intensity_normalized) |
      is.nan(mexp_res@dataset$feature_intensity_normalized),
    na.rm = TRUE
  ))
})

test_that("calibrate_by_reference warns and sets a zero reference concentration to an NA ratio", {
  refid <- "NIST_SRM1950"

  # Zero one known reference concentration; the concentration ratio
  # (value / reference) would otherwise be Inf.
  mexp_zero <- mexp
  ref_rows <- which(mexp_zero@annot_qcconcentrations$sample_id == refid)
  mexp_zero@annot_qcconcentrations$concentration[ref_rows[1]] <- 0

  suppressMessages(
    expect_warning(
      mexp_res <- calibrate_by_reference(
        mexp_zero,
        variable = "conc",
        reference_sample_id = refid,
        absolute_calibration = TRUE,
        undefined_conc_action = "na"
      ),
      "zero reference concentration"
    )
  )

  expect_true(any(is.na(mexp_res@dataset$feature_conc_ratio)))
  expect_false(any(
    is.infinite(mexp_res@dataset$feature_conc_ratio),
    na.rm = TRUE
  ))
})

test_that("multiple reference samples with equal concentrations do not fan out the dataset", {
  # Two reference samples defining the SAME concentration for an analyte is a
  # valid configuration. The reference-concentration lookup must collapse them to
  # one value per analyte, not duplicate every measurement of that analyte
  # (which previously broke the one-row-per-(analysis_id, feature_id) invariant).
  mexp_temp <- mexp
  qc <- mexp_temp@annot_qcconcentrations
  qc_second_ref <- qc |>
    dplyr::filter(sample_id == "NIST_SRM1950") |>
    dplyr::mutate(sample_id = "NIST_SRM1950_dup") # identical concentrations
  mexp_temp@annot_qcconcentrations <- dplyr::bind_rows(qc, qc_second_ref)

  n_rows_before <- nrow(mexp_temp@dataset)
  mexp_res <- calibrate_by_reference(
    data = mexp_temp,
    variable = "conc",
    reference_sample_id = c("NIST_SRM1950", "NIST_SRM1950_dup"),
    absolute_calibration = TRUE,
    undefined_conc_action = "na"
  )

  expect_equal(nrow(mexp_res@dataset), n_rows_before)
  expect_false(any(duplicated(
    mexp_res@dataset[, c("analysis_id", "feature_id")]
  )))
})

test_that("calibrate_by_reference aborts on conflicting reference concentrations", {
  # If two reference samples give DIFFERENT concentrations for the same analyte,
  # there is no safe choice: silently picking one (or duplicating rows) would
  # corrupt the calibration. Abort with a clear message instead.
  mexp_temp <- mexp
  qc <- mexp_temp@annot_qcconcentrations
  qc_second_ref <- qc |>
    dplyr::filter(sample_id == "NIST_SRM1950") |>
    dplyr::mutate(sample_id = "NIST_SRM1950_dup")
  qc_second_ref$concentration[1] <- qc_second_ref$concentration[1] * 2 # conflict
  mexp_temp@annot_qcconcentrations <- dplyr::bind_rows(qc, qc_second_ref)

  expect_error(
    calibrate_by_reference(
      data = mexp_temp,
      variable = "conc",
      reference_sample_id = c("NIST_SRM1950", "NIST_SRM1950_dup"),
      absolute_calibration = TRUE,
      undefined_conc_action = "na"
    ),
    "Conflicting reference concentrations"
  )
})
