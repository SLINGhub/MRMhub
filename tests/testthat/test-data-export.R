# library(fs)
# library(ggplot2)
# library(openxlsx2)
# library(readr)
# library(testthat)
set.seed(123)

mexp_orig <- lipidomics_dataset

mexp <- normalize_by_istd(mexp_orig)
mexp <- quantify_by_istd(mexp)
mexp_empty <- MRMhubExperiment()
mexp_filt <- filter_features_qc(
  mexp,
  include_qualifier = FALSE,
  include_istd = FALSE,
  max.cv.conc.bqc = 20
)
mexp@title <- "Test Experiment"
mexp <- calc_qc_metrics(mexp) # Ensure calc_qc_metrics is executed before
mexp_drift <- correct_drift_gaussiankernel(
  mexp_orig,
  variable = "intensity",
  ref_qc_types = "SPL",
  ignore_istd = FALSE
)


test_that("save_report_xlsx creates an Excel file", {
  temp_file <- tempfile(fileext = ".xlsx")

  expect_message(
    save_report_xlsx(data = mexp, path = temp_file),
    "The data processing report of experiment 'Test Experiment' has been saved to"
  )

  expect_true(file.exists(temp_file))
  on.exit(unlink(temp_file)) # Clean up
})

test_that("save_report_xlsx adds .xlsx extension if not provided", {
  temp_file <- tempfile()
  mexp@title <- ""
  expect_message(
    save_report_xlsx(data = mexp, path = temp_file),
    "The data processing report has been saved to"
  )

  expect_true(file.exists(paste0(temp_file, ".xlsx")))
  unlink(paste0(temp_file, ".xlsx")) # Clean up
})

test_that("save_report_xlsx creates the correct sheets", {
  temp_file <- tempfile(fileext = ".xlsx")

  save_report_xlsx(data = mexp, path = temp_file)

  # Load the workbook and check for sheets
  w_xlm <- openxlsx2::wb_load(temp_file)
  expected_sheets <- c(
    "Info",
    "Feature_QC_metrics",
    "Calibration_metrics",
    "QCfilt_StudySamples",
    "QCfilt_AllSamples",
    "Conc_FullDataset",
    "Raw_Intensity_FullDataset",
    "Norm_Intensity_FullDataset",
    "SampleMetadata",
    "FeatureMetadata",
    "InternalStandards",
    "BatchInfo",
    "Interferences"
  )

  expect_setequal(w_xlm$sheet_names, expected_sheets)
  on.exit(unlink(temp_file)) # Clean up
})

test_that("save_report_xlsx inluded feature-filtered data", {
  temp_file <- tempfile(fileext = ".xlsx")

  save_report_xlsx(
    data = mexp_filt,
    path = temp_file,
    filtered_variable = "norm_intensity"
  )

  # Load the workbook and check for sheets
  w_xlm <- openxlsx2::wb_load(temp_file)
  expected_sheets <- c(
    "Info",
    "Feature_QC_metrics",
    "Calibration_metrics",
    "QCfilt_NormInt_StudySamples",
    "QCfilt_NormInt_AllSamples",
    "Conc_FullDataset",
    "Raw_Intensity_FullDataset",
    "Norm_Intensity_FullDataset",
    "SampleMetadata",
    "FeatureMetadata",
    "InternalStandards",
    "BatchInfo",
    "Interferences"
  )
  expect_setequal(w_xlm$sheet_names, expected_sheets)
  tbl <- openxlsx2::wb_to_df(temp_file, sheet = "QCfilt_NormInt_StudySamples")
  expect_equal(dim(tbl), c(374, 19))
  tbl <- openxlsx2::wb_to_df(temp_file, sheet = "QCfilt_NormInt_AllSamples")
  expect_equal(dim(tbl), c(499, 20))
  on.exit(unlink(temp_file)) # Clean up
})

test_that("save_report_xlsx handles missing data", {
  # Create a dataset with missing fields
  mexp_empty <- MRMhubExperiment()

  temp_file <- tempfile(fileext = ".xlsx")

  save_report_xlsx(data = mexp_empty, path = temp_file)

  # Verify the file creation
  expect_true(file.exists(temp_file))

  # Optionally, verify the content
  wb <- openxlsx2::wb_to_df(temp_file, sheet = "Raw_Intensity_FullDataset")
  expect_true(all(is.na(wb[["No annotated raw data available."]])))

  on.exit(unlink(temp_file)) # Clean up
})


