# library(fs)
# library(vdiffr)
# library(ggplot2)
# library(testthat)
# library(scales)
set.seed(123)

mexp <- lipidomics_dataset

mexp <- normalize_by_istd(mexp)
mexp <- calc_qc_metrics(mexp)

test_that("plot_responsecurves generates a plot", {
  # Test with valid arguments
  p <- plot_responsecurves(
    data = mexp,
    variable = "intensity",
    rows_page = 3,
    cols_page = 4,
    return_plots = TRUE
  )
  expect_s3_class(p[[1]], "gg")
  # Check how many pages
  expect_equal(length(p), 3)
  expect_doppelganger_cond("default plot_responsecurves plot", p[[1]])

  # Test if the number of points in the plot matches the expected value
  plot_data <- ggplot2::ggplot_build(p[[1]])$data[[1]]
  expect_equal(nrow(plot_data), 1920)

  temp_pdf_path <- file.path(tempdir(), "mrmhub_test_responsecurve.pdf")
  p <- plot_responsecurves(
    data = mexp,
    variable = "intensity",
    rows_page = 3,
    cols_page = 4,
    output_pdf = TRUE,
    path = temp_pdf_path,
    return_plots = FALSE
  )
  expect_null(p)
  expect_true(file_exists(temp_pdf_path), info = "PDF file was not created.")
  size_kb <- as.numeric(fs::file_size(temp_pdf_path)) / 1024
  expect_equal(size_kb, 65.9, tolerance = 0.2)
  fs::file_delete(temp_pdf_path)

  temp_pdf_path <- file.path(tempdir(), "mrmhub_test_responsecurve.pdf")
  p <- plot_responsecurves(
    data = mexp,
    variable = "intensity",
    rows_page = 3,
    cols_page = 4,
    output_pdf = TRUE,
    specific_page = 3,
    path = temp_pdf_path,
    return_plots = FALSE
  )

  expect_silent(p)
  expect_true(file_exists(temp_pdf_path), info = "PDF file was not created.")
  size_kb <- as.numeric(fs::file_size(temp_pdf_path)) / 1024
  expect_equal(size_kb, 15.35, tolerance = 0.2)
  fs::file_delete(temp_pdf_path)

  expect_error(
    p <- plot_responsecurves(
      data = mexp,
      variable = "intensity",
      rows_page = 3,
      cols_page = 4,
      output_pdf = FALSE,
      specific_page = 4,
      return_plots = TRUE
    ),
    "Selected page exceeds "
  )
  p <- plot_responsecurves(
    data = mexp,
    variable = "intensity",
    rows_page = 3,
    cols_page = 4,
    output_pdf = FALSE,
    specific_page = 3,
    return_plots = TRUE
  )
  expect_equal(length(p), 1)

  expect_error(
    p <- plot_responsecurves(
      data = mexp,
      variable = "intensity",
      rows_page = 3,
      cols_page = 4,
      output_pdf = TRUE,
      specific_page = 4,
      return_plots = TRUE
    ),
    "The argument "
  )
})


test_that("plot_responsecurves handles missing data", {
  expect_error(
    p <- plot_responsecurves(
      data = mexp,
      variable = "intensity",
      output_pdf = TRUE,
      return_plots = TRUE
    ),
    "The argument "
  )

  mexp_defect <- mexp
  mexp_defect@dataset <- mexp_defect@dataset |> dplyr::slice_head(n = 0)

  expect_error(
    p <- plot_responsecurves(
      data = mexp_defect,
      variable = "intensity",
      output_pdf = FALSE,
      return_plots = TRUE
    ),
    "No data available in "
  )

  mexp_defect <- mexp
  mexp_defect@dataset$qc_type <- "SPL"

  expect_error(
    p <- plot_responsecurves(
      data = mexp_defect,
      variable = "intensity",
      output_pdf = FALSE,
      return_plots = TRUE
    ),
    "No QC type "
  )

  mexp_defect <- mexp
  mexp_defect@annot_responsecurves <- mexp_defect@annot_responsecurves |>
    dplyr::slice_head(n = 0)

  expect_error(
    p <- plot_responsecurves(
      data = mexp_defect,
      variable = "intensity",
      output_pdf = FALSE,
      return_plots = TRUE
    ),
    "No response curve metadata is available"
  )
})

