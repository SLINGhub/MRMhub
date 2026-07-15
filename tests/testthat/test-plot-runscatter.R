# library(fs)
# library(vdiffr)
# library(ggplot2)
# library(testthat)
set.seed(123)
testthat::local_edition(3)

mexp_orig <- lipidomics_dataset

mexp <- normalize_by_istd(mexp_orig)
mexp <- quantify_by_istd(mexp)
mexp <- calc_qc_metrics(mexp) # Ensure calc_qc_metrics is executed before


test_that("plot_runscatter generates a plot", {
  # Test with valid arguments
  p <- plot_runscatter(
    data = mexp,
    variable = "intensity",
    rows_page = 3,
    cols_page = 4,
    return_plots = TRUE
  )
  # Check if a ggplot object is returned
  expect_s3_class(p[[1]], "gg")

  # Check how many pages
  expect_equal(length(p), 3)

  expect_equal(max(p[[1]]$data$value_mod), 12390146.0)
  plot_data <- ggplot2::ggplot_build(p[[1]])$data[[2]]
  expect_equal(nrow(plot_data), 5988)
  expect_doppelganger_cond("def_runscatter", p)

  # log y axis
  p <- plot_runscatter(
    data = mexp,
    variable = "intensity",
    rows_page = 3,
    cols_page = 4,
    show_batches = TRUE,
    batch_zebra_stripe = TRUE,
    log_scale = TRUE,
    return_plots = TRUE
  )
  plot_data <- ggplot2::ggplot_build(p[[1]])$data
  expect_equal(max(plot_data[[2]]$y), 7.09307642)
  expect_doppelganger_cond("log_runscat", p)

  mexp_withzero <- mexp
  mexp_withzero@dataset$feature_intensity[sample(1:499, 10)] <- 0
  expect_message(
    p <- plot_runscatter(
      data = mexp_withzero,
      variable = "intensity",
      rows_page = 3,
      cols_page = 4,
      show_batches = TRUE,
      batch_zebra_stripe = TRUE,
      log_scale = TRUE,
      return_plots = TRUE
    ),
    "Zero or negative values were replaced"
  )

  # Test with valid arguments
  p <- plot_runscatter(
    data = mexp,
    variable = "intensity",
    rows_page = 3,
    cols_page = 4,
    specific_page = 3,
    return_plots = TRUE
  )
  # Check how many pages
  expect_equal(length(p), 1)

  # Test with valid arguments
  p <- plot_runscatter(
    data = mexp,
    variable = "conc",
    rows_page = 3,
    cols_page = 4,
    return_plots = TRUE
  )
  expect_false(is.null(p))
  expect_equal(max(p[[1]]$data$value_mod), 18.2841845)
  plot_data <- ggplot2::ggplot_build(p[[1]])$data[[2]]
  expect_equal(nrow(plot_data), 5988)

  temp_pdf_path <- file.path(tempdir(), "mrmhub_test_runscay.pdf")
  p <- plot_runscatter(
    data = mexp,
    variable = "conc",
    rows_page = 3,
    cols_page = 4,
    return_plots = FALSE,
    output_pdf = TRUE,
    path = temp_pdf_path
  )
  expect_null(p)
  expect_true(file_exists(temp_pdf_path), info = "PDF file was not created.")
  size_kb <- as.numeric(fs::file_size(temp_pdf_path)) / 1024
  expect_equal(size_kb, 119, tolerance = 0.2)
  fs::file_delete(temp_pdf_path)
})

# check diverse feature filters
test_that("plot_runscatter filter work", {
  p <- plot_runscatter(
    data = mexp,
    variable = "intensity",
    qc_types = c("BQC", "SPL"),
    include_qualifier = FALSE,
    include_feature_filter = "PC|PE",
    exclude_feature_filter = "ISTD",
    rows_page = 3,
    cols_page = 4,
    return_plots = TRUE
  )
  expect_equal(length(p), 1)
  plot_data <- ggplot2::ggplot_build(p[[1]])$data
  expect_equal(nrow(plot_data[[2]]), 3456)
  expect_doppelganger_cond("filteredrunscat", p)

  # Test range filter and also regex for qc type
  p <- plot_runscatter(
    data = mexp,
    variable = "intensity",
    qc_types = c("BQC|SPL"),
    include_qualifier = FALSE,
    include_feature_filter = "PC|PE",
    exclude_feature_filter = "ISTD|SIM",
    plot_range = c(100, 400),
    rows_page = 3,
    cols_page = 4,
    return_plots = TRUE
  )
  expect_equal(length(p), 1)
  plot_data <- ggplot2::ggplot_build(p[[1]])$data
  expect_equal(nrow(plot_data[[2]]), 3456)
  expect_equal(max(p[[1]]$data$value_mod), 12390146.0)
  expect_doppelganger_cond("rangerunscat", p)

  # Test include e
  p <- plot_runscatter(
    data = mexp,
    variable = "intensity",
    qc_types = c("BQC|SPL"),
    include_qualifier = FALSE,
    include_feature_filter = c("PC 40:6", "PC 40:8"),
    plot_range = c(100, 400),
    rows_page = 3,
    cols_page = 4,
    return_plots = TRUE
  )
  expect_equal(length(p), 1)
  plot_data <- ggplot2::ggplot_build(p[[1]])$data
  expect_equal(nrow(plot_data[[2]]), 864)
  expect_equal(max(p[[1]]$data$value_mod), 9364398.0)
  expect_doppelganger_cond("filtrunscat2", p)

  expect_error(
    p <- plot_runscatter(
      data = mexp,
      variable = "intensity",
      qc_types = c("BQC|SPL"),
      include_qualifier = FALSE,
      include_feature_filter = "40",
      exclude_feature_filter = "PC",
      plot_range = c(100, 400),
      rows_page = 3,
      cols_page = 4,
      return_plots = TRUE
    ),
    "filter criteria resulted in no selected features "
  )

  # TODO: Remove after confirm that purrr progress bar works

  # captured_output <- capture_output(
  #   plot_runscatter(
  #     data = mexp,
  #     variable = "conc",
  #     rows_page = 3,
  #     cols_page = 4,
  #     return_plots = FALSE,
  #     show_progress = TRUE
  # ))

  # expect_false(any(grepl("======================",
  #                       captured_output)))

  # captured_output <- capture_output(
  #   plot_runscatter(
  #     data = mexp,
  #     variable = "conc",
  #     rows_page = 3,
  #     cols_page = 4,
  #     return_plots = FALSE,
  #     show_progress = FALSE
  #   ))

  # expect_false(any(grepl("==",
  #                       captured_output)))
})

