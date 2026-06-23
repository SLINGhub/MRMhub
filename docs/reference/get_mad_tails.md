# Get MAD-based tails

Computes the lower and upper boundaries based on Median Absolute
Deviation (MAD) from a numeric vector. Returns c(NA_real\_, NA_real\_)
if the input vector has less than 2 elements or if no values fall within
the computed fences.

## Usage

``` r
get_mad_tails(x, k, na.rm = FALSE)
```

## Arguments

- x:

  a numeric vector

- k:

  multiplier for the MAD

- na.rm:

  if TRUE then NA values are stripped from x before computation takes
  place.

## Value

a numeric vector of length 2 with the lower and upper boundaries.