test_that("Function exports correct variables", {
  temp_file <- tempfile(fileext = ".csv")
  expect_message(
    save_dataset_csv(
      data = mexp,
      path = temp_file,
      variable = "intensity",
      filter_data = FALSE
    ),
    "Intensity values for 499 analyses and 29 features"
  )

  exported_data <- readr::read_csv(temp_file)
  expect_true("analysis_id" %in% colnames(exported_data))
  expect_true("SM 36:2 d9 (ISTD)" %in% colnames(exported_data))
  expect_false("feature_intensity" %in% colnames(exported_data))
  expect_equal(mean(exported_data$`PC 40:6`), 3293741.4)

  temp_file <- tempfile(fileext = ".csv")
  expect_message(
    save_dataset_csv(
      data = mexp,
      path = temp_file,
      variable = "conc",
      filter_data = FALSE
    ),
    "Concentration values for 499 analyses and 19 features"
  )

  exported_data <- readr::read_csv(temp_file)
  expect_true("analysis_id" %in% colnames(exported_data))
  expect_false("SM 36:2 d9 (ISTD)" %in% colnames(exported_data))
  expect_false("feature_conc" %in% colnames(exported_data))
  expect_equal(mean(exported_data$`PC 40:6`), 0.082982104)
})

test_that("QC-filtered data is used when filter_data is TRUE", {
  temp_file <- tempfile(fileext = ".csv")
  expect_message(
    save_dataset_csv(
      data = mexp_filt,
      path = temp_file,
      variable = "area",
      filter_data = TRUE
    ),
    "Area values for 499 analyses and 18 features"
  )

  exported_data <- readr::read_csv(temp_file)
  expect_equal(dim(exported_data), c(499, 19))
})

test_that("QC-filtered data is used when filter_data is TRUE", {
  temp_file <- tempfile(fileext = ".csv")
  expect_message(
    save_dataset_csv(
      data = mexp_filt,
      path = temp_file,
      variable = "area",
      filter_data = TRUE,
      add_qctype = TRUE
    ),
    "Area values for 499 analyses and 18 features"
  )

  exported_data <- readr::read_csv(temp_file)
  expect_equal(dim(exported_data), c(499, 20))
  expect_true("qc_type" %in% colnames(exported_data))
})

test_that("Function handles non-existent variable gracefully", {
  expect_error(
    save_dataset_csv(
      data = mexp,
      path = tempfile(),
      variable = "non_existent_var",
      filter_data = FALSE
    ),
    regexp = "`variable` must be one of"
  )
})


test_that("QC types filtering works correctly", {
  temp_file <- tempfile(fileext = ".csv")
  save_dataset_csv(
    data = mexp,
    path = temp_file,
    variable = "intensity",
    filter_data = FALSE,
    qc_types = c("SPL", "BQC"),
    add_qctype = TRUE
  )

  exported_data <- readr::read_csv(temp_file)
  expect_equal(unique(exported_data$qc_type), c("BQC", "SPL"))
})


# Test when the data is NULL
test_that("save_feature_qc_metrics handles NULL data input", {
  expect_error(
    save_feature_qc_metrics(mexp_empty, "output.csv"),
    "Feature QC metrics has not yet been"
  )
})

# Test when the QC metrics are present
test_that("save_feature_qc_metrics exports QC metrics to CSV", {
  # Use a temporary file path to ensure tests do not interfere with actual files
  temp_file <- tempfile(fileext = ".csv")
  on.exit(unlink(temp_file)) # Ensure the temporary file is deleted after the test

  # Run the function and check it doesn't return errors
  expect_message(
    dat <- save_feature_qc_metrics(mexp_filt, temp_file),
    "Feature QC metrics table was saved"
  )

  expect_equal(dim(dat), c(29, 92))
  # Check if the file was created
  expect_true(file.exists(temp_file))

  # Read the file and compare with original data
  written_data <- readr::read_csv(temp_file)
  expect_equal(dim(written_data), c(29, 92))
})


test_that("save_metadata_templates() copies the file correctly and sends correct errors if required", {
  temp_file <- tempfile(fileext = "test.xlsx")

  expect_message(
    save_metadata_templates(temp_file),
    "Metadata table templates were saved to"
  )
  expect_true(file.exists(temp_file))
  expect_error(
    save_metadata_templates(temp_file),
    "A file with this name already exists at the specified location."
  )
  unlink(temp_file)

  default_file <- "metadata_template.xlsx"
  if (file.exists(default_file)) {
    unlink(default_file)
  }

  expect_message(
    save_metadata_templates(),
    "Metadata table templates were saved to 'metadata_template.xlsx'"
  )
  expect_true(file.exists(default_file))
  unlink(default_file)
})

