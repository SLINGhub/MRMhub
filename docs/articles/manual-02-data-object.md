# The MRMhubExperiment Data Object

Manual

The `MRMhubExperiment` object is the primary data container in the
MRMhub workflow. It holds all the experimental and processed data and
metadata, as well as details of the applied processing steps and the
current status of the data. Most MRMhub functions take the
`MRMhubExperiment` object as data input, and functions that process the
data return an updated `MRMhubExperiment` object, which can then be used
in subsequent steps. The data within the object is organized into
**data** and **metadata** categories, each divided into tables (data
frames).

![](data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdib3g9IjAgMCA2MDAgMjgwIiBzdHlsZT0ibWF4LXdpZHRoOiA2MDBweDsgd2lkdGg6IDEwMCU7IGhlaWdodDogYXV0bzsgZm9udC1mYW1pbHk6IC1hcHBsZS1zeXN0ZW0sIEJsaW5rTWFjU3lzdGVtRm9udCwgJiMzOTtTZWdvZSBVSSYjMzk7LCBzYW5zLXNlcmlmOyI+PHJlY3QgeD0iNSIgeT0iNSIgd2lkdGg9IjU5MCIgaGVpZ2h0PSIyNzAiIHJ4PSIxMCIgZmlsbD0iI2Y4ZjlmYSIgc3Ryb2tlPSIjNUI4RkE4IiBzdHJva2Utd2lkdGg9IjIiIC8+PHRleHQgeD0iMzAwIiB5PSIzMCIgdGV4dC1hbmNob3I9Im1pZGRsZSIgZm9udC13ZWlnaHQ9IjcwMCIgZm9udC1zaXplPSIxNCIgZmlsbD0iIzJDM0U1MCI+TVJNaHViRXhwZXJpbWVudDwvdGV4dD48bGluZSB4MT0iMjAiIHkxPSI0MCIgeDI9IjU4MCIgeTI9IjQwIiBzdHJva2U9IiNkZWUyZTYiPjwvbGluZT48cmVjdCB4PSIyMCIgeT0iNTUiIHdpZHRoPSIyNzAiIGhlaWdodD0iMTAwIiByeD0iNiIgZmlsbD0iI2Q2ZTRlYiIgc3Ryb2tlPSIjNUI4RkE4IiAvPjx0ZXh0IHg9IjE1NSIgeT0iNzUiIHRleHQtYW5jaG9yPSJtaWRkbGUiIGZvbnQtd2VpZ2h0PSI2MDAiIGZvbnQtc2l6ZT0iMTIiIGZpbGw9IiMyQzNFNTAiPkRBVEE8L3RleHQ+PHRleHQgeD0iMzUiIHk9Ijk1IiBmb250LXNpemU9IjEwIiBmaWxsPSIjMzMzIj5kYXRhc2V0X29yaWcg4oCUIG9yaWdpbmFsCmltcG9ydGVkIGRhdGE8L3RleHQ+PHRleHQgeD0iMzUiIHk9IjExMiIgZm9udC1zaXplPSIxMCIgZmlsbD0iIzMzMyI+ZGF0YXNldCDigJQgYW5ub3RhdGVkIGFuZApwcm9jZXNzZWQgZGF0YTwvdGV4dD48dGV4dCB4PSIzNSIgeT0iMTI5IiBmb250LXNpemU9IjEwIiBmaWxsPSIjMzMzIj5kYXRhc2V0X2ZpbHRlcmVkIOKAlApRQy1maWx0ZXJlZCBvdXRwdXQ8L3RleHQ+PHRleHQgeD0iMzUiIHk9IjE0NiIgZm9udC1zaXplPSIxMCIgZmlsbD0iIzMzMyI+bWV0cmljc19xYyDigJQgUUMgbWV0cmljcwpwZXIgZmVhdHVyZTwvdGV4dD48cmVjdCB4PSIzMTAiIHk9IjU1IiB3aWR0aD0iMjcwIiBoZWlnaHQ9IjEwMCIgcng9IjYiIGZpbGw9IiNmNWUwYzgiIHN0cm9rZT0iI0Q0OTE0RSIgLz48dGV4dCB4PSI0NDUiIHk9Ijc1IiB0ZXh0LWFuY2hvcj0ibWlkZGxlIiBmb250LXdlaWdodD0iNjAwIiBmb250LXNpemU9IjEyIiBmaWxsPSIjMkMzRTUwIj5NRVRBREFUQTwvdGV4dD48dGV4dCB4PSIzMjUiIHk9Ijk1IiBmb250LXNpemU9IjEwIiBmaWxsPSIjMzMzIj5hbm5vdF9hbmFseXNlcyDigJQKc2FtcGxlL3J1biBhbm5vdGF0aW9uczwvdGV4dD48dGV4dCB4PSIzMjUiIHk9IjExMiIgZm9udC1zaXplPSIxMCIgZmlsbD0iIzMzMyI+YW5ub3RfZmVhdHVyZXMg4oCUCmZlYXR1cmUgYW5ub3RhdGlvbnM8L3RleHQ+PHRleHQgeD0iMzI1IiB5PSIxMjkiIGZvbnQtc2l6ZT0iMTAiIGZpbGw9IiMzMzMiPmFubm90X2lzdGRzIOKAlCBJU1RECmNvbmNlbnRyYXRpb25zPC90ZXh0Pjx0ZXh0IHg9IjMyNSIgeT0iMTQ2IiBmb250LXNpemU9IjEwIiBmaWxsPSIjMzMzIj5hbm5vdF9iYXRjaGVzIC8KYW5ub3RfcWNjb25jZW50cmF0aW9ucyAvIOKApjwvdGV4dD48cmVjdCB4PSIyMCIgeT0iMTcwIiB3aWR0aD0iNTYwIiBoZWlnaHQ9IjUwIiByeD0iNiIgZmlsbD0iI2Q4ZTZkNCIgc3Ryb2tlPSIjNkI5RTVFIiAvPjx0ZXh0IHg9IjMwMCIgeT0iMTkyIiB0ZXh0LWFuY2hvcj0ibWlkZGxlIiBmb250LXdlaWdodD0iNjAwIiBmb250LXNpemU9IjEyIiBmaWxsPSIjMkMzRTUwIj5TVEFUVVMKQU5EIEZMQUdTPC90ZXh0Pjx0ZXh0IHg9IjMwMCIgeT0iMjEwIiB0ZXh0LWFuY2hvcj0ibWlkZGxlIiBmb250LXNpemU9IjEwIiBmaWxsPSIjMzMzIj5pc19pc3RkX25vcm1hbGl6ZWQsCmlzX3F1YW50aXRhdGVkLCB2YXJfZHJpZnRfY29ycmVjdGVkLCB2YXJfYmF0Y2hfY29ycmVjdGVkLCDigKY8L3RleHQ+PHRleHQgeD0iMzAwIiB5PSIyNTgiIHRleHQtYW5jaG9yPSJtaWRkbGUiIGZvbnQtc2l6ZT0iMTAiIGZpbGw9IiM2NjYiPkZ1bmN0aW9ucwp0YWtlIE1STWh1YkV4cGVyaW1lbnQgaW4gYW5kIHJldHVybiB1cGRhdGVkIE1STWh1YkV4cGVyaW1lbnQ8L3RleHQ+PC9zdmc+)

