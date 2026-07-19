library(vdiffr)
library(ggplot2)

mexp <- lipidomics_dataset
mexp_nonorm <- mexp
mexp <- normalize_by_istd(mexp)
mexp <- calc_qc_metrics(mexp) # Ensure calc_qc_metrics is executed before
mexp <- filter_features_qc(
  mexp,
  include_qualifier = TRUE,
  include_istd = FALSE,
  max.cv.intensity.bqc = 10
)

test_that("plot_normalization_qc() generates a plot", {
  # Test with valid arguments
  p <- plot_normalization_qc(
    data = mexp,
    before_norm_var = "intensity",
    after_norm_var = "norm_intensity",
    plot_type = "diff",
    qc_type = NA,
    facet_by_class = TRUE
  )
  # Check if a ggplot object is returned
  expect_s3_class(p, "gg")

  # Extract the plot's data (data frame used for the first layer)
  plot_data <- ggplot2::ggplot_build(p)$data[[1]]
  # Test if the number of points in the plot matches the expected value
  expect_equal(nrow(plot_data), 9)

  expect_error(
    plot_normalization_qc(
      data = mexp,
      before_norm_var = "conc",
      after_norm_var = "norm_intensity",
      plot_type = "diff",
      qc_type = "BQC",
      facet_by_class = TRUE
    ),
    "`before_norm_var` must be one of"
  )
  expect_error(
    plot_normalization_qc(
      data = mexp,
      before_norm_var = "norm_intensity",
      after_norm_var = "intensity",
      plot_type = "diff",
      qc_type = "BQC",
      facet_by_class = TRUE
    ),
    "`after_norm_var` must be one of"
  )

  expect_error(
    plot_normalization_qc(
      data = mexp,
      before_norm_var = "conc_raw",
      after_norm_var = "conc_raw",
      plot_type = "diff",
      qc_type = "BQC",
      facet_by_class = TRUE
    ),
    "`before_norm_var` and `after_norm_var` cannot be the same",
    fixed = TRUE
  )

  expect_error(
    plot_normalization_qc(
      data = mexp,
      before_norm_var = "conc_raw",
      after_norm_var = "intensity",
      qc_type = "BQC",
      plot_type = "diff",
      facet_by_class = TRUE
    ),
    "`after_norm_var` must be one of",
    fixed = TRUE
  )

  expect_error(
    plot_normalization_qc(
      data = mexp,
      before_norm_var = "intensity",
      after_norm_var = "norm_intensity",
      qc_type = "UNdefind",
      facet_by_class = TRUE,
      plot_type = "diff"
    ),
    "One or more specified `qc_types` are not present in the dataset",
    fixed = TRUE
  )
})

# tests/testthat/test-plot-qc-comparisons.R

# --- Visual Regression Tests for plot_normalization_qc ---

test_that("plot_normalization_qc generates correct plot types", {
  p_scatter <- plot_normalization_qc(
    data = mexp,
    before_norm_var = "intensity",
    after_norm_var = "norm_intensity",
    plot_type = "scatter",
    qc_types = "BQC"
  )
  expect_doppelganger_cond("norm-qc-scatter", p_scatter)

  p_diff <- plot_normalization_qc(
    data = mexp,
    before_norm_var = "intensity",
    after_norm_var = "norm_intensity",
    plot_type = "diff",
    qc_types = "BQC"
  )
  expect_doppelganger_cond("norm-qc-diff", p_diff)

  p_ratio <- plot_normalization_qc(
    data = mexp,
    before_norm_var = "intensity",
    after_norm_var = "norm_intensity",
    plot_type = "ratio",
    qc_types = "BQC"
  )
  expect_doppelganger_cond("norm-qc-ratio", p_ratio)
})

