# Design Overview: How Data Flows Through MRMhub

## The Big Picture

MRMhub processes targeted mass spectrometry data in two stages:

![](data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdib3g9IjAgMCA4NjAgMTAwIiBzdHlsZT0ibWF4LXdpZHRoOiA4NjBweDsgd2lkdGg6IDEwMCU7IGhlaWdodDogYXV0bzsgZm9udC1mYW1pbHk6IC1hcHBsZS1zeXN0ZW0sIEJsaW5rTWFjU3lzdGVtRm9udCwgJiMzOTtTZWdvZSBVSSYjMzk7LCBzYW5zLXNlcmlmOyI+PHN0eWxlPgogICAgLmFyY2gtYm94IHsgcng6IDg7IHJ5OiA4OyBzdHJva2Utd2lkdGg6IDEuNTsgfQogICAgLmFyY2gtbGFiZWwgeyBmb250LXNpemU6IDEycHg7IGZvbnQtd2VpZ2h0OiA2MDA7IGZpbGw6ICMxYTFhMWE7IH0KICAgIC5hcmNoLXN1YiB7IGZvbnQtc2l6ZTogMTBweDsgZmlsbDogIzU1NTsgfQogICAgLmFyY2gtYXJyb3cgeyBmaWxsOiAjNjY2OyB9CiAgPC9zdHlsZT4KPHJlY3QgY2xhc3M9ImFyY2gtYm94IiB4PSIwIiB5PSIxNSIgd2lkdGg9IjE0MCIgaGVpZ2h0PSI3MCIgZmlsbD0iI2U4ZThlOCIgc3Ryb2tlPSIjODg4IiAvPjx0ZXh0IGNsYXNzPSJhcmNoLWxhYmVsIiB4PSI3MCIgeT0iNDUiIHRleHQtYW5jaG9yPSJtaWRkbGUiPlJhdwpGaWxlczwvdGV4dD48dGV4dCBjbGFzcz0iYXJjaC1zdWIiIHg9IjcwIiB5PSI2MiIgdGV4dC1hbmNob3I9Im1pZGRsZSI+KC53aWZmIC8KLmQpPC90ZXh0Pjxwb2x5Z29uIGNsYXNzPSJhcmNoLWFycm93IiBwb2ludHM9IjE1MCw1MCAxNjIsNDMgMTYyLDU3Ij48L3BvbHlnb24+PHJlY3QgY2xhc3M9ImFyY2gtYm94IiB4PSIxNzIiIHk9IjE1IiB3aWR0aD0iMTQwIiBoZWlnaHQ9IjcwIiBmaWxsPSIjZDZlOGYwIiBzdHJva2U9IiM0YTkwYTQiIC8+PHRleHQgY2xhc3M9ImFyY2gtbGFiZWwiIHg9IjI0MiIgeT0iNDUiIHRleHQtYW5jaG9yPSJtaWRkbGUiPm1zY29udmVydDwvdGV4dD48dGV4dCBjbGFzcz0iYXJjaC1zdWIiIHg9IjI0MiIgeT0iNjIiIHRleHQtYW5jaG9yPSJtaWRkbGUiPuKGkgoubXpNTDwvdGV4dD48cG9seWdvbiBjbGFzcz0iYXJjaC1hcnJvdyIgcG9pbnRzPSIzMjIsNTAgMzM0LDQzIDMzNCw1NyI+PC9wb2x5Z29uPjxyZWN0IGNsYXNzPSJhcmNoLWJveCIgeD0iMzQ0IiB5PSIxNSIgd2lkdGg9IjE0MCIgaGVpZ2h0PSI3MCIgZmlsbD0iI2Y1ZTBjOCIgc3Ryb2tlPSIjYzg3ZjNiIiAvPjx0ZXh0IGNsYXNzPSJhcmNoLWxhYmVsIiB4PSI0MTQiIHk9IjQ1IiB0ZXh0LWFuY2hvcj0ibWlkZGxlIj5JTlRFR1JBVE9SPC90ZXh0Pjx0ZXh0IGNsYXNzPSJhcmNoLXN1YiIgeD0iNDE0IiB5PSI2MiIgdGV4dC1hbmNob3I9Im1pZGRsZSI+UGVhawppbnRlZ3JhdGlvbjwvdGV4dD48cG9seWdvbiBjbGFzcz0iYXJjaC1hcnJvdyIgcG9pbnRzPSI0OTQsNTAgNTA2LDQzIDUwNiw1NyI+PC9wb2x5Z29uPjxyZWN0IGNsYXNzPSJhcmNoLWJveCIgeD0iNTE2IiB5PSIxNSIgd2lkdGg9IjE0MCIgaGVpZ2h0PSI3MCIgZmlsbD0iI2YwZjBmMCIgc3Ryb2tlPSIjODg4IiAvPjx0ZXh0IGNsYXNzPSJhcmNoLWxhYmVsIiB4PSI1ODYiIHk9IjQ1IiB0ZXh0LWFuY2hvcj0ibWlkZGxlIj5sb25nLmNzdjwvdGV4dD48dGV4dCBjbGFzcz0iYXJjaC1zdWIiIHg9IjU4NiIgeT0iNjIiIHRleHQtYW5jaG9yPSJtaWRkbGUiPlRpZHkKZXhjaGFuZ2U8L3RleHQ+PHBvbHlnb24gY2xhc3M9ImFyY2gtYXJyb3ciIHBvaW50cz0iNjY2LDUwIDY3OCw0MyA2NzgsNTciPjwvcG9seWdvbj48YSBocmVmPSJodHRwczovL3NsaW5naHViLmdpdGh1Yi5pby9NUk1odWIvcXVhbnQvYXJ0aWNsZXMvbWFudWFsLTA1LWRhdGEtaW1wb3J0Lm1kIj4KPHJlY3QgY2xhc3M9ImFyY2gtYm94IiB4PSI2ODgiIHk9IjE1IiB3aWR0aD0iMTYwIiBoZWlnaHQ9IjcwIiBmaWxsPSIjZDRlOGQ0IiBzdHJva2U9IiM1YTlhNWEiIC8+PHRleHQgY2xhc3M9ImFyY2gtbGFiZWwiIHg9Ijc2OCIgeT0iNDUiIHRleHQtYW5jaG9yPSJtaWRkbGUiPlFVQU5UCihSKTwvdGV4dD48dGV4dCBjbGFzcz0iYXJjaC1zdWIiIHg9Ijc2OCIgeT0iNjIiIHRleHQtYW5jaG9yPSJtaWRkbGUiPlBvc3QtcHJvY2Vzc2luZzwvdGV4dD48L2E+Cjwvc3ZnPg==)