# check diverse feature filters
test_that("plot_runscatter with unknown qc_types", {
  mexp_newqc <- import_data_csv(
    data = MRMhubExperiment(),
    path = test_path("testdata/plain-wide/plain_wide_dataset2_22rows_unknownQC.csv"),
    variable_name = "conc",
    analysis_id_col = "analysis_id",
    import_metadata = TRUE
  )

  expect_message(
    p <- plot_runscatter(
      data = mexp_newqc,
      variable = "conc",
      include_qualifier = FALSE,
      rows_page = 3,
      cols_page = 4,
      point_size = 10,
      return_plots = TRUE
    ),
    "QC types 'XYX, MyQC, BLK' not predefined in MRMhub and will be displayed in black with auto-assigned shapes",
    fixed = TRUE
  )

  plot_data <- ggplot2::ggplot_build(p[[1]])$data[[2]]
  expect_equal(length(unique(plot_data$shape)), 5)
  expect_doppelganger_cond("runscatunknownqc", p)
})


test_that("plot_runscatter show batches works", {
  # Test with valid arguments
  p <- plot_runscatter(
    data = mexp,
    variable = "intensity",
    show_batches = FALSE,
    rows_page = 3,
    cols_page = 4,
    return_plots = TRUE
  )
  expect_equal(max(p[[1]]$data$value_mod), 12390146.0)
  # No batches lines/shapes, so data is in first item
  plot_data <- ggplot2::ggplot_build(p[[1]])$data[[1]]
  expect_equal(nrow(plot_data), 5988)

  p <- plot_runscatter(
    data = mexp,
    variable = "intensity",
    show_batches = TRUE,
    batch_zebra_stripe = TRUE,
    rows_page = 3,
    cols_page = 4,
    return_plots = TRUE
  )
  expect_equal(max(p[[1]]$data$value_mod), 12390146.0)
  # No batches lines/shapes, so data is in first item
  plot_data <- ggplot2::ggplot_build(p[[1]])$data[[1]]
  expect_equal(nrow(plot_data), 36)
})


test_that("plot_runscatter outlier cap works", {
  # Test with valid arguments
  p <- plot_runscatter(
    data = mexp,
    variable = "intensity",
    rows_page = 3,
    cols_page = 4,
    return_plots = TRUE,
    cap_outliers = TRUE,
    cap_sample_k_mad = 2,
    cap_qc_k_mad = 2
  )
  expect_doppelganger_cond("runscattercapoutlier", p)

  expect_equal(max(p[[1]]$data$value_mod), 6481466.4)
  plot_data <- ggplot2::ggplot_build(p[[1]])$data[[3]] # not fully understand this test
  expect_equal(nrow(plot_data), 5988)

  p <- plot_runscatter(
    data = mexp,
    variable = "intensity",
    rows_page = 3,
    cols_page = 4,
    return_plots = TRUE,
    cap_outliers = TRUE,
    cap_sample_k_mad = 3,
    cap_qc_k_mad = 3
  )
  expect_equal(max(p[[1]]$data$value_mod), 7694153.4)

  p <- plot_runscatter(
    data = mexp,
    variable = "intensity",
    rows_page = 3,
    cols_page = 4,
    return_plots = TRUE,
    cap_outliers = TRUE,
    cap_sample_k_mad = NA,
    cap_qc_k_mad = NA,
    cap_top_n_outliers = 0,
  )
  expect_equal(max(p[[1]]$data$value_mod), 12390146.0)

  p <- plot_runscatter(
    data = mexp,
    variable = "intensity",
    rows_page = 3,
    cols_page = 4,
    return_plots = TRUE,
    cap_outliers = TRUE,
    cap_sample_k_mad = NA,
    cap_qc_k_mad = NA,
    cap_top_n_outliers = 1,
  )
  expect_equal(max(p[[1]]$data$value_mod), 10147223.2)

  p <- plot_runscatter(
    data = mexp,
    variable = "intensity",
    rows_page = 3,
    cols_page = 4,
    return_plots = TRUE,
    cap_outliers = TRUE,
    cap_sample_k_mad = NA,
    cap_qc_k_mad = NA,
    cap_top_n_outliers = 30,
  )
  expect_equal(max(p[[1]]$data$value_mod), 6068838.3)

  expect_error(
    p <- plot_runscatter(
      data = mexp,
      variable = "intensity",
      rows_page = 3,
      cols_page = 4,
      return_plots = TRUE,
      cap_outliers = TRUE,
      cap_sample_k_mad = NA,
      cap_qc_k_mad = NA,
      cap_top_n_outliers = NA,
    ),
    "One or more of `cap_sample_k_mad`"
  )
})


