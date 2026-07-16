#' Plot response curves
#'
#' This function plots response curves for each feature. Multiple response curves,
#' each with a linear regression line, can be plotted on the same graph.
#' Each feature is displayed as a separate facet.
#'
#' Features for plotting can be filtered using QC filters defined via
#' [filter_features_qc()] or through `include_feature_filter` and
#' `exclude_feature_filter` arguments. The resulting plots offer extensive
#' customization options, including point size, line width, point color, point
#' fill, point shape, line color, ribbon fill, and font base size.
#'
#' Plots will be divided into multiple pages if the number of features exceeds
#' the product of `rows_page` and `cols_page` settings. The function supports
#' both direct plotting within R and saving plots as PDF files. Additionally,
#' plots can be returned as a list of ggplot2 objects for further manipulation
#' or integration into other analyses.
#'
#' @template data_mexp
#' @param variable The variable to plot on the y-axis.
#' @param filter_data Whether to use all data (default) or only
#'   QC-filtered data (filtered via [filter_features_qc()]).
#' @param include_qualifier Logical, whether to include qualifier features. Default is `TRUE`.
#' @param include_istd Logical, whether to include internal standard (ISTD) features. Default is `TRUE`.
#' @template feature_filters_2
#' @param max_regression_value The maximum sample_amount (x) value for fitting
#' the regression line. If `NA`, regression is based on all data points.
#' @param output_pdf If `TRUE`, saves the generated plots as a PDF
#'   file. When `FALSE`, plots are directly plotted.
#' @param path The file path for saving the PDF. Must be defined if
#'   `output_pdf` is `TRUE`.
#' @param return_plots Logical. If `TRUE`, returns the plots as a list of
#'   `ggplot` objects.
#' @param color_curves A vector of colors for the curves. If `NULL` (default),
#' the colors for each curve are generated automatically. If colors are provided,
#' the number of colors must match the number of curves.
#' @param point_size Size of points in millimeters.
#' @param line_width Width of regression lines.
#' @template font_base_size
#' @param rows_page Number of rows of plots per page. Used for pagination in
#'   `curve_layout = "overlay"` and `"cols"`. Ignored in `curve_layout = "rows"`.
#' @param cols_page Number of columns of plots per page. Used for pagination in
#'   `curve_layout = "overlay"` and `"rows"`. Ignored in `curve_layout = "cols"`.
#' @param label_wrap Logical. If `TRUE`, long `feature_id` labels are wrapped to multiple
#'   lines using `label_wrap_width`. Default is `FALSE`.
#' @param label_wrap_width Integer. Maximum width in characters for wrapped labels when
#'   `label_wrap = TRUE`. Default is `25`. Ignored when `label_wrap = FALSE`.
#' @param curve_layout Controls how multiple curves are displayed. One of:
#'   \describe{
#'     \item{`"overlay"`}{(default) All curves overlaid in each feature panel using
#'       `facet_wrap2`. Pagination uses `rows_page * cols_page`.}
#'     \item{`"cols"`}{Grid layout with features as rows and curves as columns
#'       using `facet_grid2`. Pagination uses `rows_page` only.}
#'     \item{`"rows"`}{Grid layout with curves as rows and features as columns
#'       using `facet_grid2`. Pagination uses `cols_page` only.}
#'   }
#' @param fixed_scale_curves Logical. If `TRUE`, fixes the y-axis scale per feature row
#'   (`curve_layout = "cols"`) or per curve row (`curve_layout = "rows"`). If `FALSE`
#'   (default), each panel auto-scales. Silently ignored when `curve_layout = "overlay"`.

