# Get the start and end analysis numbers of specified batches

Returns the lower and upper analysis number (sequence position) spanned
by the specified batch or range of batches.

## Usage

``` r
get_batch_boundaries(data = NULL, batch_indices = NULL)
```

## Arguments

- data:

  [`MRMhubExperiment`](https://slinghub.github.io/MRMhub/quant/reference/MRMhubExperiment-class.md)
  object

- batch_indices:

  A numeric vector with one or two elements, representing the first
  and/or last batch index (i.e., sequential batch number). If NULL or
  invalid, the function will abort.

## Value

A vector with two elements: the lower and upper analysis number for the
specified batch(es).
