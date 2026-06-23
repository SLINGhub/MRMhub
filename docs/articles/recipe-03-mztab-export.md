# Recipe: Export to mzTab-M

**Level:** Intermediate  \|  **Output:** `.mzTab` file (mzTab-M 2.0.0-M)
 \|  **Requires:** a processed `MRMhubExperiment`

## Goal

Export the quantitative results of a processed experiment to
[mzTab-M](https://github.com/HUPO-PSI/mzTab-M), the HUPO-PSI community
standard for reporting metabolomics / lipidomics quantification. mzTab-M
is a plain, tab-delimited text format that opens in Excel yet is fully
machine-readable, and is the format expected by repositories such as
[MetaboLights](https://www.ebi.ac.uk/metabolights/).

## Prerequisites

``` r

library(mrmhub)

# A fully processed MRMhubExperiment. Here we build one from the bundled
# `lipidomics_dataset`; in practice this would be your own processed object.
mexp <- lipidomics_dataset |>
  normalize_by_istd() |>
  quantify_by_istd()
```

## Basic export

``` r

# write to a temporary directory for this example; use your own path in practice
out_dir <- tempdir()

save_dataset_mztab(mexp, file.path(out_dir, "experiment.mzTab"))
```

By default the **final concentrations** (`feature_conc`) are written as
the per-sample abundances, with the concentration unit declared in the
file header. If the experiment has not been quantified, the exporter
automatically falls back to the raw `feature_intensity` and declares an
“Arbitrary quantification unit”.

Choose a different abundance variable with `variable`:

``` r

save_dataset_mztab(mexp, file.path(out_dir, "raw_areas.mzTab"), variable = "area")
save_dataset_mztab(
  mexp,
  file.path(out_dir, "intensities.mzTab"),
  variable = "intensity"
)
```

## What gets written

The full dataset is exported — every analysis (including QC, blank and
calibration samples) and every feature:

| mzTab-M section | mrmhub source |
|----|----|
| `MTD` metadata | experiment title, units, one `ms_run`/`assay` per analysis, one `study_variable` per `qc_type` |
| `SMF` (feature) | one row per `feature_id` (quantifiers, qualifiers **and** ISTDs); `abundance_assay[n]` = chosen variable; ISTDs flagged via `opt_global_is_internal_standard` |
| `SML` (summary) | one row per analyte, grouping its features; the quantifier drives the summary abundance and per-group mean / %CV |
| `SME` (evidence) | a minimal identification stub per feature |

You can enrich the metadata header with optional arguments:

``` r

save_dataset_mztab(
  mexp, file.path(out_dir, "experiment.mzTab"),
  instrument = "Agilent 6495C QqQ",
  contact = "Jane Doe",
  publication = "doi:10.1234/example"
)
```

**mzTab-M is a quantification report, not a full processing record.**
Internal-standard relationships, QC and calibration metrics,
drift/batch-correction state, and the QC-type / batch structure are not
part of the mzTab-M model and are therefore *not* reproduced on
round-trip. The file captures identities, the chosen abundance matrix,
and the study-variable grouping. Keep the `MRMhubExperiment` (or the
Excel report from
[`save_report_xlsx()`](https://slinghub.github.io/MRMhub/quant/reference/save_report_xlsx.md))
as the authoritative processing record.

## Validating the file

The output targets mzTab-M **2.0.0-M**. To confirm conformance, upload
the file to the official HUPO-PSI / LIFS web validator at
<https://apps.lifs-tools.org/mztabvalidator/>, or, if you have the
reference R package [`rmzTabM`](https://lifs-tools.github.io/rmzTabM/)
installed, parse it back:

``` r

# optional, GitHub-only reference implementation
m <- rmzTabM::readMzTab(file.path(out_dir, "experiment.mzTab"))
rmzTabM::extractSmallMoleculeFeatures(m)
```

`mrmhub` itself has **no runtime dependency** on `rmzTabM` — the writer
is self-contained.

## Next Steps

- [Custom QC
  Report](https://slinghub.github.io/MRMhub/quant/articles/recipe-02-custom-qc-report.md)
  — a richer human-readable report.
- [Feature
  Variables](https://slinghub.github.io/MRMhub/quant/articles/manual-03-feature-variables.md)
  — what `conc`, `intensity`, `area` and friends mean.
- [The MRMhubExperiment
  Object](https://slinghub.github.io/MRMhub/quant/articles/manual-04-mrmhub-experiment.md)
  — the slots behind the export.
