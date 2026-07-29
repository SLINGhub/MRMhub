# Build a workflow without code

Tutorial Beginner Prerequisites: [MRMhub
installed](https://slinghub.github.io/MRMhub/quant/articles/manual-00-installation.md)

[`build_workflow()`](https://slinghub.github.io/MRMhub/quant/reference/build_workflow.md)
opens a point-and-click app that turns a data file and its metadata into
a runnable Quarto (`.qmd`) workflow. You fill in the sidebar, the app
checks your inputs, and it writes the same script you would otherwise
type by hand.

![The MRMhub Workflow Builder: sidebar on the left, live-generated
workflow and validation on the right.](images/workflow-builder.png)

The MRMhub Workflow Builder: sidebar on the left, live-generated
workflow and validation on the right.

## Steps

1.  **Start the app.** Run
    [`build_workflow()`](https://slinghub.github.io/MRMhub/quant/reference/build_workflow.md);
    it opens in your browser. To try it with no files of your own, click
    **Load bundled demo data**.

    ``` r

    library(mrmhub)
    build_workflow()
    ```

2.  **1 · Data source** — pick the tool or format that produced your
    data and upload the file. For a generic CSV, click **Configure
    columns…** to map them.

3.  **2 · Metadata** — choose where sample, feature, and ISTD
    annotations come from (embedded in the data file, an MSOrganiser
    workbook, or separate files).

4.  **3 · Project folder** — optionally **Browse…** to a folder; the app
    copies your data in and writes the report there. Leave it empty to
    just download the `.qmd`.

5.  **4 · Processing steps** — tick the steps to include. A greyed-out
    step tells you what metadata it still needs (e.g. *Quantify by
    internal standard* stays off until an ISTD concentration table is
    imported).

6.  **5 · Output formats** — choose HTML, Word, or PDF for the rendered
    report.

7.  **Check the Validation panel.** A green **✓** means the workflow
    will run; **✗** and **⚠** point to what is missing or out of order.

8.  **Save it.** Click **Download .qmd** (or **Create project & write
    .qmd**), then render:

    ``` bash
    quarto render mrmhub_workflow.qmd
    ```

The result is an ordinary Quarto document. Open it in RStudio, Positron,
or VS Code, tweak paths or steps, and run the chunks yourself — the
builder is a starting point, not a black box.

## Next steps

- [Your first
  analysis](https://slinghub.github.io/MRMhub/quant/articles/tutorial-00-first-analysis.md):
  the same workflow written by hand
- [Basic MRMhub
  workflow](https://slinghub.github.io/MRMhub/quant/articles/tutorial-02-basic-workflow.md):
  the full pipeline the builder mirrors
- [Quarto
  workflows](https://slinghub.github.io/MRMhub/quant/articles/manual-11-quarto-workflows.md):
  rendering to HTML, PDF, and Word
