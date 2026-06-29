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

test_that("import_data_mztab reads a Lipid Data Analyzer file", {
  f <- system.file("extdata", "lda_example.mzTab", package = "mrmhub")
  expect_true(file.exists(f))

  mexp <- import_data_mztab(MRMhubExperiment(title = "LDA"), f, silent = TRUE)

  # 3 assays x 4 features (one analyte split into two adduct features)
  expect_equal(length(unique(mexp@dataset_orig$analysis_id)), 3L)
  expect_equal(length(unique(mexp@dataset_orig$feature_id)), 4L)

  # analysis_id derived from ms_run location basename, extension stripped
  expect_setequal(
    unique(mexp@dataset_orig$analysis_id),
    c("001_liver_A", "002_liver_B", "003_liver_C")
  )

  # shared analyte name disambiguated by adduct
  expect_true("Cer d18:1/16:0 | [M-H]-" %in% mexp@dataset_orig$feature_id)
  expect_true("Cer d18:1/16:0 | [M+HCOO]-" %in% mexp@dataset_orig$feature_id)

  # abundance -> feature_intensity, with "null" abundance -> NA
  lps <- mexp@dataset_orig |>
    dplyr::filter(.data$feature_id == "LPS 11:1") |>
    dplyr::arrange(.data$analysis_id)
  expect_equal(lps$feature_intensity, c(12345.6, 23456.7, NA))

  # study_variable membership imported as batch_id (best effort)
  expect_setequal(
    unique(mexp@annot_analyses$batch_id),
    c("mouse liver 1", "mouse liver 2")
  )

  # feature metadata carried through to annot_features
  expect_true(any(!is.na(mexp@annot_features$molecular_weight)))
  expect_equal(
    mexp@annot_features$chem_formula[
      mexp@annot_features$feature_id == "LPS 11:1"
    ],
    "C17H32NO9P"
  )
})

test_that("export -> import round-trips feature and analysis counts", {
  out <- withr::local_tempfile(fileext = ".mzTab")
  suppressMessages(save_dataset_mztab(mexp_quant, out, variable = "intensity"))

  back <- import_data_mztab(MRMhubExperiment(), out, silent = TRUE)

  expect_equal(
    length(unique(back@dataset_orig$analysis_id)),
    length(unique(mexp_quant@dataset$analysis_id))
  )
  expect_equal(
    length(unique(back@dataset_orig$feature_id)),
    length(unique(mexp_quant@dataset$feature_id))
  )
  expect_true(any(!is.na(back@dataset_orig$feature_intensity)))
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
