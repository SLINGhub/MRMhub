# Styled log-tick marks for a log axis

`ggh4x` (0.3.1) has no `guide_axis_logticks`, so log tick marks use
[`ggplot2::annotation_logticks()`](https://ggplot2.tidyverse.org/reference/annotation_logticks.html)
as in `plot_abundanceprofile`. Add once per plot when the log scale is
global.

## Usage

``` r
pretty_logticks(sides = "bl")
```

## Arguments

- sides:

  Which axes carry the ticks, e.g. `"b"`, `"l"`, `"bl"`.