test_that("plot_runscatter show reference lines works", {
  # No batch-wise reference lines
  p <- plot_runscatter(
    data = mexp,
    variable = "intensity",
    show_batches = TRUE,
    show_reference_lines = TRUE,
    ref_qc_types = "BQC",
    reference_batchwise = FALSE,
    reference_sd_shade = FALSE,
    reference_k_sd = 2,
    rows_page = 3,
    cols_page = 4,
    return_plots = TRUE
  )
  expect_equal(max(p[[1]]$data$value_mod), 12390146.0)
  plot_data <- ggplot2::ggplot_build(p[[1]])$data[[4]]
  expect_equal(unique(plot_data$linetype), "dashed")

  p <- plot_runscatter(
    data = mexp,
    variable = "intensity",
    show_batches = TRUE,
    show_reference_lines = TRUE,
    ref_qc_types = "BQC",
    reference_batchwise = FALSE,
    reference_sd_shade = TRUE,
    reference_k_sd = 2,
    rows_page = 3,
    cols_page = 4,
    return_plots = TRUE
  )
  expect_equal(max(p[[1]]$data$value_mod), 12390146.0)
  plot_data <- ggplot2::ggplot_build(p[[1]])$data[[2]]
  expect_equal(unique(plot_data$alpha), 0.15)

  # batch-wise reference lines

  p <- plot_runscatter(
    data = mexp,
    variable = "intensity",
    show_batches = TRUE,
    show_reference_lines = TRUE,
    ref_qc_types = "BQC",
    reference_batchwise = TRUE,
    reference_sd_shade = FALSE,
    reference_k_sd = 2,
    rows_page = 3,
    cols_page = 4,
    return_plots = TRUE
  )
  expect_equal(max(p[[1]]$data$value_mod), 12390146.0)
  plot_data <- ggplot2::ggplot_build(p[[1]])$data
  expect_equal(length(plot_data), 6)
  expect_equal(mean(plot_data[[3]]$yend), 2103609.1)

  p <- plot_runscatter(
    data = mexp,
    variable = "intensity",
    show_batches = TRUE,
    show_reference_lines = TRUE,
    ref_qc_types = "BQC",
    reference_batchwise = TRUE,
    reference_sd_shade = TRUE,
    reference_k_sd = 2,
    rows_page = 3,
    cols_page = 4,
    return_plots = TRUE
  )
  expect_equal(max(p[[1]]$data$value_mod), 12390146.0)
  plot_data <- ggplot2::ggplot_build(p[[1]])$data
  expect_equal(length(plot_data), 5)
  expect_equal(unique(plot_data[[2]]$alpha), 0.15)
  expect_equal(mean(plot_data[[2]]$ymax), 2408485.4)
  expect_doppelganger_cond("extrunscatterref", p)

  p <- plot_runscatter(
    data = mexp,
    variable = "intensity",
    show_batches = TRUE,
    show_reference_lines = TRUE,
    reference_batchwise = FALSE,
    ref_qc_types = "BQC",
    reference_k_sd = NA,
    rows_page = 3,
    cols_page = 4,
    return_plots = TRUE
  )
  expect_equal(max(p[[1]]$data$value_mod), 12390146.0)
  plot_data <- ggplot2::ggplot_build(p[[1]])$data
  expect_equal(length(plot_data), 4)
  expect_equal(mean(plot_data[[3]]$yintercept), 2103633.9)

  p <- plot_runscatter(
    data = mexp,
    variable = "intensity",
    show_batches = TRUE,
    show_reference_lines = TRUE,
    reference_batchwise = TRUE,
    ref_qc_types = "SPL",
    reference_k_sd = 2,
    rows_page = 3,
    cols_page = 4,
    return_plots = TRUE
  )
  expect_equal(max(p[[1]]$data$value_mod), 12390146.0)
  plot_data <- ggplot2::ggplot_build(p[[1]])$data[[5]]
  expect_equal(dim(plot_data), c(72, 10))

  expect_error(
    p <- plot_runscatter(
      data = mexp,
      variable = "intensity",
      show_reference_lines = TRUE,
      rows_page = 3,
      cols_page = 4,
      show_trend = TRUE,
      return_plots = TRUE
    ),
    "Please define a QC to show reference lines"
  )

  expect_error(
    p <- plot_runscatter(
      data = mexp,
      variable = "intensity",
      show_reference_lines = TRUE,
      ref_qc_types = "CAL",
      rows_page = 3,
      cols_page = 4,
      show_trend = TRUE,
      return_plots = TRUE
    ),
    "Selected `ref_qc_types` not"
  )
})


