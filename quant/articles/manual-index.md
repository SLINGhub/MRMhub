# Manual

Manual

Every manual page, grouped by stage of a post-processing project.
Step-by-step worked examples are in the
[Tutorials](https://slinghub.github.io/MRMhub/quant/articles/tutorial-02-getting-started-mrmhub.md),
and the full argument reference for every function is in the [function
reference](https://slinghub.github.io/MRMhub/quant/reference/index.md).

## Getting started

- **[Installation](https://slinghub.github.io/MRMhub/quant/articles/manual-00-installation.md)**:
  install `mrmhub` and load it.
- **[MRMhub
  overview](https://slinghub.github.io/MRMhub/quant/articles/manual-01-key-concepts.md)**:
  the data object, how it moves through a workflow, and the core
  function groups.

## Preparing and running

- **[Importing analytical
  data](https://slinghub.github.io/MRMhub/quant/articles/manual-04-data-import.md)**:
  choosing an importer and the file layout each one expects.
- **[Importing
  metadata](https://slinghub.github.io/MRMhub/quant/articles/manual-05-metadata.md)**:
  attaching sample, feature, and internal-standard annotations.
- **[Drift and batch
  correction](https://slinghub.github.io/MRMhub/quant/articles/manual-07-corrections.md)**:
  correcting signal drift within runs and offsets between batches.
- **[Isotopic interference
  correction](https://slinghub.github.io/MRMhub/quant/articles/manual-12-interference-correction.md)**:
  the M+2 overlap concepts, the MRM and MS1 derivation levels, and the
  co-elution requirement.
- **[Quarto
  workflows](https://slinghub.github.io/MRMhub/quant/articles/manual-11-quarto-workflows.md)**:
  recording a pipeline as a `.qmd` notebook, coloured console output,
  and rendering to HTML, PDF, and Word.

## Results and downstream use

- **[Visualisation
  functions](https://slinghub.github.io/MRMhub/quant/articles/manual-08-visualization.md)**:
  RunScatter, PCA, run-sequence, and normalization-QC plots, and
  exporting figures at a defined size and resolution.
- **[Writing pipelines with AI
  assistants](https://slinghub.github.io/MRMhub/quant/articles/manual-09-ai-assistants.md)**:
  grounding LLMs (Claude, ChatGPT, local models) in the real API, and
  verifying what they produce.

## Reference

- **[The MRMhubExperiment data
  object](https://slinghub.github.io/MRMhub/quant/articles/manual-02-data-object.md)**:
  the tables, identifiers, and feature variables of the central object.
- **[Function
  map](https://slinghub.github.io/MRMhub/quant/articles/manual-13-function-map.md)**:
  every function grouped by pipeline stage, linked to its reference.
- **[Glossary](https://slinghub.github.io/MRMhub/quant/articles/manual-14-glossary.md)**:
  definitions of the analytical terms used throughout the documentation.
- **[Design
  decisions](https://slinghub.github.io/MRMhub/quant/articles/manual-03-design-decisions.md)**:
  why the package is built the way it is.
- **[Sample types & QC
  roles](https://slinghub.github.io/MRMhub/quant/articles/manual-06-sample-types.md)**:
  every sample-type (`qc_type`) label and its role in QC.
- **[Troubleshooting &
  FAQ](https://slinghub.github.io/MRMhub/quant/articles/manual-10-troubleshooting.md)**:
  frequent problems and how to resolve them.

## See also

- [Tutorials](https://slinghub.github.io/MRMhub/quant/articles/tutorial-02-getting-started-mrmhub.md):
  worked, end-to-end examples
- [Function
  reference](https://slinghub.github.io/MRMhub/quant/reference/index.md):
  full arguments for every function
- [INTEGRATOR
  documentation](https://slinghub.github.io/MRMhub/integrator/):
  upstream peak integration