**Stage 1 — INTEGRATOR** converts vendor raw files into a standardized
long-format CSV containing peak areas per feature per sample. This
handles:

- File format conversion (msconvert)
- Peak detection, picking, and integration
- Batch-aware file organization

**Stage 2 — QUANT (this R package)** takes the long CSV and provides:

- Data import and validation
- Internal standard (ISTD) normalization
- Drift and batch correction
- External calibration and quantification
- Quality control metrics and filtering
- Visualization and reporting

## Data Flow Inside QUANT

![](data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdib3g9IjAgMCA3MDAgMjIwIiBzdHlsZT0ibWF4LXdpZHRoOiA3MDBweDsgd2lkdGg6IDEwMCU7IGhlaWdodDogYXV0bzsgZm9udC1mYW1pbHk6IC1hcHBsZS1zeXN0ZW0sIEJsaW5rTWFjU3lzdGVtRm9udCwgJiMzOTtTZWdvZSBVSSYjMzk7LCBzYW5zLXNlcmlmOyI+PHJlY3QgeD0iNSIgeT0iNSIgd2lkdGg9IjY5MCIgaGVpZ2h0PSIyMTAiIHJ4PSIxMCIgZmlsbD0iI2Y4ZjlmYSIgc3Ryb2tlPSIjNGE5MGE0IiBzdHJva2Utd2lkdGg9IjEuNSIgLz48dGV4dCB4PSIzNTAiIHk9IjI4IiB0ZXh0LWFuY2hvcj0ibWlkZGxlIiBmb250LXdlaWdodD0iNzAwIiBmb250LXNpemU9IjEzIiBmaWxsPSIjMmM1ZjdhIj5NUk1odWJFeHBlcmltZW50Ck9iamVjdDwvdGV4dD48bGluZSB4MT0iMjAiIHkxPSIzNiIgeDI9IjY4MCIgeTI9IjM2IiBzdHJva2U9IiNkZWUyZTYiPjwvbGluZT48IS0tIElucHV0IGFycm93cyAtLT48dGV4dCB4PSIyMCIgeT0iNzAiIGZvbnQtc2l6ZT0iMTEiIGZpbGw9IiM1NTUiPmxvbmcuY3N2IOKGkjwvdGV4dD48dGV4dCB4PSIyMCIgeT0iMTMwIiBmb250LXNpemU9IjExIiBmaWxsPSIjNTU1Ij5tZXRhZGF0YSDihpI8L3RleHQ+PCEtLSBEYXRhIHNsb3RzIC0tPjxyZWN0IHg9IjEwMCIgeT0iNTAiIHdpZHRoPSIxODAiIGhlaWdodD0iNzAiIHJ4PSI2IiBmaWxsPSIjZDZlOGYwIiBzdHJva2U9IiM0YTkwYTQiIC8+PHRleHQgeD0iMTkwIiB5PSI3MCIgdGV4dC1hbmNob3I9Im1pZGRsZSIgZm9udC1zaXplPSIxMSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iIzJjNWY3YSI+RGF0YXNldHM8L3RleHQ+PHRleHQgeD0iMTE1IiB5PSI4OCIgZm9udC1zaXplPSIxMCIgZmlsbD0iIzMzMyI+ZGF0YXNldF9vcmlnCihpbW11dGFibGUpPC90ZXh0Pjx0ZXh0IHg9IjExNSIgeT0iMTAzIiBmb250LXNpemU9IjEwIiBmaWxsPSIjMzMzIj5kYXRhc2V0Cih3b3JraW5nKTwvdGV4dD48dGV4dCB4PSIxMTUiIHk9IjExOCIgZm9udC1zaXplPSIxMCIgZmlsbD0iIzMzMyI+ZGF0YXNldF9maWx0ZXJlZAooZmluYWwpPC90ZXh0PjwhLS0gTWV0YWRhdGEgc2xvdHMgLS0+PHJlY3QgeD0iMzAwIiB5PSI1MCIgd2lkdGg9IjE4MCIgaGVpZ2h0PSI3MCIgcng9IjYiIGZpbGw9IiNmNWUwYzgiIHN0cm9rZT0iI2M4N2YzYiIgLz48dGV4dCB4PSIzOTAiIHk9IjcwIiB0ZXh0LWFuY2hvcj0ibWlkZGxlIiBmb250LXNpemU9IjExIiBmb250LXdlaWdodD0iNjAwIiBmaWxsPSIjN2E0YTFhIj5NZXRhZGF0YTwvdGV4dD48dGV4dCB4PSIzMTUiIHk9Ijg4IiBmb250LXNpemU9IjEwIiBmaWxsPSIjMzMzIj5hbm5vdF9hbmFseXNlczwvdGV4dD48dGV4dCB4PSIzMTUiIHk9IjEwMyIgZm9udC1zaXplPSIxMCIgZmlsbD0iIzMzMyI+YW5ub3RfZmVhdHVyZXM8L3RleHQ+PHRleHQgeD0iMzE1IiB5PSIxMTgiIGZvbnQtc2l6ZT0iMTAiIGZpbGw9IiMzMzMiPmFubm90X2lzdGRzPC90ZXh0PjwhLS0gUUMvTWV0cmljcyBzbG90cyAtLT48cmVjdCB4PSI1MDAiIHk9IjUwIiB3aWR0aD0iMTgwIiBoZWlnaHQ9IjcwIiByeD0iNiIgZmlsbD0iI2Q0ZThkNCIgc3Ryb2tlPSIjNWE5YTVhIiAvPjx0ZXh0IHg9IjU5MCIgeT0iNzAiIHRleHQtYW5jaG9yPSJtaWRkbGUiIGZvbnQtc2l6ZT0iMTEiIGZvbnQtd2VpZ2h0PSI2MDAiIGZpbGw9IiMyYzVmMmMiPk1ldHJpY3M8L3RleHQ+PHRleHQgeD0iNTE1IiB5PSI4OCIgZm9udC1zaXplPSIxMCIgZmlsbD0iIzMzMyI+bWV0cmljc19xYzwvdGV4dD48dGV4dCB4PSI1MTUiIHk9IjEwMyIgZm9udC1zaXplPSIxMCIgZmlsbD0iIzMzMyI+bWV0cmljc19jYWxpYnJhdGlvbjwvdGV4dD48dGV4dCB4PSI1MTUiIHk9IjExOCIgZm9udC1zaXplPSIxMCIgZmlsbD0iIzMzMyI+c3RhdHVzX3Byb2Nlc3Npbmc8L3RleHQ+PCEtLSBQaXBlbGluZSAtLT48cmVjdCB4PSIxMDAiIHk9IjE0MCIgd2lkdGg9IjU4MCIgaGVpZ2h0PSI1NSIgcng9IjYiIGZpbGw9IiNlOGQ0ZTAiIHN0cm9rZT0iI2E0NWE4YSIgLz48dGV4dCB4PSIzOTAiIHk9IjE2MiIgdGV4dC1hbmNob3I9Im1pZGRsZSIgZm9udC1zaXplPSIxMSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iIzVhMmE0YSI+UHJvY2Vzc2luZwpQaXBlbGluZTwvdGV4dD48dGV4dCB4PSIzOTAiIHk9IjE4MiIgdGV4dC1hbmNob3I9Im1pZGRsZSIgZm9udC1zaXplPSIxMCIgZmlsbD0iIzMzMyI+aW1wb3J0CuKGkiBub3JtYWxpemUg4oaSIGNvcnJlY3RfZHJpZnQg4oaSIGNvcnJlY3RfYmF0Y2gg4oaSIHF1YW50aWZ5IOKGkiBRQyDihpIKZXhwb3J0PC90ZXh0Pjwvc3ZnPg==)