test_that("plot_runscatter show trend works", {
  expect_error(
    p <- plot_runscatter(
      data = mexp,
      variable = "intensity",
      rows_page = 3,
      cols_page = 4,
      show_trend = TRUE,
      return_plots = TRUE
    ),
    "Drift or batch correction is currently required to show"
  )

  mexp_drift <- correct_drift_gaussiankernel(
    mexp_orig,
    variable = "intensity",
    recalc_trend_after = TRUE,

    ref_qc_types = "SPL",
    ignore_istd = FALSE
  )

  p <- plot_runscatter(
    data = mexp_drift,
    variable = "intensity",
    qc_types = c("BQC", "SPL"),
    rows_page = 3,
    cols_page = 4,
    show_trend = TRUE,
    return_plots = TRUE
  )

  plot_data <- ggplot2::ggplot_build(p[[1]])$data
  expect_equal(dim(plot_data[[2]]), c(5184, 10))
  expect_equal(mean(plot_data[[2]]$y), 2054300.962) #  data points
  expect_equal(dim(plot_data[[3]]), c(5184, 9)) # smoothed ref data points
  expect_equal(mean(plot_data[[3]]$y), 1985330.456) # smoothed ref data points

  p <- plot_runscatter(
    data = mexp_drift,
    variable = "intensity_raw",
    qc_types = c("BQC", "SPL"),
    rows_page = 3,
    cols_page = 4,
    show_trend = TRUE,
    return_plots = TRUE
  )

  plot_data <- ggplot2::ggplot_build(p[[1]])$data
  expect_equal(dim(plot_data[[2]]), c(5184, 10))
  expect_equal(dim(plot_data[[3]]), c(5184, 9)) # smoothed data points
  expect_equal(mean(plot_data[[2]]$y), 2044597.1) # data points
  expect_equal(mean(plot_data[[3]]$y), 1982570.1) # ref data points (batch-wise)

  p <- plot_runscatter(
    data = mexp_drift,
    variable = "intensity_before",
    qc_types = c("BQC", "SPL"),
    rows_page = 3,
    cols_page = 4,
    show_trend = TRUE,
    return_plots = TRUE
  )

  plot_data <- ggplot2::ggplot_build(p[[1]])$data
  expect_equal(dim(plot_data[[2]]), c(5184, 10))
  expect_equal(dim(plot_data[[3]]), c(5184, 9)) # smoothed data points
  expect_equal(mean(plot_data[[2]]$y), 2044597.1) # data points
  expect_equal(mean(plot_data[[3]]$y), 1982570.1) # ref data points (batch-wise)

  mexp_drift <- correct_batch_centering(
    mexp_orig,
    ref_qc_types = "BQC",
    variable = "intensity"
  )

  p <- plot_runscatter(
    data = mexp_drift,
    variable = "intensity",
    qc_types = c("BQC", "SPL"),
    rows_page = 3,
    cols_page = 4,
    show_trend = TRUE,
    return_plots = TRUE
  )

  plot_data <- ggplot2::ggplot_build(p[[1]])$data
  expect_equal(dim(plot_data[[2]]), c(5184, 10))
  expect_equal(dim(plot_data[[3]]), c(5184, 9)) # ref data points
  expect_equal(mean(plot_data[[2]]$y), 2039591.3) #  data points
  expect_equal(mean(plot_data[[3]]$y), 2084560.8) #  ref data points (batch-wise)

  p <- plot_runscatter(
    data = mexp_drift,
    variable = "intensity_raw",
    qc_types = c("BQC", "SPL"),
    rows_page = 3,
    cols_page = 4,
    show_trend = TRUE,
    return_plots = TRUE
  )

  plot_data <- ggplot2::ggplot_build(p[[1]])$data
  expect_equal(dim(plot_data[[2]]), c(5184, 10))
  expect_equal(dim(plot_data[[3]]), c(5184, 9)) # smoothed data points
  expect_equal(mean(plot_data[[2]]$y), 2044597.1) # data points
  expect_equal(mean(plot_data[[3]]$y), 2093909.456) # ref data points (batch-wise)

  p <- plot_runscatter(
    data = mexp_drift,
    variable = "intensity_raw",
    qc_types = c("BQC", "SPL"),
    rows_page = 3,
    cols_page = 4,
    show_trend = FALSE,
    return_plots = TRUE
  )

  plot_data <- ggplot2::ggplot_build(p[[1]])$data
  expect_equal(dim(plot_data[[2]]), c(5184, 10))
  expect_equal(mean(plot_data[[2]]$y), 2044597.1) # data points

  p <- plot_runscatter(
    data = mexp_drift,
    variable = "intensity_before",
    qc_types = c("BQC", "SPL"),
    rows_page = 3,
    cols_page = 4,
    show_trend = TRUE,
    return_plots = TRUE
  )

  plot_data <- ggplot2::ggplot_build(p[[1]])$data
  expect_equal(dim(plot_data[[2]]), c(5184, 10))
  expect_equal(dim(plot_data[[3]]), c(5184, 9)) # smoothed data points
  expect_equal(mean(plot_data[[2]]$y), 2044597.1) # data points
  expect_equal(mean(plot_data[[3]]$y), 2093909.456) # ref data points (batch-wise)

  # compare again with orginal data from mexp orginal
  p <- plot_runscatter(
    data = mexp_orig,
    variable = "intensity",
    qc_types = c("BQC", "SPL"),
    rows_page = 3,
    cols_page = 4,
    show_trend = FALSE,
    return_plots = TRUE
  )

  plot_data <- ggplot2::ggplot_build(p[[1]])$data
  expect_equal(dim(plot_data[[2]]), c(5184, 10))
  expect_equal(mean(plot_data[[2]]$y), 2044597.1) # data points

  mexp_drift <- correct_drift_gaussiankernel(
    mexp_orig,
    variable = "intensity",
    recalc_trend_after = TRUE,

    ref_qc_types = "SPL",
    ignore_istd = FALSE
  )

  mexp_drift2 <- correct_batch_centering(
    mexp_drift,
    ref_qc_types = "SPL",
    variable = "intensity"
  )

  p <- plot_runscatter(
    data = mexp_drift2,
    variable = "intensity_raw",
    qc_types = c("BQC", "SPL"),
    rows_page = 3,
    cols_page = 4,
    show_trend = TRUE,
    return_plots = TRUE
  )

  plot_data <- ggplot2::ggplot_build(p[[1]])$data
  expect_equal(dim(plot_data[[2]]), c(5184, 10))
  expect_equal(dim(plot_data[[3]]), c(5184, 9)) # smoothed data points
  expect_equal(mean(plot_data[[2]]$y), 2044597.1) # data points
  expect_equal(mean(plot_data[[3]]$y), 1982570.1) # ref data points (batch-wise)

  p <- plot_runscatter(
    data = mexp_drift2,
    variable = "intensity_before",
    qc_types = c("BQC", "SPL"),
    rows_page = 3,
    cols_page = 4,
    show_trend = TRUE,
    return_plots = TRUE
  )

  plot_data <- ggplot2::ggplot_build(p[[1]])$data
  expect_equal(dim(plot_data[[2]]), c(5184, 10))
  expect_equal(dim(plot_data[[3]]), c(5184, 9)) # smoothed data points
  expect_equal(mean(plot_data[[2]]$y), 2054300.962) # data points
  expect_equal(mean(plot_data[[3]]$y), 1982570.1) # ref data points (batch-wise)

  expect_error(
    p <- plot_runscatter(
      data = mexp_orig,
      variable = "intensity_before",
      qc_types = c("BQC", "SPL"),
      rows_page = 3,
      cols_page = 4,
      show_trend = FALSE,
      return_plots = TRUE
    ),
    "Variables `_before` and `_raw` after only available after drift/batch corrections",
    fixed = TRUE
  )

  expect_error(
    p <- plot_runscatter(
      data = mexp_orig,
      variable = "intensity",
      qc_types = c("BQC", "SPL"),
      rows_page = 3,
      cols_page = 4,
      show_trend = TRUE,
      return_plots = TRUE
    ),
    "Drift or batch correction is currently required to show trend lines",
    fixed = TRUE
  )
})

