# Validating and Fixing Metadata

Tutorial

Most processing errors in MRMhub trace back to defects in the annotation
tables rather than the analytical data itself. The most frequent
offenders are mismatched `analysis_id` between data and annotation,
missing required columns (`qc_type`, `batch_id`, `analysis_order`), and
`qc_type` labels that do not match the canonical vocabulary used
internally for QC selection. This tutorial covers generating a template,
validating annotations against imported data, and resolving the typical
defects.

See [Sample Types and QC
Roles](https://slinghub.github.io/MRMhub/quant/articles/manual-06-sample-types.md)
for the canonical `qc_type` vocabulary and [Metadata
Import](https://slinghub.github.io/MRMhub/quant/articles/manual-05-metadata.md)
for the per-table importer reference.

**Time** ~10 min  ·  **Level** Beginner  ·  **Prerequisites** [Your
first
analysis](https://slinghub.github.io/MRMhub/quant/articles/tutorial-00-first-analysis.md)

## 1. Generate a metadata template

[`save_metadata_templates()`](https://slinghub.github.io/MRMhub/quant/reference/save_metadata_templates.md)
writes an XLSX template containing one sheet per annotation table
(`annot_analyses`, `annot_features`, `annot_istds`,
`annot_responsecurves`, `annot_qcconcentrations`). The template carries
the expected column names and example rows.

``` r

library(mrmhub)

save_metadata_templates(path = "metadata/sPerfect_metadata.xlsx")
```

Fill in the sheets in Excel, save, and proceed to import. The
`MRMhub Metadata Organizer` template
([`save_metadata_msorganiser_template()`](https://slinghub.github.io/MRMhub/quant/reference/save_metadata_msorganiser_template.md))
is a richer alternative that bundles every metadata table into a single
`.xlsx` workbook, for labs that prefer Excel-driven workflows.

## 2. Extract a template from imported data

If the imported data file already carries embedded metadata (e.g. an
INTEGRATOR `long.tsv` with `qc_type`, `batch_id`, and `analysis_order`
columns),
[`import_metadata_from_data()`](https://slinghub.github.io/MRMhub/quant/reference/import_metadata_from_data.md)
lifts those columns into the annotation slots and links them to the
dataset in a single call. The function returns the updated
`MRMhubExperiment`.

``` r

myexp <- MRMhubExperiment()
myexp <- import_data_mrmhub(myexp,
                            path = "datasets/sPerfect_MRMhub.tsv",
                            import_metadata = FALSE)

# Pull embedded metadata, validate, and link in one step
myexp <- import_metadata_from_data(myexp)
```

This is a fast path for data that already contains analysis metadata in
the import file. For manual edits or additional annotation (ISTDs,
calibration concentrations, biological covariates), fill in the XLSX
template from Step 1 and use the per-table importers in Step 3.

## 3. Import and validate annotation tables

The per-table importers
([`import_metadata_analyses()`](https://slinghub.github.io/MRMhub/quant/reference/import_metadata_analyses.md),
[`import_metadata_features()`](https://slinghub.github.io/MRMhub/quant/reference/import_metadata_features.md),
[`import_metadata_istds()`](https://slinghub.github.io/MRMhub/quant/reference/import_metadata_istds.md),
[`import_metadata_responsecurves()`](https://slinghub.github.io/MRMhub/quant/reference/import_metadata_responsecurves.md),
[`import_metadata_qcconcentrations()`](https://slinghub.github.io/MRMhub/quant/reference/import_metadata_qcconcentrations.md))
read a CSV or Excel file, validate it against the imported data, and
link the validated table to the experiment. Defects are reported via
`cli` warnings and aborts; on success the table is attached.

``` r

myexp <- import_metadata_analyses(myexp,
                                  path = "metadata/sPerfect_metadata.xlsx",
                                  sheet = "annot_analyses",
                                  excl_unmatched_analyses = FALSE,
                                  ignore_warnings = FALSE)

myexp <- import_metadata_features(myexp,
                                  path = "metadata/sPerfect_metadata.xlsx",
                                  sheet = "annot_features")

myexp <- import_metadata_istds(myexp,
                               path = "metadata/sPerfect_metadata.xlsx",
                               sheet = "annot_istds")
```

The import validates:

- presence of required columns (`analysis_id`, `qc_type` for analyses;
  `feature_id` for features; `istd_feature_id` and an `istd_conc_*`
  column for ISTDs);
- uniqueness of identifiers (`analysis_id`, `feature_id`);
- consistency between annotation IDs and IDs present in `dataset_orig`;
- canonical `qc_type` labels (see [Sample
  Types](https://slinghub.github.io/MRMhub/quant/articles/manual-06-sample-types.md)).

Defects are reported using `cli` messages that name the offending table,
column, and IDs. When annotation tables are assembled programmatically
rather than read from a file, pass them to
[`add_metadata()`](https://slinghub.github.io/MRMhub/quant/reference/add_metadata.md)
as a named list; the same validation is applied before the tables are
linked.

## 4. Common defects and resolutions

**Column `qc_type` missing from `annot_analyses`**

`qc_type` is the only column besides `analysis_id` that is strictly
required. Add it before re-importing:

``` r

annot_analyses <- annot_analyses |>
  dplyr::mutate(qc_type = dplyr::case_when(
    stringr::str_detect(analysis_id, "BQC")  ~ "BQC",
    stringr::str_detect(analysis_id, "BLK")  ~ "SBLK",
    TRUE                                     ~ "SPL"
  ))
```

**`analysis_id` in data not found in annotation**

Some injections in the imported dataset have no matching row in the
annotation table. List them and inspect the difference —
leading/trailing whitespace and case mismatches are the most frequent
causes.

``` r

data_ids  <- unique(myexp@dataset_orig$analysis_id)
annot_ids <- annot_analyses$analysis_id

# IDs present in data but missing from annotation
setdiff(data_ids, annot_ids)

# Fix trailing whitespace introduced by Excel
annot_analyses <- annot_analyses |>
  dplyr::mutate(analysis_id = trimws(analysis_id))
```

`excl_unmatched_analyses = TRUE` in the importer drops unmatched
analyses silently — useful only when the omission is intentional (e.g.,
excluded conditioning injections).

**Non-canonical `qc_type` values**

The canonical vocabulary is `BQC`, `TQC`, `PQC`, `HQC`, `MQC`, `LQC`,
`QC`, `CAL`, `RQC`, `EQC`, `NIST`, `LTR`, `EQA`, `SPL`, `SST`, `SBLK`,
`TBLK`, `PBLK`, `MBLK`, `UBLK`. Labels are case-sensitive. Replace
non-standard values before validation:

``` r

unique(annot_analyses$qc_type)

annot_analyses <- annot_analyses |>
  dplyr::mutate(qc_type = dplyr::case_when(
    qc_type == "Standard" ~ "CAL",
    qc_type == "Blank"    ~ "SBLK",
    qc_type == "Pool"     ~ "BQC",
    qc_type == "Sample"   ~ "SPL",
    TRUE                  ~ qc_type
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

data_features  <- unique(myexp@dataset_orig$feature_id)
annot_feat_ids <- annot_features$feature_id

# In data but missing from annotation
setdiff(data_features, annot_feat_ids)

# In annotation but absent from data (often method-development residue)
setdiff(annot_feat_ids, data_features)
```

A common cause is differing encoding of special characters (parentheses,
slashes, unicode escapes) between the integration software output and a
hand-edited Excel file.

## 5. Practical recommendations

- Re-import annotations after every edit. Saved Excel files held open in
  a separate process can be silently locked and read partially.
- Save CSVs as UTF-8 without BOM. Excel’s default “CSV UTF-8” export
  adds a byte-order mark that shifts the first column header.
- Avoid special characters in `analysis_id` and `feature_id`
  (parentheses, slashes, spaces) — they survive R but complicate
  downstream column references. Letters, digits, underscores, hyphens.
- Keep the annotation file under version control alongside the data
  file.

## Next steps

- [Sample Types & QC
  Roles](https://slinghub.github.io/MRMhub/quant/articles/manual-06-sample-types.md)
  — canonical `qc_type` vocabulary
- [Importing
  Metadata](https://slinghub.github.io/MRMhub/quant/articles/manual-05-metadata.md)
  — per-table importer reference
- [Importing Analytical
  Data](https://slinghub.github.io/MRMhub/quant/articles/manual-04-data-import.md)
  — importing peak area / concentration data
- [Your First
  Analysis](https://slinghub.github.io/MRMhub/quant/articles/tutorial-00-first-analysis.md)
  — minimal end-to-end workflow