test_that("plot_normalization_qc does not clip an improved CV", {
  # For `diff` and `ratio` a negative y is the improvement -- the feature's CV
  # went down. A `c(0, NA)` y_lim clipped exactly those points, so normalization
  # looked inert. Count what is drawn against what was computed.
  drawn_y <- function(p) {
    b <- suppressWarnings(ggplot2::ggplot_build(p))
    layer <- which(vapply(b$data, \(x) "y" %in% names(x), logical(1)))[1]
    b$data[[layer]]$y
  }

  for (type in c("diff", "ratio")) {
    p <- plot_normalization_qc(
      data = mexp,
      before_norm_var = "intensity",
      after_norm_var = "norm_intensity",
      plot_type = type,
      qc_types = "SPL"
    )
    computed <- p$data$y_values
    expect_true(any(computed < 0, na.rm = TRUE)) # the fixture exercises it
    expect_equal(sum(!is.na(drawn_y(p))), sum(!is.na(computed)))
  }

  # An explicit y_lim still wins, clipping as asked.
  p_clipped <- plot_normalization_qc(
    data = mexp,
    before_norm_var = "intensity",
    after_norm_var = "norm_intensity",
    plot_type = "diff",
    qc_types = "SPL",
    y_lim = c(0, NA_real_)
  )
  expect_lt(
    sum(!is.na(drawn_y(p_clipped))),
    sum(!is.na(p_clipped$data$y_values))
  )
})

test_that("plot_normalization_qc faceting works", {
  p_faceted <- plot_normalization_qc(
    data = mexp,
    before_norm_var = "intensity",
    after_norm_var = "norm_intensity",
    plot_type = "scatter",
    qc_types = "SPL",
    facet_by_class = TRUE
  )
  expect_doppelganger_cond("norm-qc-faceted", p_faceted)

  # Object check for faceting
  built_plot <- ggplot_build(p_faceted)
  expect_gt(length(built_plot$layout$panel_params), 1)
})


test_that("plot_normalization_qc pre-flight checks for data state work", {
  # Test on data that has not been normalized
  expect_error(
    plot_normalization_qc(
      mexp_nonorm,
      plot_type = "diff",
      before_norm_var = "intensity",
      after_norm_var = "norm_intensity",
      qc_types = "BQC"
    ),
    "Data has not yet been normalized",
    fixed = TRUE
  )

  # Test on data without QC metrics
  mexp_no_metrics <- mexp
  mexp_no_metrics@metrics_qc <- mexp_no_metrics@metrics_qc[0, ] # Empty the table
  expect_error(
    plot_normalization_qc(
      mexp_no_metrics,
      before_norm_var = "intensity",
      after_norm_var = "norm_intensity",
      plot_type = "diff"
    ),
    "No QC metrics available yet",
    fixed = TRUE
  )

  expect_error(
    plot_normalization_qc(
      mexp_no_metrics,
      after_norm_var = "norm_intensity",
      plot_type = "diff"
    ),
    "`before_norm_var` and `after_norm_var` must be supplied",
    fixed = TRUE
  )
  expect_error(
    plot_normalization_qc(
      mexp_no_metrics,
      before_norm_var = "norm_intensity",
      plot_type = "diff"
    ),
    "`before_norm_var` and `after_norm_var` must be supplied",
    fixed = TRUE
  )
  expect_error(
    plot_normalization_qc(
      mexp_no_metrics,
      before_norm_var = "intensity",
      after_norm_var = "norm_intensity"
    ),
    "`plot_type` must be supplied ('scatter', 'diff', or 'ratio')",
    fixed = TRUE
  )
})

test_that("plot_normalization_qc constructs correct axis labels", {
  # This object check verifies the internal logic without a visual diff
  p_diff <- plot_normalization_qc(
    mexp,
    before_norm_var = "intensity",
    after_norm_var = "norm_intensity",
    plot_type = "diff",
    qc_types = "BQC"
  )

  built_plot <- ggplot_build(p_diff)

  expect_equal(
    built_plot$plot$scales$get_scales("y")$name,
    "norm_intensity_cv - intensity_cv"
  )
  expect_equal(
    built_plot$plot$scales$get_scales("x")$name,
    "Mean of intensity_cv and norm_intensity_cv"
  )

  p_ratio <- plot_normalization_qc(
    mexp,
    before_norm_var = "intensity",
    after_norm_var = "norm_intensity",
    plot_type = "ratio",
    qc_types = "BQC"
  )
  built_plot <- ggplot_build(p_ratio)
  expect_equal(
    built_plot$plot$scales$get_scales("y")$name,
    "log2( norm_intensity_cv / intensity_cv )"
  )

  p_ratio <- plot_normalization_qc(
    mexp,
    before_norm_var = "intensity",
    after_norm_var = "norm_intensity",
    plot_type = "scatter",
    qc_types = "BQC"
  )
  built_plot <- ggplot_build(p_ratio)
  expect_equal(
    built_plot$plot$scales$get_scales("y")$name,
    "QC metric: norm_intensity_cv"
  )
})