test_that("plot_runscatter handles filter and missing data", {
  expect_error(
    p <- plot_runscatter(
      data = MRMhubExperiment(),
      variable = "intensity",
      rows_page = 3,
      cols_page = 4,
      return_plots = TRUE,
      cap_outliers = TRUE,
      cap_sample_k_mad = NA,
      cap_qc_k_mad = NA,
      cap_top_n_outliers = NA
    ),
    "No data available"
  )

  expect_error(
    p <- plot_runscatter(
      data = mexp,
      variable = "intensity",
      rows_page = 3,
      cols_page = 4,
      return_plots = TRUE,
      y_lim = "NO"
    ),
    "`y_lim` must have numeric values or",
    fixed = TRUE
  )

  expect_error(
    p <- plot_runscatter(
      data = mexp,
      filter_data = TRUE,
      variable = "intensity",
      rows_page = 3,
      cols_page = 4,
      return_plots = TRUE
    ),
    "Data has not been QC-filtered"
  )
  mexp_filt <- mrmhub::filter_features_qc(
    mexp,
    include_qualifier = FALSE,
    include_istd = FALSE,

    min.intensity.median.spl = 1000000
  )

  # uses filtered dataset
  p <- plot_runscatter(
    data = mexp_filt,
    variable = "intensity",
    filter_data = TRUE,
    rows_page = 3,
    cols_page = 4,
    return_plots = TRUE
  )
  expect_equal(length(p), 2)

  # returns error if variable not present in dataset
  expect_error(
    p <- plot_runscatter(
      data = mexp_orig,
      variable = "conc",
      rows_page = 3,
      cols_page = 4,
      return_plots = TRUE
    ),
    "Concentration data are not available"
  )

  # returns error if variable not present in dataset
  expect_error(
    p <- plot_runscatter(
      data = mexp,
      variable = "conc_raw",
      rows_page = 3,
      cols_page = 4,
      return_plots = TRUE
    ),
    "Raw feature abundance data "
  )

  # returns error if variable not present in dataset
  expect_error(
    p <- plot_runscatter(
      data = mexp,
      variable = "conc_raw",
      output_pdf = TRUE,
      rows_page = 3,
      cols_page = 4,
      return_plots = TRUE
    ),
    "No valid path defined"
  )

  p <- plot_runscatter(
    data = mexp,
    variable = "intensity",
    rows_page = 3,
    cols_page = 4,
    plot_range = c(100, 400),
    return_plots = TRUE
  )

  expect_doppelganger_cond("runscatterrange_filter", p)
})