test_that("curve color definition works", {
  expect_error(
    p <- plot_responsecurves(
      data = mexp,
      variable = "intensity",
      rows_page = 3,
      cols_page = 4,
      output_pdf = FALSE,
      color_curves = "red",
      specific_page = 3,
      return_plots = TRUE
    ),
    "Insufficient colors in `color_curves`. Provide at least 2 unique"
  )

  p <- plot_responsecurves(
    data = mexp,
    variable = "intensity",
    rows_page = 3,
    cols_page = 4,
    output_pdf = FALSE,
    color_curves = c("red", "blue"),
    specific_page = 3,
    return_plots = TRUE
  )

  smooth_data <- ggplot2::ggplot_build(p[[1]])$data
  expect_equal(unique(smooth_data[[1]]$colour), c("red", "blue"))

  p <- plot_responsecurves(
    data = mexp,
    variable = "intensity",
    rows_page = 3,
    cols_page = 4,
    output_pdf = FALSE,
    color_curves = NA,
    specific_page = 3,
    return_plots = TRUE
  )
  smooth_data <- ggplot2::ggplot_build(p[[1]])$data
  expect_equal(unique(smooth_data[[1]]$colour), c("#34629e", "#91bfdb"))

  mexp_temp <- mexp
  mexp_temp@annot_responsecurves$curve_id <- rep(1:6, each = 2)
  p <- plot_responsecurves(
    data = mexp_temp,
    variable = "intensity",
    rows_page = 3,
    cols_page = 4,
    output_pdf = FALSE,
    color_curves = NA,
    specific_page = 3,
    return_plots = TRUE
  )

  smooth_data <- ggplot2::ggplot_build(p[[1]])$data
  expect_equal(
    unique(smooth_data[[1]]$colour),
    c("#F8766D", "#B79F00", "#00BA38", "#00BFC4", "#619CFF", "#F564E3")
  )
})


test_that("`max_regression_value` works", {
  mex_reg_val <- 80

  p <- plot_responsecurves(
    data = mexp,
    variable = "intensity",
    max_regression_value = mex_reg_val,
    rows_page = 3,
    cols_page = 4,
    return_plots = TRUE
  )

  # Extract the regression data from the ggplot object
  # We need to extract the smooth line data for the regression (method = "lm")
  smooth_data <- ggplot2::ggplot_build(p[[1]])$data[[1]]

  # Check that the 'analyzed_amount' values used for regression are <= max_reg_value
  expect_true(
    all(smooth_data$x <= 80),
    info = "Regression data exceeds max_regression_value"
  )
})

test_that("plot_responsecurves feature filters work", {
  # Test with valid arguments
  p <- plot_responsecurves(
    data = mexp,
    variable = "intensity",
    include_feature_filter = "PC",
    exclude_feature_filter = "ISTD",
    rows_page = 3,
    cols_page = 4,
    return_plots = TRUE
  )

  # Check how many pages
  expect_equal(length(p), 1)

  # Test if the number of points in the plot matches the expected value
  plot_data <- ggplot2::ggplot_build(p[[1]])$data[[1]]
  expect_equal(nrow(plot_data), 960)
  expect_equal(mean(plot_data$y), 977995.276)

  expect_error(
    p <- plot_responsecurves(
      data = mexp,
      filter_data = TRUE,
      variable = "norm_intensity",
      include_feature_filter = "PC",
      exclude_feature_filter = "ISTD",
      rows_page = 3,
      cols_page = 4,
      return_plots = TRUE
    ),
    "Data has not been QC-filtered"
  )
  mexp_filt <- mexp
  mexp_filt <- filter_features_qc(
    mexp_filt,
    include_qualifier = FALSE,
    include_istd = FALSE,
    min.intensity.median.spl = 100000
  )

  p <- plot_responsecurves(
    data = mexp_filt,
    filter_data = FALSE,
    variable = "norm_intensity",
    include_feature_filter = "PC",
    exclude_feature_filter = "ISTD",
    rows_page = 3,
    cols_page = 4,
    return_plots = TRUE
  )

  # Test if the number of points in the plot matches the expected value
  plot_data <- ggplot2::ggplot_build(p[[1]])$data[[1]]
  expect_equal(nrow(plot_data), 960)
  expect_equal(mean(plot_data$y), 0.35804775)

  p <- plot_responsecurves(
    data = mexp_filt,
    filter_data = TRUE,
    variable = "norm_intensity",
    include_feature_filter = c("PC 40:6", "PC 40:8"),
    exclude_feature_filter = c("PC 40:1", "PC 40:2"),
    rows_page = 3,
    cols_page = 4,
    return_plots = TRUE
  )

  # Test if the number of points in the plot matches the expected value
  plot_data <- ggplot2::ggplot_build(p[[1]])$data[[1]]
  expect_equal(nrow(plot_data), 320)
  expect_equal(mean(plot_data$y), 0.31212162)

  expect_error(
    p <- plot_responsecurves(
      data = mexp_filt,
      filter_data = TRUE,
      variable = "norm_intensity",
      include_feature_filter = c("PC 40:6", "PC 40:8"),
      exclude_feature_filter = "PC",
      rows_page = 3,
      cols_page = 4,
      return_plots = TRUE
    ),
    "defined feature filter criteria resulted in no"
  )

  mexp_def <- mexp_filt
  mexp_def@dataset$qc_type <- ifelse(
    mexp_def@dataset$qc_type == "RQC",
    "SPL",
    mexp_def@dataset$qc_type
  )
  expect_error(
    p <- plot_responsecurves(
      data = mexp_def,
      filter_data = FALSE,
      variable = "norm_intensity",
      include_feature_filter = c("PC 40:6", "PC 40:8"),
      exclude_feature_filter = "PC",
      rows_page = 3,
      cols_page = 4,
      return_plots = TRUE
    ),
    "No QC type 'RQC'"
  )

  mexp_def <- mexp_filt
  mexp_def@annot_responsecurves$analysis_id <- paste0(
    mexp_def@annot_responsecurves$analysis_id,
    "_no"
  )
  expect_error(
    p <- plot_responsecurves(
      data = mexp_def,
      filter_data = FALSE,
      variable = "norm_intensity",
      include_feature_filter = c("PC 40:6", "PC 40:8"),
      exclude_feature_filter = NA,
      rows_page = 3,
      cols_page = 4,
      return_plots = TRUE
    ),
    "Missmatch between data and response curve metadata"
  )
})

