#' PCA plot for quality control
#'
#' @description Generates a Principal Component Analysis (PCA) plot for
#' visualizing samples including quality control (QC) samples. This function
#' provides options for filtering data, applying transformations,
#' and labelling of outliers.
#'
#' Experimental batches can be visualized as ellipses to assess batch effects.
#'
#' This function returns a ggplot object. Identified outliers can be printed to the console.
#'
#' @template data_mexp
#' @param variable A character string indicating the variable to use for PCA
#' analysis. Must be one of: "area", "height", "intensity", "norm_intensity", "response",
#' "conc", "conc_raw", "rt", "fwhm".
#' @template qc_types
#' @param ellipse_variable String specifying which sample variable to show
#' as ellipses. Must be one of: "none", "qc_type", "batch_id".
#' "none" omits ellipses.
#' @param ellipse_levels A character vector specifying the levels of
#' `ellipse_variable` to display as ellipses.
#' @param pca_dims A numeric vector of length 2 indicating the PCA dimensions
#' to plot. Default is c(1, 2).
#' @param log_transform A logical value indicating whether to log-transform
#' the data before the PCA. Default is `TRUE`.
#'
#' @param filter_data A logical value indicating whether to use all data
#' (default) or only QC-filtered data (filtered via [filter_features_qc()]).
#' @param include_qualifier A logical value indicating whether to include
#' qualifier features. Default is `TRUE`.
#' @param include_istd A logical value indicating whether to include internal
#' standard (ISTD) features. Default is `TRUE`.
#' @template feature_filters
#'
#' @param show_labels A logical value indicating whether to show analysis_id
#' labels for points outside k * MAD of the selected PCA dimensions. Default
#' is `TRUE`.
#' @param labels_column A character string indicating the column to be used for the point labels. Typically "analysis_id" or "analysis_order".
#' Default is "analysis_id".
#' @param labels_threshold_mad A numeric value determining the threshold
#' for showing labels based on the median absolute deviation (MAD). Default
#' is 3. Set to `NULL` to suppress labels.
#' @param shared_labeltext_hide A character string representing text shared
#' across labels to be hidden (case-sensitive). If this results in
#' non-unique analysis_id's, an error will be raised.
#' @param label_font_size Number indicating the font size for labels in 'mm'.
#' Note the unit is different from font_base_size that is in 'pt'.
#'
#' @param point_size A numeric value indicating the size of points in
#' millimeters. Default is 2.
#' @param point_alpha A numeric value indicating the transparency of
#' points (0-1). Default is 0.5.
#' @template font_base_size
#' @template legend_args
#' @template legend_args_core
#' @template title
#' @param aspect_ratio Panel aspect ratio (height/width). Default `1` gives a
#'   square score plot (PC1/PC2 on the same visual scale); `NULL` leaves it free.
#' @param ellipse_confidence_level A numeric value indicating the confidence level
#' for the ellipses. Default is 0.95.
#' @param ellipse_linewidth A numeric value indicating the line width of the
#' ellipses. Default is 1.
#' @param ellipse_fill A logical value indicating whether to fill the ellipses.
#' @param ellipse_fillcolor A vector specifying the fill colors for ellipse corresponding
#'   to different `ellipse_variable` levels. This can be either an unnamed vector or a named
#'   vector, with names corresponding to leves in `ellipse_variable`. Unused fill colors will be ignored.
#'   Default is `NA` which corresponds to the default fill colors in case of
#'   `ellipse_variable = qc_type`, and to automatically generated colors otherwise.
#' @param ellipse_alpha A numeric value indicating the transparency of the
#' ellipse fill (0-1). Default is 0.3.