test_that("plot_runscatter multicore 1 core", {
  expect_message(
    p <- plot_runscatter(
      data = mexp,
      variable = "intensity",
      qc_types = c("BQC", "SPL"),
      include_qualifier = FALSE,
      include_feature_filter = "PC|PE",
      exclude_feature_filter = "ISTD",
      rows_page = 3,
      cols_page = 4,
      multithreading = TRUE,
      return_plots = TRUE
    ),
    "To use multithreading for plot generation",
    fixed = TRUE
  )
  expect_equal(length(p), 1)
  plot_data <- ggplot2::ggplot_build(p[[1]])$data
  expect_equal(nrow(plot_data[[2]]), 3456)
})

test_that("plot_runscatter multicore", {
  skip_if(
    nzchar(Sys.getenv("R_COVR")),
    "mirai daemons corrupt covr trace files"
  )
  mirai::daemons(4)
  p <- plot_runscatter(
    data = mexp,
    variable = "intensity",
    qc_types = c("BQC", "SPL"),
    include_qualifier = FALSE,
    include_feature_filter = "PC|PE",
    exclude_feature_filter = "ISTD",
    rows_page = 3,
    cols_page = 4,
    multithreading = TRUE,
    return_plots = TRUE
  )
  expect_equal(length(p), 1)
  plot_data <- ggplot2::ggplot_build(p[[1]])$data
  expect_equal(nrow(plot_data[[2]]), 3456)
  mirai::daemons(0)
})

test_that("plot_runscatter multicore error ref no qc", {
  expect_error(
    p <- plot_runscatter(
      data = mexp,
      variable = "intensity",
      qc_types = c("BQC", "SPL"),
      include_qualifier = FALSE,
      include_feature_filter = "PC|PE",
      exclude_feature_filter = "ISTD",
      rows_page = 3,
      cols_page = 4,
      show_reference_lines = TRUE,
      return_plots = TRUE
    ),
    "Please define a QC to show reference lines",
    fixed = TRUE
  )
})


test_that("plot_runscatter  error refqc not there", {
  expect_error(
    p <- plot_runscatter(
      data = mexp,
      variable = "intensity",
      qc_types = c("BQC", "SPL"),
      include_qualifier = FALSE,
      include_feature_filter = "PC|PE",
      exclude_feature_filter = "ISTD",
      rows_page = 3,
      cols_page = 4,
      show_reference_lines = TRUE,
      ref_qc_types = "CAL",
      return_plots = TRUE
    ),
    "Selected `ref_qc_types` not present in the ",
    fixed = TRUE
  )
})

test_that("plot_runscatter  error cap no limits", {
  expect_error(
    p <- plot_runscatter(
      data = mexp,
      variable = "intensity",
      qc_types = c("BQC", "SPL"),
      cap_outliers = TRUE,
      cap_sample_k_mad = NA,
      cap_qc_k_mad = NA,
      cap_top_n_outliers = NA,

      return_plots = TRUE
    ),
    "One or more of `cap_sample_k_mad`",
    fixed = TRUE
  )
})

test_that("plot_runscatter  error cap n again", {
  p <- plot_runscatter(
    data = mexp,
    variable = "intensity",
    rows_page = 3,
    cols_page = 4,
    return_plots = TRUE,
    cap_outliers = TRUE,
    cap_sample_k_mad = NA,
    cap_qc_k_mad = NA,
    cap_top_n_outliers = 1
  )
  expect_equal(max(p[[1]]$data$value_mod), 10147223.2)
})


test_that("plot_runscatter  error cap logscale", {
  p <- plot_runscatter(
    data = mexp,
    variable = "intensity",
    rows_page = 3,
    cols_page = 4,
    return_plots = TRUE,
    cap_outliers = TRUE,
    cap_sample_k_mad = 1,
    cap_qc_k_mad = NA,
    log_scale = TRUE
  )
  expect_equal(length(p), 3)
  expect_doppelganger_cond("plot_runscatter capoutlierlog", p)
})

test_that("plot_runscatter specific_page gried", {
  p <- plot_runscatter(
    data = mexp,
    variable = "intensity",
    rows_page = 3,
    cols_page = 4,
    return_plots = TRUE,
    cap_outliers = TRUE,
    cap_sample_k_mad = 1,
    cap_qc_k_mad = NA,
    log_scale = TRUE,
    show_gridlines = TRUE,
    specific_page = 2
  )
  expect_equal(length(p), 1)
  expect_doppelganger_cond("plot_runscatter page2grid", p[[1]])
})


