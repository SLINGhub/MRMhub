# Quarto Workflows

Manual

A reproducible MRMhub analysis is best recorded as a
[Quarto](https://quarto.org) notebook (`.qmd`): a single document that
interleaves the processing code, its console feedback, and the resulting
figures and tables. Rendering the document re-runs the whole pipeline
from the raw import to the final report, so the record and the result
never drift apart. The [Workflow
Builder](https://slinghub.github.io/MRMhub/quant/articles/tutorial-12-workflow-builder.md)
emits exactly such a document; this page documents the conventions it
follows and how to render them to HTML, PDF, and Word.

Because MRMhub reports each processing step on the console —
line-by-line, in colour, with a truncated list of the features or
analyses affected — a rendered notebook doubles as an audit trail of
what each step did. Preserving that feedback in the rendered output is
the main subject of this page.

## Project layout

A workflow document reads its inputs and writes its report by *relative*
path, so the notebook, its data, and its output live together in one
project folder. The [Basic MRMhub
Workflow](https://slinghub.github.io/MRMhub/quant/articles/tutorial-02-basic-workflow.md)
sketches the recommended three-folder layout (`data/`, the notebook,
`output/`); rendering from the project root then resolves every path
without absolute references, and the folder can be archived or shared as
a self-contained unit.

## The global setup chunk

Every workflow opens with a hidden setup chunk that loads the package
and fixes a few session options. Marking it `#| include: false` keeps it
out of the rendered output while still executing it:

```` default
```{r}
#| label: setup
#| include: false
library(mrmhub)

# Render mrmhub's coloured console feedback in HTML output (see below):
mrmhub_enable_cli_color()

# Widen or narrow the truncated feature/analysis lists in console messages:
options(mrmhub.max_report_items = 10)

# Reproducibility and tidy console printing:
set.seed(1041)
options(dplyr.print_max = 10)
```
````

[`mrmhub_enable_cli_color()`](https://slinghub.github.io/MRMhub/quant/reference/mrmhub_enable_cli_color.md)
is the only line specific to notebook rendering; the others are ordinary
session preferences. Its effect is explained in [CLI output in
colour](#cli-output-in-colour-nicely-formatted) below.

## Cell options

Quarto cell options are written as specially-formatted comments at the
top of a chunk, each prefixed with `#|`. The options below cover the
needs of a processing notebook; the [Quarto
documentation](https://quarto.org/docs/computations/execution-options.html)
is the complete reference.

MRMhub’s step feedback travels on the *message* stream, so a chunk that
runs a processing step should keep `#| message: true` (the default) to
preserve it. A document-wide default can be set in the YAML front
matter:

``` yaml
execute:
  warning: true
  message: true
```

**Long-running steps.** For a step that is slow to compute but whose
console summary is the point (a large drift correction, for example),
suppress the verbose progress but keep the summary. Several plotting and
correction functions accept `show_progress = FALSE` for exactly this;
combining it with `#| cache: true` avoids re-running the step on every
render while the surrounding prose is edited.

## CLI output in colour, nicely formatted

In an interactive R session MRMhub’s messages are already coloured —
green for a successful step, yellow for a caution, red for an error. In
a non-interactive render, cli suppresses colour by default, so the same
messages would arrive as plain text.
[`mrmhub_enable_cli_color()`](https://slinghub.github.io/MRMhub/quant/reference/mrmhub_enable_cli_color.md)
re-enables it: it advertises colour support to cli, and knitr then
converts the emitted ANSI sequences to coloured HTML using the **fansi**
package (installed automatically as a suggested dependency).

Colour applies to **HTML** output only. PDF and Word have no ANSI
concept, so their console blocks render as plain — but still fully
legible — monospaced text. The severity is never carried by colour
alone: success, caution, and error lines remain distinguishable by their
leading symbol and wording.

**What a message conveys.** A processing message states a **count** and,
where a subset of features or analyses is affected, an **illustrative
list** of them. That list is deliberately truncated —
`options(mrmhub.max_report_items = 10)` sets how many members are shown
before the `…` — so a step touching hundreds of features still prints a
single tidy line rather than a wall of identifiers.

**Recovering the full list.** Because the list is truncated for display,
the message names the column in the returned object that carries the
*complete* membership. The truncated names are a preview; the column is
the record. To export the full set, filter the object on that column and
write it out:

``` r

# A message reporting features flagged out of calibration range names the
# `feature_conc_out_of_range` column; recover the complete set from the object:
mexp@metrics_qc |>
  dplyr::filter(feature_conc_out_of_range) |>
  dplyr::pull(feature_id) |>
  readr::write_lines("output/features_out_of_range.txt")
```

Raise `options(mrmhub.max_report_items = 50)` (or pass
`max_report_items` to a function that reports lists) to widen the
preview in every message at once.

An **error** aborts the pipeline before it returns an object, so —
unlike a warning or success — there is no result to filter afterwards.
An error message is therefore self-contained: it names the offending
values inline and, for the metadata validation report, prints the full
error/warning/note table before stopping. The traceback is kept
collapsed but remains reachable with
[`rlang::last_trace()`](https://rlang.r-lib.org/reference/last_error.html).

## Output formats — HTML, PDF, and Word

The output format is declared in the YAML front matter; several may be
combined, and each is produced by rendering the document once:

``` yaml
format:
  html: default
  pdf:
    include-in-header:
      text: |
        \renewcommand{\familydefault}{\sfdefault}
  docx: default
```

- **HTML** is the recommended working format: it preserves the coloured
  console feedback, keeps interactive tables scrollable, and needs no
  external tooling.
- **PDF** requires a LaTeX installation. The lightweight
  [TinyTeX](https://yihui.org/tinytex/) distribution is sufficient —
  install it once with
  [`tinytex::install_tinytex()`](https://rdrr.io/pkg/tinytex/man/install_tinytex.html).
  The `include-in-header` snippet above switches the LaTeX body font to
  sans-serif using the default `pdflatex` engine, matching the look the
  Workflow Builder emits without requiring a font install.
- **Word** (`.docx`) is convenient for collaborators who annotate in
  Word, but it has no styled-console concept: message blocks render as
  plain monospaced text, and there is no live table interactivity.

Rendering is performed with Quarto once the document is saved:

``` bash
quarto render mrmhub_workflow.qmd
```

## Parameters

A workflow document hard-codes its input paths, so processing a second
batch means editing the file. Declaring those values as Quarto
*parameters* instead lets the same notebook render unchanged against
different inputs — one report per batch or per project. Parameters are
listed in the YAML front matter with their defaults:

``` yaml
params:
  data_path: "data/batch01/"
```

The setup chunk then reads from `params` rather than a string literal:

``` r

mexp <- import_data_mrmhub(params$data_path)
```

Rendering with no override reproduces the default report; a different
batch is produced by overriding the parameter on the command line,

``` bash
quarto render mrmhub_workflow.qmd -P data_path:data/batch02/
```

or from R, where the output file can also be named per run:

``` r

quarto::quarto_render(
  "mrmhub_workflow.qmd",
  execute_params = list(data_path = "data/batch02/"),
  output_file = "batch02.html"
)
```

For a fuller worked example — a standalone report template rendered from
a saved results object — see [Custom QC
Report](https://slinghub.github.io/MRMhub/quant/articles/recipe-02-custom-qc-report.md).

## Slides

The same processing document can be presented as slides by adding the
`revealjs` format, without duplicating the analysis code:

``` yaml
format:
  revealjs:
    echo: true
```

Each `##` heading becomes a slide. Setting `echo: true` shows the code
alongside its result, which suits a methods walk-through; `echo: false`
shows only the figures and tables, which suits a results presentation.
The processing chunks are unchanged from the HTML document — only the
format block differs.

Coloured console feedback renders reliably in an **HTML document**; on
`revealjs` slides the console output is best kept brief or shown as the
emitted tables and values, as slide rendering does not always preserve
the coloured message blocks.

## Next Steps

- [Using the Workflow
  Builder](https://slinghub.github.io/MRMhub/quant/articles/tutorial-12-workflow-builder.md)
  — generate a ready-to-render `.qmd` from your data and metadata files
- [Basic MRMhub
  Workflow](https://slinghub.github.io/MRMhub/quant/articles/tutorial-02-basic-workflow.md)
  — the pipeline a workflow document records, written by hand
- [Custom QC
  Report](https://slinghub.github.io/MRMhub/quant/articles/recipe-02-custom-qc-report.md)
  — render one notebook once per batch or project
- [Troubleshooting &
  FAQ](https://slinghub.github.io/MRMhub/quant/articles/manual-10-troubleshooting.md)
  — resolving common rendering and processing problems
