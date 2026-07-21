# library(testthat)
# library(tibble)
# library(cli)
# library(dplyr)

test_that("Imports/associates data and metadata, orders analyses by dataset (timestamp missing)", {
  mexp <- mrmhub::MRMhubExperiment()
  mexp <- mrmhub::import_data_masshunter(
    mexp,
    path = testthat::test_path(
      "testdata/masshunter/23_MHQuant_notInSeq_notimestamp.csv"
    ),
    import_metadata = FALSE
  )
  mexp <- mrmhub::import_metadata_msorganiser(
    mexp,
    path = testthat::test_path(
      "testdata/metadata/MRMhub_Metadata_Template_191_20240226_MHQuant_S1P_V1.xlsx"
    ),
    excl_unmatched_analyses = FALSE
  )
  expect_equal(mexp@dataset[[1, "analysis_id"]], "020_SPL_S001")
  expect_equal(dim(mexp@annot_analyses), c(65, 13))
  expect_equal(dim(mexp@annot_features), c(16, 18))
  expect_equal(dim(mexp@annot_istds), c(2, 5))
  expect_equal(dim(mexp@annot_responsecurves), c(12, 5))
  expect_equal(dim(mexp@annot_batches), c(3, 4))
  expect_equal(dim(mexp@annot_qcconcentrations), c(6, 6))
  expect_in(
    c(
      "analysis_order",
      "batch_id",
      "is_quantifier",
      "qc_type",
      "is_istd",
      "is_quantifier"
    ),
    names(mexp@dataset)
  )
})

test_that("import_metadata_msorganiser handles missing / invalid files", {
  mexp <- mrmhub::MRMhubExperiment()
  mexp <- mrmhub::import_data_masshunter(
    mexp,
    path = testthat::test_path(
      "testdata/masshunter/22_MHQuant_notInSeq-noalphafeat.csv"
    ),
    import_metadata = FALSE
  )
  expect_error(
    mexp <- mrmhub::import_metadata_msorganiser(
      mexp,
      path = testthat::test_path("Does not exist.xlsx"),
      excl_unmatched_analyses = FALSE
    ),
    "File not found. Please verify path"
  )

  expect_error(
    mexp <- mrmhub::import_metadata_msorganiser(
      mexp,
      path = testthat::test_path(
        "testdata/masshunter/MRMhub_MHQuant_S1P.csv"
      ),
      excl_unmatched_analyses = FALSE
    ),
    "Invalid file type not. A MSOrganiser template",
    fixed = TRUE
  )

  expect_error(
    mexp <- mrmhub::import_metadata_msorganiser(
      mexp,
      path = testthat::test_path(
        "testdata/metadata/MRMhub_Metadata_Template_wrongabout.xlsx"
      ),
      excl_unmatched_analyses = FALSE
    ),
    "This appears to be an invalid or unsupported MSOrganiser template file.",
    fixed = TRUE
  )

  expect_error(
    mexp <- mrmhub::import_metadata_msorganiser(
      mexp,
      path = testthat::test_path(
        "testdata/metadata/MRMhub_Metadata_Template_missingabout.xlsx"
      ),
      excl_unmatched_analyses = FALSE
    ),
    "This appears to be an invalid or unsupported MSOrganiser template file, without `About`",
    fixed = TRUE
  )

  expect_error(
    mexp <- mrmhub::import_metadata_msorganiser(
      mexp,
      path = testthat::test_path(
        "testdata/metadata/MRMhub_Metadata_Template_lowerversion.xlsx"
      ),
      excl_unmatched_analyses = FALSE
    ),
    "Unsupported MSOrganiser template version. Please use an MSOrganiser template v0.2 or higher.",
    fixed = TRUE
  )
  expect_error(
    mexp <- mrmhub::import_metadata_msorganiser(
      mexp,
      path = testthat::test_path(
        "testdata/metadata/MRMhub_Metadata_Template_higherversion.xlsx"
      ),
      excl_unmatched_analyses = FALSE
    ),
    "Unsupported MSOrganiser template version. Please use an MSOrganiser template v0.2 or higher.",
    fixed = TRUE
  )

  expect_error(
    mexp <- mrmhub::import_metadata_msorganiser(
      mexp,
      path = testthat::test_path(
        "testdata/metadata/MRMhub_Metadata_Template_invalidversion.xlsx"
      ),
      excl_unmatched_analyses = FALSE
    ),
    "Invalid version number found in the template. Please",
    fixed = TRUE
  )
})


