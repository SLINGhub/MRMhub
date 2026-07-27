# Report the global MRMhub plot defaults

Returns the currently set `mrmhub.*` plot-appearance options as a named
list. Options that are not set are omitted.

## Usage

``` r
mrmhub_get_plot_defaults()
```

## Value

A named list of the active plot defaults (empty if none are set).

## See also

[`mrmhub_set_plot_defaults()`](https://slinghub.github.io/MRMhub/quant/reference/mrmhub_set_plot_defaults.md)

## Examples

``` r
mrmhub_set_plot_defaults(font_base_size = 8)
mrmhub_get_plot_defaults()
#> $font_base_size
#> [1] 8
#> 
mrmhub_reset_plot_defaults()
```
