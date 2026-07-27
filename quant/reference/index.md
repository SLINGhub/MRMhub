# Package index

## Getting started

Functions to validate your R environment and explore the MRMhub workflow
interactively.

- [`check_setup()`](https://slinghub.github.io/MRMhub/quant/reference/check_setup.md)
  : Check MRMhub setup
- [`build_workflow()`](https://slinghub.github.io/MRMhub/quant/reference/build_workflow.md)
  : Launch the MRMhub Workflow Builder
- [`generate_workflow_qmd()`](https://slinghub.github.io/MRMhub/quant/reference/generate_workflow_qmd.md)
  : Generate a runnable Quarto (.qmd) mrmhub workflow

## QUANT R package reference

Functions to create, access and query MRMhubExperiment objects, which
are the central data object in the MRMhub workflow.

- [`MRMhubExperiment()`](https://slinghub.github.io/MRMhub/quant/reference/MRMhubExperiment.md)
  :

  Constructor for the `MRMhubExperiment` object

- [`MRMhubExperiment-class`](https://slinghub.github.io/MRMhub/quant/reference/MRMhubExperiment-class.md)
  : S4 class representing the MRMhub dataset

- [`` `$`( ``*`<MRMhubExperiment>`*`)`](https://slinghub.github.io/MRMhub/quant/reference/cash-MRMhubExperiment-method.md)
  :

  Access slots of a `MRMhubExperiment` object via \$ syntax

- [`mrmhub_status()`](https://slinghub.github.io/MRMhub/quant/reference/mrmhub_status.md)
  :

  Detailed processing and metadata report for a `MRMhubExperiment`

- [`set_analysis_order()`](https://slinghub.github.io/MRMhub/quant/reference/set_analysis_order.md)
  : Set analysis order

- [`get_batch_boundaries()`](https://slinghub.github.io/MRMhub/quant/reference/get_batch_boundaries.md)
  : Get the start and end analysis numbers of specified batches

- [`data_sum_features()`](https://slinghub.github.io/MRMhub/quant/reference/data_sum_features.md)
  : Sum up feature intensities per analyte

- [`exclude_analyses()`](https://slinghub.github.io/MRMhub/quant/reference/exclude_analyses.md)
  : Exclude analyses from the dataset

- [`exclude_features()`](https://slinghub.github.io/MRMhub/quant/reference/exclude_features.md)
  : Exclude features from the dataset

- [`get_analyticaldata()`](https://slinghub.github.io/MRMhub/quant/reference/get_analyticaldata.md)
  : Get the annotated or the originally imported analytical data

- [`set_intensity_var()`](https://slinghub.github.io/MRMhub/quant/reference/set_intensity_var.md)
  : Set default variable to be used as feature raw signal value

- [`get_analysis_count()`](https://slinghub.github.io/MRMhub/quant/reference/get_analysis_count.md)
  : Get the number of analyses in the dataset

- [`get_analyis_start()`](https://slinghub.github.io/MRMhub/quant/reference/get_analyis_start.md)
  : Get the start time of the analysis sequence

- [`get_analyis_end()`](https://slinghub.github.io/MRMhub/quant/reference/get_analyis_end.md)
  : Get the end time of the analysis sequence

- [`get_analysis_breaks()`](https://slinghub.github.io/MRMhub/quant/reference/get_analysis_breaks.md)
  : Get the number of analysis breaks in the analysis

- [`get_analysis_duration()`](https://slinghub.github.io/MRMhub/quant/reference/get_analysis_duration.md)
  : Get the total duration of the analysis

- [`get_runtime_median()`](https://slinghub.github.io/MRMhub/quant/reference/get_runtime_median.md)
  : Get the median run time

- [`get_feature_count()`](https://slinghub.github.io/MRMhub/quant/reference/get_feature_count.md)
  : Get the number of features in the dataset

- [`get_featurelist()`](https://slinghub.github.io/MRMhub/quant/reference/get_featurelist.md)
  : Get feature IDs

## Analysis data import

Functions to import analytical data from different sources into
MRMhubExperiment objects. Additionally, the file parser function used
internally by these import functions are available for direct use,
i.e. to import different analytical data into data frames.

- [`import_data_mrmhub()`](https://slinghub.github.io/MRMhub/quant/reference/import_data_mrmhub.md)
  : Import MRMhub peak integration results
- [`import_data_masshunter()`](https://slinghub.github.io/MRMhub/quant/reference/import_data_masshunter.md)
  : Import Agilent MassHunter Quantitative Analysis CSV files
- [`import_data_skyline()`](https://slinghub.github.io/MRMhub/quant/reference/import_data_skyline.md)
  : Import Skyline peak integration results
- [`import_data_csv_wide()`](https://slinghub.github.io/MRMhub/quant/reference/import_data_csv_wide.md)
  : Import analysis results from plain wide-format CSV files
- [`import_data_csv_long()`](https://slinghub.github.io/MRMhub/quant/reference/import_data_csv_long.md)
  : Import analysis results from long-format CSV files
- [`import_data_mztab()`](https://slinghub.github.io/MRMhub/quant/reference/import_data_mztab.md)
  : Import data from an mzTab-M file
- [`parse_mrmhub_result()`](https://slinghub.github.io/MRMhub/quant/reference/parse_mrmhub_result.md)
  : Parses MRMhub peak integration results into a tibble
- [`parse_masshunter_csv()`](https://slinghub.github.io/MRMhub/quant/reference/parse_masshunter_csv.md)
  : Reads and parses one Agilent MassHunter Quant CSV result file
- [`parse_skyline_result()`](https://slinghub.github.io/MRMhub/quant/reference/parse_skyline_result.md)
  : Parses skyline peak integration results into a tibble
- [`parse_plain_wide_csv()`](https://slinghub.github.io/MRMhub/quant/reference/parse_plain_wide_csv.md)
  : Parses a plain wide CSV file
- [`parse_plain_long_csv()`](https://slinghub.github.io/MRMhub/quant/reference/parse_plain_long_csv.md)
  : Parses a plain long CSV file
- [`import_data_csv()`](https://slinghub.github.io/MRMhub/quant/reference/import_data_csv.md)
  : (Deprecated) Import wide CSV files

## Metadata import

Functions to import metadata describing the analyses (samples), features
(analytes), internal standards and other relevant information from the
MRMhub Excel template or CSV files.

- [`import_metadata_analyses()`](https://slinghub.github.io/MRMhub/quant/reference/import_metadata_analyses.md)
  : Import analysis metadata

- [`import_metadata_features()`](https://slinghub.github.io/MRMhub/quant/reference/import_metadata_features.md)
  : Import feature metadata

- [`import_metadata_istds()`](https://slinghub.github.io/MRMhub/quant/reference/import_metadata_istds.md)
  : Import internal standards (ISTD) metadata

- [`import_metadata_responsecurves()`](https://slinghub.github.io/MRMhub/quant/reference/import_metadata_responsecurves.md)
  : Import response curves metadata

- [`import_metadata_qcconcentrations()`](https://slinghub.github.io/MRMhub/quant/reference/import_metadata_qcconcentrations.md)
  : Import calibration curves metadata

- [`import_metadata_msorganiser()`](https://slinghub.github.io/MRMhub/quant/reference/import_metadata_msorganiser.md)
  : Import metadata from a MRMhub Metadata Organizer file

- [`import_metadata_from_data()`](https://slinghub.github.io/MRMhub/quant/reference/import_metadata_from_data.md)
  : Retrieve metadata from imported analysis data

- [`save_metadata_templates()`](https://slinghub.github.io/MRMhub/quant/reference/save_metadata_templates.md)
  : Saves an Excel (xlsx) file with metadata templates

- [`save_metadata_msorganiser_template()`](https://slinghub.github.io/MRMhub/quant/reference/save_metadata_msorganiser_template.md)
  : Saves a MRMhub Metadata Organizer template

- [`add_metadata()`](https://slinghub.github.io/MRMhub/quant/reference/add_metadata.md)
  :

  Add metadata to an `MRMhubExperiment` object

## Isotope correction

Functions to perform type II isotopic interference correction

- [`calc_isotopic_interferences()`](https://slinghub.github.io/MRMhub/quant/reference/calc_isotopic_interferences.md)
  : Derive isotopic interference relationships
- [`correct_isotopic_interferences()`](https://slinghub.github.io/MRMhub/quant/reference/correct_isotopic_interferences.md)
  : Correct automatically derived isotopic interferences
- [`correct_custom_interferences()`](https://slinghub.github.io/MRMhub/quant/reference/correct_custom_interferences.md)
  : Correct declared (custom) interferences
- [`correct_interference_manual()`](https://slinghub.github.io/MRMhub/quant/reference/correct_interference_manual.md)
  : Manual isotopic interference correction
- [`summarize_interferences()`](https://slinghub.github.io/MRMhub/quant/reference/summarize_interferences.md)
  : Summarize interference relationships
- [`licar_pattern_choices()`](https://slinghub.github.io/MRMhub/quant/reference/licar_pattern_choices.md)
  : Valid MRM-pattern labels

## External Calibration

Function to plot and analyze external calibration curves

- [`quantify_by_calibration()`](https://slinghub.github.io/MRMhub/quant/reference/quantify_by_calibration.md)
  : Calculate concentrations based on external calibration
- [`plot_calibrationcurves()`](https://slinghub.github.io/MRMhub/quant/reference/plot_calibrationcurves.md)
  : Plot calibration curves
- [`calc_calibration_results()`](https://slinghub.github.io/MRMhub/quant/reference/calc_calibration_results.md)
  : Calculate external calibration curve results
- [`get_calibration_metrics()`](https://slinghub.github.io/MRMhub/quant/reference/get_calibration_metrics.md)
  : Get calibration metrics
- [`get_qc_bias_variability()`](https://slinghub.github.io/MRMhub/quant/reference/get_qc_bias_variability.md)
  : Retrieve QC bias and variability metrics

## Normalization, Quantification

Functions for normalization by internal standards and sample amounts, to
calculate analyte concentrations based on internal standards amounts or
external calibration curves. Function to for absolute or relative
calibration using a reference sample.

- [`normalize_by_istd()`](https://slinghub.github.io/MRMhub/quant/reference/normalize_by_istd.md)
  : Normalize feature intensities using internal standards
- [`quantify_by_istd()`](https://slinghub.github.io/MRMhub/quant/reference/quantify_by_istd.md)
  : Calculate analyte concentrations using internal standards
- [`calibrate_by_reference()`](https://slinghub.github.io/MRMhub/quant/reference/calibrate_by_reference.md)
  : Calibrate feature values using a reference sample

## Drift/Batch Correction

Function for drift and batch correction correction

- [`correct_drift_gaussiankernel()`](https://slinghub.github.io/MRMhub/quant/reference/correct_drift_gaussiankernel.md)
  : Drift correction by Gaussian kernel smoothing
- [`correct_drift_cubicspline()`](https://slinghub.github.io/MRMhub/quant/reference/correct_drift_cubicspline.md)
  : Drift correction by cubic spline smoothing
- [`correct_drift_loess()`](https://slinghub.github.io/MRMhub/quant/reference/correct_drift_loess.md)
  : Drift correction by LOESS smoothing
- [`correct_drift_gam()`](https://slinghub.github.io/MRMhub/quant/reference/correct_drift_gam.md)
  : Drift correction by generalized additive model (GAM) smoothing
- [`correct_batch_centering()`](https://slinghub.github.io/MRMhub/quant/reference/correct_batch_centering.md)
  : Batch centering correction

## Quality Control and Filtering

Functions to calculate feature QC metrics and apply QC filtering, and
vizualize the filtering results.

- [`calc_qc_metrics()`](https://slinghub.github.io/MRMhub/quant/reference/calc_qc_metrics.md)
  : Calculate quality control (QC) metrics for features
- [`filter_features_qc()`](https://slinghub.github.io/MRMhub/quant/reference/filter_features_qc.md)
  : Feature filtering based on QC criteria
- [`detect_outlier_pca()`](https://slinghub.github.io/MRMhub/quant/reference/detect_outlier_pca.md)
  : Get list of analyses classified as technical outliers
- [`plot_qc_summary_byclass()`](https://slinghub.github.io/MRMhub/quant/reference/plot_qc_summary_byclass.md)
  : Plot QC filtering summary by feature class
- [`plot_qc_summary_overall()`](https://slinghub.github.io/MRMhub/quant/reference/plot_qc_summary_overall.md)
  : Plot overall QC filtering summary
- [`plot_abundanceprofile()`](https://slinghub.github.io/MRMhub/quant/reference/plot_abundanceprofile.md)
  : Plot abundance profile

## Quality Control Plots

Functions to plots diverse QC visualizatios.

- [`plot_runsequence()`](https://slinghub.github.io/MRMhub/quant/reference/plot_runsequence.md)
  : RunSequence plot
- [`plot_runscatter()`](https://slinghub.github.io/MRMhub/quant/reference/plot_runscatter.md)
  : RunScatter plot
- [`plot_rla_boxplot()`](https://slinghub.github.io/MRMhub/quant/reference/plot_rla_boxplot.md)
  : Relative log abundance (RLA) plot
- [`plot_pca()`](https://slinghub.github.io/MRMhub/quant/reference/plot_pca.md)
  : PCA plot for quality control
- [`plot_pca_loading()`](https://slinghub.github.io/MRMhub/quant/reference/plot_pca_loading.md)
  : Plot PCA loadings
- [`plot_feature_correlations()`](https://slinghub.github.io/MRMhub/quant/reference/plot_feature_correlations.md)
  : Plot highly correlated feature pairs
- [`plot_rt_vs_chain()`](https://slinghub.github.io/MRMhub/quant/reference/plot_rt_vs_chain.md)
  : Plot retention time versus chain length and saturation
- [`plot_matrixeffects()`](https://slinghub.github.io/MRMhub/quant/reference/plot_matrixeffects.md)
  : Plot standardized feature intensities grouped by QC type
- [`plot_normalization_qc()`](https://slinghub.github.io/MRMhub/quant/reference/plot_normalization_qc.md)
  : Compare feature variability before and after normalization
- [`plot_qcmetrics_comparison()`](https://slinghub.github.io/MRMhub/quant/reference/plot_qcmetrics_comparison.md)
  : Comparison of two feature QC metrics variables
- [`plot_interference_correction()`](https://slinghub.github.io/MRMhub/quant/reference/plot_interference_correction.md)
  : Plot the results of interference correction
- [`plot_qc_interference_impact()`](https://slinghub.github.io/MRMhub/quant/reference/plot_qc_interference_impact.md)
  : Plot the magnitude of interference correction as a histogram

## Plot appearance defaults

Set session-wide defaults (font size, point size, legend, strips) for
the plotting functions. See the “Customising plots” article.

- [`mrmhub_set_plot_defaults()`](https://slinghub.github.io/MRMhub/quant/reference/mrmhub_set_plot_defaults.md)
  : Set global default appearance for MRMhub plots
- [`mrmhub_get_plot_defaults()`](https://slinghub.github.io/MRMhub/quant/reference/mrmhub_get_plot_defaults.md)
  : Report the global MRMhub plot defaults
- [`mrmhub_reset_plot_defaults()`](https://slinghub.github.io/MRMhub/quant/reference/mrmhub_reset_plot_defaults.md)
  : Clear the global MRMhub plot defaults

## Response Curves

Functions to calculate and visualize response curves

- [`plot_responsecurves()`](https://slinghub.github.io/MRMhub/quant/reference/plot_responsecurves.md)
  : Plot response curves
- [`get_response_curve_stats()`](https://slinghub.github.io/MRMhub/quant/reference/get_response_curve_stats.md)
  : Linear regression statistics of response curves

## Data Reporting and Sharing

Functions to export processed and raw datasets and the processing steps
in different formats.

- [`save_report_xlsx()`](https://slinghub.github.io/MRMhub/quant/reference/save_report_xlsx.md)
  : Write a data-processing report (Excel)
- [`save_dataset_csv()`](https://slinghub.github.io/MRMhub/quant/reference/save_dataset_csv.md)
  : Export data to a CSV file
- [`save_dataset_mztab()`](https://slinghub.github.io/MRMhub/quant/reference/save_dataset_mztab.md)
  : Export an experiment to mzTab-M (HUPO-PSI)
- [`save_dataset_summarizedexperiment()`](https://slinghub.github.io/MRMhub/quant/reference/save_dataset_summarizedexperiment.md)
  : Export an experiment to a Bioconductor SummarizedExperiment
- [`save_feature_qc_metrics()`](https://slinghub.github.io/MRMhub/quant/reference/save_feature_qc_metrics.md)
  : Save feature QC metrics to CSV

## Lipidomics

Functions specific to lipidomics data processing and analysis.

- [`parse_lipid_feature_names()`](https://slinghub.github.io/MRMhub/quant/reference/parse_lipid_feature_names.md)
  : Get lipid class, species and transition names

## Datasets

Example datasets for testing and demonstration.

- [`lipidomics_dataset`](https://slinghub.github.io/MRMhub/quant/reference/lipidomics_dataset.md)
  : Plasma lipidomics dataset with metadata

- [`quant_lcms_dataset`](https://slinghub.github.io/MRMhub/quant/reference/quant_lcms_dataset.md)
  : LC-MS dataset with external calibration curve and metadata

- [`data_load_example()`](https://slinghub.github.io/MRMhub/quant/reference/data_load_example.md)
  :

  Load an example `MRMhubExperiment` dataset

## Helper functions

A collection of functions that may be useful in the context of mass
spectrometry is also available.

- [`cv()`](https://slinghub.github.io/MRMhub/quant/reference/cv.md) :
  Percent coefficient of variation (%CV)
- [`cv_log()`](https://slinghub.github.io/MRMhub/quant/reference/cv_log.md)
  : Percent coefficient of variation (%CV) based on log-transformation
- [`pooled_sd()`](https://slinghub.github.io/MRMhub/quant/reference/pooled_sd.md)
  : Pooled standard deviation across groups
- [`pooled_rsd()`](https://slinghub.github.io/MRMhub/quant/reference/pooled_rsd.md)
  : Pooled percent relative standard deviation (%RSD) across groups
- [`calc_average_molweight()`](https://slinghub.github.io/MRMhub/quant/reference/calc_average_molweight.md)
  : Calculate average molecular weight from chemical formulas
- [`correct_drift()`](https://slinghub.github.io/MRMhub/quant/reference/correct_drift.md)
  : Drift correction by custom function
- [`fun_gauss.kernel.smooth()`](https://slinghub.github.io/MRMhub/quant/reference/fun_gauss.kernel.smooth.md)
  : Gaussian kernel smoothing helper function
- [`fun_loess()`](https://slinghub.github.io/MRMhub/quant/reference/fun_loess.md)
  : Loess smoothing helper function
- [`fun_cspline()`](https://slinghub.github.io/MRMhub/quant/reference/fun_cspline.md)
  : Cubic spline smoothing helper function
- [`fun_gam_smooth()`](https://slinghub.github.io/MRMhub/quant/reference/fun_gam_smooth.md)
  : Generalized additive model (GAM) smoothing helper function
- [`get_mad_tails()`](https://slinghub.github.io/MRMhub/quant/reference/get_mad_tails.md)
  : Get MAD-based tails
- [`get_iqr_tails()`](https://slinghub.github.io/MRMhub/quant/reference/get_iqr_tails.md)
  : Get Tukey's IQR fences
- [`get_outlier_bounds()`](https://slinghub.github.io/MRMhub/quant/reference/get_outlier_bounds.md)
  : Get outlier bounds via different methods
- [`order_chained_columns_tbl()`](https://slinghub.github.io/MRMhub/quant/reference/order_chained_columns_tbl.md)
  : Reorder a data frame based on a chain of linked values in two
  columns
- [`mrmhub_enable_cli_color()`](https://slinghub.github.io/MRMhub/quant/reference/mrmhub_enable_cli_color.md)
  : Enable coloured mrmhub console output in notebooks
