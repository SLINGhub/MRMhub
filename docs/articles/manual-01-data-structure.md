# Data and Metadata in MRMhub

## Overview

The **`MRMhubExperiment`** object is the primary data container in the
MRMhub workflow. It holds all experimental and processed data and
metadata, as well as details of applied processing steps and the current
status of the data. Most MRMhub functions take the `MRMhubExperiment`
object as input and return an updated copy.

Data within the `MRMhubExperiment` is organized into **data** and
**metadata** categories, each divided into tables (data frames).

![](data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdib3g9IjAgMCA2MDAgMjgwIiBzdHlsZT0ibWF4LXdpZHRoOiA2MDBweDsgd2lkdGg6IDEwMCU7IGhlaWdodDogYXV0bzsgZm9udC1mYW1pbHk6IC1hcHBsZS1zeXN0ZW0sIEJsaW5rTWFjU3lzdGVtRm9udCwgJiMzOTtTZWdvZSBVSSYjMzk7LCBzYW5zLXNlcmlmOyI+PHJlY3QgeD0iNSIgeT0iNSIgd2lkdGg9IjU5MCIgaGVpZ2h0PSIyNzAiIHJ4PSIxMCIgZmlsbD0iI2Y4ZjlmYSIgc3Ryb2tlPSIjNGE5MGE0IiBzdHJva2Utd2lkdGg9IjIiIC8+PHRleHQgeD0iMzAwIiB5PSIzMCIgdGV4dC1hbmNob3I9Im1pZGRsZSIgZm9udC13ZWlnaHQ9IjcwMCIgZm9udC1zaXplPSIxNCIgZmlsbD0iIzFhMWExYSI+TVJNaHViRXhwZXJpbWVudDwvdGV4dD48bGluZSB4MT0iMjAiIHkxPSI0MCIgeDI9IjU4MCIgeTI9IjQwIiBzdHJva2U9IiNkZWUyZTYiPjwvbGluZT48cmVjdCB4PSIyMCIgeT0iNTUiIHdpZHRoPSIyNzAiIGhlaWdodD0iMTAwIiByeD0iNiIgZmlsbD0iI2Q2ZThmMCIgc3Ryb2tlPSIjNGE5MGE0IiAvPjx0ZXh0IHg9IjE1NSIgeT0iNzUiIHRleHQtYW5jaG9yPSJtaWRkbGUiIGZvbnQtd2VpZ2h0PSI2MDAiIGZvbnQtc2l6ZT0iMTIiIGZpbGw9IiMyYzVmN2EiPkRBVEE8L3RleHQ+PHRleHQgeD0iMzUiIHk9Ijk1IiBmb250LXNpemU9IjEwIiBmaWxsPSIjMzMzIj5kYXRhc2V0X29yaWcg4oCUIG9yaWdpbmFsCmltcG9ydGVkIGRhdGE8L3RleHQ+PHRleHQgeD0iMzUiIHk9IjExMiIgZm9udC1zaXplPSIxMCIgZmlsbD0iIzMzMyI+ZGF0YXNldCDigJQgYW5ub3RhdGVkIGFuZApwcm9jZXNzZWQgZGF0YTwvdGV4dD48dGV4dCB4PSIzNSIgeT0iMTI5IiBmb250LXNpemU9IjEwIiBmaWxsPSIjMzMzIj5kYXRhc2V0X2ZpbHRlcmVkIOKAlApRQy1maWx0ZXJlZCBvdXRwdXQ8L3RleHQ+PHRleHQgeD0iMzUiIHk9IjE0NiIgZm9udC1zaXplPSIxMCIgZmlsbD0iIzMzMyI+ZmVhdHVyZV9tZXRyaWNzIOKAlCBRQwptZXRyaWNzIHBlciBmZWF0dXJlPC90ZXh0PjxyZWN0IHg9IjMxMCIgeT0iNTUiIHdpZHRoPSIyNzAiIGhlaWdodD0iMTAwIiByeD0iNiIgZmlsbD0iI2Y1ZTBjOCIgc3Ryb2tlPSIjYzg3ZjNiIiAvPjx0ZXh0IHg9IjQ0NSIgeT0iNzUiIHRleHQtYW5jaG9yPSJtaWRkbGUiIGZvbnQtd2VpZ2h0PSI2MDAiIGZvbnQtc2l6ZT0iMTIiIGZpbGw9IiM3YTRhMWEiPk1FVEFEQVRBPC90ZXh0Pjx0ZXh0IHg9IjMyNSIgeT0iOTUiIGZvbnQtc2l6ZT0iMTAiIGZpbGw9IiMzMzMiPmFubm90X2FuYWx5c2VzIOKAlApzYW1wbGUvcnVuIGFubm90YXRpb25zPC90ZXh0Pjx0ZXh0IHg9IjMyNSIgeT0iMTEyIiBmb250LXNpemU9IjEwIiBmaWxsPSIjMzMzIj5hbm5vdF9mZWF0dXJlcyDigJQKZmVhdHVyZSBhbm5vdGF0aW9uczwvdGV4dD48dGV4dCB4PSIzMjUiIHk9IjEyOSIgZm9udC1zaXplPSIxMCIgZmlsbD0iIzMzMyI+YW5ub3RfaXN0ZHMg4oCUIElTVEQKY29uY2VudHJhdGlvbnM8L3RleHQ+PHRleHQgeD0iMzI1IiB5PSIxNDYiIGZvbnQtc2l6ZT0iMTAiIGZpbGw9IiMzMzMiPmFubm90X2JhdGNoZXMgLwphbm5vdF9zdGFuZGFyZHMgLyDigKY8L3RleHQ+PHJlY3QgeD0iMjAiIHk9IjE3MCIgd2lkdGg9IjU2MCIgaGVpZ2h0PSI1MCIgcng9IjYiIGZpbGw9IiNkNGU4ZDQiIHN0cm9rZT0iIzVhOWE1YSIgLz48dGV4dCB4PSIzMDAiIHk9IjE5MiIgdGV4dC1hbmNob3I9Im1pZGRsZSIgZm9udC13ZWlnaHQ9IjYwMCIgZm9udC1zaXplPSIxMiIgZmlsbD0iIzJjNWYyYyI+U1RBVFVTCkFORCBGTEFHUzwvdGV4dD48dGV4dCB4PSIzMDAiIHk9IjIxMCIgdGV4dC1hbmNob3I9Im1pZGRsZSIgZm9udC1zaXplPSIxMCIgZmlsbD0iIzMzMyI+aXNfaXN0ZF9ub3JtYWxpemVkLAppc19xdWFudGl0YXRlZCwgdmFyX2RyaWZ0X2NvcnJlY3RlZCwgdmFyX2JhdGNoX2NvcnJlY3RlZCwg4oCmPC90ZXh0Pjx0ZXh0IHg9IjMwMCIgeT0iMjU4IiB0ZXh0LWFuY2hvcj0ibWlkZGxlIiBmb250LXNpemU9IjEwIiBmaWxsPSIjNjY2Ij5GdW5jdGlvbnMKdGFrZSBNUk1odWJFeHBlcmltZW50IGluIGFuZCByZXR1cm4gdXBkYXRlZCBNUk1odWJFeHBlcmltZW50PC90ZXh0Pjwvc3ZnPg==)

