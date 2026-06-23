# Plasma Lipidomics Dataset with Metadata

This demo dataset is included for use in function examples and user
testing.. It is a small, preprocessed subset of a plasma lipidomics
dataset, containing raw peak areas and analytical metadata. The original
dataset was published in Tan et al., ATVB, 2022.

## Usage

``` r
lipidomics_dataset
```

## Format

A `MRMhubExperiment` object with the following data and metadata:

- dataset_orig:

  A tibble containing the original peak data.

- dataset:

  A tibble with annotated lipidomics data.

- annot_analyses:

  Analysis-level metadata

- annot_features:

  Feature-level metadata

- annot_batches:

  Batch annotations.

- annot_istds:

  ISTD concentrations

- annot_responsecurves:

  Response curves metadata