test_that("Imports/associates data and metadata, orders features by default according to order in metadata", {
  mexp <- mrmhub::MRMhubExperiment()
  mexp <- mrmhub::import_data_masshunter(
    mexp,
    path = testthat::test_path(
      "testdata/masshunter/22_MHQuant_notInSeq-noalphafeat.csv"
    ),
    import_metadata = FALSE
  )
  mexp <- mrmhub::import_metadata_msorganiser(
    mexp,
    path = testthat::test_path(
      "testdata/metadata/MRMhub_Metadata_Template_191_20240226_MHQuant_S1P_V1.xlsx"
    ),
    excl_unmatched_analyses = FALSE
  )
  expect_equal(
    mexp@dataset_orig[1, ] |> pull("feature_id"),
    "S1P d18:0 [M>113]"
  )
  expect_equal(mexp@dataset[1, ] |> pull("feature_id"), "S1P d16:1 [M>60]")
})


test_that("Raise data assertion warning and stops with not all analyses defined in analysis metadata ", {
  mexp <- mrmhub::MRMhubExperiment()
  mexp <- mrmhub::import_data_masshunter(
    mexp,
    path = testthat::test_path(
      "testdata/masshunter/22_MHQuant_notInSeq-noalphafeat.csv"
    ),
    import_metadata = FALSE
  )
  expect_error(
    mexp <- mrmhub::import_metadata_msorganiser(
      mexp,
      path = testthat::test_path(
        "testdata/metadata/MRMhub_Metadata_191_MHQuant_S1P_analysissubset.xlsx"
      ),
      excl_unmatched_analyses = FALSE
    ),
    "Not all analyses in the data have corresponding metadata"
  )
})

test_that("Metadata matching zero analyses errors instead of reporting green 0-match success (bug 3.3)", {
  mexp <- mrmhub::MRMhubExperiment()
  mexp <- mrmhub::import_data_masshunter(
    mexp,
    path = testthat::test_path(
      "testdata/masshunter/23_MHQuant_notInSeq_notimestamp.csv"
    ),
    import_metadata = FALSE
  )
  mexp_ok <- mrmhub::import_metadata_msorganiser(
    mexp,
    path = testthat::test_path(
      "testdata/metadata/MRMhub_Metadata_Template_191_20240226_MHQuant_S1P_V1.xlsx"
    ),
    excl_unmatched_analyses = FALSE
  )
  # Rename every metadata analysis_id so none matches the data (100% unmatched).
  meta <- list(
    annot_analyses = mexp_ok@annot_analyses |>
      dplyr::mutate(analysis_id = paste0("nomatch_", .data$analysis_id))
  )
  expect_error(
    add_metadata(mexp, meta),
    "None of the analyses in the data match"
  )
})

test_that("Shows analyses defined in metadata but missing in data as Note in assertion table, instead of Warning and proceeds", {
  mexp <- mrmhub::MRMhubExperiment()
  mexp <- mrmhub::import_data_masshunter(
    mexp,
    path = testthat::test_path(
      "testdata/masshunter/22_MHQuant_notInSeq-noalphafeat.csv"
    ),
    import_metadata = FALSE
  )
  mexp <- mrmhub::import_metadata_msorganiser(
    mexp,
    path = testthat::test_path(
      "testdata/metadata/MRMhub_Metadata_191_MHQuant_S1P_analysissubset.xlsx"
    ),
    excl_unmatched_analyses = TRUE
  )

  expect_equal(
    mexp@dataset_orig[1, ] |> pull("feature_id"),
    "S1P d18:0 [M>113]"
  )
  expect_equal(mexp@dataset[1, ] |> pull("feature_id"), "S1P d16:1 [M>60]")
})

test_that("Ignores warnings after metadata import and proceeds", {
  mexp <- mrmhub::MRMhubExperiment()
  mexp <- mrmhub::import_data_masshunter(
    mexp,
    path = testthat::test_path(
      "testdata/masshunter/22_MHQuant_notInSeq-noalphafeat.csv"
    ),
    import_metadata = FALSE
  )
  mexp <- mrmhub::import_metadata_msorganiser(
    mexp,
    path = testthat::test_path(
      "testdata/metadata/MRMhub_Metadata_191_MHQuant_S1P_analysissubset.xlsx"
    ),
    ignore_warnings = TRUE
  )

  expect_equal(
    mexp@dataset_orig[1, ] |> pull("feature_id"),
    "S1P d18:0 [M>113]"
  )
  expect_equal(mexp@dataset[1, ] |> pull("feature_id"), "S1P d16:1 [M>60]")
})


