#library(vdiffr)
library(ggplot2)

mexp <- lipidomics_dataset
mexp <- normalize_by_istd(mexp)
mexp <- calc_qc_metrics(mexp)


# Baseline test
test_that("Default plot_qc_matrixeffects looks as expected", {
  p <- plot_qc_matrixeffects(data = mexp)
  expect_doppelganger_cond("matrixeffects-default", p)
})


test_that("y-axis label matches the standardization (% of mean)", {
  p <- plot_qc_matrixeffects(data = mexp)
  # The axis must describe what is plotted: each point is an intensity as a
  # percentage of its (per-feature) mean, not a "% of uncorrected" baseline.
  expect_match(p$labels$y, "% of mean", fixed = TRUE)
  # The standardization sets each feature's mean to 100, so the pooled mean is 100.
  expect_equal(mean(p$data$scaled_intensity, na.rm = TRUE), 100)
})


# --- Tests for Core Logic ---

test_that("batchwise_normalization = FALSE changes the standardization", {
  # This is a critical logic test. With global normalization, the spread of
  # points within each feature should change compared to the default batchwise plot.
  p <- plot_qc_matrixeffects(data = mexp, batchwise_normalization = FALSE)
  expect_doppelganger_cond("matrixeffects-no-batchnorm", p)
})

test_that("Using a different `variable` works haha", {
  # This tests that the function correctly selects and processes a different input column.
  # We use 'norm_intensity' which was created by normalize_by_istd().
  p <- plot_qc_matrixeffects(data = mexp, variable = "norm_intensity")
  expect_doppelganger_cond("matrixeffects-var-norm-intensity", p)
})

test_that("only_istd = FALSE includes non-ISTD features", {
  # This should dramatically increase the number of features on the x-axis.
  p <- plot_qc_matrixeffects(data = mexp, only_istd = FALSE)
  expect_doppelganger_cond("matrixeffects-all-features", p)
})


# --- Tests for Data Filtering ---

test_that("Filtering by qc_types works", {
  # Plotting only SPL and TQC should result in a plot with only two colors/groups.
  p <- plot_qc_matrixeffects(data = mexp, qc_types = c("SPL", "TQC"))
  expect_doppelganger_cond("matrixeffects-filter-qcs", p)
})

test_that("min_median_value filter works visually", {
  # A value of 500,000 should filter out some of the lower-intensity ISTDs.
  p <- plot_qc_matrixeffects(data = mexp, min_median_value = 500000)
  expect_doppelganger_cond("matrixeffects-min-median", p)
})

test_that("min_median_value throws error when no features remain", {
  # A very high value should trigger the "No features passed" error.
  expect_error(
    plot_qc_matrixeffects(data = mexp, min_median_value = 99999999),
    "No features passed the `min_median_value` filter"
  )
})


# --- Test for Aesthetics ---

test_that("Aesthetic parameters are applied correctly", {
  # Bundle several aesthetic changes to create a visually distinct plot.
  p <- plot_qc_matrixeffects(
    data = mexp,
    y_lim = c(50, 150),
    font_base_size = 12,
    angle_x = 0,
    point_size = 1.5
  )
  expect_doppelganger_cond("matrixeffects-aesthetics", p)
})


# --- Object Check for Precise Logic Validation ---

test_that("Object check: only_istd = FALSE correctly adds non-ISTD features to axis", {
  # This test programmatically verifies the logic of `only_istd` without
  # relying on a visual comparison.

  # Generate the plot with all features
  p <- plot_qc_matrixeffects(data = mexp, only_istd = FALSE)

  # Build the plot and get the final labels that will be drawn on the x-axis
  built_plot <- ggplot_build(p)
  x_axis_labels <- built_plot$layout$panel_params[[1]]$x$get_labels()

  # Assert that a known non-ISTD feature is now present in the labels
  # (We pick one from the lipidomics_dataset)
  expect_true("LPC 18:1 (b)" %in% x_axis_labels)

  # Assert that a known ISTD is also still present
  expect_true("CE 18:1 d7 (ISTD)" %in% x_axis_labels)
})

# Missing check_data() let a non-MRMhubExperiment fail cryptically downstream.
test_that("plot_qc_matrixeffects validates the data object", {
  expect_error(plot_qc_matrixeffects(data = 42), "MRMhubExperiment")
})
