# Metadata tables & matching

Manual

Metadata in this context refers to analysis metadata, i.e., data that
annotate the analytical data. MRMhub stores it in five tables (analyses,
features, internal standards, response curves, and calibration/QC
concentrations) that are attached to an `MRMhubExperiment` and linked to
the measurements by identifier. For the steps to obtain the templates
and import metadata, see [Preparing & importing
data](https://slinghub.github.io/MRMhub/quant/articles/tutorial-01-prep-data.md).

Integrity of metadata and data is essential for correct post-processing:
MRMhub inspects imported data and metadata for completeness and for
consistency of the IDs used across the tables, and prints a summary of
the identified errors, warnings, and notes to the console after import
so that possible issues can be identified and addressed.

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

| feature_id | istd_feature_id | feature_class | analyte_id | chem_formula | molecular_weight | feature_label | response_factor | is_quantifier | valid_integration | polarity | mrm_pattern | interference_feature_id | interference_proportion | remarks |
|----|----|----|----|----|----|----|----|----|----|----|----|----|----|----|

Template sheet `Features` (column headers) {.table style="width:100%;"}

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

## Identifier matching

Metadata is linked to the data by identifier: `analysis_id` joins the
sample metadata to the analyses, and `feature_id` joins the feature
metadata to the measurements. For the join to succeed, an identifier in
a metadata sheet must match the corresponding identifier in the data
exactly.

To make that robust, identifiers in metadata are normalized on import in
the same way as in the data: leading and trailing spaces are removed,
internal runs of whitespace are collapsed to a single space, and
raw-data file extensions (`.mzML`, `.d`, `.raw`, `.wiff`, `.wiff2`,
`.lcd`, `.chrom`) are stripped from `analysis_id`. So `"QC 01"` in a
sample sheet still matches `"QC 01"` in the data.

If analyses appear to be missing after
[`add_metadata()`](https://slinghub.github.io/MRMhub/quant/reference/add_metadata.md),
a difference in identifier spelling is the usual cause. Whitespace
differences are always squished on both sides and no warning is issued
for them: they are handled silently so a stray space cannot cause a
hard-to-trace mapping failure. Other differences (a raw-data extension
the import does not recognize, a typo, or a different naming scheme) are
not normalized, and the affected analyses are dropped from the join with
a warning.

## Common defects and fixes

Most processing errors trace back to defects in the annotation tables
rather than to the analytical data. The frequent offenders are a
mismatched `analysis_id` between data and annotation, a missing
`qc_type` label (the one column besides `analysis_id` the importer
requires), and `qc_type` values that fall outside the canonical
vocabulary. Each defect below pairs its diagnostic with the edit that
resolves it. After an annotation table is edited in R it is re-imported,
or passed to
[`add_metadata()`](https://slinghub.github.io/MRMhub/quant/reference/add_metadata.md)
as a named list, so the same validation runs again before the table is
linked.

**Column `qc_type` missing from `annot_analyses`**

`qc_type` is the only column besides `analysis_id` that the importer
strictly requires. When it is absent it can be derived from a naming
convention embedded in `analysis_id`:

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
annotation table. Listing the difference exposes the cause; leading or
trailing whitespace and case mismatches are the most frequent.

``` r

data_ids <- unique(mexp@dataset_orig$analysis_id)
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

MRMhub recognises only its canonical `qc_type` labels, and they are
case-sensitive; see [Sample types & QC
roles](https://slinghub.github.io/MRMhub/quant/articles/manual-06-sample-types.md)
for the full set. Non-standard values are mapped to the canonical set
before validating:

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

Repeated identifiers most often stem from copy-paste errors in Excel, or
from header rows interpreted as data.

``` r

annot_analyses |>
  dplyr::count(analysis_id) |>
  dplyr::filter(n > 1)
```

**Feature IDs in annotation do not match data**

Comparing the feature identifiers in both directions separates features
present in the data but unannotated from method-development residue left
only in the annotation. A common cause is differing encoding of special
characters (parentheses, slashes, unicode escapes) between the
integration-software output and a hand-edited Excel file.

``` r

data_features <- unique(mexp@dataset_orig$feature_id)
annot_feat_ids <- annot_features$feature_id

# In data but missing from annotation
setdiff(data_features, annot_feat_ids)

# In annotation but absent from data (often method-development residue)
setdiff(annot_feat_ids, data_features)
```

## Practical recommendations

- Annotations are re-imported after every edit. A saved Excel file held
  open in a separate process can be silently locked and read only in
  part.
- CSVs are saved as UTF-8 without BOM. Excel’s default “CSV UTF-8”
  export adds a byte-order mark that shifts the first column header.
- Special characters in `analysis_id` and `feature_id` (parentheses,
  slashes, spaces) survive R but complicate downstream column
  references; restricting IDs to letters, digits, underscores, and
  hyphens avoids this.
- The annotation file is kept under version control alongside the data
  file.

## Next steps

- [Preparing & importing
  data](https://slinghub.github.io/MRMhub/quant/articles/tutorial-01-prep-data.md):
  the import steps
- [Importing analytical
  data](https://slinghub.github.io/MRMhub/quant/articles/manual-04-data-import.md):
  importing the measurement data
- [Sample types & QC
  roles](https://slinghub.github.io/MRMhub/quant/articles/manual-06-sample-types.md):
  the `qc_type` values that drive QC logic
- [The MRMhubExperiment data
  object](https://slinghub.github.io/MRMhub/quant/articles/manual-02-data-object.md):
  where the metadata is stored