#' @param r2_vstep Numeric. Vertical step between stacked R-squared labels when multiple
#'   curves are plotted in the same panel (`curve_layout = "overlay"`). Default is `0.06`.
#'   Ignored when `curve_layout` is `"cols"` or `"rows"`, where each panel has one curve.
#' @param specific_page An integer specifying a specific page to plot. If
#'   `NA` (default), all pages are plotted.
#' @param page_orientation Orientation of the PDF paper: `"LANDSCAPE"` or
#'   `"PORTRAIT"`.
#' @param show_progress Logical. If `TRUE`, displays a progress bar during
#'   plot creation.
#'
#' @return If `return_plots` is `TRUE`, a list of `ggplot` objects is
#'   returned. Otherwise, the function saves the plot output or does not return
#'   anything.
#'
#' @family calibration plots
#' @export
#'
#'
plot_responsecurves <- function(
  data = NULL,
  variable = "intensity",
  # Data and filtering arguments
  filter_data = FALSE,
  include_qualifier = TRUE,
  include_istd = TRUE,
  include_feature_filter = NA,
  exclude_feature_filter = NA,
  max_regression_value = NA,

  # Output settings
  output_pdf = FALSE,
  path = NA,
  return_plots = FALSE,

  # Plot customization
  color_curves = NULL,
  point_size = 1.5,
  line_width = 0.7,
  label_wrap = FALSE,
  label_wrap_width = 25,
  font_base_size = 8,

  # Layout settings (for multi-page PDF)
  rows_page = 4,
  cols_page = 5,
  curve_layout = "overlay",
  fixed_scale_curves = FALSE,
  r2_vstep = 0.06,
  specific_page = NA,
  page_orientation = "LANDSCAPE",

  # Progress bar settings
  show_progress = TRUE
) {
  # {ggpmisc} neeeded for plots
  check_installed("ggpmisc")
  curve_layout <- rlang::arg_match(curve_layout, c("overlay", "cols", "rows"))

  # Validate arguments and corresponding data
  # -------------------------------------------
  check_data(data)
  variable_strip <- str_remove(variable, "feature_") # Clean variable name
  rlang::arg_match(
    variable_strip,
    c(
      "area",
      "height",
      "intensity",
      "norm_intensity",
      "response",
      "conc",
      "conc_raw",
      "rt",
      "fwhm"
    )
  )
  variable <- stringr::str_c("feature_", variable_strip)
  variable_sym <- rlang::sym(variable) # Convert to symbol for tidy evaluation
  check_var_in_dataset(data@dataset, variable) # Check if variable exists

  # Ensure path is defined when saving PDF
  if (output_pdf && (is.na(path) || path == "")) {
    cli::cli_abort(
      "The argument {.strong `path`} must be defined when {.strong output_pdf} is {.strong TRUE}."
    )
  }
  if (nrow(data@dataset) < 1) {
    cli::cli_abort(
      col_red(
        "No data available in the dataset. Please import the necessary data and metadata before proceeding."
      )
    )
  }
  if (nrow(data@annot_responsecurves) < 1) {
    cli::cli_abort(col_red(
      "No response curve metadata is available. Please import the corresponding metadata to proceed."
    ))
  }
  if (!"RQC" %in% unique(data@dataset$qc_type)) {
    cli::cli_abort(
      col_red(
        "No QC type {.strong 'RQC'} defined in the data. Please assign `RQC` as `qc_type` to corresponding analyses in the analysis metadata."
      )
    )
  }

  # Subset dataset according to filter arguments
  # -------------------------------------
  d_filt <- get_dataset_subset(
    data,
    filter_data = filter_data,
    qc_types = NA,
    include_qualifier = include_qualifier,
    include_istd = include_istd,
    include_feature_filter = include_feature_filter,
    exclude_feature_filter = exclude_feature_filter
  )

  # Link to response curve metadata and check for missmatch
  d_rqc <- d_filt |>
    select(any_of(c("analysis_id", "feature_id", variable))) |>
    inner_join(data@annot_responsecurves, by = "analysis_id", keep = FALSE)

  if (nrow(d_rqc) == 0) {
    cli_abort(col_red(
      "Missmatch between data and response curve metadata. Please verify if `analysis_id` in response curve metadata match the data."
    ))
  }

  # Ensure consistent units for analyzed_amount (x-axis)
  x_axis_unit <- unique(d_rqc$analyzed_amount_unit)
  if (length(x_axis_unit) > 1) {
    cli::cli_abort(cli::col_red(
      "The `analyzed_amount_unit` (x axis) must be
                                identical across all curves."
    ))
  }

  # Set max regression value, use all data if NA
  max_regression_value <- ifelse(
    is.na(max_regression_value),
    max(d_rqc$analyzed_amount, na.rm = TRUE),
    max_regression_value
  )

  #Check if color_curves is provided or is NA
  if (
    is.null(color_curves) ||
      length(color_curves) == 0 ||
      all(is.na(color_curves))
  ) {
    # If no color_curves is provided (NA or NULL), generate a discrete color scale
    n_curves <- length(unique(d_rqc$curve_id))
    if (n_curves < 5) {
      color_curves <- c("#34629e", "#91bfdb", "#fc8d59", "#d73027")
      fill_curves <- c("#8ba7cc", "#b3d2e6", "#f7c0a6", "#f07771")
    } else {
      color_curves <- scales::hue_pal()(n_curves)
      fill_curves <- scales::hue_pal()(n_curves)
    }
  } else {
    # If color_curves is provided, check if it has enough colors
    num_levels <- length(unique(d_rqc$curve_id))
    fill_curves <- desaturate_colors(color_curves, 0.3)
    if (length(color_curves) < num_levels) {
      cli::cli_abort(
        cli::col_red(paste(
          "Insufficient colors in `color_curves`. Provide at least",
          num_levels,
          "unique colors for the number of curves."
        ))
      )
    }
  }

  # Prepare PDF output
  if (output_pdf && !is.na(path)) {
    # nocov start
    path <- ifelse(
      stringr::str_detect(path, ".pdf"),
      path,
      paste0(path, ".pdf")
    )
    if (page_orientation == "LANDSCAPE") {
      pdf(
        file = path,
        onefile = TRUE,
        paper = "A4r",
        useDingbats = FALSE,
        width = 28 / 2.54,
        height = 20 / 2.54
      )
    } else {
      pdf(
        file = path,
        onefile = TRUE,
        paper = "A4",
        useDingbats = FALSE,
        height = 28 / 2.54,
        width = 20 / 2.54
      )
    }
  } # nocov end

  # Determine the range of pages to generate
  total_pages <- switch(
    curve_layout,
    "overlay" = ceiling(n_distinct(d_rqc$feature_id) / (cols_page * rows_page)),
    "cols" = ceiling(n_distinct(d_rqc$feature_id) / rows_page),
    "rows" = ceiling(n_distinct(d_rqc$feature_id) / cols_page)
  )

  if (!is.na(specific_page)) {
    if (specific_page > total_pages) {
      cli::cli_abort(col_red(
        "Selected page exceeds the total number of pages. Please select a page number between {.strong 1} and {.strong {total_pages}}."
      ))
    }
    page_range <- specific_page
  } else {
    page_range <- 1:total_pages
  }

  # Action text for progress output
  action_text <- if (output_pdf) "Saving plots to pdf" else "Generating plots"
  page_suffix <- if (max(page_range) > 1) {
    glue::glue("{max(page_range)} pages")
  } else {
    glue::glue("{max(page_range)} page")
  }
  progress_suffix <- if (show_progress) ":" else "..."

  # Output formatted message
  message(
    glue::glue("{action_text} ({page_suffix}){progress_suffix}"),
    appendLF = FALSE
  )

  # Initialize progress bar if requested
  if (show_progress) {
    pb <- txtProgressBar(min = 0, max = max(page_range), width = 30, style = 3)
  }

  p_list <- list() # List to store plots for each page
  for (i in page_range) {
    p <- plot_responsecurves_page(
      dataset = d_rqc,
      output_pdf = output_pdf,
      response_variable = variable,
      max_regression_value = max_regression_value,
      path = path,
      rows_page = rows_page,
      cols_page = cols_page,
      specific_page = i,
      point_size = point_size,
      line_width = line_width,
      font_base_size = font_base_size,
      x_axis_title = x_axis_unit,
      color_curves = color_curves,
      fill_curves = fill_curves,
      curve_layout = curve_layout,
      fixed_scale_curves = fixed_scale_curves,
      label_wrap = label_wrap,
      label_wrap_width = label_wrap_width,
      r2_vstep = r2_vstep
    )
    if (!return_plots) {
      plot(p)
    }
    dev.flush() # Flush the plot
    flush.console() # Ensure plot is rendered
    if (show_progress) {
      setTxtProgressBar(pb, i)
    } # Update progress bar
    p_list[[i]] <- p
  }

  if (output_pdf) {
    dev.off()
  } # Close PDF device
  message("  done!") # Completion message
  if (show_progress) {
    close(pb)
  } # Close progress bar if open

  # Return plot list or invisible
  if (return_plots) {
    return(p_list[page_range])
  } else {
    invisible()
  }
}

