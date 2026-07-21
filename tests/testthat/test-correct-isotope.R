#mexp_orig <- readRDS(file = testthat::test_path("testdata/masshunter/MHQuant_demo.rds"))
#mexp <- mexp_orig

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

mexp_orig <- mexp

mexp2 <- lipidomics_dataset

mexp2@annot_features$interference_contribution[9] <- 0.5

test_that("correct_interference_manual warns when interference_contribution > 1", {
  expect_message(
    correct_interference_manual(
      mexp_orig,
      variable = "feature_intensity",
      feature = "S1P d18:1 [M>60]",
      interfering_feature = "S1P d18:2 [M>60]",
      interference_contribution = 1.5
    ),
    "greater than 1"
  )
})

test_that("correct_custom_interferences corrects overlapping interferences", {
  # d18:2 is interfering with d18:1, which in turn is interfering with d18:0
  # the code does not correct for M+4 isotope interference

  # Check initial uncorrected values

  expect_equal(
    mexp@dataset |>
      filter(
        feature_id == "S1P d18:2 [M>60]",
        analysis_id == "008_LTR_LTR01"
      ) |>
      pull(feature_intensity),
    31526
  )

  expect_equal(
    mexp@dataset |>
      filter(
        feature_id == "S1P d18:1 [M>60]",
        analysis_id == "008_LTR_LTR01"
      ) |>
      pull(feature_intensity),
    85299
  )

  expect_equal(
    mexp@dataset |>
      filter(
        feature_id == "S1P d18:0 [M>60]",
        analysis_id == "008_LTR_LTR01"
      ) |>
      pull(feature_intensity),
    9919
  )

  # Apply correction and check corrected values, with sequential correction enabled

  expect_message(
    mexp_res <-
      correct_custom_interferences(
        mexp,
        variable = "feature_intensity",
        sequential_correction = TRUE
      ),
    "applied to 4 of 15 feature"
  )

  expect_equal(
    mexp_res@dataset |>
      filter(
        feature_id == "S1P d18:2 [M>60]",
        analysis_id == "008_LTR_LTR01"
      ) |>
      pull(feature_intensity),
    31526
  )

  expect_equal(
    mexp_res@dataset |>
      filter(
        feature_id == "S1P d18:1 [M>60]",
        analysis_id == "008_LTR_LTR01"
      ) |>
      pull(feature_intensity),
    84304.7172490
  )

  # corrrected with corrected S1P d18:1
  expect_equal(
    mexp_res@dataset |>
      filter(
        feature_id == "S1P d18:0 [M>60]",
        analysis_id == "008_LTR_LTR01"
      ) |>
      pull(feature_intensity),
    7256.0500353124
  )

  # reapply
  expect_message(
    mexp_res <-
      correct_custom_interferences(
        mexp_res,
        variable = "feature_intensity",
        sequential_correction = TRUE
      ),
    "applied to 4 of 15 feature"
  )

  expect_equal(
    mexp_res@dataset |>
      filter(
        feature_id == "S1P d18:1 [M>60]",
        analysis_id == "008_LTR_LTR01"
      ) |>
      pull(feature_intensity),
    84304.7172490
  )

  # corrrected with corrected S1P d18:1
  expect_equal(
    mexp_res@dataset |>
      filter(
        feature_id == "S1P d18:0 [M>60]",
        analysis_id == "008_LTR_LTR01"
      ) |>
      pull(feature_intensity),
    7256.0500353124
  )

  # Apply correction and check corrected values, with sequential correction disabled

  expect_message(
    mexp_res <-
      correct_custom_interferences(
        mexp,
        variable = "feature_intensity",
        sequential_correction = FALSE
      ),
    "applied to 4 of 15 feature"
  )

  expect_equal(
    mexp_res@dataset |>
      filter(
        feature_id == "S1P d18:2 [M>60]",
        analysis_id == "008_LTR_LTR01"
      ) |>
      pull(feature_intensity),
    31526
  )

  expect_equal(
    mexp_res@dataset |>
      filter(
        feature_id == "S1P d18:1 [M>60]",
        analysis_id == "008_LTR_LTR01"
      ) |>
      pull(feature_intensity),
    84304.7172490
  )

  # corrrected based on raw S1P d18:1 intensity
  expect_equal(
    mexp_res@dataset |>
      filter(
        feature_id == "S1P d18:0 [M>60]",
        analysis_id == "008_LTR_LTR01"
      ) |>
      pull(feature_intensity),
    7224.6434272
  )
})