test_that("split_by_curve option works correctly", {
  # Test with split_by_curve = TRUE
  p <- plot_responsecurves(
    data = mexp,
    variable = "intensity",
    rows_page = 3,
    cols_page = 4,
    split_by_curve = TRUE,
    return_plots = TRUE
  )

  expect_s3_class(p[[1]], "gg")

  # Check that facet_grid is used instead of facet_wrap
  built_plot <- ggplot2::ggplot_build(p[[1]])
  # Check that facet_grid2 is used instead of facet_wrap
  facet_type <- class(p[[1]]$facet)[1]
  expect_equal(facet_type, "FacetGrid2")

  # Check that legend is suppressed
  expect_null(p[[1]]$guides$colour)
  expect_null(p[[1]]$guides$fill)

  # Test pagination with split_by_curve
  # Total features: 29, rows_page: 3, should give ceiling(29/3) = 10 pages
  expect_equal(length(p), 10)

  # Test specific page with split_by_curve
  p_page <- plot_responsecurves(
    data = mexp,
    variable = "intensity",
    rows_page = 3,
    split_by_curve = TRUE,
    specific_page = 2,
    return_plots = TRUE
  )
  expect_equal(length(p_page), 1)
  expect_s3_class(p_page[[1]], "gg")

  # Test that cols_page is ignored when split_by_curve = TRUE
  p_with_cols <- plot_responsecurves(
    data = mexp,
    variable = "intensity",
    rows_page = 3,
    cols_page = 10, # Should be ignored
    split_by_curve = TRUE,
    return_plots = TRUE
  )
  expect_equal(length(p_with_cols), 10) # Same as before
})

test_that("fixed_scale_curves option works with split_by_curve", {
  # Test with fixed_scale_curves = TRUE
  p_fixed <- plot_responsecurves(
    data = mexp,
    variable = "intensity",
    rows_page = 3,
    split_by_curve = TRUE,
    fixed_scale_curves = TRUE,
    specific_page = 1,
    return_plots = TRUE
  )

  expect_s3_class(p_fixed[[1]], "gg")

  # Check that facet uses fixed scales (independent = "x" means only x is free,
  # y is shared per row — facet_grid2 stores this in the independent param)
  facet_params <- p_fixed[[1]]$facet$params
  expect_true(facet_params$independent$x)
  expect_false(facet_params$independent$y)

  # Test with fixed_scale_curves = FALSE (default)
  p_free <- plot_responsecurves(
    data = mexp,
    variable = "intensity",
    rows_page = 3,
    split_by_curve = TRUE,
    fixed_scale_curves = FALSE,
    specific_page = 1,
    return_plots = TRUE
  )

  expect_s3_class(p_free[[1]], "gg")

  # Check that facet uses free scales
  facet_params_free <- p_free[[1]]$facet$params
  expect_false(facet_params_free$independent$x)
  expect_true(facet_params_free$independent$y)

  # Test that fixed_scale_curves is silently ignored when split_by_curve = FALSE
  p_ignored <- plot_responsecurves(
    data = mexp,
    variable = "intensity",
    rows_page = 3,
    cols_page = 4,
    split_by_curve = FALSE,
    fixed_scale_curves = TRUE, # Should be ignored
    specific_page = 1,
    return_plots = TRUE
  )

  expect_s3_class(p_ignored[[1]], "gg")
  # Should use facet_wrap, not facet_grid
  facet_type <- class(p_ignored[[1]]$facet)[1]
  expect_true(facet_type != "FacetGrid2")
})

