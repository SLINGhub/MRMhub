# Import data from an mzTab-M file

Imports quantitative results from an
[mzTab-M](https://github.com/HUPO-PSI/mzTab-M) file (e.g. produced by
Lipid Data Analyzer, MS-DIAL or MZmine) into an `MRMhubExperiment`. Each
Small Molecule Feature (`SMF`) becomes an mrmhub feature and each assay
an analysis; the per-assay abundances are imported as
`feature_intensity`.

## Usage

``` r
import_data_mztab(data = NULL, path, import_metadata = TRUE, silent = FALSE)
```

## Arguments

- data:

  An `MRMhubExperiment` object (e.g. from
  [`MRMhubExperiment()`](https://slinghub.github.io/MRMhub/quant/reference/MRMhubExperiment.md)).

- path:

  Path to a `.mzTab` file, or a directory of them.

- import_metadata:

  If `TRUE` (default), derive analysis/feature metadata (incl.
  `batch_id`, formula, neutral mass) from the imported data via
  [`import_metadata_from_data()`](https://slinghub.github.io/MRMhub/quant/reference/import_metadata_from_data.md).

- silent:

  Suppress messages.

## Value

The updated `MRMhubExperiment`.

## Details

mzTab-M is a quantification *report*, so an import is necessarily
partial: the single reported abundance per feature is mapped to
`feature_intensity`, and feature identities (name, formula, neutral
mass, m/z, retention time) are taken from the `SMF`/`SML` sections where
available. Internal-standard relationships, QC-type assignments and
calibration metadata are **not** part of mzTab-M and must be supplied
afterwards with
[`add_metadata()`](https://slinghub.github.io/MRMhub/quant/reference/add_metadata.md).
`study_variable` group membership is imported best-effort as `batch_id`
(mzTab-M has no analytical-batch concept).

## See also

[`import_data_mrmhub()`](https://slinghub.github.io/MRMhub/quant/reference/import_data_mrmhub.md),
[`save_dataset_mztab()`](https://slinghub.github.io/MRMhub/quant/reference/save_dataset_mztab.md),
[`add_metadata()`](https://slinghub.github.io/MRMhub/quant/reference/add_metadata.md)

## Examples

``` r
if (FALSE) { # \dontrun{
mexp <- MRMhubExperiment()
mexp <- import_data_mztab(mexp, "LDA_export.mzTab")
} # }
```
