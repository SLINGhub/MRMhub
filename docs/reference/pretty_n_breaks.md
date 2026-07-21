# Panel-size-aware tick count

More facets per page -\> fewer ticks per panel, so faceted plots don't
crowd or blank. Floored at 3 to keep the "\>=3 non-empty labels"
guarantee.

## Usage

``` r
pretty_n_breaks(n_panels = 1L)
```

## Arguments

- n_panels:

  Number of panels on the page (`rows_page * cols_page`).
