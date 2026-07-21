# Importing Analytical Data

Manual

Analytical data, i.e. preprocessed data from mass spectrometry
experiments, can be imported from different sources. Data files present
in a folder can also be imported and merged, which is useful when the
raw data processing is broken down into batches that produce separate
result files. The following formats are currently supported; each
importer reads a CSV or TSV file and returns an `MRMhubExperiment`, and
the exact file layout and all arguments are documented on the linked
reference pages.

| Source | Function |
|----|----|
| MRMhub / INTEGRATOR *(recommended)* | [`import_data_mrmhub()`](https://slinghub.github.io/MRMhub/quant/reference/import_data_mrmhub.md) |
| Agilent MassHunter Quant | [`import_data_masshunter()`](https://slinghub.github.io/MRMhub/quant/reference/import_data_masshunter.md) |
| Skyline (small molecule) | [`import_data_skyline()`](https://slinghub.github.io/MRMhub/quant/reference/import_data_skyline.md) |
| Generic wide CSV | [`import_data_csv_wide()`](https://slinghub.github.io/MRMhub/quant/reference/import_data_csv_wide.md) |
| Generic long CSV | [`import_data_csv_long()`](https://slinghub.github.io/MRMhub/quant/reference/import_data_csv_long.md) |

When the analytical results contain metadata, such as sample and feature
annotations, these can be imported into the `MRMhubExperiment` object as
well. The imported metadata is checked for integrity and consistency and
then added to the annotation tables; to include it, set the argument
`import_metadata = TRUE` (see [Importing
Metadata](https://slinghub.github.io/MRMhub/quant/articles/manual-05-metadata.md)).

## MRMhub / INTEGRATOR

Long-format output files produced by MRMhub-INTEGRATOR, the
peak-integration component of the project, can be imported directly.
Specific metadata present in the data file is imported as well when
`import_metadata = TRUE`:

``` r

filepath <- system.file("extdata/MRMhub_demo.tsv", package = "mrmhub")
mexp <- MRMhubExperiment()
mexp <- import_data_mrmhub(mexp, filepath, import_metadata = TRUE)
#> Warning: Unknown or uninitialised column: `valid_feature`.
#> Warning: Unknown or uninitialised column: `is_quantifier`.
```

## Agilent MassHunter Quant

Peak integration results exported from Agilent MassHunter Quant in CSV
format can be imported, with samples in rows and features in columns.
Import of qualifier results is supported, and sample, method and result
metadata present in the file can also be imported
(`import_metadata = TRUE`):

``` r

filepath <- system.file("extdata/MHQuant_demo.csv", package = "mrmhub")
mexp <- MRMhubExperiment()
mexp <- import_data_masshunter(mexp, filepath, import_metadata = TRUE)
#> Warning: Unknown or uninitialised column: `valid_feature`.
#> Warning: Unknown or uninitialised column: `is_quantifier`.
```

## Skyline

Small-molecule peak integration results from
[Skyline](https://skyline.ms/) can be imported from long-format CSV
reports. The `analysis_id` is mapped from the `Replicate Name` column,
and unique `feature_id`s are generated from the `Molecule Name` together
with the precursor/product names or *m/z* values, unless the
`Molecule Name` alone already identifies the feature (controlled by
`transition_id_columns`):

``` r

filepath <- system.file("extdata/Skyline_MoleculeTransitionResults.csv", package = "mrmhub")
mexp <- MRMhubExperiment()
mexp <- import_data_skyline(mexp, filepath,
                            import_metadata = TRUE,
                            transition_id_columns = "mz")
#> Warning: Unknown or uninitialised column: `valid_feature`.
#> Warning: Unknown or uninitialised column: `is_quantifier`.
```

**Exporting the report from Skyline**

Navigate to *File → Export* and select the *Molecule Transition Results*
format. Ensure the export includes `Replicate Name`, `Molecule Name`,
and either `Precursor Mz` and `Product Mz` or `Precursor Name` and
`Product Name`, plus at least one feature variable such as `Area` or
`Retention Time`. Further options are described in
[`import_data_skyline()`](https://slinghub.github.io/MRMhub/quant/reference/import_data_skyline.md).

## Generic wide-format CSV

Analysis results, whether raw intensities (e.g. peak areas) or
preprocessed data (e.g. concentrations), can be provided as plain
wide-format CSV tables with analyses in rows and features in columns.
The data type held in the table is declared with the `variable_name`
argument:

``` r

filepath <- system.file("extdata/plain_wide_dataset.csv", package = "mrmhub")
mexp <- MRMhubExperiment()
mexp <- import_data_csv_wide(mexp, path = filepath,
                             variable_name = "area",
                             import_metadata = TRUE)
#> Warning: Unknown or uninitialised column: `valid_feature`.
#> Warning: Unknown or uninitialised column: `is_quantifier`.
```

## Generic long-format CSV

Analysis results containing various feature variables can be provided as
generic long-format CSV tables, where each row is a feature–value
observation for a sample and additional columns capture feature
variables and sample- or method-related metadata. By default the file
must include `analysis_id`, `feature_id`, and at least one feature-value
column such as `area`; if the file uses different column names, a
`column_mapping` associates the MRMhub column names with those in the
file. The full column list and mapping rules are given in
[`import_data_csv_long()`](https://slinghub.github.io/MRMhub/quant/reference/import_data_csv_long.md):

``` r

filepath <- system.file("extdata/plain_long_dataset.csv", package = "mrmhub")
mexp <- MRMhubExperiment()
mexp <- import_data_csv_long(mexp, path = filepath, import_metadata = TRUE,
  column_mapping = c(
    "analysis_id"     = "raw_data_filename",
    "qc_type"         = "qc_type",
    "feature_id"      = "feature_id",
    "feature_class"   = "feature_class",
    "istd_feature_id" = "istd_feature_id",
    "feature_rt"      = "rt",
    "feature_area"    = "area"))
#> Warning: Unknown or uninitialised column: `valid_feature`.
#> Warning: Unknown or uninitialised column: `is_quantifier`.
```

## File formats

The previews below show the first rows of the example files bundled with
the package, so that an input file can be recognised and prepared before
importing. Vendor and tool exports (MRMhub/INTEGRATOR, MassHunter,
Skyline) are produced by the software and are not edited by hand,
whereas the generic wide and long CSV tables are prepared manually. The
full column reference for each format is given on its linked function
reference page.

### MRMhub / INTEGRATOR — long CSV/TSV

The long output has one row per analysis × feature, tab- or
comma-separated. Besides the columns shown it also carries
`internal_standard`, `time_stamp`, transition columns (`precursor_mz`,
`product_mz`, `collision_energy`, `polarity`), and integration columns
(`height`, `FWHM`, `rt_int_start`, `rt_int_end`). The file is produced
by INTEGRATOR and is not prepared by hand.

``` r

show_head(
  "MRMhub_demo.tsv",
  delim = "\t",
  cols = c("feature_name", "raw_data_filename", "sample_type", "batch", "rt_apex", "area")
)
```

| feature_name | raw_data_filename | sample_type | batch | rt_apex | area |
|:---|:---|:---|---:|---:|---:|
| CE 18:1 | Longit_BLANK-01 (Eluent A).mzML | SBLK | 1 | 7.295 | 3134.1636 |
| CE 18:1 | Longit_B-ISTD 01 Extr.mzML | PBLK | 1 | 7.295 | 854.8992 |
| CE 18:1 | Longit_Un-ISTD 01 Unextr.mzML | UBLK | 1 | 7.280 | 229.5320 |

First 3 rows of `MRMhub_demo.tsv` (showing 6 of 18 columns) {.table}

### Agilent MassHunter Quant — wide CSV

A MassHunter Quant export is wide with a two-row header. The first
header row groups columns by compound (`<Compound> Method` and
`<Compound> Results` blocks) after a leading `Sample` block; the second
row holds the actual sub-headers. The `Method`/`Results` blocks repeat
for every compound (quantifiers and qualifiers).

| Sample |  |  |  | CE 18:1 — Method |  |  |  | CE 18:1 — Results |  |  | … |
|----|----|----|----|----|----|----|----|----|----|----|----|
| Data File | Name | Type | Acq. Date-Time | Precursor Ion | Product Ion | Collision Energy | RT | RT | Area | FWHM |  |
| 001\_…01.d | 001\_…01 | Sample | 4/12/18 18:28 | 668.6 | 369.3 | 10 | 7.16 | 7.16 | 5152996 | 0.081 |  |
| 002\_…02.d | 002\_…02 | Sample | 4/12/18 18:39 | 668.6 | 369.3 | 10 | 7.16 | 7.16 | 4789505 | 0.080 |  |

### Skyline (small molecule) — long CSV

The *Molecule Transition Results* export has one row per transition
result; `Replicate Name` becomes `analysis_id`, `Molecule Name` becomes
`feature_id`, and transitions are identified by precursor/product name
or *m/z*.

``` r

show_head(
  "Skyline_MoleculeTransitionResults.csv",
  cols = c("Molecule Name", "Replicate Name", "Precursor Mz", "Product Mz", "Retention Time", "Area")
)
```

| Molecule Name | Replicate Name | Precursor Mz | Product Mz | Retention Time |   Area |
|:--------------|:---------------|-------------:|-----------:|---------------:|-------:|
| Aldosterone   | SBLK1          |        359.2 |      331.2 |           2.43 |      2 |
| Aldosterone   | SBLK1          |        359.2 |      189.0 |           2.70 |     36 |
| Aldosterone   | SBLK1          |        361.2 |      343.1 |           2.49 | 121860 |

First 3 rows of `Skyline_MoleculeTransitionResults.csv` (showing 6 of 16
columns) {.table}

### Generic wide CSV

One row per sample, one column per feature; the column name is the
`feature_id` and the values are of the type declared by `variable_name`.

``` r

show_head("plain_wide_dataset.csv")
```

| analysis_id | qc_type | batch_id | S1P 18:1;O2 | S1P 18:2;O2 | S1P 18:0;O2 | S1P 16:1;O2 | S1P 17:1;O2 |
|---:|:---|---:|---:|---:|---:|---:|---:|
| 1 | SPL | 1 | 943.9524 | 321.1111 | 338.2323 | 91.16817 | 24.52784 |
| 2 | SPL | 1 | 976.9823 | 543.4100 | 217.6715 | 133.31666 | 66.12263 |
| 3 | SPL | 1 | 1155.8708 | 1327.3995 | 1539.4633 | 1690.63083 | 339.54704 |

First 3 rows of `plain_wide_dataset.csv` {.table}

### Generic long CSV

One row per `(sample, feature)` measurement. Columns are auto-detected
by name (case-insensitive); the bundled example uses INTEGRATOR-style
headers such as `raw_data_filename` and `rt_apex`, so it is imported
with a `column_mapping`.

``` r

show_head(
  "plain_long_dataset.csv",
  cols = c("feature_id", "raw_data_filename", "sample_type", "batch", "rt_apex", "area")
)
```

| feature_id | raw_data_filename     | sample_type | batch | rt_apex |    area |
|:-----------|:----------------------|:------------|------:|--------:|--------:|
| CE 18:1    | Longit_batch1_15.mzML | SPL         |     1 |   7.295 | 1546867 |
| CE 18:1    | Longit_batch1_16.mzML | SPL         |     1 |   7.311 | 1407493 |
| CE 18:1    | Longit_batch1_17.mzML | SPL         |     1 |   7.311 | 1378911 |

First 3 rows of `plain_long_dataset.csv` (showing 6 of 18 columns)
{.table}

## Multiple files: import and merging

Multiple data files can be imported and merged by passing either a list
of file paths or a folder path, in which case all data files in the
directory are imported. This is useful when raw data processing is
divided into batches that produce separate result files. The merged data
is checked for consistency, so that each `analysis_id`–`feature_id` pair
is unique and the same feature cannot be reported more than once within
an analysis.

## Identifier normalization

All identifiers are normalized as they are imported. Leading and
trailing spaces are removed and internal runs of whitespace are
collapsed to a single space, so `"QC 01"` and `"QC 01"` become the same
value. Raw-data file extensions (`.mzML`, `.d`, `.raw`, `.wiff`,
`.wiff2`, `.lcd`, `.chrom`, case-insensitive) are stripped from
`analysis_id`, and only a genuine *trailing* extension is removed — a
name such as `Study.data_01.d` keeps its internal `.data`.

The identical normalization is applied when metadata is imported. This
is what lets an `analysis_id` typed into a metadata sheet match the one
derived from a data-file name; without it, a stray space would cause the
analysis to be dropped silently when data and metadata are joined.

This normalization is **always** applied, on both data and metadata, and
**no warning is issued** when whitespace is removed — it is silent by
design. Stray spaces are a common and hard-to-trace cause of identifiers
failing to map between data and metadata, so they are removed rather
than reported. The one visible consequence is that two identifiers
differing *only* by whitespace collapse to one and are then reported as
a duplicate (for example, the same feature appearing to be measured
twice in one analysis).

## Next steps

- [Importing
  Metadata](https://slinghub.github.io/MRMhub/quant/articles/manual-05-metadata.md)
  — attach and validate sample and feature annotations
- [The MRMhubExperiment Data
  Object](https://slinghub.github.io/MRMhub/quant/articles/manual-02-data-object.md)
  — the object the data is loaded into
- [Basic MRMhub
  Workflow](https://slinghub.github.io/MRMhub/quant/articles/tutorial-02-basic-workflow.md)
  — start processing the imported data
- [Function
  reference](https://slinghub.github.io/MRMhub/quant/reference/index.md)
  — full arguments for every importer
