# Preparing and importing data

Tutorial Prerequisites: [Getting started with
MRMhub](https://slinghub.github.io/MRMhub/quant/articles/tutorial-02-getting-started-mrmhub.md)

Every analysis begins with the analytical data: the pre-processed
measurements from the instrument, such as peak areas. That alone is
already enough for some basic exploration, for example plotting signal
intensities against injection order. Most processing, though, also draws
on metadata: the information describing the samples and features behind
those measurements. Some metadata travels with the data file itself
(INTEGRATOR and MassHunter results in particular can carry it, pulled in
with the importer’s `import_metadata` argument) while the rest is
imported from separate sources. This tutorial covers both, from a raw
result file to a fully annotated `MRMhubExperiment` ready for
processing.

## 1. Importing analytical data

Analytical data, such as pre-processed measurement data (e.g. peak
areas), can be imported from several software platforms. MRMhub reads
results from INTEGRATOR, its bundled peak picker
([`import_data_mrmhub()`](https://slinghub.github.io/MRMhub/quant/reference/import_data_mrmhub.md)),
from Agilent MassHunter Quantitative Analysis
([`import_data_masshunter()`](https://slinghub.github.io/MRMhub/quant/reference/import_data_masshunter.md)),
from Skyline
([`import_data_skyline()`](https://slinghub.github.io/MRMhub/quant/reference/import_data_skyline.md)),
and from generic wide- or long-format CSV files
([`import_data_csv_wide()`](https://slinghub.github.io/MRMhub/quant/reference/import_data_csv_wide.md)
and
[`import_data_csv_long()`](https://slinghub.github.io/MRMhub/quant/reference/import_data_csv_long.md)).

Do not manually edit these files before importing them. Hand edits can
corrupt the file or introduce silent errors in the data; MRMhub is built
around reproducible, automated workflows, and editing the source data
works against that.

We start from an empty object and read an INTEGRATOR result file. The
imported measurements land in the `dataset_orig` slot and are copied to
the working `dataset`; with `import_metadata = TRUE`, the sample- and
feature-level metadata embedded in the file (such as acquisition time
stamps and precursor/product m/z) is brought across as well.

``` r

library(mrmhub)

mexp <- MRMhubExperiment()
mexp <- import_data_mrmhub(
  mexp,
  path = "datasets/sPerfect_MRMhub.tsv",
  import_metadata = TRUE)
```

    ✔ Imported 499 analyses with 503 features.

    ℹ feature_area selected as default feature intensity. Modify with `set_intensity_var()`.

    ✔ Analysis metadata associated with 499 analyses.

    ✔ Feature metadata associated with 503 features.

A plain wide-format CSV of peak areas is imported the same way, into a
fresh object. Here `variable_name` names the quantity stored in the
table’s cells, so MRMhub knows which measurement it is reading.

``` r

mexp2 <- MRMhubExperiment()
mexp2 <- import_data_csv_wide(
  mexp2,
  path = "data/plain_wide_dataset.csv",
  variable_name = "area",
  import_metadata = TRUE)
```

See [Importing analytical
data](https://slinghub.github.io/MRMhub/quant/articles/manual-04-data-import.md)
for a decision guide and full documentation of every importer.

## 2. Metadata

Metadata (the analysis metadata that describes and annotates the
analytical data at the sample and feature level) is essential to the
MRMhub workflow. Some of it can be read straight from the imported
result file, but more commonly the required metadata comes from other
sources and has to be imported separately. Which tables are needed
depends on the intended processing; see [Data and metadata in
MRMhub](https://slinghub.github.io/MRMhub/quant/articles/manual-02-data-object.md)
for an overview of the metadata categories.

When the data file already carries embedded analysis metadata (an
INTEGRATOR result, for instance, can hold `qc_type`, `batch_id` and
`analysis_order` columns),
[`import_metadata_from_data()`](https://slinghub.github.io/MRMhub/quant/reference/import_metadata_from_data.md)
lifts those columns into the annotation tables in a single call:

``` r

mexp <- import_metadata_from_data(mexp)
```

This is the fast path for data that already contains its analysis
metadata. Internal standards, calibration concentrations and other
annotations still come from separate sources, prepared and imported as
shown below.

Integrity of the data and metadata is key to accurate, reproducible
processing. MRMhub therefore inspects imported metadata for completeness
and for consistency of the IDs used across the different tables, and
reports a summary of the errors, warnings and notes it finds after each
import.

## 3. Preparing metadata

Metadata can be imported from Excel sheets, CSV files, or R data frames.
Preparing it is often a manual step, collecting information from various
sources. To support this, MRMhub ships Excel templates that carry the
expected column headers and usage notes for every supported metadata
type. Starting from a template and filling it in is the recommended
approach.
[`save_metadata_templates()`](https://slinghub.github.io/MRMhub/quant/reference/save_metadata_templates.md)
writes the workbook (`metadata_template.xlsx` by default) to the working
directory:

``` r

save_metadata_templates()
```

    ✔ Metadata table templates were saved to 'metadata_template.xlsx'.

## 4. Importing metadata

Metadata can be imported table by table from CSV files. Below we bring
in the analysis and feature tables. `excl_unmatched_analyses = TRUE`
drops any imported analysis that has no matching row in the metadata,
and `ignore_warnings = TRUE` lets the import proceed despite the
integrity warnings reported above.

``` r
mexp <- import_metadata_analyses(
  mexp,
  path = "datasets/analysis_metadata.csv",
  excl_unmatched_analyses = TRUE,
  ignore_warnings = TRUE)
Found no errors, 1 warning, and no notes in the metadata.
----------------------------------------------------------------
  Type  Table    Column      Issue                         Count
1 W*    Analyses analysis_id Analyses not in analysis data    15

----------------------------------------------------------------
E = Error, W = Warning, W* = Suppressed Warning, N = Note
----------------------------------------------------------------
```

    ✔ Analysis metadata associated with 499 analyses.

    ✔ Feature metadata associated with 503 features.

``` r

mexp <- import_metadata_features(
  mexp,
  path = "datasets/feature_metadata.csv",
  ignore_warnings = TRUE)
Found no errors, 2 warnings, and no notes in the metadata.
-----------------------------------------------------------------
  Type  Table    Column     Issue                           Count
1 W*    Features feature_id Feature(s) without metadata         1
2 W*    Features feature_id Feature(s) not in analysis data     4

-----------------------------------------------------------------
E = Error, W = Warning, W* = Suppressed Warning, N = Note
-----------------------------------------------------------------
```

    ✔ Analysis metadata associated with 499 analyses.

    ✔ Feature metadata associated with 502 features.

Metadata can also be read from the sheets of an Excel workbook, which
lets all tables live in a single file. Here we add the internal-standard
metadata from the `ISTDs` sheet:

``` r
mexp <- import_metadata_istds(
  mexp,
  path = "datasets/metadata_tables.xlsx",
  sheet = "ISTDs",
  ignore_warnings = TRUE)
Found no errors, 1 warning, and no notes in the metadata.
-----------------------------------------------------------------------
  Type  Table Column                Issue                         Count
1 W*    ISTDs quant_istd_feature_id Internal standard(s) not used     1

-----------------------------------------------------------------------
E = Error, W = Warning, W* = Suppressed Warning, N = Note
-----------------------------------------------------------------------
```

Finally, metadata can be passed directly as an R `data.frame`, so it can
be prepared in R or pulled from a database or LIMS. Below we import the
quality control sample concentrations from a table read into R:

``` r
df_qcinfo <- readr::read_table(file = "datasets/qc_metadata.txt")
mexp <- import_metadata_qcconcentrations(mexp, table = df_qcinfo)
Found no errors, no warnings, and 3 notes in the metadata.
--------------------------------------------------------------------------------
  Type  Table             Column     Issue                                 Count
1 N     QC concentrations analyte_id Non-ISTD analytes missing from QC co…     1
2 N     QC concentrations sample_id  Samples not defined in analysis data      6
3 N     QC concentrations analyte_id Analytes not defined in analysis data     6

--------------------------------------------------------------------------------
E = Error, W = Warning, W* = Suppressed Warning, N = Note
--------------------------------------------------------------------------------
```

## 5. Metadata from the MSOrganiser template

Rather than importing each table on its own, all metadata can be
collected in a single MSOrganiser template (an Excel file providing a
sheet for every metadata type, with built-in validity and integrity
checks) and imported in one step. Obtain the template from
<https://github.com/SLINGhub/mrmhub>, or save a blank copy to the
working directory:

``` r

save_metadata_msorganiser_template()
```

Only the tables required by the intended workflow need to be completed;
the import reads every table that has been filled in:

``` r

mexp <- import_metadata_msorganiser(
  mexp,
  path = "datasets/sPerfect_Metadata.xlsx",
  ignore_warnings = TRUE)
```

See [Importing
metadata](https://slinghub.github.io/MRMhub/quant/articles/manual-05-metadata.md)
for the full set of metadata tables, templates and validation checks.

## Next steps

- [Importing analytical
  data](https://slinghub.github.io/MRMhub/quant/articles/manual-04-data-import.md):
  decision guide and reference for every importer
- [Importing
  metadata](https://slinghub.github.io/MRMhub/quant/articles/manual-05-metadata.md):
  metadata tables, templates and validation
- [Common defects and
  fixes](https://slinghub.github.io/MRMhub/quant/articles/manual-05-metadata.md):
  checking metadata for common errors
- [Lipidomics
  workflow](https://slinghub.github.io/MRMhub/quant/articles/tutorial-03-lipidomics-workflow.md):
  a complete walkthrough from import to export
