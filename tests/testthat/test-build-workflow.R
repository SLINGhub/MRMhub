# Tests for the workflow builder's pure generator and validator (no Shiny).

demo_file <- function() {
  system.file("extdata", "MRMhub_demo.tsv", package = "mrmhub")
}

test_that("generate_workflow_qmd emits a runnable, tutorial-faithful workflow", {
  qmd <- generate_workflow_qmd(list(
    importer = "mrmhub",
    data_path = "MRMhub_demo.tsv",
    metadata_route = "embedded",
    steps = c("normalize_istd", "quantify_istd", "correct_drift", "filter_qc"),
    variable = "conc",
    ref_qc_types = "SPL"
  ))

  expect_type(qmd, "character")
  expect_length(qmd, 1)

  # YAML + structure
  expect_match(qmd, "^---\\ntitle:", perl = TRUE)
  expect_match(qmd, "format:", fixed = TRUE)
  expect_match(qmd, "html: default", fixed = TRUE)

  # Real API calls with correct argument names (guards against the old app's
  # fictional correct_drift()/calibrate_external()/export_xlsx()).
  expect_match(qmd, "mexp <- MRMhubExperiment()", fixed = TRUE)
  expect_match(qmd, 'import_data_mrmhub(mexp, path = "MRMhub_demo.tsv", import_metadata = TRUE)', fixed = TRUE)
  expect_match(qmd, "mexp <- normalize_by_istd(mexp)", fixed = TRUE)
  expect_match(qmd, "mexp <- quantify_by_istd(mexp)", fixed = TRUE)
  expect_match(qmd, 'correct_drift_gaussiankernel(mexp, variable = "conc", ref_qc_types = "SPL")', fixed = TRUE)
  expect_match(qmd, 'filter_features_qc(mexp, include_qualifier = FALSE, include_istd = FALSE)', fixed = TRUE)
  expect_match(qmd, 'save_report_xlsx(mexp, path = "results.xlsx")', fixed = TRUE)

  # No fictional functions from the retired walkthrough app.
  expect_no_match(qmd, "calibrate_external", fixed = TRUE)
  expect_no_match(qmd, "export_xlsx", fixed = TRUE)
})

test_that("steps are emitted in canonical order regardless of input order", {
  qmd <- generate_workflow_qmd(list(
    steps = c("filter_qc", "normalize_istd", "quantify_istd")
  ))
  expect_lt(
    regexpr("normalize_by_istd", qmd, fixed = TRUE),
    regexpr("quantify_by_istd", qmd, fixed = TRUE)
  )
  expect_lt(
    regexpr("quantify_by_istd", qmd, fixed = TRUE),
    regexpr("filter_features_qc", qmd, fixed = TRUE)
  )
})

test_that("importer and metadata route select the right calls", {
  qmd <- generate_workflow_qmd(list(
    importer = "csv_long",
    data_path = "d.csv",
    metadata_route = "msorganiser",
    metadata_path = "meta.xlsx",
    steps = character()
  ))
  expect_match(qmd, 'import_data_csv_long(mexp, path = "d.csv")', fixed = TRUE)
  expect_match(qmd, 'import_metadata_msorganiser(mexp, path = "meta.xlsx")', fixed = TRUE)
  # Import + export are always present even with no steps.
  expect_match(qmd, "save_report_xlsx", fixed = TRUE)
})

test_that("generic long CSV emits a column_mapping when provided", {
  qmd <- generate_workflow_qmd(list(
    importer = "csv_long", data_path = "d.csv", steps = character(),
    column_mapping = c(analysis_id = "Sample", feature_id = "Compound", feature_area = "Area")
  ))
  expect_match(qmd, "import_data_csv_long(", fixed = TRUE)
  expect_match(qmd, 'column_mapping = c(analysis_id = "Sample", feature_id = "Compound", feature_area = "Area")', fixed = TRUE)
})

test_that("generic wide CSV emits variable_name and optional args", {
  qmd <- generate_workflow_qmd(list(
    importer = "csv_wide", data_path = "w.csv", steps = character(),
    variable_name = "conc", analysis_id_col = "SampleID", first_feature_column = 3
  ))
  expect_match(qmd, 'variable_name = "conc"', fixed = TRUE)
  expect_match(qmd, 'analysis_id_col = "SampleID"', fixed = TRUE)
  expect_match(qmd, "first_feature_column = 3", fixed = TRUE)
})

