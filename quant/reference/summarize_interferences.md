# Summarize interference relationships

Prints and returns a rollup of the interference relationships defined
for the experiment – automatically derived
([`calc_isotopic_interferences()`](https://slinghub.github.io/MRMhub/quant/reference/calc_isotopic_interferences.md))
and declared (custom) – so they can be reviewed before, and after,
applying a correction. Reports the affected features, a split by source
and overlap type, the contribution-factor range and, once the data are
corrected, the per-feature median impact.

## Usage

``` r
summarize_interferences(data = NULL)
```

## Arguments

- data:

  A `MRMhubExperiment`.

## Value

Invisibly, a tibble of the assembled, de-duplicated interference edges
(with a `pct_impact` column when the data are already corrected). Called
mainly for the printed summary.

## See also

[`calc_isotopic_interferences()`](https://slinghub.github.io/MRMhub/quant/reference/calc_isotopic_interferences.md),
[`correct_isotopic_interferences()`](https://slinghub.github.io/MRMhub/quant/reference/correct_isotopic_interferences.md),
[`correct_custom_interferences()`](https://slinghub.github.io/MRMhub/quant/reference/correct_custom_interferences.md)