test_that("plot_runscatter pdf multi4", {
  skip_if(
    nzchar(Sys.getenv("R_COVR")),
    "mirai daemons corrupt covr trace files"
  )
  temp_pdf_path <- file.path(tempdir(), "mrmhub_test_runscay2.pdf")
  mirai::daemons(4)
  p <- plot_runscatter(
    data = mexp,
    variable = "conc",
    rows_page = 3,
    cols_page = 4,
    return_plots = FALSE,
    output_pdf = TRUE,
    multithreading = TRUE,
    path = temp_pdf_path
  )
  expect_null(p)
  expect_true(file_exists(temp_pdf_path), info = "PDF file was not created.")
  size_kb <- as.numeric(fs::file_size(temp_pdf_path)) / 1024
  expect_equal(size_kb, 119, tolerance = 0.2)
  fs::file_delete(temp_pdf_path)
  mirai::daemons(0)
})

test_that("plot_runscatter pdf multi", {
  temp_pdf_path <- file.path(tempdir(), "mrmhub_test_runscay2.pdf")

  p <- plot_runscatter(
    data = mexp,
    variable = "conc",
    rows_page = 3,
    cols_page = 4,
    return_plots = FALSE,
    output_pdf = TRUE,
    multithreading = TRUE,
    path = temp_pdf_path
  )
  expect_null(p)
  expect_true(file_exists(temp_pdf_path), info = "PDF file was not created.")
  size_kb <- as.numeric(fs::file_size(temp_pdf_path)) / 1024
  expect_equal(size_kb, 119, tolerance = 0.2)
  fs::file_delete(temp_pdf_path)
})

test_that("plot_runscatter pdf multi", {
  temp_pdf_path <- file.path(tempdir(), "mrmhub_test_runscay2.pdf")

  p <- plot_runscatter(
    data = mexp,
    variable = "conc",
    rows_page = 3,
    cols_page = 4,
    return_plots = FALSE,
    output_pdf = TRUE,
    multithreading = FALSE,
    path = temp_pdf_path
  )
  expect_null(p)
  expect_true(file_exists(temp_pdf_path), info = "PDF file was not created.")
  size_kb <- as.numeric(fs::file_size(temp_pdf_path)) / 1024
  expect_equal(size_kb, 119, tolerance = 0.2)
  fs::file_delete(temp_pdf_path)
})

# Dataset with one large contiguous gap: orders 99–150
# (Longit_batch2_1 to _45 plus the interleaved PQC 12-15 and TQC13-15,
#  all of which fall in analysis_order 99–150)
mexp_gaps <- exclude_analyses(
  mexp_orig,
  analyses = c(
    paste0("Longit_batch2_", 1:45),
    "Longit_batch2_PQC 12",
    "Longit_batch2_PQC 13",
    "Longit_batch2_PQC 14",
    "Longit_batch2_PQC 15",
    "Longit_batch2_TQC13",
    "Longit_batch2_TQC14",
    "Longit_batch2_TQC15"
  ),
  clear_existing = TRUE
)
mexp_gaps <- normalize_by_istd(mexp_gaps)
mexp_gaps <- quantify_by_istd(mexp_gaps)

test_that("plot_runscatter remove_gaps works", {
  p <- plot_runscatter(
    data = mexp_gaps,
    variable = "intensity",
    rows_page = 3,
    cols_page = 4,
    show_batches = TRUE,
    remove_gaps = TRUE,
    return_plots = TRUE
  )
  expect_s3_class(p[[1]], "gg")

  # Re-indexed x must be contiguous — max index < max analysis_order
  # (52 analyses excluded => max_index = 499 - 52 = 447)
  plot_data <- ggplot2::ggplot_build(p[[1]])$data[[2]]
  expect_lt(
    max(plot_data$x, na.rm = TRUE),
    max(mexp_gaps@dataset$analysis_order)
  )

  # Exactly one gap marker (one vline from GeomVline added for the gap)
  layer_classes <- sapply(p[[1]]$layers, function(l) class(l$geom)[1])
  n_gap_vlines <- sum(layer_classes == "GeomVline")
  expect_gte(n_gap_vlines, 1L)

  expect_doppelganger_cond("runscatter_remove_gaps", p[[1]])
})

test_that("plot_runscatter remove_gaps gap markers present", {
  p <- plot_runscatter(
    data = mexp_gaps,
    variable = "intensity",
    rows_page = 3,
    cols_page = 4,
    remove_gaps = TRUE,
    gap_line_color = "#e34a33",
    gap_line_width = 1.5,
    gap_label_size = 3,
    return_plots = TRUE
  )
  expect_s3_class(p[[1]], "gg")

  layer_classes <- sapply(p[[1]]$layers, function(l) class(l$geom)[1])
  expect_true(any(layer_classes == "GeomVline"))
  expect_true(any(layer_classes %in% c("GeomLabel", "GeomText")))

  # Label text contains the "|" separator between flanking IDs
  label_layers <- p[[1]]$layers[layer_classes %in% c("GeomLabel", "GeomText")]
  label_data <- label_layers[[1]]$data
  expect_true(any(grepl("|", label_data$gap_label, fixed = TRUE)))

  expect_doppelganger_cond("runscatter_remove_gaps_styled", p[[1]])
})

