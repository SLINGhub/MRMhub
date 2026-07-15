# Get Tukey's IQR fences

Computes the lower and upper boundaries based on Tukey's Interquartile
Range (IQR) fences from a numeric vector.

## Usage

``` r
get_iqr_tails(x, k = 1.5, na.rm = FALSE)
```

## Arguments

- x:

  A numeric vector.

- k:

  A numeric multiplier for the IQR. Default is `1.5`.

- na.rm:

  Logical. Should missing values be removed? Default is `FALSE`.

## Value

A numeric vector of length 2: `c(lower_tail, upper_tail)`.