#'
#' @return A `ggplot` object with the PCA plot
#'
#' @family QC plots
#' @export
plot_pca <- function(
  data = NULL,
  variable,
  qc_types = NA,
  ellipse_variable = "qc_type",
  ellipse_levels = NA,
  pca_dims = c(1, 2),

  log_transform = TRUE,

  filter_data = FALSE,
  include_qualifier = FALSE,
  include_istd = FALSE,
  include_feature_filter = NA,
  exclude_feature_filter = NA,
  min_median_value = NA,

  show_labels = TRUE,
  labels_column = "analysis_id",
  labels_threshold_mad = 3,
  shared_labeltext_hide = NA,
  label_font_size = 3,

  point_size = 1.5,
  point_alpha = 0.7,
  font_base_size = 11,
  legend_position = "right",
  legend_size = NULL,
  show_legend_title = TRUE,
  title = NULL,
  strip_text_size = NULL,
  strip_bg_color = NULL,
  legend_bg_alpha = NULL,
  aspect_ratio = 1,

  ellipse_confidence_level = 0.95,
  ellipse_linewidth = 1,
  ellipse_fill = TRUE,
  ellipse_fillcolor = NA,
  ellipse_alpha = 0.1
) {
  # Check and define arguments

  check_data(data)
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
      "rt"
    )
  )
  variable <- stringr::str_c("feature_", variable)
  check_var_in_dataset(data@dataset, variable)
  variable_sym = rlang::sym(variable)

  rlang::arg_match(ellipse_variable, c("none", "qc_type", "batch_id"))
  ellipse_variable_sym = rlang::sym(ellipse_variable)

  PCx <- rlang::sym(paste0(".fittedPC", pca_dims[1]))
  PCy <- rlang::sym(paste0(".fittedPC", pca_dims[2]))

  if (show_labels) {
    check_installed("ggrepel")
  }
  if (ellipse_variable != "none") {
    check_installed("ggnewscale")
  }

  if (all(is.na(qc_types))) {
    qc_types <- intersect(
      data$dataset$qc_type,
      c("SPL", "TQC", "BQC", "TQC", "HQC", "MQC", "LQC", "NIST", "LTR")
    )
  }

  # Subset dataset according to filter arguments
  # -------------------------------------
  d_filt <- get_dataset_subset(
    data,
    filter_data = filter_data,
    qc_types = qc_types,
    include_qualifier = include_qualifier,
    include_istd = include_istd,
    include_feature_filter = include_feature_filter,
    exclude_feature_filter = exclude_feature_filter
  )

  d_filt <- d_filt |>
    dplyr::select(
      "analysis_id",
      "analysis_order",
      "qc_type",
      "batch_id",
      "feature_id",
      {{ variable }}
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

  d_wide <- d_filt |>
    tidyr::pivot_wider(
      id_cols = "analysis_id",
      names_from = "feature_id",
      values_from = all_of(variable)
    )

  # if(!all(d_filt |> pull(analysis_id) == d_metadata |> pull(AnalyticalID))) cli::cli_abort("Data and Metadata missmatch")

  # ToDo: warning when rows/cols with NA
  d_clean <- d_wide |>
    filter(if_any(dplyr::where(is.numeric), ~ !is.na(.))) |>
    dplyr::select(where(~ !any(is.na(.) | is.nan(.) | is.infinite(.) | . <= 0)))

  n_removed <- ncol(d_wide) - ncol(d_clean)
  if (n_removed > 0) {
    mh_warn(
      "{n_removed} features contained missing or non-numeric values and were exluded."
    )
  }

  d_metadata <- d_filt |>
    dplyr::select("analysis_id", "analysis_order", "qc_type", "batch_id") |>
    dplyr::distinct() |>
    dplyr::right_join(
      d_clean |> dplyr::select("analysis_id") |> distinct(),
      by = c("analysis_id")
    )

  m_raw <- d_clean |>
    tibble::column_to_rownames("analysis_id") |>
    as.matrix()

  if (log_transform) {
    m_raw <- log2(m_raw)
  }

  # prcomp(scale = TRUE) cannot rescale a constant (zero-variance) column; drop
  # such features with a warning instead of surfacing a cryptic prcomp error.
  col_sd <- apply(m_raw, 2, stats::sd, na.rm = TRUE)
  constant <- !is.na(col_sd) & col_sd == 0
  if (any(constant)) {
    mh_warn(
      "{sum(constant)} feature{?s} had zero variance across the selected samples and {?was/were} excluded from the PCA."
    )
    m_raw <- m_raw[, !constant, drop = FALSE]
  }

  # get pca result with annotation
  pca_res <- prcomp(m_raw, scale = TRUE, center = TRUE)
  pca_annot <- pca_augment(pca_res, d_metadata)

  # Order by the master qc_type levels (not a hard-coded subset), so QC types
  # the default selection includes (HQC/MQC/LQC, ...) keep their level and get a
  # colour/shape/legend from the scales below instead of collapsing to NA.
  pca_annot$qc_type <- droplevels(factor(
    pca_annot$qc_type,
    levels = pkg.env$qc_type_annotation$qc_type_levels
  ))
  pca_annot <- pca_annot |>
    dplyr::arrange(.data$qc_type)

  pca_contrib <- pca_eigenvalues(pca_res)

  # `&&` (short-circuit + scalar) so a NULL/NA threshold — the documented way to
  # suppress labels — does not error; and d_outlier is always defined (empty when
  # labels are off) so the join below never hits `object 'd_outlier' not found`.
  if (!is.null(labels_threshold_mad) && !is.na(labels_threshold_mad)) {
    d_outlier <- pca_annot |>
      filter(
        abs(!!PCx) > (median(!!PCx) + labels_threshold_mad * mad(!!PCx)) |
          abs(!!PCy) > (median(!!PCy) + labels_threshold_mad * mad(!!PCy))
      )
  } else {
    d_outlier <- pca_annot[0, ]
  }

  pca_annot <- pca_annot |>
    select("analysis_id":stringr::str_c(".fittedPC", max(pca_dims))) |>
    left_join(
      d_outlier |> select(any_of(labels_column)),
      by = labels_column,
      keep = TRUE,
      suffix = c("", "_outlier")
    ) |>
    rename(label_outlier = sym(paste0(labels_column, "_outlier")))

  if (!is.na(shared_labeltext_hide)) {
    pca_annot <- pca_annot |>
      mutate(
        label_outlier = str_remove(.data$label_outlier, shared_labeltext_hide)
      )
    if (any(duplicated(pca_annot$label_outlier, incomparables = NA))) {
      cli_abort(
        "`shared_labeltext_hide` setting causes duplicate labels. Please adjust or set to `NA` to show full labels."
      )
    }
  }

  #Check if ellipse_fillcolor is provided or is NA
  if (ellipse_variable != "none") {
    if (all(is.na(ellipse_levels))) {
      pca_annot_ellipses <- pca_annot
    } else {
      if (
        length(setdiff(ellipse_levels, unique(pca_annot[[ellipse_variable]]))) >
          0
      ) {
        cli_abort(
          "One or more levels in `ellipse_levels` are not present in `{ellipse_variable}`. Please verify the levels and `ellipse_variable`."
        )
      }
      pca_annot_ellipses <- pca_annot |>
        filter(.data[[ellipse_variable]] %in% ellipse_levels)
    }

    if (
      is.null(ellipse_fillcolor) ||
        length(ellipse_fillcolor) == 0 ||
        all(is.na(ellipse_fillcolor))
    ) {
      # If no ellipse_fillcolor is provided (NA or NULL), generate a discrete color scale
      n_col <- if (ellipse_variable == "qc_type") {
        length(unique(d_filt$qc_type))
      } else {
        length(unique(d_filt$batch_id))
      }
      if (ellipse_variable == "qc_type") {
        ellipse_fillcolor <- pkg.env$qc_type_annotation$qc_type_col
        # Make the color for SPL lighter for fill
        if (
          !is.null(ellipse_fillcolor[["SPL"]]) &&
            ellipse_fillcolor[["SPL"]] == "#8e9b9e"
        ) {
          ellipse_fillcolor[["SPL"]] <- "#cad6d9"
        }
      } else if (ellipse_variable == "batch_id") {
        ellipse_fillcolor <- scales::hue_pal()(n_col)
      } else {
        ellipse_fillcolor <- ellipse_fillcolor
      }
    } else {
      # If ellipse_fillcolor is provided, check if it has enough colors
      num_levels <- length(unique(pca_annot_ellipses[[ellipse_variable]]))
      if (length(ellipse_fillcolor) < num_levels) {
        cli::cli_abort(
          "Insufficient colors in `ellipse_fillcolor`. Provide at least {num_levels} unique colors for the number of {ellipse_variable}"
        )
      }
    }
  }

  p <- ggplot(
    data = pca_annot,
    mapping = aes(
      x = !!sym(paste0(".fittedPC", pca_dims[1])),
      y = !!sym(paste0(".fittedPC", pca_dims[2]))
    )
  ) +
    ggplot2::geom_hline(
      yintercept = 0,
      linewidth = 0.5,
      color = "grey80",
      linetype = "dashed"
    ) +
    ggplot2::geom_vline(
      xintercept = 0,
      linewidth = 0.5,
      color = "grey80",
      linetype = "dashed"
    )

  if (show_labels) {
    p <- suppressWarnings(
      p +
        ggrepel::geom_text_repel(
          aes(label = .data$label_outlier),
          size = label_font_size,
          na.rm = TRUE,
          seed = 1237,
          max.overlaps = 30
        )
    )
  }

  if (ellipse_variable != "none") {
    # The point legend already encodes qc_type, so drop the redundant qc_type
    # ellipse legend title; keep it for other variables (e.g. batch_id).
    ellipse_legend_title <- if (ellipse_variable == "qc_type") {
      NULL
    } else {
      ellipse_variable
    }
    p <- p +
      suppressWarnings(
        stat_ellipse(
          data = pca_annot_ellipses,
          aes(
            color = !!sym(ellipse_variable),
            fill = if (ellipse_fill) !!sym(ellipse_variable) else NA
          ),
          geom = "polygon",
          level = ellipse_confidence_level,
          alpha = ellipse_alpha,
          linewidth = ellipse_linewidth,
          na.rm = TRUE
        )
      ) +
      scale_fill_manual(
        name = "Batch Id",
        values = ellipse_fillcolor,
        drop = TRUE,
        na.value = "transparent"
      ) +
      scale_color_manual(
        name = "Batch Id",
        values = ellipse_fillcolor,
        drop = TRUE
      ) +
      ggplot2::guides(
        fill = if (ellipse_fill) {
          ggplot2::guide_legend(
            title = ellipse_legend_title,
            override.aes = list(size = 1, alpha = ellipse_alpha)
          )
        } else {
          "none"
        },
        color = if (ellipse_fill) {
          ggplot2::guide_legend(
            title = ellipse_legend_title
            #override.aes = list(size = 1, alpha = ellipse_alpha)
          )
        } else {
          ggplot2::guide_legend(
            title = ellipse_legend_title
            #override.aes = list(size = 1, alpha = 0.0)
          )
        }
      )
  }

  p <- p +
    ggnewscale::new_scale_fill() +
    ggnewscale::new_scale_color() +
    ggplot2::geom_point(
      size = point_size,
      aes(color = .data$qc_type, shape = .data$qc_type, fill = .data$qc_type),
      alpha = point_alpha
    ) +
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
    ggplot2::scale_shape_manual(
      name = NULL,
      values = pkg.env$qc_type_annotation$qc_type_shape,
      drop = TRUE
    )

  p <- p +
    ggplot2::theme_bw(base_size = font_base_size) +
    ggplot2::xlab(glue::glue(
      "PC{pca_dims[1]} ({round(pca_contrib[[pca_dims[1],'percent']]*100,1)}%)"
    )) +
    ggplot2::ylab(glue::glue(
      "PC{pca_dims[2]} ({round(pca_contrib[[pca_dims[2],'percent']]*100,1)}%)"
    )) +
    mrmhub_base_theme(font_base_size) +
    ggplot2::theme(
      axis.title.x = ggplot2::element_text(size = font_base_size * 1.2),
      axis.title.y = ggplot2::element_text(size = font_base_size * 1.2)
    )

  p <- p +
    mrmhub_style_layer(
      font_base_size = font_base_size,
      legend_position = legend_position,
      legend_size = legend_size,
      strip_text_size = strip_text_size,
      strip_bg_color = strip_bg_color,
      show_legend_title = show_legend_title,
      title = title,
      legend_bg_alpha = legend_bg_alpha,
      aspect_ratio = aspect_ratio
    )

  mh_success(
    "The PCA was calculated based on `{variable}` values of {length(unique(d_filt$feature_id))} features."
  )

  p
}

