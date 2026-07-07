# Data and Metadata in MRMhub

## Overview

The **`MRMhubExperiment`** object is the primary data container in the
MRMhub workflow. It holds all experimental and processed data and
metadata, as well as details of applied processing steps and the current
status of the data. Most MRMhub functions take the `MRMhubExperiment`
object as input and return an updated copy.

Data within the `MRMhubExperiment` is organized into **data** and
**metadata** categories, each divided into tables (data frames).

![](data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdib3g9IjAgMCA2MDAgMjgwIiBzdHlsZT0ibWF4LXdpZHRoOiA2MDBweDsgd2lkdGg6IDEwMCU7IGhlaWdodDogYXV0bzsgZm9udC1mYW1pbHk6IC1hcHBsZS1zeXN0ZW0sIEJsaW5rTWFjU3lzdGVtRm9udCwgJiMzOTtTZWdvZSBVSSYjMzk7LCBzYW5zLXNlcmlmOyI+PHJlY3QgeD0iNSIgeT0iNSIgd2lkdGg9IjU5MCIgaGVpZ2h0PSIyNzAiIHJ4PSIxMCIgZmlsbD0iI2Y4ZjlmYSIgc3Ryb2tlPSIjNGE5MGE0IiBzdHJva2Utd2lkdGg9IjIiIC8+PHRleHQgeD0iMzAwIiB5PSIzMCIgdGV4dC1hbmNob3I9Im1pZGRsZSIgZm9udC13ZWlnaHQ9IjcwMCIgZm9udC1zaXplPSIxNCIgZmlsbD0iIzFhMWExYSI+TVJNaHViRXhwZXJpbWVudDwvdGV4dD48bGluZSB4MT0iMjAiIHkxPSI0MCIgeDI9IjU4MCIgeTI9IjQwIiBzdHJva2U9IiNkZWUyZTYiPjwvbGluZT48cmVjdCB4PSIyMCIgeT0iNTUiIHdpZHRoPSIyNzAiIGhlaWdodD0iMTAwIiByeD0iNiIgZmlsbD0iI2Q2ZThmMCIgc3Ryb2tlPSIjNGE5MGE0IiAvPjx0ZXh0IHg9IjE1NSIgeT0iNzUiIHRleHQtYW5jaG9yPSJtaWRkbGUiIGZvbnQtd2VpZ2h0PSI2MDAiIGZvbnQtc2l6ZT0iMTIiIGZpbGw9IiMyYzVmN2EiPkRBVEE8L3RleHQ+PHRleHQgeD0iMzUiIHk9Ijk1IiBmb250LXNpemU9IjEwIiBmaWxsPSIjMzMzIj5kYXRhc2V0X29yaWcg4oCUIG9yaWdpbmFsCmltcG9ydGVkIGRhdGE8L3RleHQ+PHRleHQgeD0iMzUiIHk9IjExMiIgZm9udC1zaXplPSIxMCIgZmlsbD0iIzMzMyI+ZGF0YXNldCDigJQgYW5ub3RhdGVkIGFuZApwcm9jZXNzZWQgZGF0YTwvdGV4dD48dGV4dCB4PSIzNSIgeT0iMTI5IiBmb250LXNpemU9IjEwIiBmaWxsPSIjMzMzIj5kYXRhc2V0X2ZpbHRlcmVkIOKAlApRQy1maWx0ZXJlZCBvdXRwdXQ8L3RleHQ+PHRleHQgeD0iMzUiIHk9IjE0NiIgZm9udC1zaXplPSIxMCIgZmlsbD0iIzMzMyI+bWV0cmljc19xYyDigJQgUUMgbWV0cmljcwpwZXIgZmVhdHVyZTwvdGV4dD48cmVjdCB4PSIzMTAiIHk9IjU1IiB3aWR0aD0iMjcwIiBoZWlnaHQ9IjEwMCIgcng9IjYiIGZpbGw9IiNmNWUwYzgiIHN0cm9rZT0iI2M4N2YzYiIgLz48dGV4dCB4PSI0NDUiIHk9Ijc1IiB0ZXh0LWFuY2hvcj0ibWlkZGxlIiBmb250LXdlaWdodD0iNjAwIiBmb250LXNpemU9IjEyIiBmaWxsPSIjN2E0YTFhIj5NRVRBREFUQTwvdGV4dD48dGV4dCB4PSIzMjUiIHk9Ijk1IiBmb250LXNpemU9IjEwIiBmaWxsPSIjMzMzIj5hbm5vdF9hbmFseXNlcyDigJQKc2FtcGxlL3J1biBhbm5vdGF0aW9uczwvdGV4dD48dGV4dCB4PSIzMjUiIHk9IjExMiIgZm9udC1zaXplPSIxMCIgZmlsbD0iIzMzMyI+YW5ub3RfZmVhdHVyZXMg4oCUCmZlYXR1cmUgYW5ub3RhdGlvbnM8L3RleHQ+PHRleHQgeD0iMzI1IiB5PSIxMjkiIGZvbnQtc2l6ZT0iMTAiIGZpbGw9IiMzMzMiPmFubm90X2lzdGRzIOKAlCBJU1RECmNvbmNlbnRyYXRpb25zPC90ZXh0Pjx0ZXh0IHg9IjMyNSIgeT0iMTQ2IiBmb250LXNpemU9IjEwIiBmaWxsPSIjMzMzIj5hbm5vdF9iYXRjaGVzIC8KYW5ub3RfcWNjb25jZW50cmF0aW9ucyAvIOKApjwvdGV4dD48cmVjdCB4PSIyMCIgeT0iMTcwIiB3aWR0aD0iNTYwIiBoZWlnaHQ9IjUwIiByeD0iNiIgZmlsbD0iI2Q0ZThkNCIgc3Ryb2tlPSIjNWE5YTVhIiAvPjx0ZXh0IHg9IjMwMCIgeT0iMTkyIiB0ZXh0LWFuY2hvcj0ibWlkZGxlIiBmb250LXdlaWdodD0iNjAwIiBmb250LXNpemU9IjEyIiBmaWxsPSIjMmM1ZjJjIj5TVEFUVVMKQU5EIEZMQUdTPC90ZXh0Pjx0ZXh0IHg9IjMwMCIgeT0iMjEwIiB0ZXh0LWFuY2hvcj0ibWlkZGxlIiBmb250LXNpemU9IjEwIiBmaWxsPSIjMzMzIj5pc19pc3RkX25vcm1hbGl6ZWQsCmlzX3F1YW50aXRhdGVkLCB2YXJfZHJpZnRfY29ycmVjdGVkLCB2YXJfYmF0Y2hfY29ycmVjdGVkLCDigKY8L3RleHQ+PHRleHQgeD0iMzAwIiB5PSIyNTgiIHRleHQtYW5jaG9yPSJtaWRkbGUiIGZvbnQtc2l6ZT0iMTAiIGZpbGw9IiM2NjYiPkZ1bmN0aW9ucwp0YWtlIE1STWh1YkV4cGVyaW1lbnQgaW4gYW5kIHJldHVybiB1cGRhdGVkIE1STWh1YkV4cGVyaW1lbnQ8L3RleHQ+PC9zdmc+)

## Data Tables

| Category | Table (Slot) | Description |
|----|----|----|
| Raw Data | `dataset_orig` | Original imported data — never modified after import. |
| Processed Data | `dataset` | Working copy with all annotations and processing results. |
| QC-filtered Data | `dataset_filtered` | Subset of `dataset` passing QC criteria. |
| Feature Metrics | `metrics_qc` | Quality control metrics calculated per feature. |

## Metadata Tables

| Category | Table (Slot) | Description |
|----|----|----|
| Analyses | `annot_analyses` | Sample categories, amounts, dilutions, batch assignments, and run order. |
| Features | `annot_features` | ISTD assignments, response factors, feature classification, quantifier/qualifier flags. |
| Internal Standards | `annot_istds` | ISTD concentrations added to each sample. |
| Batches | `annot_batches` | Start and end boundaries for each analytical batch. |
| Response Curves | `annot_responsecurves` | Dilution series definitions for response QC (RQC). |
| Calibration | `annot_qcconcentrations` | Known concentrations of standards in calibration and QC samples. |

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

## Next Steps

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