test_that("Stale assertr warnings on pre-existing tables are not carried into a partial re-validation (bug 3.4)", {
  mexp <- mrmhub::MRMhubExperiment()
  mexp <- mrmhub::import_data_masshunter(
    mexp,
    path = testthat::test_path(
      "testdata/masshunter/22_MHQuant_notInSeq-noalphafeat.csv"
    ),
    import_metadata = FALSE
  )
  # First import leaves a real "Analyses without metadata" note as an
  # assertr_errors attribute on annot_analyses.
  mexp <- mrmhub::import_metadata_msorganiser(
    mexp,
    path = testthat::test_path(
      "testdata/metadata/MRMhub_Metadata_191_MHQuant_S1P_analysissubset.xlsx"
    ),
    excl_unmatched_analyses = TRUE
  )
  expect_false(is.null(attr(mexp@annot_analyses, "assertr_errors")))

  # A later validation that does NOT re-provide annot_analyses must not restore
  # (and re-report) its stale attribute.
  res <- assert_metadata(
    mexp,
    metadata = list(annot_features = mexp@annot_features),
    ignore_warnings = FALSE,
    excl_unmatched_analyses = TRUE
  )
  expect_null(attr(res$annot_analyses, "assertr_errors"))
})


test_that("Reads metadata from csv file", {
  path <- testthat::test_path("testdata/metadata/sperfect_metadata_tables.csv")
  tbl <- get_metadata_table(path = path)
  expect_equal(tbl[[1, "analysis_id"]], "Longit_BLANK-01 (Eluent A)")
  expect_equal(tbl[[1, "sample_amount"]], 10)
})

test_that("Reads metadata from XLSX sheet", {
  path <- testthat::test_path("testdata/metadata/sperfect_metadata_tables.xlsx")
  tbl <- get_metadata_table(path = path, sheet = "Analyses")
  expect_equal(tbl[[1, "analysis_id"]], "Longit_BLANK-01 (Eluent A)")
  expect_equal(tbl[[1, "sample_amount"]], 10)
})

test_that("Reads metadata from XLSX sheet", {
  path <- testthat::test_path("testdata/metadata/sperfect_metadata_tables.xlsx")
  tbl <- get_metadata_table(path = path, sheet = "Features")
  expect_equal(tbl[[1, "feature_id"]], "CE 14:0")
  expect_equal(tbl[[224, "interference_contribution"]], 0.00774513)
})

test_that("Reads metadata from given data frame", {
  path <- testthat::test_path("testdata/metadata/sperfect_metadata_tables.csv")
  df <- readr::read_csv(file = path, show_col_types = FALSE)
  tbl <- get_metadata_table(dataset = df)
  expect_equal(tbl[[1, "analysis_id"]], "Longit_BLANK-01 (Eluent A)")
  expect_equal(tbl[[1, "sample_amount"]], 10)
})


test_that("Reads metadata from given data frame", {
  path <- testthat::test_path("testdata/metadata/sperfect_metadata_tables.csv")
  df <- readr::read_csv(file = path, show_col_types = FALSE)
  expect_error(
    get_metadata_table(path = path, dataset = df),
    regexp = "cannot be specified at the same time"
  )
})


test_that("Prepare analysis metadata from given data file", {
  path <- testthat::test_path("testdata/metadata/sperfect_metadata_tables.csv")
  tbl <- get_metadata_table(path = path) |> dplyr::select(-"batch_id")
  metadata <- clean_analysis_metadata(tbl)
  expect_in(c("batch_id", "replicate_no", "valid_analysis"), names(metadata))
  expect_equal(metadata[[1, "valid_analysis"]], TRUE)
})

test_that("Prepare analysis metadata from given data file", {
  path <- testthat::test_path("testdata/metadata/sperfect_metadata_tables.csv")
  tbl <- get_metadata_table(path = path) |> select(-"batch_id")
  metadata <- clean_analysis_metadata(tbl)
  expect_in(c("batch_id", "replicate_no", "valid_analysis"), names(metadata))
  expect_equal(metadata[[1, "valid_analysis"]], TRUE)
  expect_error(
    clean_analysis_metadata(tbl |> select(-"analysis_id")),
    regexp = "Analysis (Sample) metadata must have the `analysis_id` columnn",
    fixed = TRUE
  )
})

