#' @section Preferred formats and devices:
#'
#' | Purpose | Format | Device used | Typical `dpi` |
#' |---|---|---|---|
#' | Journal figure, vector (default choice) | `"pdf"` | `grDevices::cairo_pdf`, else `grDevices::pdf` | n/a |
#' | Figure for further editing (Illustrator, Inkscape) | `"svg"` | `svglite::svglite`, else `grDevices::svg` | n/a |
#' | Slides, Quarto HTML, GitHub | `"png"` | `ragg::agg_png`, else `grDevices::png` | 150-300 |
#' | Journal requiring raster submission | `"tiff"` | `ragg::agg_tiff`, else `grDevices::tiff` | 300-600 |
#'
#' Prefer a **vector** format (`pdf`, `svg`) for publication: text stays
#' selectable and searchable, and lines stay sharp at any magnification.
#'
#' Prefer a **raster** format (`png`, `tiff`) when a plot draws very many marks
#' -- a [plot_runscatter()] page covering several thousand analyses, or a dense
#' [plot_pca()] score plot. Every point becomes a separate object in a PDF, so
#' such figures produce very large files that are slow to open and to typeset.
#' Saving them at 300-600 dpi instead keeps the file small with no visible loss.
#'
#' The optional packages `ragg` and `svglite` are used automatically when
#' installed, giving better text rendering, system-font support and smaller SVG
#' files. When they are absent the equivalent `grDevices` device is used and the
#' output is still correct. Installing both is recommended:
#' `install.packages(c("ragg", "svglite"))`.
#'
#' PDF output uses the cairo device wherever R was built with cairo support
#' (`capabilities("cairo")`), because plain `grDevices::pdf()` writes text in a
#' single-byte encoding and silently transliterates anything outside it -- an en
#' dash becomes `-`, `>=` replaces the proper symbol. Unit labels such as
#' `umol/L` and statistical annotations routinely depend on those glyphs.
#'
#' Multi-page output from the paged plot functions ([plot_runscatter()],
#' [plot_calibrationcurves()], [plot_responsecurves()],
#' [plot_feature_correlations()]) is PDF only, which is the only format that
#' holds many pages in one file. Use [save_plot()] for single figures in any of
#' the other formats.
