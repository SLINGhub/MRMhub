# Access slots of a `MRMhubExperiment` object via \$ syntax

\$ syntax can be used to as a shortcut for getting specific variables
and results from a `MRMhubExperiment` object

## Usage

``` r
# S4 method for class 'MRMhubExperiment'
x$name
```

## Arguments

- x:

  [`MRMhubExperiment`](https://slinghub.github.io/MRMhub/quant/reference/MRMhubExperiment-class.md)
  object

- name:

  [`MRMhubExperiment`](https://slinghub.github.io/MRMhub/quant/reference/MRMhubExperiment-class.md)
  slot

## Value

Value with a variable or a tibble

## Examples

``` r
mexp <- MRMhubExperiment(title = "Test Experiment", analysis_type = "lipidomics")
mexp$analysis_type
#> [1] "lipidomics"
mexp$title
#> [1] "Test Experiment"
mexp$annot_analyses
#> # A tibble: 0 × 13
#> # ℹ 13 variables: analysis_order <int>, analysis_id <chr>, sample_id <chr>,
#> #   qc_type <fct>, batch_id <chr>, replicate_no <int>, specimen <chr>,
#> #   sample_amount <dbl>, sample_amount_unit <chr>, istd_volume <dbl>,
#> #   valid_analysis <lgl>, annot_order_num <int>, remarks <chr>
```
