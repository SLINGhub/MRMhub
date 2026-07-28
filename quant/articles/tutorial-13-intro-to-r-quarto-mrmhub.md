# Introduction to R, Quarto, and MRMhub

Tutorial Beginner

A MRMhub analysis is written as a document that mixes prose with the R
code that produces the results, so the report and the analysis are one
file. This tutorial assumes no prior experience with R or Quarto. It
starts from an empty computer, installs the software, sets up a project,
and then runs a complete analysis of the bundled demonstration data —
importing, normalizing, plotting, and exporting — using MRMhub functions
alone, without any custom R code. After working through it you can open
a fresh Quarto document and reproduce the same workflow on your own
data.

## 1. Install R and an editor

Two pieces of software are needed. **R** is the language the analysis
runs in; an **integrated development environment** (IDE) is the editor
you write and run it in.

- Install R from [CRAN](https://cran.r-project.org/) (version 4.1 or
  newer). Pick the download for your operating system and accept the
  defaults.
- Install an IDE. [RStudio](https://posit.co/download/rstudio-desktop/)
  is the most common choice and the one this tutorial follows. If you
  already work in VS Code, [Positron](https://positron.posit.co/) is an
  RStudio-like alternative built on the same editor.

With R and RStudio installed, open RStudio and install MRMhub from the
console (the bottom-left pane). The first line installs `pak`, a package
installer; the second uses it to fetch MRMhub and its dependencies:

``` r

if (!require("pak")) install.packages("pak")
pak::pak("SLINGhub/MRMhub")
```

If the installation reports an error, the [Installation
guide](https://slinghub.github.io/MRMhub/quant/articles/manual-00-installation.md)
lists the common causes (a missing compiler on Windows or macOS, a
firewall blocking the download) and their fixes.

## 2. Create a Quarto project

A **project** keeps everything for one analysis — data, code, and
results — in a single folder that the IDE treats as a unit. In RStudio,
choose *File → New Project → New Directory → Quarto Project*, give it a
name, and create it. Quarto’s [project
documentation](https://quarto.org/docs/tools/rstudio/) covers the dialog
in detail.

Inside the new project, add two folders to keep raw inputs separate from
generated results — the convention MRMhub’s own workflows follow:

    my_study/
    ├── data/            # raw INTEGRATOR output and metadata files
    ├── output/          # exported CSVs, PDFs, and reports
    └── analysis.qmd     # this document

A Quarto document (`.qmd`) is the home for the workflow: it interleaves
explanatory text with code, documenting each decision alongside the
result it produces.

## 3. Add text and code

A `.qmd` file is plain text with two kinds of content. **Prose** is
written in Markdown — plain paragraphs, with `#` for headings,
`**bold**`, and `-` for lists. **Code** lives in *chunks*: R code fenced
between ```` ```{r} ```` and ```` ``` ````. In RStudio, *Insert → Code
Chunk* (or Ctrl/Cmd + Alt + I) adds an empty one.

```` markdown
Some explanatory text describing the next step.


``` r
1 + 1
[1] 2
```
````

RStudio offers two ways to edit a `.qmd`: the **Source** editor shows
the raw Markdown, while the **Visual** editor (the *Visual* toggle,
top-left of the document) shows a formatted, word-processor-like view.
Both edit the same file. Quarto’s [authoring
guide](https://quarto.org/docs/get-started/hello/rstudio.html)
introduces both.

## 4. Preview and run code

There are two distinct actions. **Running a chunk** executes its code
immediately and shows the result inline: click the green ▶ arrow at the
chunk’s top-right, or press Ctrl/Cmd + Shift + Enter with the cursor
inside it. **Rendering** turns the whole document into a finished HTML
(or PDF) report: click **Render**, and RStudio runs every chunk in order
and assembles the output. The **Preview** that opens updates each time
you render, so the report stays in step with the code.

While developing an analysis, run chunks one at a time to check each
step; render at the end to produce the shareable report.

## 5. The setup chunk

The first chunk of an analysis loads the packages and sets defaults that
apply throughout. Loading MRMhub makes its functions available;
[`mrmhub_enable_cli_color()`](https://slinghub.github.io/MRMhub/quant/reference/mrmhub_enable_cli_color.md)
colours the console messages in the rendered report; and
[`mrmhub_set_plot_defaults()`](https://slinghub.github.io/MRMhub/quant/reference/mrmhub_set_plot_defaults.md)
sets a house font size and resolution for every figure, so individual
plots need not repeat them.

``` r

library(mrmhub)
mrmhub_enable_cli_color()
mrmhub_set_plot_defaults(font_base_size = 8)
```

Figure dimensions are controlled by Quarto itself, through the
document’s `fig-width` and `fig-height` options; [Quarto
workflows](https://slinghub.github.io/MRMhub/quant/articles/manual-11-quarto-workflows.md)
explains how those interact with MRMhub’s plot sizing.

## 6. Load the data

Every analysis begins with a `MRMhubExperiment` — the container that
holds the data and every result computed from it (see [The
MRMhubExperiment
object](https://slinghub.github.io/MRMhub/quant/articles/manual-02-data-object.md)).
We create an empty one and import the demonstration dataset bundled with
the package. Using
[`system.file()`](https://rdrr.io/r/base/system.file.html) locates that
file wherever the package is installed, so the code runs unchanged on
any machine; in your own project you would instead give the path to a
file in `data/`.

``` r

demo_file <- system.file("extdata", "MRMhub_demo.tsv", package = "mrmhub")

mexp <- MRMhubExperiment()
mexp <- import_data_mrmhub(
  mexp,
  path = demo_file,
  import_metadata = TRUE)
```

    ✔ Imported 499 analyses with 28 features.

    ℹ feature_area selected as default feature intensity. Modify with `set_intensity_var()`.

    ✔ Analysis metadata associated with 499 analyses.

    ✔ Feature metadata associated with 28 features.

Setting `import_metadata = TRUE` reads the sample and internal-standard
annotations embedded in the INTEGRATOR file at the same time. MRMhub
reads several other formats; [Importing analytical
data](https://slinghub.github.io/MRMhub/quant/articles/manual-04-data-import.md)
has a decision flowchart and the full importer reference.

## 7. Process the data

The core processing step normalizes each feature to its assigned
internal standard, which corrects for extraction and injection
variation. The result is stored in the `feature_norm_intensity`
variable, leaving the raw intensities untouched.

``` r

mexp <- normalize_by_istd(mexp)
```

    ✔ 19 features normalized with 9 ISTDs in 499 analyses.

This is the shortest useful pipeline. A real study usually adds drift
and batch correction and QC filtering in a set order; [A basic MRMhub
workflow](https://slinghub.github.io/MRMhub/quant/articles/tutorial-02-basic-workflow.md)
and [Drift and batch
correction](https://slinghub.github.io/MRMhub/quant/articles/tutorial-04-drift-correction.md)
build on the object from here.

## 8. Plot signals across the run

A run-scatter plot shows each feature’s signal against injection order —
a quick check for trends or outliers. We plot the normalized intensities
for two lipid classes, selected by a regular expression on their names.

``` r

plot_runscatter(
  mexp,
  variable = "norm_intensity",
  include_feature_filter = "^(Cer|PC)",
  rows_page = 2, cols_page = 3)
```

![Run-scatter of normalized intensities for Cer and PC features by
injection
order](tutorial-13-intro-to-r-quarto-mrmhub_files/figure-html/runscatter-1.png)

Figure 1. Normalized intensities of Cer and PC features across injection
order.

![Run-scatter of normalized intensities for Cer and PC features by
injection
order](tutorial-13-intro-to-r-quarto-mrmhub_files/figure-html/runscatter-2.png)

Figure 1. Normalized intensities of Cer and PC features across injection
order.

To save the plot to a file instead of showing it,
[`plot_runscatter()`](https://slinghub.github.io/MRMhub/quant/reference/plot_runscatter.md)
can write a multi-page PDF — one page per grid of features — directly to
`output/`:

``` r

plot_runscatter(
  mexp,
  variable = "norm_intensity",
  include_feature_filter = "^(Cer|PC)",
  rows_page = 2, cols_page = 3,
  output_pdf = TRUE,
  path = "output/runscatter.pdf")
```

## 9. Run a PCA, inline and as a PDF

A principal-component analysis (PCA) summarises all features at once,
placing each sample in a plane so that similar samples fall close
together — useful for spotting QC clustering or outliers.

``` r

plot_pca(mexp, variable = "norm_intensity")
```

![PCA score plot of samples coloured by QC
type](tutorial-13-intro-to-r-quarto-mrmhub_files/figure-html/pca-1.png)

Figure 2. PCA of the normalized intensities, coloured by QC type.

To keep a copy of the figure, pipe it into
[`save_plot()`](https://slinghub.github.io/MRMhub/quant/reference/save_plot.md).
Because
[`save_plot()`](https://slinghub.github.io/MRMhub/quant/reference/save_plot.md)
returns the plot visibly, one line both writes the PDF and still renders
the figure in the report; `width` and `height` are in millimetres:

``` r

plot_pca(mexp, variable = "norm_intensity") |>
  save_plot("output/pca.pdf", width = 180, height = 120)
```

Giving
[`save_plot()`](https://slinghub.github.io/MRMhub/quant/reference/save_plot.md)
a path with no extension and `format = c("pdf", "png")` writes both
formats at once; [Visualisation
functions](https://slinghub.github.io/MRMhub/quant/articles/manual-08-visualization.md)
lists the plots available at each stage.

## 10. Export results

Finally, export the results for downstream use. A single-variable CSV
gives a plain table of normalized intensities, and
[`save_report_xlsx()`](https://slinghub.github.io/MRMhub/quant/reference/save_report_xlsx.md)
writes a multi-sheet Excel workbook holding every data table and QC
metric in one file.

``` r

save_dataset_csv(
  mexp,
  path = "output/norm_intensities.csv",
  variable = "norm_intensity")

save_report_xlsx(
  mexp,
  path = "output/report.xlsx",
  filtered_variable = "norm_intensity")
```

With these chunks written, click **Render** once more: RStudio runs the
whole analysis top to bottom and produces a self-contained report, with
the CSV, PDFs, and Excel workbook waiting in `output/`.

## Next steps

- [A basic MRMhub
  workflow](https://slinghub.github.io/MRMhub/quant/articles/tutorial-02-basic-workflow.md):
  the full pipeline with quantification and QC filtering
- [Drift and batch
  correction](https://slinghub.github.io/MRMhub/quant/articles/tutorial-04-drift-correction.md):
  correcting run-order and batch effects
- [Exploring QC: RunScatter and
  PCA](https://slinghub.github.io/MRMhub/quant/articles/tutorial-05-run-scatter.md):
  QC visualisation in depth
- [Quarto
  workflows](https://slinghub.github.io/MRMhub/quant/articles/manual-11-quarto-workflows.md):
  rendering, figure sizing, and report options