# test_that("save_metadata_templates() returns an error if template is missing", {
#   # Temporarily change the system.file() return to an empty string
#   mock_template_path <- function(...) { "" }
#
#   with_mocked_bindings(
#     `system.file` = mock_template_path,
#     .package = "mrmhub",
#     expect_error(save_metadata_templates(tempfile()), "Template file not found in package")
#   )
# })

test_that("save_metadata_msorganiser_template() copies the file correctly and sends correct errors if required", {
  temp_file <- tempfile(fileext = ".xlsx")

  expect_message(
    save_metadata_msorganiser_template(temp_file),
    "A MRMhub Metadata Organizer template was saved"
  )
  expect_true(file.exists(temp_file))
  expect_error(
    save_metadata_msorganiser_template(temp_file),
    "A file with this name already exists at the specified location."
  )
  unlink(temp_file)

  default_file <- "metadata_msorganiser_template.xlsx"
  if (file.exists(default_file)) {
    unlink(default_file)
  }

  expect_message(
    save_metadata_msorganiser_template(),
    "A MRMhub Metadata Organizer template was saved to 'metadata_msorganiser_template.xlsx'"
  )
  expect_true(file.exists(default_file))
  unlink(default_file)
})
#
# test_that("save_metadata_templates() returns an error if template is missing", {
#   # Temporarily change the system.file() return to an empty string
#   mock_template_path <- function(...) { "" }
#
#   with_mocked_bindings(
#     `system.file` = mock_template_path,
#     .package = "mrmhub",
#     expect_error(save_metadata_msorganiser_template(tempfile()), "Template file not found in package")
#   )
# })

test_that("save_report_xlsx aborts on duplicate (analysis, feature) rows", {
  temp_file <- tempfile(fileext = ".xlsx")
  on.exit(unlink(temp_file))

  # A duplicated (analysis_id, feature_id) row would make pivot_wider produce a
  # list-column in the exported wide sheets; the values_fn guard aborts instead.
  mexp_dup <- mexp
  mexp_dup@dataset <- dplyr::bind_rows(mexp_dup@dataset, mexp_dup@dataset[1, ])

  suppressMessages(
    expect_error(
      save_report_xlsx(data = mexp_dup, path = temp_file),
      "more than one value per cell"
    )
  )
})

test_that("save_dataset_csv() / save_feature_qc_metrics() reject an invalid path", {
  expect_error(
    save_dataset_csv(mexp, path = c("a.csv", "b.csv"), variable = "intensity"),
    "must be a single"
  )
  expect_error(
    save_dataset_csv(mexp, path = NA_character_, variable = "intensity"),
    "must be a single"
  )
  expect_error(
    save_feature_qc_metrics(mexp, path = 42),
    "must be a single"
  )
})

test_that("save_dataset_rds() writes the file and round-trips the object", {
  f <- withr::local_tempfile(fileext = ".rds")

  expect_message(
    save_dataset_rds(mexp, f),
    "MRMhubExperiment saved to"
  )
  expect_true(file.exists(f))

  mexp2 <- suppressMessages(read_dataset_rds(f))
  expect_equal(mexp2, mexp)
})

test_that("save_dataset_rds() appends the .rds extension when missing", {
  f <- withr::local_tempfile()
  suppressMessages(save_dataset_rds(mexp, f))
  expect_true(file.exists(paste0(f, ".rds")))
})

test_that("save_dataset_rds() respects overwrite = FALSE", {
  f <- withr::local_tempfile(fileext = ".rds")
  suppressMessages(save_dataset_rds(mexp, f))
  expect_error(
    save_dataset_rds(mexp, f, overwrite = FALSE),
    "already exists"
  )
})

test_that("save_dataset_rds() writes an uncompressed file that round-trips", {
  f_gz <- withr::local_tempfile(fileext = ".rds")
  f_raw <- withr::local_tempfile(fileext = ".rds")
  suppressMessages(save_dataset_rds(mexp, f_gz, compress = TRUE))
  suppressMessages(save_dataset_rds(mexp, f_raw, compress = FALSE))

  expect_gt(file.info(f_raw)$size, file.info(f_gz)$size)
  expect_equal(suppressMessages(read_dataset_rds(f_raw)), mexp)
})