test_that("split_by_curve works with PDF output", {
  temp_pdf_path <- file.path(tempdir(), "mrmhub_test_split_curve.pdf")

  p <- plot_responsecurves(
    data = mexp,
    variable = "intensity",
    rows_page = 3,
    split_by_curve = TRUE,
    output_pdf = TRUE,
    path = temp_pdf_path,
    return_plots = FALSE
  )

  expect_null(p)
  expect_true(file_exists(temp_pdf_path), info = "PDF file was not created.")

  # Check file size is reasonable
  size_kb <- as.numeric(fs::file_size(temp_pdf_path)) / 1024
  expect_true(size_kb > 0, info = "PDF file is empty")

  fs::file_delete(temp_pdf_path)

  # Test with specific page
  temp_pdf_path2 <- file.path(tempdir(), "mrmhub_test_split_curve_page.pdf")

  p <- plot_responsecurves(
    data = mexp,
    variable = "intensity",
    rows_page = 3,
    split_by_curve = TRUE,
    specific_page = 5,
    output_pdf = TRUE,
    path = temp_pdf_path2,
    return_plots = FALSE
  )

  expect_silent(p)
  expect_true(file_exists(temp_pdf_path2), info = "PDF file was not created.")

  fs::file_delete(temp_pdf_path2)
})

test_that("split_by_curve handles edge cases", {
  # Test with single feature
  p_single <- plot_responsecurves(
    data = mexp,
    variable = "intensity",
    include_feature_filter = c("PC 40:6"),
    rows_page = 3,
    split_by_curve = TRUE,
    return_plots = TRUE
  )

  expect_s3_class(p_single[[1]], "gg")
  expect_equal(length(p_single), 1)

  # Test with filtered data
  mexp_filt <- filter_features_qc(
    mexp,
    include_qualifier = FALSE,
    include_istd = FALSE,
    min.intensity.median.spl = 100000
  )

  p_filtered <- plot_responsecurves(
    data = mexp_filt,
    filter_data = TRUE,
    variable = "intensity",
    rows_page = 2,
    split_by_curve = TRUE,
    return_plots = TRUE
  )

  expect_s3_class(p_filtered[[1]], "gg")
  expect_true(length(p_filtered) > 0)
})

test_that("long feature_id labels are wrapped in both split and non-split modes", {
  # Replace first 3 feature_ids with very long names
  long_ids <- c(
    "Ceramide d18:1/16:0 long name feature label",
    "Phosphatidylcholine PC 34:1 with extra long annotation",
    "Lysophosphatidylethanolamine LPE 18:2 very long descriptor label"
  )
  orig_ids <- unique(mexp@dataset$feature_id)[1:3]
  names(long_ids) <- orig_ids

  mexp_long <- mexp
  mexp_long@dataset <- mexp_long@dataset |>
    dplyr::mutate(feature_id = dplyr::recode(.data$feature_id, !!!long_ids))

  # --- split_by_curve = TRUE ---
  p_split <- plot_responsecurves(
    data = mexp_long,
    variable = "intensity",
    rows_page = 3,
    split_by_curve = TRUE,
    label_wrap = TRUE,
    label_wrap_width = 20,
    specific_page = 1,
    include_feature_filter = long_ids,
    return_plots = TRUE,
    show_progress = FALSE
  )

  expect_s3_class(p_split[[1]], "gg")

  # With label_wrap = TRUE, strip labels contain \n inserted by label_wrap_gen
  # We verify by checking the grob text directly
  # Helper: extract all strip text labels from a ggplot gtable
  get_strip_labels <- function(p) {
    gt <- ggplot2::ggplot_gtable(ggplot2::ggplot_build(p))
    strip_grobs <- gt$grobs[grepl("strip", gt$layout$name)]
    sapply(strip_grobs, function(sg) {
      sg$grobs[[1]]$children[[2]]$children[[1]]$label
    })
  }

  # With label_wrap = TRUE, feature_id strip labels contain \n
  strip_labels_split <- get_strip_labels(p_split[[1]])
  expect_true(
    any(stringr::str_detect(strip_labels_split, "\n")),
    info = "Expected line breaks in long feature_id row labels (split_by_curve = TRUE)"
  )

  # --- split_by_curve = FALSE ---
  p_wrap <- plot_responsecurves(
    data = mexp_long,
    variable = "intensity",
    rows_page = 3,
    cols_page = 2,
    split_by_curve = FALSE,
    label_wrap = TRUE,
    label_wrap_width = 20,
    specific_page = 1,
    include_feature_filter = long_ids,
    return_plots = TRUE,
    show_progress = FALSE
  )

  expect_s3_class(p_wrap[[1]], "gg")

  strip_labels_wrap <- get_strip_labels(p_wrap[[1]])
  expect_true(
    any(stringr::str_detect(strip_labels_wrap, "\n")),
    info = "Expected line breaks in long feature_id panel labels (split_by_curve = FALSE)"
  )
})
