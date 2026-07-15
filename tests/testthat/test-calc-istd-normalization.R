# library(testthat)
# library(dplyr)
mexp_orig <- lipidomics_dataset


test_that("Add metadata table by table, the normalize and quantify based on ISTD", {
  mexp <- mrmhub::MRMhubExperiment()
  mexp <- mrmhub::import_data_masshunter(
    mexp,
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
  expect_message(
    mexp <- mrmhub:::import_metadata_responsecurves(
      mexp,
      path = path,
      sheet = "RQCs",
      ignore_warnings = FALSE
    ),
    "Response curve metadata associated with 12 annotated analyses"
  )
  expect_message(
    mexp <- mrmhub:::import_metadata_qcconcentrations(
      mexp,
      path = path,
      sheet = "QCconc",
      ignore_warnings = FALSE
    ),
    "QC concentration metadata associated with 2 annotated samples and 3 annotated analytes"
  )

  testthat::expect_message(
    mexp <- normalize_by_istd(mexp, ignore_missing_annotation = TRUE),
    "13 features normalized with 2 ISTDs in 64 analyses"
  )

  # istd normalized by itself should be 1
  testthat::expect_equal(mexp@dataset$feature_norm_intensity[5], 1)

  testthat::expect_equal(mexp@dataset$feature_norm_intensity[100], 0.175428349)

  # Repeated normalization should give a notification
  testthat::expect_message(
    mexp <- normalize_by_istd(mexp, ignore_missing_annotation = TRUE),
    "Replacing previously normalized feature intensities"
  )
  testthat::expect_message(
    mexp <- normalize_by_istd(mexp, ignore_missing_annotation = TRUE),
    "13 features normalized with 2 ISTDs in 64 analyses"
  )

  mexp_mod <- mexp
  mexp_mod@annot_features <- mexp_mod@annot_features[-13, ]
  testthat::expect_error(
    mexp_mod <- normalize_by_istd(mexp_mod, ignore_missing_annotation = TRUE),
    "1 ISTD\\(s\\) were not defined as individual feature"
  )

  mexp_mod <- mexp
  mexp_mod@annot_features$istd_feature_id <- NA
  testthat::expect_error(
    mexp_mod <- normalize_by_istd(mexp_mod, ignore_missing_annotation = TRUE),
    "No ISTDs defined in feature metadata"
  )

  mexp_mod <- mexp
  mexp_mod@annot_features$istd_feature_id[1] <- NA
  testthat::expect_message(
    mexp_mod <- normalize_by_istd(mexp_mod, ignore_missing_annotation = TRUE),
    "For 1 feature\\(s\\) no ISTD was defined, normalized intensities will be \\`NA"
  )
  testthat::expect_message(
    mexp_mod <- normalize_by_istd(mexp_mod, ignore_missing_annotation = TRUE),
    "12 features normalized with 2 ISTDs in 64"
  )

  testthat::expect_error(
    mexp_mod <- normalize_by_istd(mexp_mod, ignore_missing_annotation = FALSE),
    "For 1 feature\\(s\\) no ISTD was defined. Please ammend feature"
  )

  mexp <- mrmhub::normalize_by_istd(mexp)
  expect_equal(mexp@dataset[[5, "feature_intensity"]], 43545)
  expect_equal(mexp@dataset[[434, "feature_norm_intensity"]], 0.64371386)
  expect_equal(mexp@dataset[[583, "feature_norm_intensity"]], 1.0) # ISTD norm by itself
  expect_equal(mexp@dataset[[583, "is_istd"]], TRUE) # ISTD norm by itself
  expect_equal(mexp@dataset[[583, "is_istd"]], TRUE) # ISTD norm by itself
  mexp <- mrmhub::quantify_by_istd(mexp)
  # expect_equal(mexp@dataset[[583, "feature_pmol_total"]], 4.0)
  expect_equal(mexp@dataset[[583, "feature_conc"]], 0.2) # ISTD norm by itself
  expect_equal(mexp@dataset[[582, "feature_pmol_total"]], 15.6093933)
  expect_equal(mexp@dataset[[582, "feature_conc"]], 0.78046967) # ISTD norm by itself

  expect_equal(dim(mexp@annot_responsecurves), c(12, 5))
  expect_equal(dim(mexp@annot_qcconcentrations), c(6, 6))

  mexp_mod <- mexp
  mexp_mod@annot_analyses$sample_amount[11] <- NA
  testthat::expect_message(
    mexp_mod <- quantify_by_istd(mexp_mod, ignore_missing_annotation = TRUE),
    "Sample and/or ISTD solution amount\\(s\\) for 1 analyses missing, concentrations of all features for these analyses will be \\`NA"
  )
  testthat::expect_message(
    mexp_mod <- quantify_by_istd(mexp_mod, ignore_missing_annotation = TRUE),
    "13 feature concentrations calculated based on 2 ISTDs and sample amounts of 63 analyses"
  )

  testthat::expect_error(
    mexp_mod <- quantify_by_istd(mexp_mod, ignore_missing_annotation = FALSE),
    "Sample and\\/or ISTD amount\\(s\\) for 1 analyses missing. Please ammend"
  )

  mexp_mod <- mexp
  mexp_mod@annot_istds <- mexp_mod@annot_istds[-2, ]
  testthat::expect_error(
    mexp_mod <- quantify_by_istd(mexp_mod, ignore_missing_annotation = FALSE),
    "Concentrations of 1 ISTD\\(s\\) missing. Please ammend ISTD"
  )

  testthat::expect_message(
    mexp_mod <- quantify_by_istd(mexp_mod, ignore_missing_annotation = TRUE),
    "Spiked-in concentrations of 1 ISTD\\(s\\) missing, calculated concentrations of affected features will be \\`NA"
  )

  mexp_mod <- mexp
  mexp_mod@annot_features$istd_feature_id <- NA
  testthat::expect_error(
    mexp_mod <- normalize_by_istd(mexp_mod, ignore_missing_annotation = TRUE),
    "No ISTDs defined in feature metadata"
  )

  mexp_mod <- mexp
  mexp_mod@annot_features$istd_feature_id[1] <- NA
  testthat::expect_message(
    mexp_mod <- normalize_by_istd(mexp_mod, ignore_missing_annotation = TRUE),
    "For 1 feature\\(s\\) no ISTD was defined, normalized intensities will be \\`NA"
  )
  testthat::expect_message(
    mexp_mod <- normalize_by_istd(mexp_mod, ignore_missing_annotation = TRUE),
    "12 features normalized with 2 ISTDs in 64"
  )

  testthat::expect_error(
    mexp_mod <- normalize_by_istd(mexp_mod, ignore_missing_annotation = FALSE),
    "For 1 feature\\(s\\) no ISTD was defined. Please ammend feature"
  )

  testthat::expect_message(
    mexp <- quantify_by_istd(mexp, ignore_missing_annotation = TRUE),
    "13 feature concentrations calculated based on 2 ISTDs and sample amounts of 64 analyses"
  )

  testthat::expect_message(
    mexp <- quantify_by_istd(mexp, ignore_missing_annotation = TRUE),
    "Concentrations are given in μmol/L"
  )

  # istd normalized by itself and quantified should be istd conc corrected for the dilution factor
  testthat::expect_equal(mexp@dataset$feature_conc[5], 0.2)

  testthat::expect_equal(
    mexp@dataset$feature_conc[
      mexp@dataset$analysis_id == "012_TQCd-40_TQC-40percent" &
        mexp@dataset$feature_id == "S1P d18:1 [M>60]"
    ],
    0.663945978
  )

  # Repeated normalization should give a notification
  testthat::expect_message(
    mexp <- quantify_by_istd(mexp, ignore_missing_annotation = TRUE),
    "Replacing previously calculated concentrations"
  )
  testthat::expect_message(
    mexp <- quantify_by_istd(mexp, ignore_missing_annotation = TRUE),
    "13 feature concentrations calculated based on 2 ISTDs and sample amounts of 64 analyses"
  )
})


test_that("quantify_by_istd with mass concentration", {
  mexp <- mrmhub::MRMhubExperiment()
  mexp <- mrmhub::import_data_masshunter(
    mexp,
    path = testthat::test_path(
      "testdata/masshunter/23_Testdata_MHQuant_DefaultSampleInfo_RT-Areas-FWHM_notInSeq_notimestamp.csv"
    ),
    import_metadata = FALSE
  )
  mexp <- mrmhub::import_metadata_msorganiser(
    mexp,
    path = testthat::test_path(
      "testdata/metadata/Metadata_Template_210_MHQuant_S1P_with-ngml.xlsx"
    ),
    excl_unmatched_analyses = FALSE
  )

  mexp <- mrmhub::normalize_by_istd(mexp)

  expect_error(
    mexp <- mrmhub::quantify_by_istd(mexp),
    "ISTD concentrations are defined in both nmolar and ng/mL",
    fixed = TRUE
  )

  mexp_temp <- mexp
  mexp_temp@annot_istds$istd_conc_nmolar <- NA_real_
  mexp_temp@annot_features$chem_formula <- NA_character_
  mexp_temp@annot_features$molecular_weight <- NA_real_

  expect_error(
    mexp_temp <- mrmhub::quantify_by_istd(mexp_temp),
    "Chemical formula or molecular weight is missing for all ISTDs",
    fixed = TRUE
  )

  expect_error(
    mexp_temp <- mrmhub::quantify_by_istd(
      mexp_temp,
      concentration_unit = "mass"
    ),
    "Chemical formula or molecular weight is not defined for the features",
    fixed = TRUE
  )

  mexp_temp <- mexp
  mexp_temp@annot_istds$istd_conc_nmolar <- NA_real_
  mexp_temp@annot_features$chem_formula[1] <- NA_character_
  mexp_temp@annot_features$molecular_weight <- NA_real_

  expect_error(
    mexp_temp <- mrmhub::quantify_by_istd(
      mexp_temp,
      concentration_unit = "mass"
    ),
    "One or more chemical formulas are missing",
    fixed = TRUE
  )

  mexp_temp <- mexp
  mexp_temp@annot_istds$istd_conc_nmolar <- NA_real_
  mexp_temp@annot_features$chem_formula <- NA_character_
  mexp_temp@annot_features$molecular_weight[1] <- 343

  expect_error(
    mexp_temp <- mrmhub::quantify_by_istd(
      mexp_temp,
      concentration_unit = "mass"
    ),
    "One or more molecular weights are missing",
    fixed = TRUE
  )

  mexp_temp <- mexp
  mexp_temp@annot_istds$istd_conc_nmolar <- NA_real_
  mexp_temp <- mrmhub::quantify_by_istd(mexp_temp)
  testthat::expect_equal(
    mexp_temp@dataset$feature_conc[
      mexp_temp@dataset$analysis_id == "012_TQCd-40_TQC-40percent" &
        mexp_temp@dataset$feature_id == "S1P d18:1 [M>60]"
    ],
    0.663945936
  )

  testthat::expect_equal(
    mexp_temp@dataset$feature_conc[
      mexp_temp@dataset$analysis_id == "012_TQCd-40_TQC-40percent" &
        mexp_temp@dataset$feature_id == "S1P d18:1 13C2D2 (ISTD) [M>60]"
    ],
    0.199999987
  )

  mexp_temp <- mexp
  mexp_temp@annot_istds$istd_conc_nmolar <- NA_real_
  mexp_temp <- mrmhub::quantify_by_istd(mexp_temp, ignore_istds = TRUE)
  testthat::expect_equal(
    mexp_temp@dataset$feature_conc[
      mexp_temp@dataset$analysis_id == "012_TQCd-40_TQC-40percent" &
        mexp_temp@dataset$feature_id == "S1P d18:1 13C2D2 (ISTD) [M>60]"
    ],
    NA_real_
  )

  mexp_temp <- mexp
  mexp_temp@annot_istds$istd_conc_nmolar <- NA_real_
  mexp_temp@annot_features$chem_formula <- NA_character_
  mexp_temp@annot_features[c(5, 13), ]$molecular_weight <- 383.47
  mexp_temp <- mrmhub::quantify_by_istd(mexp_temp)
  testthat::expect_equal(
    mexp_temp@dataset$feature_conc[
      mexp_temp@dataset$analysis_id == "012_TQCd-40_TQC-40percent" &
        mexp_temp@dataset$feature_id == "S1P d18:1 [M>60]"
    ],
    0.663945978
  )

  mexp_temp@annot_features[c(5), ]$molecular_weight <- NA_real_
  expect_error(
    mexp_temp <- mrmhub::quantify_by_istd(mexp_temp),
    "One or more ISTDs are missing both chemical formula and molecular weight.",
    fixed = TRUE
  )

  expect_no_error(
    mexp_temp <- mrmhub::quantify_by_istd(
      mexp_temp,
      ignore_missing_annotation = TRUE
    )
  )

  mexp_temp <- mexp
  mexp_temp@annot_istds$istd_conc_nmolar <- NA_real_
  mexp_temp <- mrmhub::quantify_by_istd(mexp_temp, concentration_unit = "mass")

  testthat::expect_equal(
    mexp_temp@dataset$feature_conc[
      mexp_temp@dataset$analysis_id == "012_TQCd-40_TQC-40percent" &
        mexp_temp@dataset$feature_id == "S1P d18:1 [M>60]"
    ],
    251.94920
  )

  mexp <- mrmhub::MRMhubExperiment()
  mexp <- mrmhub::import_data_masshunter(
    mexp,
    path = testthat::test_path(
      "testdata/masshunter/23_Testdata_MHQuant_DefaultSampleInfo_RT-Areas-FWHM_notInSeq_notimestamp.csv"
    ),
    import_metadata = FALSE
  )
  mexp <- mrmhub::import_metadata_msorganiser(
    mexp,
    path = testthat::test_path(
      "testdata/metadata/Metadata_Template_210_MHQuant_S1P_with-ngml-MW.xlsx"
    ),
    excl_unmatched_analyses = FALSE
  )
  mexp <- mrmhub::normalize_by_istd(mexp)

  mexp_temp <- mexp
  mexp_temp@annot_istds$istd_conc_nmolar <- NA_real_
  mexp_temp <- mrmhub::quantify_by_istd(mexp_temp, concentration_unit = "mass")

  testthat::expect_equal(
    mexp_temp@dataset$feature_conc[
      mexp_temp@dataset$analysis_id == "012_TQCd-40_TQC-40percent" &
        mexp_temp@dataset$feature_id == "S1P d18:1 [M>60]"
    ],
    251.949240
  )

  mexp <- mrmhub::normalize_by_istd(mexp)

  mexp_temp <- mexp
  mexp_temp@annot_istds$istd_conc_nmolar <- NA_real_
  mexp_temp@annot_istds$istd_conc_ngml <- NA_real_
  testthat::expect_error(
    mexp_temp <- mrmhub::quantify_by_istd(
      mexp_temp,
      concentration_unit = "mass"
    ),
    "No ISTD concentrations defined. Please define ISTD concentrations in either nmol/L or ng/mL.",
    fixed = TRUE
  )
})

test_that("quantify_by_istd/normalize_by_istd fail if 1 istd not defined", {
  mexp <- mexp_orig
  mexp@annot_istds <- mexp@annot_istds[-1, ]
  mexp_res <- normalize_by_istd(mexp)
  expect_error(
    mexp_res <- quantify_by_istd(mexp_res),
    "Concentrations of 1 ISTD"
  )
})

test_that("quantify_by_istd/normalize_by_istd fail if no istd defined/normalized", {
  mexp <- mexp_orig
  mexp@annot_istds <- mexp@annot_istds[0, ]
  expect_error(
    mexp_res <- quantify_by_istd(mexp),
    "ISTD concentrations are missing...please import ISTD metadata first."
  )

  expect_error(
    mexp_res <- quantify_by_istd(mexp_orig),
    "Data needs to be ISTD normalized"
  )
})

# test_that("istd-based quantification is correct and overwites previous if present", {
#   mexp <- readRDS(file = testthat::test_path("testdata/masshunter/MHQuant_demo.rds"))
#   mexp <- normalize_by_istd(mexp, ignore_missing_annotation = TRUE)

#   testthat::expect_message(
#     mexp <- quantify_by_istd(mexp, ignore_missing_annotation = TRUE),
#     "14 feature concentrations calculated based on 2 ISTDs and sample amounts of 65 analyses"
#   )

#   testthat::expect_message(
#     mexp <- quantify_by_istd(mexp, ignore_missing_annotation = TRUE),
#     "Concentrations are given in μmol/L"
#   )

#   # istd normalized by itself and quantified should be istd conc corrected for the dilution factor
#   testthat::expect_equal(mexp@dataset$feature_conc[5], 0.2)

#   testthat::expect_equal(
#     mexp@dataset$feature_conc[
#       mexp@dataset$analysis_id == "012_TQCd-40_TQC-40percent" &
#         mexp@dataset$feature_id == "S1P d18:1 [M>60]"
#     ],
#     0.663945978
#   )

#   # Repeated normalization should give a notification
#   testthat::expect_message(
#     mexp <- quantify_by_istd(mexp, ignore_missing_annotation = TRUE),
#     "Replacing previously calculated concentrations"
#   )
#   testthat::expect_message(
#     mexp <- quantify_by_istd(mexp, ignore_missing_annotation = TRUE),
#     "14 feature concentrations calculated based on 2 ISTDs and sample amounts of 65 analyses"
#   )
# })

# test_that("istd-based quantification handles missing info correctly", {
#   mexp <- readRDS(file = testthat::test_path("testdata/masshunter/MHQuant_demo.rds"))
#   mexp <- normalize_by_istd(mexp, ignore_missing_annotation = TRUE)

#   mexp_mod <- mexp
#   mexp_mod@annot_analyses$sample_amount[11] <- NA
#   testthat::expect_message(
#     mexp_mod <- quantify_by_istd(mexp_mod, ignore_missing_annotation = TRUE),
#     "Sample and/or ISTD solution amount\\(s\\) for 1 analyses missing, concentrations of all features for these analyses will be \\`NA"
#   )
#   testthat::expect_message(
#     mexp_mod <- quantify_by_istd(mexp_mod, ignore_missing_annotation = TRUE),
#     "14 feature concentrations calculated based on 2 ISTDs and sample amounts of 64 analyses"
#   )

#   testthat::expect_error(
#     mexp_mod <- quantify_by_istd(mexp_mod, ignore_missing_annotation = FALSE),
#     "Sample and\\/or ISTD amount\\(s\\) for 1 analyses missing. Please ammend"
#   )

#   mexp_mod <- mexp
#   mexp_mod@annot_istds <- mexp_mod@annot_istds[-2, ]
#   testthat::expect_error(
#     mexp_mod <- quantify_by_istd(mexp_mod, ignore_missing_annotation = FALSE),
#     "Concentrations of 1 ISTD\\(s\\) missing. Please ammend ISTD"
#   )

#   testthat::expect_message(
#     mexp_mod <- quantify_by_istd(mexp_mod, ignore_missing_annotation = TRUE),
#     "Spiked-in concentrations of 1 ISTD\\(s\\) missing, calculated concentrations of affected features will be \\`NA"
#   )

#   mexp_mod <- mexp
#   mexp_mod@annot_features$istd_feature_id <- NA
#   testthat::expect_error(
#     mexp_mod <- normalize_by_istd(mexp_mod, ignore_missing_annotation = TRUE),
#     "No ISTDs defined in feature metadata"
#   )

#   mexp_mod <- mexp
#   mexp_mod@annot_features$istd_feature_id[1] <- NA
#   testthat::expect_message(
#     mexp_mod <- normalize_by_istd(mexp_mod, ignore_missing_annotation = TRUE),
#     "For 1 feature\\(s\\) no ISTD was defined, normalized intensities will be \\`NA"
#   )
#   testthat::expect_message(
#     mexp_mod <- normalize_by_istd(mexp_mod, ignore_missing_annotation = TRUE),
#     "13 features normalized with 2 ISTDs in 65"
#   )

#   testthat::expect_error(
#     mexp_mod <- normalize_by_istd(mexp_mod, ignore_missing_annotation = FALSE),
#     "For 1 feature\\(s\\) no ISTD was defined. Please ammend feature"
#   )
# })

test_that("quantify_by_istd/normalize_by_istd fail if 1 istd not defined", {
  mexp <- mexp_orig
  mexp@annot_istds <- mexp@annot_istds[-1, ]
  mexp_res <- normalize_by_istd(mexp)
  expect_error(
    mexp_res <- quantify_by_istd(mexp_res),
    "Concentrations of 1 ISTD"
  )
})

test_that("quantify_by_istd/normalize_by_istd fail if no istd defined/normalized", {
  mexp <- mexp_orig
  mexp@annot_istds <- mexp@annot_istds[0, ]
  expect_error(
    mexp_res <- quantify_by_istd(mexp),
    "ISTD concentrations are missing...please import ISTD metadata first."
  )

  expect_error(
    mexp_res <- quantify_by_istd(mexp_orig),
    "Data needs to be ISTD normalized"
  )
})

test_that("istd-based norm and quantification are correct, another test", {
  mexp_orig <- lipidomics_dataset
  mexp <- mexp_orig
  mexp_res <- normalize_by_istd(mexp)
  mexp_res <- quantify_by_istd(mexp_res)

  # mexp_res@dataset$feature_id[100] # PC 49:8
  # mexp_res@dataset$analysis_id[100]   #"Longit_LTR 01"
  # mexp_res@dataset$feature_id[98] #"PC 33:1 d7 (ISTD)"
  # mexp_res@dataset$analysis_id[98]  #"Longit_LTR 01"
  conc_istd = mexp_res@annot_istds$istd_conc_nmolar[4] #PC 33:1 d7 (ISTD)

  # check/get raw areas
  expect_equal(mexp_res@dataset$feature_intensity[100], 70530.266)
  expect_equal(mexp_res@dataset$feature_intensity[98], 2933433.3)

  # check/get raw normalzied areas
  expect_equal(
    mexp_res@dataset$feature_norm_intensity[100],
    70530.266 / 2933433.3,
    tolerance = 0.0000000001
  )
  expect_equal(
    mexp_res@dataset$feature_norm_intensity[98],
    1,
    tolerance = 0.0000000001
  )

  # check/get conc
  expect_equal(
    mexp_res@dataset$feature_conc[100],
    70530.266 / 2933433.3 * 4.5 / 10 * 212.45 / 1000,
    tolerance = 0.0000000001
  )
  expect_equal(
    mexp_res@dataset$feature_conc[98],
    1 * 4.5 / 10 * 212.45 / 1000,
    tolerance = 0.0000000001
  )
})

test_that("normalize_by_istd sets a zero-ISTD divisor to NA (not Inf) and warns", {
  mexp <- lipidomics_dataset
  istd_fid <- mexp@annot_features |>
    dplyr::filter(.data$is_istd) |>
    dplyr::pull(.data$feature_id) |>
    head(1)
  an <- unique(mexp@dataset$analysis_id)[1]
  grp_feat <- mexp@annot_features |>
    dplyr::filter(.data$istd_feature_id == istd_fid, !.data$is_istd) |>
    dplyr::pull(.data$feature_id) |>
    head(1)

  # Zero the internal standard intensity for a single analysis; without the
  # guard this divisor would yield Inf/NaN for every feature in the ISTD group.
  mexp@dataset$feature_intensity[
    mexp@dataset$feature_id == istd_fid & mexp@dataset$analysis_id == an
  ] <- 0

  suppressMessages(
    expect_warning(
      mexp_res <- normalize_by_istd(mexp),
      "zero intensity"
    )
  )

  # The affected feature is NA, and no value in the column is Inf/NaN
  affected <- mexp_res@dataset$feature_norm_intensity[
    mexp_res@dataset$feature_id == grp_feat & mexp_res@dataset$analysis_id == an
  ]
  expect_true(is.na(affected))
  expect_false(any(
    is.infinite(mexp_res@dataset$feature_norm_intensity) |
      is.nan(mexp_res@dataset$feature_norm_intensity),
    na.rm = TRUE
  ))
})

test_that("normalize_by_istd errors cleanly on an empty experiment", {
  expect_error(
    normalize_by_istd(mrmhub::MRMhubExperiment()),
    "No feature metadata available"
  )
})