test_that("individual metadata files emit one import per provided table", {
  qmd <- generate_workflow_qmd(list(
    importer = "mrmhub", data_path = "d.tsv", metadata_route = "individual",
    metadata_individual = list(analyses = "meta/analyses.csv", features = "meta/features.csv", istds = NULL),
    steps = character()
  ))
  expect_match(qmd, 'import_metadata_analyses(mexp, path = "meta/analyses.csv")', fixed = TRUE)
  expect_match(qmd, 'import_metadata_features(mexp, path = "meta/features.csv")', fixed = TRUE)
  # A NULL table is skipped.
  expect_no_match(qmd, "import_metadata_istds", fixed = TRUE)
})

test_that("format_named_vec renders a named vector as R source", {
  expect_equal(
    format_named_vec(c(analysis_id = "S", feature_id = "F")),
    'c(analysis_id = "S", feature_id = "F")'
  )
})

test_that("save_rds is optional", {
  with_rds <- generate_workflow_qmd(list(steps = character(), save_rds = TRUE))
  without <- generate_workflow_qmd(list(steps = character()))
  expect_match(with_rds, "saveRDS(mexp", fixed = TRUE)
  expect_no_match(without, "saveRDS", fixed = TRUE)
})

test_that("output formats are written into the YAML, with sans-serif pdf", {
  qmd <- generate_workflow_qmd(list(
    steps = character(),
    formats = c("html", "docx", "pdf")
  ))
  expect_match(qmd, "html: default", fixed = TRUE)
  expect_match(qmd, "docx: default", fixed = TRUE)
  expect_match(qmd, "  pdf:", fixed = TRUE)
  # pdflatex-safe sans-serif switch.
  expect_match(qmd, "\\renewcommand{\\familydefault}{\\sfdefault}", fixed = TRUE)
  # docx must not be given the pdf-only sans-serif header.
  docx_only <- generate_workflow_qmd(list(steps = character(), formats = "docx"))
  expect_no_match(docx_only, "familydefault", fixed = TRUE)
})

test_that("format_char_vec renders scalars and vectors as R source", {
  expect_equal(format_char_vec("SPL"), '"SPL"')
  expect_equal(format_char_vec(c("SPL", "BQC")), 'c("SPL", "BQC")')
})

test_that("validator flags missing feature metadata for normalize_by_istd", {
  skip_if(demo_file() == "")
  # Importing without metadata leaves annot_features empty.
  res <- validate_workflow_inputs(
    demo_file(), "mrmhub",
    metadata_route = "none", steps = "normalize_istd"
  )
  expect_s3_class(res, "tbl_df")
  expect_true("normalize_istd" %in% res$step)
  norm <- res[res$step == "normalize_istd", ]
  expect_equal(norm$severity, "error")
  expect_match(norm$message, "feature metadata", ignore.case = TRUE)
})

test_that("validator passes normalize_by_istd when ISTDs are defined", {
  skip_if(demo_file() == "")
  # The demo's embedded metadata assigns an istd_feature_id to every feature.
  res <- validate_workflow_inputs(
    demo_file(), "mrmhub",
    metadata_route = "embedded", steps = "normalize_istd"
  )
  # normalize_istd contributes no issue; validator returns the ok summary row.
  expect_false(any(res$step == "normalize_istd" & res$severity != "ok"))
})

test_that("validator reports a missing reference QC type for drift correction", {
  skip_if(demo_file() == "")
  mexp <- build_experiment(demo_file(), "mrmhub", NULL, "embedded")
  defs <- workflow_steps()
  issues <- defs$correct_drift$precheck(
    mexp,
    list(steps = "correct_drift", ref_qc_types = "NOT_A_QC", variable = "conc")
  )
  expect_true(any(issues$severity == "error"))
  expect_match(issues$message[issues$severity == "error"][1], "not present", ignore.case = TRUE)
})

test_that("validator surfaces import failures instead of erroring", {
  bad <- withr::local_tempfile(fileext = ".tsv")
  writeLines(c("not\ta\tvalid\tfile", "1\t2\t3\t4"), bad)
  res <- validate_workflow_inputs(bad, "mrmhub", metadata_route = "none", steps = "normalize_istd")
  expect_equal(res$severity[1], "error")
  expect_match(res$message[1], "Import failed", fixed = TRUE)
})