test_that("read_dataset_rds() aborts on a non-MRMhubExperiment file", {
  f <- withr::local_tempfile(fileext = ".rds")
  saveRDS(1:10, f)
  expect_error(read_dataset_rds(f), "MRMhubExperiment")
})

test_that("read_dataset_rds() aborts when the file does not exist", {
  expect_error(
    read_dataset_rds(file.path(tempdir(), "does-not-exist.rds")),
    "does not exist"
  )
})

test_that("read_dataset_rds() verifies the embedded fingerprint", {
  f <- withr::local_tempfile(fileext = ".rds")
  suppressMessages(save_dataset_rds(mexp, f, hash = TRUE))
  expect_message(read_dataset_rds(f), "fingerprint verified")
})

test_that("read_dataset_rds() reports a fingerprint mismatch", {
  f <- withr::local_tempfile(fileext = ".rds")
  tampered <- mexp
  attr(tampered, "mrmhub_hash") <- "deadbeef"
  saveRDS(tampered, f)
  expect_message(read_dataset_rds(f), "mismatch")
})

test_that("read_dataset_rds() skips verification when no fingerprint is embedded", {
  f <- withr::local_tempfile(fileext = ".rds")
  suppressMessages(save_dataset_rds(mexp, f, hash = FALSE))
  expect_message(read_dataset_rds(f), "No embedded fingerprint")
})

test_that("read_dataset_rds() prints the full status when show_status = TRUE", {
  f <- withr::local_tempfile(fileext = ".rds")
  suppressMessages(save_dataset_rds(mexp, f))
  expect_message(
    read_dataset_rds(f, show_status = TRUE),
    "Processing Status"
  )
})


# ---- create_dir: auto-create the output directory ----------------------------

test_that("ensure_output_dir() creates a missing parent directory when create_dir = TRUE", {
  root <- withr::local_tempdir()
  target <- file.path(root, "nested", "sub", "file.csv")
  expect_false(dir.exists(dirname(target)))
  ensure_output_dir(target, create_dir = TRUE)
  expect_true(dir.exists(dirname(target)))
})

test_that("ensure_output_dir() does nothing when create_dir = FALSE", {
  root <- withr::local_tempdir()
  target <- file.path(root, "nope", "file.csv")
  ensure_output_dir(target, create_dir = FALSE)
  expect_false(dir.exists(dirname(target)))
})

test_that("ensure_output_dir() is a no-op for NA or empty paths", {
  expect_silent(ensure_output_dir(NA_character_))
  expect_silent(ensure_output_dir(""))
})

test_that("save_dataset_csv() creates a missing output directory (create_dir = TRUE)", {
  root <- withr::local_tempdir()
  path <- file.path(root, "newdir", "conc.csv")
  expect_false(dir.exists(dirname(path)))
  suppressMessages(save_dataset_csv(mexp, path = path, variable = "conc"))
  expect_true(file.exists(path))
})

test_that("save_dataset_csv() errors when the directory is missing and create_dir = FALSE", {
  root <- withr::local_tempdir()
  path <- file.path(root, "missing", "conc.csv")
  expect_error(
    suppressMessages(
      save_dataset_csv(mexp, path = path, variable = "conc", create_dir = FALSE)
    )
  )
  expect_false(file.exists(path))
})

test_that("save_dataset_rds() creates a missing output directory (create_dir = TRUE)", {
  root <- withr::local_tempdir()
  path <- file.path(root, "newdir", "mexp.rds")
  expect_false(dir.exists(dirname(path)))
  suppressMessages(save_dataset_rds(mexp, path = path))
  expect_true(file.exists(path))
})

test_that("save_dataset_rds() errors when the directory is missing and create_dir = FALSE", {
  root <- withr::local_tempdir()
  path <- file.path(root, "missing", "mexp.rds")
  expect_error(
    suppressWarnings(
      suppressMessages(save_dataset_rds(mexp, path = path, create_dir = FALSE))
    )
  )
  expect_false(file.exists(path))
})

test_that("save_report_xlsx() creates a missing output directory (create_dir = TRUE)", {
  root <- withr::local_tempdir()
  path <- file.path(root, "newdir", "report.xlsx")
  expect_false(dir.exists(dirname(path)))
  suppressMessages(save_report_xlsx(mexp, path = path))
  expect_true(file.exists(path))
})
