mexp_empty <- MRMhubExperiment()

mexp <- mrmhub::import_data_masshunter(
  mexp_empty,
  path = testthat::test_path(
    "testdata/masshunter/MRMhub_TestData_MHQuant_S1P_DefaultSampleInfo_RT-Areas-FWHM.csv"
  ),
  import_metadata = FALSE
)
path <- testthat::test_path(
  "testdata/metadata/MRMhub_TestData_MHQuant_S1P_metadata_tables.xlsx"
)
expect_message(
  mexp <- mrmhub:::import_metadata_analyses(
    mexp,
    path = path,
    sheet = "Analyses",
    ignore_warnings = FALSE,
    excl_unmatched_analyses = TRUE
  ),
  "Analysis metadata associated with 64 analyses"
)
expect_message(
  mexp <- mrmhub:::import_metadata_features(
    mexp,
    path = path,
    sheet = "Features",
    ignore_warnings = TRUE
  ),
  "Feature metadata associated with 15 features"
)

expect_message(
  mexp <- mrmhub:::import_metadata_istds(
    mexp,
    path = path,
    sheet = "ISTDs",
    ignore_warnings = FALSE
  ),
  "Internal Standard metadata associated with 2 ISTDs"
)


mexp_proc <- mexp
mexp_proc <- normalize_by_istd(mexp_proc)
mexp_proc <- quantify_by_istd(mexp_proc)


test_that("detect_outlier_pca works", {
  outliers <- detect_outlier_pca(
    mexp_proc,
    variable = "intensity",
    filter_data = FALSE,
    qc_types = "BQC",
    outlier_detection = "mad",
    pca_component = 1,
    fence_multiplicator = 2,
    log_transform = TRUE
  )
  expect_equal(outliers, c("194_BQC_PQC_B 06", "195_BQC_PQC_B 07"))

  outliers <- detect_outlier_pca(
    mexp_proc,
    variable = "intensity",
    filter_data = FALSE,
    outlier_detection = "mad",
    pca_component = 1,
    fence_multiplicator = 2,
    log_transform = TRUE
  )
  expect_contains(
    outliers,
    c(
      "194_BQC_PQC_B 06",
      "195_BQC_PQC_B 07",
      "024_SPL_S005",
      "033_SPL_S013",
      "198_LTR_LTR04"
    )
  )

  outliers <- detect_outlier_pca(
    mexp_proc,
    variable = "intensity",
    filter_data = FALSE,
    outlier_detection = "mad",
    pca_component = 1,
    qc_types = "BQC",
    log_transform = TRUE,
    fence_multiplicator = 1.3
  )
  expect_equal(
    outliers,
    c("194_BQC_PQC_B 06", "195_BQC_PQC_B 07")
  )

  outliers <- detect_outlier_pca(
    mexp_proc,
    variable = "intensity",
    filter_data = FALSE,
    outlier_detection = "mad",
    pca_component = 1,
    qc_types = "BQC",
    log_transform = FALSE,
    fence_multiplicator = 1.3
  )
  expect_equal(
    outliers,
    c("194_BQC_PQC_B 06", "195_BQC_PQC_B 07")
  )

  outliers <- detect_outlier_pca(
    mexp_proc,
    variable = "intensity",
    filter_data = FALSE,
    outlier_detection = "sd",
    pca_component = 1,
    qc_types = "BQC",
    log_transform = FALSE,
    fence_multiplicator = 1.3
  )
  expect_equal(outliers, c("194_BQC_PQC_B 06", "195_BQC_PQC_B 07"))

  outliers <- detect_outlier_pca(
    mexp_proc,
    variable = "conc",
    filter_data = FALSE,
    outlier_detection = "mad",
    pca_component = 1,
    qc_types = "BQC",
    log_transform = TRUE,
    fence_multiplicator = 1.3
  )
  expect_equal(
    outliers,
    c("113_BQC_PQC12", "194_BQC_PQC_B 06", "195_BQC_PQC_B 07")
  )

  outliers <- detect_outlier_pca(
    mexp_proc,
    variable = "intensity",
    filter_data = FALSE,
    outlier_detection = "mad",
    pca_component = 2,
    qc_types = "BQC",
    log_transform = TRUE,
    fence_multiplicator = 1.3
  )
  expect_equal(outliers, NULL)
  expect_error(
    outliers <- detect_outlier_pca(
      mexp_proc,
      variable = "intensity",
      filter_data = TRUE,
      outlier_detection = "mad",
      pca_component = 2,
      log_transform = TRUE,
      fence_multiplicator = 1.3
    ),
    "Data has not been qc filtered"
  )

  expect_error(
    outliers <- detect_outlier_pca(
      mexp_proc,
      variable = "intensity",
      filter_data = FALSE,
      outlier_detection = "mad",
      pca_component = 2,
      summarize_fun = "rma",
      log_transform = TRUE,
      fence_multiplicator = 1.3
    ),
    "Relative Mean Abundance"
  )

  expect_error(
    outliers <- detect_outlier_pca(
      mexp_proc,
      variable = "intensity",
      filter_data = FALSE,
      outlier_detection = "mad",
      pca_component = 1,
      qc_types = c("BQC", "XYZ"),
      fence_multiplicator = 2,
      log_transform = TRUE
    ),
    "The following specified QC types are missing in the dataset: \"XYZ\""
  )
})

test_that("detect_outlier_pca() rejects non-positive pca_component / fence_multiplicator", {
  expect_error(
    detect_outlier_pca(
      mexp_proc,
      variable = "intensity",
      filter_data = FALSE,
      pca_component = 0,
      fence_multiplicator = 2
    ),
    "pca_component"
  )
  expect_error(
    detect_outlier_pca(
      mexp_proc,
      variable = "intensity",
      filter_data = FALSE,
      pca_component = 1,
      fence_multiplicator = -1
    ),
    "fence_multiplicator"
  )
})