test_that("Prepare feature metadata from given table imported from an XLSX sheet", {
  path <- testthat::test_path("testdata/metadata/sperfect_metadata_tables.xlsx")
  tbl <- get_metadata_table(path = path, sheet = "Features")
  metadata <- clean_feature_metadata(tbl)
  expect_type(metadata$response_factor, "double")
  expect_type(metadata$interference_contribution, "double")
  expect_type(metadata$is_quantifier, "logical")
  expect_type(metadata$valid_feature, "logical")
  expect_equal(metadata[[1, "feature_id"]], "CE 14:0")
  expect_error(
    clean_istd_metadata(tbl |> select(-"feature_id")),
    regexp = "must have following columns"
  )
})

test_that("Prepare istd metadata from given table imported from an XLSX sheet", {
  path <- testthat::test_path("testdata/metadata/sperfect_metadata_tables.xlsx")
  tbl <- get_metadata_table(path = path, sheet = "ISTDs")
  metadata <- clean_istd_metadata(tbl)
  expect_type(metadata$quant_istd_feature_id, "character")
  expect_type(metadata$istd_conc_nmolar, "double")
  expect_type(metadata$remarks, "character")
  expect_equal(metadata[[1, "quant_istd_feature_id"]], "CE 18:1 d7 (ISTD)")
  expect_equal(nrow(metadata), 19)
  expect_error(
    clean_istd_metadata(tbl |> select(-"istd_feature_id")),
    regexp = "must have following columns"
  )
})

test_that("Prepare rqc metadata from given table imported from an XLSX sheet", {
  path <- testthat::test_path("testdata/metadata/sperfect_metadata_tables.xlsx")
  tbl <- get_metadata_table(path = path, sheet = "RQCs")
  metadata <- clean_response_metadata(tbl)
  expect_type(metadata$analysis_id, "character")
  expect_type(metadata$analyzed_amount, "double")
  expect_type(metadata$analyzed_amount_unit, "character")
  expect_type(metadata$remarks, "character")
  expect_equal(metadata[[1, "analysis_id"]], "Longit_TQC-10%")
  expect_equal(nrow(metadata), 12)
  expect_error(
    clean_response_metadata(tbl |> select(-"curve_id")),
    regexp = "must have following columns"
  )
})

test_that("Prepare qc concentration metadata from given table imported from an XLSX sheet", {
  path <- testthat::test_path("testdata/metadata/sperfect_metadata_tables.xlsx")
  tbl <- get_metadata_table(path = path, sheet = "QCconc")
  metadata <- clean_qcconc_metadata(tbl)
  expect_type(metadata$sample_id, "character")
  expect_type(metadata$analyte_id, "character")
  expect_type(metadata$concentration, "double")
  expect_type(metadata$concentration_unit, "character")
  expect_type(metadata$remarks, "character")
  expect_equal(metadata[[1, "sample_id"]], "199_NIST_NIST04")
  expect_equal(metadata[[2, "sample_id"]], "198_LTR_LTR04")
  expect_equal(metadata[[3, "concentration"]], 0.1)
  expect_equal(nrow(metadata), 6)
  expect_equal(ncol(metadata), 6)
  expect_error(
    clean_qcconc_metadata(tbl |> select(-"analyte_id")),
    regexp = "must have following columns"
  )
})

test_that("clean_analysis_metadata strips extensions like the data side (bug 2.1: silent join loss)", {
  # Names the old unanchored, .wiff2-less metadata regex corrupted, so the
  # analysis silently dropped out of the data<->metadata inner_join:
  #  - a mid-name ".d" (inside ".data") -> "Studyata_01.d" -> no match
  #  - ".wiff2" (absent from the metadata regex) -> "sample2"  -> no match
  raw <- c("Study.data_01.d", "sample.wiff2", "Study_01.d ")
  meta <- clean_analysis_metadata(data.frame(analysis_id = raw))

  # Metadata side now equals what the data side produces (both route through
  # strip_raw_extension) -> the join keys agree.
  expect_equal(meta$analysis_id, strip_raw_extension(raw))
  expect_equal(meta$analysis_id, c("Study.data_01", "sample", "Study_01"))

  # The join no longer drops rows: data-side ids match metadata-side ids.
  joined <- dplyr::inner_join(
    tibble::tibble(analysis_id = strip_raw_extension(raw), x = 1:3),
    tibble::tibble(analysis_id = meta$analysis_id, y = 1:3),
    by = "analysis_id"
  )
  expect_equal(nrow(joined), 3L)
})