test_that("every optional step emits its real, correctly-named API call", {
  qmd <- generate_workflow_qmd(list(
    steps = c(
      "normalize_istd", "quantify_istd", "quantify_cal",
      "calibrate_ref", "correct_drift", "correct_batch", "qc_metrics",
      "filter_qc", "plot_runscatter"
    )
  ))
  expect_match(qmd, "mexp <- quantify_by_calibration(mexp, fit_overwrite = TRUE)", fixed = TRUE)
  expect_match(qmd, "mexp <- calibrate_by_reference(", fixed = TRUE)
  expect_match(qmd, 'reference_sample_id = "REFERENCE_SAMPLE_ID"', fixed = TRUE)
  # quantify steps selected -> variable is conc; default drift method -> SPL ref.
  expect_match(qmd, 'mexp <- correct_batch_centering(mexp, variable = "conc", ref_qc_types = "SPL")', fixed = TRUE)
  expect_match(qmd, "mexp <- calc_qc_metrics(mexp)", fixed = TRUE)
  expect_match(qmd, 'plot_runscatter(mexp, variable = "conc")', fixed = TRUE)
})

test_that("each importer maps to the matching import_data_* call", {
  mh <- generate_workflow_qmd(list(importer = "masshunter", data_path = "mh.csv", steps = character()))
  expect_match(mh, 'import_data_masshunter(mexp, path = "mh.csv", import_metadata = TRUE)', fixed = TRUE)
  sk <- generate_workflow_qmd(list(importer = "skyline", data_path = "sk.csv", steps = character()))
  expect_match(sk, 'import_data_skyline(mexp, path = "sk.csv", import_metadata = TRUE)', fixed = TRUE)
  cw <- generate_workflow_qmd(list(importer = "csv_wide", data_path = "w.csv", steps = character()))
  expect_match(cw, 'import_data_csv_wide(mexp, path = "w.csv", variable_name = "area")', fixed = TRUE)
  # An unrecognised importer falls back to import_data_mrmhub.
  fb <- generate_workflow_qmd(list(importer = "??", data_path = "x.tsv", steps = character()))
  expect_match(fb, 'import_data_mrmhub(mexp, path = "x.tsv")', fixed = TRUE)
})

test_that("the multi-table metadata route emits one import per sheet", {
  qmd <- generate_workflow_qmd(list(
    importer = "mrmhub", data_path = "d.tsv",
    metadata_route = "tables", metadata_path = "m.xlsx", steps = character()
  ))
  expect_match(qmd, 'import_metadata_analyses(mexp, path = "m.xlsx", sheet = "Analyses")', fixed = TRUE)
  expect_match(qmd, 'import_metadata_features(mexp, path = "m.xlsx", sheet = "Features")', fixed = TRUE)
  expect_match(qmd, 'import_metadata_istds(mexp, path = "m.xlsx", sheet = "ISTDs")', fixed = TRUE)
  # Non-embedded route imports the data without pulling embedded metadata.
  expect_match(qmd, "import_metadata = FALSE", fixed = TRUE)
})

test_that("step availability disables steps whose supporting metadata is absent", {
  skip_if(demo_file() == "")
  # The demo has feature ISTD assignments but no ISTD/QC concentrations and no
  # populated sample_id, so quantitation and reference calibration are gated off.
  mexp <- build_experiment(demo_file(), "mrmhub", NULL, "embedded")
  av <- workflow_step_availability(mexp)
  by_id <- stats::setNames(av, vapply(av, function(s) s$id, character(1)))

  expect_true(by_id$normalize_istd$enabled)
  expect_true(by_id$correct_batch$enabled) # demo spans multiple batches
  expect_false(by_id$quantify_istd$enabled)
  expect_match(by_id$quantify_istd$reason, "ISTD", ignore.case = TRUE)
  expect_false(by_id$quantify_cal$enabled)
  expect_false(by_id$calibrate_ref$enabled)
})

test_that("workflow_step_availability warns and falls open when a gate errors", {
  # A buggy gate must not blank the step list (fail open), but the error must be
  # surfaced, not silently swallowed. Inject a step whose gate throws.
  local_mocked_bindings(
    workflow_steps = function() {
      list(
        boom = list(
          id = "boom",
          label = "Boom",
          order = 10,
          default_selected = FALSE,
          gate = function(mexp) stop("gate exploded")
        )
      )
    }
  )
  mexp <- MRMhubExperiment()

  expect_warning(
    av <- workflow_step_availability(mexp),
    "boom"
  )
  by_id <- stats::setNames(av, vapply(av, function(s) s$id, character(1)))
  expect_true(by_id$boom$enabled) # fell open despite the gate error
})