### Step-by-step inside QUANT:

``` r

library(mrmhub)

# 1. Import data into MRMhubExperiment
mexp <- import_data_csv_long("path/to/long.csv",
                             analysis_type = "lipidomics")

# 2. Add metadata (sample and feature annotations)
mexp <- add_metadata(mexp,
                     annot_analyses = annot_analyses,
                     annot_features = annot_features)

# 3. Set analysis order (critical for drift correction)
mexp <- set_analysis_order(mexp)

# 4. Normalize by internal standards
mexp <- normalize_by_istd(mexp)

# 5. Correct drift (within-batch signal drift)
mexp <- correct_drift_loess(mexp)

# 6. Correct batch effects (between-batch)
mexp <- correct_batch_centering(mexp)

# 7. Quantify (using ISTD or external calibration)
mexp <- quantify_by_istd(mexp)
# -- OR --
mexp <- quantify_by_calibration(mexp)

# 8. QC filtering
mexp <- calc_qc_metrics(mexp)
mexp <- filter_features_qc(mexp)

# 9. Export
save_report_xlsx(mexp, "results.xlsx")
```

## The MRMhubExperiment Object

**All slots (click to expand)**

| Slot | Purpose |
|----|----|
| `dataset_orig` | Original imported data (never modified) |
| `dataset` | Working data (modified by corrections/normalisation) |
| `dataset_filtered` | Final filtered data after QC |
| `annot_analyses` | Sample/run metadata (run order, batch, sample type) |
| `annot_features` | Feature metadata (compound name, ISTD assignment, RT) |
| `annot_istds` | ISTD concentrations and assignments |
| `metrics_qc` | QC metrics per feature (CV, bias, n) |
| `metrics_calibration` | Calibration curve statistics |
| `status_processing` | Current pipeline status |

