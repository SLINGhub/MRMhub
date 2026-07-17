# S4 class representing the MRMhub dataset

The `MRMhubExperiment` object is the core data structure utilized within
the MRMhub workflow, encapsulating all relevant experimental data and
metadata. It also includes processing results, details of the applied
processing steps, and the current status of the data.

## Slots

- `title`:

  Title of the experiment

- `analysis_type`:

  Analysis type, one of "lipidomics", "metabolomics", "externalcalib",
  "others"

- `feature_intensity_var`:

  Feature variable used as default for calculations

- `conc_analyte_unit`:

  Unit of the analyte amount underlying `feature_conc`, set when the
  data are quantitated. `"pmol"` or `"ng"` for ISTD quantitation (see
  [`quantify_by_istd()`](https://slinghub.github.io/MRMhub/quant/reference/quantify_by_istd.md)),
  or the calibrant concentration unit (e.g. `"nmol/L"`) for calibration
  quantitation. Divided by `sample_amount_unit` by `get_conc_unit()` to
  name the unit of `feature_conc`. `NA` when not quantitated.

- `dataset_orig`:

  Original imported analysis data. Required fields:

- `dataset`:

  Processed analysis data. Required fields:

- `dataset_filtered`:

  Processed analysis data. Required fields:

- `annot_analyses`:

  Annotation of analyses/runs

- `annot_features`:

  Annotation of measured features.

- `annot_istds`:

  Annotation of Internal Standard concs.

- `annot_responsecurves`:

  Annotation of response curves (RQC). Required fields

- `annot_qcconcentrations`:

  Annotation of calibration curves. Required fields

- `annot_studysamples`:

  Annotation of study samples. Required fields:

- `annot_batches`:

  Annotation of batches. Required fields:

- `metrics_qc`:

  QC information for each measured feature

- `metrics_calibration`:

  Calibration metrics calculated from external calibration curves for
  each measured feature

- `parameters_processing`:

  Values of parameters used for the different processing steps

- `status_processing`:

  Status within the data processing workflow

- `is_istd_normalized`:

  Flag if data has been ISTD normalized

- `is_quantitated`:

  Flag if data has been quantitated using ISTD and sample amount

- `is_filtered`:

  Flag if data has been filtered based on QC parameters

- `is_isotope_corr`:

  Flag if one or more features have been isotope corrected

- `has_outliers_tech`:

  Flag if data has technical analysis/sample outliers

- `analyses_excluded`:

  Analyses excluded from processing, plots and reporting, unless
  explicitly requested

- `features_excluded`:

  Features excluded from processing, plots and reporting, unless
  explicitly requested

- `var_drift_corrected`:

  List indicating which variables are drift corrected

- `var_batch_corrected`:

  List indicating which variables are batch corrected