test_that("prechecks error when quantitation metadata is missing", {
  skip_if(demo_file() == "")
  mexp <- build_experiment(demo_file(), "mrmhub", NULL, "embedded")
  defs <- workflow_steps()

  qi <- defs$quantify_istd$precheck(mexp, list(steps = "quantify_istd"))
  expect_true(any(qi$severity == "error"))
  expect_match(paste(qi$message, collapse = " "), "annot_istds", fixed = TRUE)

  qc <- defs$quantify_cal$precheck(mexp, list(steps = "quantify_cal"))
  expect_true(any(qc$severity == "error"))
})

test_that("calibrate_ref precheck warns without a reference and errors on a bad one", {
  skip_if(demo_file() == "")
  mexp <- build_experiment(demo_file(), "mrmhub", NULL, "embedded")
  defs <- workflow_steps()

  none <- defs$calibrate_ref$precheck(mexp, list(steps = "calibrate_ref"))
  expect_equal(none$severity, "warning")

  bad <- defs$calibrate_ref$precheck(
    mexp, list(steps = "calibrate_ref", reference_sample_id = "NOPE")
  )
  expect_true(any(bad$severity == "error"))
})

test_that("correct_batch precheck warns when the target variable is not yet present", {
  skip_if(demo_file() == "")
  # With a quantify step selected the target variable is conc, but right after
  # import feature_conc does not exist yet, so batch should warn to run it first.
  mexp <- build_experiment(demo_file(), "mrmhub", NULL, "embedded")
  issues <- workflow_steps()$correct_batch$precheck(
    mexp, list(steps = c("quantify_istd", "correct_batch"), ref_qc_types = "SPL")
  )
  expect_true(any(issues$severity == "warning"))
  expect_match(paste(issues$message, collapse = " "), "feature_conc", fixed = TRUE)
})

test_that("drift method selects the matching correct_drift_* function", {
  base <- list(steps = c("quantify_istd", "correct_drift"), ref_qc_types = "BQC")
  expect_match(generate_workflow_qmd(c(base, list(drift_method = "spline"))),
    "correct_drift_cubicspline(mexp", fixed = TRUE)
  expect_match(generate_workflow_qmd(c(base, list(drift_method = "loess"))),
    "correct_drift_loess(mexp", fixed = TRUE)
  expect_match(generate_workflow_qmd(c(base, list(drift_method = "gaussian"))),
    "correct_drift_gaussiankernel(mexp", fixed = TRUE)
})

test_that("drift ref defaults by method and variable tracks the highest level", {
  # Gaussian with no explicit ref -> SPL; only normalize selected -> norm_intensity.
  q1 <- generate_workflow_qmd(list(steps = c("normalize_istd", "correct_drift"), drift_method = "gaussian"))
  expect_match(q1, 'correct_drift_gaussiankernel(mexp, variable = "norm_intensity", ref_qc_types = "SPL")', fixed = TRUE)
  # Spline with no explicit ref -> BQC; no normalize/quantify -> intensity.
  q2 <- generate_workflow_qmd(list(steps = c("correct_drift"), drift_method = "spline"))
  expect_match(q2, 'correct_drift_cubicspline(mexp, variable = "intensity", ref_qc_types = "BQC")', fixed = TRUE)
})

test_that("normalize_istd is gated off and errors when ISTDs are undefined", {
  skip_if(demo_file() == "")
  mexp <- build_experiment(demo_file(), "mrmhub", NULL, "embedded")
  defs <- workflow_steps()

  # No feature metadata at all -> gate disabled with a reason.
  empty_gate <- defs$normalize_istd$gate(MRMhubExperiment())
  expect_false(empty_gate$enabled)
  expect_match(empty_gate$reason, "feature metadata", ignore.case = TRUE)

  # Features present but every istd_feature_id is NA -> gate off + precheck error.
  no_istd <- mexp
  no_istd@annot_features$istd_feature_id <- NA_character_
  expect_false(defs$normalize_istd$gate(no_istd)$enabled)
  err <- defs$normalize_istd$precheck(no_istd, list(steps = "normalize_istd"))
  expect_true(any(err$severity == "error"))

  # Only some istds missing -> precheck warns instead of erroring.
  some_istd <- mexp
  some_istd@annot_features$istd_feature_id[1] <- NA_character_
  warn <- defs$normalize_istd$precheck(some_istd, list(steps = "normalize_istd"))
  expect_true(any(warn$severity == "warning"))
})

