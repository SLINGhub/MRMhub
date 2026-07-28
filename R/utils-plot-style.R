#' Resolve a plot appearance argument against the global defaults
#'
#' Internal helper implementing the precedence used by every appearance
#' argument: an explicit (non-`NULL`) value always wins, then the global option
#' `mrmhub.<name>` (set via `mrmhub_set_plot_defaults()`), then the built-in
#' `default`.
#'
#' @param value The value passed to the plotting function (possibly `NULL`).
#' @param name Option suffix, e.g. `"font_base_size"` for `mrmhub.font_base_size`.
#' @param default Built-in fallback when neither an explicit value nor an option
#'   is set.
#' @return The resolved value.
#' @noRd
resolve_plot_opt <- function(value, name, default = NULL) {
  value %||% getOption(paste0("mrmhub.", name), default)
}

#' Shared refined base theme for `plot_*()` functions
#'
#' Internal helper returning the common mrmhub plot theme layer, applied on top
#' of [ggplot2::theme_bw()]. Encodes the house defaults: faint major gridlines,
#' minor gridlines off, a clear panel border and axis ticks, dark-navy facet
#' strips with white bold text, and a plain left-aligned title. Gridline,
#' border and tick widths thin down for dense multi-column facet pages, keyed on
#' `n_cols` (facet columns per page).
#'
#' Legend placement is intentionally *not* set here -- callers pass a
#' per-function `legend_position` default through `mrmhub_style_layer()`, which
#' is applied last.
#'
#' @param font_base_size Base font size (points); sizes the strip and title text.
#' @param n_cols Facet columns per page, or `NULL` for a single/large panel.
#'   `NULL` or `< 4` uses the large-panel line widths; `>= 4` thins them.
#' @return A [ggplot2::theme()] object.
#' @noRd
mrmhub_base_theme <- function(font_base_size, n_cols = NULL) {
  dense <- !is.null(n_cols) && n_cols >= 4
  grid_lw <- if (is.null(n_cols)) 0.25 else if (dense) 0.20 else 0.30
  border_lw <- if (dense) 0.30 else 0.40
  tick_lw <- if (dense) 0.25 else 0.30
  ggplot2::theme(
    panel.grid.major = ggplot2::element_line(
      linewidth = grid_lw,
      colour = "grey93"
    ),
    panel.grid.minor = ggplot2::element_blank(),
    panel.border = ggplot2::element_rect(
      linewidth = border_lw,
      colour = "grey40"
    ),
    axis.ticks = ggplot2::element_line(linewidth = tick_lw, colour = "grey40"),
    strip.background = ggplot2::element_rect(fill = "#00283d", colour = NA),
    strip.text = ggplot2::element_text(
      colour = "white",
      face = "bold",
      size = font_base_size
    ),
    plot.title = ggplot2::element_text(
      size = font_base_size,
      face = "plain",
      hjust = 0
    )
  )
}

#' Resolve autoscaled font/point sizes for faceted and paginated plots
#'
#' Internal helper for the `plot_*()` functions that lay out facet panels in a
#' grid. When `autoscale = TRUE`, any size left `NULL` is filled from a small
#' lookup keyed on `cols_page` (the main driver of panel size); a value the user
#' passes explicitly always wins. When `autoscale = FALSE`, `NULL`s fall back to
#' the single/large-panel defaults.
#'
#' @param cols_page Facet columns per page.
#' @param font_base_size,point_size User-supplied sizes, or `NULL` to autoscale.
#' @param autoscale Logical; `FALSE` uses the single-plot fallbacks.
#' @return A list with resolved `font_base_size`, `point_size` and `n_cols`.
#' @noRd
mrmhub_autoscale_sizes <- function(
  cols_page,
  font_base_size = NULL,
  point_size = NULL,
  autoscale = TRUE
) {
  # Global defaults (mrmhub_set_plot_defaults()) fill any size left unset before
  # the cols_page autoscale lookup; an explicitly passed value still wins.
  font_base_size <- resolve_plot_opt(font_base_size, "font_base_size")
  point_size <- resolve_plot_opt(point_size, "point_size")
  if (autoscale) {
    lut_font <- if (cols_page <= 2) {
      9
    } else if (cols_page == 3) {
      7
    } else if (cols_page <= 5) {
      6
    } else {
      5
    }
    lut_point <- if (cols_page <= 2) {
      1.0
    } else if (cols_page == 3) {
      0.7
    } else if (cols_page <= 5) {
      0.5
    } else {
      0.4
    }
  } else {
    lut_font <- 11
    lut_point <- 1.5
  }
  list(
    font_base_size = if (is.null(font_base_size)) lut_font else font_base_size,
    point_size = if (is.null(point_size)) lut_point else point_size,
    n_cols = cols_page
  )
}

