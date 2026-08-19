# Enable coloured mrmhub console output in notebooks

mrmhub's console feedback is coloured with cli. In an interactive
session this works out of the box, but in a non-interactive render
(Quarto or R Markdown) cli suppresses colour by default, and its alerts
travel on the *message* stream, which knitr does not colour-convert.
Call this once in a setup chunk to (1) advertise colour support to cli
via `cli.num_colors` / `crayon.enabled` and (2), when rendering to HTML,
register a knitr message hook that converts the emitted ANSI sequences
to coloured HTML using the fansi package. For PDF and Word the same hook
strips the ANSI so messages stay clean plain text.

## Usage

``` r
mrmhub_enable_cli_color(num_colors = 256L)
```

## Arguments

- num_colors:

  Number of colours to advertise to cli. Defaults to `256`.

## Value

Invisibly, the previous values of the options it changed (as returned by
[`options()`](https://rdrr.io/r/base/options.html)), so the caller can
restore them.

## Examples

``` r
if (FALSE) { # \dontrun{
# In a Quarto / R Markdown setup chunk:
mrmhub_enable_cli_color()
} # }
```