test_that("gates enable once their supporting metadata is present", {
  skip_if(demo_file() == "")
  mexp <- build_experiment(demo_file(), "mrmhub", NULL, "embedded")
  defs <- workflow_steps()

  with_istds <- mexp
  with_istds@annot_istds <- tibble::tibble(istd_feature_id = "x")
  expect_true(defs$quantify_istd$gate(with_istds)$enabled)

  with_qcconc <- mexp
  with_qcconc@annot_qcconcentrations <- tibble::tibble(feature_id = "x")
  expect_true(defs$quantify_cal$gate(with_qcconc)$enabled)

  with_sid <- mexp
  with_sid@annot_analyses$sample_id <- "REF"
  expect_true(defs$calibrate_ref$gate(with_sid)$enabled)
  # A valid reference id yields no precheck issue.
  ok <- defs$calibrate_ref$precheck(
    with_sid,
    list(steps = "calibrate_ref", reference_sample_id = "REF")
  )
  expect_true(is.null(ok) || nrow(ok) == 0)

  # When the sample_id column is absent entirely, the gate is off and a chosen
  # reference errors in the precheck.
  no_sid_col <- mexp
  no_sid_col@annot_analyses$sample_id <- NULL
  expect_false(defs$calibrate_ref$gate(no_sid_col)$enabled)
  res <- defs$calibrate_ref$precheck(
    no_sid_col,
    list(steps = "calibrate_ref", reference_sample_id = "REF")
  )
  expect_true(any(res$severity == "error"))
})

test_that("correct_batch is gated off and warns with a single batch", {
  skip_if(demo_file() == "")
  mexp <- build_experiment(demo_file(), "mrmhub", NULL, "embedded")
  one_batch <- mexp
  one_batch@dataset$batch_id <- "B1"
  defs <- workflow_steps()

  expect_false(defs$correct_batch$gate(one_batch)$enabled)
  issues <- defs$correct_batch$precheck(
    one_batch,
    list(steps = "correct_batch", ref_qc_types = "SPL", variable = "conc")
  )
  expect_true(any(issues$severity == "warning"))
})

test_that("validate_workflow_inputs ignores unknown step ids", {
  skip_if(demo_file() == "")
  res <- validate_workflow_inputs(
    demo_file(), "mrmhub",
    metadata_route = "none", steps = "not_a_real_step"
  )
  expect_s3_class(res, "tbl_df")
  expect_equal(res$severity, "ok")
})

test_that("build_experiment attaches msorganiser metadata and surfaces tables mismatches", {
  data_csv <- test_path(
    "testdata/masshunter/MRMhub_TestData_MHQuant_S1P_DefaultSampleInfo_RT-Areas-FWHM.csv"
  )
  msorg <- test_path(
    "testdata/metadata/MRMhub_Metadata_Template_191_20240226_MHQuant_S1P_V1.xlsx"
  )
  tables <- test_path(
    "testdata/metadata/MRMhub_TestData_MHQuant_S1P_metadata_tables.xlsx"
  )
  skip_if(!all(file.exists(c(data_csv, msorg, tables))))

  # msorganiser route attaches metadata.
  mexp <- suppressWarnings(
    build_experiment(data_csv, "masshunter", msorg, "msorganiser")
  )
  expect_gt(nrow(mexp@annot_features), 0)

  # tables route runs import_metadata_tables; a metadata/data mismatch is
  # reported as an import failure rather than crashing the validator.
  res <- suppressWarnings(validate_workflow_inputs(
    data_csv, "masshunter",
    metadata_file = tables, metadata_route = "tables", steps = character()
  ))
  expect_equal(res$severity[1], "error")
})

test_that("build_workflow() aborts when its Shiny dependencies are missing", {
  # build_workflow() guards via rlang::check_installed(), not requireNamespace,
  # so mock that. The runApp mock is a safety net: if the guard is ever
  # bypassed the test fails fast instead of launching a real server and
  # hanging the suite.
  local_mocked_bindings(
    check_installed = function(pkg, ...) {
      rlang::abort("The shiny package is required.")
    },
    .package = "rlang"
  )
  local_mocked_bindings(
    runApp = function(...) stop("runApp() must not be reached when deps are missing"),
    .package = "shiny"
  )
  expect_error(build_workflow(), "shiny")
})

test_that("build_workflow() aborts when only bslib is missing", {
  local_mocked_bindings(
    check_installed = function(pkg, ...) {
      rlang::abort("The bslib package is required.")
    },
    .package = "rlang"
  )
  local_mocked_bindings(
    runApp = function(...) stop("runApp() must not be reached when deps are missing"),
    .package = "shiny"
  )
  expect_error(build_workflow(), "bslib")
})
