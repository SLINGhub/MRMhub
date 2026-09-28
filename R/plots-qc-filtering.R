#' Plot QC filtering summary by feature class
#'
#' This function provides a summary of feature QC filtering based on feature class,
#' showing the number of features that passed or failed various quality control criteria.
#' It visualizes the filtering in a hierarchical sequence. Features are first evaluated
#' against lower-level filters such as signal-to-blank (S/B) ratios and minimum intensity,
#' followed by higher-level filters like the coefficient of variation (CV) or linear regression results.
#' This means that a feature is classified as failing a given criterion (e.g., `CV`)
#' only if it has passed all hierarchically lower filters (e.g., `S/B` ratio and minimum intensity).
#' Each feature is counted once; features retained via `features.to.keep`
#' despite failing are shown as "QC failed, kept".
#'
#' @template data_mexp
#' @template font_base_size
#' @template legend_args
#' @template title
#'
#' @return A `ggplot` object showing the feature QC filtering summary by feature class.
#'
#' @seealso
#' [plot_qc_summary_overall()] for an overall summary plot
#' [filter_features_qc()] for comparing QC metrics
#'
#' @family QC plots
#' @export

#'
# @param exclude_qualifier Whether to exclude any qualifier features in the plot. Default is `FALSE`.
# @param exclude_istd Whether to exclude any internal standard features in the plot. Default is `FALSE`.

# TODO: handling of features with (many) missing values, in SPL, in QC
# TODO: add option to facet by batch (required qc matrix by batch)
plot_qc_summary_byclass <- function(
  data = NULL,
  font_base_size = NULL,
  legend_position = NULL,
  legend_size = NULL,
  show_legend_title = NULL,
  title = NULL
) {
  check_data(data)
  font_base_size <- resolve_plot_opt(font_base_size, "font_base_size", 11)

  if (!data@is_filtered) {
    cli_abort(
      "Feature QC filter has not yet been applied, or data has changed. Please run `filter_features_qc()` first."
    )
  }

  if (all(is.na(data@metrics_qc$feature_class))) {
    cli::cli_abort(
      "This plot requires the `feature_class` to be defined in the data. Please define classes in the feature metadata or retrieve via corresponding functions."
    )
  }

  d_qc <- data@metrics_qc |>
    filter(.data$valid_feature, .data$in_data) |>
    mutate(
      feature_class = as.factor(.data$feature_class),
      feature_class = if (any(is.na(.data$feature_class))) {
        forcats::fct_na_value_to_level(.data$feature_class, "Undefined")
      } else {
        .data$feature_class
      }
    )

  # Each feature counts once, in the first QC criterion it fails
  d_qc_in <- d_qc |>
    filter(.data$pass_istd, .data$pass_qualifier) |>
    mutate(
      feature_class = droplevels(.data$feature_class),
      qc_criteria = qc_summary_category(pick(everything()))
    )
  d_qc_sum <- tidyr::expand_grid(
    feature_class = levels(d_qc_in$feature_class),
    qc_criteria = names(qc_summary_colors)
  ) |>
    left_join(
      d_qc_in |>
        mutate(feature_class = as.character(.data$feature_class)) |>
        summarise(count_pass = n(), .by = c("feature_class", "qc_criteria")),
      by = c("feature_class", "qc_criteria")
    ) |>
    mutate(
      count_pass = replace_na(.data$count_pass, 0L),
      percent_pass = .data$count_pass / sum(.data$count_pass) * 100,
      .by = "feature_class"
    )
  unused <- qc_summary_unused(d_qc_in, d_qc_sum)
  d_qc_sum <- d_qc_sum |>
    filter(!.data$qc_criteria %in% unused) |>
    mutate(
      feature_class = factor(
        .data$feature_class,
        levels(d_qc_in$feature_class)
      ),
      qc_criteria = factor(
        .data$qc_criteria,
        rev(setdiff(names(qc_summary_colors), unused))
      )
    )

  p <- ggplot(
    d_qc_sum,
    # Reverse the discrete axis by each row's own class code (not by row order):
    # `as.numeric(rev(feature_class))` reversed the data vector, so a class landed
    # under the wrong label whenever the rows were not in level order.
    aes(
      x = nlevels(.data$feature_class) + 1 - as.numeric(.data$feature_class),
      y = .data$count_pass
    )
  ) +
    ggplot2::geom_bar(
      aes(fill = .data$qc_criteria),
      stat = "identity",
      na.rm = TRUE
    ) +
    scale_fill_manual(
      values = qc_summary_colors,
      labels = qc_summary_labels,
      drop = FALSE
    ) +
    # facet_wrap(~Tissue) +
    # guides(fill = guide_legend(override.aes = list(size = 6))) +
    ggplot2::coord_flip() +
    labs(y = "Number of features", x = "Feature class") +
    #facet_wrap(~batch_id, scales = "free") +
    ggplot2::scale_y_continuous(expand = expansion(0.02, 0.03)) +
    ggplot2::scale_x_continuous(
      breaks = seq(1, nlevels(d_qc_sum$feature_class), by = 1),
      labels = rev(levels(d_qc_sum$feature_class)),
      expand = expansion(0.02, 0.02),
      sec.axis = ggplot2::sec_axis(
        ~.,
        name = "Features passing filter (% per class)",
        breaks = seq(1, nlevels(d_qc_sum$feature_class), by = 1),
        labels = rev(
          d_qc_sum |>
            filter(.data$qc_criteria == "all_filter_pass") |>
            mutate(
              txt = (paste0(
                .data$count_pass,
                " (",
                round(.data$percent_pass, 0),
                "%)"
              ))
            ) |>
            pull(.data$txt)
        )
      )
    ) +
    theme_bw(base_size = font_base_size) +
    theme(
      axis.title.y.right = element_text(angle = 90, vjust = 0.5, hjust = 0.5)
    ) +
    mrmhub_base_theme(font_base_size)

  p +
    mrmhub_style_layer(
      font_base_size = font_base_size,
      legend_position = legend_position,
      legend_size = legend_size,
      show_legend_title = show_legend_title,
      title = title
    )
}


