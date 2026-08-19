# Getting help from an AI assistant

Manual

An AI assistant (Claude, ChatGPT, or a locally hosted model) can help
you plan an analysis, draft R code, fix errors, and explain a step in
MRMhub QUANT, whether or not you write much R. It cannot run your data
or confirm the numbers; that stays with you.

## Use it in three steps

1.  **Give it the package reference first.** An assistant has read
    little about a recently published, specialised package, so from
    memory it invents function names that sound right but do not exist.
    MRMhub publishes its whole interface as one file:
    <https://slinghub.github.io/MRMhub/quant/llms.txt>. Give the
    assistant that **link** and tell it to **use only functions that
    appear there**, or paste the file’s contents if it cannot browse the
    web. For regular use, add the file once to a Claude Project or a
    ChatGPT custom GPT. Ask it to keep the **`mexp <- f(mexp, ...)` step
    pattern** in the recommended pipeline order, and to use **current
    terminology** in prose (interference source/target, precursor and
    product ions, not parent/daughter) and the plain name MRMhub.
2.  **Ask for what you need**, adapting one of the prompts below.
3.  **Run it and check the numbers yourself.** Run generated code on
    data you understand first, the bundled demo
    (`system.file("extdata", "MRMhub_demo.tsv", package = "mrmhub")`) is
    ideal; confirm every function it used appears in the [function
    reference](https://slinghub.github.io/MRMhub/quant/reference/index.md);
    and cross-check the results against QC plots and metrics, not just
    that the script ran.

## Prompts to copy

Ground the assistant (step 1), then adapt one of these.

**Explain a step**

``` text
In one short paragraph, explain what correct_drift_loess() does and why drift
and batch corrections in mrmhub are fitted on QC samples, not study samples.
```

**Draft a workflow script**

``` text
Write an R script using mrmhub that imports my data, normalises by internal
standard, corrects signal drift, quantifies against calibration curves,
computes QC metrics, filters failing features, and writes an Excel report.
Keep the mexp <- f(mexp, ...) pattern for every step, in recommended order.
```

**Explain and fix an error** (paste the line and the exact message)

``` text
Running: mexp <- normalize_by_istd(mexp)
I get: <paste the exact error message>
What does it mean, and how do I fix it?
```

**Plan the analysis**

``` text
My samples are plasma extracts with stable-isotope-labelled internal standards
and a 7-point external calibration curve. Which mrmhub steps apply, in what
order, and where do QC samples come in?
```

Prefer not to write R at all?
[`build_workflow()`](https://slinghub.github.io/MRMhub/quant/reference/build_workflow.md)
generates a correct, runnable Quarto workflow from your data and
metadata; handing that to an assistant to explain or adjust is safer
than asking it to write a pipeline from scratch (see [Build a workflow
without
code](https://slinghub.github.io/MRMhub/quant/articles/tutorial-12-workflow-builder.md)).

## Limits and risks

An assistant produces plausible code that can be wrong. It cannot run
your data, cannot guarantee the code is correct, and does not know
MRMhub’s functions reliably unless you show it the reference (step 1).
Treat its output as a first draft to verify, never as a result.

Do not paste study data into a cloud assistant. Sample intensities,
subject metadata, and unpublished results sent to a hosted service
(Claude, ChatGPT) leave your control and may be retained. Share only
code and the [function
map](https://slinghub.github.io/MRMhub/quant/articles/manual-13-function-map.md),
`llms.txt`, and reference pages, never the measurements. If the data
must stay on the machine, use a locally hosted model (through Ollama or
LM Studio), which keeps everything on-device but depends even more on
being shown the reference.

## Next steps

- [Design
  decisions](https://slinghub.github.io/MRMhub/quant/articles/manual-03-design-decisions.md):
  the conventions an assistant must respect, the `mexp -> mexp` pattern
  and the pipeline order
- [Key concepts and
  glossary](https://slinghub.github.io/MRMhub/quant/articles/manual-01-key-concepts.md):
  the data model and terms to share with the assistant
- [Getting started with
  MRMhub](https://slinghub.github.io/MRMhub/quant/articles/tutorial-02-getting-started-mrmhub.md):
  a hand-run baseline to compare generated code against