test_that("clean_response_metadata strips analysis_id extensions consistently (bug 2.1)", {
  tbl <- data.frame(
    analysis_id = c("Study.data_01.d", "sample.wiff2"),
    curve_id = c("c1", "c1"),
    analyzed_amount = c(1, 2),
    analyzed_amount_unit = c("ng", "ng")
  )
  meta <- clean_response_metadata(tbl)
  expect_equal(meta$analysis_id, c("Study.data_01", "sample"))
})

test_that("clean_qcconc_metadata strips sample_id extensions consistently (bug 2.1)", {
  tbl <- data.frame(
    sample_id = c("Study.data_01.d", "sample.wiff2"),
    analyte_id = c("a1", "a2"),
    concentration = c(0.1, 0.2),
    concentration_unit = c("uM", "uM")
  )
  meta <- clean_qcconc_metadata(tbl)
  expect_equal(meta$sample_id, c("Study.data_01", "sample"))
})

test_that("Add indidual metadata types to data, first analyses then features", {
  mexp <- mrmhub::MRMhubExperiment()
  mexp <- mrmhub::import_data_masshunter(
    mexp,
    path = testthat::test_path(
      "testdata/masshunter/MRMhub_MHQuant_S1P.csv"
    ),
    import_metadata = FALSE
  )
  path <- testthat::test_path(
    "testdata/metadata/MRMhub_TestData_MHQuant_S1P_metadata_tables.xlsx"
  )
  mexp <- mrmhub:::import_metadata_analyses(
    mexp,
    path = path,
    sheet = "Analyses",
    excl_unmatched_analyses = TRUE
  )
  expect_equal(mexp@dataset[[10, "feature_intensity"]], 43545)
  expect_in(
    c("sample_id", "feature_class", "is_istd", "is_quantifier"),
    names(mexp@dataset)
  )
  mexp <- mrmhub:::import_metadata_features(
    mexp,
    path = path,
    sheet = "Features",
    ignore_warnings = TRUE
  )
  #expect_equal(mexp@annot_features[[245, "interference_contribution" ]], 43545)
  expect_equal(mexp@dataset[[5, "feature_intensity"]], 43545)
  expect_equal(mexp@dataset[[5, "feature_class"]], "SPBP")
  expect_equal(mexp@dataset[[5, "is_istd"]], TRUE)
  expect_in(
    c("sample_id", "feature_class", "is_istd", "is_quantifier"),
    names(mexp@dataset)
  )
})


test_that("Add indidual metadata types to data, first features then analyses", {
  mexp <- mrmhub::MRMhubExperiment()
  mexp <- mrmhub::import_data_masshunter(
    mexp,
    path = testthat::test_path(
      "testdata/masshunter/MRMhub_MHQuant_S1P.csv"
    ),
    import_metadata = FALSE
  )
  path <- testthat::test_path(
    "testdata/metadata/MRMhub_TestData_MHQuant_S1P_metadata_tables.xlsx"
  )
  mexp <- mrmhub:::import_metadata_features(
    mexp,
    path = path,
    sheet = "Features",
    ignore_warnings = TRUE
  )
  expect_equal(mexp@dataset[[5, "feature_intensity"]], 43545)
  expect_equal(mexp@dataset[[5, "feature_class"]], "SPBP")
  expect_true(is.na(mexp@dataset[[1, "batch_id"]]))
  expect_true(is.na(mexp@dataset[[1, "qc_type"]]))
  mexp <- mrmhub:::import_metadata_analyses(
    mexp,
    path = path,
    sheet = "Analyses",
    excl_unmatched_analyses = TRUE,
    ignore_warnings = TRUE
  )
  expect_equal(mexp@dataset[[5, "feature_intensity"]], 43545)
  expect_in(
    c("sample_id", "feature_class", "is_istd", "is_quantifier"),
    names(mexp@dataset)
  )
  expect_equal(mexp@dataset[[5, "qc_type"]], "PBLK")
  expect_equal(mexp@dataset[[5, "batch_id"]], "1")
})

