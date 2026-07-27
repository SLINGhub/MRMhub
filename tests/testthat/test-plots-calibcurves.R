# library(fs)
# library(vdiffr)
# library(ggplot2)
# library(testthat)
# library(scales)
set.seed(123)

mexp <- quant_lcms_dataset

mexp <- normalize_by_istd(mexp)
mexp <- calc_calibration_results(
  mexp,
  fit_overwrite = TRUE,
  fit_model = "quadratic",
  fit_weighting = "1/x"
)

test_that("plot_responsecurves generates a plot", {
  mexp_temp <- mexp
  mexp_temp@annot_qcconcentrations$concentration[19] <- NA

  # Test with valid arguments
  p <- plot_calibrationcurves(
    data = mexp_temp,
    fit_overwrite = TRUE,
    fit_model = "quadratic",
    fit_weighting = "1/x",
    rows_page = 2,
    cols_page = 2,
    return_plots = TRUE
  )
  expect_s3_class(p[[1]], "gg")
  # Check how many pages
  expect_equal(length(p), 2)
  expect_doppelganger_cond("default plot_calibration plot 1", p[[1]])

  p <- plot_calibrationcurves(
    data = mexp_temp,
    fit_overwrite = TRUE,
    fit_model = "quadratic",
    fit_weighting = "1/x",
    rows_page = 2,
    cols_page = 2,
    specific_page = 2,
    return_plots = TRUE
  )
  expect_equal(length(p), 1)

  # Test with valid arguments and using fit param from feature metadata
  p <- plot_calibrationcurves(
    data = mexp,
    fit_overwrite = FALSE,
    fit_model = "quadratic",
    fit_weighting = "1/x",
    rows_page = 2,
    cols_page = 2,
    return_plots = TRUE
  )
  expect_s3_class(p[[1]], "gg")
  # Check how many pages
  expect_equal(length(p), 2)
  expect_doppelganger_cond("default plot_calibration plot 2 ", p[[1]])

  p <- plot_calibrationcurves(
    data = mexp,
    fit_overwrite = TRUE,
    fit_model = "quadratic",
    ci_show = FALSE,
    fit_weighting = "1/x",
    rows_page = 2,
    cols_page = 2,
    return_plots = TRUE
  )
  expect_s3_class(p[[1]], "gg")
  # Check how many pages
  expect_equal(length(p), 2)
  expect_doppelganger_cond("no ci plot_calibration plot ", p[[1]])

  expect_no_error(
    p <- plot_calibrationcurves(
      data = mexp,
      log_scale = TRUE,
      fit_overwrite = TRUE,
      ci_show = T,
      fit_model = "quadratic",
      fit_weighting = "1/x",
      rows_page = 2,
      cols_page = 2,
      return_plots = TRUE
    )
  )
  expect_doppelganger_cond(
    "log-log plot_calibration plot default ",
    p[[1]]
  )

  expect_message(
    p <- plot_calibrationcurves(
      data = mexp,
      log_scale = TRUE,
      fit_overwrite = TRUE,
      fit_model = "quadratic",
      ci_show = TRUE,
      fit_weighting = "1/x",
      rows_page = 2,
      cols_page = 2,
      return_plots = TRUE
    ),
    "Regions of the regression confidence intervals are partially"
  )
  expect_doppelganger_cond(
    "log-log plot_calibration plot with ci ",
    p[[1]]
  )

  mexp_temp <- mexp
  mexp_temp@dataset <- mexp_temp@dataset |>
    mutate(
      feature_norm_intensity = if_else(
        str_detect(analyte_id, "Cortiso") & analysis_id == "CalA",
        0.000001,
        feature_norm_intensity
      )
    )
  mexp_temp@dataset <- mexp_temp@dataset |>
    mutate(
      feature_norm_intensity = if_else(
        str_detect(analyte_id, "Cortiso") & analysis_id == "CalB",
        0.000001,
        feature_norm_intensity
      )
    )

  # Test with valid arguments
  expect_message(
    p <- plot_calibrationcurves(
      data = mexp_temp,
      fit_overwrite = TRUE,
      fit_model = "linear",
      fit_weighting = "1/x",
      log_scale = TRUE,
      rows_page = 2,
      cols_page = 2,
      return_plots = TRUE
    ),
    "Regions of the regression curve are partially"
  )

  # Test with valid arguments
  expect_message(
    p <- plot_calibrationcurves(
      data = mexp_temp,
      fit_overwrite = TRUE,
      ci_show = TRUE,
      fit_model = "linear",
      fit_weighting = "1/x",
      log_scale = TRUE,
      rows_page = 2,
      cols_page = 2,
      return_plots = TRUE
    ),
    "Regions of the regression curve and confidence intervals are partially"
  )

  # Test if the number of points in the plot matches the expected value
  plot_data <- ggplot2::ggplot_build(p[[1]])$data[[1]]
  expect_equal(nrow(plot_data), 281)

  temp_pdf_path <- file.path(tempdir(), "mrmhub_test_calibcurve.pdf")
  p <- plot_calibrationcurves(
    data = mexp,
    fit_overwrite = TRUE,
    fit_model = "quadratic",
    fit_weighting = "1/x",
    rows_page = 2,
    cols_page = 2,
    output_pdf = TRUE,
    path = temp_pdf_path,
    return_plots = FALSE
  )
  expect_null(p)
  expect_true(file_exists(temp_pdf_path), info = "PDF file was not created.")
  size_kb <- as.numeric(fs::file_size(temp_pdf_path)) / 1024
  expect_equal(size_kb, 27, tolerance = 0.2)
  fs::file_delete(temp_pdf_path)

  temp_pdf_path <- file.path(tempdir(), "mrmhub_test_responsecurve.pdf")
  expect_no_error(
    p <- plot_calibrationcurves(
      data = mexp,
      fit_overwrite = TRUE,
      fit_model = "quadratic",
      fit_weighting = "1/x",
      rows_page = 2,
      cols_page = 2,
      output_pdf = TRUE,
      path = temp_pdf_path,
      return_plots = FALSE
    )
  )

  expect_silent(p)
  expect_true(file_exists(temp_pdf_path), info = "PDF file was not created.")
  size_kb <- as.numeric(fs::file_size(temp_pdf_path)) / 1024
  expect_equal(size_kb, 27, tolerance = 0.2)
  fs::file_delete(temp_pdf_path)

  expect_error(
    p <- plot_calibrationcurves(
      data = mexp,
      fit_overwrite = TRUE,
      fit_model = "quadratic",
      fit_weighting = "1/x",
      rows_page = 2,
      cols_page = 2,
      output_pdf = FALSE,
      specific_page = 3,
      path = temp_pdf_path,
      return_plots = FALSE
    ),
    "Selected page exceeds "
  )
  p <- plot_calibrationcurves(
    data = mexp,
    fit_overwrite = TRUE,
    fit_model = "quadratic",
    fit_weighting = "1/x",
    rows_page = 2,
    cols_page = 2,
    output_pdf = FALSE,
    specific_page = 2,
    path = temp_pdf_path,
    return_plots = TRUE
  )
  expect_equal(length(p), 1)

  expect_error(
    p <- plot_calibrationcurves(
      data = mexp,
      fit_overwrite = TRUE,
      fit_model = "quadratic",
      fit_weighting = "1/x",
      rows_page = 2,
      cols_page = 2,
      output_pdf = TRUE,
      specific_page = 2,
      return_plots = TRUE
    ),
    "The argument "
  )
})


