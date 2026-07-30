# Formats `save_plot()` can write, and the device used for each. The `preferred`
# package is used when installed, otherwise the base grDevices device is used.
mrmhub_plot_formats <- c("pdf", "svg", "png", "tiff", "jpeg")

# Extensions accepted on `path` and the format they map to.
mrmhub_plot_format_aliases <- c(
  pdf = "pdf",
  svg = "svg",
  png = "png",
  tif = "tiff",
  tiff = "tiff",
  jpg = "jpeg",
  jpeg = "jpeg"
)

# Conversion factors to inches. "px" depends on `dpi` and is handled separately.
mrmhub_unit_to_inch <- c(
  "in" = 1,
  cm = 1 / 2.54,
  mm = 1 / 25.4,
  pt = 1 / 72
)

#' Convert a plot dimension to inches
#'
#' @param value Numeric dimension.
#' @param units One of `"mm"`, `"cm"`, `"in"`, `"pt"`, `"px"`.
#' @param dpi Resolution, used only when `units = "px"`.
#' @param arg Argument name used in error messages.
#' @return The dimension in inches.
#' @noRd
convert_to_inches <- function(value, units, dpi, arg = "width") {
  if (!is.numeric(value) || length(value) != 1L || is.na(value) || value <= 0) {
    cli::cli_abort(
      "{.arg {arg}} must be a single positive number, not {.obj_type_friendly {value}}."
    )
  }
  if (identical(units, "px")) {
    return(value / dpi)
  }
  value * mrmhub_unit_to_inch[[units]]
}

#' Resolve the output formats and file paths for `save_plot()`
#'
#' Determines which formats to write and the file path for each. With
#' `format = NULL` the format comes from the extension of `path`. With an
#' explicit `format`, a known extension is stripped from `path` first and one
#' path per format is returned.
#'
#' @param path File path, with or without extension.
#' @param format Character vector of formats, or `NULL` to infer from `path`.
#' @return A named character vector of paths, names being the formats.
#' @noRd
resolve_plot_formats <- function(path, format = NULL) {
  if (
    !is.character(path) || length(path) != 1L || is.na(path) || !nzchar(path)
  ) {
    cli::cli_abort("{.arg path} must be a single non-empty file path.")
  }

  ext <- tolower(tools::file_ext(path))
  known_ext <- nzchar(ext) && ext %in% names(mrmhub_plot_format_aliases)

  if (is.null(format)) {
    if (!known_ext) {
      cli::cli_abort(c(
        "Cannot determine the output format from {.path {path}}.",
        "i" = "Use a supported file extension ({.val {names(mrmhub_plot_format_aliases)}}) or set {.arg format}."
      ))
    }
    fmts <- unname(mrmhub_plot_format_aliases[[ext]])
    return(stats::setNames(path, fmts))
  }

  format <- tolower(as.character(format))
  unknown <- setdiff(
    format,
    c(mrmhub_plot_formats, names(mrmhub_plot_format_aliases))
  )
  if (length(unknown) > 0) {
    cli::cli_abort(c(
      "Unsupported {.arg format}: {.val {unknown}}.",
      "i" = "Supported formats are {.val {mrmhub_plot_formats}}."
    ))
  }
  fmts <- unname(mrmhub_plot_format_aliases[format])
  fmts <- unique(fmts)

  stem <- if (known_ext) tools::file_path_sans_ext(path) else path
  stats::setNames(paste0(stem, ".", fmts), fmts)
}

# Whether the cairo PDF device can actually be opened here. `capabilities("cairo")`
# only reports that R was *built* with cairo, not that the device loads: on macOS
# the cairo DLL links against XQuartz's libXrender, so without XQuartz
# `capabilities()` is TRUE yet `cairo_pdf()` fails to load, opens no device and
# writes no file. Probe the device once and cache the result.
cairo_pdf_usable <- local({
  cached <- NULL
  function() {
    if (!is.null(cached)) {
      return(cached)
    }
    ok <- isTRUE(capabilities("cairo")) &&
      tryCatch(
        {
          tmp <- tempfile(fileext = ".pdf")
          on.exit(unlink(tmp), add = TRUE)
          before <- grDevices::dev.cur()
          suppressWarnings(grDevices::cairo_pdf(filename = tmp))
          opened <- !identical(grDevices::dev.cur(), before)
          if (opened) {
            grDevices::dev.off()
          }
          opened && file.exists(tmp) && file.size(tmp) > 0
        },
        error = function(e) FALSE
      )
    cached <<- ok
    ok
  }
})

