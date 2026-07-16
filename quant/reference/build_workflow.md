# Launch the MRMhub Workflow Builder

Opens an interactive Shiny application that helps you turn your data and
metadata files into a runnable Quarto (`.qmd`) mrmhub workflow. Point
the app at your files, tick the processing steps you need, and the app
validates the inputs against each step (warning, for example, when
`normalize_by_istd` is selected but no `istd_feature_id` is defined)
while previewing the generated workflow document for download.

## Usage

``` r
build_workflow()
```

## Value

Invisible `NULL`. Launches the Shiny app in the default browser.

## See also

[`generate_workflow_qmd()`](https://slinghub.github.io/MRMhub/quant/reference/generate_workflow_qmd.md)
for the non-interactive generator.

## Examples

``` r
if (interactive()) {
  build_workflow()
}
```
