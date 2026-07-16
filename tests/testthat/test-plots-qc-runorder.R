library(fs)
library(vdiffr)
library(ggplot2)
library(testthat)
set.seed(123)
testthat::local_edition(3)

mexp_orig <- lipidomics_dataset

mexp <- normalize_by_istd(mexp_orig)
mexp <- quantify_by_istd(mexp)
mexp <- calc_qc_metrics(mexp) # Ensure calc_qc_metrics is executed before

test_that("plot_runsequence works with basic parameters", {
  p <- plot_runsequence(mexp, show_batches = TRUE)
  expect_s3_class(p, "gg")
  plot_data <- ggplot2::ggplot_build(p)$data
  expect_equal(plot_data[[1]]$xintercept[1], 93.5) # check no date as x axis
  expect_equal(dim(plot_data[[2]]), c(499, 10))

  expect_doppelganger_cond("plot_runsequence default", p)

  plot_obj <- ggplot_build(p)
  lbls <- plot_obj$layout$panel_params[[1]]$x$get_labels()
  expect_equal(lbls, c("0", "100", "200", "300", "400"))

  p <- plot_runsequence(
    mexp,
    show_batches = TRUE,
    show_timestamp = TRUE
  )

  p <- plot_runsequence(data = mexp, show_timestamp = TRUE)
  expect_true(any(grepl("Acquisition Time", p$labels$x))) # Check x-axis label

  p <- plot_runsequence(data = mexp, show_batches = FALSE)
  plot_data <- ggplot2::ggplot_build(p)$data
  expect_equal(length(plot_data), 1) # additional layer for batches geoms

  p <- plot_runsequence(
    data = mexp,
    show_batches = TRUE,
    batch_zebra_stripe = FALSE
  )
  plot_data <- ggplot2::ggplot_build(p)$data
  expect_equal(length(plot_data), 2) # additional layer for batches geoms
  expect_equal(dim(plot_data[[1]]), c(6, 7)) # rows for each line

  p <- plot_runsequence(
    data = mexp,
    show_batches = TRUE,
    batch_zebra_stripe = TRUE
  )
  plot_data <- ggplot2::ggplot_build(p)$data
  expect_equal(length(plot_data), 2) # additional layer for batches geoms
  expect_equal(dim(plot_data[[1]]), c(3, 11)) # rows for each stripe

  p <- plot_runsequence(mexp, show_batches = TRUE, show_timestamp = TRUE)
  plot_data <- ggplot2::ggplot_build(p)$data
  ts <- as.POSIXct(
    plot_data[[1]]$xintercept[1],
    origin = "1970-01-01",
    tz = "Asia/Singapore"
  )
  expect_equal(format(ts, "%Y-%m-%d %H:%M:%S %Z"), "2017-10-20 22:15:36 +08") # check x axis uses data
})

test_that("plot_runsequence single row works", {
  p <- plot_runsequence(data = mexp, single_row = TRUE)
  expect_true(any(grepl("y", p$mapping))) # Check if y axis is not present
  expect_doppelganger_cond("plot_runsequence singlerow", p)
})

test_that("plot_runsequence single batch zebra", {
  p <- plot_runsequence(data = mexp, batch_zebra_stripe = TRUE)
  expect_doppelganger_cond("plot_runsequence zebra", p)
})

test_that("plot_runsequence single batch zebra timestamp", {
  p <- plot_runsequence(
    data = mexp,
    batch_zebra_stripe = TRUE,
    show_timestamp = TRUE
  )
  expect_doppelganger_cond("plot_runsequence zebratime", p)
})


test_that("plot_runsequence qc selection works", {
  p <- plot_runsequence(
    mexp,
    qc_types = c("SPL", "BQC", "RQC"),
    show_batches = TRUE
  )
  plot_data <- ggplot2::ggplot_build(p)$data
  expect_equal(dim(plot_data[[2]]), c(444, 10))

  p <- plot_runsequence(
    mexp,
    qc_types = c("SPL|BQC|RQC"),
    show_batches = TRUE
  )
  plot_data <- ggplot2::ggplot_build(p)$data
  expect_equal(dim(plot_data[[2]]), c(444, 10))
})