test_that("plot_responsecurves handles missing data", {
  expect_error(
    p <- plot_calibrationcurves(
      data = mexp,
      fit_model = "quadratic",
      fit_weighting = "1/x",
      rows_page = 2,
      cols_page = 2,
      output_pdf = TRUE,
      return_plots = TRUE
    ),
    "The argument "
  )

  mexp_defect <- mexp
  mexp_defect@dataset <- mexp_defect@dataset |> dplyr::slice_head(n = 0)

  expect_error(
    p <- plot_calibrationcurves(
      data = mexp_defect,
      fit_model = "quadratic",
      fit_weighting = "1/x",
      rows_page = 2,
      cols_page = 2,
      output_pdf = FALSE,
      return_plots = TRUE
    ),
    "No data available in "
  )

  mexp_defect <- mexp
  mexp_defect@dataset$qc_type <- "SPL"

  expect_error(
    p <- plot_calibrationcurves(
      data = mexp_defect,
      fit_model = "quadratic",
      fit_weighting = "1/x",
      rows_page = 2,
      cols_page = 2,
      output_pdf = FALSE,
      return_plots = TRUE
    ),
    "No QC type "
  )

  mexp_defect <- mexp
  mexp_defect@annot_qcconcentrations <- mexp_defect@annot_qcconcentrations |>
    dplyr::slice_head(n = 0)

  expect_error(
    p <- plot_calibrationcurves(
      data = mexp_defect,
      fit_model = "quadratic",
      fit_weighting = "1/x",
      rows_page = 2,
      cols_page = 2,
      output_pdf = FALSE,
      return_plots = TRUE
    ),
    "No QC-concentration metadata"
  )
})


