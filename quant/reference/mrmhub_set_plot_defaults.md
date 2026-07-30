# Set global default appearance for MRMhub plots

Sets session-wide defaults for the shared appearance arguments of the
`plot_*()` functions, so common choices such as a smaller base font or
point size can be made once at the top of a notebook instead of on every
call. Defaults are stored as `mrmhub.*` options. The precedence for
every argument is: a value passed explicitly to a plotting function
wins, then the global default set here, then the function's built-in
default (including automatic `cols_page`-based sizing on faceted plots).

## Usage

``` r
mrmhub_set_plot_defaults(
  font_base_size = NULL,
  point_size = NULL,
  legend_position = NULL,
  legend_size = NULL,
  show_legend_title = NULL,
  strip_bg_color = NULL,
  units = NULL,
  dpi = NULL
)
```

## Arguments

- font_base_size:

  Base font size in points; all plot text scales from it.

- point_size:

  Point/marker size.

- legend_position:

  Legend placement: a keyword (`"right"`, `"left"`, `"top"`, `"bottom"`,
  `"none"`), a corner (`"inside-tr"`, `"inside-tl"`, `"inside-br"`,
  `"inside-bl"`), or a numeric `c(x, y)`.

- legend_size:

  Scales the whole legend (text, title, key and glyphs); a value `<= 3`
  is a multiplier of `font_base_size`, larger values are points.

- show_legend_title:

  `FALSE` hides legend titles.

- strip_bg_color:

  Facet strip background fill (strip text auto-contrasts).

- units:

  Default unit for the `width` and `height` of
  [`save_plot()`](https://slinghub.github.io/MRMhub/quant/reference/save_plot.md):
  `"mm"` (the built-in default), `"cm"`, `"in"`, `"pt"` or `"px"`.

- dpi:

  Default resolution in dots per inch for the raster formats of
  [`save_plot()`](https://slinghub.github.io/MRMhub/quant/reference/save_plot.md).
  The built-in default is `300`.

## Value

Invisibly, a named list of the option values as they were before this
call (as returned by
[`options()`](https://rdrr.io/r/base/options.html)).

## Details

Only the arguments you supply are changed; the rest are left untouched.
Pass `NULL` (the default) to leave a setting as it is, and use
[`mrmhub_reset_plot_defaults()`](https://slinghub.github.io/MRMhub/quant/reference/mrmhub_reset_plot_defaults.md)
to clear them all. The previous option values are returned invisibly, so
a set can be undone with `options(old)` or scoped to a block with
[`withr::local_options()`](https://withr.r-lib.org/reference/with_options.html).

## See also

[`mrmhub_reset_plot_defaults()`](https://slinghub.github.io/MRMhub/quant/reference/mrmhub_reset_plot_defaults.md),
[`mrmhub_get_plot_defaults()`](https://slinghub.github.io/MRMhub/quant/reference/mrmhub_get_plot_defaults.md),
[`save_plot()`](https://slinghub.github.io/MRMhub/quant/reference/save_plot.md)
and the `vignette("manual-08-visualization")` article.

## Examples

``` r
old <- mrmhub_set_plot_defaults(font_base_size = 8, point_size = 0.8)
# ... make plots with the smaller defaults ...
options(old) # restore
```
