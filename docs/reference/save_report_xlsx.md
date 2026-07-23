# Write a data-processing report (Excel)

Generates a data processing report from a `MRMhubExperiment` object and
writes it to an Excel file. The report includes information on the data
processing steps, quality control metrics, feature concentrations, and
metadata. Following tables will be created as sheets in the EXCEL file:

## Usage

``` r
save_report_xlsx(
  data = NULL,
  path,
  filtered_variable = "conc",
  normalized_variable = NA,
  overwrite = TRUE
)
```

## Arguments

- data:

  A
  [`MRMhubExperiment`](https://slinghub.github.io/MRMhub/quant/reference/MRMhubExperiment-class.md)
  object containing original and processed data and metadata.

- path:

  A character string specifying the file name and path for the Excel
  file. If the path does not include an `.xlsx` extension, it is added
  automatically.

- filtered_variable:

  A character string specifying the variable name in the filtered data
  to be exported. It must be one of "conc", "intensity",
  "norm_intensity", "response", "area", "height", "conc_raw", "rt", or
  "fwhm". The defined variable name will be included in the sheet name.
  Default is "conc".

- normalized_variable:

  A character string indicating if and which normalized feature values
  (by reference sample) to include in the report.See also
  `[calibrate_by_reference()]`.

- overwrite:

  A logical value indicating whether to overwrite the file if it already
  exists. Default is `TRUE`.

## Value

The function does not return a value. It writes the report to the
specified Excel file.

## Details

- Info: General information including date, author, and MRMhub version,
  processing status and feature concentration unit.

- Feature_QC_metrics: Quality control metrics of all features.

- QCfilt_x_StudySamples: Feature (QC)-filtered data (variable defined
  via `filtered_variable`) in study samples ('SPL'). Filter have to be
  set via
  [`filter_features_qc()`](https://slinghub.github.io/MRMhub/quant/reference/filter_features_qc.md).
  The *x* corresponds to the `filtered_variable` argument.

- QCfilt_x_AllSamples: Feature (QC)-filtered data (variable defined via
  `filtered_variable`) in all samples. Filter have to be set via
  [`filter_features_qc()`](https://slinghub.github.io/MRMhub/quant/reference/filter_features_qc.md).
  The *x* corresponds to the `filtered_variable` argument.

- Conc_FullDataset: Final feature concentrations from the full,
  non-filtered dataset.

- Raw_Intensity_FullDataset: Raw feature intensities from the full,
  non-filtered dataset.

- Norm_Intensity_FullDataset: Normalized feature intensities from the
  full, non-filtered dataset.

- SampleMetadata: Analysis metadata that was imported and used for
  processing steps

- FeatureMetadata: Feature metadata that was imported and used for
  processing steps

- InternalStandards: Internal standards metadata with concentrations

- BatchInfo: Information on batches and positions of first and last
  analysis/sample in each batch

- Interferences: Derived and declared interference relationships
  (interfering feature, contribution factor, overlap type, source) with
  the per-feature correction impact when the correction has been
  applied.

If certain data sets are not available, the function includes empty
tables for the corresponding dataset.

Concentration corresponds to the final concentration values after
applying isotope correction, and drift and batch correction, if
applicable. If any corrections, such as drift or batch correction, were
applied to raw or normalized intensities, the exported values will
reflect these corrections.

## See also

[`normalize_by_istd()`](https://slinghub.github.io/MRMhub/quant/reference/normalize_by_istd.md),
[`quantify_by_istd()`](https://slinghub.github.io/MRMhub/quant/reference/quantify_by_istd.md),
[`quantify_by_calibration()`](https://slinghub.github.io/MRMhub/quant/reference/quantify_by_calibration.md),
[`calibrate_by_reference()`](https://slinghub.github.io/MRMhub/quant/reference/calibrate_by_reference.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# Assuming `mrmhubexp` is a MRMhubExperiment object and `output_path` is a valid path
save_report_xlsx(data = mrmhubexp, path = "output_path/report.xlsx")
} # }
```