test_that("Check import of inconsitent metadata", {
  mexp <- mrmhub::MRMhubExperiment()
  mexp <- mrmhub::import_data_masshunter(
    mexp,
    path = testthat::test_path(
      "testdata/masshunter/MRMhub_MHQuant_S1P.csv"
    ),
    import_metadata = FALSE
  )
  path <- testthat::test_path(
    "testdata/metadata/MRMhub_TestData_MHQuant_S1P_metadata_tables.xlsx"
  )
  expect_error(
    mexp <- mrmhub:::import_metadata_analyses(
      mexp,
      path = path,
      sheet = "Analyses_Inconsistent",
      excl_unmatched_analyses = TRUE
    ),
    "`valid_analysis` is inconsistently defined"
  )
  expect_error(
    mexp <- mrmhub:::import_metadata_features(
      mexp,
      path = path,
      sheet = "Features_Inconsist_Both"
    ),
    "`valid_feature` is inconsistently defined, i.e., not for one or more features. Please"
  )
  expect_error(
    mexp <- mrmhub:::import_metadata_features(
      mexp,
      path = path,
      sheet = "Features_Inconsist_qual"
    ),
    "`is_quantifier` is inconsistently defined, i.e., not for one or more features. Please"
  )
  expect_error(
    mexp <- mrmhub:::import_metadata_features(
      mexp,
      path = path,
      sheet = "Features_Inconsist_val"
    ),
    "`valid_feature` is inconsistently defined, i.e., not for one or more features. Please"
  )

  expect_error(
    mexp <- mrmhub:::import_metadata_features(
      mexp,
      path = path,
      sheet = "Features_inval_interf"
    )
  )
  expect_error(
    mexp <- mrmhub:::import_metadata_features(
      mexp,
      path = path,
      sheet = "Features_miss_interf"
    )
  )
})

test_that("Replacing specific undefined metadata", {
  mexp <- mrmhub::MRMhubExperiment()
  mexp <- mrmhub::import_data_masshunter(
    mexp,
    path = testthat::test_path(
      "testdata/masshunter/MRMhub_MHQuant_S1P.csv"
    ),
    import_metadata = FALSE
  )
  path <- testthat::test_path(
    "testdata/metadata/MRMhub_TestData_MHQuant_S1P_metadata_tables.xlsx"
  )
  mexp <- mrmhub:::import_metadata_analyses(
    mexp,
    path = path,
    sheet = "Analyses_missing_val",
    excl_unmatched_analyses = TRUE
  )
  expect_true(all(mexp@annot_analyses$valid_analysis))

  mexp2 <- mrmhub:::import_metadata_features(
    mexp,
    path = path,
    sheet = "Features_missing_val",
    ignore_warnings = TRUE
  )
  expect_true(all(mexp@annot_features$valid_feature))

  mexp2 <- mrmhub:::import_metadata_features(
    mexp,
    path = path,
    sheet = "Features_missing_quan",
    ignore_warnings = TRUE
  )
  expect_true(all(mexp@annot_features$is_quantifier))

  expect_error(
    mexp <- mrmhub:::import_metadata_features(
      mexp,
      path = path,
      sheet = "Features_rfzero"
    ),
    "Please verify warnings in corresponding metadata"
  )

  expect_error(
    mexp <- mrmhub:::import_metadata_features(
      mexp,
      path = path,
      sheet = "Features_intefzero"
    ),
    "Please verify warnings in corresponding metadata"
  )
})

test_that("assert_metadata rejects duplicated analysis_id keys", {
  mexp <- mrmhub::MRMhubExperiment()
  mexp <- mrmhub::import_data_masshunter(
    mexp,
    path = testthat::test_path(
      "testdata/masshunter/MRMhub_MHQuant_S1P.csv"
    ),
    import_metadata = FALSE
  )
  analyses <- get_metadata_table(
    path = testthat::test_path(
      "testdata/metadata/MRMhub_TestData_MHQuant_S1P_metadata_tables.xlsx"
    ),
    sheet = "Analyses"
  )

  # Positive control: the unperturbed table imports without error
  expect_no_error(
    mrmhub::import_metadata_analyses(
      mexp,
      table = analyses,
      excl_unmatched_analyses = TRUE
    )
  )

  # A duplicated analysis_id is caught by the `is_uniq` assertion
  analyses_dup <- dplyr::bind_rows(analyses, analyses[1, ])
  expect_error(
    mrmhub::import_metadata_analyses(
      mexp,
      table = analyses_dup,
      excl_unmatched_analyses = TRUE
    ),
    "Metadata validation failed"
  )
})

