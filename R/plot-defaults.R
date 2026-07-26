#' Set global default appearance for MRMhub plots
#'
#' Sets session-wide defaults for the shared appearance arguments of the
#' `plot_*()` functions, so common choices such as a smaller base font or point
#' size can be made once at the top of a notebook instead of on every call.
#' Defaults are stored as `mrmhub.*` options. The precedence for every argument
#' is: a value passed explicitly to a plotting function wins, then the global
#' default set here, then the function's built-in default (including automatic
#' `cols_page`-based sizing on faceted plots).
#'
#' Only the arguments you supply are changed; the rest are left untouched. Pass
#' `NULL` (the default) to leave a setting as it is, and use
#' [mrmhub_reset_plot_defaults()] to clear them all. The previous option values
#' are returned invisibly, so a set can be undone with `options(old)` or scoped
#' to a block with [withr::local_options()].
#'
#' @param font_base_size Base font size in points; all plot text scales from it.
#' @param point_size Point/marker size.
#' @param legend_position Legend placement: a keyword (`"right"`, `"left"`,
#'   `"top"`, `"bottom"`, `"none"`), a corner (`"inside-tr"`, `"inside-tl"`,
#'   `"inside-br"`, `"inside-bl"`), or a numeric `c(x, y)`.
#' @param legend_size Scales the whole legend (text, title, key and glyphs); a
#'   value `<= 3` is a multiplier of `font_base_size`, larger values are points.
#' @param show_legend_title `FALSE` hides legend titles.
#' @param strip_bg_color Facet strip background fill (strip text auto-contrasts).
#'
#' @return Invisibly, a named list of the option values as they were before this
#'   call (as returned by [options()]).
#' @seealso [mrmhub_reset_plot_defaults()], [mrmhub_get_plot_defaults()] and the
#'   `vignette("manual-13-plot-customization")` article.
#' @examples
#' old <- mrmhub_set_plot_defaults(font_base_size = 8, point_size = 0.8)
#' # ... make plots with the smaller defaults ...
#' options(old) # restore
#' @export
mrmhub_set_plot_defaults <- function(
  font_base_size = NULL,
  point_size = NULL,
  legend_position = NULL,
  legend_size = NULL,
  show_legend_title = NULL,
  strip_bg_color = NULL
) {
  new <- list(
    mrmhub.font_base_size = font_base_size,
    mrmhub.point_size = point_size,
    mrmhub.legend_position = legend_position,
    mrmhub.legend_size = legend_size,
    mrmhub.show_legend_title = show_legend_title,
    mrmhub.strip_bg_color = strip_bg_color
  )
  new <- new[!vapply(new, is.null, logical(1))]
  invisible(options(new))
}

#' Clear the global MRMhub plot defaults
#'
#' Removes all `mrmhub.*` plot-appearance options set by
#' [mrmhub_set_plot_defaults()], restoring the built-in per-function defaults.
#'
#' @return Invisibly, the previous option values (as returned by [options()]).
#' @seealso [mrmhub_set_plot_defaults()]
#' @examples
#' mrmhub_set_plot_defaults(font_base_size = 8)
#' mrmhub_reset_plot_defaults()
#' @export
mrmhub_reset_plot_defaults <- function() {
  invisible(options(stats::setNames(
    vector("list", length(.mrmhub_plot_option_names)),
    .mrmhub_plot_option_names
  )))
}

#' Report the global MRMhub plot defaults
#'
#' Returns the currently set `mrmhub.*` plot-appearance options as a named list.
#' Options that are not set are omitted.
#'
#' @return A named list of the active plot defaults (empty if none are set).
#' @seealso [mrmhub_set_plot_defaults()]
#' @examples
#' mrmhub_set_plot_defaults(font_base_size = 8)
#' mrmhub_get_plot_defaults()
#' mrmhub_reset_plot_defaults()
#' @export
mrmhub_get_plot_defaults <- function() {
  vals <- lapply(.mrmhub_plot_option_names, getOption)
  names(vals) <- sub("^mrmhub\\.", "", .mrmhub_plot_option_names)
  vals[!vapply(vals, is.null, logical(1))]
}

# The set of options managed by the plot-defaults helpers.
.mrmhub_plot_option_names <- c(
  "mrmhub.font_base_size",
  "mrmhub.point_size",
  "mrmhub.legend_position",
  "mrmhub.legend_size",
  "mrmhub.show_legend_title",
  "mrmhub.strip_bg_color"
)
