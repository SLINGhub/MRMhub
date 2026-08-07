test_that("split_by_curve option works correctly", {
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

  test_that("r2_vstep controls R-squared label spacing in stacked curve mode", {
    # Default r2_vstep = 0.06
    p_default <- plot_responsecurves(
      data = mexp,
      variable = "intensity",
      rows_page = 3,
      cols_page = 3,
      curve_layout = "overlay",
      specific_page = 1,
      return_plots = TRUE,
      show_progress = FALSE
    )
    expect_s3_class(p_default[[1]], "gg")
    # stat_poly_eq is the 2nd layer; check vstep == 0.06 (default)
    expect_equal(p_default[[1]]$layers[[2]]$stat_params$vstep, 0.06)

    # Custom r2_vstep = 0.10
    p_custom <- plot_responsecurves(
      data = mexp,
      variable = "intensity",
      rows_page = 3,
      cols_page = 3,
      curve_layout = "overlay",
      r2_vstep = 0.10,
      specific_page = 1,
      return_plots = TRUE,
      show_progress = FALSE
    )
    expect_s3_class(p_custom[[1]], "gg")
    expect_equal(p_custom[[1]]$layers[[2]]$stat_params$vstep, 0.10)

    # r2_vstep is ignored when curve_layout = "cols" (vstep hardcoded to 0)
    p_split <- plot_responsecurves(
      data = mexp,
      variable = "intensity",
      rows_page = 3,
      curve_layout = "cols",
      r2_vstep = 0.20,
      specific_page = 1,
      return_plots = TRUE,
      show_progress = FALSE
    )
    expect_s3_class(p_split[[1]], "gg")
    # In cols mode, vstep is hardcoded to 0 regardless of r2_vstep
    expect_equal(p_split[[1]]$layers[[2]]$stat_params$vstep, 0)
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

  test_that("curve_layout = 'cols' option works correctly", {
    p <- plot_responsecurves(
      data = mexp,
      variable = "intensity",
      rows_page = 3,
      cols_page = 4,
      curve_layout = "cols",
      return_plots = TRUE
    )
    expect_s3_class(p[[1]], "gg")
    expect_equal(class(p[[1]]$facet)[1], "FacetGrid2")
    # Legend should be suppressed (no colour/fill guide overrides needed since
    # no color aes is mapped)
    # Total features: 29, rows_page: 3 -> ceiling(29/3) = 10 pages
    expect_equal(length(p), 10)

    # Test specific page
    p_page <- plot_responsecurves(
      data = mexp,
      variable = "intensity",
      rows_page = 3,
      curve_layout = "cols",
      specific_page = 2,
      return_plots = TRUE
    )
    expect_equal(length(p_page), 1)
    expect_s3_class(p_page[[1]], "gg")

    # cols_page is ignored when curve_layout = "cols"
    p_with_cols <- plot_responsecurves(
      data = mexp,
      variable = "intensity",
      rows_page = 3,
      cols_page = 10,
      curve_layout = "cols",
      return_plots = TRUE
    )
    expect_equal(length(p_with_cols), 10)
  })

  test_that("curve_layout = 'rows' option works correctly", {
    # curves as rows, features as columns; pagination by cols_page
    # Total features: 29, cols_page: 5 -> ceiling(29/5) = 6 pages
    p <- plot_responsecurves(
      data = mexp,
      variable = "intensity",
      rows_page = 3,
      cols_page = 5,
      curve_layout = "rows",
      return_plots = TRUE
    )
    expect_s3_class(p[[1]], "gg")
    expect_equal(class(p[[1]]$facet)[1], "FacetGrid2")
    expect_equal(length(p), 6)

    # Check facet rows = curve_id, cols = feature_id
    facet_rows <- rlang::as_label(p[[1]]$facet$params$rows[[1]])
    facet_cols <- rlang::as_label(p[[1]]$facet$params$cols[[1]])
    expect_equal(facet_rows, "curve_id")
    expect_equal(facet_cols, "feature_id")

    # rows_page is ignored when curve_layout = "rows"
    p_ignored_rows <- plot_responsecurves(
      data = mexp,
      variable = "intensity",
      rows_page = 10,
      cols_page = 5,
      curve_layout = "rows",
      return_plots = TRUE
    )
    expect_equal(length(p_ignored_rows), 6)

    # Specific page
    p_page <- plot_responsecurves(
      data = mexp,
      variable = "intensity",
      cols_page = 5,
      curve_layout = "rows",
      specific_page = 2,
      return_plots = TRUE
    )
    expect_equal(length(p_page), 1)
    expect_s3_class(p_page[[1]], "gg")
  })

  test_that("fixed_scale_curves option works with curve_layout cols and rows", {
    # cols: fixed_scale_curves = TRUE -> independent = "x" (y shared per row)
    p_fixed_cols <- plot_responsecurves(
      data = mexp,
      variable = "intensity",
      rows_page = 3,
      curve_layout = "cols",
      fixed_scale_curves = TRUE,
      specific_page = 1,
      return_plots = TRUE
    )
    expect_s3_class(p_fixed_cols[[1]], "gg")
    facet_params <- p_fixed_cols[[1]]$facet$params
    expect_true(facet_params$independent$x)
    expect_false(facet_params$independent$y)

    # cols: fixed_scale_curves = FALSE -> independent = "y" (y free per panel)
    p_free_cols <- plot_responsecurves(
      data = mexp,
      variable = "intensity",
      rows_page = 3,
      curve_layout = "cols",
      fixed_scale_curves = FALSE,
      specific_page = 1,
      return_plots = TRUE
    )
    expect_s3_class(p_free_cols[[1]], "gg")
    facet_params_free <- p_free_cols[[1]]$facet$params
    expect_false(facet_params_free$independent$x)
    expect_true(facet_params_free$independent$y)

    # rows: fixed_scale_curves = TRUE -> y fixed per feature COLUMN via
    # facetted_pos_scales(). facet uses independent="y" internally but limits
    # are overridden per column so all panels in same column share y range.
    p_fixed_rows <- plot_responsecurves(
      data = mexp,
      variable = "intensity",
      cols_page = 5,
      curve_layout = "rows",
      fixed_scale_curves = TRUE,
      specific_page = 1,
      return_plots = TRUE
    )
    expect_s3_class(p_fixed_rows[[1]], "gg")
    # Verify y ranges are equal across rows for the same feature column
    gb_rows <- ggplot2::ggplot_build(p_fixed_rows[[1]])
    layout_rows <- gb_rows$layout$layout
    for (col_idx in unique(layout_rows$COL)) {
      panels_in_col <- which(layout_rows$COL == col_idx)
      y_ranges <- sapply(panels_in_col, function(pi) {
        diff(gb_rows$layout$panel_params[[pi]]$y.range)
      })
      expect_true(
        length(unique(round(y_ranges, 0))) == 1,
        info = paste(
          "Y range should be identical across rows for column",
          col_idx
        )
      )
    }

    # fixed_scale_curves silently ignored for overlay
    p_ignored <- plot_responsecurves(
      data = mexp,
      variable = "intensity",
      rows_page = 3,
      cols_page = 4,
      curve_layout = "overlay",
      fixed_scale_curves = TRUE,
      specific_page = 1,
      return_plots = TRUE
    )
    expect_s3_class(p_ignored[[1]], "gg")
    expect_equal(class(p_ignored[[1]]$facet)[1], "FacetWrap2")
  })

  test_that("curve_layout cols and rows work with PDF output", {
    temp_pdf_path <- file.path(tempdir(), "mrmhub_test_cols.pdf")
    p <- plot_responsecurves(
      data = mexp,
      variable = "intensity",
      rows_page = 3,
      curve_layout = "cols",
      output_pdf = TRUE,
      path = temp_pdf_path,
      return_plots = FALSE
    )
    expect_null(p)
    expect_true(file_exists(temp_pdf_path))
    expect_true(as.numeric(fs::file_size(temp_pdf_path)) / 1024 > 0)
    fs::file_delete(temp_pdf_path)

    temp_pdf_path2 <- file.path(tempdir(), "mrmhub_test_rows.pdf")
    p <- plot_responsecurves(
      data = mexp,
      variable = "intensity",
      cols_page = 5,
      curve_layout = "rows",
      specific_page = 1,
      output_pdf = TRUE,
      path = temp_pdf_path2,
      return_plots = FALSE
    )
    expect_silent(p)
    expect_true(file_exists(temp_pdf_path2))
    fs::file_delete(temp_pdf_path2)
  })

  test_that("curve_layout handles edge cases", {
    # Single feature with cols
    p_single <- plot_responsecurves(
      data = mexp,
      variable = "intensity",
      include_feature_filter = c("PC 40:6"),
      rows_page = 3,
      curve_layout = "cols",
      return_plots = TRUE
    )
    expect_s3_class(p_single[[1]], "gg")
    expect_equal(length(p_single), 1)

    # Filtered data with rows
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
      cols_page = 3,
      curve_layout = "rows",
      return_plots = TRUE
    )
    expect_s3_class(p_filtered[[1]], "gg")
    expect_true(length(p_filtered) > 0)
  })
  test_that("long feature_id labels are wrapped in all curve_layout modes", {
    skip_if_not_installed("dplyr", "1.2.0") # recode_values()
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

    # curve_layout = "cols"
    p_cols <- plot_responsecurves(
      data = mexp_long,
      variable = "intensity",
      rows_page = 3,
      curve_layout = "cols",
      label_wrap = TRUE,
      label_wrap_width = 20,
      specific_page = 1,
      include_feature_filter = long_ids,
      return_plots = TRUE,
      show_progress = FALSE
    )
    expect_s3_class(p_cols[[1]], "gg")
    expect_true(any(stringr::str_detect(get_strip_labels(p_cols[[1]]), "\n")))

    # curve_layout = "rows"
    p_rows <- plot_responsecurves(
      data = mexp_long,
      variable = "intensity",
      cols_page = 3,
      curve_layout = "rows",
      label_wrap = TRUE,
      label_wrap_width = 20,
      specific_page = 1,
      include_feature_filter = long_ids,
      return_plots = TRUE,
      show_progress = FALSE
    )
    expect_s3_class(p_rows[[1]], "gg")
    expect_true(any(stringr::str_detect(get_strip_labels(p_rows[[1]]), "\n")))

    # curve_layout = "overlay"
    p_wrap <- plot_responsecurves(
      data = mexp_long,
      variable = "intensity",
      rows_page = 3,
      cols_page = 2,
      curve_layout = "overlay",
      label_wrap = TRUE,
      label_wrap_width = 20,
      specific_page = 1,
      include_feature_filter = long_ids,
      return_plots = TRUE,
      show_progress = FALSE
    )
    expect_s3_class(p_wrap[[1]], "gg")
    expect_true(any(stringr::str_detect(get_strip_labels(p_wrap[[1]]), "\n")))
  })
})

test_that("plot_responsecurves R2 is fit over the same range as the drawn line", {
  # Regression (WS-P(A)): stat_poly_eq fit the full range while geom_smooth fit
  # only analyzed_amount <= max_regression_value, so the printed R2 did not
  # describe the drawn regression line. Fails on the old code.
  set.seed(123)
  mexp <- lipidomics_dataset
  mexp <- normalize_by_istd(mexp)
  mexp <- calc_qc_metrics(mexp)

  max_reg <- 60 # response curves span 10..100; this restricts the fit range
  pl <- plot_responsecurves(
    data = mexp,
    variable = "intensity",
    rows_page = 3,
    cols_page = 4,
    max_regression_value = max_reg,
    curve_layout = "cols",
    return_plots = TRUE,
    show_progress = FALSE
  )
  p <- pl[[1]]
  b <- ggplot2::ggplot_build(p)

  # The stat_poly_eq layer exposes the computed r.squared.
  r2_layer <- which(vapply(
    b$data,
    function(x) "r.squared" %in% names(x),
    logical(1)
  ))
  plotted_r2 <- sort(round(b$data[[r2_layer]]$r.squared, 6))

  r2_over <- function(dat) {
    dat |>
      dplyr::group_by(feature_id, curve_id) |>
      dplyr::filter(any(not_zero), sum(!is.na(feature_intensity)) >= 3) |>
      dplyr::summarise(
        r2 = summary(stats::lm(feature_intensity ~ analyzed_amount))$r.squared,
        .groups = "drop"
      ) |>
      dplyr::pull(r2) |>
      round(6) |>
      sort()
  }
  restricted <- r2_over(dplyr::filter(p$data, analyzed_amount <= max_reg))
  full <- r2_over(p$data)

  # Plotted R2 must match the restricted-range fit (the drawn line), not the
  # full range.
  expect_equal(plotted_r2, restricted, tolerance = 1e-5)
  expect_false(isTRUE(all.equal(restricted, full)))
})

test_that("plot_responsecurves keeps the R2 label when a curve point is NA", {
  # not_zero = sum(x != 0) lacked na.rm, so a single NA curve point propagated to
  # NA -> the stat_poly_eq filter treated it as FALSE and the feature lost its R2
  # label, despite plenty of non-zero points remaining.
  m <- lipidomics_dataset |> normalize_by_istd()
  curve_an <- m@annot_responsecurves$analysis_id
  tf <- unique(m@dataset$feature_id)[1]
  label_rows <- function(x) {
    p <- suppressMessages(suppressWarnings(plot_responsecurves(
      data = x,
      variable = "intensity",
      rows_page = 3,
      cols_page = 4,
      return_plots = TRUE
    )))
    b <- ggplot2::ggplot_build(p[[1]])
    li <- which(vapply(b$data, \(d) "label" %in% names(d), logical(1)))
    nrow(b$data[[li[1]]])
  }
  base_n <- label_rows(m)
  k <- which(
    m@dataset$feature_id == tf &
      m@dataset$analysis_id %in% curve_an &
      !is.na(m@dataset$feature_intensity) &
      m@dataset$feature_intensity != 0
  )
  m@dataset$feature_intensity[k[1]] <- NA_real_
  expect_equal(label_rows(m), base_n)
})

test_that("overlay pagination keeps each feature on a single page (non-uniform rows)", {
  # Make one feature short so features have non-uniform row counts. Row-index
  # pagination then straddled a page boundary and split a feature across pages;
  # feature-based pagination keeps each feature whole.
  mexp_rc <- lipidomics_dataset |> normalize_by_istd() |> calc_qc_metrics()
  rqc <- mexp_rc@dataset$qc_type == "RQC"
  f1 <- sort(unique(mexp_rc@dataset$feature_id[rqc]))[1]
  drop <- which(mexp_rc@dataset$feature_id == f1 & rqc)[1:3]
  mexp_rc@dataset <- mexp_rc@dataset[-drop, ]

  p <- suppressMessages(suppressWarnings(plot_responsecurves(
    mexp_rc,
    variable = "intensity",
    curve_layout = "overlay",
    rows_page = 2,
    cols_page = 2,
    return_plots = TRUE
  )))
  page_features <- lapply(p, function(x) unique(x$data$feature_id))
  # every feature appears on exactly one page (no feature split across pages)
  expect_false(any(duplicated(unlist(page_features))))
})

# page_orientation was never validated -> a typo silently produced a portrait PDF.
test_that("plot_responsecurves rejects an invalid page_orientation", {
  mexp <- calc_qc_metrics(normalize_by_istd(lipidomics_dataset))
  expect_error(
    plot_responsecurves(mexp, page_orientation = "landscape"),
    "page_orientation"
  )
})

# Branch 5: shared pretty-axis helper -> >=3 non-empty labels per facet axis.
test_that("plot_responsecurves axes render >=3 non-empty labels", {
  mexp <- lipidomics_dataset
  mexp <- normalize_by_istd(mexp)
  mexp <- calc_qc_metrics(mexp)

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

  p <- plot_responsecurves(
    data = mexp,
    variable = "intensity",
    rows_page = 3,
    cols_page = 4,
    return_plots = TRUE
  )
  expect_gte(length(axis_labels(p[[1]], "x")), 3)
  expect_gte(length(axis_labels(p[[1]], "y")), 3)
})
