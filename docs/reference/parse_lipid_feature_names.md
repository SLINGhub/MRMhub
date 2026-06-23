# Get lipid class, species and transition names

This function retrieves lipid class, species and transition names from
the `feature_id` column and adds them as columns to the dataset.

## Usage

``` r
parse_lipid_feature_names(
  tbl,
  use_as_feature_class = "lipid_class_lcb",
  add_transition_names = FALSE,
  add_chain_composition = TRUE
)
```

## Arguments

- tbl:

  A data frame containing a `feature_id` column

- use_as_feature_class:

  Set feature_class to lipid_class

- add_transition_names:

  add transition name and transition group, based on information in
  square brackets in feature_id

- add_chain_composition:

  add total_c and total_db to the dataset

## Value

MRMhubExperiment object