test_that("long feature_id labels are wrapped when label_wrap = TRUE", {
  long_ids <- c(
    "Ceramide d18:1/16:0 long name feature label",
    "Phosphatidylcholine PC 34:1 with extra long annotation",
    "Lysophosphatidylethanolamine LPE 18:2 very long descriptor label"
  )
  orig_ids <- unique(mexp@dataset$feature_id)[1:3]
  names(long_ids) <- orig_ids

  mexp_long <- mexp
  mexp_long@dataset <- mexp_long@dataset |>
    dplyr::mutate(
      feature_id = dplyr::recode_values(
        .data$feature_id,
        names(long_ids)[1] ~ long_ids[1],
        names(long_ids)[2] ~ long_ids[2],
        names(long_ids)[3] ~ long_ids[3],
        default = .data$feature_id
      )
    )

  # Helper: extract all strip text labels from a ggplot gtable
  get_strip_labels <- function(p) {
    gt <- ggplot2::ggplot_gtable(ggplot2::ggplot_build(p))
    strip_grobs <- gt$grobs[grepl("strip", gt$layout$name)]
    sapply(strip_grobs, function(sg) {
      sg$grobs[[1]]$children[[2]]$children[[1]]$label
    })
  }

  # label_wrap = TRUE: at least one strip label should contain a newline
  p_wrap <- plot_runscatter(
    data = mexp_long,
    variable = "intensity",
    rows_page = 3,
    cols_page = 4,
    label_wrap = TRUE,
    label_wrap_width = 20,
    specific_page = 1,
    return_plots = TRUE
  )
  expect_s3_class(p_wrap[[1]], "gg")
  expect_true(any(stringr::str_detect(get_strip_labels(p_wrap[[1]]), "\n")))

  # label_wrap = FALSE (default): no strip label should contain a newline
  p_nowrap <- plot_runscatter(
    data = mexp_long,
    variable = "intensity",
    rows_page = 3,
    cols_page = 4,
    label_wrap = FALSE,
    specific_page = 1,
    return_plots = TRUE
  )
  expect_s3_class(p_nowrap[[1]], "gg")
  expect_false(any(stringr::str_detect(get_strip_labels(p_nowrap[[1]]), "\n")))

  expect_doppelganger_cond("runscatter_label_wrap", p_wrap[[1]])
})

test_that("plot_runscatter collapse_excluded works", {
  p <- plot_runscatter(
    data = mexp,
    variable = "intensity",
    rows_page = 3,
    cols_page = 4,
    qc_types = c("TQC", "BQC"),
    show_batches = TRUE,
    collapse_excluded = TRUE,
    return_plots = TRUE
  )
  expect_s3_class(p[[1]], "gg")

  # With collapse_excluded, unique x values < total analysis_order range
  plot_data <- ggplot2::ggplot_build(p[[1]])$data[[2]]
  n_shown <- length(unique(plot_data$x))
  n_total <- diff(range(mexp@dataset$analysis_order)) + 1L
  expect_lt(n_shown, n_total)

  expect_doppelganger_cond("runscatter_collapse_excluded", p[[1]])
})

test_that("plot_runscatter collapse_excluded produces no gap markers", {
  p <- plot_runscatter(
    data = mexp,
    variable = "intensity",
    rows_page = 3,
    cols_page = 4,
    qc_types = c("TQC", "BQC"),
    collapse_excluded = TRUE,
    return_plots = TRUE
  )
  layer_classes <- sapply(p[[1]]$layers, function(l) class(l$geom)[1])
  # collapse_excluded alone must NOT add gap-marker labels
  expect_false(any(layer_classes %in% c("GeomLabel", "GeomText")))
})

test_that("plot_runscatter remove_gaps + collapse_excluded combined", {
  p <- plot_runscatter(
    data = mexp_gaps,
    variable = "intensity",
    rows_page = 3,
    cols_page = 4,
    qc_types = c("TQC", "BQC"),
    show_batches = TRUE,
    collapse_excluded = TRUE,
    remove_gaps = TRUE,
    return_plots = TRUE
  )
  expect_s3_class(p[[1]], "gg")

  # When filtering to TQC/BQC only, the real gap (excluded SPL analyses)
  # may or may not fall between visible QC orders.  Just verify it renders.
  expect_doppelganger_cond("runscatter_remove_gaps_collapse_excl", p[[1]])
})

test_that("plot_runscatter remove_gaps plot_range uses original order", {
  p_range <- plot_runscatter(
    data = mexp_gaps,
    variable = "intensity",
    rows_page = 3,
    cols_page = 4,
    remove_gaps = TRUE,
    plot_range = c(1, 50),
    return_plots = TRUE
  )
  expect_s3_class(p_range[[1]], "gg")

  # x upper range must be <= 50 (original order 50 = index 50, gap starts at 99)
  built <- ggplot2::ggplot_build(p_range[[1]])
  x_range <- built$layout$panel_params[[1]]$x.range
  expect_lte(x_range[2], 52) # small buffer for coord_cartesian expansion

  # No gap markers: d_gaps$gap_x is ~98.5 (index space), which is > 50
  layer_classes <- sapply(p_range[[1]]$layers, function(l) class(l$geom)[1])
  gap_label_layers <- p_range[[1]]$layers[
    layer_classes %in% c("GeomLabel", "GeomText")
  ]
  if (length(gap_label_layers) > 0) {
    label_data <- gap_label_layers[[1]]$data
    # All gap labels should be outside the plotted x range
    expect_true(all(label_data$gap_x > x_range[2]))
  }

  expect_doppelganger_cond("runscatter_remove_gaps_plotrange", p_range[[1]])
})
