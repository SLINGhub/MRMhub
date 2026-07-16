# Retrieve metadata from imported analysis data

Retrieves available metadata from the imported analysis data and
associates it with the provided MRMhubExperiment object.

## Usage

``` r
import_metadata_from_data(data = NULL, qc_type_column_name = "qc_type")
```

## Arguments

- data:

  A `MRMhubExperiment` object

- qc_type_column_name:

  Column name in the imported raw data representing the `qc_type`

## Value

An updated `MRMhubExperiment` object