# --- Tests for plot_qcmetrics_comparison ---

test_that("plot_qcmetrics_comparison plot looks as expected", {
  p <- plot_qcmetrics_comparison(
    data = mexp,
    x_variable = "rt_median_bqc",
    y_variable = "norm_intensity_cv_bqc",
    plot_type = "scatter",
    y_shared = TRUE,
    equality_line = FALSE,
    facet_by_class = TRUE
  )
  expect_doppelganger_cond("default plot_qcmetrics_comparison plot", p)
})

test_that("plot_qcmetrics_comparison plot no facets", {
  p <- plot_qcmetrics_comparison(
    data = mexp,
    x_variable = "rt_median_bqc",
    y_variable = "norm_intensity_cv_bqc",
    plot_type = "scatter",
    y_shared = TRUE,
    equality_line = FALSE,
    facet_by_class = FALSE
  )
  expect_doppelganger_cond("nofacet plot_qcmetrics_comparison plot", p)
})

test_that("plot_qcmetrics_comparison labels a single-QC-type comparison by its type", {
  # Two different metrics sharing one qc_type suffix (rt_median_bqc vs
  # norm_intensity_cv_bqc) -> every point is BQC, so the legend shows BQC
  # instead of collapsing to an unlabelled "NONE".
  p <- plot_qcmetrics_comparison(
    data = mexp,
    x_variable = "rt_median_bqc",
    y_variable = "norm_intensity_cv_bqc",
    plot_type = "scatter",
    facet_by_class = FALSE
  )
  expect_setequal(unique(ggplot2::ggplot_build(p)$plot$data$qc_type), "BQC")
  expect_identical(ggplot2::get_guide_data(p, "colour")$.label, "BQC")
  # the QC type is in the legend, so the axis titles drop the "_bqc" suffix
  expect_identical(ggplot2::get_labs(p)$x, "QC metric: rt_median")
  expect_identical(ggplot2::get_labs(p)$y, "QC metric: norm_intensity_cv")

  # Different metrics with different qc_type suffixes (bqc vs tqc) have no single
  # type -> the points stay unlabelled ("NONE") and no qc_type legend is drawn.
  p2 <- plot_qcmetrics_comparison(
    data = mexp,
    x_variable = "rt_median_bqc",
    y_variable = "norm_intensity_cv_tqc",
    plot_type = "scatter",
    facet_by_class = FALSE
  )
  expect_setequal(unique(ggplot2::ggplot_build(p2)$plot$data$qc_type), "NONE")
  # no single QC type -> the suffix stays, so the two axes remain distinguishable
  expect_identical(ggplot2::get_labs(p2)$x, "QC metric: rt_median_bqc")
  expect_identical(ggplot2::get_labs(p2)$y, "QC metric: norm_intensity_cv_tqc")
})

test_that("plot_qcmetrics_comparison combines multiple QC types for a shared-vs-per-type metric", {
  # Unsuffixed metric names (rt_median vs norm_intensity_cv) match every qc_type
  # variant, so the plot combines all QC types, coloured + legended by qc_type
  # (the "rt vs CV" view). The axis titles keep the bare metric names.
  p <- plot_qcmetrics_comparison(
    data = mexp,
    x_variable = "rt_median",
    y_variable = "norm_intensity_cv",
    plot_type = "scatter",
    facet_by_class = FALSE
  )
  expect_setequal(
    unique(ggplot2::ggplot_build(p)$plot$data$qc_type),
    c("BQC", "TQC", "SPL", "LTR")
  )
  expect_setequal(
    ggplot2::get_guide_data(p, "colour")$.label,
    c("BQC", "TQC", "SPL", "LTR")
  )
  expect_identical(ggplot2::get_labs(p)$x, "QC metric: rt_median")
  # the autoscaled x (rt_median) gets 10% room; the CV y axis is pinned at 0 and
  # kept tight at 5% (the old 20% left a large empty band below 0)
  expect_equal(p$scales$get_scales("x")$expand, ggplot2::expansion(mult = 0.1))
  expect_equal(p$scales$get_scales("y")$expand, ggplot2::expansion(mult = 0.05))
  expect_doppelganger_cond("plot_qcmetrics_comparison multiple qc types", p)
})