#' Plot PCA loadings
#'
#' Generates a plot of PCA loadings, illustrating the contribution of
#' features to each principal component. This function can be used to
#' investigate which feature (groups) are contributing to the variance seen in the plot and which need further investigation.
#'
#' @template data_mexp
#' @param variable A character string indicating the variable to use for PCA
#' analysis. Must be one of: "area", "height", "intensity", "norm_intensity", "response",
#' "conc", "conc_raw", "rt", "fwhm".
#' @template qc_types
#' @param pca_dims A numeric vector indicating for which PCA dimensions
#' the loadings should be shown. Default is c(1, 2, 3, 4).
#' @param log_transform A logical value indicating whether to log-transform
#' the data before the PCA. Default is `TRUE`.
#'
#' @param top_n Number of top features with highest absolute loading that will be shown for each PC dimension. Default is 30.
#' @param vertical_bars Show vertical bars instead of horizontal bars in the plot. Default is `FALSE`.
#' @param abs_loading Show absolute loading values instead of signed loadings. Default is `TRUE`.
#'
#' @param filter_data A logical value indicating whether to use all data
#' (default) or only QC-filtered data (filtered via [filter_features_qc()]).
#' @param include_qualifier A logical value indicating whether to include
#' qualifier features. Default is `TRUE`.
#' @param include_istd A logical value indicating whether to include internal
#' standard (ISTD) features. Default is `TRUE`.
#' @template feature_filters
#' @template font_base_size
#' @template legend_args
#' @template legend_args_core
#' @template title
#'
#' @return A `ggplot` object with PCA loadings plot
#'
#' @family QC plots
#' @export
plot_pca_loading <- function(
  data = NULL,
  variable,
  qc_types = NA,
  pca_dims = c(1, 2, 3, 4),
  log_transform = TRUE,
  top_n = 30,
  vertical_bars = FALSE,
  abs_loading = TRUE,
  filter_data = FALSE,
  include_qualifier = FALSE,
  include_istd = FALSE,
  include_feature_filter = NA,
  exclude_feature_filter = NA,
  min_median_value = NA,
  font_base_size = 11,
  legend_position = "right",
  legend_size = NULL,
  show_legend_title = TRUE,
  title = NULL,
  strip_text_size = NULL,
  strip_bg_color = NULL,
  legend_bg_alpha = NULL
) {
  # ... (all data prep code remains the same) ...

  check_data(data)
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
      "rt"
    )
  )
  variable <- stringr::str_c("feature_", variable)
  check_var_in_dataset(data@dataset, variable)
  variable_sym = rlang::sym(variable)

  if (all(is.na(qc_types))) {
    qc_types <- intersect(
      data$dataset$qc_type,
      c("SPL", "TQC", "BQC", "TQC", "HQC", "MQC", "LQC", "NIST", "LTR")
    )
  }

  d_filt <- get_dataset_subset(
    data,
    filter_data = filter_data,
    qc_types = qc_types,
    include_qualifier = include_qualifier,
    include_istd = include_istd,
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

  d_filt <- d_filt |>
    dplyr::select(
      "analysis_id",
      "qc_type",
      "batch_id",
      "feature_id",
      {{ variable }}
    ) |>
    tidyr::pivot_wider(
      id_cols = "analysis_id",
      names_from = "feature_id",
      values_from = {{ variable }}
    )

  d_filt <- d_filt |>
    tibble::column_to_rownames("analysis_id") |>
    dplyr::select(where(~ !any(is.na(.))))

  m_raw <- d_filt |>
    filter(if_any(dplyr::where(is.numeric), ~ !is.na(.))) |>
    dplyr::select(where(
      ~ !any(is.na(.) | is.nan(.) | is.infinite(.) | . <= 0)
    )) |>
    as.matrix()

  if (log_transform) {
    m_raw <- log2(m_raw)
  }
  pca_res <- prcomp(m_raw, scale = TRUE, center = TRUE)

  d_loading <- pca_rotation_wide(pca_res, name_col = "feature_name")

  d_loadings_selected <- d_loading |>
    tidyr::pivot_longer(
      cols = -"feature_name",
      names_to = "PC",
      values_to = "Value"
    ) |>
    dplyr::mutate(PC = as.numeric(stringr::str_remove(.data$PC, "PC"))) |>
    filter(.data$PC %in% pca_dims)

  d_loadings_selected <- d_loadings_selected |>
    dplyr::rowwise() |>
    dplyr::mutate(
      direction = if_else(.data$Value < 0, "neg", "pos"),
      Value = dplyr::if_else(abs_loading, abs(.data$Value), .data$Value),
      abs_value = abs(.data$Value)
    ) |>
    group_by(.data$PC)

  if (vertical_bars) {
    d_loadings_selected <- d_loadings_selected |>
      dplyr::arrange(.data$abs_value)
  } else {
    d_loadings_selected <- d_loadings_selected |>
      dplyr::arrange(desc(.data$abs_value))
  }

  d_loadings_selected <- d_loadings_selected |>
    dplyr::slice_max(order_by = .data$abs_value, n = top_n) |>
    ungroup() |>
    tidyr::unite("Feature", "feature_name", "PC", remove = FALSE) |>
    mutate(
      PC = as.factor(.data$PC),
      Feature = forcats::fct_reorder(.data$Feature, .data$abs_value)
    )

  p <- ggplot(
    d_loadings_selected,
    ggplot2::aes(
      x = .data$Feature,
      y = .data$Value,
      color = .data$direction,
      fill = .data$direction
    )
  ) +
    ggplot2::geom_col() +
    ggplot2::facet_wrap(
      ggplot2::vars(.data$PC),
      scales = "free",
      ncol = ifelse(vertical_bars, 1, length(pca_dims))
    ) +
    ggplot2::scale_color_manual(
      values = c("neg" = "lightblue", "pos" = "#FF8C00")
    ) +
    ggplot2::scale_fill_manual(
      values = c("neg" = "lightblue", "pos" = "#FF8C00")
    ) +
    ggplot2::theme_bw(base_size = 8)

  if (!vertical_bars) {
    p <- p +
      ggplot2::coord_flip() +
      # --- FIX: `limits = rev` is REMOVED for horizontal bars ---
      ggplot2::scale_x_discrete(
        labels = d_loadings_selected$feature_name,
        breaks = d_loadings_selected$Feature
      ) +
      ggplot2::labs(y = "Feature", x = "Loading")
  } else {
    p <- p +
      # --- FIX: `limits = rev` is KEPT for vertical bars ---
      ggplot2::scale_x_discrete(
        limits = rev,
        labels = d_loadings_selected$feature_name,
        breaks = d_loadings_selected$Feature
      ) +
      ggplot2::labs(x = "Feature", y = "Loading") +
      ggplot2::theme(
        axis.text.x = ggplot2::element_text(angle = 90, vjust = 0.5, hjust = 1)
      )
  }

  if (abs_loading) {
    p <- p + ggplot2::scale_y_continuous(expand = expansion(mult = c(0, 0.05)))
  }

  p <- p +
    theme_bw(base_size = font_base_size) +
    theme(
      axis.text.x = element_text(size = font_base_size * 0.6),
      axis.text.y = element_text(size = font_base_size * 0.6),
      axis.title = element_text(size = font_base_size, face = "bold")
    ) +
    mrmhub_base_theme(font_base_size, n_cols = length(pca_dims))

  p +
    mrmhub_style_layer(
      font_base_size = font_base_size,
      legend_position = legend_position,
      legend_size = legend_size,
      strip_text_size = strip_text_size,
      strip_bg_color = strip_bg_color,
      show_legend_title = show_legend_title,
      title = title,
      legend_bg_alpha = legend_bg_alpha
    )
}