test_that("correct_custom_interferences corrects overlapping interferences", {
  # d18:2 is interfering with d18:1, which in turn is interfering with d18:0
  # the code does not correct for M+4 isotope interference

  mexp2 <- mexp_orig

  expect_equal(
    mexp2@dataset |>
      filter(
        feature_id == "S1P d18:1 [M>60]",
        analysis_id == "008_LTR_LTR01"
      ) |>
      pull(feature_intensity),
    85299
  )

  expect_message(
    mexp2 <- correct_interference_manual(
      mexp2,
      variable = "feature_intensity",
      feature = "S1P d18:1 [M>60]",
      interfering_feature = "S1P d18:2 [M>60]",
      interference_contribution = 0.0315385
    ),
    "Interference-correction was manually applied to "
  )

  expect_equal(
    mexp2@dataset |>
      filter(
        feature_id == "S1P d18:1 [M>60]",
        analysis_id == "008_LTR_LTR01"
      ) |>
      pull(feature_intensity),
    84304.7172490
  )

  # test renaming of feature and additional correction
  mexp2 <- correct_interference_manual(
    mexp2,
    variable = "feature_intensity",
    feature = "S1P d18:0 [M>60]",
    interfering_feature = "S1P d18:1 [M>60]",
    interference_contribution = 0.0315872,
    updated_feature_id = "S1P d18:0 [M>60] corrected"
  )

  expect_equal(
    mexp2@dataset |>
      filter(
        feature_id == "S1P d18:0 [M>60] corrected",
        analysis_id == "008_LTR_LTR01"
      ) |>
      pull(feature_intensity),
    7256.0500353124
  )

  expect_error(
    mexp2 <- correct_interference_manual(
      mexp2,
      variable = "var_undefined",
      feature = "S1P d18:0 [M>60]",
      interfering_feature = "S1P d18:1 [M>60]",
      interference_contribution = 0.0315872,
      updated_feature_id = "S1P d18:0 [M>60] corrected"
    ),
    "Variable `var_undefined` is not"
  )

  expect_error(
    mexp2 <- correct_interference_manual(
      mexp2,
      variable = "feature_intensity",
      feature = "S1P d18:0 [M>601]",
      interfering_feature = "S1P d18:1 [M>60]",
      interference_contribution = 0.0315872,
      updated_feature_id = "S1P d18:0 [M>60] corrected"
    ),
    "Selected feature is not present in the dataset"
  )

  expect_error(
    mexp2 <- correct_interference_manual(
      mexp2,
      variable = "feature_intensity",
      feature = "S1P d18:0 [M>60]",
      interfering_feature = "S1P d18:3 [M>60]",
      interference_contribution = 0.0315872,
      updated_feature_id = "S1P d18:0 [M>60] corrected"
    ),
    "Selected interfering feature is not present"
  )

  expect_error(
    mexp2 <- correct_interference_manual(
      mexp2,
      variable = "feature_intensity",
      feature = "S1P d18:0 [M>60]",
      interfering_feature = "S1P d18:1 [M>60]",
      interference_contribution = NA,
      updated_feature_id = "S1P d18:0 [M>60] corrected"
    ),
    "must be a number larger than 0",
    fixed = TRUE
  )

  expect_error(
    mexp2 <- correct_interference_manual(
      mexp2,
      variable = "feature_intensity",
      feature = "S1P d18:0 [M>60]",
      interfering_feature = "S1P d18:1 [M>60]",
      interference_contribution = 0.1,
      updated_feature_id = "S1P d18:2 [M>60]"
    ),
    "is already present in the dataset"
  )
})