# this comparison doesnt make sense, but it tests the plotting function
test_that("plot_qcmetrics_comparison plot looks as expected", {
  p <- plot_qcmetrics_comparison(
    data = mexp,
    x_variable = "rt_median_bqc",
    y_variable = "norm_intensity_cv_bqc",
    plot_type = "diff",
    y_shared = TRUE,
    equality_line = FALSE,
    facet_by_class = TRUE
  )
  expect_doppelganger_cond("diff plot_qcmetrics_comparison plot", p)
})

# this comparison doesnt make sense, but it tests the plotting function
test_that("plot_qcmetrics_comparison plot looks as expected", {
  p <- plot_qcmetrics_comparison(
    data = mexp,
    x_variable = "rt_median_bqc",
    y_variable = "norm_intensity_cv_bqc",
    plot_type = "ratio",
    y_shared = TRUE,
    equality_line = FALSE,
    facet_by_class = TRUE
  )
  expect_doppelganger_cond("plot_qcmetrics_comparison ratio ", p)
})

test_that("plot_qcmetrics_comparison plot looks as expected", {
  p <- plot_qcmetrics_comparison(
    data = mexp,
    x_variable = "rt_median_bqc",
    y_variable = "norm_intensity_cv_bqc",
    plot_type = "scatter",
    y_shared = FALSE,
    equality_line = FALSE,
    filter_data = FALSE,
    include_qualifier = FALSE,
    facet_by_class = TRUE
  )
  # Extract the plot's data (data frame used for the first layer)
  plot_data <- ggplot2::ggplot_build(p)$data[[1]]
  # Test if the number of points in the plot matches the expected value
  expect_equal(nrow(plot_data), 19)
  expect_doppelganger_cond("plot_qcmetrics_comparison 1panel", p)
})

test_that("plot_qcmetrics_comparison plot looks as expected", {
  p <- plot_qcmetrics_comparison(
    data = mexp,
    x_variable = "rt_median_bqc",
    y_variable = "norm_intensity_cv_bqc",
    plot_type = "scatter",
    y_shared = FALSE,
    equality_line = FALSE,
    filter_data = FALSE,
    include_qualifier = TRUE,
    facet_by_class = TRUE
  )
  # Extract the plot's data (data frame used for the first layer)
  plot_data <- ggplot2::ggplot_build(p)$data[[1]]
  # Test if the number of points in the plot matches the expected value
  expect_equal(nrow(plot_data), 20)
})

test_that("plot_qcmetrics_comparison data filter works", {
  p <- plot_qcmetrics_comparison(
    data = mexp,
    x_variable = "rt_median_bqc",
    y_variable = "norm_intensity_cv_bqc",
    plot_type = "scatter",
    filter_data = TRUE,
    y_shared = FALSE,
    equality_line = FALSE,
    facet_by_class = TRUE
  )
  # Extract the plot's data (data frame used for the first layer)
  plot_data <- ggplot2::ggplot_build(p)$data[[1]]
  # Test if the number of points in the plot matches the expected value
  expect_equal(nrow(plot_data), 6)
  expect_doppelganger_cond("plot_qcmetrics_comparison filter", p)
})

test_that("plot_qcmetrics_comparison plot threshold", {
  p <- plot_qcmetrics_comparison(
    data = mexp,
    x_variable = "rt_median_bqc",
    y_variable = "norm_intensity_cv_bqc",
    plot_type = "scatter",
    y_shared = FALSE,
    threshold_value = 10,
    facet_by_class = TRUE
  )
  expect_doppelganger_cond("plot_qcmetrics_comparison threshold1", p)
})

