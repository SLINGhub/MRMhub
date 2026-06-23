# Launch the MRMhub Walkthrough App

Opens an interactive Shiny application that helps new users validate
their data format, generate workflow code, and explore results.

## Usage

``` r
run_walkthrough()
```

## Value

Invisible NULL. Launches the Shiny app in the default browser.

## Examples

``` r
if (interactive()) {
  run_walkthrough()
}
```
