# Data and Metadata in MRMhub

## MRMhubExperiment

The **`MRMhubExperiment`** object is the **primary data container** in
the MRMhub workflow. It holds all the experimental and processed data
and metadata, as well as details of the applied processing steps and the
current status of the data. Most `MRMhub` functions take the
`MRMhubExperiment` object as data input. Functions that process the data
return an updated `MRMhubExperiment` object, which can then be used in
subsequent steps.

Data within the `MRMhubExperiment` is organized into **data** and
**metadata** categories, each divided into tables (data.frames).

## Data

| Category | Table name (Slot) | Description |
|----|----|----|
| Raw Data | `dataset_orig` | Original imported analysis data. |
| Processed Data | `dataset` | Annotated raw and processed data with available metadata. |
| Feature metrics | `feature_metrics` | Information and various quality control metrics for features. |

## Metadata

| Data Type | Table name (Slot) | Description |
|----|----|----|
| Analyses Annotation | `annot_analyses` | Details sample categories, amounts, dilutions, processing batches, and other relevant information. |
| Features Annotation | `annot_features` | Describes internal standards for normalization, response factors, feature classification, and specifies quantifiers and internal standards. |
| Internal Standard | `annot_istds` | Concentrations of internal standards added to samples. |
| Batches | `annot_batches` | Specifies the boundaries (start and end) for each defined batch. |
| Response Curves | `annot_responsecurves` | Defines response curves, detailing sample amounts across different steps. |
| Calibration Curves | `annot_standards` | Defines concentrations of unlabelled and labelled standards in calibration curves and other quality control materials. |
