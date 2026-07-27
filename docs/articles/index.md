# Articles

### All vignettes

- [Installation](https://slinghub.github.io/MRMhub/quant/articles/manual-00-installation.md):

  Install mrmhub, verify your setup, and fix common install errors.

- [Key concepts &
  glossary](https://slinghub.github.io/MRMhub/quant/articles/manual-01-key-concepts.md):

  Core vocabulary of MRMhub: the data model, terminology, and the
  function-naming convention.

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

- [Writing pipelines with AI
  assistants](https://slinghub.github.io/MRMhub/quant/articles/manual-09-ai-assistants.md):

  How to use large language models (Claude, ChatGPT, or local models) to
  help write MRMhub QUANT pipelines – how to ground them in the real
  API, and how to verify what they produce.

- [Troubleshooting and
  FAQ](https://slinghub.github.io/MRMhub/quant/articles/manual-10-troubleshooting.md):

  Solutions to the most common errors and questions when using MRMhub
  QUANT.

- [Quarto
  workflows](https://slinghub.github.io/MRMhub/quant/articles/manual-11-quarto-workflows.md):

  MRMhub: postprocessing and quality control of small molecule mass
  spectrometry data

- [Isotopic interference
  correction](https://slinghub.github.io/MRMhub/quant/articles/manual-12-interference-correction.md):

  Reference for MRMhub’s isotopic interference correction: the
  fragment-based (MRM) and whole-molecule (MS1) derivation levels, the
  co-elution requirement, and the provenance of the derived contribution
  factors.

- [Customising
  plots](https://slinghub.github.io/MRMhub/quant/articles/manual-13-plot-customization.md):

  How the shared appearance arguments of the MRMhub plotting functions
  control text size, legend placement, and automatic sizing, so a
  balanced figure needs little or no manual ggplot2 theming.

- [Manual](https://slinghub.github.io/MRMhub/quant/articles/manual-index.md):

  Complete contents of the MRMhub-QUANT manual.

- [MRMhub](https://slinghub.github.io/MRMhub/quant/articles/mrmhub.md):

- [Quantitative assay with external calibration and
  QC](https://slinghub.github.io/MRMhub/quant/articles/recipe-01-ext-calibration-qc.md):

  Quantify a targeted assay from external calibration curves and check
  the result against calibrator and QC samples.

- [Custom QC
  report](https://slinghub.github.io/MRMhub/quant/articles/recipe-02-custom-qc-report.md):

  Create a detailed HTML QC report from a processed MRMhubExperiment
  using a parameterized Quarto template.

- [Import and export
  mzTab-M](https://slinghub.github.io/MRMhub/quant/articles/recipe-03-mztab-export.md):

  Exchange data with the HUPO-PSI mzTab-M standard format: export a
  processed MRMhubExperiment for sharing or MetaboLights submission, and
  import results from tools such as Lipid Data Analyzer, MS-DIAL or
  MZmine.

- [Validating and fixing
  metadata](https://slinghub.github.io/MRMhub/quant/articles/recipe-04-validate-metadata.md):

  Validate analysis, feature, and ISTD annotations against imported
  data, diagnose the common defects, and generate a metadata template.

- [Import metadata from files or a
  template](https://slinghub.github.io/MRMhub/quant/articles/recipe-05-import-metadata.md):

  Attach sample, feature, ISTD and QC metadata to an MRMhubExperiment,
  file by file, from Excel sheets, from a data.frame, or in one step
  from an MSOrganiser template.

- [Your first
  analysis](https://slinghub.github.io/MRMhub/quant/articles/tutorial-00-first-analysis.md):

  A short walkthrough on the bundled demo data: import a result file,
  normalize by internal standard, inspect the run, and export: no
  external files needed.

- [Preparing and importing
  data](https://slinghub.github.io/MRMhub/quant/articles/tutorial-01-prep-data.md):

  Import analytical data from the supported platforms and bring in the
  sample and feature metadata that the MRMhub workflow depends on.

- [A basic MRMhub
  workflow](https://slinghub.github.io/MRMhub/quant/articles/tutorial-02-basic-workflow.md):

  A realistic end-to-end workflow, from project setup through drift and
  batch correction, QC filtering, and export.

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

- [Calibration by a reference
  sample](https://slinghub.github.io/MRMhub/quant/articles/tutorial-07-calibration-reference.md):

  Re-calibrate or normalise concentrations against a reference sample
  (e.g. NIST SRM1950), apply it batch-wise, and check the reference
  bias.

- [Export to Bioconductor
  (SummarizedExperiment)](https://slinghub.github.io/MRMhub/quant/articles/tutorial-08-summarizedexperiment.md):

  Export a processed MRMhubExperiment as a Bioconductor
  SummarizedExperiment, and take it downstream: differential abundance
  with limma, or lipid-specific analysis with lipidr.

- [Interference
  correction](https://slinghub.github.io/MRMhub/quant/articles/tutorial-11-interference-correction.md):

  Derive and subtract isotopic (M+2) interferences in class-based
  targeted assays: annotate mrm_pattern, auto-derive the overlaps,
  inspect, and correct.

- [Build a workflow without
  code](https://slinghub.github.io/MRMhub/quant/articles/tutorial-12-workflow-builder.md):

  Use the point-and-click builder to validate your data and metadata and
  generate a runnable Quarto workflow.
