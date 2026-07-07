# Key Concepts & Glossary

## How MRMhub Thinks About Your Data

MRMhub organizes targeted mass spectrometry data around two axes:

- **Analyses** (rows) — individual injections/samples in your run
- **Features** (columns) — individual MRM transitions (compound +
  precursor/product ion pair)

Every measurement is a **peak area** at the intersection of one analysis
and one feature. All of this is stored in a single object: the
`MRMhubExperiment`.

## The MRMhubExperiment Object

![](data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdib3g9IjAgMCA0ODAgMjgwIiBzdHlsZT0ibWF4LXdpZHRoOiA0ODBweDsgd2lkdGg6IDEwMCU7IGhlaWdodDogYXV0bzsgZm9udC1mYW1pbHk6IC1hcHBsZS1zeXN0ZW0sIEJsaW5rTWFjU3lzdGVtRm9udCwgJiMzOTtTZWdvZSBVSSYjMzk7LCBzYW5zLXNlcmlmOyI+PHJlY3QgeD0iMTAiIHk9IjEwIiB3aWR0aD0iNDYwIiBoZWlnaHQ9IjI2MCIgcng9IjEyIiBmaWxsPSIjZjhmOWZhIiBzdHJva2U9IiM0YTkwYTQiIHN0cm9rZS13aWR0aD0iMiIgLz48dGV4dCB4PSIyNDAiIHk9IjM4IiB0ZXh0LWFuY2hvcj0ibWlkZGxlIiBmb250LXdlaWdodD0iNzAwIiBmb250LXNpemU9IjE1IiBmaWxsPSIjMWExYTFhIj5NUk1odWJFeHBlcmltZW50PC90ZXh0PjxsaW5lIHgxPSIzMCIgeTE9IjQ4IiB4Mj0iNDUwIiB5Mj0iNDgiIHN0cm9rZT0iI2RlZTJlNiI+PC9saW5lPjwhLS0gREFUQSBzZWN0aW9uIC0tPjxyZWN0IHg9IjMwIiB5PSI2MCIgd2lkdGg9IjIwMCIgaGVpZ2h0PSI5MCIgcng9IjYiIGZpbGw9IiNkNmU4ZjAiIHN0cm9rZT0iIzRhOTBhNCIgLz48dGV4dCB4PSIxMzAiIHk9IjgyIiB0ZXh0LWFuY2hvcj0ibWlkZGxlIiBmb250LXdlaWdodD0iNjAwIiBmb250LXNpemU9IjEyIiBmaWxsPSIjMmM1ZjdhIj5EQVRBPC90ZXh0Pjx0ZXh0IHg9IjQ1IiB5PSIxMDIiIGZvbnQtc2l6ZT0iMTEiIGZpbGw9IiMzMzMiPuKAoiBwZWFrIGFyZWFzCihyYXcpPC90ZXh0Pjx0ZXh0IHg9IjQ1IiB5PSIxMTgiIGZvbnQtc2l6ZT0iMTEiIGZpbGw9IiMzMzMiPuKAoiBwZWFrCmFyZWFzIChub3JtYWxpemVkKTwvdGV4dD48dGV4dCB4PSI0NSIgeT0iMTM0IiBmb250LXNpemU9IjExIiBmaWxsPSIjMzMzIj7igKIgY2FsaWJyYXRpb24KY3VydmVzPC90ZXh0PjwhLS0gTUVUQURBVEEgc2VjdGlvbiAtLT48cmVjdCB4PSIyNTAiIHk9IjYwIiB3aWR0aD0iMjAwIiBoZWlnaHQ9IjkwIiByeD0iNiIgZmlsbD0iI2Y1ZTBjOCIgc3Ryb2tlPSIjYzg3ZjNiIiAvPjx0ZXh0IHg9IjM1MCIgeT0iODIiIHRleHQtYW5jaG9yPSJtaWRkbGUiIGZvbnQtd2VpZ2h0PSI2MDAiIGZvbnQtc2l6ZT0iMTIiIGZpbGw9IiM3YTRhMWEiPk1FVEFEQVRBPC90ZXh0Pjx0ZXh0IHg9IjI2NSIgeT0iMTAyIiBmb250LXNpemU9IjExIiBmaWxsPSIjMzMzIj7igKIgYW5hbHlzZXNfdGFibGU8L3RleHQ+PHRleHQgeD0iMjY1IiB5PSIxMTgiIGZvbnQtc2l6ZT0iMTEiIGZpbGw9IiMzMzMiPuKAoiBmZWF0dXJlc190YWJsZTwvdGV4dD48dGV4dCB4PSIyNjUiIHk9IjEzNCIgZm9udC1zaXplPSIxMSIgZmlsbD0iIzMzMyI+4oCiIHByb2Nlc3NpbmcgbG9nPC90ZXh0PjwhLS0gUGlwZWxpbmUgY29uY2VwdCAtLT48cmVjdCB4PSIzMCIgeT0iMTcwIiB3aWR0aD0iNDIwIiBoZWlnaHQ9IjUwIiByeD0iNiIgZmlsbD0iI2Q0ZThkNCIgc3Ryb2tlPSIjNWE5YTVhIiAvPjx0ZXh0IHg9IjI0MCIgeT0iMTkyIiB0ZXh0LWFuY2hvcj0ibWlkZGxlIiBmb250LXdlaWdodD0iNjAwIiBmb250LXNpemU9IjEyIiBmaWxsPSIjMmM1ZjJjIj5QSVBFTElORTwvdGV4dD48dGV4dCB4PSIyNDAiIHk9IjIxMCIgdGV4dC1hbmNob3I9Im1pZGRsZSIgZm9udC1zaXplPSIxMSIgZmlsbD0iIzMzMyI+ZnVuY3Rpb24obWhleHApCuKGkiB1cGRhdGVkIG1oZXhwIOKGkiBmdW5jdGlvbihtaGV4cCkg4oaSIOKApjwvdGV4dD48IS0tIEZvb3RlciAtLT48dGV4dCB4PSIyNDAiIHk9IjI1NSIgdGV4dC1hbmNob3I9Im1pZGRsZSIgZm9udC1zaXplPSIxMCIgZmlsbD0iIzY2NiI+Q2hhaW4KZnVuY3Rpb25zIHRvZ2V0aGVyIHRvIGJ1aWxkIHlvdXIgd29ya2Zsb3c8L3RleHQ+PC9zdmc+)

Functions take an `MRMhubExperiment` in and return an updated one — you
chain them together to build your workflow.

## Glossary

## Key Identifiers

MRMhub uses consistent column names across all data:

| Column | Where | Purpose |
|----|----|----|
| `analysis_id` | analyses table, data tables | Links a row to a specific injection |
| `feature_id` | features table, data tables | Links a value to a specific transition |
| `analysis_type` | analyses table | Sample, RQC, blank, calibration, etc. |
| `compound_name` | features table | Human-readable compound name |
| `istd_feature_id` | features table | Maps each analyte to its internal standard |

## See Also

- [Data
  Structures](https://slinghub.github.io/MRMhub/quant/articles/manual-01-data-structure.md)
  — technical details of each table
- [Data
  Identifiers](https://slinghub.github.io/MRMhub/quant/articles/manual-02-data-identifiers.md)
  — deep dive on ID columns
- [Feature
  Variables](https://slinghub.github.io/MRMhub/quant/articles/manual-03-feature-variables.md)
  — all feature metadata columns
