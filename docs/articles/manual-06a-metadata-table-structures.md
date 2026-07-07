# Metadata table structures

The metadata tables are prepared manually, so this page documents every
column and its purpose. Each importer accepts the same three input modes
— a **CSV file** (`path =`), a **sheet in an Excel workbook**
(`path =` + `sheet =`), or an in-memory **`data.frame`** (`table =`).

**Get blank templates for all these tables.** Save a ready-made
workbook, fill it in, and load it back.

``` r

save_metadata_templates()              # Individual metadata tables (XLSX)
save_metadata_msorganiser_template()   # msorganizer metadata template (XLSX)
```

Identifier columns must be consistent across tables: `analysis_id` /
`sample_id` match the analysis metadata and the data; `analyte_id` links
features to QC concentrations; `istd_feature_id` and `feature_id`
reference the feature metadata.

## Analyses (samples)

One row per analysis (injection). Import with
[`import_metadata_analyses()`](https://slinghub.github.io/MRMhub/quant/reference/import_metadata_analyses.md).

| analysis_id | qc_type | sample_amount | sample_amount_unit | istd_volume | batch_id |
|:---|:---|---:|:---|---:|---:|
| 001_EQC_TQC prerun 01 | EQC | 20 | uL | 200 | 1 |
| 002_EQC_TQC prerun 02 | EQC | 20 | uL | 200 | 1 |
| 003_EQC_TQC prerun 03 | EQC | 20 | uL | 200 | 1 |
| 004_EQC_TQC prerun 04 | EQC | 20 | uL | 200 | 1 |

Example file `MHQuant_demo_metadata_analyses.csv` {.table
style="width:100%;"}

| Column | Required | Description |
|----|----|----|
| `analysis_id` | Yes | Unique identifier of each analysis/injection; must match the imported data. |
| `qc_type` | Yes | Sample / QC role (e.g. `SPL`, `TQC`, `BQC`, `SBLK`, `PBLK`, `RQC`) that drives the QC logic. |
| `sample_id` | Optional | Sample identifier; groups replicate injections of the same sample. |
| `batch_id` | Optional | Batch identifier (defaults to `1`). |
| `sample_amount` | Optional | Amount of sample used. |
| `sample_amount_unit` | Optional | Unit of `sample_amount` (e.g. `uL`, `mg`). |
| `istd_volume` | Optional | Volume of internal-standard mixture added. |
| `valid_analysis` | Optional | Whether to include the analysis (default `TRUE`). |

Also recognised (optional): `analysis_order`, `replicate_no`,
`specimen`, `remarks`.

## Features (analytes)

One row per feature/compound. Import with
[`import_metadata_features()`](https://slinghub.github.io/MRMhub/quant/reference/import_metadata_features.md).

| feature_id | istd_feature_id | feature_class | analyte_id | chem_formula | molecular_weight | feature_label | response_factor | is_quantifier | valid_integration | interference_feature_id | interference_proportion | remarks |
|----|----|----|----|----|----|----|----|----|----|----|----|----|

Template sheet `Features` (column headers) {.table}

| Column | Required | Description |
|----|----|----|
| `feature_id` | Yes | Unique feature/compound identifier; must match the imported data. |
| `istd_feature_id` | Optional | `feature_id` of the internal standard used to normalise this feature. |
| `feature_class` | Optional | Lipid / chemical class or group. |
| `analyte_id` | Optional | Standardised analyte identifier (links to QC concentrations). |
| `chem_formula` | Optional | Chemical formula (for molecular-weight / isotope calculations). |
| `molecular_weight` | Optional | Molecular weight (Da). |
| `feature_label` | Optional | Display name used to rename the feature. |
| `response_factor` | Optional | Response correction factor (default `1`). |
| `is_quantifier` | Optional | Whether this is the quantifier transition (default `TRUE`). |
| `valid_integration` | Optional | Whether the feature should be kept (default `TRUE`). |
| `interference_feature_id` | Optional | `feature_id` of an interfering feature to subtract. |
| `interference_proportion` | Optional | Fraction (0–1) of the interfering signal that contributes. |
| `remarks` | Optional | Free-text comment. |

## Internal standards (ISTDs)

One row per internal standard. Import with
[`import_metadata_istds()`](https://slinghub.github.io/MRMhub/quant/reference/import_metadata_istds.md).

| istd_feature_id          | istd_conc_nmolar |
|:-------------------------|-----------------:|
| CE 18:1 d7 (ISTD)        |           541.05 |
| Cer d18:1/25:0 (ISTD)    |            25.00 |
| LPC 18:1 (ab ) d7 (ISTD) |            48.23 |
| PC 33:1 d7 (ISTD)        |           212.45 |

Example file `MRMhub_ISTDconc.csv` {.table}

| Column             | Required | Description                            |
|--------------------|----------|----------------------------------------|
| `istd_feature_id`  | Yes      | `feature_id` of the internal standard. |
| `istd_conc_nmolar` | Yes\*    | ISTD concentration in nM.              |
| `istd_conc_ngml`   | Yes\*    | ISTD concentration in ng/mL.           |
| `remarks`          | Optional | Free-text comment.                     |

\* Provide **one** of `istd_conc_nmolar` or `istd_conc_ngml`.

## Response curves

Maps response-curve injections to the amount analysed. Import with
[`import_metadata_responsecurves()`](https://slinghub.github.io/MRMhub/quant/reference/import_metadata_responsecurves.md).

| analysis_id | curve_id | analyzed_amount | analyzed_amount_unit |
|-------------|----------|-----------------|----------------------|

Template sheet `ResponseCurves` (column headers) {.table}

| Column | Required | Description |
|----|----|----|
| `analysis_id` | Yes | Analysis identifier of a response-curve injection; must match the data. |
| `curve_id` | Yes | Identifier grouping injections into one response curve. |
| `analyzed_amount` | Yes | Relative amount injected (e.g. dilution level or % of sample). |
| `analyzed_amount_unit` | Yes | Unit of `analyzed_amount` (e.g. `%`). |

## Calibration / QC concentrations

Known analyte concentrations in calibration / QC samples. Import with
[`import_metadata_qcconcentrations()`](https://slinghub.github.io/MRMhub/quant/reference/import_metadata_qcconcentrations.md).

| sample_id | analyte_id | concentration | concentration_unit | include_in_analysis |
|-----------|------------|---------------|--------------------|---------------------|

Template sheet `QCconcentrations` (column headers) {.table}

| Column | Required | Description |
|----|----|----|
| `sample_id` | Yes | QC sample identifier; must match `sample_id` in the analyses metadata. |
| `analyte_id` | Yes | Analyte identifier; must match `analyte_id` in the feature metadata. |
| `concentration` | Yes | Known/expected concentration of the analyte in that sample. |
| `concentration_unit` | Yes | Unit (e.g. `nmol/L`, `ng/mL`). |
| `include_in_analysis` | Optional | Whether to use this value (`yes`/`no`/`true`/`false`; default `TRUE`). |

## All tables at once — MSOrganiser template

The MSOrganiser workbook (`.xlsx`) bundles every table above as a sheet,
so you can fill in all metadata in one file and load it with
[`import_metadata_msorganiser()`](https://slinghub.github.io/MRMhub/quant/reference/import_metadata_msorganiser.md).
Get a blank copy with
[`save_metadata_msorganiser_template()`](https://slinghub.github.io/MRMhub/quant/reference/save_metadata_msorganiser_template.md).

Sheets: **Analyses (Samples)**, **Features (Analytes)**, **Internal
Standards**, **Response Curves**, **QC Concentrations**. The workbook
uses Title-Case headers (e.g. `Raw_Data_Filename`, `Sample_Type`,
`ISTD_Feature_Name`) that are mapped to the snake_case columns
documented above on import. See [Metadata
Import](https://slinghub.github.io/MRMhub/quant/articles/manual-06-metadata-import.md)
for the full mapping and validation rules.

## Next Steps

- [Import and prepare data
  files](https://slinghub.github.io/MRMhub/quant/articles/manual-05a-which-importer.md)
  — the importer decision table
- [Data file
  structures](https://slinghub.github.io/MRMhub/quant/articles/manual-05b-data-file-structures.md)
  — peak-table file layouts
- [Metadata
  Import](https://slinghub.github.io/MRMhub/quant/articles/manual-06-metadata-import.md)
  — validation rules and the MSOrganiser mapping