#' Build an additive legend/text style layer for `plot_*()` functions
#'
#' Internal helper shared by the `plot_*()` functions. It returns a list of
#' ggplot layers (a [ggplot2::theme()] and/or a [ggplot2::guides()] object)
#' assembled *only* from the arguments that were supplied (non-`NULL`), or
#' `NULL` when nothing was supplied. Appending it with
#' `p <- p + mrmhub_style_layer(...)` therefore leaves an otherwise-unchanged
#' plot when every argument is `NULL` (`p + NULL` is a no-op in ggplot2).
#'
#' Size arguments (`legend_size`, `strip_text_size`) are interpreted as a
#' multiplier of `font_base_size` when `<= 3`, otherwise as an absolute point
#' size.
#'
#' @param font_base_size Reference base font size (points) used to interpret
#'   the size multipliers. Callers pass their own `font_base_size`.
#' @param legend_position Legend placement: one of `"right"`, `"left"`,
#'   `"top"`, `"bottom"`, `"none"`; a corner keyword `"inside-tr"`,
#'   `"inside-tl"`, `"inside-br"`, `"inside-bl"`; or a numeric `c(x, y)` in
#'   `[0, 1]` npc coordinates.
#' @param legend_size Single multiplier of `font_base_size` (`<= 3`) or an
#'   absolute point size (`> 3`) that scales the whole legend: text, title,
#'   key size, and the plotted symbols/glyphs (via `override.aes`).
#' @param strip_text_size Facet strip text size, as a multiplier of
#'   `font_base_size` (`<= 3`) or an absolute point size (`> 3`).
#' @param strip_bg_color Facet strip background fill colour. The strip text
#'   colour is set automatically for contrast: white on a dark background,
#'   black on a light one.
#' @param show_legend_title `FALSE` blanks the legend title.
#' @param title Plot title: `NULL` (default) leaves the plot's own title (none),
#'   `NA` blanks it, a string sets it.
#' @param legend_bg_alpha Opacity (`[0, 1]`) of a white legend background box,
#'   for a readable inside legend drawn over points.
#' @param aspect_ratio Panel aspect ratio (height/width); `NULL` leaves it free.
#' @param legend_aes Aesthetics whose legend guide is set when `legend_size` is
#'   set. Defaults to `"colour"`. Only the first aesthetic carries the glyph-size
#'   `override.aes`; that alone resizes the shared key of a merged
#'   colour/shape/fill legend, so passing several aesthetics never emits ggplot's
#'   "Duplicated `override.aes`" warning. Lead with the aesthetic that drives the
#'   legend if it is not `colour`.
#'
#' @return A list of ggplot layers, or `NULL` if no argument was supplied.
#' @noRd
mrmhub_style_layer <- function(
  font_base_size = NULL,
  legend_position = NULL,
  legend_size = NULL,
  strip_text_size = NULL,
  strip_bg_color = NULL,
  show_legend_title = NULL,
  title = NULL,
  legend_bg_alpha = NULL,
  aspect_ratio = NULL,
  legend_aes = "colour"
) {
  # Fill any argument left unset from the global defaults set by
  # mrmhub_set_plot_defaults(); an explicit value passed by the caller wins.
  # (font_base_size arrives already resolved from the plotting function, so this
  # is a harmless no-op for it in the normal path.)
  font_base_size <- resolve_plot_opt(font_base_size, "font_base_size")
  legend_position <- resolve_plot_opt(legend_position, "legend_position")
  legend_size <- resolve_plot_opt(legend_size, "legend_size")
  show_legend_title <- resolve_plot_opt(show_legend_title, "show_legend_title")
  strip_bg_color <- resolve_plot_opt(strip_bg_color, "strip_bg_color")

  ref <- if (is.null(font_base_size)) 8 else font_base_size
  # A size <= 3 is treated as a multiplier of the base font size, larger
  # values as absolute points -- matches the convention used in the workflows.
  resolve_size <- function(x) if (x <= 3) x * ref else x

  theme_args <- list()
  layers <- list()

  if (!is.null(legend_position)) {
    if (is.numeric(legend_position)) {
      theme_args$legend.position <- "inside"
      theme_args$legend.position.inside <- legend_position
    } else if (
      legend_position %in% c("inside-tr", "inside-tl", "inside-br", "inside-bl")
    ) {
      corner <- switch(
        legend_position,
        "inside-tr" = list(pos = c(0.98, 0.98), just = c(1, 1)),
        "inside-tl" = list(pos = c(0.02, 0.98), just = c(0, 1)),
        "inside-br" = list(pos = c(0.98, 0.02), just = c(1, 0)),
        "inside-bl" = list(pos = c(0.02, 0.02), just = c(0, 0))
      )
      theme_args$legend.position <- "inside"
      theme_args$legend.position.inside <- corner$pos
      theme_args$legend.justification.inside <- corner$just
    } else {
      rlang::arg_match0(
        legend_position,
        c("right", "left", "top", "bottom", "none")
      )
      theme_args$legend.position <- legend_position
    }
  }

  if (!is.null(legend_size)) {
    sz <- resolve_size(legend_size)
    theme_args$legend.text <- ggplot2::element_text(size = sz)
    theme_args$legend.title <- ggplot2::element_text(size = sz)
    theme_args$legend.key.size <- ggplot2::unit(sz, "pt")
    # legend.key.size alone does not resize the drawn point/line -- the glyph
    # must be overridden on each mapped aesthetic. Convert the point size (pt)
    # to ggplot's mm-based `size`/`linewidth` scale so the glyph tracks the text.
    glyph <- sz / ggplot2::.pt
    # A merged legend (colour+fill+shape all mapped to one variable) needs only
    # one `override.aes` to resize its shared key; a second one on the same key
    # triggers ggplot's "Duplicated `override.aes`" warning. So carry the
    # override on the first aesthetic only -- any extra `legend_aes` get a plain
    # guide, which still merges but adds no duplicate override.
    overrides <- stats::setNames(
      lapply(seq_along(legend_aes), function(i) {
        if (i == 1L) {
          ggplot2::guide_legend(
            override.aes = list(size = glyph, linewidth = glyph)
          )
        } else {
          ggplot2::guide_legend()
        }
      }),
      legend_aes
    )
    layers <- c(layers, list(do.call(ggplot2::guides, overrides)))
  }

  strip_text_args <- list()
  if (!is.null(strip_text_size)) {
    strip_text_args$size <- resolve_size(strip_text_size)
  }
  if (!is.null(strip_bg_color)) {
    theme_args$strip.background <- ggplot2::element_rect(
      fill = strip_bg_color,
      colour = NA
    )
    # Pick a legible text colour: white on a dark fill, black on a light one
    # (perceived luminance, 0-255 scale).
    rgb <- grDevices::col2rgb(strip_bg_color)[, 1]
    lum <- 0.299 * rgb[[1]] + 0.587 * rgb[[2]] + 0.114 * rgb[[3]]
    strip_text_args$colour <- if (lum < 140) "white" else "black"
  }
  if (length(strip_text_args) > 0) {
    theme_args$strip.text <- do.call(ggplot2::element_text, strip_text_args)
  }

  # Placed after legend_size so an explicit FALSE wins over the sized title.
  if (isFALSE(show_legend_title)) {
    theme_args$legend.title <- ggplot2::element_blank()
  }

  # `title`: NULL leaves the plot's own title (none, for these plots); NA blanks
  # it explicitly; a string sets it.
  if (!is.null(title)) {
    if (length(title) == 1 && is.na(title)) {
      theme_args$plot.title <- ggplot2::element_blank()
    } else {
      layers <- c(layers, list(ggplot2::ggtitle(title)))
    }
  }

  if (!is.null(aspect_ratio)) {
    theme_args$aspect.ratio <- aspect_ratio
  }

  if (!is.null(legend_bg_alpha)) {
    theme_args$legend.background <- ggplot2::element_rect(
      fill = scales::alpha("white", legend_bg_alpha),
      colour = NA
    )
  }

  if (length(theme_args) > 0) {
    layers <- c(list(do.call(ggplot2::theme, theme_args)), layers)
  }

  if (length(layers) == 0) {
    return(NULL)
  }
  layers
}

