# Importing Metadata

Manual

Metadata in this context refers to analysis metadata, i.e., data that
annotate the analytical data. Metadata can be retrieved from the
imported analysis data file where available, or imported from separate
files or R data frames. Integrity of metadata and data is essential for
correct post-processing: MRMhub inspects imported data and metadata for
completeness and for consistency of the IDs used across the different
metadata tables, and after import a summary of the identified errors,
warnings, and notes is printed to the console so that possible issues
can be identified and addressed.

## Metadata formats and templates

The structure and the required and optional columns for each metadata
type are described below under [Metadata table
structures](#metadata-table-structures) and in the help pages of the
corresponding import functions. To obtain metadata templates, an Excel
file containing all metadata table templates can be saved.

``` r

mrmhub::save_metadata_templates()
```

## Importing metadata from files and sheets

The analysis data are first imported as outlined in [Importing
Analytical
Data](https://slinghub.github.io/MRMhub/quant/articles/manual-04-data-import.md).
In this case, metadata present in the analysis data is not imported;
only the peak areas are read.

``` r

library(mrmhub)
mexp <- mrmhub::MRMhubExperiment()

data_path <- "datasets/sPerfect_MRMhub.tsv"
mexp <- import_data_mrmhub(data = mexp, path = data_path, import_metadata = FALSE)
```

The corresponding metadata can then be added file by file.

``` r

mexp <- import_metadata_analyses(mexp,
                                 path = "datasets/analysis_metadata.csv",
                                 excl_unmatched_analyses = TRUE,
                                 ignore_warnings = TRUE)

mexp <- import_metadata_features(mexp,
                                 path = "datasets/feature_metadata.csv",
                                 ignore_warnings= TRUE )
```

Metadata can also be imported from sheets of an Excel workbook, which
allows all metadata to be stored in one file. Here, metadata on internal
standards and response curves is added to the MRMhubExperiment object.

``` r

mexp <- import_metadata_istds(mexp,
                              path = "datasets/metadata_tables.xlsx",
                              sheet = "ISTDs",
                              ignore_warnings= TRUE)
```

Furthermore, metadata can be imported from R `data.frame` objects, which
allows metadata to be obtained from additional sources, e.g. databases
or a LIMS.

``` r

df_qcinfo <- readr::read_table(file = "datasets/qc_metadata.txt")
mexp <- import_metadata_qcconcentrations(mexp, table = df_qcinfo)
```

## Importing an MSOrganiser metadata template

Another option to import metadata is via the MSOrganiser template file,
an Excel file (`.xlsx`). This template provides tables for all metadata
types supported by MRMhub, with options to check the validity and
integrity of the metadata. The template can be obtained from
<https://github.com/SLINGhub/mrmhub> or via a mrmhub function.

``` r

mrmhub::save_metadata_msorganiser_template()
```

Only the metadata tables required by the intended processing workflow
need to be completed. The following import function imports all
completed tables.

``` r

mexp <- import_metadata_msorganiser(mexp,
                                    path = "datasets/sPerfect_Metadata.xlsx",
                                    ignore_warnings= TRUE)
```

## Metadata table structures

The previews below show example rows or the blank template headers for
each metadata table, so the tables can be prepared before import.
Identifier columns must be consistent across tables: `analysis_id` /
`sample_id` match the analysis metadata and the data, `analyte_id` links
features to QC concentrations, and `istd_feature_id` and `feature_id`
reference the feature metadata. The full column reference for each table
is given on its linked function reference page.

### Analyses (samples)

One row per analysis (injection). Import with
[`import_metadata_analyses()`](https://slinghub.github.io/MRMhub/quant/reference/import_metadata_analyses.md).

``` r

show_csv("MHQuant_demo_metadata_analyses.csv")
```

| analysis_id | qc_type | sample_amount | sample_amount_unit | istd_volume | batch_id |
|:---|:---|---:|:---|---:|---:|
| 001_EQC_TQC prerun 01 | EQC | 20 | uL | 200 | 1 |
| 002_EQC_TQC prerun 02 | EQC | 20 | uL | 200 | 1 |
| 003_EQC_TQC prerun 03 | EQC | 20 | uL | 200 | 1 |
| 004_EQC_TQC prerun 04 | EQC | 20 | uL | 200 | 1 |

Example file `MHQuant_demo_metadata_analyses.csv` {.table
style="width:100%;"}

### Features (analytes)

One row per feature. Import with
[`import_metadata_features()`](https://slinghub.github.io/MRMhub/quant/reference/import_metadata_features.md).

``` r

show_template("Features")
```

| feature_id | istd_feature_id | feature_class | analyte_id | chem_formula | molecular_weight | feature_label | response_factor | is_quantifier | valid_integration | interference_feature_id | interference_proportion | remarks |
|----|----|----|----|----|----|----|----|----|----|----|----|----|

Template sheet `Features` (column headers) {.table}

### Internal standards (ISTDs)

One row per internal standard, giving its known concentration. Import
with
[`import_metadata_istds()`](https://slinghub.github.io/MRMhub/quant/reference/import_metadata_istds.md).

``` r

show_csv("MRMhub_ISTDconc.csv")
```

| istd_feature_id          | istd_conc_nmolar |
|:-------------------------|-----------------:|
| CE 18:1 d7 (ISTD)        |           541.05 |
| Cer d18:1/25:0 (ISTD)    |            25.00 |
| LPC 18:1 (ab ) d7 (ISTD) |            48.23 |
| PC 33:1 d7 (ISTD)        |           212.45 |

Example file `MRMhub_ISTDconc.csv` {.table}

### Response curves

Maps response-curve injections to the amount analysed. Import with
[`import_metadata_responsecurves()`](https://slinghub.github.io/MRMhub/quant/reference/import_metadata_responsecurves.md).

``` r

show_template("ResponseCurves")
```

| analysis_id | curve_id | analyzed_amount | analyzed_amount_unit |
|-------------|----------|-----------------|----------------------|

Template sheet `ResponseCurves` (column headers) {.table}

### Calibration / QC concentrations

Known analyte concentrations in calibration and QC samples. Import with
[`import_metadata_qcconcentrations()`](https://slinghub.github.io/MRMhub/quant/reference/import_metadata_qcconcentrations.md).

``` r

show_template("QCconcentrations")
```

| sample_id | analyte_id | concentration | concentration_unit | include_in_analysis |
|-----------|------------|---------------|--------------------|---------------------|

Template sheet `QCconcentrations` (column headers) {.table}

## Next steps

- [Importing Analytical
  Data](https://slinghub.github.io/MRMhub/quant/articles/manual-04-data-import.md)
  — importing the measurement data
- [Sample Types & QC
  Roles](https://slinghub.github.io/MRMhub/quant/articles/manual-06-sample-types.md)
  — the `qc_type` values that drive QC logic
- [The MRMhubExperiment Data
  Object](https://slinghub.github.io/MRMhub/quant/articles/manual-02-data-object.md)
  — where the metadata is stored
- [Function
  reference](https://slinghub.github.io/MRMhub/quant/reference/index.md)
  — full arguments for every metadata importer
