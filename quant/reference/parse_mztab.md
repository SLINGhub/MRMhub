# Parse an mzTab-M file into a long mrmhub table

Internal worker behind
[`import_data_mztab()`](https://slinghub.github.io/MRMhub/quant/reference/import_data_mztab.md).
Reads the `MTD`, `SMF`/`SFH` and `SML`/`SMH` sections of an mzTab-M file
and returns a long tibble (one row per analysis x feature) shaped like
the output of
[`parse_plain_long_csv()`](https://slinghub.github.io/MRMhub/quant/reference/parse_plain_long_csv.md).

## Usage

``` r
parse_mztab(path, silent = FALSE)
```

## Arguments

- path:

  Path to a `.mzTab` file.

- silent:

  Suppress messages.

## Value

A long-format tibble.
