# Tests for the SummarizedExperiment / LipidomicsExperiment exporter.
#
# The orientation and round-trip tests are the load-bearing ones: a transposed
# or mis-mapped assay is silently wrong, so it is checked by value and not just
# by dim().

skip_if_not_installed("SummarizedExperiment")

mexp <- quantify_by_istd(normalize_by_istd(lipidomics_dataset))
mexp@title <- "Test Experiment"

n_features <- length(unique(mexp@dataset$feature_id))
n_analyses <- length(unique(mexp@dataset$analysis_id))

test_that("save_dataset_summarizedexperiment lays features out as rows and analyses as columns", {
  se <- save_dataset_summarizedexperiment(mexp)

  expect_s4_class(se, "SummarizedExperiment")
  expect_identical(dim(se), c(n_features, n_analyses))
  expect_setequal(rownames(se), unique(mexp@dataset$feature_id))
  expect_setequal(colnames(se), unique(mexp@dataset$analysis_id))
})

test_that("assay values match the long-format dataset cell by cell", {
  se <- save_dataset_summarizedexperiment(mexp, variable = "conc")
  m <- SummarizedExperiment::assay(se, "conc")

  d <- mexp@dataset
  expect_equal(
    m[cbind(d$feature_id, d$analysis_id)],
    d$feature_conc,
    ignore_attr = TRUE
  )
})

test_that("rowData and colData are bound to the assay by name, not position", {
  se <- save_dataset_summarizedexperiment(mexp)

  expect_identical(rownames(se), rownames(SummarizedExperiment::rowData(se)))
  expect_identical(colnames(se), rownames(SummarizedExperiment::colData(se)))

  # annotation must follow its own feature/analysis, not the row it landed on
  expect_identical(SummarizedExperiment::rowData(se)$feature_id, rownames(se))
  expect_identical(SummarizedExperiment::colData(se)$analysis_id, colnames(se))
})

test_that("every feature variable becomes an assay, and `variable` subsets them", {
  se <- save_dataset_summarizedexperiment(mexp)
  expect_true(
    all(
      c("intensity", "norm_intensity", "conc") %in%
        SummarizedExperiment::assayNames(se)
    )
  )

  expect_identical(
    SummarizedExperiment::assayNames(
      save_dataset_summarizedexperiment(mexp, variable = "conc")
    ),
    "conc"
  )
  expect_identical(
    SummarizedExperiment::assayNames(
      save_dataset_summarizedexperiment(
        mexp,
        variable = c("intensity", "conc")
      )
    ),
    c("intensity", "conc")
  )

  # the `feature_` prefix is optional
  expect_identical(
    SummarizedExperiment::assayNames(
      save_dataset_summarizedexperiment(mexp, variable = "feature_conc")
    ),
    "conc"
  )
})

test_that("filter_data uses the QC-filtered dataset", {
  mexp_filt <- filter_features_qc(
    calc_qc_metrics(mexp),
    include_qualifier = FALSE,
    include_istd = FALSE,
    max.cv.conc.bqc = 25
  )
  se <- save_dataset_summarizedexperiment(mexp_filt, filter_data = TRUE)

  expect_identical(
    nrow(se),
    length(unique(mexp_filt@dataset_filtered$feature_id))
  )
  expect_lt(nrow(se), n_features)
  expect_true(S4Vectors::metadata(se)$is_filtered)
})

test_that("metadata carries the processing state", {
  md <- S4Vectors::metadata(save_dataset_summarizedexperiment(mexp))

  expect_identical(md$title, "Test Experiment")
  expect_identical(md$status_processing, "ISTD-quantitated data")
  expect_true(md$is_istd_normalized)
  expect_true(md$is_quantitated)
  expect_false(md$is_filtered)
  expect_identical(md$conc_unit, "\U003BCmol/L")
  expect_named(
    md$var_drift_corrected,
    c("feature_intensity", "feature_norm_intensity", "feature_conc")
  )
})

test_that("the reported concentration unit follows the quantitation used", {
  # The unit must come from the experiment, never a hardcoded default: mass
  # quantitation yields ug/L, and reporting umol/L for it would be a silently
  # wrong number.
  mexp_mass <- normalize_by_istd(lipidomics_dataset)
  mexp_mass@annot_features$molecular_weight <- 700
  mexp_mass <- quantify_by_istd(mexp_mass, concentration_unit = "mass")

  expect_identical(
    S4Vectors::metadata(save_dataset_summarizedexperiment(mexp_mass))$conc_unit,
    "\U003BCg/L"
  )

  # calibration quantitation reports the calibrant unit
  mexp_cal <- quantify_by_calibration(
    normalize_by_istd(quant_lcms_dataset),
    fit_overwrite = FALSE,
    fit_model = "quadratic",
    fit_weighting = "1/x"
  )
  expect_identical(
    S4Vectors::metadata(save_dataset_summarizedexperiment(mexp_cal))$conc_unit,
    "nmol/L"
  )

  # unquantitated data has no concentration unit; guessing one would be worse
  expect_identical(
    S4Vectors::metadata(
      save_dataset_summarizedexperiment(normalize_by_istd(lipidomics_dataset))
    )$conc_unit,
    NA_character_
  )
})