test_that("assert_metadata rejects duplicated (sample_id, analyte_id) in QC concentrations", {
  mexp <- quant_lcms_dataset
  qc <- mexp@annot_qcconcentrations

  # Positive control: the unperturbed concentration table validates.
  expect_no_error(
    mrmhub:::assert_metadata(
      mexp,
      metadata = list(annot_qcconcentrations = qc),
      ignore_warnings = TRUE,
      excl_unmatched_analyses = FALSE
    )
  )

  # A duplicated (sample_id, analyte_id) row would silently double a calibrator
  # level / QC target, so it must be rejected at import (obligatory E defect).
  qc_dup <- dplyr::bind_rows(qc, qc[1, ])
  expect_error(
    mrmhub:::assert_metadata(
      mexp,
      metadata = list(annot_qcconcentrations = qc_dup),
      ignore_warnings = FALSE,
      excl_unmatched_analyses = FALSE
    ),
    "Metadata validation failed"
  )
})

test_that("missing qc_type and valid_analysis are filled with forgiving defaults, not errors", {
  mexp <- mrmhub::MRMhubExperiment()
  mexp <- mrmhub::import_data_masshunter(
    mexp,
    path = testthat::test_path(
      "testdata/masshunter/MRMhub_MHQuant_S1P.csv"
    ),
    import_metadata = FALSE
  )
  analyses <- get_metadata_table(
    path = testthat::test_path(
      "testdata/metadata/MRMhub_TestData_MHQuant_S1P_metadata_tables.xlsx"
    ),
    sheet = "Analyses"
  )
  id1 <- analyses$analysis_id[[1]]

  # Missing qc_type is treated as a study sample ("SPL"), so the not_na
  # assertion never fires -- a blank value is a documented default, not an error.
  analyses_na_qc <- analyses
  analyses_na_qc$qc_type[1] <- NA
  out_na <- mrmhub::import_metadata_analyses(
    mexp,
    table = analyses_na_qc,
    excl_unmatched_analyses = TRUE
  )
  qc_na <- out_na@annot_analyses$qc_type[
    out_na@annot_analyses$analysis_id == id1
  ]
  expect_equal(qc_na, "SPL")

  # The literal "Sample" is an alias for "SPL"
  analyses_sample <- analyses
  analyses_sample$qc_type[1] <- "Sample"
  out_sample <- mrmhub::import_metadata_analyses(
    mexp,
    table = analyses_sample,
    excl_unmatched_analyses = TRUE
  )
  qc_sample <- out_sample@annot_analyses$qc_type[
    out_sample@annot_analyses$analysis_id == id1
  ]
  expect_equal(qc_sample, "SPL")

  # valid_analysis undefined for *all* analyses defaults to TRUE (undefined for
  # only some is the inconsistency error covered above)
  analyses_na_valid <- analyses
  analyses_na_valid$valid_analysis <- NA
  out_valid <- mrmhub::import_metadata_analyses(
    mexp,
    table = analyses_na_valid,
    excl_unmatched_analyses = TRUE
  )
  expect_true(all(out_valid@annot_analyses$valid_analysis))
  expect_false(any(is.na(out_valid@annot_analyses$valid_analysis)))
})

