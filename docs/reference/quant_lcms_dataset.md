# LC-MS dataset with external calibration curve and metadata

This demo dataset is included for use in function examples and user
testing. It is a subset of an LC-MS analysis of plasma steroids,
containing an external calibration curve for each analyte, QC samples
with known concentrations, and unknown samples.

## Usage

``` r
quant_lcms_dataset
```

## Format

A `MRMhubExperiment` object with the following data and metadata:

- dataset_orig:

  Original data (peak data).

- dataset:

  Annotated data

- annot_analyses:

  Analysis-level metadata

- annot_features:

  Feature-level annotations

- annot_istds:

  ISTD concentrations

- annot_qcconcentrations:

  Calibrant (`CAL`) and QC concentrations
