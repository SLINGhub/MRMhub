# Key Concepts & Glossary

Manual

MRMhub organizes targeted mass spectrometry data around two axes:
**analyses**, the individual injections or samples in a run, and
**features**, the distinct signals extracted from the MS data. Every
measurement is a value — typically a peak area — at the intersection of
one analysis and one feature, and all of these values are held together
with their metadata in a single object, the `MRMhubExperiment`.
Functions take an `MRMhubExperiment` and return an updated one, and
these calls are chained together to build a workflow. See [The
MRMhubExperiment Data
Object](https://slinghub.github.io/MRMhub/quant/articles/manual-02-data-object.md)
for how the object is structured and [Sample Types & QC
Roles](https://slinghub.github.io/MRMhub/quant/articles/manual-06-sample-types.md)
for the sample roles that drive its QC logic.

## Glossary

A feature and an analyte are not one-to-one: one analyte can give
several features (isotopes, adducts, transitions), and one feature can
carry several analytes when they are isobaric or isomeric (e.g. SM/PC).
The `feature_id` names the signal, while the `analyte_id` names the
compound.

## Reading the function names

A naming convention runs through the public API, so once it is
internalised the function names are largely predictable:

- `import_data_*()` — read raw integrated peak data from a given source
- `import_metadata_*()` — read an annotation table from a given source
- [`add_metadata()`](https://slinghub.github.io/MRMhub/quant/reference/add_metadata.md)
  / `set_*()` — attach annotation or assign a slot on the experiment
- `normalize_by_*()` — divide one variable by another (e.g. by ISTD)
- `correct_drift_*()` / `correct_batch_*()` — apply a named correction
  model
- `quantify_by_*()` — compute concentration values via a given strategy
- `calc_*()` — compute per-feature or per-analysis metrics
- `filter_*()` — apply pass/fail thresholds
- `plot_*()` — return a ggplot2 object
- `save_*()` — write to disk
- `get_*()` — read a derived value from the experiment

## Next steps

- [The MRMhubExperiment Data
  Object](https://slinghub.github.io/MRMhub/quant/articles/manual-02-data-object.md)
  — the tables and identifiers in detail
- [Sample Types & QC
  Roles](https://slinghub.github.io/MRMhub/quant/articles/manual-06-sample-types.md)
  — the `qc_type` labels used throughout
- [Basic MRMhub
  Workflow](https://slinghub.github.io/MRMhub/quant/articles/tutorial-02-basic-workflow.md)
  — these functions in a real script
- [Function
  reference](https://slinghub.github.io/MRMhub/quant/reference/index.md)
  — every function with full parameter detail