test_that("plot_qcmetrics_comparison plot log", {
  p <- plot_qcmetrics_comparison(
    data = mexp,
    x_variable = "rt_median_bqc",
    y_variable = "norm_intensity_cv_bqc",
    plot_type = "scatter",
    y_shared = FALSE,
    threshold_value = c(NA, 10),
    facet_by_class = TRUE
  )
  expect_doppelganger_cond("plot_qcmetrics_comparison threshold2", p)
})


test_that("plot_qcmetrics_comparison plot looks as expected", {
  p <- plot_qcmetrics_comparison(
    data = mexp,
    x_variable = "rt_median_bqc",
    y_variable = "norm_intensity_cv_bqc",
    plot_type = "scatter",
    y_shared = FALSE,
    threshold_value = c(NA, 10),
    facet_by_class = TRUE,
    log_scale = TRUE
  )
  expect_doppelganger_cond("plot_qcmetrics_comparison thresholdlog", p)
})


test_that("plot_qcmetrics_comparison error handling works", {
  expect_error(
    p <- plot_qcmetrics_comparison(
      data = mexp,
      x_variable = "rt_median_bqc",
      y_variable = "norm_intensity_cv_bqc",
      plot_type = "scatter",
      y_shared = FALSE,
      y_lim = c(0, 10),
      facet_by_class = TRUE,
      log_scale = TRUE
    ),
    "Log scale cannot be used with zero, negative, infinite, or NA axis limits",
    fixed = TRUE
  )

  # Test faceting when feature_class column is missing
  mexp_no_class <- mexp
  mexp_no_class@metrics_qc$feature_class <- NULL
  expect_error(
    p <- plot_qcmetrics_comparison(
      data = mexp_no_class,
      x_variable = "rt_median_bqc",
      y_variable = "norm_intensity_cv_bqc",
      plot_type = "scatter",
      y_shared = FALSE,
      facet_by_class = TRUE,
      log_scale = TRUE
    ),
    "`feature_class` to be defined in the metadata",
    fixed = TRUE
  )
})


test_that("get_feature_correlations returns correct filtered long format", {
  # Create example data
  set.seed(123)
  df <- tibble(
    analysis_id = paste0("sample", 1:5),
    qc_type = rep("BQC", 5),
    feat1 = rnorm(5),
    feat2 = rnorm(5),
    feat3 = rnorm(5)
  )

  # Run the function with thresholds
  res <- get_feature_correlations(df, cor_min_neg = -0.2, cor_min = 0.2)

  # Check that result is a tibble/data.frame
  expect_s3_class(res, "data.frame")

  # Check required columns exist
  expect_true(all(c("var1", "var2", "value") %in% colnames(res)))

  # Check only upper triangle correlations are included
  expect_true(all(res$var1 < res$var2))

  # Check thresholds
  expect_true(all(res$value <= -0.2 | res$value >= 0.2))

  # Check number of rows is <= ncol(numeric choose 2)
  numeric_cols <- df |> select(where(is.numeric)) |> colnames()
  n_pairs <- choose(length(numeric_cols), 2)
  expect_lte(nrow(res), n_pairs)
})

test_that("function works when no correlations pass thresholds", {
  set.seed(42)
  df <- tibble(
    analysis_id = paste0("sample", 1:3),
    qc_type = "BQC",
    x = c(1, 2, 3),
    y = c(4, 5, 6)
  )

  # Use high thresholds to filter everything out
  res <- get_feature_correlations(df, cor_min_neg = -1, cor_min = 2)

  expect_s3_class(res, "data.frame")
  expect_equal(nrow(res), 0) # no correlations pass thresholds
})

test_that("plot_qcmetrics_comparison honors qc_types and does not pool QC types", {
  # Regression (WS-P(A)): the !var_has_qctype pivot branch never filtered
  # qc_type, so requesting a single QC type pooled every QC type present in the
  # CV columns. Fails on the old code.
  p <- plot_qcmetrics_comparison(
    data = mexp,
    x_variable = "intensity_cv",
    y_variable = "norm_intensity_cv",
    plot_type = "scatter",
    qc_types = "BQC"
  )
  expect_setequal(unique(p$data$qc_type), "BQC")

  # Confirm the test exercises the leaky branch: unfiltered, it pools >1 QC type.
  p_all <- plot_qcmetrics_comparison(
    data = mexp,
    x_variable = "intensity_cv",
    y_variable = "norm_intensity_cv",
    plot_type = "scatter",
    qc_types = NA
  )
  expect_gt(length(unique(p_all$data$qc_type)), 1)
})

