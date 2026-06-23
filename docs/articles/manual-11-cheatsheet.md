# Function Cheatsheet

The `mrmhub` package exposes more than two hundred functions across
import, processing, plotting, and reporting. A typical end-to-end
workflow uses fewer than fifteen of them, in roughly this order. Use
this page as a quick reminder of which function does what; click any
function name for the full reference.

## Workflow order

| Stage | Function | Purpose |
|----|----|----|
| Import | [`import_data_mrmhub()`](https://slinghub.github.io/MRMhub/quant/reference/import_data_mrmhub.md) / [`import_data_masshunter()`](https://slinghub.github.io/MRMhub/quant/reference/import_data_masshunter.md) / [`import_data_skyline()`](https://slinghub.github.io/MRMhub/quant/reference/import_data_skyline.md) | Read integrated peak data |
| Metadata | [`import_metadata_msorganiser()`](https://slinghub.github.io/MRMhub/quant/reference/import_metadata_msorganiser.md) / [`add_metadata()`](https://slinghub.github.io/MRMhub/quant/reference/add_metadata.md) | Link analysis / feature / ISTD annotation |
| Setup | [`set_analysis_order()`](https://slinghub.github.io/MRMhub/quant/reference/set_analysis_order.md) | Set acquisition order |
| Normalisation | [`normalize_by_istd()`](https://slinghub.github.io/MRMhub/quant/reference/normalize_by_istd.md) | Per-feature ISTD normalisation |
| Drift correction | [`correct_drift_loess()`](https://slinghub.github.io/MRMhub/quant/reference/correct_drift_loess.md) / [`correct_drift_gaussiankernel()`](https://slinghub.github.io/MRMhub/quant/reference/correct_drift_gaussiankernel.md) | Smooth run-order drift |
| Batch correction | [`correct_batch_centering()`](https://slinghub.github.io/MRMhub/quant/reference/correct_batch_centering.md) | Align medians across batches |
| Quantitation | [`quantify_by_istd()`](https://slinghub.github.io/MRMhub/quant/reference/quantify_by_istd.md) / [`quantify_by_calibration()`](https://slinghub.github.io/MRMhub/quant/reference/quantify_by_calibration.md) | Concentration values |
| QC metrics | [`calc_qc_metrics()`](https://slinghub.github.io/MRMhub/quant/reference/calc_qc_metrics.md) | Per-feature CV, bias, etc. |
| Filtering | [`filter_features_qc()`](https://slinghub.github.io/MRMhub/quant/reference/filter_features_qc.md) | Pass/fail features against thresholds |
| Reporting | [`save_report_xlsx()`](https://slinghub.github.io/MRMhub/quant/reference/save_report_xlsx.md) / [`save_dataset_csv()`](https://slinghub.github.io/MRMhub/quant/reference/save_dataset_csv.md) | Export final dataset |

## Visualisation at each stage

Plotting functions follow the same workflow logic — see [Visualisation
Functions](https://slinghub.github.io/MRMhub/quant/articles/manual-08-visualization.md)
for the grouped reference, or [The MRMhub
Workflow](https://slinghub.github.io/MRMhub/quant/articles/tutorial-02-basic-workflow.md)
for a walked-through example.

## Reading the function names

A naming convention runs through the public API. Once internalised,
function names mostly predict themselves:

- `import_data_*()` — read raw integrated peak data from a given source
- `import_metadata_*()` — read an annotation table from a given source
- `set_*()` — assign a slot on the experiment
- [`add_metadata()`](https://slinghub.github.io/MRMhub/quant/reference/add_metadata.md)
  — attach annotation
- `normalize_by_*()` — divide one variable by another (e.g. by ISTD)
- `correct_drift_*()` / `correct_batch_*()` — apply a named correction
  model
- `quantify_by_*()` — compute concentration values via a given strategy
- `calc_*()` — compute per-feature or per-analysis metrics
- `filter_*()` — apply pass/fail thresholds
- `plot_*()` — return a ggplot2 object
- `save_*()` — write to disk
- `get_*()` — read a derived value from the experiment

See [Key Concepts &
Glossary](https://slinghub.github.io/MRMhub/quant/articles/manual-00-key-concepts.md)
for the vocabulary (`MRMhubExperiment`, `analysis_id`, `feature_id`,
`qc_type`, `ISTD`, …).

## See Also

- [The MRMhub
  Workflow](https://slinghub.github.io/MRMhub/quant/articles/tutorial-02-basic-workflow.md)
  — these functions in a real script
- [Key Concepts &
  Glossary](https://slinghub.github.io/MRMhub/quant/articles/manual-00-key-concepts.md)
  — vocabulary used in every function
- [Visualisation
  Functions](https://slinghub.github.io/MRMhub/quant/articles/manual-08-visualization.md)
  — plotting reference grouped by stage
- [Full
  Reference](https://slinghub.github.io/MRMhub/quant/reference/index.md)
  — every function with full parameter detail