test_that("plot_runsequence timestamp works", {
  p <- plot_runsequence(mexp, show_batches = TRUE, show_timestamp = TRUE)
  plot_obj <- ggplot_build(p)
  lbls <- plot_obj$layout$panel_params[[1]]$x$get_labels()
  expect_equal(
    lbls,
    c(NA, "2017-10-21", "2017-10-22", "2017-10-23", "2017-10-24", NA)
  )
})


# RLA plot tests

test_that("plot_rla_boxplot no data works", {
  expect_error(
    p <- plot_rla_boxplot(
      MRMhubExperiment(),
      show_batches = TRUE,
      show_timestamp = TRUE
    ),
    "No data available. Please import data and metadata first",
    fixed = TRUE
  )
})

test_that("plot_rla_boxplot variable not available", {
  expect_error(
    p <- plot_rla_boxplot(
      mexp,
      rla_type_batch = "within",
      show_batches = TRUE,
      variable = "conc_raw"
    ),
    "Raw feature abundance data is only available after drift and/or batch correction",
    fixed = TRUE
  )
})

test_that("plot_rla_boxplot variable not available", {
  expect_error(
    p <- plot_rla_boxplot(
      mexp,
      rla_type_batch = "within",
      show_batches = TRUE
    ),
    "`variable` must be supplied",
    fixed = TRUE
  )
})

test_that("plot_rla_boxplot variable not available", {
  expect_error(
    p <- plot_rla_boxplot(
      mexp,
      show_batches = TRUE,
      show_plot = FALSE,
      variable = "conc_raw"
    ),
    "`rla_type_batch` must be supplied ('within', 'across')",
    fixed = TRUE
  )
})

test_that("plot_runsequence default works", {
  expect_message(
    p <- plot_rla_boxplot(
      mexp,
      rla_type_batch = "within",
      show_plot = FALSE,
      outlier_method = "mad",
      variable = "intensity",
      show_timestamp = FALSE,
      show_batches = TRUE
    ),
    "Found 15 outliers in the 499 shown analyses",
    fixed = TRUE
  )
  expect_doppelganger_cond("plot_rla_boxplot default", p$plot)
})

test_that("plot_runsequence outlier outlierfold", {
  expect_message(
    p <- plot_rla_boxplot(
      mexp,
      rla_type_batch = "within",
      show_plot = FALSE,
      outlier_method = "fold",
      variable = "intensity",
      show_timestamp = FALSE,
      outlier_k = 0.5,
      show_batches = TRUE
    ),
    "Found 4 outliers in the 499 shown analyses",
    fixed = TRUE
  )
  expect_doppelganger_cond("plot_rla_boxplot outlierfold", p$plot)
})

test_that("plot_runsequence default outlierfold 2", {
  expect_message(
    p <- plot_rla_boxplot(
      mexp,
      rla_type_batch = "within",
      show_plot = FALSE,
      outlier_method = "fold",
      variable = "intensity",
      show_timestamp = FALSE,
      outlier_k = c(-2.5, 0.1),
      show_batches = TRUE
    ),
    "Found 84 outliers in the 499 shown analyses",
    fixed = TRUE
  )
  expect_doppelganger_cond("plot_rla_boxplot outlierfold2", p$plot)
})

test_that("plot_runsequence outlier qctypes", {
  expect_message(
    p <- plot_rla_boxplot(
      mexp,
      rla_type_batch = "within",
      show_plot = FALSE,
      outlier_method = "fold",
      variable = "intensity",
      show_timestamp = FALSE,
      outlier_qctypes = c("LTR", "PBLK", "SPL"),
      outlier_k = c(-0.5, 0.2),
      show_batches = TRUE
    ),
    "Found 19 outliers in the 499 shown analyses",
    fixed = TRUE
  )
})

test_that("plot_runsequence outlierqctypes 3", {
  expect_error(
    p <- plot_rla_boxplot(
      mexp,
      rla_type_batch = "within",
      show_plot = FALSE,
      outlier_method = "fold",
      variable = "intensity",
      show_timestamp = FALSE,
      outlier_qctypes = c("LTR", "PBLK", "SPL"),
      outlier_k = c(-0.5, 0.2, 1),
      show_batches = TRUE
    ),
    "must be of length 1 or 2",
    fixed = TRUE
  )
})