## Key Accessor Functions

``` r

# Get the current working dataset as a tibble
get_analyticaldata(mexp)

# Counts
get_feature_count(mexp)
get_analysis_count(mexp)

# Feature list
get_featurelist(mexp)

# Batch boundaries (for plotting)
get_batch_boundaries(mexp)

# Run start/end
get_analysis_start(mexp)
get_analysis_end(mexp)
```

## Decision Points

| Question | Answer |
|----|----|
| Do I need INTEGRATOR? | Only if starting from raw vendor files (.wiff, .d). If you already have peak areas in CSV, skip directly to QUANT. |
| Which importer? | See [Import and prepare data files](https://slinghub.github.io/MRMhub/quant/articles/manual-05a-which-importer.md) |
| ISTD or external calibration? | ISTD: relative quantification. External calibration: absolute concentrations with calibration curve. |
| Drift correction needed? | Check with [`plot_runscatter()`](https://slinghub.github.io/MRMhub/quant/reference/plot_runscatter.md) — if QC samples show systematic trend, apply correction. |

## Next Steps

- [Your First
  Analysis](https://slinghub.github.io/MRMhub/quant/articles/tutorial-00-first-analysis.md)
  — try the pipeline hands-on
- [Key Concepts &
  Glossary](https://slinghub.github.io/MRMhub/quant/articles/manual-00-key-concepts.md)
  — terminology reference
- [Import and prepare data
  files](https://slinghub.github.io/MRMhub/quant/articles/manual-05a-which-importer.md)
  — choose the right entry point
