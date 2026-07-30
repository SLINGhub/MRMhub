# Articles

### All vignettes

- [Installation](https://slinghub.github.io/MRMhub/quant/articles/manual-00-installation.md):

  Install mrmhub, verify your setup, and fix common install errors.

- [MRMhub
  overview](https://slinghub.github.io/MRMhub/quant/articles/manual-01-key-concepts.md):

  A technical overview of MRMhub.

- [The MRMhubExperiment data
  object](https://slinghub.github.io/MRMhub/quant/articles/manual-02-data-object.md):

  The primary data container of the MRMhub workflow: its data and
  metadata tables, the identifiers that link them, and the feature
  variables it stores.

- [Design decisions behind MRMhub
  QUANT](https://slinghub.github.io/MRMhub/quant/articles/manual-03-design-decisions.md):

  The main architectural choices behind MRMhub QUANT and the reasoning
  for each – for contributors and users who want to understand or extend
  the package.

- [Importing analytical
  data](https://slinghub.github.io/MRMhub/quant/articles/manual-04-data-import.md):

  Importing analytical data from different sources into an
  MRMhubExperiment.

- [Metadata tables &
  matching](https://slinghub.github.io/MRMhub/quant/articles/manual-05-metadata.md):

  The metadata tables MRMhub uses (analyses, features, ISTDs, response
  curves and QC concentrations), their structure, and how identifiers
  are matched to the data.

- [Sample types & QC
  roles](https://slinghub.github.io/MRMhub/quant/articles/manual-06-sample-types.md):

  Reference for the QC-type labels used in MRMhub and their roles in
  quality control and data processing.

- [Drift and batch
  correction](https://slinghub.github.io/MRMhub/quant/articles/manual-07-corrections.md):

  Run-order drift and batch-effect correction: the available methods,
  their parameters, and when to use each.

- [Visualisation
  functions](https://slinghub.github.io/MRMhub/quant/articles/manual-08-visualization.md):

  Reference for the MRMhub plotting functions, grouped by workflow
  stage, with the canonical argument forms and customisation guidance.

- [Getting help from an AI
  assistant](https://slinghub.github.io/MRMhub/quant/articles/manual-09-ai-assistants.md):

  How to use Claude, ChatGPT, or a local model to plan, draft, and
  troubleshoot MRMhub QUANT workflows without exposing study data.

- [Troubleshooting and
  FAQ](https://slinghub.github.io/MRMhub/quant/articles/manual-10-troubleshooting.md):

  Solutions to the most common errors and questions when using MRMhub
  QUANT.

- [Quarto
  workflows](https://slinghub.github.io/MRMhub/quant/articles/manual-11-quarto-workflows.md):

  Preserving MRMhub’s coloured console feedback and controlling figure
  size when a workflow notebook is rendered.

- [Isotopic interference
  correction](https://slinghub.github.io/MRMhub/quant/articles/manual-12-interference-correction.md):

  Reference for MRMhub’s LICAR-based isotopic interference correction:
  the mrm_pattern labels, the MRM and MS1 derivation levels, and the
  co-elution rule.

- [Function
  map](https://slinghub.github.io/MRMhub/quant/articles/manual-13-function-map.md):

  Every MRMhub function, grouped by pipeline stage and linked to its
  reference.

- [Glossary](https://slinghub.github.io/MRMhub/quant/articles/manual-14-glossary.md):

  Definitions of the analytical terms used throughout the MRMhub
  documentation.

- [Manual](https://slinghub.github.io/MRMhub/quant/articles/manual-index.md):

  Complete contents of the MRMhub-QUANT manual.

- [MRMhub](https://slinghub.github.io/MRMhub/quant/articles/mrmhub.md):

- [Preparing and importing
  data](https://slinghub.github.io/MRMhub/quant/articles/tutorial-01-prep-data.md):

  Import analytical data from the supported platforms and bring in the
  sample and feature metadata that the MRMhub workflow depends on.

- [Getting started with
  MRMhub](https://slinghub.github.io/MRMhub/quant/articles/tutorial-02-getting-started-mrmhub.md):

  Create a MRMhubExperiment, import the bundled demo data, then
  normalize, plot, and export — a first end-to-end MRMhub analysis in a
  Quarto notebook.

- [Lipidomics data
  processing](https://slinghub.github.io/MRMhub/quant/articles/tutorial-03-lipidomics-workflow.md):

  Post-process a targeted lipidomics run from peak areas to a curated,
  quantified dataset: quality assessment, ISTD normalisation, drift and
  batch correction, and QC filtering.

- [Drift and batch
  correction](https://slinghub.github.io/MRMhub/quant/articles/tutorial-04-drift-correction.md):

  Correct run-order signal drift and between-batch effects from QC
  samples, and combine the two in the recommended order.

- [Exploring QC: RunScatter and
  PCA](https://slinghub.github.io/MRMhub/quant/articles/tutorial-05-run-scatter.md):

  Read run-order signal quality with RunScatter and multivariate
  structure with PCA, using the built-in lipidomics dataset.

- [Quantification with external
  calibration](https://slinghub.github.io/MRMhub/quant/articles/tutorial-06-external-calibration.md):

  Fit external calibration curves for a targeted assay, quantify the
  samples, and check the result against QC samples with known
  concentrations.

- [Calibration by a reference
  sample](https://slinghub.github.io/MRMhub/quant/articles/tutorial-07-calibration-reference.md):

  Re-calibrate or normalise concentrations against a reference sample
  (e.g. NIST SRM1950), apply it batch-wise, and check the reference
  bias.

- [Exporting to standard and community
  formats](https://slinghub.github.io/MRMhub/quant/articles/tutorial-08-export-formats.md):

  Move a processed MRMhubExperiment into interchange formats: mzTab-M
  for repositories, or a Bioconductor SummarizedExperiment for
  downstream analysis.

- [Correcting isotopic
  interference](https://slinghub.github.io/MRMhub/quant/articles/tutorial-11-interference-correction.md):

  Annotate the mrm_pattern, derive the M+2 overlaps, inspect them, and
  subtract them — the step-by-step isotopic interference-correction
  workflow.

- [Using the interactive workflow
  builder](https://slinghub.github.io/MRMhub/quant/articles/tutorial-12-workflow-builder.md):

  Use the point-and-click builder to turn a data file into a runnable
  Quarto workflow.

- [Getting started with R and Quarto
  notebooks](https://slinghub.github.io/MRMhub/quant/articles/tutorial-13-getting-started-r-quarto.md):

  Install R and an IDE, create a Quarto project, learn to read and run
  notebook code, and render a report — for readers new to R and Quarto.