test_that("curve color definition works", {
  expect_error(
    p <- plot_calibrationcurves(
      data = mexp,
      fit_model = "quadratic",
      fit_weighting = "1/x",
      rows_page = 2,
      cols_page = 2,
      point_color = c("red", "green"),
      output_pdf = FALSE,
      return_plots = TRUE
    ),
    "Insufficient colors in \\`point_colors\\`"
  )

  expect_error(
    p <- plot_calibrationcurves(
      data = mexp,
      fit_model = "quadratic",
      fit_weighting = "1/x",
      rows_page = 2,
      cols_page = 2,
      point_fill = c("red", "green"),
      output_pdf = FALSE,
      return_plots = TRUE
    ),
    "Insufficient fill colors in \\`point_fill\\`"
  )

  expect_error(
    p <- plot_calibrationcurves(
      data = mexp,
      fit_model = "quadratic",
      fit_weighting = "1/x",
      rows_page = 2,
      cols_page = 2,
      point_shape = c(1, 2),
      output_pdf = FALSE,
      return_plots = TRUE
    ),
    "Insufficient shape codes in \\`point_shape\\`"
  )

  expect_no_error(
    p <- plot_calibrationcurves(
      data = mexp,
      fit_overwrite = TRUE,
      fit_model = "quadratic",
      fit_weighting = "1/x",
      rows_page = 2,
      cols_page = 2,
      point_fill = c("red", "green", "blue"),
      output_pdf = FALSE,
      return_plots = TRUE
    )
  )
  p_data <- ggplot2::ggplot_build(p[[1]])$data
  expect_equal(unique(p_data[[7]]$fill), c("red", "green", "blue"))

  expect_error(
    p <- plot_calibrationcurves(
      data = mexp,
      fit_model = "quadratic",
      fit_weighting = "1/x",
      rows_page = 2,
      cols_page = 2,
      point_color = c("CAL" = "red", "green", "blue"),
      point_fill = c("CAL" = "red", "green", "blue"),
      point_shape = c("CAL" = 22, 21, 23),
      output_pdf = FALSE,
      return_plots = TRUE
    ),
    "The names in \\`point_color\\`"
  )

  expect_error(
    p <- plot_calibrationcurves(
      data = mexp,
      fit_model = "quadratic",
      fit_weighting = "1/x",
      rows_page = 2,
      cols_page = 2,
      point_fill = c("CAL" = "red", "green", "blue"),
      point_shape = c("CAL" = 22, 21, 23),

      output_pdf = FALSE,
      return_plots = TRUE
    ),
    "The names in \\`point_fill\\`"
  )

  expect_error(
    p <- plot_calibrationcurves(
      data = mexp,
      fit_model = "quadratic",
      fit_weighting = "1/x",
      rows_page = 2,
      cols_page = 2,
      point_shape = c("CAL" = 22, 21, 23),

      output_pdf = FALSE,
      return_plots = TRUE
    ),
    "The names in \\`point_shape\\`"
  )

  expect_error(
    p <- plot_calibrationcurves(
      data = mexp,
      fit_model = "quadratic",
      fit_weighting = "1/x",
      rows_page = 2,
      cols_page = 2,
      point_color = c("CAL" = "red", "QC" = "green", "LQC" = "blue"),
      output_pdf = FALSE,
      return_plots = TRUE
    ),
    "The names in \\`point_color\`"
  )

  expect_error(
    p <- plot_calibrationcurves(
      data = mexp,
      fit_model = "quadratic",
      fit_weighting = "1/x",
      qc_types = c("CAL", "QC", "LQC"),
      rows_page = 2,
      cols_page = 2,
      output_pdf = FALSE,
      return_plots = TRUE
    ),
    "One or more specified \\`qc_types\\`"
  )

  expect_error(
    p <- plot_calibrationcurves(
      data = mexp,
      fit_model = "quadratic",
      fit_weighting = "1/x",
      qc_types = c("CAL", "SPL", "LQC"),
      rows_page = 2,
      cols_page = 2,
      output_pdf = FALSE,
      return_plots = TRUE
    ),
    "One or more selected \\`qc_types\\`"
  )

  expect_error(
    p <- plot_calibrationcurves(
      data = mexp,
      filter_data = TRUE,
      fit_model = "quadratic",
      fit_weighting = "1/x",
      rows_page = 2,
      cols_page = 2,
      return_plots = TRUE
    ),
    "Data has not been QC-filtered"
  )

  expect_error(
    p <- plot_calibrationcurves(
      data = mexp,
      filter_data = FALSE,
      fit_overwrite = TRUE,
      fit_model = "quadratic",
      fit_weighting = "1/x",
      rows_page = 2,
      specific_page = 7,
      cols_page = 2,
      return_plots = TRUE
    ),
    "Selected page exceeds the total number",
    fixed = TRUE
  )
})


