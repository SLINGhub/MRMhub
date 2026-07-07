# Import and prepare data files

Loading an experiment takes two steps: import the **peak table**
produced by your integration software, then attach the **metadata** that
describes samples, features, and standards. MRMhub stores everything
internally in **long** format (one row per sample × feature); **wide**
files (one row per sample, one column per feature) are pivoted
automatically on import.

**Start from a blank template.** Save a ready-made metadata workbook,
fill it in, and load it back — no need to build the tables from scratch.

``` r

save_metadata_templates()              # Individual metadata tables (XLSX)
save_metadata_msorganiser_template()   # msorganizer metadata template (XLSX)
```

## Data import

Pick the importer that matches the software that produced your peak
table. Each reads a CSV/TSV file and returns an `MRMhubExperiment`.

Click a **Format** to see the file structure and column meanings.

| Source | Format | Function |
|----|----|----|
| MRMhub / INTEGRATOR *(recommended)* | [Long CSV / TSV](https://slinghub.github.io/MRMhub/quant/articles/manual-05b-data-file-structures.html#str-mrmhub) | [`import_data_mrmhub()`](https://slinghub.github.io/MRMhub/quant/reference/import_data_mrmhub.md) |
| Agilent MassHunter Quant | [Wide CSV](https://slinghub.github.io/MRMhub/quant/articles/manual-05b-data-file-structures.html#str-masshunter) | [`import_data_masshunter()`](https://slinghub.github.io/MRMhub/quant/reference/import_data_masshunter.md) |
| Skyline (small molecule) | [Long CSV](https://slinghub.github.io/MRMhub/quant/articles/manual-05b-data-file-structures.html#str-skyline) | [`import_data_skyline()`](https://slinghub.github.io/MRMhub/quant/reference/import_data_skyline.md) |
| Generic spreadsheet (samples × features) | [Wide CSV](https://slinghub.github.io/MRMhub/quant/articles/manual-05b-data-file-structures.html#str-csv-wide) | [`import_data_csv_wide()`](https://slinghub.github.io/MRMhub/quant/reference/import_data_csv_wide.md) |
| Generic table (one row per measurement) | [Long CSV](https://slinghub.github.io/MRMhub/quant/articles/manual-05b-data-file-structures.html#str-csv-long) | [`import_data_csv_long()`](https://slinghub.github.io/MRMhub/quant/reference/import_data_csv_long.md) |
| mzTab-M (Lipid Data Analyzer, MS-DIAL, MZmine) | [mzTab-M 2.0](https://github.com/HUPO-PSI/mzTab-M) | [`import_data_mztab()`](https://slinghub.github.io/MRMhub/quant/reference/import_data_mztab.md) |

## Metadata import

Annotate the loaded peak table with metadata. Every importer accepts the
same three input modes — a **CSV file** (`path=`), a **sheet in an Excel
workbook** (`path=` + `sheet=`), or an in-memory **`data.frame`**
(`table=`).

Click a **Structure** to see the table columns and what each one is for.

| Metadata table | Structure | Function |
|----|----|----|
| Analyses (samples) | [CSV · Excel · data.frame](https://slinghub.github.io/MRMhub/quant/articles/manual-06a-metadata-table-structures.html#str-analyses) | [`import_metadata_analyses()`](https://slinghub.github.io/MRMhub/quant/reference/import_metadata_analyses.md) |
| Features | [CSV · Excel · data.frame](https://slinghub.github.io/MRMhub/quant/articles/manual-06a-metadata-table-structures.html#str-features) | [`import_metadata_features()`](https://slinghub.github.io/MRMhub/quant/reference/import_metadata_features.md) |
| Internal standards (ISTDs) | [CSV · Excel · data.frame](https://slinghub.github.io/MRMhub/quant/articles/manual-06a-metadata-table-structures.html#str-istds) | [`import_metadata_istds()`](https://slinghub.github.io/MRMhub/quant/reference/import_metadata_istds.md) |
| Response curves | [CSV · Excel · data.frame](https://slinghub.github.io/MRMhub/quant/articles/manual-06a-metadata-table-structures.html#str-responsecurves) | [`import_metadata_responsecurves()`](https://slinghub.github.io/MRMhub/quant/reference/import_metadata_responsecurves.md) |
| Calibration / QC concentrations | [CSV · Excel · data.frame](https://slinghub.github.io/MRMhub/quant/articles/manual-06a-metadata-table-structures.html#str-qcconcentrations) | [`import_metadata_qcconcentrations()`](https://slinghub.github.io/MRMhub/quant/reference/import_metadata_qcconcentrations.md) |
| All tables at once | [MSOrganiser template (.xlsx)](https://slinghub.github.io/MRMhub/quant/articles/manual-06a-metadata-table-structures.html#str-msorganiser) | [`import_metadata_msorganiser()`](https://slinghub.github.io/MRMhub/quant/reference/import_metadata_msorganiser.md) |

A minimal import looks like this:

``` r

exp <- import_data_mrmhub("datasets/integrator_output.tsv")
exp <- import_metadata_msorganiser(exp, path = "datasets/metadata.xlsx")
```

## See Also

- [Data file
  structures](https://slinghub.github.io/MRMhub/quant/articles/manual-05b-data-file-structures.md)
  — per-importer file layout and column reference
- [Metadata table
  structures](https://slinghub.github.io/MRMhub/quant/articles/manual-06a-metadata-table-structures.md)
  — per-table columns and what each is for
- [Data Import
  (detailed)](https://slinghub.github.io/MRMhub/quant/articles/manual-05-data-import.md)
  — per-function arguments, column expectations, and troubleshooting
- [Metadata
  Import](https://slinghub.github.io/MRMhub/quant/articles/manual-06-metadata-import.md)
  — required columns and validation
- [Key
  Concepts](https://slinghub.github.io/MRMhub/quant/articles/manual-00-key-concepts.md)
  — terminology reference