test_that("plot_runsequence default no outlier", {
  expect_no_message(
    p <- plot_rla_boxplot(
      mexp,
      rla_type_batch = "within",
      show_plot = FALSE,
      variable = "intensity",
      show_timestamp = FALSE,
      show_batches = TRUE,
      outlier_detection = FALSE
    )
  )
  expect_doppelganger_cond("plot_rla_boxplot nooutlier", p$plot)
})

test_that("plot_runsequence default works2", {
  p <- plot_rla_boxplot(
    mexp,
    rla_type_batch = "within",
    show_plot = FALSE,
    variable = "intensity",
    show_timestamp = FALSE,
    show_batches = TRUE
  )
  expect_doppelganger_cond("plot_rla_boxplot default2", p$plot)
})


test_that("plot_runsequence timestamp works", {
  p <- plot_rla_boxplot(
    mexp,
    rla_type_batch = "within",
    show_plot = FALSE,
    variable = "intensity",
    show_timestamp = TRUE,
    show_batches = FALSE
  )
  expect_doppelganger_cond("plot_rla_boxplot with timestamp", p$plot)
})

test_that("plot_rla_boxplot within correct", {
  p <- plot_rla_boxplot(
    mexp,
    rla_type_batch = "within",
    show_plot = FALSE,
    variable = "intensity",
    show_batches = TRUE
  )
  expect_s3_class(p$plot, "gg")
  plot_data <- ggplot2::ggplot_build(p$plot)$data
  expect_equal(plot_data[[1]]$xintercept[1], 0.5) # check batches shown
  expect_equal(dim(plot_data[[2]]), c(499, 29)) # more columns for box plots
  expect_equal(mean(plot_data[[2]]$middle), -0.193117043184098)
})


test_that("plot_rla_boxplot across correct", {
  p <- plot_rla_boxplot(
    mexp,
    rla_type_batch = "across",
    show_plot = FALSE,
    variable = "intensity",
    show_batches = TRUE
  )

  plot_data <- ggplot2::ggplot_build(p$plot)$data
  expect_equal(mean(plot_data[[2]]$middle), -0.185713556)
  expect_equal(max(plot_data[[2]]$x), 499)
})

test_that("plot_rla_boxplot zebra works", {
  expect_no_error(
    p <- plot_rla_boxplot(
      mexp,
      rla_type_batch = "across",
      variable = "intensity",
      show_batches = TRUE,
      show_plot = FALSE,
      batch_zebra_stripe = TRUE,
      collapse_excluded = FALSE
    )
  )
  expect_doppelganger_cond("plot_rla_boxplot zebrawithgaps", p$plot)
  plot_data <- ggplot2::ggplot_build(p$plot)$data
  expect_equal(dim(plot_data[[1]]), c(3, 11)) # rows for each stripe
})

test_that("plot_rla_boxplot zebra removegaps works", {
  expect_no_error(
    p <- plot_rla_boxplot(
      mexp,
      rla_type_batch = "across",
      variable = "intensity",
      show_batches = TRUE,
      qc_types = c("SPL"),
      show_plot = FALSE,
      batch_zebra_stripe = TRUE,
      collapse_excluded = TRUE
    )
  )
  expect_doppelganger_cond("plot_rla_boxplot zebranogaps2", p$plot)
  plot_data <- ggplot2::ggplot_build(p$plot)$data
  expect_equal(dim(plot_data[[1]]), c(3, 11)) # rows for each stripe
})

test_that("plot_rla_boxplot zebra no batch ok", {
  expect_no_error(
    p <- plot_rla_boxplot(
      mexp,
      rla_type_batch = "across",
      variable = "intensity",
      show_batches = FALSE,
      show_plot = FALSE,
      batch_zebra_stripe = TRUE
    )
  )

  expect_doppelganger_cond("plot_rla_boxplot nobzebra", p$plot)
})

test_that("plot_rla_boxplot zebra gridlinesh ok", {
  expect_no_error(
    p <- plot_rla_boxplot(
      mexp,
      rla_type_batch = "across",
      variable = "intensity",
      show_batches = TRUE,
      show_plot = FALSE,
      show_timestamp = FALSE,
      x_gridlines = TRUE
    )
  )
  expect_doppelganger_cond("plot_rla_boxplot gridlines", p$plot)
})


