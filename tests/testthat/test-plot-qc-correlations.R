library(vdiffr)
library(ggplot2)
set.seed(123)

mexp <- lipidomics_dataset


test_that("get_feature_correlations works correctly", {
  # Create test data
  test_data <- data.frame(
    analysis_id = 1:100,
    qc_type = "QC",
    feature1 = rnorm(100),
    feature2 = NA,
    feature3 = rnorm(100)
  )
  test_data$feature2 <- test_data$feature1 # Perfect correlation

  # Test basic functionality
  cors <- get_feature_correlations(test_data, cor_min_neg = -0.9, cor_min = 0.9)
  expect_s3_class(cors, "data.frame")
  expect_equal(names(cors), c("var1", "var2", "value"))
  expect_true(any(cors$value > 0.9)) # Should find high correlation
})

test_that("get_feature_correlations uses pairwise-complete values with 50% overlap", {
  set.seed(1)
  test_data <- data.frame(
    analysis_id = 1:20,
    qc_type = "SPL",
    a = rnorm(20),
    c = rnorm(20)
  )
  test_data$b <- test_data$a * 2 # perfect correlation with a
  test_data$b[1:3] <- NA # few missing: pair kept
  test_data$d <- test_data$a
  test_data$d[1:12] <- NA # overlap below 50%: pair dropped

  expect_message(
    cors <- get_feature_correlations(
      test_data,
      cor_min_neg = -0.9,
      cor_min = 0.9
    ),
    "2 features"
  )
  pairs <- paste(cors$var1, cors$var2)
  expect_true("a b" %in% pairs)
  expect_false(any(c("a d", "b d") %in% pairs))
})


test_that("pages keep each feature pair together when |r| ties", {
  d_plot <- data.frame(
    analysis_id = rep(c("s1", "s2", "s3"), 2),
    qc_type = factor("SPL"),
    x = c(1, 2, 3, 1, 2, 3),
    y = c(1, 2, 3, 3, 2, 1),
    pair = rep(c("A\nB", "C\nD"), each = 3),
    r = rep(c("r = 0.995", "r = -0.995"), each = 3),
    abs_cor = 0.995
  )
  p <- plot_feature_correlations_page(
    d_plot,
    rows_page = 1,
    cols_page = 1,
    specific_page = 1,
    sort_by_corr = TRUE,
    log_scale = FALSE,
    point_size = 1,
    point_alpha = 1,
    point_stroke = 0.5,
    line_width = 0.5,
    line_color = "grey",
    line_alpha = 1,
    font_base_size = 8
  )
  expect_equal(length(unique(as.character(p$data$pair))), 1)
  expect_equal(nrow(p$data), 3)
})


test_that("plot_feature_correlations handles invalid inputs", {
  # Test invalid variable
  expect_error(
    plot_feature_correlations(mexp, variable = "invalid_var"),
    "`variable` must be one of",
    fixed = TRUE
  )

  # Test invalid correlation thresholds
  expect_error(
    plot_feature_correlations(
      mexp,
      variable = "area",
      cor_min_neg = 0.9,
      cor_min = 0.8
    ),
    "Lower correlation threshold must be less than upper threshold"
  )
})

test_that("plot_feature_correlations handles empty results", {
  # Should return NULL with message
  expect_null(
    plot_feature_correlations(
      mexp,
      variable = "intensity",
      cor_min = 0.99,
      cor_min_neg = -0.99
    )
  )

  expect_message(
    plot_feature_correlations(
      mexp,
      variable = "intensity",
      cor_min = 0.99,
      cor_min_neg = -0.99
    ),
    "No correlations found exceeding thresholds",
    fixed = TRUE
  )
})

