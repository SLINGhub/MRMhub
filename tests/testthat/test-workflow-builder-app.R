# Tests for the workflow-builder Shiny app (inst/shiny/workflow-builder/app.R).
# The generator/validator have their own pure tests in test-build-workflow.R;
# here we exercise the app's reactive wiring with shiny::testServer (no browser)
# and add one guarded, browser-level shinytest2 smoke of the real app.
#
# testServer does not apply UI input defaults, so tests set the inputs the real
# browser would already carry (e.g. importer = "mrmhub").

app_dir <- function()
  system.file("shiny", "workflow-builder", package = "mrmhub")

test_that("with no data the welcome gate is closed but a template preview renders", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")
  skip_if(app_dir() == "")

  shiny::testServer(app_dir(), {
    session$setInputs(importer = "mrmhub")
    expect_false(has_data())
    # Even before any upload the preview shows a runnable template.
    expect_match(output$qmd_preview, "mexp <- MRMhubExperiment()", fixed = TRUE)
  })
})

test_that("loading the bundled example opens the builder and previews a real workflow", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")
  skip_if(app_dir() == "")
  skip_if(system.file("extdata", "MRMhub_demo.tsv", package = "mrmhub") == "")

  shiny::testServer(app_dir(), {
    # "Try the example" wires up the bundled demo (with embedded metadata).
    session$setInputs(
      importer = "mrmhub",
      metadata_route = "embedded",
      load_demo = 1
    )
    expect_true(has_data())
    expect_equal(data_name(), "MRMhub_demo.tsv")
    expect_s4_class(mexp_r(), "MRMhubExperiment")

    # Tick the steps the demo actually supports, then confirm the generated qmd
    # and that the demo's embedded metadata validates without errors.
    session$setInputs(
      step_normalize_istd = TRUE,
      step_qc_metrics = TRUE,
      step_filter_qc = TRUE
    )
    expect_true("normalize_istd" %in% selected_steps())
    expect_match(
      output$qmd_preview,
      "mexp <- normalize_by_istd(mexp)",
      fixed = TRUE
    )

    issues <- mrmhub:::workflow_step_issues(mexp_r(), selected_steps())
    expect_false(any(issues$severity == "error"))
  })
})

test_that("a generic wide CSV waits for column config, then imports", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")
  skip_if(app_dir() == "")
  wide <- system.file("extdata", "plain_wide_dataset.csv", package = "mrmhub")
  skip_if(wide == "")

  shiny::testServer(app_dir(), {
    session$setInputs(importer = "csv_wide")
    session$setInputs(
      data_file = data.frame(
        name = "plain_wide_dataset.csv",
        size = 1L,
        type = "text/csv",
        datapath = wide,
        stringsAsFactors = FALSE
      )
    )
    expect_true(has_data())
    # Not configured yet -> no experiment, but the code preview still renders
    # (the app always shows the .qmd once a data file is chosen).
    expect_null(mexp_r())
    expect_match(output$qmd_preview, "import_data_csv_wide", fixed = TRUE)

    # Configure the columns -> the experiment imports without error.
    csv_cfg$variable_name <- "area"
    csv_cfg$configured <- TRUE
    expect_s4_class(mexp_r(), "MRMhubExperiment")
  })
})

test_that("selecting drift on the demo emits an uncommented spline call", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")
  skip_if(app_dir() == "")
  skip_if(system.file("extdata", "MRMhub_demo.tsv", package = "mrmhub") == "")

  shiny::testServer(app_dir(), {
    session$setInputs(
      importer = "mrmhub",
      metadata_route = "embedded",
      load_demo = 1
    )
    session$setInputs(step_normalize_istd = TRUE, step_correct_drift = TRUE)
    qmd <- output$qmd_preview
    # The demo carries BQC/TQC, so drift is auto-referenced and emitted live
    # (not commented out).
    expect_match(qmd, "correct_drift_cubicspline(mexp", fixed = TRUE)
    expect_no_match(qmd, "# mexp <- correct_drift_cubicspline", fixed = TRUE)
  })
})

test_that("the app launches and drives the happy path (shinytest2, local only)", {
  skip_on_cran()
  skip_on_ci() # chromote/Chrome not guaranteed in CI; this is a local check
  skip_if_not_installed("shinytest2")
  skip_if(app_dir() == "")

  # Needs an installed mrmhub (the app subprocess does library(mrmhub)) plus a
  # working chromote/Chrome. Skip cleanly rather than fail if either is absent.
  app <- tryCatch(
    shinytest2::AppDriver$new(
      app_dir(),
      name = "workflow-builder",
      height = 820,
      width = 1200
    ),
    error = function(e) NULL
  )
  skip_if(
    is.null(app),
    "could not launch the app (needs installed mrmhub + chromote)"
  )
  withr::defer(app$stop())

  # Welcome screen -> load the bundled example -> the builder previews a real
  # workflow for the demo.
  app$click("load_demo")
  app$wait_for_idle(timeout = 20000)

  # The demo carries embedded metadata, so that route must be (and stay)
  # selected through the update round-trip -- guards the startup/ordering bug
  # where the choice was stripped before the loader could pick it.
  expect_equal(app$get_value(input = "metadata_route"), "embedded")

  qmd <- app$get_value(output = "qmd_preview")
  expect_match(qmd, "import_data_mrmhub", fixed = TRUE)
  # Embedded metadata enables ISTD normalisation, so it appears by default.
  expect_match(qmd, "normalize_by_istd", fixed = TRUE)
})
