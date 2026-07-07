# INTEGRATOR vs QUANT: Which Tool Do I Need?

## Overview

MRMhub consists of two complementary modules that handle different
stages of a targeted mass spectrometry workflow. This page documents
**MRMhub-QUANT** (referred to as **QUANT** here), the post-processing
module distributed as the R package `mrmhub`.

|  | INTEGRATOR | QUANT (R package `mrmhub`) |
|----|----|----|
| **What it does** | Peak detection, picking & integration from mzML files | Post-processing: QC, normalization, quantitation, reporting |
| **Language** | Standalone executable | R |
| **Input** | `.mzML` raw data files + `param.txt` + transition list | Long-format `.csv`/`.tsv` + metadata |
| **Output** | Integrated peak areas (long-format `.csv`) | Corrected data, QC reports, publication figures |
| **Requires R?** | No | Yes |
| **Installation** | None (pre-built binary) | R package |

## The Typical MRMhub Pipeline

    Raw Data (.d/.raw)
        │
        ▼  msconvert (vendor → open format)
    mzML files
        │
        ▼  INTEGRATOR (peak integration)
    long.csv (integrated areas)
        │
        ▼  QUANT R package (post-processing)
    Final results, QC reports

## You Might NOT Need INTEGRATOR If…

- The lab already uses **MassHunter**, **Skyline**, or another vendor
  tool for peak integration
- A table of integrated peak areas already exists
- Only the post-processing, QC, and reporting functionality is needed

In these cases, skip directly to QUANT (the `mrmhub` package) and use
the appropriate importer:

``` r

library(mrmhub)
# From MassHunter:
exp <- MRMhubExperiment() |> import_data_masshunter(path = "masshunter_export.csv")
# From Skyline:
exp <- MRMhubExperiment() |> import_data_skyline(path = "skyline_results.csv")
```

## You Might NOT Need QUANT If…

- Only peak integration is needed, with downstream analysis performed in
  another tool (e.g., Excel, Python, or a LIMS)
- INTEGRATOR’s `.csv` output is the final deliverable

## Using Both Together (Recommended)

The full MRMhub pipeline provides end-to-end reproducibility:

1.  Convert vendor raw files with `msconvert`
2.  Run INTEGRATOR for peak integration
3.  Import into QUANT with
    [`import_data_mrmhub()`](https://slinghub.github.io/MRMhub/quant/reference/import_data_mrmhub.md)
4.  Apply corrections, QC, and generate reports

This ensures every step from raw data to final report is documented and
reproducible.

## Why is QUANT an R package?

QUANT is implemented in R rather than Python because the bulk of its
work is statistical and visual: smoothing, robust regression, mixed
modelling, multivariate QC, and ggplot2-driven inspection plots. R
provides established, audit-friendly implementations of these primitives
(loess, cubic splines, prcomp, mixed models, kernel smoothers) and a
large ecosystem of neighbouring tools (`tidyverse`, Bioconductor,
`learnr`, `shiny`) familiar to most academic mass spectrometry and
bioinformatics groups. Literate `.Rmd` / `.qmd` notebooks make the final
analysis self-documenting: the same file produces the figures, the
report, and the audit trail.

The audience is twofold. For lab scientists who write R, QUANT is a
direct tool: every step is an `mexp -> mexp` transform of the
`MRMhubExperiment` container, composable in standard pipelines. For lab
scientists who do not write R, the recommended approach is to
collaborate with a bioinformatician or core-facility analyst; the
package is designed so that processing scripts can be authored once and
re-run unchanged across cohorts, with QC outputs that are readable
without R knowledge. The 5-minute [Your First
Analysis](https://slinghub.github.io/MRMhub/quant/articles/tutorial-00-first-analysis.md)
walkthrough is a useful gauge of the R learning curve involved.

## Next Steps

- [INTEGRATOR Manual ↗](https://slinghub.github.io/MRMhub/integrator/)
  (separate site)
- [Import and prepare data
  files](https://slinghub.github.io/MRMhub/quant/articles/manual-05a-which-importer.md)
- [Your First
  Analysis](https://slinghub.github.io/MRMhub/quant/articles/tutorial-00-first-analysis.md)