test_that("plot_qcmetrics_comparison() keeps features with NA feature_class", {
  # A bare drop_na() used to drop any feature whose (optional) feature_class was
  # NA, even with facet_by_class = FALSE. The drop must be scoped to the plotted
  # CV columns.
  m <- lipidomics_dataset |> normalize_by_istd() |> quantify_by_istd()
  m <- calc_qc_metrics(m)
  args <- list(
    x_variable = "intensity_cv_tqc",
    y_variable = "intensity_cv_bqc",
    plot_type = "scatter",
    facet_by_class = FALSE
  )
  p_clean <- suppressMessages(suppressWarnings(
    do.call(plot_qcmetrics_comparison, c(list(m), args))
  ))
  na_feat <- unique(p_clean$data$feature_id)[1] # guaranteed drawn with a class
  m@metrics_qc$feature_class[m@metrics_qc$feature_id == na_feat] <- NA
  p_na <- suppressMessages(suppressWarnings(
    do.call(plot_qcmetrics_comparison, c(list(m), args))
  ))
  expect_true(na_feat %in% p_na$data$feature_id)
})

test_that("plot_qcmetrics_comparison starts only CV scatter axes at 0", {
  # A scatter CV axis (>= 0) gets a 0 lower limit (visible origin); a non-CV
  # metric (e.g. rt_median) autoscales. diff/ratio keep NA lower limits so their
  # negative (CV-improved) values are not clipped.
  m <- lipidomics_dataset |> normalize_by_istd() |> calc_qc_metrics()
  lower <- function(pt, xv, yv) {
    p <- suppressMessages(suppressWarnings(plot_qcmetrics_comparison(
      m,
      x_variable = xv,
      y_variable = yv,
      plot_type = pt,
      facet_by_class = FALSE
    )))
    b <- ggplot2::ggplot_build(p)
    c(
      x = b$layout$panel_scales_x[[1]]$limits[1],
      y = b$layout$panel_scales_y[[1]]$limits[1]
    )
  }
  # CV vs CV scatter: both axes pinned to 0
  expect_equal(
    unname(lower("scatter", "intensity_cv_tqc", "intensity_cv_bqc")),
    c(0, 0)
  )
  # non-CV x (rt_median) autoscales; the CV y still starts at 0
  rt <- lower("scatter", "rt_median_bqc", "norm_intensity_cv_bqc")
  expect_true(is.na(rt[["x"]]))
  expect_equal(rt[["y"]], 0)
  # diff/ratio keep NA lower limits (negatives = improvement)
  expect_true(all(is.na(lower("diff", "intensity_cv_tqc", "intensity_cv_bqc"))))
  expect_true(all(is.na(lower("ratio", "intensity_cv_tqc", "intensity_cv_bqc"))))
})

# Branch 5: shared pretty-axis helper must render >=3 non-empty labels on both
# axes, linear and log.
test_that("plot_qcmetrics_comparison axes render >=3 non-empty labels", {
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

  p <- plot_qcmetrics_comparison(
    data = mexp,
    x_variable = "rt_median_bqc",
    y_variable = "norm_intensity_cv_bqc",
    plot_type = "scatter",
    facet_by_class = FALSE
  )
  expect_gte(length(axis_labels(p, "x")), 3)
  expect_gte(length(axis_labels(p, "y")), 3)

  p_log <- plot_qcmetrics_comparison(
    data = mexp,
    x_variable = "intensity_median_bqc",
    y_variable = "norm_intensity_median_bqc",
    plot_type = "scatter",
    log_scale = TRUE,
    facet_by_class = FALSE
  )
  expect_gte(length(axis_labels(p_log, "x")), 3)
  expect_gte(length(axis_labels(p_log, "y")), 3)
})