test_that("plot_feature_correlations respects QC types", {
  # Test QC type filtering
  p <- plot_feature_correlations(
    mexp,
    variable = "area",
    qc_types = c("BQC", "SPL", "RQC"),
    cor_min = 0.8,
    cor_min_neg = -0.9,
    return_plot = TRUE
  )

  # Check that only QC samples are included
  plot_data <- ggplot2::ggplot_build(p[[1]])$data[[3]]
  expect_equal(plot_data[1, "label"], "r = 0.971")

  # Test QC type filtering
  p <- plot_feature_correlations(
    mexp,
    variable = "area",
    cor_min = 0.8,
    cor_min_neg = -0.9,
    return_plot = TRUE
  )

  # Check that only QC samples are included
  plot_data <- ggplot2::ggplot_build(p[[1]])$data[[3]]
  expect_equal(plot_data[1, "label"], "r = 0.969")

  expect_doppelganger_cond("default plot_feature_correlations plot", p)

  # Sort by occurrence in data
  p <- plot_feature_correlations(
    mexp,
    variable = "area",
    sort_by_corr = FALSE,
    cor_min = 0.8,
    cor_min_neg = -0.9,
    log_scale = FALSE,
    return_plot = TRUE
  )

  # Check that only QC samples are included
  plot_data <- ggplot2::ggplot_build(p[[1]])$data[[3]]
  expect_equal(plot_data[1, "label"], "r = 0.860")

  p <- plot_feature_correlations(
    mexp,
    variable = "area",
    cor_min = 0.8,
    sort_by_corr = FALSE,
    cor_min_neg = -0.9,
    log_scale = FALSE,
    return_plot = TRUE
  )

  # Check that only QC samples are included
  plot_data <- ggplot2::ggplot_build(p[[1]])$data[[3]]
  expect_equal(plot_data[1, "label"], "r = 0.860")

  p <- plot_feature_correlations(
    mexp,
    variable = "area",
    cor_min = 0.8,
    sort_by_corr = FALSE,
    cols_page = 2,
    rows_page = 2,
    cor_min_neg = -0.9,
    log_scale = FALSE,
    return_plot = TRUE
  )

  # Check that only QC samples are included
  plot_data <- ggplot2::ggplot_build(p[[3]])$data[[3]]
  expect_equal(plot_data[1, "label"], "r = 0.949")

  p <- plot_feature_correlations(
    mexp,
    variable = "area",
    cor_min = 0.8,
    sort_by_corr = FALSE,
    cols_page = 2,
    rows_page = 2,
    specific_page = 3,
    cor_min_neg = -0.9,
    log_scale = FALSE,
    return_plot = TRUE
  )

  # Check that only QC samples are included
  plot_data <- ggplot2::ggplot_build(p[[1]])$data[[3]]
  expect_equal(plot_data[1, "label"], "r = 0.949")

  expect_error(
    p <- plot_feature_correlations(
      mexp,
      variable = "area",
      cor_min = 0.8,
      sort_by_corr = FALSE,
      cols_page = 2,
      rows_page = 2,
      specific_page = 4,
      cor_min_neg = -0.9,
      log_scale = FALSE,
      return_plot = TRUE
    ),
    "Selected page exceeds the total number of pages"
  )
})

test_that("plot_feature_correlations min intensity", {
  expect_error(
    plot_feature_correlations(
      mexp,
      variable = "intensity",
      cor_min = 0.80,
      min_median_value = 1E8,
      cor_min_neg = -0.99
    ),
    "No features passed the",
    fixed = TRUE
  )
})


test_that("plot_feature_correlations min int left 1 feature", {
  expect_error(
    plot_feature_correlations(
      mexp,
      variable = "intensity",
      cor_min = 0.80,
      min_median_value = 1E7,
      cor_min_neg = -0.99
    ),
    "Only 1 feature passed the",
    fixed = TRUE
  )
})

test_that("plot_feature_correlations exceed page", {
  expect_error(
    plot_feature_correlations(
      mexp,
      variable = "intensity",
      cor_min = 0.80,
      cor_min_neg = -0.99,
      specific_page = 2
    ),
    "Selected page exceeds the total number of pages",
    fixed = TRUE
  )
})

test_that("plot_feature_correlations specific page", {
  p <- plot_feature_correlations(
    mexp,
    variable = "intensity",
    cor_min = 0.80,
    rows_page = 1,
    cols_page = 2,
    cor_min_neg = -0.99,
    return_plot = TRUE
  )
  expect_equal(length(p), 5)

  p <- plot_feature_correlations(
    mexp,
    variable = "intensity",
    cor_min = 0.80,
    rows_page = 1,
    cols_page = 2,
    cor_min_neg = -0.99,
    specific_page = 2,
    return_plot = TRUE
  )
  expect_equal(length(p), 1)
})


test_that("plot_feature_correlations  logscale", {
  # Test QC type filtering
  p <- plot_feature_correlations(
    mexp,
    variable = "area",
    cor_min = 0.8,
    cor_min_neg = -0.9,
    log_scale = TRUE,
    return_plot = TRUE
  )

  # Check that only QC samples are included. Find the r-label layer by its
  # column (the log branch now adds an annotation_logticks layer, so a hard
  # index is fragile) -- see dev-notes 11d.
  b <- ggplot2::ggplot_build(p[[1]])
  label_layer <- which(vapply(b$data, \(x) "label" %in% names(x), logical(1)))
  expect_equal(b$data[[label_layer]][1, "label"], "r = 0.969")

  expect_doppelganger_cond("plot_feature_correlations logscale", p)
})