#' Select the graphics device function for a format
#'
#' Prefers `ragg` (raster formats), `svglite` (SVG) and the cairo PDF device
#' when available, falling back to the equivalent plain `grDevices` device.
#'
#' @param format One of `mrmhub_plot_formats`.
#' @return A function suitable for the `device` argument of [ggplot2::ggsave()].
#' @noRd
resolve_plot_device <- function(format) {
  has <- function(pkg) requireNamespace(pkg, quietly = TRUE)

  switch(
    format,
    # `grDevices::pdf()` writes text in a single-byte encoding and silently
    # transliterates anything outside it -- an en dash becomes "-", a "greater
    # than or equal" sign becomes ">=". Unit labels such as "umol/L" and
    # statistical annotations routinely carry such characters, so the cairo
    # device is preferred wherever it can actually be opened.
    pdf = if (cairo_pdf_usable()) {
      function(filename, ...) {
        grDevices::cairo_pdf(filename = filename, ...)
      }
    } else {
      function(filename, ...) {
        grDevices::pdf(file = filename, ..., useDingbats = FALSE)
      }
    },
    svg = if (has("svglite")) {
      getExportedValue("svglite", "svglite")
    } else {
      function(filename, width, height, ...) {
        grDevices::svg(filename = filename, width = width, height = height)
      }
    },
    png = if (has("ragg")) {
      getExportedValue("ragg", "agg_png")
    } else {
      function(filename, width, height, res, ...) {
        grDevices::png(
          filename = filename,
          width = width,
          height = height,
          res = res,
          units = "in"
        )
      }
    },
    tiff = if (has("ragg")) {
      # `agg_tiff()` writes uncompressed TIFF by default, which at 600 dpi runs
      # to tens of MB. LZW is lossless and universally readable. The wrapper
      # keeps `agg_tiff()`'s formals, which `ggplot2::ggsave()` inspects to
      # decide which arguments to pass on.
      agg_tiff <- getExportedValue("ragg", "agg_tiff")
      wrapper <- function() {
        formals(agg_tiff)$compression <- "lzw"
        agg_tiff
      }
      wrapper()
    } else {
      function(filename, width, height, res, ...) {
        grDevices::tiff(
          filename = filename,
          width = width,
          height = height,
          res = res,
          units = "in",
          compression = "lzw"
        )
      }
    },
    jpeg = if (has("ragg")) {
      getExportedValue("ragg", "agg_jpeg")
    } else {
      function(filename, width, height, res, ...) {
        grDevices::jpeg(
          filename = filename,
          width = width,
          height = height,
          res = res,
          units = "in",
          quality = 95
        )
      }
    },
    cli::cli_abort("Unsupported format {.val {format}}.")
  )
}

#' Extract the plot object(s) to be drawn
#'
#' Accepts the shapes the `plot_*()` functions return: a `ggplot`, a `patchwork`,
#' a list carrying the plot in a `plot` element (as [plot_rla_boxplot()] returns),
#' or a list of `ggplot` objects (as `return_plots = TRUE` returns).
#'
#' @param plot The object passed to [save_plot()].
#' @return A list with `plots` (a list of ggplots) and `multipage` (logical).
#' @noRd
as_plot_list <- function(plot) {
  # `inherits()` rather than `ggplot2::is_ggplot()`: it holds for ggplot and
  # patchwork objects alike and works across the supported ggplot2 versions.
  is_gg <- function(x) inherits(x, "ggplot")

  if (is_gg(plot)) {
    return(list(plots = list(plot), multipage = FALSE))
  }
  if (is.list(plot)) {
    # A results list carrying the plot alongside tables, e.g. plot_rla_boxplot()
    if (!is.null(plot[["plot"]]) && is_gg(plot[["plot"]])) {
      return(list(plots = list(plot[["plot"]]), multipage = FALSE))
    }
    if (length(plot) > 0 && all(vapply(plot, is_gg, logical(1)))) {
      return(list(
        plots = unname(plot),
        multipage = length(plot) > 1
      ))
    }
  }
  cli::cli_abort(c(
    "{.arg plot} must be a {.cls ggplot} object, or a list of them.",
    "x" = "Got {.obj_type_friendly {plot}}.",
    "i" = "Plot functions returning several pages need {.code return_plots = TRUE}."
  ))
}

