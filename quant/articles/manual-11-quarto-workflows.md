# Quarto workflows

Manual

A reproducible MRMhub analysis is recorded as a
[Quarto](https://quarto.org) notebook (`.qmd`): one document that
interleaves the processing code, its console feedback, and the resulting
figures and tables. Rendering it re-runs the whole pipeline from raw
import to final report, so the record and the result never drift apart.
[Introduction to R, Quarto, and
MRMhub](https://slinghub.github.io/MRMhub/quant/articles/tutorial-13-intro-to-r-quarto-mrmhub.md)
covers writing such a document from scratch, and the [Workflow
builder](https://slinghub.github.io/MRMhub/quant/articles/tutorial-12-workflow-builder.md)
emits one automatically.

This page documents the two aspects of rendering that are specific to
MRMhub: preserving its coloured, step-by-step console feedback in the
output, and controlling figure size independently of that feedback.
Because MRMhub reports each processing step on the console — a count and
a truncated list of the features or analyses affected — a rendered
notebook doubles as an **audit trail** of what each step did, and
keeping that feedback intact is the main concern here.

## Session setup

Two session options in the notebook’s setup chunk govern MRMhub’s
rendered feedback. Both belong in a hidden chunk (`#| include: false`)
so they run without appearing in the output:

``` r

library(mrmhub)

# Render mrmhub's coloured console feedback in HTML output (see below):
mrmhub_enable_cli_color()

# Widen or narrow the truncated feature/analysis lists in console messages:
options(mrmhub.max_report_items = 10)
```

[`mrmhub_enable_cli_color()`](https://slinghub.github.io/MRMhub/quant/reference/mrmhub_enable_cli_color.md)
is the only line specific to notebook rendering; the
`mrmhub.max_report_items` option is an ordinary session preference that
also applies interactively.

## Console feedback in the render

In an interactive R session MRMhub’s messages are already coloured:
green for a successful step, yellow for a caution, red for an error. In
a non-interactive render, cli suppresses colour by default, so the same
messages arrive as plain text.
[`mrmhub_enable_cli_color()`](https://slinghub.github.io/MRMhub/quant/reference/mrmhub_enable_cli_color.md)
re-enables it: it advertises colour support to cli, and knitr then
converts the emitted ANSI sequences to coloured HTML using the **fansi**
package (installed automatically as a suggested dependency). MRMhub’s
step feedback travels on the *message* stream, so a chunk that runs a
processing step must keep `#| message: true` (the default) to preserve
it.

Colour applies to **HTML** output only. PDF and Word have no ANSI
concept, so their console blocks render as plain (but still legible)
monospaced text. Severity is never carried by colour alone: success,
caution, and error lines remain distinguishable by their leading symbol
and wording.

**What a message conveys.** A processing message states a **count** and,
where a subset of features or analyses is affected, an **illustrative
list** of them. That list is deliberately truncated
(`options(mrmhub.max_report_items = 10)` sets how many members are shown
before the `…`), so a step touching hundreds of features still prints a
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

An **error** aborts the pipeline before it returns an object, so (unlike
a warning or success) there is no result to filter afterwards. An error
message is therefore self-contained: it names the offending values
inline and, for the metadata validation report, prints the full
error/warning/note table before stopping. The traceback is kept
collapsed but remains reachable with
[`rlang::last_trace()`](https://rlang.r-lib.org/reference/last_error.html).

## Output formats

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
- **PDF** requires a LaTeX installation; the lightweight
  [TinyTeX](https://yihui.org/tinytex/) distribution is sufficient
  ([`tinytex::install_tinytex()`](https://rdrr.io/pkg/tinytex/man/install_tinytex.html)).
  Console blocks render as plain monospaced text.
- **Word** (`.docx`) is convenient for collaborators who annotate in
  Word, but has no styled-console concept: message blocks render as
  plain text and tables are not interactive.

## Figure size: `save_plot()` vs Quarto

Quarto’s `fig-width`, `fig-height`, and `fig-dpi` control the figure
*embedded in the rendered document*.
[`save_plot()`](https://slinghub.github.io/MRMhub/quant/reference/save_plot.md)
controls a *standalone file* at an exact physical size. The two are
independent: a manuscript figure needs the latter, because its width
must match the journal’s column specification regardless of how the
notebook happens to display it.

``` r

save_plot(
  p, "figures/fig3",
  format = c("pdf", "png"), width = 180, height = 200)
```

To render the same notebook against different inputs — one report per
batch or per project — declare its input paths as Quarto *parameters*
rather than string literals; [Custom QC
report](https://slinghub.github.io/MRMhub/quant/articles/recipe-02-custom-qc-report.md)
is the worked example.

## Next steps

- [Introduction to R, Quarto, and
  MRMhub](https://slinghub.github.io/MRMhub/quant/articles/tutorial-13-intro-to-r-quarto-mrmhub.md):
  writing a workflow notebook from scratch
- [Using the workflow
  builder](https://slinghub.github.io/MRMhub/quant/articles/tutorial-12-workflow-builder.md):
  generate a ready-to-render `.qmd` from your data
- [Custom QC
  report](https://slinghub.github.io/MRMhub/quant/articles/recipe-02-custom-qc-report.md):
  render one notebook once per batch or project
- [Troubleshooting &
  FAQ](https://slinghub.github.io/MRMhub/quant/articles/manual-10-troubleshooting.md):
  resolving common rendering problems