test_that("an unrecognized qc_type is warned about and preserved, then drops to NA under the standard levels", {
  mexp <- mrmhub::MRMhubExperiment()
  mexp <- mrmhub::import_data_masshunter(
    mexp,
    path = testthat::test_path(
      "testdata/masshunter/MRMhub_MHQuant_S1P.csv"
    ),
    import_metadata = FALSE
  )
  analyses <- get_metadata_table(
    path = testthat::test_path(
      "testdata/metadata/MRMhub_TestData_MHQuant_S1P_metadata_tables.xlsx"
    ),
    sheet = "Analyses"
  )
  id1 <- analyses$analysis_id[[1]]
  analyses$qc_type[1] <- "WEIRD"

  # A custom qc_type is surfaced with a warning but retained (not dropped) at
  # import -- custom values are permitted for non-standard workflows.
  suppressMessages(
    expect_warning(
      mexp_res <- mrmhub::import_metadata_analyses(
        mexp,
        table = analyses,
        excl_unmatched_analyses = TRUE
      ),
      "Unrecognized"
    )
  )
  qc_col <- mexp_res@annot_analyses$qc_type
  expect_type(qc_col, "character")
  expect_equal(qc_col[mexp_res@annot_analyses$analysis_id == id1], "WEIRD")

  # Standard QC computations and plots coerce qc_type via the canonical levels,
  # which drops the unknown value to NA (a known value is retained).
  qc_levels <- mrmhub:::pkg.env$qc_type_annotation$qc_type_levels
  expect_true(is.na(factor("WEIRD", levels = qc_levels)))
  expect_false(is.na(factor("SPL", levels = qc_levels)))
})

test_that("clean_* coerce character numeric metadata columns to numeric", {
  # Previously clean_istd_metadata coerced starts_with("feature_conc_") -- a
  # no-op, since the columns are istd_conc_*, so ISTD concentrations stayed
  # character. Sample amount / istd volume / MW / concentration read from CSV
  # were likewise left as character.
  istd <- mrmhub:::clean_istd_metadata(
    dplyr::tibble(istd_feature_id = "X", istd_conc_nmolar = "5.5")
  )
  expect_type(istd$istd_conc_nmolar, "double")

  qc <- mrmhub:::clean_qcconc_metadata(dplyr::tibble(
    sample_id = "S",
    analyte_id = "A",
    concentration = "3.2",
    concentration_unit = "uM"
  ))
  expect_type(qc$concentration, "double")

  an <- mrmhub:::clean_analysis_metadata(dplyr::tibble(
    analysis_id = "a1",
    sample_amount = "10",
    istd_volume = "5"
  ))
  expect_type(an$sample_amount, "double")
  expect_type(an$istd_volume, "double")

  ft <- mrmhub:::clean_feature_metadata(dplyr::tibble(
    feature_id = "F",
    molecular_weight = "200"
  ))
  expect_type(ft$molecular_weight, "double")
})

test_that("clean_* drop stray rows and headerless columns with a warning", {
  # A row whose key is NA (a leftover cell elsewhere) is dropped and surfaced.
  expect_warning(
    r <- mrmhub:::clean_feature_metadata(
      dplyr::tibble(feature_id = c("A", NA), feature_class = c("x", "STRAY"))
    ),
    "stray row"
  )
  expect_setequal(r$feature_id[!is.na(r$feature_id)], "A")

  # A column with a blank header is a stray spreadsheet column -> dropped/warned.
  d <- dplyr::tibble(feature_id = c("A", "B"), z = c("x", "y"))
  names(d)[2] <- ""
  expect_warning(mrmhub:::clean_feature_metadata(d), "unnamed column")
})

test_that("metadata validation warns (overridably) on <=0 divisors, notes on missing", {
  mexp <- mrmhub::import_data_masshunter(
    mrmhub::MRMhubExperiment(),
    testthat::test_path(
      "testdata/masshunter/MRMhub_MHQuant_S1P.csv"
    ),
    import_metadata = FALSE
  )
  ids <- unique(mexp@dataset_orig$analysis_id)
  base_df <- dplyr::tibble(analysis_id = ids, qc_type = "SPL")

  # A present <=0 sample_amount corrupts the concentration divisor -> W, which
  # blocks by default but can be overridden with ignore_warnings = TRUE.
  df_neg <- base_df |>
    dplyr::mutate(sample_amount = c(-5, rep(10, length(ids) - 1)))
  expect_error(
    suppressMessages(mrmhub::import_metadata_analyses(mexp, table = df_neg)),
    "verify warnings"
  )
  expect_no_error(
    suppressMessages(
      mrmhub::import_metadata_analyses(
        mexp,
        table = df_neg,
        ignore_warnings = TRUE
      )
    )
  )

  # A *missing* sample_amount is processable (only needed if quantifying, which
  # guards it) -> N, which never blocks.
  df_na <- base_df |>
    dplyr::mutate(sample_amount = c(NA_real_, rep(10, length(ids) - 1)))
  expect_no_error(
    suppressMessages(mrmhub::import_metadata_analyses(mexp, table = df_na))
  )
})