test_that("plot_responsecurves generates a plot with calib failes", {
  mexp_temp <- mexp
  mexp_temp@annot_qcconcentrations <- mexp_temp@annot_qcconcentrations |>
    mutate(
      concentration = if_else(
        str_detect(analyte_id, "Cortiso") & str_detect(sample_id, "CAL"),
        NA_real_,
        concentration
      )
    )

  # Test with valid arguments
  expect_message(
    p <- plot_calibrationcurves(
      data = mexp_temp,
      fit_overwrite = TRUE,
      fit_model = "quadratic",
      fit_weighting = "1/x",
      rows_page = 2,
      cols_page = 2,
      return_plots = TRUE
    ),
    "Regression failed for 4 features"
  )
  expect_s3_class(p[[1]], "gg")
  expect_equal(length(p), 2)
  expect_doppelganger_cond(
    "default plot_calibration plot log_scale 1",
    p[[2]]
  )

  p <- plot_calibrationcurves(
    data = mexp_temp,
    fit_overwrite = TRUE,
    fit_model = "quadratic",
    fit_weighting = "1/x",
    log_scale = TRUE,
    rows_page = 2,
    cols_page = 2,
    return_plots = TRUE
  )
  expect_s3_class(p[[1]], "gg")
  expect_equal(length(p), 2)
  expect_doppelganger_cond(
    "default plot_calibration plot log_scale 2",
    p[[1]]
  )
})


test_that("plot_responsecurves generates a plot with some calib concs is NA ", {
  mexp_temp <- mexp
  mexp_temp@annot_qcconcentrations <- mexp_temp@annot_qcconcentrations |>
    mutate(
      concentration = if_else(
        str_detect(sample_id, "CAL-F"),
        NA_real_,
        concentration
      )
    )

  p <- plot_calibrationcurves(
    data = mexp_temp,
    fit_overwrite = TRUE,
    fit_model = "quadratic",
    fit_weighting = "1/x",
    log_scale = TRUE,
    rows_page = 2,
    cols_page = 2,
    return_plots = TRUE
  )
  expect_doppelganger_cond("plot_calibration somecal na", p[[1]])
})

# page_orientation was never validated -> a typo silently produced a portrait PDF.
test_that("plot_calibrationcurves rejects an invalid page_orientation", {
  expect_error(
    plot_calibrationcurves(mexp, page_orientation = "landscape"),
    "page_orientation"
  )
})

# Branch 5: shared pretty-axis helper -> >=3 non-empty labels per facet axis.
test_that("plot_calibrationcurves axes render >=3 non-empty labels", {
  axis_labels <- function(p, axis) {
    b <- ggplot2::ggplot_build(p)
    lbl <- b$layout$panel_params[[1]][[axis]]$get_labels()
    lbl[!vapply(
      lbl,
      function(x) is.null(x) || (length(x) == 1 && is.na(x)) ||
        (is.character(x) && !nzchar(x)),
      logical(1)
    )]
  }

  p <- plot_calibrationcurves(
    data = mexp,
    fit_overwrite = TRUE,
    fit_model = "quadratic",
    fit_weighting = "1/x",
    rows_page = 2,
    cols_page = 2,
    return_plots = TRUE
  )
  expect_gte(length(axis_labels(p[[1]], "x")), 3)
  expect_gte(length(axis_labels(p[[1]], "y")), 3)

  p_log <- plot_calibrationcurves(
    data = mexp,
    fit_overwrite = TRUE,
    fit_model = "quadratic",
    fit_weighting = "1/x",
    log_scale = TRUE,
    rows_page = 2,
    cols_page = 2,
    return_plots = TRUE
  )
  expect_gte(length(axis_labels(p_log[[1]], "x")), 3)
  expect_gte(length(axis_labels(p_log[[1]], "y")), 3)
})

test_that("plot_calibrationcurves() creates a missing PDF output directory (create_dir = TRUE)", {
  root <- withr::local_tempdir()
  path <- file.path(root, "plots", "calib.pdf")
  expect_false(dir.exists(dirname(path)))
  p <- plot_calibrationcurves(
    data = mexp,
    fit_overwrite = TRUE,
    fit_model = "quadratic",
    fit_weighting = "1/x",
    rows_page = 2,
    cols_page = 2,
    output_pdf = TRUE,
    path = path,
    show_progress = FALSE
  )
  expect_null(p)
  expect_true(dir.exists(dirname(path)))
  expect_true(fs::file_exists(path))
})

test_that("plot_calibrationcurves() errors writing a PDF into a missing dir when create_dir = FALSE", {
  root <- withr::local_tempdir()
  path <- file.path(root, "missing", "calib.pdf")
  expect_error(
    plot_calibrationcurves(
      data = mexp,
      fit_overwrite = TRUE,
      fit_model = "quadratic",
      fit_weighting = "1/x",
      rows_page = 2,
      cols_page = 2,
      output_pdf = TRUE,
      path = path,
      create_dir = FALSE,
      show_progress = FALSE
    )
  )
  expect_false(fs::file_exists(path))
})
