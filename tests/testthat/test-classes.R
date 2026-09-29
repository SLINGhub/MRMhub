mexp_empty <- MRMhubExperiment(
  title = "Test Experiment",
  analysis_type = "lipidomics"
)
mexp <- lipidomics_dataset


mexp_proc <- mexp
mexp_proc <- normalize_by_istd(mexp_proc)
mexp_proc <- quantify_by_istd(mexp_proc)

test_that("Construct MRMhubExperiments", {
  expect_type(MRMhubExperiment(), "S4")
  expect_equal(as.character(class(MRMhubExperiment())), "MRMhubExperiment")
  mexp <- MRMhubExperiment(title = "Test", analysis_type = "lipidomics")
  expect_equal(mexp@title, "Test")
  expect_equal(mexp@analysis_type, "lipidomics")
  expect_equal(
    MRMhubExperiment(analysis_type = "externalcalib")@analysis_type,
    "externalcalib"
  )
  expect_error(
    mexp <- MRMhubExperiment(title = "Test", analysis_type = "undefined"),
    "must be one of"
  )
})

test_that(" MRMhubExperiments setter/getter work", {
  mexp <- MRMhubExperiment(title = "Test", analysis_type = "lipidomics")
  expect_equal(mexp@analysis_type, "lipidomics")

  expect_error(
    mexp <- MRMhubExperiment(title = "Test", analysis_type = "undefined"),
    "must be one of"
  )
})

test_that("MRMhubExperiment $ accessor works correctly", {
  mexp <- MRMhubExperiment(
    title = "Test Experiment",
    analysis_type = "lipidomics"
  )

  #  accessing valid slots
  expect_equal(mexp$title, "Test Experiment")
  expect_equal(mexp$analysis_type, "lipidomics")

  # invalid slot
  expect_error(mexp$invalid_slot, "is not valid for this object")
})


test_that("compact show method displays title and signal", {
  mexp <- MRMhubExperiment(
    title = "Test Experiment",
    analysis_type = "lipidomics"
  )
  compact <- toString(cli::cli_fmt(show(mexp)))
  expect_match(compact, "Test Experiment")
  expect_match(compact, "Normalized")
})

test_that("mrmhub_status() displays composition, metadata and exclusions", {
  compact <- toString(cli::cli_fmt(print(mexp)))
  expect_match(compact, "feature_area")

  text_output <- toString(cli::cli_fmt(mrmhub_status(mexp)))
  expect_match(text_output, "Analyses manually excluded")
  mexp <- exclude_analyses(
    mexp,
    c("Longit_batch1_4", "Longit_batch6_51"),
    clear_existing = TRUE
  )
  mexp <- exclude_features(mexp, c("PC 32:1", "PC 40:8"), clear_existing = TRUE)
  text_output <- toString(cli::cli_fmt(mrmhub_status(mexp)))
  expect_match(text_output, "Longit_batch1_4", fixed = TRUE)
  expect_match(text_output, "PC 32:1, and PC 40:8", fixed = TRUE)
})


test_that("get_status_flag works", {
  expect_equal(get_status_flag(TRUE), "v")
  expect_equal(get_status_flag(FALSE), "x")
})

test_that("check_data works", {
  expect_no_error(check_data(mexp))
  expect_no_error(check_data(mexp_empty))
  expect_error(check_data(NULL), "cannot be")
  expect_error(check_data(tibble(a = 1)), "must be an")
})
