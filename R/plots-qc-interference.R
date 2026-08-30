#' Plot the results of interference correction
#'
#' This function generates grouped standardized beeswarm plots to visualize the results of interference correction
#' across different QC types.
#'
#' @inheritParams plot_matrixeffects
#' @param include_istd A logical value indicating whether to include internal
#' standards (ISTD) features.  Default is `TRUE`.
#' @param min_median_value Median raw-signal abundance floor: drop features whose
#'   median `feature_intensity` across the selected QC types is below this value.
#'   `NA` (default) applies no threshold. Use to hide low-signal features.
#' @param min_correction_pct Keep only features whose median correction (percent
#'   of raw signal removed, across the selected QC types) is at least this value.
#'   `NA` (default) applies no threshold. Use to focus the plot on
#'   substantially-corrected features.
#' @param sort_by_effect Order the x-axis by correction effect, defined per
#'   feature as the deviation of its median % change from 100% (pooled across the
#'   displayed QC-type points). One of `"none"` (default, alphabetical),
#'   `"desc"` (largest effect first) or `"asc"`.
#' @param top_n Keep only the `top_n` features with the largest correction
#'   effect (see `sort_by_effect`). `NA` (default) keeps all. Applied after the
#'   `min_median_value` / `min_correction_pct` filters.
#'
#' @return A `ggplot` object showing the grouped standardized beeswarm plot.
#' @family QC plots
#' @export