#' Plot overall QC filtering summary
#'
#' This function generates a summary of the feature QC filtering process, visualizing the number of features that passed or failed the various QC criteria.
#' The bars apply the criteria hierarchically: a feature is counted once, under
#' the first criterion it fails, and features retained via `features.to.keep`
#' despite failing are shown as "QC failed, kept". See [plot_qc_summary_byclass()]
#' for more information.
#' The optional Venn diagram shows, for the features passing the missing-value
#' and minimum-intensity criteria, the overlap of features failing the
#' signal-to-blank, CV and linearity criteria; unlike the bars, it is not
#' hierarchical.
#'
#' @template data_mexp
#' @param with_venn Whether to include a Venn diagram summarizing the features excluded due to different QC criteria. Default is `TRUE`.
#' @template font_base_size
#'
#' @return A `ggplot` object showing the feature QC filtering summary with or without a Venn diagram.
#'
#' @details
#' The QC filtering process follows a hierarchical structure, where features are first evaluated against lower-level filters such as signal-to-blank ratios and minimum intensity.
#' Only features that pass these basic criteria are then subjected to higher-level filters like the coefficient of variation (CV) or linear regression results.
#' A feature will only fail a higher-level filter (such as `CV` or `R²`) if it has passed all previous lower-level filters.
#' This ensures that features are evaluated progressively, starting from fundamental quality checks up to more stringent filtering criteria.
#'
#' Note: The function currently shows a warning `Using `size` aesthetic for lines was deprecated in ggplot2 3.4.0.` which can be ignored.
#'
#' @family QC plots
#' @export

