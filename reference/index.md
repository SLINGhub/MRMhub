# Package index

## QUANT R package reference

Functions to create, access and query MRMhubExperiment objects, which
are the central data object in the MRMhub workflow.

- [`MRMhubExperiment()`](https://slinghub.github.io/MRMhub/reference/MRMhubExperiment.md)
  : Constructor for the MRMhubExperiment object.
- [`MRMhubExperiment-class`](https://slinghub.github.io/MRMhub/reference/MRMhubExperiment-class.md)
  : S4 Class Representing the MRMhub Dataset
- [`` `$`( ``*`<MRMhubExperiment>`*`)`](https://slinghub.github.io/MRMhub/reference/cash-MRMhubExperiment-method.md)
  : Access Slots of a MRMhubExperiment Object via \$ Syntax
- [`set_analysis_order()`](https://slinghub.github.io/MRMhub/reference/set_analysis_order.md)
  : Set Analysis Order
- [`get_batch_boundaries()`](https://slinghub.github.io/MRMhub/reference/get_batch_boundaries.md)
  : Get the start and end analysis numbers of specified batches
- [`data_sum_features()`](https://slinghub.github.io/MRMhub/reference/data_sum_features.md)
  : Sum up feature intensities per analyte
- [`exclude_analyses()`](https://slinghub.github.io/MRMhub/reference/exclude_analyses.md)
  : Exclude analyses from the dataset
- [`exclude_features()`](https://slinghub.github.io/MRMhub/reference/exclude_features.md)
  : Exclude features from the dataset
- [`get_analyticaldata()`](https://slinghub.github.io/MRMhub/reference/get_analyticaldata.md)
  : Get the annotated or the originally imported analytical data
- [`set_intensity_var()`](https://slinghub.github.io/MRMhub/reference/set_intensity_var.md)
  : Set default variable to be used as feature raw signal value
- [`get_analysis_count()`](https://slinghub.github.io/MRMhub/reference/get_analysis_count.md)
  : Get the number of analyses in the dataset
- [`get_analyis_start()`](https://slinghub.github.io/MRMhub/reference/get_analyis_start.md)
  : Get the start time of the analysis sequence
- [`get_analyis_end()`](https://slinghub.github.io/MRMhub/reference/get_analyis_end.md)
  : Get the end time of the analysis sequence
- [`get_analysis_breaks()`](https://slinghub.github.io/MRMhub/reference/get_analysis_breaks.md)
  : Get the number of analysis breaks in the analysis
- [`get_analysis_duration()`](https://slinghub.github.io/MRMhub/reference/get_analysis_duration.md)
  : Get the total duration of the analysis
- [`get_runtime_median()`](https://slinghub.github.io/MRMhub/reference/get_runtime_median.md)
  : Get the median run time
- [`get_feature_count()`](https://slinghub.github.io/MRMhub/reference/get_feature_count.md)
  : Get the number of features in the dataset
- [`get_featurelist()`](https://slinghub.github.io/MRMhub/reference/get_featurelist.md)
  : Get feature IDs

## Analysis data import

Functions to import analytical data from different sources into
MRMhubExperiment objects. Additionally, the file parser function used
internally by these import functions are available for direct use,
i.e. to import different analytical data into data frames.

- [`import_data_mrmhub()`](https://slinghub.github.io/MRMhub/reference/import_data_mrmhub.md)
  : Import MRMhub peak integration results
- [`import_data_masshunter()`](https://slinghub.github.io/MRMhub/reference/import_data_masshunter.md)
  : Import Agilent MassHunter Quantitative Analysis CSV files
- [`import_data_skyline()`](https://slinghub.github.io/MRMhub/reference/import_data_skyline.md)
  : Import Skyline Peak Integration Results
- [`import_data_csv_wide()`](https://slinghub.github.io/MRMhub/reference/import_data_csv_wide.md)
  : Import Analysis Results from Plain Wide-Format CSV Files
- [`import_data_csv_long()`](https://slinghub.github.io/MRMhub/reference/import_data_csv_long.md)
  : Import Analysis Results from Long Format CSV Files
- [`parse_mrmhub_result()`](https://slinghub.github.io/MRMhub/reference/parse_mrmhub_result.md)
  : Parses MRMhub peak integration results into a tibble
- [`parse_masshunter_csv()`](https://slinghub.github.io/MRMhub/reference/parse_masshunter_csv.md)
  : Reads and parses one Agilent MassHunter Quant CSV result file
- [`parse_skyline_result()`](https://slinghub.github.io/MRMhub/reference/parse_skyline_result.md)
  : Parses skyline peak integration results into a tibble
- [`parse_plain_wide_csv()`](https://slinghub.github.io/MRMhub/reference/parse_plain_wide_csv.md)
  : Parses a plain wide CSV file
- [`parse_plain_long_csv()`](https://slinghub.github.io/MRMhub/reference/parse_plain_long_csv.md)
  : Parses a plain long CSV file
- [`import_data_csv()`](https://slinghub.github.io/MRMhub/reference/import_data_csv.md)
  : (Depreciated) Import Wide CSV Files

## Metadata import

Functions to import metadata describing the analyses (samples), features
(analytes), internal standards and other relevant information from the
MRMhub Excel template or CSV files.

- [`import_metadata_analyses()`](https://slinghub.github.io/MRMhub/reference/import_metadata_analyses.md)
  : Import analysis metadata
- [`import_metadata_features()`](https://slinghub.github.io/MRMhub/reference/import_metadata_features.md)
  : Import feature metadata
- [`import_metadata_istds()`](https://slinghub.github.io/MRMhub/reference/import_metadata_istds.md)
  : Import Internal Standards (ISTD) metadata
- [`import_metadata_responsecurves()`](https://slinghub.github.io/MRMhub/reference/import_metadata_responsecurves.md)
  : Import response curves metadata
- [`import_metadata_qcconcentrations()`](https://slinghub.github.io/MRMhub/reference/import_metadata_qcconcentrations.md)
  : Import calibration curves metadata
- [`import_metadata_msorganiser()`](https://slinghub.github.io/MRMhub/reference/import_metadata_msorganiser.md)
  : Import Metadata from a MRMhub Metadata Organizer file
- [`import_metadata_from_data()`](https://slinghub.github.io/MRMhub/reference/import_metadata_from_data.md)
  : Retrieve Metadata from Imported Analysis Data
- [`save_metadata_templates()`](https://slinghub.github.io/MRMhub/reference/save_metadata_templates.md)
  : Saves a Excel (xlsx) file with metadata templates
- [`save_metadata_msorganiser_template()`](https://slinghub.github.io/MRMhub/reference/save_metadata_msorganiser_template.md)
  : Saves a MRMhub Metadata Organizer template
- [`add_metadata()`](https://slinghub.github.io/MRMhub/reference/add_metadata.md)
  : Add metadata an MRMhubExperiment object
- [`assert_metadata()`](https://slinghub.github.io/MRMhub/reference/assert_metadata.md)
  : Add metadata an MRMhubExperiment object

## Isotope correction

Functions to perform type II isotopic correction

- [`correct_interferences()`](https://slinghub.github.io/MRMhub/reference/correct_interferences.md)
  : Apply interference correction
- [`correct_interference_manual()`](https://slinghub.github.io/MRMhub/reference/correct_interference_manual.md)
  : Manual isotopic interference correction

## External Calibration

Function to plot and analyze external calibration curves

- [`quantify_by_calibration()`](https://slinghub.github.io/MRMhub/reference/quantify_by_calibration.md)
  : Calculate concentrations based on external calibration
- [`plot_calibrationcurves()`](https://slinghub.github.io/MRMhub/reference/plot_calibrationcurves.md)
  : Plot Calibration Curves
- [`calc_calibration_results()`](https://slinghub.github.io/MRMhub/reference/calc_calibration_results.md)
  : Calculate external calibration curve results
- [`get_calibration_metrics()`](https://slinghub.github.io/MRMhub/reference/get_calibration_metrics.md)
  : Get Calibration Metrics
- [`get_qc_bias_variability()`](https://slinghub.github.io/MRMhub/reference/get_qc_bias_variability.md)
  : Retrieve Calibration Regression Results

## Normalization, Quantification

Functions for normalization by internal standards and sample amounts, to
calculate analyte concentrations based on internal standards amounts or
external calibration curves. Function to for absolute or relative
calibration using a reference sample.

- [`normalize_by_istd()`](https://slinghub.github.io/MRMhub/reference/normalize_by_istd.md)
  : Normalize Feature Intensities Using Internal Standards
- [`quantify_by_istd()`](https://slinghub.github.io/MRMhub/reference/quantify_by_istd.md)
  : Calculate Analyte Concentrations Using Internal Standards
- [`quantify_by_calibration()`](https://slinghub.github.io/MRMhub/reference/quantify_by_calibration.md)
  : Calculate concentrations based on external calibration
- [`calibrate_by_reference()`](https://slinghub.github.io/MRMhub/reference/calibrate_by_reference.md)
  : Calibrate Features Values Using Reference Sample

## Drift/Batch Correction

Function for drift and batch correction correction

- [`correct_drift_gaussiankernel()`](https://slinghub.github.io/MRMhub/reference/correct_drift_gaussiankernel.md)
  : Drift Correction by Gaussian Kernel Smoothing
- [`correct_drift_cubicspline()`](https://slinghub.github.io/MRMhub/reference/correct_drift_cubicspline.md)
  : Drift Correction by Cubic Spline Smoothing
- [`correct_drift_loess()`](https://slinghub.github.io/MRMhub/reference/correct_drift_loess.md)
  : Drift Correction by LOESS Smoothing
- [`correct_drift_gam()`](https://slinghub.github.io/MRMhub/reference/correct_drift_gam.md)
  : Drift Correction by Generalized Additive Model (GAM) Smoothing
- [`correct_batch_centering()`](https://slinghub.github.io/MRMhub/reference/correct_batch_centering.md)
  : Batch Centering Correction

## Quality Control and Filtering

Functions to calculate feature QC metrics and apply QC filtering, and
vizualize the filtering results.

- [`calc_qc_metrics()`](https://slinghub.github.io/MRMhub/reference/calc_qc_metrics.md)
  : Calculate Quality Control (QC) Metrics for Features
- [`filter_features_qc()`](https://slinghub.github.io/MRMhub/reference/filter_features_qc.md)
  : Feature Filtering Based on QC Criteria
- [`detect_outlier_pca()`](https://slinghub.github.io/MRMhub/reference/detect_outlier_pca.md)
  : Get list of analyses classified as technical outliers
- [`plot_qc_summary_byclass()`](https://slinghub.github.io/MRMhub/reference/plot_qc_summary_byclass.md)
  : Plot QC Filtering Summary by Feature Class
- [`plot_qc_summary_overall()`](https://slinghub.github.io/MRMhub/reference/plot_qc_summary_overall.md)
  : Plot Overall QC Filtering Summary
- [`plot_abundanceprofile()`](https://slinghub.github.io/MRMhub/reference/plot_abundanceprofile.md)
  : Plot Abundance Profile

## Quality Control Plots

Functions to plots diverse QC visualizatios.

- [`plot_runsequence()`](https://slinghub.github.io/MRMhub/reference/plot_runsequence.md)
  : RunSequence Plot
- [`plot_runscatter()`](https://slinghub.github.io/MRMhub/reference/plot_runscatter.md)
  : RunScatter Plot
- [`plot_rla_boxplot()`](https://slinghub.github.io/MRMhub/reference/plot_rla_boxplot.md)
  : Relative Log Abundance (RLA) Plot
- [`plot_pca()`](https://slinghub.github.io/MRMhub/reference/plot_pca.md)
  : PCA Plot for Quality Control
- [`plot_pca_loading()`](https://slinghub.github.io/MRMhub/reference/plot_pca_loading.md)
  : Plot PCA loadings
- [`plot_feature_correlations()`](https://slinghub.github.io/MRMhub/reference/plot_feature_correlations.md)
  : Plot Highly Correlated Feature Pairs
- [`plot_rt_vs_chain()`](https://slinghub.github.io/MRMhub/reference/plot_rt_vs_chain.md)
  : Plot Retention Time versus Chain Length and Saturation
- [`plot_qc_matrixeffects()`](https://slinghub.github.io/MRMhub/reference/plot_qc_matrixeffects.md)
  : Plot standardized feature intensities grouped by QC type
- [`plot_normalization_qc()`](https://slinghub.github.io/MRMhub/reference/plot_normalization_qc.md)
  : Compare Feature Variability Before and After Normalization
- [`plot_qcmetrics_comparison()`](https://slinghub.github.io/MRMhub/reference/plot_qcmetrics_comparison.md)
  : Comparison of two feature QC metrics variables
- [`plot_qc_interferences()`](https://slinghub.github.io/MRMhub/reference/plot_qc_interferences.md)
  : Plot the results of interference correction

## Response Curves

Functions to calculate and visualize response curves

- [`plot_responsecurves()`](https://slinghub.github.io/MRMhub/reference/plot_responsecurves.md)
  : Plot Response Curves
- [`get_response_curve_stats()`](https://slinghub.github.io/MRMhub/reference/get_response_curve_stats.md)
  : Linear Regression Statistics of Response Curves

## Data Reporting and Sharing

Functions to export processed and raw datasets and the processing steps
in different formats.

- [`save_report_xlsx()`](https://slinghub.github.io/MRMhub/reference/save_report_xlsx.md)
  : Write Data Processing Report (EXCEL)
- [`save_dataset_csv()`](https://slinghub.github.io/MRMhub/reference/save_dataset_csv.md)
  : Export Data to CSV file
- [`save_feature_qc_metrics()`](https://slinghub.github.io/MRMhub/reference/save_feature_qc_metrics.md)
  : Save Feature QC Metrics to CSV

## Lipidomics

Functions specific to lipidomics data processing and analysis.

- [`parse_lipid_feature_names()`](https://slinghub.github.io/MRMhub/reference/parse_lipid_feature_names.md)
  : Get lipid class, species and transition names

## Datasets

Example datasets for testing and demonstration.

- [`lipidomics_dataset`](https://slinghub.github.io/MRMhub/reference/lipidomics_dataset.md)
  : Plasma Lipidomics Dataset with Metadata
- [`quant_lcms_dataset`](https://slinghub.github.io/MRMhub/reference/quant_lcms_dataset.md)
  : LC-MS Dataset with External Calibration Curve and Metadata
- [`data_load_example()`](https://slinghub.github.io/MRMhub/reference/data_load_example.md)
  : Load an example MRMhubExperiment dataset

## Helper functions

A collection of functions that may be useful in the context of mass
spectrometry is also available.

- [`cv()`](https://slinghub.github.io/MRMhub/reference/cv.md) : Percent
  coefficient of variation (%CV)
- [`cv_log()`](https://slinghub.github.io/MRMhub/reference/cv_log.md) :
  Percent coefficient of variation (%CV) based on log-transformation
- [`calc_average_molweight()`](https://slinghub.github.io/MRMhub/reference/calc_average_molweight.md)
  : Calculate Average Molecular Weight from Chemical Formulas
- [`save_dataset_csv()`](https://slinghub.github.io/MRMhub/reference/save_dataset_csv.md)
  : Export Data to CSV file
- [`fun_correct_drift()`](https://slinghub.github.io/MRMhub/reference/fun_correct_drift.md)
  : Drift Correction by Custom Function
- [`fun_gauss.kernel.smooth()`](https://slinghub.github.io/MRMhub/reference/fun_gauss.kernel.smooth.md)
  : Gaussian Kernel smoothing helper function
- [`fun_loess()`](https://slinghub.github.io/MRMhub/reference/fun_loess.md)
  : Loess smoothing helper function
- [`fun_cspline()`](https://slinghub.github.io/MRMhub/reference/fun_cspline.md)
  : Cubic spline smoothing helper function
- [`fun_gam_smooth()`](https://slinghub.github.io/MRMhub/reference/fun_gam_smooth.md)
  : Generalized Additive Model (GAM) smoothing helper function
- [`get_mad_tails()`](https://slinghub.github.io/MRMhub/reference/get_mad_tails.md)
  : Get MAD-based tails
- [`get_iqr_tails()`](https://slinghub.github.io/MRMhub/reference/get_iqr_tails.md)
  : Get Tukey's IQR fences
- [`get_outlier_bounds()`](https://slinghub.github.io/MRMhub/reference/get_outlier_bounds.md)
  : Get outlier bounds via different methods
- [`order_chained_columns_tbl()`](https://slinghub.github.io/MRMhub/reference/order_chained_columns_tbl.md)
  : Reorder Data Frame based on a chain of linked values in two columns.