plot_interference_correction <- function(
  data,
  qc_types = c("SPL", "TQC", "PBLK", "BQC"),
  include_qualifier = FALSE,
  include_istd = TRUE,
  include_feature_filter = NA,
  exclude_feature_filter = NA,
  min_median_value = NA,
  min_correction_pct = NA,
  sort_by_effect = c("none", "desc", "asc"),
  top_n = NA,
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
  check_pkg_installed("ggbeeswarm")
  font_base_size <- resolve_plot_opt(font_base_size, "font_base_size", 11)
  point_size <- resolve_plot_opt(point_size, "point_size", 0.5)
  sort_by_effect <- match.arg(sort_by_effect)
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
    include_istd = include_istd,
    include_feature_filter = include_feature_filter,
    exclude_feature_filter = exclude_feature_filter
  )

  if (!is.na(min_median_value)) {
    d_minsignal <- d_filt |>
      summarise(
        median_signal = median(.data$feature_intensity, na.rm = TRUE),
        .by = "feature_id"
      ) |>
      filter(.data$median_signal >= min_median_value)
    if (nrow(d_minsignal) == 0) {
      cli_abort(
        "No features passed the `min_median_value` filter. Please review the filter value, `variable` and data."
      )
    }

    d_filt <- d_filt |> semi_join(d_minsignal, by = "feature_id")
  }

  if (!is.na(min_correction_pct)) {
    d_mincorr <- d_filt |>
      filter(
        .data$interference_corrected,
        !is.na(.data$feature_intensity_orig),
        .data$feature_intensity_orig > 0
      ) |>
      mutate(
        pct_removed = 100 *
          (.data$feature_intensity_orig - .data$feature_intensity) /
          .data$feature_intensity_orig
      ) |>
      summarise(
        median_removed = median(.data$pct_removed, na.rm = TRUE),
        .by = "feature_id"
      ) |>
      filter(.data$median_removed >= min_correction_pct)
    if (nrow(d_mincorr) == 0) {
      cli_abort(
        "No features passed the `min_correction_pct` filter. Please lower the threshold or review the data."
      )
    }
    d_filt <- d_filt |> semi_join(d_mincorr, by = "feature_id")
  }

  df <- d_filt |>
    dplyr::select(
      "feature_id",
      "qc_type",
      "batch_id",
      "is_istd",
      "interference_corrected",
      "feature_intensity",
      "feature_intensity_orig"
    ) |>
    filter(.data$interference_corrected) |>
    mutate(
      # Guard a zero/NA pre-correction intensity (e.g. a blank), which would
      # otherwise yield Inf/NaN percentages.
      perc_change = dplyr::if_else(
        is.na(.data$feature_intensity_orig) | .data$feature_intensity_orig == 0,
        NA_real_,
        (.data$feature_intensity / .data$feature_intensity_orig) * 100
      )
    )

  # Rank features by correction effect (how far the median % change lies from
  # 100%, pooled across the displayed QC-type points) for `top_n` / sorting.
  if (!is.na(top_n) || sort_by_effect != "none") {
    feature_effect <- df |>
      summarise(
        effect = abs(100 - median(.data$perc_change, na.rm = TRUE)),
        .by = "feature_id"
      ) |>
      arrange(desc(.data$effect))

    if (!is.na(top_n)) {
      keep <- head(feature_effect$feature_id, top_n)
      feature_effect <- feature_effect |> filter(.data$feature_id %in% keep)
      df <- df |> filter(.data$feature_id %in% keep)
    }

    if (sort_by_effect != "none") {
      lvls <- feature_effect$feature_id
      if (sort_by_effect == "asc") lvls <- rev(lvls)
      df$feature_id <- factor(df$feature_id, levels = lvls)
    }
  }

  df$qc_type <- factor(
    df$qc_type,
    levels = c("PBLK", "TQC", "BQC", "LQC", "MQC", "HQC", "SPL", "NIST", "LTR")
  )

  df_std <- df

  ggplot2::ggplot(
    df_std,
    ggplot2::aes(
      x = .data$feature_id,
      y = .data$perc_change,
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
    # Keep x expansion so the dodged boxes at the first/last feature are not
    # clipped by the panel border; tighten y only when an explicit `y_lim` zoom
    # is requested (clip out-of-range points cleanly, no extra padding) while
    # still padding the auto range so extreme points do not clip.
    ggplot2::coord_cartesian(ylim = y_lim) +
    ggplot2::scale_y_continuous(
      expand = if (all(is.na(y_lim))) {
        ggplot2::expansion(mult = 0.05)
      } else {
        ggplot2::expansion(0)
      }
    ) +
    ggplot2::theme_bw(base_size = font_base_size) +
    ylab("Signal after correction (% of original)") +
    xlab("Corrected Features") +
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


#' Plot the magnitude of interference correction as a histogram
#'
#' @description Shows how many features were affected by which magnitude of
#' interference correction, as a histogram of the per-feature correction impact
#' (percent of raw signal removed) within one or more QC types (study samples by
#' default). The data must already be interference-corrected. Features with no
#' impact are excluded and reported.
#'
#' @param data A [`MRMhubExperiment`][MRMhubExperiment-class] (already interference-corrected).
#' @param qc_types QC type(s) to summarize. Default `"SPL"` (study samples). Set
#'   to `NA` to use all non-blank sample/QC types.
#' @param include_qualifier Include qualifier features. Default `FALSE`.
#' @param include_istd Include internal standards. Default `TRUE`.
#' @param include_feature_filter Feature(s) to include by `feature_id`, as a
#'   character vector. Each element is matched exactly when it names an existing
#'   feature, otherwise treated as a regex; elements combine with OR. A full ID
#'   (e.g. `"S1P d18:0 [M>60]"`) needs no escaping, while patterns like `"PC|PE"`
#'   still work. `NA` or `""` ignores the filter.
#' @param exclude_feature_filter Feature(s) to exclude by `feature_id`, matched
#'   the same way as `include_feature_filter`. `NA` or `""` ignores the filter.
#' @param min_correction_pct Keep only features whose median correction (percent
#'   of raw signal removed) is at least this value. `NA` (default) keeps every
#'   feature with a positive impact. Use to drop negligible corrections.
#' @param binwidth Histogram bin width (percent). Default `NA` (30 bins).
#' @param font_base_size Base font size. Default `8`.
#' @return A `ggplot` object: feature count vs. percent of signal removed.
#' @family QC plots
#' @export
plot_qc_interference_impact <- function(
  data,
  qc_types = "SPL",
  include_qualifier = FALSE,
  include_istd = TRUE,
  include_feature_filter = NA,
  exclude_feature_filter = NA,
  min_correction_pct = NA,
  binwidth = NA,
  font_base_size = 8
) {
  check_data(data)
  if (
    !all(
      c("feature_intensity_orig", "interference_corrected") %in%
        names(data@dataset)
    )
  ) {
    cli_abort(c(
      "Data has not been interference-corrected.",
      "i" = "Run {.code correct_isotopic_interferences()} or {.code correct_custom_interferences()} first."
    ))
  }
  if (all(is.na(qc_types))) {
    qc_types <- intersect(
      data@dataset$qc_type,
      pkg.env$qc_type_annotation$qc_type_levels_nonblank
    )
  }
  missing_qc <- setdiff(qc_types, unique(data@dataset$qc_type))
  if (length(missing_qc) > 0) {
    mh_warn(
      "QC type(s) not present in the data and ignored: {.val {missing_qc}}."
    )
    qc_types <- setdiff(qc_types, missing_qc)
  }
  if (length(qc_types) == 0) {
    cli_abort("None of the requested `qc_types` are present in the data.")
  }

  d_filt <- get_dataset_subset(
    data,
    filter_data = FALSE,
    qc_types = qc_types,
    include_qualifier = include_qualifier,
    include_istd = include_istd,
    include_feature_filter = include_feature_filter,
    exclude_feature_filter = exclude_feature_filter
  )

  impact <- d_filt |>
    filter(
      .data$interference_corrected,
      # A zero/NA raw signal gives no meaningful percentage.
      !is.na(.data$feature_intensity_orig),
      .data$feature_intensity_orig > 0
    ) |>
    mutate(
      pct_removed = 100 *
        (.data$feature_intensity_orig - .data$feature_intensity) /
        .data$feature_intensity_orig
    ) |>
    group_by(.data$feature_id, .data$qc_type) |>
    summarise(
      pct_removed = stats::median(.data$pct_removed, na.rm = TRUE),
      .groups = "drop"
    )

  n_unaffected <- sum(impact$pct_removed <= 0, na.rm = TRUE)
  impact <- impact |> filter(.data$pct_removed > 0)
  if (n_unaffected > 0) {
    mh_info(
      "{n_unaffected} corrected feature/QC-type combination(s) with no impact were excluded."
    )
  }
  if (!is.na(min_correction_pct)) {
    n_below <- sum(impact$pct_removed < min_correction_pct, na.rm = TRUE)
    impact <- impact |> filter(.data$pct_removed >= min_correction_pct)
    if (n_below > 0) {
      mh_info(
        "{n_below} feature/QC-type combination(s) below the {min_correction_pct}% threshold were excluded."
      )
    }
  }
  if (nrow(impact) == 0) {
    cli_abort(
      "No features had a positive correction impact in the selected QC type(s)."
    )
  }

  impact$qc_type <- factor(impact$qc_type, levels = qc_types)

  hist_layer <- if (is.na(binwidth)) {
    ggplot2::geom_histogram(bins = 30, color = "white", linewidth = 0.2)
  } else {
    ggplot2::geom_histogram(
      binwidth = binwidth,
      color = "white",
      linewidth = 0.2
    )
  }

  # Study samples (SPL) carry no usable fill colour in the palette (stored as a
  # missing key or the literal "NA"), which would leave the histogram bars
  # invisible. Build fills for the QC types actually plotted, falling back to the
  # line colour (then grey) when no fill is defined.
  fillcol <- pkg.env$qc_type_annotation$qc_type_fillcol
  linecol <- pkg.env$qc_type_annotation$qc_type_col
  no_col <- function(x) is.na(x) || identical(unname(x), "NA")
  qc_present <- unique(as.character(impact$qc_type))
  fill_vals <- vapply(
    qc_present,
    function(q) {
      v <- unname(fillcol[q])
      if (no_col(v)) v <- unname(linecol[q])
      if (no_col(v)) v <- "grey50"
      v
    },
    character(1)
  )

  ggplot2::ggplot(
    impact,
    ggplot2::aes(x = .data$pct_removed, fill = .data$qc_type)
  ) +
    hist_layer +
    ggplot2::scale_fill_manual(
      values = fill_vals,
      drop = TRUE
    ) +
    ggplot2::theme_bw(base_size = font_base_size) +
    xlab("Interference correction (% of raw signal removed)") +
    ylab("Number of features") +
    theme(
      panel.grid.minor = element_blank(),
      axis.title = element_text(size = font_base_size, face = "plain"),
      panel.border = element_rect(linewidth = 0.7, color = "grey40"),
      legend.title = element_blank(),
      legend.text = element_text(size = font_base_size * 0.8)
    )
}
