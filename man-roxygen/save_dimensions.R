#' @param width,height Figure size, in `units`. Both are required: the physical
#'   size of a saved figure is always explicit at the call site, so it can be
#'   read off the code rather than inherited from a session setting.
#' @param units Unit of `width` and `height`: `"mm"` (default), `"cm"`, `"in"`,
#'   `"pt"` or `"px"`. `NULL` uses the global default set by
#'   [mrmhub_set_plot_defaults()] if one is in effect, otherwise `"mm"`.
#' @param dpi Resolution in dots per inch for the raster formats (`png`, `tiff`,
#'   `jpeg`), and the reference resolution when `units = "px"`. Ignored for the
#'   vector formats. `NULL` uses the global default set by
#'   [mrmhub_set_plot_defaults()] if one is in effect, otherwise `300`.
