# Clear the global MRMhub plot defaults

Removes all `mrmhub.*` plot-appearance options set by
[`mrmhub_set_plot_defaults()`](https://slinghub.github.io/MRMhub/quant/reference/mrmhub_set_plot_defaults.md),
restoring the built-in per-function defaults.

## Usage

``` r
mrmhub_reset_plot_defaults()
```

## Value

Invisibly, the previous option values (as returned by
[`options()`](https://rdrr.io/r/base/options.html)).

## See also

[`mrmhub_set_plot_defaults()`](https://slinghub.github.io/MRMhub/quant/reference/mrmhub_set_plot_defaults.md)

## Examples

``` r
mrmhub_set_plot_defaults(font_base_size = 8)
mrmhub_reset_plot_defaults()
```
