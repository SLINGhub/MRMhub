#' @param strip_text_size Optional facet strip text size, as a multiplier of
#'   `font_base_size` (when `<= 3`) or an absolute point size (when `> 3`).
#'   `NULL` (default) inherits from `font_base_size`.
#' @param strip_bg_color Optional facet strip background fill colour. The strip
#'   text colour is set automatically for contrast (white on a dark fill, black
#'   on a light one). `NULL` (default) keeps the house dark-navy strips.
#' @param legend_bg_alpha Optional opacity (`[0, 1]`) of a white legend
#'   background box, useful for a readable inside legend drawn over points.
#'   `NULL` (default) leaves the legend background unchanged.