test_that("plot_rla_boxplot ylim", {
  expect_no_error(
    p <- plot_rla_boxplot(
      mexp,
      rla_type_batch = "across",
      variable = "intensity",
      show_batches = TRUE,
      show_plot = FALSE,
      show_timestamp = FALSE,
      y_lim = c(-1, 1)
    )
  )
  expect_doppelganger_cond("plot_rla_boxplot ylim", p$plot)
})

test_that("plot_rla_boxplot ylim", {
  expect_no_error(
    p <- plot_rla_boxplot(
      mexp,
      rla_type_batch = "across",
      variable = "intensity",
      show_batches = TRUE,
      show_plot = FALSE,
      show_timestamp = FALSE,
      outlier_exclude = TRUE
    )
  )
  expect_doppelganger_cond("plot_rla_boxplot outlier_exlude", p$plot)
})


test_that("plot_rla_boxplot abslog", {
  expect_no_error(
    p <- plot_rla_boxplot(
      mexp,
      rla_type_batch = "across",
      variable = "intensity",
      show_batches = TRUE,
      show_plot = FALSE,
      show_timestamp = FALSE,
      relative_log_abundances = FALSE
    )
  )
  expect_doppelganger_cond("default plot_rla_boxplot abslog", p$plot)
})


test_that("plot_rla_boxplot lot range not changes data", {
  p <- plot_rla_boxplot(
    mexp,
    rla_type_batch = "across",
    variable = "intensity",
    show_plot = FALSE,
    plot_range = c(50, 100),
    rla_limit_to_range = FALSE,
    show_batches = TRUE
  )

  plot_data <- ggplot2::ggplot_build(p$plot)$data
  expect_equal(mean(plot_data[[2]]$middle), -0.185713556)
  expect_equal(min(plot_data[[2]]$x), 1)
  expect_equal(max(plot_data[[2]]$x), 499)
  expect_doppelganger_cond("plot_rla_boxplot rangefull", p$plot)
})


test_that("plot_rla_boxplot lot range rla_limit_to_range changes data", {
  p <- plot_rla_boxplot(
    mexp,
    rla_type_batch = "across",
    variable = "intensity",
    show_plot = FALSE,
    plot_range = c(50, 100),
    rla_limit_to_range = TRUE,
    show_batches = TRUE
  )

  plot_data <- ggplot2::ggplot_build(p$plot)$data
  expect_equal(mean(plot_data[[2]]$middle), -0.30282026)
  expect_equal(min(plot_data[[2]]$x), 1)
  expect_equal(max(plot_data[[2]]$x), 499)
  expect_doppelganger_cond("plot_rla_boxplot rangerla", p$plot)
})


test_that("plot_rla_boxplot abslog", {
  expect_no_error(
    p <- plot_rla_boxplot(
      mexp,
      rla_type_batch = "across",
      variable = "intensity",
      show_batches = TRUE,
      show_plot = FALSE,
      show_timestamp = FALSE,
      relative_log_abundances = FALSE
    )
  )
  expect_doppelganger_cond("plot_rla_boxplot abslog", p$plot)
})


test_that("plot_rla_boxplot qc subset range collapse_excluded ", {
  expect_no_error(
    p <- plot_rla_boxplot(
      mexp,
      rla_type_batch = "across",
      variable = "intensity",
      show_batches = TRUE,
      show_plot = FALSE,
      show_timestamp = FALSE,
      collapse_excluded = TRUE,
      qc_types = c("TQC", "BQC"),
      plot_range = c(50, 100),
      relative_log_abundances = FALSE
    )
  )
  expect_doppelganger_cond("plot_rla_boxplot qctype removegaps", p$plot)
})

test_that("plot_rla_boxplot qc subset range collapse_excluded ", {
  expect_no_error(
    p <- plot_rla_boxplot(
      mexp,
      rla_type_batch = "across",
      variable = "intensity",
      show_batches = TRUE,
      show_plot = FALSE,
      show_timestamp = FALSE,
      collapse_excluded = TRUE,
      batch_zebra_stripe = TRUE,
      qc_types = c("TQC", "BQC"),
      plot_range = c(50, 100),
      relative_log_abundances = FALSE
    )
  )
  expect_doppelganger_cond(
    "plot_rla_boxplot qctype removegapszebra",
    p$plot
  )
})