plot_qc_summary_overall <- function(
  data = NULL,
  with_venn = TRUE,
  font_base_size = NULL
) {
  check_data(data)
  font_base_size <- resolve_plot_opt(font_base_size, "font_base_size", 8)

  if (!data@is_filtered) {
    cli_abort(
      "Feature QC filter has not yet been applied, or data has changed. Please run `filter_features_qc()` first."
    )
  }

  d_qc <- data@metrics_qc |>
    filter(.data$valid_feature, .data$in_data)

  # Each feature counts once, in the first QC criterion it fails
  d_qc_in <- d_qc |> filter(.data$pass_istd, .data$pass_qualifier)
  category <- factor(qc_summary_category(d_qc_in), names(qc_summary_colors))
  d_qc_sum <- tibble(
    qc_criteria = levels(category),
    count_pass = as.vector(table(category))
  )
  unused <- qc_summary_unused(d_qc_in, d_qc_sum)
  d_qc_sum <- d_qc_sum |>
    filter(!.data$qc_criteria %in% unused) |>
    mutate(
      qc_criteria = factor(
        .data$qc_criteria,
        rev(setdiff(names(qc_summary_colors), unused))
      )
    )

  p_bar <- ggplot(
    d_qc_sum,
    aes(x = .data$qc_criteria, y = .data$count_pass, fill = .data$qc_criteria)
  ) +
    geom_bar(width = 1, stat = "identity") +
    coord_flip() +
    scale_fill_manual(values = qc_summary_colors) +
    ggplot2::scale_y_continuous(expand = expansion(mult = c(0.02, 0.1))) +
    ggplot2::scale_x_discrete(
      labels = qc_summary_labels,
      expand = expansion(0.12, 0.12)
    ) +
    # geom_text(aes(label = Count), size=4 ) +
    geom_text(
      aes(
        label = .data$count_pass,
        # Place the count label outside bars shorter than ~2/3 of the longest
        # (hjust -2) and inside longer bars (hjust 2), so labels never overflow
        # the panel or run off the bar end (x is flipped via coord_flip()).
        hjust = ifelse(.data$count_pass < max(.data$count_pass) / 1.5, -2, 2),
      ),
      size = font_base_size / 3.5,
    ) +
    labs(x = "", y = "Number of features") +
    # facet_wrap(~Tissue) +
    theme_bw(base_size = font_base_size) +
    theme(
      legend.position = "none",
      panel.grid.major.y = element_blank(), #element_line(color = "grey80", linewidth = .1),
      panel.grid.major.x = element_line(
        color = "grey80",
        linewidth = .2,
        linetype = "dotted"
      ),
      panel.grid.minor = element_blank()
    ) # Legend key size

  # prevent creating log file
  if (with_venn) {
    check_installed("ggvenn")
    check_installed("patchwork")

    # Same features as the bars; among those passing the missing-value and
    # minimum-intensity criteria, the (non-hierarchical) S/B, CV and linearity
    # failures
    d_qc_venn <- d_qc_in |>
      filter(
        !replace_na(.data$na_in_all, TRUE),
        replace_na(.data$pass_missingval, TRUE),
        replace_na(.data$pass_minint, TRUE)
      )
    sb_failed <- d_qc_venn$feature_id[!replace_na(d_qc_venn$pass_sb, TRUE)]
    cva_failed <- d_qc_venn$feature_id[!replace_na(d_qc_venn$pass_cva, TRUE)]
    lin_failed <- d_qc_venn$feature_id[
      !replace_na(d_qc_venn$pass_linearity, TRUE)
    ]

    keys <- c("below_sb", "above_cva", "bad_linearity")
    x2 <- rlang::set_names(
      list(sb_failed, cva_failed, lin_failed),
      qc_summary_labels[keys]
    )

    p_venn <- ggvenn::ggvenn(
      x2,
      names(x2),
      show_percentage = FALSE,
      fill_color = unname(qc_summary_colors[keys]),
      fill_alpha = 0.5,
      stroke_size = 0.0,
      text_size = font_base_size / 3.5,
      set_name_size = font_base_size / 3.5
    ) # + ggplot2::coord_cartesian(clip="off")

    plt <- patchwork::wrap_plots(p_bar, p_venn) +
      patchwork::plot_layout(ncol = 2, widths = c(1.3, 1)) +
      patchwork::plot_annotation(tag_levels = c("A", "B")) +
      theme(
        plot.tag = element_text(
          face = 'bold',
          size = font_base_size,
          color = 'black',
          hjust = 0,
          vjust = 0,
          margin = margin(10, 20, 10, 10)
        )
      )
  } else {
    plt <- p_bar
  }

  return(plt)
}


# QC summary categories, from the top of the stacked bar down, and colours
qc_summary_colors <- c(
  all_filter_pass = "#02bf83",
  kept_failed_qc = "#00796b",
  above_dratio = "#b5a2f5",
  bad_linearity = "#abdeed",
  above_cva = "#F44336",
  below_sb = "#d9d5b6",
  below_minint = "#ada3a3",
  above_missingness = "yellow",
  has_only_na = "#111111"
)

qc_summary_labels <- c(
  all_filter_pass = "passed",
  kept_failed_qc = "QC failed, kept",
  above_dratio = "> max D-ratio",
  bad_linearity = "failed RQC",
  above_cva = "> max CV",
  below_sb = "< min S/B",
  below_minint = "< min intensity",
  above_missingness = "> max missing",
  has_only_na = "all missing"
)

# One QC summary category per feature: the first criterion it fails, in the
# hierarchical order. Features kept via `features.to.keep` despite failing get
# their own category, so each feature is counted once.
qc_summary_category <- function(d_qc) {
  fails <- function(x) !replace_na(x, TRUE)
  case_when(
    !d_qc$all_qc_filter_pass & d_qc$pass_featureskeep ~ "kept_failed_qc",
    replace_na(d_qc$na_in_all, FALSE) ~ "has_only_na",
    fails(d_qc$pass_missingval) ~ "above_missingness",
    fails(d_qc$pass_minint) ~ "below_minint",
    fails(d_qc$pass_sb) ~ "below_sb",
    fails(d_qc$pass_cva) ~ "above_cva",
    fails(d_qc$pass_linearity) ~ "bad_linearity",
    fails(d_qc$pass_dratio) ~ "above_dratio",
    .default = "all_filter_pass"
  )
}

# Categories not shown: criteria that were not applied, and empty NA or kept
# categories
qc_summary_unused <- function(d_qc, d_qc_sum) {
  n <- function(x) sum(d_qc_sum$count_pass[d_qc_sum$qc_criteria == x])
  unused <- c(
    has_only_na = n("has_only_na") == 0,
    kept_failed_qc = n("kept_failed_qc") == 0,
    above_missingness = all(is.na(d_qc$pass_missingval)),
    below_minint = all(is.na(d_qc$pass_minint)),
    below_sb = all(is.na(d_qc$pass_sb)),
    above_cva = all(is.na(d_qc$pass_cva)),
    bad_linearity = all(is.na(d_qc$pass_linearity)),
    above_dratio = all(is.na(d_qc$pass_dratio))
  )
  names(unused)[unused]
}