## Data Tables

| Category | Table (Slot) | Description |
|----|----|----|
| Raw Data | `dataset_orig` | Original imported data — never modified after import. |
| Processed Data | `dataset` | Working copy with all annotations and processing results. |
| QC-filtered Data | `dataset_filtered` | Subset of `dataset` passing QC criteria. |
| Feature Metrics | `feature_metrics` | Quality control metrics calculated per feature. |

## Metadata Tables

| Category | Table (Slot) | Description |
|----|----|----|
| Analyses | `annot_analyses` | Sample categories, amounts, dilutions, batch assignments, and run order. |
| Features | `annot_features` | ISTD assignments, response factors, feature classification, quantifier/qualifier flags. |
| Internal Standards | `annot_istds` | ISTD concentrations added to each sample. |
| Batches | `annot_batches` | Start and end boundaries for each analytical batch. |
| Response Curves | `annot_responsecurves` | Dilution series definitions for response QC (RQC). |
| Calibration | `annot_standards` | Known concentrations of standards in calibration and QC samples. |

## How They Connect

All tables are linked by shared identifiers:

- **`analysis_id`** — links rows in `dataset` to rows in
  `annot_analyses`
- **`feature_id`** — links measurements to feature properties in
  `annot_features`
- **`batch_id`** — connects analyses to batch-level metadata in
  `annot_batches`

``` r

library(mrmhub)
mexp <- MRMhubExperiment()
mexp <- data_load_example(mexp, 1)

# Access data
get_analyticaldata(mexp)

# Access metadata
mexp$annot_analyses
mexp$annot_features
```

## See Also

- [Data
  Identifiers](https://slinghub.github.io/MRMhub/quant/articles/manual-02-data-identifiers.md)
  — detailed explanation of ID columns
- [Feature
  Variables](https://slinghub.github.io/MRMhub/quant/articles/manual-03-feature-variables.md)
  — all measurement variables
- [MRMhubExperiment
  Object](https://slinghub.github.io/MRMhub/quant/articles/manual-04-mrmhub-experiment.md)
  — creating and using the object
- [Key Concepts &
  Glossary](https://slinghub.github.io/MRMhub/quant/articles/manual-00-key-concepts.md)
  — plain-language overview
