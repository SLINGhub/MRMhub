# Print method for validation-report tibbles

Replaces the standard tibble header (`# A tibble: N x M`) with a black
divider line, hides the column-type chip row (`<chr> <int> ...`), and
adds an italic legend explaining the E / W / W\* / N severity codes used
by
[`assert_metadata()`](https://slinghub.github.io/MRMhub/quant/reference/assert_metadata.md).
Implemented with `cli` only (no pillar dependency).

## Usage

``` r
# S3 method for class 'assertr_tibble'
print(x, n = NULL, width = NULL, ...)
```

## Arguments

- x:

  An `assertr_tibble`.

- n, width:

  Forwarded to the underlying tibble print method.

- ...:

  Forwarded.
