# Pretty continuous x/y scale

Returns a ggplot2 scale (composable with `+` or
[`ggh4x::facetted_pos_scales`](https://teunbrand.github.io/ggh4x/reference/facetted_pos_scales.html))
with panel-aware break counts, adaptive labels (`.pretty_labels()`:
plain numbers, superscript scientific only for extreme magnitudes), and
minor ticks. Log axes use decade breaks; add
[`pretty_logticks()`](https://slinghub.github.io/MRMhub/quant/reference/pretty_logticks.md)
for the log tick marks. `expand` is passed straight through so callers
keep their tuned axis expansion.

## Usage

``` r
scale_pretty_x(
  log = FALSE,
  n = 5L,
  limits = NULL,
  expand = ggplot2::waiver(),
  name = ggplot2::waiver(),
  minor_ticks = TRUE
)

scale_pretty_y(
  log = FALSE,
  n = 5L,
  limits = NULL,
  expand = ggplot2::waiver(),
  name = ggplot2::waiver(),
  minor_ticks = TRUE
)
```

## Arguments

- log:

  Log10 axis if `TRUE`, else linear.

- n:

  Target number of breaks (see
  [`pretty_n_breaks()`](https://slinghub.github.io/MRMhub/quant/reference/pretty_n_breaks.md)).

- limits, expand, name:

  Passed to the underlying scale unchanged.

- minor_ticks:

  Add minor tick marks on linear axes.