#' Save a plot to a file
#'
#' Writes a plot created by any of the `plot_*()` functions to a file at a
#' defined physical size and resolution, so figures do not have to be exported
#' with hand-written [ggplot2::ggsave()] calls. Dimensions can be given in
#' millimetres, centimetres, inches, points or pixels, and the same figure can be
#' written in several formats in one call.
#'
#' @param plot The plot to save. A `ggplot` object (what most `plot_*()`
#'   functions return), a `patchwork` composition, a list carrying the plot in a
#'   `plot` element (as [plot_rla_boxplot()] returns), or a list of `ggplot`
#'   objects, which is written as a multi-page PDF. Lists of plots are returned
#'   by the paged plot functions with `return_plots = TRUE`.
#' @param path Output file path. The extension selects the format unless
#'   `format` is given, in which case a known extension is replaced.
#' @param format Output format(s): one or more of `"pdf"`, `"svg"`, `"png"`,
#'   `"tiff"`, `"jpeg"`. `NULL` (default) takes the format from the extension of
#'   `path`. Several formats write one file each, sharing the same base name.
#' @param scale Multiplicative scaling factor applied to the plot, as in
#'   [ggplot2::ggsave()]. Values `> 1` make text and symbols smaller relative to
#'   the figure.
#' @param bg Background colour. `NULL` (default) uses the plot's own background.
#' @param create_dir A logical value. If `TRUE` (the default), the parent
#'   directory of `path` is created if it does not yet exist.
#' @param overwrite A logical value indicating whether existing files may be
#'   overwritten. Default is `TRUE`.
#' @param show_plot A logical value. If `TRUE` (the default), the plot is
#'   returned *visibly*, so that piping into `save_plot()` still renders the
#'   figure in a Quarto or R Markdown chunk and the call reads as one statement.
#'   The written paths are then attached as a `"paths"` attribute. If `FALSE`,
#'   nothing is drawn and the paths are returned invisibly, which is preferable
#'   in scripts and loops where re-drawing a dense figure is wasted work.
#' @param ... Further arguments passed to the graphics device.
#'
#' @template save_dimensions
#' @template plot_devices
#'
#' @return If `show_plot = TRUE`, the plot itself, visibly, with the written
#'   paths in its `"paths"` attribute. If `show_plot = FALSE`, invisibly, a
#'   character vector of the paths written. For multi-page output the list of
#'   plots is returned in place of a single plot.
#'
#' @seealso [mrmhub_set_plot_defaults()] to set `units` and `dpi` once for a
#'   whole notebook, [plot_runscatter()] and the other paged plot functions for
#'   multi-page PDF output, and [save_report_xlsx()] to export the data.
#'
#' @examples
#' \dontrun{
#' p <- plot_pca(mexp, variable = "norm_intensity", qc_types = c("BQC", "SPL"))
#'
#' # A single figure, sized in mm (the default unit)
#' save_plot(p, "output/pca.pdf", width = 180, height = 120)
#'
#' # In a notebook: save and show the figure in one statement
#' plot_pca(mexp, variable = "norm_intensity") |>
#'   save_plot("output/pca.pdf", width = 180, height = 120)
#'
#' # The same figure as vector and raster in one call
#' save_plot(p, "output/pca", format = c("pdf", "png"), width = 180, height = 120)
#'
#' # In a script or loop, skip the re-draw and collect the paths
#' paths <- save_plot(p, "output/pca.pdf", width = 180, height = 120,
#'                    show_plot = FALSE)
#'
#' # Every runscatter page in one multi-page PDF
#' pages <- plot_runscatter(mexp, variable = "conc", return_plots = TRUE)
#' save_plot(pages, "output/runscatter.pdf", width = 280, height = 200,
#'           show_plot = FALSE)
#' }
#'
#' @export
save_plot <- function(
  plot,
  path,
  width,
  height,
  units = NULL,
  dpi = NULL,
  format = NULL,
  scale = 1,
  bg = NULL,
  create_dir = TRUE,
  overwrite = TRUE,
  show_plot = TRUE,
  ...
) {
  if (missing(width) || missing(height)) {
    cli::cli_abort(c(
      "{.arg width} and {.arg height} must both be given.",
      "i" = "Sizes are always explicit so that a figure's dimensions are readable at the call site."
    ))
  }

  units <- resolve_plot_opt(units, "units", "mm")
  dpi <- resolve_plot_opt(dpi, "dpi", 300)

  units <- rlang::arg_match(units, c("mm", "cm", "in", "pt", "px"))
  if (!is.numeric(dpi) || length(dpi) != 1L || is.na(dpi) || dpi <= 0) {
    cli::cli_abort("{.arg dpi} must be a single positive number.")
  }

  width_in <- convert_to_inches(width, units, dpi, arg = "width")
  height_in <- convert_to_inches(height, units, dpi, arg = "height")

  parsed <- as_plot_list(plot)
  targets <- resolve_plot_formats(path, format)

  if (parsed$multipage && !all(names(targets) == "pdf")) {
    cli::cli_abort(c(
      "Multi-page output is only supported for {.val pdf}.",
      "x" = "Requested format{?s}: {.val {names(targets)}}.",
      "i" = "Save the pages individually for other formats."
    ))
  }

  for (target in targets) {
    ensure_output_dir(target, create_dir)
    if (!overwrite && file.exists(target)) {
      cli::cli_abort(c(
        "{.path {target}} already exists.",
        "i" = "Use {.code overwrite = TRUE} to replace it."
      ))
    }
  }

  for (fmt in names(targets)) {
    target <- targets[[fmt]]
    if (parsed$multipage) {
      write_multipage_pdf(
        parsed$plots,
        target,
        width_in = width_in,
        height_in = height_in,
        bg = bg,
        ...
      )
    } else {
      ggplot2::ggsave(
        filename = target,
        plot = parsed$plots[[1]],
        device = resolve_plot_device(fmt),
        width = width_in,
        height = height_in,
        units = "in",
        dpi = dpi,
        scale = scale,
        bg = bg,
        ...
      )
    }
  }

  cli::cli_alert_success(
    "Saved plot ({width} x {height} {units}) to {.path {paste(targets, collapse = ', ')}}"
  )

  paths <- unname(targets)

  if (!isTRUE(show_plot)) {
    return(invisible(paths))
  }

  # Returned visibly so that `plot_*() |> save_plot()` still renders the figure
  # in a knitr chunk. The paths ride along as an attribute rather than being
  # lost.
  out <- if (parsed$multipage) parsed$plots else parsed$plots[[1]]
  attr(out, "paths") <- paths
  out
}

