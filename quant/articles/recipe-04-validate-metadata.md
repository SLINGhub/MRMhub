# Validating and fixing metadata

Recipe Prerequisites: [Importing
metadata](https://slinghub.github.io/MRMhub/quant/articles/recipe-05-import-metadata.md)

Most processing errors in MRMhub trace back to defects in the annotation
tables rather than the analytical data itself. The frequent offenders
are a mismatched `analysis_id` between data and annotation, a missing
`qc_type` label (the one column besides `analysis_id` the importer
requires), absent `batch_id` or `analysis_order` columns that later
steps depend on, and `qc_type` values that fall outside the vocabulary
MRMhub uses for QC selection. This recipe covers generating a template,
validating annotations against the imported data, and resolving the
typical defects. For the structure of each annotation table and how
identifiers are matched, see [Metadata tables and
matching](https://slinghub.github.io/MRMhub/quant/articles/manual-05-metadata.md);
for the canonical `qc_type` labels, see [Sample types and QC
roles](https://slinghub.github.io/MRMhub/quant/articles/manual-06-sample-types.md).

## Generate a metadata template

[`save_metadata_templates()`](https://slinghub.github.io/MRMhub/quant/reference/save_metadata_templates.md)
writes an XLSX template with one sheet per annotation table
(`annot_analyses`, `annot_features`, `annot_istds`,
`annot_responsecurves`, `annot_qcconcentrations`), each carrying the
expected column names and example rows.

``` r

library(mrmhub)

save_metadata_templates(path = "metadata/sPerfect_metadata.xlsx")
```

Fill in the sheets in Excel, save, and proceed to import. The MRMhub
Metadata Organizer template
([`save_metadata_msorganiser_template()`](https://slinghub.github.io/MRMhub/quant/reference/save_metadata_msorganiser_template.md))
is a richer alternative that bundles every metadata table into a single
workbook, for labs that prefer an Excel-driven layout.

## Extract metadata from imported data

If the imported data file already carries embedded metadata (for example
an INTEGRATOR result with `qc_type`, `batch_id`, and `analysis_order`
columns),
[`import_metadata_from_data()`](https://slinghub.github.io/MRMhub/quant/reference/import_metadata_from_data.md)
lifts those columns into the annotation slots and links them to the
dataset in a single call, returning the updated `MRMhubExperiment`.

``` r

myexp <- MRMhubExperiment()
myexp <- import_data_mrmhub(
  myexp,
  path = "datasets/sPerfect_MRMhub.tsv",
  import_metadata = FALSE
)

myexp <- import_metadata_from_data(myexp)
```

This is the fast path for data that already contains analysis metadata
in the import file. For manual edits or additional annotation (ISTDs,
calibration concentrations, biological covariates), fill in the XLSX
template above and use the per-table importers below.

## Import and validate annotation tables

The per-table importers
([`import_metadata_analyses()`](https://slinghub.github.io/MRMhub/quant/reference/import_metadata_analyses.md),
[`import_metadata_features()`](https://slinghub.github.io/MRMhub/quant/reference/import_metadata_features.md),
[`import_metadata_istds()`](https://slinghub.github.io/MRMhub/quant/reference/import_metadata_istds.md),
[`import_metadata_responsecurves()`](https://slinghub.github.io/MRMhub/quant/reference/import_metadata_responsecurves.md),
[`import_metadata_qcconcentrations()`](https://slinghub.github.io/MRMhub/quant/reference/import_metadata_qcconcentrations.md))
read a CSV or Excel sheet, validate it against the imported data, and
link the validated table to the experiment.

``` r

myexp <- import_metadata_analyses(
  myexp,
  path = "metadata/sPerfect_metadata.xlsx",
  sheet = "annot_analyses",
  excl_unmatched_analyses = FALSE
)

myexp <- import_metadata_features(
  myexp,
  path = "metadata/sPerfect_metadata.xlsx",
  sheet = "annot_features"
)

myexp <- import_metadata_istds(
  myexp,
  path = "metadata/sPerfect_metadata.xlsx",
  sheet = "annot_istds"
)
```

The importer checks the table against the data before attaching it
(required columns, unique and consistent identifiers, and canonical
`qc_type` labels) and reports any defect as a `cli` message naming the
offending table, column, and IDs. The [metadata tables
reference](https://slinghub.github.io/MRMhub/quant/articles/manual-05-metadata.md)
lists the required columns and matching rules for each table. When
annotation tables are assembled in R rather than read from a file, pass
them to
[`add_metadata()`](https://slinghub.github.io/MRMhub/quant/reference/add_metadata.md)
as a named list; the same validation is applied before the tables are
linked.

## Common defects and fixes

**Column `qc_type` missing from `annot_analyses`**

`qc_type` is the only column besides `analysis_id` that the importer
strictly requires. Add it before re-importing:

``` r

annot_analyses <- annot_analyses |>
  dplyr::mutate(qc_type = dplyr::case_when(
    stringr::str_detect(analysis_id, "BQC") ~ "BQC",
    stringr::str_detect(analysis_id, "BLK") ~ "SBLK",
    TRUE ~ "SPL"
  ))
```

**`analysis_id` in data not found in annotation**

Some injections in the imported dataset have no matching row in the
annotation table. List them and inspect the difference: leading or
trailing whitespace and case mismatches are the most frequent causes.

``` r

data_ids <- unique(myexp@dataset_orig$analysis_id)
annot_ids <- annot_analyses$analysis_id

# IDs present in data but missing from annotation
setdiff(data_ids, annot_ids)

# Fix trailing whitespace introduced by Excel
annot_analyses <- annot_analyses |>
  dplyr::mutate(analysis_id = trimws(analysis_id))
```

`excl_unmatched_analyses = TRUE` in the importer drops unmatched
analyses silently, useful only when the omission is intentional, such as
excluded conditioning injections.

**Non-canonical `qc_type` values**

MRMhub only recognises its canonical `qc_type` labels, and they are
case-sensitive; see [Sample types and QC
roles](https://slinghub.github.io/MRMhub/quant/articles/manual-06-sample-types.md)
for the full set. Map any non-standard values before validating:

``` r

unique(annot_analyses$qc_type)

annot_analyses <- annot_analyses |>
  dplyr::mutate(qc_type = dplyr::case_when(
    qc_type == "Standard" ~ "CAL",
    qc_type == "Blank" ~ "SBLK",
    qc_type == "Pool" ~ "BQC",
    qc_type == "Sample" ~ "SPL",
    TRUE ~ qc_type
  ))
```

**Duplicate identifiers**

``` r

annot_analyses |>
  dplyr::count(analysis_id) |>
  dplyr::filter(n > 1)
```

Common cause: copy-paste errors in Excel, or repeated header rows
interpreted as data.

**Feature IDs in annotation do not match data**

``` r

data_features <- unique(myexp@dataset_orig$feature_id)
annot_feat_ids <- annot_features$feature_id

# In data but missing from annotation
setdiff(data_features, annot_feat_ids)

# In annotation but absent from data (often method-development residue)
setdiff(annot_feat_ids, data_features)
```

A common cause is differing encoding of special characters (parentheses,
slashes, unicode escapes) between the integration software output and a
hand-edited Excel file.

## Practical recommendations

- Re-import annotations after every edit. Saved Excel files held open in
  a separate process can be silently locked and read only in part.
- Save CSVs as UTF-8 without BOM. Excel’s default “CSV UTF-8” export
  adds a byte-order mark that shifts the first column header.
- Avoid special characters in `analysis_id` and `feature_id`:
  parentheses, slashes, spaces. They survive R but complicate downstream
  column references; keep to letters, digits, underscores, and hyphens.
- Keep the annotation file under version control alongside the data
  file.

## Next steps

- [Sample types and QC
  roles](https://slinghub.github.io/MRMhub/quant/articles/manual-06-sample-types.md):
  canonical `qc_type` vocabulary
- [Metadata tables and
  matching](https://slinghub.github.io/MRMhub/quant/articles/manual-05-metadata.md):
  required columns and identifier rules
- [Importing
  metadata](https://slinghub.github.io/MRMhub/quant/articles/recipe-05-import-metadata.md):
  attaching metadata from files or a template
- [Importing analytical
  data](https://slinghub.github.io/MRMhub/quant/articles/manual-04-data-import.md):
  importing peak-area / concentration data
