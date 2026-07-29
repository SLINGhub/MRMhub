# MRMhub overview

Manual

MRMhub performs postprocessing, quality control, and reporting of
targeted mass spectrometry data. This page gives a short overview of
MRMhub’s core data structure and how it is used by MRMhub’s
data-exchange, processing, and plotting functions.

**MRMhub’s data** is structured around two levels: **analyses**, the
individual measurements (often corresponding to MS injections), and
**features**, the distinct signals extracted from the MS data. Each
analysis–feature pair is a **measurement**, which can carry one or more
**feature variables** such as peak area and retention time. A **sample**
in this context is a physical sample that was measured (several analyses
can come from one sample) and an **analyte** can be represented by
several features (i.e., different transitions, isotopes and adducts).
See the
[Glossary](https://slinghub.github.io/MRMhub/quant/articles/manual-14-glossary.md)
for these and other terms.

## The MRMhubExperiment data object

All data (measurements) and detailed metadata describing the analyses
and features, together with the intermediate and final processed data
for one experiment, are stored in a single object of the
`MRMhubExperiment` class. The object also records data processing
status. See [The MRMhubExperiment data
object](https://slinghub.github.io/MRMhub/quant/articles/manual-02-data-object.md)
for details.

![](data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdib3g9IjAgMCA2MDAgMjgwIiBzdHlsZT0ibWF4LXdpZHRoOiA2MDBweDsgd2lkdGg6IDEwMCU7IGhlaWdodDogYXV0bzsgZm9udC1mYW1pbHk6IC1hcHBsZS1zeXN0ZW0sIEJsaW5rTWFjU3lzdGVtRm9udCwgJiMzOTtTZWdvZSBVSSYjMzk7LCBzYW5zLXNlcmlmOyI+PHJlY3QgeD0iNSIgeT0iNSIgd2lkdGg9IjU5MCIgaGVpZ2h0PSIyNzAiIHJ4PSIxMCIgZmlsbD0iI2Y4ZjlmYSIgc3Ryb2tlPSIjNUI4RkE4IiBzdHJva2Utd2lkdGg9IjIiIC8+PHRleHQgeD0iMzAwIiB5PSIzMCIgdGV4dC1hbmNob3I9Im1pZGRsZSIgZm9udC13ZWlnaHQ9IjcwMCIgZm9udC1zaXplPSIxNCIgZmlsbD0iIzJDM0U1MCI+TVJNaHViRXhwZXJpbWVudDwvdGV4dD48bGluZSB4MT0iMjAiIHkxPSI0MCIgeDI9IjU4MCIgeTI9IjQwIiBzdHJva2U9IiNkZWUyZTYiPjwvbGluZT48cmVjdCB4PSIyMCIgeT0iNTUiIHdpZHRoPSIyNzAiIGhlaWdodD0iMTAwIiByeD0iNiIgZmlsbD0iI2Q2ZTRlYiIgc3Ryb2tlPSIjNUI4RkE4IiAvPjx0ZXh0IHg9IjE1NSIgeT0iNzUiIHRleHQtYW5jaG9yPSJtaWRkbGUiIGZvbnQtd2VpZ2h0PSI2MDAiIGZvbnQtc2l6ZT0iMTIiIGZpbGw9IiMyQzNFNTAiPkRBVEE8L3RleHQ+PHRleHQgeD0iMzUiIHk9Ijk1IiBmb250LXNpemU9IjEwIiBmaWxsPSIjMzMzIj5kYXRhc2V0X29yaWc6IG9yaWdpbmFsCmltcG9ydGVkIGRhdGE8L3RleHQ+PHRleHQgeD0iMzUiIHk9IjExMiIgZm9udC1zaXplPSIxMCIgZmlsbD0iIzMzMyI+ZGF0YXNldDogYW5ub3RhdGVkIGFuZApwcm9jZXNzZWQgZGF0YTwvdGV4dD48dGV4dCB4PSIzNSIgeT0iMTI5IiBmb250LXNpemU9IjEwIiBmaWxsPSIjMzMzIj5kYXRhc2V0X2ZpbHRlcmVkOgpRQy1maWx0ZXJlZCBvdXRwdXQ8L3RleHQ+PHRleHQgeD0iMzUiIHk9IjE0NiIgZm9udC1zaXplPSIxMCIgZmlsbD0iIzMzMyI+bWV0cmljc19xYzogUUMgbWV0cmljcwpwZXIgZmVhdHVyZTwvdGV4dD48cmVjdCB4PSIzMTAiIHk9IjU1IiB3aWR0aD0iMjcwIiBoZWlnaHQ9IjEwMCIgcng9IjYiIGZpbGw9IiNmNWUwYzgiIHN0cm9rZT0iI0Q0OTE0RSIgLz48dGV4dCB4PSI0NDUiIHk9Ijc1IiB0ZXh0LWFuY2hvcj0ibWlkZGxlIiBmb250LXdlaWdodD0iNjAwIiBmb250LXNpemU9IjEyIiBmaWxsPSIjMkMzRTUwIj5NRVRBREFUQTwvdGV4dD48dGV4dCB4PSIzMjUiIHk9Ijk1IiBmb250LXNpemU9IjEwIiBmaWxsPSIjMzMzIj5hbm5vdF9hbmFseXNlczoKc2FtcGxlL3J1biBhbm5vdGF0aW9uczwvdGV4dD48dGV4dCB4PSIzMjUiIHk9IjExMiIgZm9udC1zaXplPSIxMCIgZmlsbD0iIzMzMyI+YW5ub3RfZmVhdHVyZXM6IGZlYXR1cmUKYW5ub3RhdGlvbnM8L3RleHQ+PHRleHQgeD0iMzI1IiB5PSIxMjkiIGZvbnQtc2l6ZT0iMTAiIGZpbGw9IiMzMzMiPmFubm90X2lzdGRzOiBJU1RECmNvbmNlbnRyYXRpb25zPC90ZXh0Pjx0ZXh0IHg9IjMyNSIgeT0iMTQ2IiBmb250LXNpemU9IjEwIiBmaWxsPSIjMzMzIj5hbm5vdF9iYXRjaGVzIC8KYW5ub3RfcWNjb25jZW50cmF0aW9ucyAvIOKApjwvdGV4dD48cmVjdCB4PSIyMCIgeT0iMTcwIiB3aWR0aD0iNTYwIiBoZWlnaHQ9IjUwIiByeD0iNiIgZmlsbD0iI2Q4ZTZkNCIgc3Ryb2tlPSIjNkI5RTVFIiAvPjx0ZXh0IHg9IjMwMCIgeT0iMTkyIiB0ZXh0LWFuY2hvcj0ibWlkZGxlIiBmb250LXdlaWdodD0iNjAwIiBmb250LXNpemU9IjEyIiBmaWxsPSIjMkMzRTUwIj5TVEFUVVMKQU5EIEZMQUdTPC90ZXh0Pjx0ZXh0IHg9IjMwMCIgeT0iMjEwIiB0ZXh0LWFuY2hvcj0ibWlkZGxlIiBmb250LXNpemU9IjEwIiBmaWxsPSIjMzMzIj5pc19pc3RkX25vcm1hbGl6ZWQsCmlzX3F1YW50aXRhdGVkLCB2YXJfZHJpZnRfY29ycmVjdGVkLCB2YXJfYmF0Y2hfY29ycmVjdGVkLCDigKY8L3RleHQ+PHRleHQgeD0iMzAwIiB5PSIyNTgiIHRleHQtYW5jaG9yPSJtaWRkbGUiIGZvbnQtc2l6ZT0iMTAiIGZpbGw9IiM2NjYiPkZ1bmN0aW9ucwp0YWtlIE1STWh1YkV4cGVyaW1lbnQgaW4gYW5kIHJldHVybiB1cGRhdGVkIE1STWh1YkV4cGVyaW1lbnQ8L3RleHQ+PC9zdmc+)

### How a MRMhubExperiment object is used in a workflow

An MRMhubExperiment object is created at the start of a workflow. Data
and metadata are imported into it, and it is then used in all subsequent
processing, plotting, and reporting steps. Each `mrmhub` function takes
an MRMhubExperiment object as its first argument, and processing
functions return an updated MRMhubExperiment object. This returned
object is typically assigned back to the same name, which is then passed
to the next function. Plotting functions instead return a plot
(typically `ggplot2` object). MRMhubExperiment objects can also be used
with the native R pipe (`|>`), which forwards the object from one
function to the next.

``` r

mexp <- MRMhubExperiment()
mexp <- import_data_mrmhub(mexp, path = "data/results.tsv")
mexp <- normalize_by_istd(mexp)

# equivalently, chained with the R pipe:
mexp <- MRMhubExperiment() |>
  import_data_mrmhub(path = "data/results.tsv") |>
  normalize_by_istd()
```

## Core function groups

MRMhub’s public functions fall into four groups, and their names follow
a consistent convention:

- **Data exchange** — read measured data and metadata into the object,
  and write results (tables, plots, reports) back out to disk.
- **Data processing** — the transforms that normalize, correct (drift,
  batch, isotopic interference), and quantify the measurements, and
  compute per-feature QC metrics.
- **QC charts** — return plots for visual inspection of the run order,
  normalization, corrections, calibration, and sample relationships.
- **QC filtering** — apply pass/fail thresholds to features and exclude
  features or analyses that fail QC.

The [Function
reference](https://slinghub.github.io/MRMhub/quant/reference/index.md)
lists every function with full parameter detail.

## Next steps

- [Glossary](https://slinghub.github.io/MRMhub/quant/articles/manual-14-glossary.md):
  definitions of the analytical terms used throughout the documentation
- [The MRMhubExperiment data
  object](https://slinghub.github.io/MRMhub/quant/articles/manual-02-data-object.md):
  the tables, identifiers, and variables in detail
- [Sample types & QC
  roles](https://slinghub.github.io/MRMhub/quant/articles/manual-06-sample-types.md):
  the QC labels used throughout
- [Basic MRMhub
  workflow](https://slinghub.github.io/MRMhub/quant/articles/tutorial-02-basic-workflow.md):
  these functions in a real script
- [Function
  reference](https://slinghub.github.io/MRMhub/quant/reference/index.md):
  every function with full parameter detail
