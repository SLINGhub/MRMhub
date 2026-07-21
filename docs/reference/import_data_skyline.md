# Import Skyline peak integration results

This function imports tabular data files (\*.csv) exported from
`Skyline`, containing peak integration results.

## Usage

``` r
import_data_skyline(
  data = NULL,
  path,
  transition_id_columns = c("name", "mz", "none"),
  import_metadata = TRUE,
  silent = FALSE
)
```

## Arguments

- data:

  A `MRMhubExperiment` object.

- path:

  One or more file paths, or a directory path from which all matching
  files will be imported.

- transition_id_columns:

  A character vector specifying the columns that define the transition
  (precursor and product) to use for unique `feature_id` generation.
  Options are "name", "mz", or "none". If "none", `feature_id` is
  derived from `Molecule Name` and `Precursor Name` or `Product Name`.
  If "mz", `feature_id` is based on `Precursor Mz` and `Product Mz`.
  Using "none" will result in `feature_id` being a copy of
  `Molecule Name`, with an error raised if it is not unique for each
  transition.

- import_metadata:

  Logical; whether to import additional metadata columns (e.g.,
  precursor/product m/z values).

- silent:

  Logical; whether to suppress most notifications.

## Value

A `MRMhubExperiment` object containing the imported data.

## Details

In Skyline, transitions are defined by the `Molecule Name` and
corresponding precursor and product m/z values, rather than any
identifier. When importing this data, the `feature_id` is generated
using the `Molecule Name` with either precursor/product names or m/z
values, unless `Molecule Name` uniquely identifies the features (refer
to the `transition_id_columns` argument below).

The following supported columns from Skyline can be imported:

|                      |                       |          |
|----------------------|-----------------------|----------|
| Skyline Column Name  | MRMhub Column Name    | Required |
| `Replicate Name`     | `analysis_id`         | Yes      |
| `Molecule List Name` | `feature_class`       | No       |
| `Molecule Name`      | `feature_id`          | Yes      |
| `Precursor Name`     | `feature_id`          | Yes\*    |
| `Product Name`       | `feature_id`          | Yes\*    |
| `Precursor Mz`       | `method_precursor_mz` | Yes\*    |
| `Product Mz`         | `method_product_mz`   | Yes\*    |
| `Area`               | `feature_area`        | Yes      |
| `Retention Time`     | `feature_rt`          | No       |

\*Requirements for these columns are described in
`transition_id_columns`.

To export results from Skyline, use the 'Molecule Transition Results'
format and include `Replicate Name`, `Molecule Name`, and either
`Precursor Mz`/`Product Mz` or `Precursor Name`/`Product Name` columns.
At least one feature variable, such as `Area` or `RT`, must also be
exported.

## Identifier normalization

All imported identifiers are whitespace-normalized on import: leading
and trailing spaces are removed and internal runs of whitespace are
collapsed to a single space (for example `"QC 01"` becomes `"QC 01"`).
Raw-data file extensions (`.mzML`, `.d`, `.raw`, `.wiff`, `.wiff2`,
`.lcd`, `.chrom`, case-insensitive) are stripped from `analysis_id`.

The same normalization is applied to both the data and the metadata,
which is what lets an `analysis_id` typed into metadata match the one
derived from a data-file name instead of silently failing to join. A
consequence is that two identifiers differing only by whitespace
collapse to one and are then reported as duplicates.

## Examples

``` r
mexp <- MRMhubExperiment()
file_path <- system.file("extdata", "Skyline_MoleculeTransitionResults.csv", package = "mrmhub")
mexp <- import_data_skyline(
  data = mexp,
  path = file_path,
  transition_id_columns = "mz",
  import_metadata = TRUE
)
#> ✔ Imported 6 analyses with 21 features.
#> ℹ feature_area selected as default feature intensity. Modify with `set_intensity_var()`.
#> Warning: Unknown or uninitialised column: `valid_feature`.
#> Warning: Unknown or uninitialised column: `is_quantifier`.
#> ✔ Analysis metadata associated with 6 analyses.
#> ✔ Feature metadata associated with 21 features.
#> ℹ Analysis order was based on `analysis_order` column of imported data. Use `set_analysis_order` to change the order.
print(mexp)
#> 
#> ── MRMhubExperiment ────────────────────────────────────────────────────────────
#> Title:
#> 
#> Processing status: Annotated raw AREA values
#> 
#> ── Annotated Raw Data ──
#> 
#> • Analyses: 6
#> • Features: 21
#> • Raw signal used for processing: `feature_area`
#> 
#> ── Metadata ──
#> 
#> • Analyses/samples: ✔
#> • Features/analytes: ✔
#> • Internal standards: ✖
#> • Response curves: ✖
#> • Calibrants/QC concentrations: ✖
#> • Study samples: ✖
#> • Interferences: ✖
#> 
#> ── Processing Status ──
#> 
#> • Isotope corrected: ✖
#> • ISTD normalized: ✖
#> • ISTD quantitated: ✖
#> • Drift corrected variables: ✖
#> • Batch corrected variables: ✖
#> • Feature filtering applied: ✖
#> 
#> ── Exclusion of Analyses and Features ──
#> 
#> • Analyses manually excluded (`analysis_id`): ✖
#> • Features manually excluded (`feature_id`): ✖
```
