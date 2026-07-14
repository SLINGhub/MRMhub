# Writing Pipelines with AI Assistants

Manual

## Audience

This article is for analysts who want to use a large language model
(LLM) – Claude, ChatGPT, or a locally hosted model – as an assistant
when writing MRMhub QUANT analysis code in R. It explains how to give
the model an accurate picture of the package, and how to check the code
it returns.

It assumes familiarity with the basic workflow. To process data
directly, start with [Your First
Analysis](https://slinghub.github.io/MRMhub/quant/articles/tutorial-00-first-analysis.md).

## The problem: a specialised package the model has not memorised

General-purpose LLMs are trained on large volumes of common R code, but
`mrmhub` is a specialised, comparatively young package. A model asked to
“write an MRMhub pipeline” from memory alone tends to fail in two
characteristic ways:

- **Invented function names.** The model produces plausible-sounding
  calls that do not exist – `normalize()` in place of
  [`normalize_by_istd()`](https://slinghub.github.io/MRMhub/quant/reference/normalize_by_istd.md),
  or a single `run_pipeline()` that was never written. The names look
  right and the code will not run.
- **Ignored conventions.** MRMhub has a load-bearing design: every
  processing function takes an `MRMhubExperiment` and returns a modified
  one (`mexp -> mexp`), and the steps follow a recommended order. A
  model unaware of this may pass bare data frames, reorder steps, or fit
  drift corrections on study samples rather than QC samples.

Both problems have the same cause – the model is guessing rather than
reading – and the same remedy: give it the package’s own reference
material as context.

## What MRMhub provides for an LLM

The pkgdown documentation site publishes, alongside the human-facing
HTML, a set of machine-readable files intended for exactly this purpose.
They are generated automatically on every site build and require no
setup:

- **An `llms.txt` index** –
  <https://slinghub.github.io/MRMhub/quant/llms.txt>. This follows the
  [llms.txt](https://llmstxt.org/) convention: a single Markdown file
  with a short package overview followed by grouped links to every
  exported function and every article. It is a compact map of the entire
  API in one file.
- **A Markdown mirror of every page.** Each reference and article page
  is also published as plain Markdown – for example
  <https://slinghub.github.io/MRMhub/quant/reference/normalize_by_istd.md>.
  These carry the full argument list and description without the
  navigation, styling, and inline SVG of the rendered HTML, which a
  model would otherwise have to parse and partly discard.

Feeding these to the model turns it from guessing to reading: it can see
which functions exist and what arguments they take.

## Three ways to provide the context

### 1. Paste it in (any assistant, no setup)

The most portable approach works with any chat interface. Open the
`llms.txt` URL, copy its contents, and paste it into the conversation
with an instruction to use only what it contains. When the exact
arguments of a function matter, follow the link to that function’s `.md`
page and paste that too.

A prompt template:

``` text
I am writing an analysis in R using the package `mrmhub`. Below is the
package's API index. Use ONLY functions that appear in it -- if you are
unsure a function exists, say so rather than inventing one.

<paste the contents of https://slinghub.github.io/MRMhub/quant/llms.txt>

Task: write a script that imports MassHunter data, normalises by internal
standard, corrects for signal drift, quantifies against a calibration curve,
computes QC metrics, filters features, and writes an Excel report. Keep the
`mexp <- f(mexp, ...)` pattern for every step.
```

### 2. Let the assistant fetch it (browsing-capable models)

Assistants that can retrieve web pages – Claude with web access, ChatGPT
with browsing, Perplexity, and similar – need only the URL. Give them
the `llms.txt` address and ask them to read it and follow the links to
individual reference pages as needed. This avoids copy-and-paste and
lets the model pull the exact page for each function it uses.

### 3. Agentic and local tools

Coding assistants that operate on a project – Claude Code, Cursor,
Continue, and comparable tools, including those backed by a local model
through Ollama – can take `llms.txt` and the `.md` reference pages as a
knowledge source, so the generated code is grounded in the real API as
it is written.

Local models deserve a note of caution: a smaller model running on a
workstation has memorised even less of a niche package than a large
hosted one, so it is *more* dependent on being given this context, not
less. Provide the reference material explicitly and keep the requested
task narrow.

### What about just the GitHub link?

A natural shortcut is to give the assistant the repository URL
(<https://github.com/SLINGhub/MRMhub>) instead. Whether this works
depends on the tool. A repository-aware or agentic tool (option 3) reads
the actual source, roxygen documentation included, so the repository –
or a local clone – is an excellent starting point. A browsing chat
assistant (option 2), by contrast, typically fetches only the rendered
README and the top-level file listing in a single request; it does not
read every source file, so it sees a handful of functions rather than
the full API, and the repository also mixes in the INTEGRATOR sources
and the documentation sites. For that reason `llms.txt` remains the
better single entry point for chat assistants – one request yields the
complete, curated API map. Supplying both the `llms.txt` URL and the
repository link covers either kind of tool.

## A worked example

Grounded in the API index, a model should produce a script that uses
real function names and respects the pipeline order. The result for the
task above looks like the following – which is also a useful template to
write by hand:

``` r

library(mrmhub)

# Import analytical data and its embedded metadata
mexp <- MRMhubExperiment(title = "Example assay")
mexp <- import_data_masshunter(mexp, path = "data.csv", import_metadata = TRUE)

# Normalise each feature by its internal standard
mexp <- normalize_by_istd(mexp)

# Correct within-run signal drift (fitted on QC samples only)
mexp <- correct_drift_loess(mexp, variable = "norm_intensity")

# Quantify against calibration curves
mexp <- quantify_by_calibration(mexp)

# Compute QC metrics, then filter features that fail them
mexp <- calc_qc_metrics(mexp)
mexp <- filter_features_qc(mexp)

# Write the multi-sheet Excel report
save_report_xlsx(mexp, path = "results.xlsx")
```

Every call here follows the `mexp -> mexp` pattern, and the order
matches the recommended pipeline. That is what the context makes
possible; it is not guaranteed. The next section is how to confirm it.

## Do not trust – verify

Grounding reduces errors but does not eliminate them. Treat generated
code as a draft to be checked, never as an answer to be trusted.

**Verify every AI-generated pipeline before relying on its results.**

- **Run it on data you understand** – the bundled demo dataset is ideal
  (`system.file("extdata", "MRMhub_demo.tsv", package = "mrmhub")`).
  Read the errors; a hallucinated function surfaces immediately as
  “could not find function”.
- **Cross-check every function name** against the [function
  reference](https://slinghub.github.io/MRMhub/quant/reference/index.md).
  If a call is not listed there, it does not exist – regardless of how
  convincing it looks.
- **Confirm the step order** matches the recommended pipeline and that
  drift and batch corrections are fitted on QC samples, not study
  samples. See [Design
  Decisions](https://slinghub.github.io/MRMhub/quant/articles/manual-03-design-decisions.md)
  for why the order and the QC-only rule matter.
- **Inspect the numbers**, not just that the script runs without error.
  A pipeline can complete and still be wrong – the wrong normalisation,
  the wrong calibration model. Sanity-check against QC plots and
  metrics.

[`build_workflow()`](https://slinghub.github.io/MRMhub/quant/reference/build_workflow.md)
offers a complementary starting point: it launches an interactive
application that validates your data and metadata, warns about pipeline
mismatches, and generates a correct, runnable Quarto (`.qmd`) workflow.
Handing that generated script to an assistant as a base – rather than
asking it to write one from nothing – gives the model a scaffold that is
already valid.

## Data privacy

**Do not paste study data into a cloud LLM.** Sample intensities,
subject metadata, and unpublished results sent to a hosted assistant
leave your control and may be retained or used by the provider. Share
*code and the API map* – `llms.txt`, reference pages, and function calls
– not the measurements themselves. When the data cannot leave the
machine, use a locally hosted model, which keeps everything on-device.

## Next Steps

- [Design
  Decisions](https://slinghub.github.io/MRMhub/quant/articles/manual-03-design-decisions.md)
  — the conventions an assistant must respect: the `mexp -> mexp`
  pattern and the pipeline order
- [Key Concepts &
  Glossary](https://slinghub.github.io/MRMhub/quant/articles/manual-01-key-concepts.md)
  — the data model and terminology to give the model (and yourself) a
  shared vocabulary
- [Your First
  Analysis](https://slinghub.github.io/MRMhub/quant/articles/tutorial-00-first-analysis.md)
  — a hand-written baseline pipeline to compare generated code against
