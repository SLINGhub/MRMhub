# Tests for mzTab-M export (save_dataset_mztab)
#
# The writer is pure R; `rmzTabM` (GitHub-only reference implementation) is used
# only as an optional conformance oracle and self-skips when not installed.

set.seed(123)

mexp_raw <- lipidomics_dataset
mexp_quant <- quantify_by_istd(normalize_by_istd(mexp_raw))
mexp_quant@title <- "Test Experiment"

# small, deterministic subset for snapshotting (avoids 499-assay files)
trim_experiment <- function(data, n_analyses = 3L, n_features = 3L) {
  keep_an <- head(sort(unique(data@dataset$analysis_id)), n_analyses)
  keep_ft <- head(sort(unique(data@dataset$feature_id)), n_features)
  data@dataset <- dplyr::filter(
    data@dataset,
    .data$analysis_id %in% keep_an,
    .data$feature_id %in% keep_ft
  )
  data@dataset_orig <- dplyr::filter(
    data@dataset_orig,
    .data$analysis_id %in% keep_an,
    .data$feature_id %in% keep_ft
  )
  data@annot_features <- dplyr::filter(
    data@annot_features,
    .data$feature_id %in% keep_ft
  )
  data@annot_analyses <- dplyr::filter(
    data@annot_analyses,
    .data$analysis_id %in% keep_an
  )
  data
}

read_section <- function(path, prefix) {
  ll <- readLines(path)
  ll[startsWith(ll, paste0(prefix, "\t"))]
}

test_that("save_dataset_mztab writes a valid-shaped mzTab-M file", {
  out <- withr::local_tempfile(fileext = ".mzTab")
  expect_message(
    save_dataset_mztab(mexp_quant, out, variable = "conc"),
    "mzTab-M export"
  )
  expect_true(file.exists(out))

  ll <- readLines(out)
  n_analyses <- length(unique(mexp_quant@dataset$analysis_id))
  n_features <- length(unique(mexp_quant@dataset$feature_id))

  # version banner is the first line
  expect_identical(ll[[1]], "MTD\tmzTab-version\t2.0.0-M")

  # required MTD elements present
  expect_true(any(startsWith(ll, "MTD\tquantification_method")))
  expect_true(any(startsWith(ll, "MTD\tsmall_molecule-quantification_unit")))
  expect_true(any(startsWith(ll, "MTD\tcv[1]-label")))
  expect_true(any(startsWith(ll, "MTD\tdatabase[1]")))
  expect_true(any(startsWith(ll, "MTD\tid_confidence_measure[1]")))

  # one assay per analysis
  expect_equal(sum(grepl("^MTD\tassay\\[[0-9]+\\]-ms_run_ref", ll)), n_analyses)

  # table sections: headers + one row per entity
  expect_length(read_section(out, "SMH"), 1L)
  expect_length(read_section(out, "SFH"), 1L)
  expect_length(read_section(out, "SEH"), 1L)
  expect_length(read_section(out, "SMF"), n_features)
  expect_length(read_section(out, "SME"), n_features)

  # SFH carries one abundance_assay column per analysis
  sfh <- strsplit(read_section(out, "SFH"), "\t")[[1]]
  expect_equal(sum(grepl("^abundance_assay\\[", sfh)), n_analyses)
})

test_that("ISTD features are flagged via opt_global_is_internal_standard", {
  out <- withr::local_tempfile(fileext = ".mzTab")
  suppressMessages(save_dataset_mztab(mexp_quant, out, variable = "conc"))

  sfh <- strsplit(read_section(out, "SFH"), "\t")[[1]]
  istd_col <- which(sfh == "opt_global_is_internal_standard")
  expect_length(istd_col, 1L)

  # header and data rows both carry the section prefix, so positions align
  smf_rows <- strsplit(read_section(out, "SMF"), "\t")
  flags <- vapply(smf_rows, function(r) r[[istd_col]], character(1))
  n_istd <- sum(mexp_quant@annot_features$is_istd, na.rm = TRUE)
  expect_equal(sum(flags == "TRUE"), n_istd)
})

test_that("variable falls back to raw intensity when not quantified", {
  out <- withr::local_tempfile(fileext = ".mzTab")
  # mexp_raw has not been quantified -> conc unavailable -> arbitrary unit
  suppressMessages(save_dataset_mztab(mexp_raw, out, variable = "conc"))

  unit_line <- grep(
    "MTD\tsmall_molecule-quantification_unit",
    readLines(out),
    value = TRUE,
    fixed = TRUE
  )
  expect_match(unit_line, "Arbitrary quantification unit")
})

test_that("path gets a .mzTab extension and overwrite is honoured", {
  base <- withr::local_tempfile()
  suppressMessages(save_dataset_mztab(mexp_quant, base, variable = "intensity"))
  expect_true(file.exists(paste0(base, ".mzTab")))

  expect_error(
    save_dataset_mztab(
      mexp_quant,
      paste0(base, ".mzTab"),
      variable = "intensity",
      overwrite = FALSE
    ),
    "already exists"
  )
})

test_that("an empty experiment is rejected", {
  expect_error(
    save_dataset_mztab(MRMhubExperiment(), tempfile(fileext = ".mzTab")),
    "No annotated data"
  )
})

test_that("table-section headers are stable (snapshot)", {
  out <- withr::local_tempfile(fileext = ".mzTab")
  small <- trim_experiment(mexp_quant)
  suppressMessages(save_dataset_mztab(small, out, variable = "conc"))

  headers <- c(
    read_section(out, "SMH"),
    read_section(out, "SFH"),
    read_section(out, "SEH")
  )
  expect_snapshot(cat(headers, sep = "\n"))
})

test_that("output parses with the rmzTabM reference reader (oracle)", {
  skip_on_cran()
  skip_if_not_installed("rmzTabM")

  out <- withr::local_tempfile(fileext = ".mzTab")
  suppressMessages(save_dataset_mztab(mexp_quant, out, variable = "conc"))

  m <- rmzTabM::readMzTab(out)
  smf <- rmzTabM::extractSmallMoleculeFeatures(m)
  expect_equal(nrow(smf), length(unique(mexp_quant@dataset$feature_id)))
})