## Working with the object

A new object is created with
[`MRMhubExperiment()`](https://slinghub.github.io/MRMhub/quant/reference/MRMhubExperiment.md).
Most MRMhub functions take an `MRMhubExperiment` object as input, and
data processing functions return a modified `MRMhubExperiment` that is
used in the subsequent step. R pipes can also be used to chain multiple
functions together, which more clearly indicates the processing workflow
and makes the code easier to read:

``` r

mexp <- MRMhubExperiment() |>
  data_load_example(1) |>
  normalize_by_istd()
```

**New to R?** — what `|>` and `<-` do

`<-` assigns the value on its right to the name on its left, so
`mexp <- MRMhubExperiment()` stores the new object in `mexp`. The native
pipe `|>` passes the object on its left as the first argument of the
function on its right, so `mexp |> normalize_by_istd()` is the same as
`normalize_by_istd(mexp)`.

Multiple `MRMhubExperiment` objects can be created and processed
independently within the same script, which is convenient when polar and
non-polar assays, or several studies, are handled together:

``` r

m_polars <- MRMhubExperiment(title = "Polar metabolites")
m_lipids <- MRMhubExperiment(title = "Non-polar metabolites")
```

Functions starting with `get_` retrieve data and metadata from an
`MRMhubExperiment` object, and the `$` syntax can be used to access the
data and metadata tables directly. The whole object, with all its data,
metadata and processing state, is saved and read back as a single `.rds`
file:

``` r

mexp <- data_load_example(MRMhubExperiment(), 1)

dataset  <- get_analyticaldata(mexp, annotated = TRUE)  # processed data
analyses <- mexp$annot_analyses                         # sample metadata

saveRDS(mexp, "myexp-mrmhub.rds", compress = TRUE)
```

### Inspecting the processing state

Printing an `MRMhubExperiment` gives a compact overview: the number of
analyses and features, the raw signal in use, the last processing step,
and a one-line summary of which steps have been applied.

``` r

mexp                    # or print(mexp)
```

[`status()`](https://slinghub.github.io/MRMhub/quant/reference/status.md)
prints the full dashboard — sample composition by QC type, feature
composition, which metadata tables are populated, the state of every
processing step, and any manually excluded analyses or features. It is
the quickest way to confirm where a dataset stands in the workflow.

``` r

status(mexp)
```

The full list of accessor and processing functions is given in the
[function
reference](https://slinghub.github.io/MRMhub/quant/reference/index.md).

**Under the hood** — the full slot structure

`MRMhubExperiment` is an S4 object with the following slots. The status
flags (`is_*`, `var_*_corrected`) record which steps have been applied
and are consulted by later functions to enforce the recommended
processing order:

    MRMhubExperiment
      ├─ title:                 chr "My LCMS Assay"
      ├─ analysis_type:         chr NA
      ├─ feature_intensity_var: chr "feature_area"
      ├─ dataset_orig:          tibble [400 × 26]
      ├─ dataset:               tibble [400 × 26]
      ├─ dataset_filtered:      tibble [0 × 14]
      ├─ annot_analyses:        tibble [25 × 13]
      ├─ annot_features:        tibble [16 × 16]
      ├─ annot_istds:           tibble [8 × 4]
      ├─ annot_responsecurves:  tibble [0 × 3]
      ├─ annot_qcconcentrations: tibble [32 × 5]
      ├─ annot_batches:         tibble [1 × 4]
      ├─ metrics_qc:            tibble [0 × 0]
      ├─ metrics_calibration:   tibble [4 × 15]
      ├─ status_processing:     chr "Calibration-quantitated data"
      ├─ is_istd_normalized:    logi TRUE
      ├─ is_quantitated:        logi TRUE
      ├─ is_filtered:           logi FALSE
      ├─ var_drift_corrected:   Named logi [1:3]
      └─ var_batch_corrected:   Named logi [1:3]

## Data and metadata tables

The **data** tables hold the raw and processed values, and the
**metadata** (annotation) tables describe the samples, features and
standards. The two groups are linked by the shared identifiers described
in the next section.

| Group | Table (slot) | Description |
|----|----|----|
| Data | `dataset_orig` | Original imported analysis data; never modified after import. |
| Data | `dataset` | Annotated raw and processed data with the available metadata. |
| Data | `dataset_filtered` | Subset of `dataset` passing the QC criteria. |
| Data | `metrics_qc` | Information and quality-control metrics for features. |
| Metadata | `annot_analyses` | Sample categories, amounts, dilutions, processing batches, run order. |
| Metadata | `annot_features` | Internal standards for normalization, response factors, classification, quantifiers. |
| Metadata | `annot_istds` | Concentrations of internal standards added to samples. |
| Metadata | `annot_batches` | Start and end boundaries for each defined batch. |
| Metadata | `annot_responsecurves` | Response curves: sample amounts across dilution steps. |
| Metadata | `annot_qcconcentrations` | Concentrations of labelled and unlabelled standards in calibration and QC materials. |

## Identifiers

A small set of key fields organizes the data within the
`MRMhubExperiment` object and is used by many functions in the package.
Certain field names differ from conventional terminology
(e.g. `analysis_id` instead of `sample_id`) to allow more flexible
workflows and to reduce confusion with other identifiers: a sample may
be measured multiple times across different methods or processing
replicates, necessitating distinct identifiers, and analytes can be
quantified through multiple transitions or adducts, which is why
`feature_id` is designated as the primary identifier.

| Table | Field | Description |
|----|----|----|
| Analyses | **`analysis_id`** | Unique identifier of each analysis. |
|  | `qc_type` | QC/sample type (see below). |
|  | `batch_id` | Unique identifier of each batch. |
|  | `sample_id` | Unique identifier of the physical sample that was tested. |
| Features | **`feature_id`** | Unique identifier for each feature. |
|  | `istd_feature_id` | The `feature_id` of the internal standard used to normalize raw intensities. |
|  | `analyte_id` | Unique identifier of the analyte. |

All identifiers are whitespace-normalized on import — leading/trailing
spaces removed and internal runs collapsed — and raw-data file
extensions are stripped from `analysis_id`, using the same rules for
data and metadata so the two join reliably. See [Importing Analytical
Data](https://slinghub.github.io/MRMhub/quant/articles/manual-04-data-import.html#identifier-normalization)
for details.

The `qc_type` field categorizes samples by their analytical purpose and
is used throughout the package. It combines standardized terms
introduced by Broadhurst et al. (2018) (SPL, BQC, TQC, LTR, RQC) with
traditional terminology from analytical and clinical chemistry (LQC,
MQC, HQC, CAL, NIST, SST, and the blank types). Each `qc_type` is shown
with a consistent colour scheme and point shape across all MRMhub plots;
the full list and their roles is given in [Sample Types & QC
Roles](https://slinghub.github.io/MRMhub/quant/articles/manual-06-sample-types.md).

## Feature variables

Feature variables store the values associated with a feature in a
specific sample. They describe, for example, the absolute or relative
abundance, the chromatographic retention time, the peak shape, and —
when processed data are imported — properties such as measurement
accuracy. A feature variable can be referred to by its internal name,
which always starts with `feature_` (e.g. `feature_intensity`), or by
its short name (e.g. `conc`, `intensity`, `norm_intensity`, `rt`), and
many processing and plotting functions take a `variable` argument that
selects which one to use.

The following variables organize the data-processing flow and are stored
in the `dataset` table. The `intensity` variable holds the raw signal
(e.g. peak area) retrieved from one of the original feature variables;
all variables downstream are the result of processing:

Some processing steps overwrite feature values with re-calculated ones —
for example feature area after interference correction, or
concentrations after drift/batch correction or reference-sample
re-calibration. In these cases the original values are kept in a backup
variable, so the earlier state remains available; the backup is named
after the original variable with a postfix: `_orig` (the imported
intensity, before interference correction), `_raw` (the uncorrected
calculated values, before a correction step), `_before` (the last value
before the most recent correction), `_beforecal` (before
[`calibrate_by_reference()`](https://slinghub.github.io/MRMhub/quant/reference/calibrate_by_reference.md)),
and `_fit` (model-fit points used by
[`plot_runscatter()`](https://slinghub.github.io/MRMhub/quant/reference/plot_runscatter.md)
to show the trend).

The raw feature variables below are stored in `dataset_orig` and are
never modified by any MRMhub function. One of them is copied to
`intensity` at import (by default `area` if available, then `height`,
`response`, or `intensity`), and the source variable can be set manually
with
[`set_intensity_var()`](https://slinghub.github.io/MRMhub/quant/reference/set_intensity_var.md):

## Next steps

- [Importing Analytical
  Data](https://slinghub.github.io/MRMhub/quant/articles/manual-04-data-import.md)
  — load a peak table into a new object
- [Sample Types & QC
  Roles](https://slinghub.github.io/MRMhub/quant/articles/manual-06-sample-types.md)
  — the full list of `qc_type` labels
- [Design
  Overview](https://slinghub.github.io/MRMhub/quant/articles/manual-03-design-overview.md)
  — how data flows through the pipeline
- [Function
  reference](https://slinghub.github.io/MRMhub/quant/reference/index.md)
  — accessors and processing functions

## References

Broadhurst, David, Royston Goodacre, Stacey N. Reinke, et al. 2018.
“Guidelines and Considerations for the Use of System Suitability and
Quality Control Samples in Mass Spectrometry Assays Applied in
Untargeted Clinical Metabolomic Studies.” *Metabolomics* 14 (6): 72.
<https://doi.org/10.1007/s11306-018-1367-3>.