#' Resolve the PDF page size of the paged `plot_*()` functions
#'
#' Internal helper turning the `page_width`/`page_height`/`page_units` arguments
#' of the paged plot functions into the `width`, `height` and `paper` arguments
#' of [grDevices::pdf()]. When both dimensions are `NULL` the historical A4
#' defaults are used (280 x 200 mm, keyed on `page_orientation`) together with
#' the matching `paper` keyword, so output is unchanged. When a custom size is
#' given, `paper` must be `"special"` -- a `paper` keyword otherwise overrides
#' `width` and `height` in [grDevices::pdf()].
#'
#' @param page_width,page_height Page size in `page_units`, or `NULL` for the
#'   A4 default. Both must be supplied together.
#' @param page_units Unit of `page_width`/`page_height`: `"mm"` (default),
#'   `"cm"`, `"in"` or `"pt"`.
#' @param page_orientation `"LANDSCAPE"` or `"PORTRAIT"`; used only when the
#'   default page size applies.
#' @return A list with `width` and `height` in inches, and `paper`.
#' @noRd
resolve_page_size <- function(
  page_width = NULL,
  page_height = NULL,
  page_units = "mm",
  page_orientation = "LANDSCAPE"
) {
  if (is.null(page_width) != is.null(page_height)) {
    cli::cli_abort(
      "{.arg page_width} and {.arg page_height} must both be given, or both be {.code NULL}."
    )
  }

  if (is.null(page_width)) {
    landscape <- identical(page_orientation, "LANDSCAPE")
    return(list(
      width = if (landscape) 28 / 2.54 else 20 / 2.54,
      height = if (landscape) 20 / 2.54 else 28 / 2.54,
      paper = if (landscape) "A4r" else "A4"
    ))
  }

  page_units <- rlang::arg_match(page_units, c("mm", "cm", "in", "pt"))
  list(
    width = convert_to_inches(page_width, page_units, dpi = NA, arg = "page_width"),
    height = convert_to_inches(page_height, page_units, dpi = NA, arg = "page_height"),
    paper = "special"
  )
}
