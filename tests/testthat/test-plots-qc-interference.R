library(ggplot2)

mexp <- mrmhub::MRMhubExperiment()
mexp <- mrmhub::import_data_masshunter(
  mexp,
  path = testthat::test_path(
    "testdata/masshunter/MRMhub_MHQuant_S1P.csv"
  ),
  import_metadata = FALSE
)
path <- testthat::test_path(
  "testdata/metadata/MRMhub_TestData_MHQuant_S1P_metadata_tables.xlsx"
)
expect_message(
  mexp <- mrmhub:::import_metadata_analyses(
    mexp,
    path = path,
    sheet = "Analyses",
    ignore_warnings = FALSE,
    excl_unmatched_analyses = TRUE
  ),
  "Analysis metadata associated with 64 analyses"
)
expect_message(
  mexp <- mrmhub:::import_metadata_features(
    mexp,
    path = path,
    sheet = "Features",
    ignore_warnings = TRUE
  ),
  "Feature metadata associated with 15 features"
)

mexp_original <- mexp
mexp2 <- lipidomics_dataset

mexp2@annot_features$interference_contribution[9] <- 0.5


mexp_corrected <-
  correct_custom_interferences(
    mexp,
    variable = "feature_intensity",
    sequential_correction = FALSE
  )


target_feature <- "S1P d18\\:0"


# Baseline test
test_that("Basic plot_qc_interferences looks as expected", {
  p <- plot_qc_interferences(mexp_corrected)
  # The name "qc-interferences-default" is more descriptive
  expect_doppelganger_cond("qc-interferences-default", p)
})


# --- Tests for Data Filtering Parameters ---

test_that("Filtering by qc_types works", {
  # The default includes "SPL". Let's plot only two.
  p <- plot_qc_interferences(mexp_corrected, qc_types = c("SPL"))
  expect_doppelganger_cond("qc-interferences-filter-qcs", p)
})

test_that("Excluding ISTDs works", {
  # The default is include_istd = TRUE. This should remove the ISTD features.
  p <- plot_qc_interferences(mexp_corrected, include_istd = FALSE)
  expect_doppelganger_cond("qc-interferences-no-istd", p)
})

test_that("Including a specific feature works", {
  # This should result in a plot with only one feature on the x-axis.
  # We pick a known corrected ISTD from the data.
  p <- plot_qc_interferences(
    mexp_corrected,
    include_feature_filter = target_feature
  )
  expect_doppelganger_cond("qc-interferences-include-filter", p)
})

test_that("Excluding a specific feature works", {
  # The plot should be missing the "LPC(17:0) (IS)" feature compared to the default.
  p <- plot_qc_interferences(
    mexp_corrected,
    exclude_feature_filter = target_feature
  )
  expect_doppelganger_cond("qc-interferences-exclude-filter", p)
})

test_that("min_median_value filter works visually", {
  # From inspecting the data, a value of 9000 will filter out some but not all features.
  # This tests that the filtering logic is applied correctly.
  p <- plot_qc_interferences(mexp_corrected, min_median_value = 49000)
  expect_doppelganger_cond("qc-interferences-min-median", p)
})

test_that("min_median_value throws error when no features remain", {
  # A very high value should filter out all features and trigger the error.
  expect_error(
    plot_qc_interferences(mexp_corrected, min_median_value = 99999999),
    "No features passed the `min_median_value` filter"
  )
})


# --- Tests for Aesthetic Parameters ---

test_that("Aesthetic parameters are applied correctly", {
  # Change several visual parameters at once to create a distinct plot.
  p <- plot_qc_interferences(
    mexp_corrected,
    y_lim = c(60, 105), # Zoom in on the y-axis (fits this dataset's spread)
    point_size = 2, # Larger points
    point_alpha = 0.8, # More opaque points
    angle_x = 0, # Horizontal x-axis labels
    font_base_size = 12 # Larger font
  )
  expect_doppelganger_cond("qc-interferences-aesthetics", p)
})

test_that("Plot works with NA qc_types to auto-detect", {
  # This tests the initial `if (all(is.na(qc_types)))` block.
  # The result should be identical to the default plot in this case.
  p <- plot_qc_interferences(mexp_corrected, qc_types = NA)
  expect_doppelganger_cond("qc-interferences-na-qcs", p)
})


