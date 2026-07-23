# Export an experiment to mzTab-M (HUPO-PSI)

Writes an
[`MRMhubExperiment`](https://slinghub.github.io/MRMhub/quant/reference/MRMhubExperiment-class.md)
to an [mzTab-M 2.0.0-M](https://github.com/HUPO-PSI/mzTab-M) file, the
HUPO-PSI community standard for reporting quantitative metabolomics /
lipidomics results (and the format expected by repositories such as
MetaboLights).

## Usage

``` r
save_dataset_mztab(
  data = NULL,
  path,
  variable = "conc",
  instrument = NULL,
  contact = NULL,
  publication = NULL,
  rt_in_minutes = TRUE,
  overwrite = TRUE
)
```

## Arguments

- data:

  An
  [`MRMhubExperiment`](https://slinghub.github.io/MRMhub/quant/reference/MRMhubExperiment-class.md)
  object.

- path:

  Output file path. A `.mzTab` extension is appended if missing.

- variable:

  Feature variable used as abundance. One of `"conc"`, `"intensity"`,
  `"norm_intensity"`, `"area"` or `"height"`. Default `"conc"` (falls
  back to `"intensity"` if not quantified).

- instrument, contact, publication:

  Optional single strings used to enrich the `MTD` metadata header
  (instrument name, contact name, publication identifier). `NULL`
  (default) omits them.

- rt_in_minutes:

  Logical; are `feature_rt` values in minutes? mzTab-M stores retention
  time in seconds, so values are multiplied by 60 when `TRUE` (default).

- overwrite:

  Logical; overwrite an existing file. Default `TRUE`.

## Value

Invisibly returns the (normalised) output `path`. Called for its side
effect of writing the file.

## Details

The full dataset is exported: every analysis becomes an `assay` (QC,
blank and calibration samples included), every feature a Small Molecule
Feature (`SMF`) row, and features are grouped by analyte into Small
Molecule Summary (`SML`) rows. A minimal Small Molecule Evidence (`SME`)
row is emitted per feature so all three table types are present.

**Abundance.** `variable` selects which `feature_*` value is written to
the `abundance_assay[n]` columns. The default `"conc"` uses final
concentrations and declares the matching concentration unit; if the
experiment has not been quantified, the exporter falls back to raw
`feature_intensity` with an "Arbitrary quantification unit".

**What is *not* exported.** mzTab-M is a quantification report, not a
processing-state container. Internal-standard relationships,
QC/calibration metrics, drift/batch-correction state and the
`qc_type`/batch structure are not representable and are therefore not
written (ISTD features are merely flagged via an
`opt_global_is_internal_standard` column). See the *mzTab-M export*
recipe article for the full mapping.

## See also

[`save_report_xlsx()`](https://slinghub.github.io/MRMhub/quant/reference/save_report_xlsx.md),
[`save_dataset_csv()`](https://slinghub.github.io/MRMhub/quant/reference/save_dataset_csv.md)

## Examples

``` r
if (FALSE) { # \dontrun{
save_dataset_mztab(mexp, "experiment.mzTab")
save_dataset_mztab(mexp, "raw.mzTab", variable = "area")
} # }
```
