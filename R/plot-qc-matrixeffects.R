#' Plot standardized feature intensities grouped by QC type
#'
#' This function creates a grouped beeswarm plot of standardized feature intensities,
#' where the y-axis represents intensity standardized such that the mean across all
#' features is 100%. Points are grouped by `qc_type` and spread using quasirandom jitter.
#'
#' @template data_mexp
#' @param variable A character string indicating the signal variable to plot.
#' Must be one of: "area", "height", "intensity", "norm_intensity", "response",
#' "conc", "conc_raw", "rt", "fwhm".
#' @template qc_types
#' @param batchwise_normalization A logical value indicating whether to normalize the signals by batch instead of globally.
#' @param include_qualifier A logical value indicating whether to include
#' qualifier features. Default is `TRUE`.
#' @param only_istd A logical value indicating whether to show only internal
#' standard (ISTD) features. Default is `TRUE`. Set to `FALSE` in combination with feature_filter parameters to show other features.
#' @template feature_filters
#' @param y_lim A numeric vector of length 2 specifying the y-axis limits.
#' @param point_size A numeric value indicating the size of points in
#' millimeters. Default is `0.5`.
#' @param dodge_width Numeric. Width used to dodge overlapping points by `qc_type`. Default is `0.6`.
#' @template font_base_size
#' @param point_alpha Numeric. Transparency of the plotted points. Default is `0.3`.
#' @param box_linewidth Numeric. Width of the boxplot lines. Default is `0.5`.
#' @param box_alpha Numeric. Transparency of the boxplot. Default is `0.3`.
#' @param angle_x Numeric. Angle of the x-axis text labels. Default is `45`.
#' @template legend_args
#' @template title
#'
#' @return A `ggplot` object showing the grouped standardized beeswarm plot.
#' @family QC plots
#' @export
#'

plot_matrixeffects <- function(
  data,
  variable = "intensity",
  qc_types = c("SPL", "TQC", "PBLK", "BQC"),
  batchwise_normalization = TRUE,
  include_qualifier = FALSE,
  only_istd = TRUE,
  include_feature_filter = NA,
  exclude_feature_filter = NA,
  min_median_value = NA,
  y_lim = c(-NA, NA),
  point_size = NULL,
  dodge_width = 0.6,
  point_alpha = 0.3,
  box_alpha = 0.3,
  box_linewidth = 0.5,
  font_base_size = NULL,
  legend_position = NULL,
  legend_size = NULL,
  show_legend_title = NULL,
  title = NULL,
  angle_x = 45
) {
  check_data(data)
  check_installed("ggbeeswarm")
  font_base_size <- resolve_plot_opt(font_base_size, "font_base_size", 11)
  point_size <- resolve_plot_opt(point_size, "point_size", 0.5)
  variable <- str_remove(variable, "feature_")
  rlang::arg_match(
    variable,
    c(
      "area",
      "height",
      "intensity",
      "norm_intensity",
      "response",
      "conc",
      "conc_raw",
      "rt",
      "fwhm",
      "width",
      "symmetry"
    )
  )
  variable <- stringr::str_c("feature_", variable)
  check_var_in_dataset(data@dataset, variable)
  variable_sym = rlang::sym(variable)

  if (all(is.na(qc_types))) {
    qc_types <- intersect(
      data$dataset$qc_type,
      c(
        "SPL",
        "TQC",
        "BQC",
        "HQC",
        "MQC",
        "LQC",
        "QC",
        "NIST",
        "LTR",
        "PBLK",
        "SBLK"
      )
    )
  }

  d_filt <- get_dataset_subset(
    data,
    filter_data = FALSE,
    qc_types = qc_types,
    include_qualifier = include_qualifier,
    include_istd = TRUE,
    include_feature_filter = include_feature_filter,
    exclude_feature_filter = exclude_feature_filter
  )

  if (!is.na(min_median_value)) {
    d_minsignal <- d_filt |>
      summarise(
        median_signal = median(!!variable_sym, na.rm = TRUE),
        .by = "feature_id"
      ) |>
      filter(.data$median_signal >= min_median_value)
    if (nrow(d_minsignal) == 0) {
      cli_abort(
        "No features passed the `min_median_value` filter. Please review the filter value, `variable` and data."
      )
    } else if (nrow(d_minsignal) == 1) {
      cli_abort(
        "Only 1 feature passed the `min_median_value` filter. Please review the filter value, `variable`, and data."
      )
    }

    d_filt <- d_filt |> semi_join(d_minsignal, by = "feature_id")
  }

  df <- d_filt |>
    dplyr::select(any_of(c(
      "feature_id",
      "qc_type",
      "batch_id",
      "is_istd",
      variable
    )))
  if (only_istd) {
    df <- df |> filter(.data$is_istd)
  }

  df$qc_type <- factor(
    df$qc_type,
    levels = c("PBLK", "TQC", "BQC", "LQC", "MQC", "HQC", "SPL", "NIST", "LTR")
  )

  grp <- if (batchwise_normalization) {
    c("feature_id", "batch_id")
  } else {
    "feature_id"
  }
  df_std <- df |>
    group_by(across(all_of(grp))) |>
    dplyr::mutate(
      scaled_intensity = !!variable_sym /
        mean(!!variable_sym, na.rm = TRUE) *
        100
    ) |>
    drop_na("scaled_intensity")

  ggplot2::ggplot(
    df_std,
    ggplot2::aes(
      x = .data$feature_id,
      y = .data$scaled_intensity,
      color = .data$qc_type,
      fill = .data$qc_type,
    )
  ) +
    ggbeeswarm::geom_quasirandom(
      # Shape 21 with a fixed dark border keeps points legible even when a QC
      # type's palette fill is faint or transparent (e.g. SPL, whose fill is
      # "NA"); the fill still encodes qc_type via `scale_fill_manual`.
      shape = 21,
      color = "grey25",
      stroke = 0.3,
      dodge.width = dodge_width,
      alpha = point_alpha,
      size = point_size,
    ) +
    ggplot2::geom_boxplot(
      ggplot2::aes(fill = .data$qc_type),
      position = ggplot2::position_dodge(width = dodge_width),
      alpha = box_alpha,
      width = 0.6,
      outlier.shape = NA,
      linewidth = box_linewidth,
    ) +
    ggplot2::geom_hline(
      yintercept = 100,
      linewidth = 0.5,
      color = "grey80",
      linetype = "dashed"
    ) +
    # ggplot2::labs(
    #   x = NULL,
    #   y = ""
    # ) +
    ggplot2::scale_color_manual(
      name = NULL,
      values = pkg.env$qc_type_annotation$qc_type_col,
      drop = TRUE
    ) +
    ggplot2::scale_fill_manual(
      name = NULL,
      values = pkg.env$qc_type_annotation$qc_type_fillcol,
      drop = TRUE
    ) +
    ggplot2::coord_cartesian(ylim = y_lim, expand = TRUE) +
    ggplot2::theme_bw(base_size = font_base_size) +
    ylab("Standardized Intensity (% of mean)") +
    xlab("Internal Standard") +
    theme(
      axis.text.x = ggplot2::element_text(angle = angle_x, hjust = 1),
      axis.title = element_text(size = font_base_size, face = "plain")
    ) +
    mrmhub_base_theme(font_base_size) +
    mrmhub_style_layer(
      font_base_size = font_base_size,
      legend_position = legend_position,
      legend_size = legend_size,
      show_legend_title = show_legend_title,
      title = title
    )
}