test_that("Handles corrections that lead to negative values", {
  expect_message(
    mexp3 <- correct_interference_manual(
      mexp2,
      variable = "feature_intensity",
      feature = "PC 28:0|SM 32:1 M+3",
      interfering_feature = "SM 32:1",
      interference_contribution = 0.1,
      updated_feature_id = "PC 28:0"
    ),
    "Interference correction led to 478 negative or zero values in 1 feature (samples/QCs). Please verify",
    fixed = TRUE
  )

  a <- mexp3@dataset |>
    group_by(feature_id) |>
    summarise(nas = sum(is.na(feature_intensity)))

  expect_equal(max(a$nas), 0)

  expect_message(
    mexp3 <- correct_interference_manual(
      mexp2,
      variable = "feature_intensity",
      feature = "PC 28:0|SM 32:1 M+3",
      interfering_feature = "SM 32:1",
      interference_contribution = 0.1,
      neg_to_na = TRUE,
      updated_feature_id = "PC 28:0"
    ),
    "Interference correction led to 478 negative or zero values in 1 feature (samples/QCs). All negative/zero values",
    fixed = TRUE
  )

  a <- mexp3@dataset |>
    group_by(feature_id) |>
    summarise(nas = sum(is.na(feature_intensity)))

  expect_equal(max(a$nas), 479)

  expect_message(
    mexp_res <-
      correct_custom_interferences(
        mexp2,
        variable = "feature_intensity",
        sequential_correction = TRUE
      ),
    "Interference correction led to 495 negative or zero values in 1 feature (samples/QCs). Please verify ",
    fixed = TRUE
  )

  expect_message(
    mexp_res <-
      correct_custom_interferences(
        mexp2,
        variable = "feature_intensity",
        sequential_correction = TRUE,
        neg_to_na = TRUE
      ),
    "Interference correction led to 495 negative or zero values in 1 feature (samples/QCs). All negative/zero values ",
    fixed = TRUE
  )
})

test_that("correct_custom_interferences does not crash when a corrected value is NA", {
  # If an interfering feature's intensity is NA in an analysis, the target's
  # corrected value becomes NA. The negative-value summary must tolerate that
  # (previously `sum(x <= 0)` without na.rm made `if (sum(...) > 0)` error).
  mexp_na <- mexp
  msk <- mexp_na@dataset$feature_id == "S1P d18:2 [M>60]" &
    mexp_na@dataset$analysis_id == "008_LTR_LTR01"
  expect_gt(sum(msk), 0)
  mexp_na@dataset$feature_intensity[msk] <- NA_real_

  expect_no_error(
    suppressMessages(correct_custom_interferences(
      mexp_na,
      variable = "feature_intensity",
      sequential_correction = TRUE
    ))
  )
})

test_that("correct_custom_interferences reports a friendly error on a circular interference chain", {
  # Close the d18:2 -> d18:1 -> d18:0 chain into a cycle (d18:2 -> d18:0).
  mexp_circ <- mexp
  af <- mexp_circ@annot_features
  sel <- af$feature_id == "S1P d18:2 [M>60]"
  af$interference_feature_id[sel] <- "S1P d18:0 [M>60]"
  af$interference_contribution[sel] <- 0.1
  mexp_circ@annot_features <- af

  expect_error(
    suppressMessages(correct_custom_interferences(
      mexp_circ,
      variable = "feature_intensity",
      sequential_correction = TRUE
    )),
    "circular correction"
  )
})

test_that("interference correction is not discarded by a later batch correction", {
  ft <- "PC 28:0|SM 32:1 M+3"
  getv <- function(d) d@dataset$feature_intensity[d@dataset$feature_id == ft]
  batch <- function(d) {
    suppressWarnings(suppressMessages(correct_batch_centering(
      d,
      variable = "feature_intensity",
      ref_qc_types = "BQC"
    )))
  }

  b1 <- batch(lipidomics_dataset)
  expect_true(b1@var_batch_corrected[["feature_intensity"]])
  expect_true("feature_intensity_before" %in% names(b1@dataset))

  i1 <- suppressWarnings(suppressMessages(correct_custom_interferences(b1)))
  # the correction actually moves values, otherwise the test proves nothing
  expect_false(isTRUE(all.equal(getv(b1), getv(i1))))
  # rewriting feature_intensity invalidates the previous batch correction of it
  expect_false(i1@var_batch_corrected[["feature_intensity"]])

  # `replace_previous = TRUE` (the default) restores the variable from the
  # `_before` snapshot. That snapshot predates the interference correction, so a
  # stale var_batch_corrected flag silently reverted it.
  with_corr <- batch(i1)
  without_corr <- batch(b1)
  expect_false(isTRUE(all.equal(getv(with_corr), getv(without_corr))))
})


