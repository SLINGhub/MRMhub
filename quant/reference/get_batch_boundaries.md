# Get the start and end analysis numbers of specified batches

Sets the analysis order (sequence) based on either (i) analysis
timestamp, if available, (ii) the order in which analysis appeared in
the imported raw data file, or (iii) the order in which analyses were
defined in the Analysis metadata.

## Usage

``` r
get_batch_boundaries(data = NULL, batch_indices = NULL)
```

## Arguments

- data:

  MRMhubExperiment object

- batch_indices:

  A numeric vector with one or two elements, representing the first
  and/or last batch index (i.e., sequential batch number). If NULL or
  invalid, the function will abort.#' @return A vector with two
  elements: the lower and upper analysis number for the specified
  batch(es).