test_that("Object check: include_feature_filter correctly filters the data layer", {
  # Define the feature we want to isolate

  # Generate the plot
  p <- plot_qc_interferences(
    mexp_corrected,
    include_feature_filter = target_feature
  )

  # 1. Build the plot to access the data used for rendering
  built_plot <- ggplot_build(p)
  plot_data <- built_plot$data[[1]]
  x_axis_labels <- built_plot$layout$panel_params[[1]]$x$get_labels()

  expect_length(x_axis_labels, 1)
  expect_equal(x_axis_labels, "S1P d18:0 [M>60]")
})

# Missing check_data() let a non-MRMhubExperiment fail cryptically downstream.
test_that("plot_qc_interferences validates the data object", {
  expect_error(plot_qc_interferences(data = 42), "MRMhubExperiment")
})


test_that("plot_qc_interference_impact aborts on uncorrected data", {
  expect_error(
    plot_qc_interference_impact(mexp_original),
    "not been interference-corrected"
  )
})

test_that("plot_qc_interference_impact returns a ggplot for corrected data", {
  p <- suppressWarnings(suppressMessages(
    plot_qc_interference_impact(mexp_corrected, qc_types = NA)
  ))
  expect_s3_class(p, "ggplot")
})

test_that("plot_qc_interference_impact renders a visible fill for SPL", {
  # Regression: study samples (SPL) carry no usable fill in the palette (stored
  # as the literal "NA"), which would render the histogram bars invisible. The
  # fill must fall back to a real colour.
  p <- suppressWarnings(suppressMessages(
    plot_qc_interference_impact(mexp_corrected, qc_types = "SPL")
  ))
  fills <- ggplot2::ggplot_build(p)$data[[1]]$fill
  expect_false(anyNA(fills))
  expect_false(any(fills == "NA"))
})

test_that("min_correction_pct filters features in the interference plots", {
  n_all <- length(unique(
    plot_qc_interferences(mexp_corrected, qc_types = "SPL")$data$feature_id
  ))
  n_thr <- length(unique(
    suppressWarnings(suppressMessages(
      plot_qc_interferences(
        mexp_corrected,
        qc_types = "SPL",
        min_correction_pct = 10
      )
    ))$data$feature_id
  ))
  expect_lt(n_thr, n_all)

  imp <- suppressWarnings(suppressMessages(
    plot_qc_interference_impact(
      mexp_corrected,
      qc_types = "SPL",
      min_correction_pct = 10
    )
  ))
  expect_true(all(imp$data$pct_removed >= 10))
})

# Expected feature ranking by correction effect, recomputed independently from
# the plotted data (effect = |100 - median(perc_change)| pooled across points).
effect_ranking <- function(p) {
  eff <- p$data |>
    dplyr::summarise(
      effect = abs(100 - median(.data$perc_change, na.rm = TRUE)),
      .by = "feature_id"
    ) |>
    dplyr::arrange(dplyr::desc(.data$effect))
  as.character(eff$feature_id)
}

test_that("top_n keeps the highest-effect features", {
  ranked <- effect_ranking(plot_qc_interferences(mexp_corrected))
  p_top <- plot_qc_interferences(mexp_corrected, top_n = 3)
  expect_setequal(unique(as.character(p_top$data$feature_id)), head(ranked, 3))
})

test_that("sort_by_effect orders the x-axis by correction effect", {
  ranked <- effect_ranking(plot_qc_interferences(mexp_corrected))

  p_desc <- plot_qc_interferences(mexp_corrected, sort_by_effect = "desc")
  expect_equal(levels(p_desc$data$feature_id), ranked)

  p_asc <- plot_qc_interferences(mexp_corrected, sort_by_effect = "asc")
  expect_equal(levels(p_asc$data$feature_id), rev(ranked))
})

test_that("sort_by_effect rejects an invalid value", {
  expect_error(
    plot_qc_interferences(mexp_corrected, sort_by_effect = "bogus"),
    "should be one of"
  )
})