test_that("correct_isotopic_interferences aborts when nothing has been derived", {
  expect_error(
    suppressMessages(correct_isotopic_interferences(mexp)),
    "No isotopic interferences"
  )
})

test_that("correct_custom_interferences warns when no custom interferences are defined", {
  mexp_none <- mexp
  mexp_none@annot_features$interference_feature_id <- NA_character_
  mexp_none@annot_features$interference_contribution <- NA_real_
  expect_message(
    correct_custom_interferences(mexp_none),
    "No custom"
  )
})

test_that("self-interference is rejected in the correction engine", {
  mexp_self <- mexp
  af <- mexp_self@annot_features
  sel <- which(!is.na(af$interference_feature_id))[1]
  af$interference_feature_id[sel] <- af$feature_id[sel]
  mexp_self@annot_features <- af
  expect_error(
    suppressMessages(correct_custom_interferences(mexp_self)),
    "cannot interfere with itself"
  )
})

test_that("correct_interference_manual rejects self-interference", {
  expect_error(
    correct_interference_manual(
      mexp_orig,
      variable = "feature_intensity",
      feature = "S1P d18:1 [M>60]",
      interfering_feature = "S1P d18:1 [M>60]",
      interference_contribution = 0.03
    ),
    "cannot interfere with itself"
  )
})

test_that("correct_interference_manual warns when re-correcting a feature", {
  m <- suppressMessages(correct_interference_manual(
    mexp_orig,
    variable = "feature_intensity",
    feature = "S1P d18:1 [M>60]",
    interfering_feature = "S1P d18:2 [M>60]",
    interference_contribution = 0.03
  ))
  expect_message(
    correct_interference_manual(
      m,
      variable = "feature_intensity",
      feature = "S1P d18:1 [M>60]",
      interfering_feature = "S1P d18:2 [M>60]",
      interference_contribution = 0.03
    ),
    "already interference-corrected"
  )
})

test_that("summarize_interferences returns the assembled edge rollup", {
  res <- suppressMessages(summarize_interferences(mexp))
  expect_s3_class(res, "tbl_df")
  expect_gt(nrow(res), 0)
  expect_true(
    all(
      c("feature_id", "interference_feature_id", "source") %in% names(res)
    )
  )
})


test_that("correction tolerates a feature absent from some analyses (ragged data)", {
  # A corrected feature (or its interferer) missing from an analysis must not
  # error via a length-0 `if_else()` recycle (e.g. blanks lacking a transition).
  m <- MRMhubExperiment()
  m@dataset <- dplyr::tibble(
    analysis_id = c("a1", "a1", "a1", "a2", "a2"),
    feature_id = c("F0", "F1", "F2", "F0", "F1"), # a2 lacks F2
    qc_type = factor("SPL"),
    feature_intensity = c(100, 50, 20, 80, 40)
  )
  m@dataset_orig <- dplyr::tibble(
    analysis_id = "a1",
    raw_data_filename = "f",
    acquisition_time_stamp = as.Date("2024-01-01"),
    feature_id = c("F0", "F1", "F2")
  )
  m@annot_features <- dplyr::tibble(
    feature_id = c("F0", "F1", "F2"),
    is_istd = FALSE,
    interference_feature_id = c(NA, "F0", "F1"),
    interference_contribution = c(NA, 0.1, 0.1)
  )
  expect_no_error(
    res <- suppressWarnings(suppressMessages(correct_custom_interferences(m)))
  )
  # F1 in a1 corrected by F0: 50 - 0.1*100 = 40
  expect_equal(
    res@dataset$feature_intensity[
      res@dataset$analysis_id == "a1" & res@dataset$feature_id == "F1"
    ],
    40
  )
})
