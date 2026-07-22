# Valid MRM-pattern labels

The labels a feature's `mrm_pattern` may take, optionally for one
product-ion origin. Single source of truth shared by metadata validation
and the Excel template dropdown (so they cannot drift).

## Usage

``` r
licar_pattern_choices(origin = NULL)
```

## Arguments

- origin:

  Optional origin filter (`"Head Group"`, `"FA"`, `"LCB"`, `"Neutral"`,
  `"RPLC"`).

## Value

A character vector of labels.
