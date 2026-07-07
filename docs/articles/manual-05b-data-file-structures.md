# Data file structures

This page shows the **expected layout** of each data file and what its
columns mean, so that the input can be recognised and prepared before
importing. Pick the importer that matches the software that produced the
peak table; see [Import and prepare data
files](https://slinghub.github.io/MRMhub/quant/articles/manual-05a-which-importer.md)
for the decision table.

The previews below are the actual first rows of the example files
bundled with the package
(`system.file("extdata", ..., package = "mrmhub")`).

Files fall into two groups:

- **Vendor / tool exports** (MRMhub/INTEGRATOR, MassHunter, Skyline) —
  the columns are produced by the software and are not edited manually.
  Confirm that the correct report was exported.
- **Generic CSV** (wide / long) — these are prepared manually, so the
  full column reference is given.

## MRMhub / INTEGRATOR — long CSV/TSV

INTEGRATOR’s long output: one row per analysis × feature. Tab-separated
(`.tsv`) or comma-separated (`.csv`). This is the preferred format;
import with
[`import_data_mrmhub()`](https://slinghub.github.io/MRMhub/quant/reference/import_data_mrmhub.md).

| feature_name | raw_data_filename | sample_type | batch | rt_apex | area |
|:---|:---|:---|---:|---:|---:|
| CE 18:1 | Longit_BLANK-01 (Eluent A).mzML | SBLK | 1 | 7.295 | 3134.1636 |
| CE 18:1 | Longit_B-ISTD 01 Extr.mzML | PBLK | 1 | 7.295 | 854.8992 |
| CE 18:1 | Longit_Un-ISTD 01 Unextr.mzML | UBLK | 1 | 7.280 | 229.5320 |

First 3 rows of `MRMhub_demo.tsv` (showing 6 of 18 columns) {.table}

The file also carries `internal_standard`, `time_stamp`, transition
columns (`precursor_mz`, `product_mz`, `collision_energy`, `polarity`),
and integration columns (`height`, `FWHM`, `rt_int_start`,
`rt_int_end`). This file is not prepared by hand; it is produced by
INTEGRATOR. See [Data Import
(detailed)](https://slinghub.github.io/MRMhub/quant/articles/manual-05-data-import.md).

## Agilent MassHunter Quant — wide CSV

A MassHunter Quant export is **wide with a two-row header**. The first
header row groups columns by compound (`<Compound> Method` and
`<Compound> Results` blocks) after a leading `Sample` block; the second
row holds the actual sub-headers. Import with
[`import_data_masshunter()`](https://slinghub.github.io/MRMhub/quant/reference/import_data_masshunter.md).

| Sample |  |  |  | CE 18:1 — Method |  |  |  | CE 18:1 — Results |  |  | … |
|----|----|----|----|----|----|----|----|----|----|----|----|
| Data File | Name | Type | Acq. Date-Time | Precursor Ion | Product Ion | Collision Energy | RT | RT | Area | FWHM |  |
| 001\_…01.d | 001\_…01 | Sample | 4/12/18 18:28 | 668.6 | 369.3 | 10 | 7.16 | 7.16 | 5152996 | 0.081 |  |
| 002\_…02.d | 002\_…02 | Sample | 4/12/18 18:39 | 668.6 | 369.3 | 10 | 7.16 | 7.16 | 4789505 | 0.080 |  |

The `Method`/`Results` blocks repeat for every compound (quantifiers and
qualifiers). MassHunter produces this layout; it is not edited manually.
See [Data Import
(detailed)](https://slinghub.github.io/MRMhub/quant/articles/manual-05-data-import.md)
for handling qualifier transitions and choosing the concentration
column.

## Skyline (small molecule) — long CSV

Skyline’s *Molecule Transition Results* export: one row per transition
result. Import with
[`import_data_skyline()`](https://slinghub.github.io/MRMhub/quant/reference/import_data_skyline.md).

| Molecule Name | Replicate Name | Precursor Mz | Product Mz | Retention Time |   Area |
|:--------------|:---------------|-------------:|-----------:|---------------:|-------:|
| Aldosterone   | SBLK1          |        359.2 |      331.2 |           2.43 |      2 |
| Aldosterone   | SBLK1          |        359.2 |      189.0 |           2.70 |     36 |
| Aldosterone   | SBLK1          |        361.2 |      343.1 |           2.49 | 121860 |

First 3 rows of `Skyline_MoleculeTransitionResults.csv` (showing 6 of 16
columns) {.table}

`Replicate Name` becomes `analysis_id`, `Molecule Name` becomes
`feature_id`, and transitions are identified by precursor/product name
or *m/z*. Export this report from Skyline; see [Data Import
(detailed)](https://slinghub.github.io/MRMhub/quant/articles/manual-05-data-import.md).

## Generic spreadsheet (wide CSV)

One row per sample, one column per feature. Import with
[`import_data_csv_wide()`](https://slinghub.github.io/MRMhub/quant/reference/import_data_csv_wide.md),
passing `variable_name` to declare what the values represent.

| analysis_id | qc_type | batch_id | S1P 18:1;O2 | S1P 18:2;O2 | S1P 18:0;O2 | S1P 16:1;O2 | S1P 17:1;O2 |
|---:|:---|---:|---:|---:|---:|---:|---:|
| 1 | SPL | 1 | 943.9524 | 321.1111 | 338.2323 | 91.16817 | 24.52784 |
| 2 | SPL | 1 | 976.9823 | 543.4100 | 217.6715 | 133.31666 | 66.12263 |
| 3 | SPL | 1 | 1155.8708 | 1327.3995 | 1539.4633 | 1690.63083 | 339.54704 |

First 3 rows of `plain_wide_dataset.csv` {.table}

| Column | Required | Description |
|----|----|----|
| `analysis_id` | Yes | Unique sample/injection identifier (one row per sample). If absent, the first column is used when its values are unique. |
| *feature columns* | Yes (≥1) | One column per feature; the **column name is the `feature_id`** and the values are of the type given by `variable_name`. |
| `qc_type` | Optional | Sample/QC role (e.g. `SPL`, `TQC`, `BQC`, `SBLK`). Imported when `import_metadata = TRUE`. |
| `batch_id` | Optional | Batch identifier. |
| `is_quantifier` | Optional | Whether the feature is a quantifier. |
| `is_istd` | Optional | Whether the feature is an internal standard. |
| `analysis_order` | Optional | Run order of the analyses. |

**Key arguments:** `variable_name` (required) declares what the values
represent — one of `"area"`, `"height"`, `"intensity"`,
`"norm_intensity"`, `"conc"`, or `"response"`. Use
`first_feature_column` to mark where the feature columns begin when
extra metadata columns are present, and `analysis_id_col` to point at a
non-standard ID column.

## Generic table (long CSV)

One row per `(sample, feature)` measurement. Import with
[`import_data_csv_long()`](https://slinghub.github.io/MRMhub/quant/reference/import_data_csv_long.md).
Columns are auto-detected by name (case-insensitive); use
`column_mapping` for non-matching headers.

| feature_id | raw_data_filename     | sample_type | batch | rt_apex |    area |
|:-----------|:----------------------|:------------|------:|--------:|--------:|
| CE 18:1    | Longit_batch1_15.mzML | SPL         |     1 |   7.295 | 1546867 |
| CE 18:1    | Longit_batch1_16.mzML | SPL         |     1 |   7.311 | 1407493 |
| CE 18:1    | Longit_batch1_17.mzML | SPL         |     1 |   7.311 | 1378911 |

First 3 rows of `plain_long_dataset.csv` (showing 6 of 18 columns)
{.table}

(The bundled example uses INTEGRATOR-style headers such as
`raw_data_filename` and `rt_apex`, so it is imported with a
`column_mapping`; see the example in
[`import_data_csv_long()`](https://slinghub.github.io/MRMhub/quant/reference/import_data_csv_long.md).)

Auto-detected columns:

| Column | Required | Description |
|----|----|----|
| `analysis_id` | Yes | Sample/injection identifier (or supply `raw_data_filename` and map it). |
| `feature_id` | Yes | Feature/compound identifier. |
| `area` / `height` / `intensity` | Yes (≥1) | A feature value column; at least one is needed. |
| `rt` | Optional | Retention time. |
| `fwhm` / `width` | Optional | Peak width metrics. |
| `qc_type` | Optional | Sample/QC role. |
| `sample_id` | Optional | Sample identifier (groups replicates). |
| `batch_id` | Optional | Batch identifier. |
| `istd_feature_id` | Optional | Internal standard used for the feature. |
| `feature_class` | Optional | Feature class/group. |
| `analyte_id` | Optional | Standardised analyte identifier. |
| `precursor_mz` / `product_mz` | Optional | Transition *m/z* values. |

Columns already named with the internal `feature_`/`method_` prefixes
(e.g. `feature_area`) are detected automatically too.

## Next Steps

- [Import and prepare data
  files](https://slinghub.github.io/MRMhub/quant/articles/manual-05a-which-importer.md)
  — the importer decision table
- [Metadata table
  structures](https://slinghub.github.io/MRMhub/quant/articles/manual-06a-metadata-table-structures.md)
  — annotation table columns
- [Data Import
  (detailed)](https://slinghub.github.io/MRMhub/quant/articles/manual-05-data-import.md)
  — full arguments and troubleshooting