test_that("plot aesthetics are correctly set", {
  # Test custom aesthetics
  p <- plot_feature_correlations(
    mexp,
    variable = "intensity",
    cor_min = 0.85,
    point_size = 2,
    point_alpha = 0.5,
    line_color = "blue",
    return_plot = TRUE,
    font_base_size = 10
  )

  # Check plot elements
  plot_build <- ggplot2::ggplot_build(p[[1]])

  # Check point size
  expect_equal(plot_build$data[[1]]$size[1], 2)

  # Check point alpha
  expect_equal(plot_build$data[[1]]$alpha[1], 0.5)

  # Check line color
  expect_equal(plot_build$data[[2]]$colour[1], "blue")
})

test_that("save plots", {
  temp_pdf_path <- file.path(tempdir(), "mrmhub_test_responsecurve.pdf")

  p <- plot_feature_correlations(
    mexp,
    variable = "intensity",
    cor_min = 0.85,
    point_size = 2,
    point_alpha = 0.5,
    line_color = "blue",
    output_pdf = TRUE,
    path = temp_pdf_path,

    return_plot = FALSE,
    font_base_size = 10
  )

  expect_null(p)
  expect_true(file_exists(temp_pdf_path), info = "PDF file was not created.")
  size_kb <- as.numeric(fs::file_size(temp_pdf_path)) / 1024
  expect_equal(size_kb, 239, tolerance = 0.2)
  fs::file_delete(temp_pdf_path)
})

test_that("plot_feature_correlations keeps QC types outside the legacy level set", {
  # quant_lcms_dataset carries HQC/LQC, which the default selection includes.
  # A hard-coded 9-of-20 qc_type factor made them NA, and a bare drop_na() then
  # deleted those rows -> the QC samples vanished from the correlation plot.
  p <- suppressMessages(suppressWarnings(plot_feature_correlations(
    quant_lcms_dataset,
    variable = "intensity",
    cor_min = 0,
    cor_min_neg = -1,
    return_plots = TRUE
  )))
  qc <- p[[1]]$data$qc_type
  expect_true(all(c("HQC", "LQC") %in% as.character(qc)))
  expect_false(any(is.na(qc)))
})

# page_orientation was never validated -> a typo silently produced a portrait PDF.
test_that("plot_feature_correlations rejects an invalid page_orientation", {
  expect_error(
    plot_feature_correlations(mexp, page_orientation = "landscape"),
    "page_orientation"
  )
})

# Branch 5: the shared pretty-axis helper must give >=3 non-empty labels on
# every facet axis (old scientific_format_end blanked all but 0/max).
test_that("plot_feature_correlations axes render >=3 non-empty labels", {
  axis_labels <- function(p, axis) {
    b <- ggplot2::ggplot_build(p)
    lbl <- b$layout$panel_params[[1]][[axis]]$get_labels()
    lbl[
      !vapply(
        lbl,
        function(x)
          is.null(x) ||
            (length(x) == 1 && is.na(x)) ||
            (is.character(x) && !nzchar(x)),
        logical(1)
      )
    ]
  }

  p <- plot_feature_correlations(
    mexp,
    variable = "area",
    qc_types = c("BQC", "SPL", "RQC"),
    cor_min = 0.8,
    cor_min_neg = -0.9,
    return_plots = TRUE
  )
  expect_gte(length(axis_labels(p[[1]], "x")), 3)
  expect_gte(length(axis_labels(p[[1]], "y")), 3)

  p <- plot_feature_correlations(
    mexp,
    variable = "area",
    qc_types = c("BQC", "SPL", "RQC"),
    cor_min = 0.8,
    cor_min_neg = -0.9,
    log_scale = TRUE,
    return_plots = TRUE
  )
  expect_gte(length(axis_labels(p[[1]], "x")), 3)
  expect_gte(length(axis_labels(p[[1]], "y")), 3)
})

test_that("non-positive values are dropped only on log axes", {
  d_plot <- data.frame(
    analysis_id = c("s1", "s2", "s3"),
    qc_type = factor("SPL"),
    x = c(-1, 2, 3),
    y = c(1, -2, 3),
    pair = "A\nB",
    r = "r = 0.500",
    abs_cor = 0.5
  )
  page <- function(log_scale) {
    plot_feature_correlations_page(
      d_plot,
      rows_page = 1,
      cols_page = 1,
      specific_page = 1,
      sort_by_corr = TRUE,
      log_scale = log_scale,
      point_size = 1,
      point_alpha = 1,
      point_stroke = 0.5,
      line_width = 0.5,
      line_color = "grey",
      line_alpha = 1,
      font_base_size = 8
    )
  }
  expect_equal(nrow(page(FALSE)$data), 3)
  expect_equal(nrow(page(TRUE)$data), 1)
})
