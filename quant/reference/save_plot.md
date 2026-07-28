# Save a plot to a file

Writes a plot created by any of the `plot_*()` functions to a file at a
defined physical size and resolution, so figures do not have to be
exported with hand-written
[`ggplot2::ggsave()`](https://ggplot2.tidyverse.org/reference/ggsave.html)
calls. Dimensions can be given in millimetres, centimetres, inches,
points or pixels, and the same figure can be written in several formats
in one call.

## Usage

``` r
save_plot(
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
)
```

## Arguments

- plot:

  The plot to save. A `ggplot` object (what most `plot_*()` functions
  return), a `patchwork` composition, a list carrying the plot in a
  `plot` element (as
  [`plot_rla_boxplot()`](https://slinghub.github.io/MRMhub/quant/reference/plot_rla_boxplot.md)
  returns), or a list of `ggplot` objects, which is written as a
  multi-page PDF. Lists of plots are returned by the paged plot
  functions with `return_plots = TRUE`.

- path:

  Output file path. The extension selects the format unless `format` is
  given, in which case a known extension is replaced.

- width, height:

  Figure size, in `units`. Both are required: the physical size of a
  saved figure is always explicit at the call site, so it can be read
  off the code rather than inherited from a session setting.

- units:

  Unit of `width` and `height`: `"mm"` (default), `"cm"`, `"in"`, `"pt"`
  or `"px"`. `NULL` uses the global default set by
  [`mrmhub_set_plot_defaults()`](https://slinghub.github.io/MRMhub/quant/reference/mrmhub_set_plot_defaults.md)
  if one is in effect, otherwise `"mm"`.

- dpi:

  Resolution in dots per inch for the raster formats (`png`, `tiff`,
  `jpeg`), and the reference resolution when `units = "px"`. Ignored for
  the vector formats. `NULL` uses the global default set by
  [`mrmhub_set_plot_defaults()`](https://slinghub.github.io/MRMhub/quant/reference/mrmhub_set_plot_defaults.md)
  if one is in effect, otherwise `300`.

- format:

  Output format(s): one or more of `"pdf"`, `"svg"`, `"png"`, `"tiff"`,
  `"jpeg"`. `NULL` (default) takes the format from the extension of
  `path`. Several formats write one file each, sharing the same base
  name.

- scale:

  Multiplicative scaling factor applied to the plot, as in
  [`ggplot2::ggsave()`](https://ggplot2.tidyverse.org/reference/ggsave.html).
  Values `> 1` make text and symbols smaller relative to the figure.

- bg:

  Background colour. `NULL` (default) uses the plot's own background.

- create_dir:

  A logical value. If `TRUE` (the default), the parent directory of
  `path` is created if it does not yet exist.

- overwrite:

  A logical value indicating whether existing files may be overwritten.
  Default is `TRUE`.

- show_plot:

  A logical value. If `TRUE` (the default), the plot is returned
  *visibly*, so that piping into `save_plot()` still renders the figure
  in a Quarto or R Markdown chunk and the call reads as one statement.
  The written paths are then attached as a `"paths"` attribute. If
  `FALSE`, nothing is drawn and the paths are returned invisibly, which
  is preferable in scripts and loops where re-drawing a dense figure is
  wasted work.

- ...:

  Further arguments passed to the graphics device.

## Value

If `show_plot = TRUE`, the plot itself, visibly, with the written paths
in its `"paths"` attribute. If `show_plot = FALSE`, invisibly, a
character vector of the paths written. For multi-page output the list of
plots is returned in place of a single plot.

## Preferred formats and devices

|  |  |  |  |
|----|----|----|----|
| Purpose | Format | Device used | Typical `dpi` |
| Journal figure, vector (default choice) | `"pdf"` | [`grDevices::cairo_pdf`](https://rdrr.io/r/grDevices/cairo.html), else [`grDevices::pdf`](https://rdrr.io/r/grDevices/pdf.html) | n/a |
| Figure for further editing (Illustrator, Inkscape) | `"svg"` | [`svglite::svglite`](https://svglite.r-lib.org/reference/svglite.html), else [`grDevices::svg`](https://rdrr.io/r/grDevices/cairo.html) | n/a |
| Slides, Quarto HTML, GitHub | `"png"` | [`ragg::agg_png`](https://ragg.r-lib.org/reference/agg_png.html), else [`grDevices::png`](https://rdrr.io/r/grDevices/png.html) | 150-300 |
| Journal requiring raster submission | `"tiff"` | [`ragg::agg_tiff`](https://ragg.r-lib.org/reference/agg_tiff.html), else [`grDevices::tiff`](https://rdrr.io/r/grDevices/png.html) | 300-600 |

Prefer a **vector** format (`pdf`, `svg`) for publication: text stays
selectable and searchable, and lines stay sharp at any magnification.

Prefer a **raster** format (`png`, `tiff`) when a plot draws very many
marks – a
[`plot_runscatter()`](https://slinghub.github.io/MRMhub/quant/reference/plot_runscatter.md)
page covering several thousand analyses, or a dense
[`plot_pca()`](https://slinghub.github.io/MRMhub/quant/reference/plot_pca.md)
score plot. Every point becomes a separate object in a PDF, so such
figures produce very large files that are slow to open and to typeset.
Saving them at 300-600 dpi instead keeps the file small with no visible
loss.

The optional packages `ragg` and `svglite` are used automatically when
installed, giving better text rendering, system-font support and smaller
SVG files. When they are absent the equivalent `grDevices` device is
used and the output is still correct. Installing both is recommended:
`install.packages(c("ragg", "svglite"))`.

PDF output uses the cairo device wherever R was built with cairo support
(`capabilities("cairo")`), because plain
[`grDevices::pdf()`](https://rdrr.io/r/grDevices/pdf.html) writes text
in a single-byte encoding and silently transliterates anything outside
it – an en dash becomes `-`, `>=` replaces the proper symbol. Unit
labels such as `umol/L` and statistical annotations routinely depend on
those glyphs.

Multi-page output from the paged plot functions
([`plot_runscatter()`](https://slinghub.github.io/MRMhub/quant/reference/plot_runscatter.md),
[`plot_calibrationcurves()`](https://slinghub.github.io/MRMhub/quant/reference/plot_calibrationcurves.md),
[`plot_responsecurves()`](https://slinghub.github.io/MRMhub/quant/reference/plot_responsecurves.md),
[`plot_feature_correlations()`](https://slinghub.github.io/MRMhub/quant/reference/plot_feature_correlations.md))
is PDF only, which is the only format that holds many pages in one file.
Use `save_plot()` for single figures in any of the other formats.

## See also

[`mrmhub_set_plot_defaults()`](https://slinghub.github.io/MRMhub/quant/reference/mrmhub_set_plot_defaults.md)
to set `units` and `dpi` once for a whole notebook,
[`plot_runscatter()`](https://slinghub.github.io/MRMhub/quant/reference/plot_runscatter.md)
and the other paged plot functions for multi-page PDF output, and
[`save_report_xlsx()`](https://slinghub.github.io/MRMhub/quant/reference/save_report_xlsx.md)
to export the data.

## Examples

``` r
if (FALSE) { # \dontrun{
p <- plot_pca(mexp, variable = "norm_intensity", qc_types = c("BQC", "SPL"))

# A single figure, sized in mm (the default unit)
save_plot(p, "output/pca.pdf", width = 180, height = 120)

# In a notebook: save and show the figure in one statement
plot_pca(mexp, variable = "norm_intensity") |>
  save_plot("output/pca.pdf", width = 180, height = 120)

# The same figure as vector and raster in one call
save_plot(p, "output/pca", format = c("pdf", "png"), width = 180, height = 120)

# In a script or loop, skip the re-draw and collect the paths
paths <- save_plot(p, "output/pca.pdf", width = 180, height = 120,
                   show_plot = FALSE)

# Every runscatter page in one multi-page PDF
pages <- plot_runscatter(mexp, variable = "conc", return_plots = TRUE)
save_plot(pages, "output/runscatter.pdf", width = 280, height = 200,
          show_plot = FALSE)
} # }
```