test_that("path writes an rds that round-trips", {
  temp_file <- withr::local_tempfile(fileext = ".rds")

  expect_message(
    se <- save_dataset_summarizedexperiment(
      mexp,
      path = temp_file,
      variable = "conc"
    ),
    "was saved to"
  )
  expect_true(file.exists(temp_file))
  expect_equal(
    SummarizedExperiment::assay(readRDS(temp_file), "conc"),
    SummarizedExperiment::assay(se, "conc")
  )

  expect_error(
    save_dataset_summarizedexperiment(
      mexp,
      path = temp_file,
      variable = "conc",
      overwrite = FALSE
    ),
    "already exists"
  )
})

test_that("a missing rds extension is added", {
  temp_file <- withr::local_tempfile()
  suppressMessages(
    save_dataset_summarizedexperiment(mexp, path = temp_file, variable = "conc")
  )
  expect_true(file.exists(paste0(temp_file, ".rds")))
})

test_that("invalid input is rejected with an informative message", {
  expect_error(
    save_dataset_summarizedexperiment(MRMhubExperiment()),
    "No annotated data available"
  )
  expect_error(
    save_dataset_summarizedexperiment(mexp, variable = "nonsense"),
    "not available"
  )
  expect_error(
    save_dataset_summarizedexperiment(lipidomics_dataset, variable = "conc"),
    "Concentration data are not available"
  )
  expect_error(
    save_dataset_summarizedexperiment(mexp, filter_data = TRUE),
    "has not been QC-filtered"
  )
})

test_that("non-numeric feature columns are rejected, not coerced into an assay", {
  # `feature_id`/`feature_class`/`feature_label` are feature_* columns but are
  # not measurements; exporting one would silently produce a character assay.
  for (v in c("id", "class", "label")) {
    expect_error(
      save_dataset_summarizedexperiment(mexp, variable = v),
      "not available"
    )
  }
  expect_false(any(
    c("id", "class", "label") %in%
      SummarizedExperiment::assayNames(save_dataset_summarizedexperiment(mexp))
  ))
})

# ---- lipidr -----------------------------------------------------------------

test_that("as = 'LipidomicsExperiment' produces a valid lipidr object", {
  skip_if_not_installed("lipidr")

  le <- save_dataset_summarizedexperiment(
    mexp,
    variable = "intensity",
    as = "LipidomicsExperiment"
  )

  expect_s4_class(le, "LipidomicsExperiment")
  expect_true(validObject(le))
  expect_identical(dim(le), c(n_features, n_analyses))

  # the four rowData columns lipidr's validity requires
  rd <- SummarizedExperiment::rowData(le)
  expect_true(all(c("filename", "Molecule", "Class", "istd") %in% names(rd)))
  expect_identical(rd$Molecule, rownames(le))
  expect_identical(rd$Class, rd$feature_class)
  expect_identical(rd$istd, rd$is_istd)

  # flags lipidr reads but does not validate
  expect_identical(S4Vectors::metadata(le)$dimnames, c("MoleculeId", "Sample"))
  expect_true(S4Vectors::metadata(le)$summarized)
  expect_false(
    S4Vectors::mcols(SummarizedExperiment::assays(le))["intensity", "logged"]
  )
})

test_that("lipidr's de_analysis runs on the exported object", {
  skip_if_not_installed("lipidr")

  le <- save_dataset_summarizedexperiment(
    mexp,
    variable = "intensity",
    as = "LipidomicsExperiment"
  )
  le <- le[
    !SummarizedExperiment::rowData(le)$istd,
    SummarizedExperiment::colData(le)$qc_type == "SPL"
  ]

  withr::local_seed(1)
  le$group <- factor(sample(c("ctrl", "trt"), ncol(le), replace = TRUE))

  res <- lipidr::de_analysis(
    lipidr::normalize_pqn(le, measure = "intensity", log = TRUE),
    trt - ctrl,
    measure = "intensity",
    group_col = "group"
  )

  expect_identical(nrow(res), nrow(le))
  # peak-area scale survives lipidr's log; a flattened assay would give logFC 0
  expect_true(all(res$logFC != 0))
})

test_that("exporting a sub-1 assay to lipidr warns about the log clamp", {
  skip_if_not_installed("lipidr")

  # lipidr clamps values < 1 to 1 before log2(), which flattens umol/L
  # concentrations. It must warn for conc but stay quiet for peak areas.
  expect_message(
    save_dataset_summarizedexperiment(
      mexp,
      variable = "conc",
      as = "LipidomicsExperiment"
    ),
    "clamps values < 1"
  )
  expect_no_message(
    save_dataset_summarizedexperiment(
      mexp,
      variable = "intensity",
      as = "LipidomicsExperiment"
    )
  )
})