#' Write a list of plots as a multi-page PDF
#'
#' @param plots A list of `ggplot` objects, one per page.
#' @param path Output file path.
#' @param width_in,height_in Page size in inches.
#' @param bg Background colour, or `NULL`.
#' @param ... Further arguments passed to the PDF device.
#' @return Invisibly, `path`.
#' @noRd
write_multipage_pdf <- function(
  plots,
  path,
  width_in,
  height_in,
  bg = NULL,
  ...
) {
  # Same reasoning as the single-page PDF device in `resolve_plot_device()`:
  # cairo preserves non-ASCII text, which `grDevices::pdf()` transliterates.
  if (cairo_pdf_usable()) {
    args <- list(
      filename = path,
      onefile = TRUE,
      width = width_in,
      height = height_in,
      ...
    )
    if (!is.null(bg)) args$bg <- bg
    do.call(grDevices::cairo_pdf, args)
  } else {
    args <- list(
      file = path,
      onefile = TRUE,
      paper = "special",
      useDingbats = FALSE,
      width = width_in,
      height = height_in,
      ...
    )
    if (!is.null(bg)) args$bg <- bg
    do.call(grDevices::pdf, args)
  }

  on.exit(grDevices::dev.off(), add = TRUE)
  for (p in plots) print(p)
  invisible(path)
}