# Plot Response Curves for one page
plot_responsecurves_page <- function(
  dataset,
  output_pdf,
  response_variable,
  max_regression_value,
  path,
  rows_page,
  cols_page,
  specific_page,
  point_size,
  line_width,
  font_base_size,
  x_axis_title,
  color_curves,
  fill_curves,
  curve_layout,
  fixed_scale_curves,
  label_wrap = FALSE,
  label_wrap_width = 25,
  r2_vstep = 0.06
) {
  plot_var <- rlang::sym(response_variable)
  dataset$curve_id <- as.character(dataset$curve_id)

  # Subset dataset for current page
  n_samples <- length(unique(dataset$analysis_id))
  features <- unique(dataset$feature_id)

  dat_subset <- if (curve_layout == "cols") {
    # Paginate by features (rows_page features per page)
    feature_start <- rows_page * (specific_page - 1) + 1
    feature_end <- min(rows_page * specific_page, length(features))
    selected_features <- features[feature_start:feature_end]
    dataset |>
      filter(.data$feature_id %in% selected_features) |>
      arrange(.data$feature_id, .data$curve_id) |>
      group_by(.data$feature_id) |>
      mutate(not_zero = sum(!!plot_var != 0) > 2)
  } else if (curve_layout == "rows") {
    # Paginate by features (cols_page features per page)
    feature_start <- cols_page * (specific_page - 1) + 1
    feature_end <- min(cols_page * specific_page, length(features))
    selected_features <- features[feature_start:feature_end]
    dataset |>
      filter(.data$feature_id %in% selected_features) |>
      arrange(.data$curve_id, .data$feature_id) |>
      group_by(.data$feature_id) |>
      mutate(not_zero = sum(!!plot_var != 0) > 2)
  } else {
    # overlay: original slice-based pagination
    row_start <- n_samples * cols_page * rows_page * (specific_page - 1) + 1
    row_end <- n_samples * cols_page * rows_page * specific_page
    dataset |>
      arrange(.data$feature_id, .data$curve_id) |>
      slice(row_start:row_end) |>
      group_by(.data$feature_id) |>
      mutate(not_zero = sum(!!plot_var != 0) > 2)
  }

  dat_subset$curve_id <- factor(dat_subset$curve_id)
  # Add "Curve " prefix to curve_id strip labels in cols/rows modes
  if (curve_layout != "overlay") {
    dat_subset$curve_id <- factor(paste0("Curve ", dat_subset$curve_id))
  }

  # Build labeller for feature_id based on label_wrap parameter
  feature_labeller <- if (label_wrap) {
    ggplot2::label_wrap_gen(width = label_wrap_width, multi_line = TRUE)
  } else {
    ggplot2::label_value
  }

  # Single color used when each panel has exactly one curve (cols/rows modes)
  single_color <- color_curves[[1]]
  single_fill <- fill_curves[[1]]

  if (curve_layout == "cols") {
    # features as rows, curves as columns
    p <-
      ggplot(
        data = dat_subset,
        aes(x = .data$analyzed_amount, y = !!plot_var)
      ) +
      geom_smooth(
        data = subset(
          dat_subset,
          dat_subset$analyzed_amount <= max_regression_value
        ),
        aes(x = .data$analyzed_amount, y = !!plot_var),
        method = "lm",
        formula = y ~ x,
        se = FALSE,
        na.rm = TRUE,
        linewidth = line_width,
        color = single_color,
        inherit.aes = FALSE
      ) +
      ggpmisc::stat_poly_eq(
        data = dat_subset |>
          filter(
            .data$not_zero &
              .data$analyzed_amount <= max_regression_value
          ),
        aes(label = ggplot2::after_stat(.data$rr.label)),
        size = font_base_size * 0.4,
        rr.digits = 4,
        vstep = 0,
        na.rm = TRUE,
        rsquared.conf.level = NA,
        n.min = 3
      ) +
      scale_y_continuous(limits = c(0, NA)) +
      scale_x_continuous(
        limits = c(0, NA),
        breaks = scales::breaks_extended(6)
      ) +
      geom_point(
        size = point_size,
        shape = 21,
        na.rm = TRUE,
        color = single_color,
        fill = single_fill
      ) +
      labs(
        x = x_axis_title,
        y = stringr::str_remove(response_variable, "feature_")
      ) +
      theme_light(base_size = font_base_size) +
      theme(
        strip.text = element_text(size = font_base_size, face = "bold"),
        strip.background = element_rect(linewidth = 0.0001, fill = "#496875"),
        axis.text.y = element_text(size = font_base_size, colour = "black"),
        axis.ticks.y = element_line(colour = "black")
      ) +
      ggh4x::facet_grid2(
        rows = vars(.data$feature_id),
        cols = vars(.data$curve_id),
        scales = "free",
        independent = if (fixed_scale_curves) "x" else "y",
        drop = TRUE,
        axes = "all",
        remove_labels = "none",
        labeller = ggplot2::labeller(feature_id = feature_labeller)
      )
  } else if (curve_layout == "rows") {
    # curves as rows, features as columns
    # When fixed_scale_curves = TRUE: y is fixed per feature COLUMN using
    # facetted_pos_scales(); each panel is fully independent then overridden
    # per column. When FALSE: each panel auto-scales (independent = "y").
    facet_rows_independent <- if (fixed_scale_curves) "y" else "y"

    # Pre-compute per-feature y max for fixed scale per column
    if (fixed_scale_curves) {
      feat_ymax <- dat_subset |>
        dplyr::group_by(.data$feature_id) |>
        dplyr::summarise(
          ymax = max(!!plot_var, na.rm = TRUE) * 1.05,
          .groups = "drop"
        )
      # Build positional scale list in panel order (row-major: all cols of row1, then row2...)
      n_curves <- nlevels(dat_subset$curve_id)
      feat_levels <- levels(factor(dat_subset$feature_id))
      # Panel order in facet_grid: row1col1, row1col2, ..., row2col1, ...
      y_scale_list <- rep(
        lapply(feat_levels, function(feat) {
          ymax <- feat_ymax$ymax[feat_ymax$feature_id == feat]
          ggplot2::scale_y_continuous(limits = c(0, ymax))
        }),
        times = n_curves
      )
      # Reorder to row-major: for n_curves rows and n_feats cols
      # panel index = (row-1)*n_feats + col
      n_feats <- length(feat_levels)
      y_scale_list <- unlist(
        lapply(seq_len(n_curves), function(r) {
          lapply(seq_len(n_feats), function(c) {
            ggplot2::scale_y_continuous(
              limits = c(0, feat_ymax$ymax[c])
            )
          })
        }),
        recursive = FALSE
      )
    }

    p <-
      ggplot(
        data = dat_subset,
        aes(x = .data$analyzed_amount, y = !!plot_var)
      ) +
      geom_smooth(
        data = subset(
          dat_subset,
          dat_subset$analyzed_amount <= max_regression_value
        ),
        aes(x = .data$analyzed_amount, y = !!plot_var),
        method = "lm",
        formula = y ~ x,
        se = FALSE,
        na.rm = TRUE,
        linewidth = line_width,
        color = single_color,
        inherit.aes = FALSE
      ) +
      ggpmisc::stat_poly_eq(
        data = dat_subset |>
          filter(
            .data$not_zero &
              .data$analyzed_amount <= max_regression_value
          ),
        aes(label = ggplot2::after_stat(.data$rr.label)),
        size = font_base_size * 0.4,
        rr.digits = 4,
        vstep = 0,
        na.rm = TRUE,
        rsquared.conf.level = NA,
        n.min = 3
      ) +
      scale_y_continuous(limits = c(0, NA)) +
      scale_x_continuous(
        limits = c(0, NA),
        breaks = scales::breaks_extended(6)
      ) +
      geom_point(
        size = point_size,
        shape = 21,
        na.rm = TRUE,
        color = single_color,
        fill = single_fill
      ) +
      labs(
        x = x_axis_title,
        y = stringr::str_remove(response_variable, "feature_")
      ) +
      theme_light(base_size = font_base_size) +
      theme(
        strip.text = element_text(size = font_base_size, face = "bold"),
        strip.background = element_rect(linewidth = 0.0001, fill = "#496875"),
        axis.text.y = element_text(size = font_base_size, colour = "black"),
        axis.ticks.y = element_line(colour = "black")
      ) +
      ggh4x::facet_grid2(
        rows = vars(.data$curve_id),
        cols = vars(.data$feature_id),
        scales = "free",
        independent = "y",
        drop = TRUE,
        axes = "all",
        remove_labels = "none",
        labeller = ggplot2::labeller(feature_id = feature_labeller)
      )

    # Apply per-column fixed y scales when requested
    if (fixed_scale_curves) {
      p <- p + ggh4x::facetted_pos_scales(y = y_scale_list)
    }
  } else {
    # overlay: all curves in each feature panel
    p <-
      ggplot(
        data = dat_subset,
        aes(
          x = .data$analyzed_amount,
          y = !!plot_var,
          color = .data$curve_id,
          fill = .data$curve_id
        )
      ) +
      geom_smooth(
        data = subset(
          dat_subset,
          dat_subset$analyzed_amount <= max_regression_value
        ),
        aes(x = .data$analyzed_amount, y = !!plot_var, color = .data$curve_id),
        method = "lm",
        formula = y ~ x,
        se = FALSE,
        na.rm = TRUE,
        linewidth = line_width,
        inherit.aes = FALSE
      ) +
      ggpmisc::stat_poly_eq(
        data = dat_subset |>
          filter(
            .data$not_zero &
              .data$analyzed_amount <= max_regression_value
          ),
        aes(
          group = .data$curve_id,
          label = ggplot2::after_stat(.data$rr.label)
        ),
        size = font_base_size * 0.4,
        rr.digits = 4,
        vstep = r2_vstep,
        na.rm = TRUE,
        rsquared.conf.level = NA,
        n.min = 3
      ) +
      scale_color_manual(values = color_curves) +
      scale_fill_manual(values = fill_curves) +
      scale_y_continuous(limits = c(0, NA)) +
      scale_x_continuous(
        limits = c(0, NA),
        breaks = scales::breaks_extended(6)
      ) +
      geom_point(size = point_size, shape = 21, na.rm = TRUE) +
      labs(
        x = x_axis_title,
        y = stringr::str_remove(response_variable, "feature_")
      ) +
      theme_light(base_size = font_base_size) +
      theme(
        strip.text = element_text(size = font_base_size, face = "bold"),
        strip.background = element_rect(linewidth = 0.0001, fill = "#496875"),
        axis.text.y = element_text(size = font_base_size),
        axis.ticks.y = element_line()
      ) +
      ggh4x::facet_wrap2(
        vars(.data$feature_id),
        scales = "free",
        nrow = rows_page,
        ncol = cols_page,
        trim_blank = FALSE,
        labeller = ggplot2::labeller(feature_id = feature_labeller)
      )
  }

  p
}