test_that("plot_rla_boxplot qc subset range with gaps ", {
  expect_no_error(
    p <- plot_rla_boxplot(
      mexp,
      rla_type_batch = "across",
      variable = "intensity",
      show_batches = TRUE,
      show_plot = FALSE,
      show_timestamp = FALSE,
      collapse_excluded = FALSE,
      qc_types = c("TQC", "BQC"),
      plot_range = c(50, 100),
      relative_log_abundances = FALSE
    )
  )
  expect_doppelganger_cond("plot_rla_boxplot qctype withgaps", p$plot)
})

test_that("plot_rla_boxplot qc subset range with gaps date ", {
  expect_no_error(
    p <- plot_rla_boxplot(
      mexp,
      rla_type_batch = "across",
      variable = "intensity",
      show_batches = TRUE,
      show_plot = FALSE,
      show_timestamp = TRUE,
      collapse_excluded = FALSE,
      qc_types = c("TQC", "BQC"),
      plot_range = c(50, 100),
      relative_log_abundances = FALSE
    )
  )
  expect_doppelganger_cond(
    "plot_rla_boxplot qctype withgaps date",
    p$plot
  )
})

# --- WS-P(A): RLA min_feature_intensity filter must be NA-safe and honor `variable` ---

test_that("plot_rla_boxplot keeps a feature with a single NA (median filter is NA-safe)", {
  # Regression: filter(median(feature_intensity) >= min_feature_intensity) had no
  # na.rm, so one NA collapsed the median to NA and silently dropped the whole
  # feature -- even at the default threshold of 0. Fails on the old code.
  p_base <- plot_rla_boxplot(
    mexp,
    rla_type_batch = "across",
    variable = "intensity",
    show_plot = FALSE,
    outlier_detection = FALSE
  )
  base_n <- dplyr::n_distinct(p_base$plot$data$feature_id)

  mexp_na <- mexp
  target <- unique(mexp_na@dataset$feature_id)[1]
  idx <- which(mexp_na@dataset$feature_id == target)
  mexp_na@dataset$feature_intensity[idx[1]] <- NA_real_

  p <- plot_rla_boxplot(
    mexp_na,
    rla_type_batch = "across",
    variable = "intensity",
    show_plot = FALSE,
    outlier_detection = FALSE
  )
  expect_true(target %in% p$plot$data$feature_id)
  expect_equal(dplyr::n_distinct(p$plot$data$feature_id), base_n)
})

test_that("plot_rla_boxplot min_feature_intensity thresholds on intensity, not the plotted variable", {
  # min_feature_intensity is a signal-quality floor on feature_intensity, applied
  # even when a different variable is plotted (here `conc`). Distinguishes the
  # intensity floor from a threshold on the plotted variable.
  p0 <- plot_rla_boxplot(
    mexp,
    rla_type_batch = "across",
    variable = "conc",
    show_plot = FALSE,
    min_feature_intensity = 0,
    outlier_detection = FALSE
  )
  full_n <- dplyr::n_distinct(p0$plot$data$feature_id)
  per_feature <- p0$plot$data |>
    dplyr::group_by(feature_id) |>
    dplyr::summarise(
      mi = median(feature_intensity, na.rm = TRUE),
      mc = median(feature_conc, na.rm = TRUE),
      .groups = "drop"
    )
  thr <- 1e6 # on the intensity scale (medians ~2e4..4e7); every conc median << thr
  intensity_based <- per_feature |>
    dplyr::filter(mi >= thr) |>
    dplyr::pull(feature_id)
  variable_based <- per_feature |>
    dplyr::filter(mc >= thr) |>
    dplyr::pull(feature_id)

  p1 <- plot_rla_boxplot(
    mexp,
    rla_type_batch = "across",
    variable = "conc",
    show_plot = FALSE,
    min_feature_intensity = thr,
    outlier_detection = FALSE
  )
  got <- unique(p1$plot$data$feature_id)
  # Kept set follows feature_intensity (a strict subset), not feature_conc.
  expect_setequal(got, intensity_based)
  expect_gt(length(got), 0)
  expect_lt(length(got), full_n)
  expect_false(setequal(got, variable_based))
})
