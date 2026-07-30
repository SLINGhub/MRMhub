# Getting started with R and Quarto notebooks

Tutorial

A MRMhub analysis is written as a document that mixes prose with the R
code that produces the results, so the report and the analysis are one
file. This tutorial assumes no prior experience with R or Quarto: it
starts from an empty computer, installs the software, sets up the
project and notebook to work in, and shows how to read and run the code.
Once your machine is set up, [Getting started with
MRMhub](https://slinghub.github.io/MRMhub/quant/articles/tutorial-02-getting-started-mrmhub.md)
runs a complete analysis in the project you create here.

## 1. Install R and an editor

Two pieces of software are needed. **R** is the language the analysis
runs in; an **integrated development environment** (IDE) is the editor
you write and run it in. Install R first — the IDE looks for it on
startup.

- Install R from [CRAN](https://cran.r-project.org/) (version 4.1 or
  newer). Pick the download for your operating system and accept the
  defaults.
- Install an IDE. [RStudio](https://posit.co/download/rstudio-desktop/)
  is the most common choice and the one this tutorial follows. If you
  already work in VS Code, [Positron](https://positron.posit.co/) is an
  RStudio-like alternative built on the same editor.

Both are installed once per machine and shared by every project you
create afterwards.

## 2. RStudio at a glance

When RStudio opens it shows four panes, each used at some point in an
analysis:

- **Source** (top-left) — where you edit the notebook and run its code.
  Its toolbar carries the **Render** button, and each code chunk gets a
  green ▶ arrow that runs it.
- **Console** (bottom-left) — runs a single line of R immediately,
  without saving it in the notebook. This is where software is installed
  and where MRMhub’s step messages appear.
- **Environment** (top-right) — lists the objects that currently exist
  in the session, such as the `mexp` data object once the notebook has
  created it.
- **Files / Plots / Help** (bottom-right) — browses the project folder,
  shows figures, and displays function help pages.

![](data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdib3g9IjAgMCA2NDAgNDcwIiBzdHlsZT0ibWF4LXdpZHRoOiA3MDBweDsgd2lkdGg6IDEwMCU7IGhlaWdodDogYXV0bzsgZm9udC1mYW1pbHk6IC1hcHBsZS1zeXN0ZW0sIEJsaW5rTWFjU3lzdGVtRm9udCwgJiMzOTtTZWdvZSBVSSYjMzk7LCBzYW5zLXNlcmlmOyIgcm9sZT0iaW1nIiBhcmlhLWxhYmVsPSJTY2hlbWF0aWMgb2YgdGhlIFJTdHVkaW8gd2luZG93OiB0aGUgU291cmNlIHBhbmUgdG9wLWxlZnQgaG9sZHMgdGhlIG5vdGVib29rIHdpdGggYW4gUiBjb2RlIGNodW5rLCBhIFJlbmRlciBidXR0b24gYW5kIGEgZ3JlZW4gcnVuIGFycm93OyB0aGUgQ29uc29sZSBib3R0b20tbGVmdCBydW5zIHNpbmdsZSBjb21tYW5kczsgdGhlIEVudmlyb25tZW50IHBhbmUgdG9wLXJpZ2h0IGxpc3RzIG9iamVjdHM7IEZpbGVzLCBQbG90cyBhbmQgSGVscCBhcmUgYm90dG9tLXJpZ2h0LiI+PHJlY3QgeD0iOCIgeT0iOCIgd2lkdGg9IjYyNCIgaGVpZ2h0PSI0MjgiIHJ4PSIxMCIgZmlsbD0iI2Y4ZjlmYSIgc3Ryb2tlPSIjMkMzRTUwIiBzdHJva2Utd2lkdGg9IjIiIC8+PGNpcmNsZSBjeD0iMzAiIGN5PSIyOSIgcj0iNSIgZmlsbD0iI2RlZTJlNiI+PC9jaXJjbGU+PGNpcmNsZSBjeD0iNDgiIGN5PSIyOSIgcj0iNSIgZmlsbD0iI2RlZTJlNiI+PC9jaXJjbGU+PGNpcmNsZSBjeD0iNjYiIGN5PSIyOSIgcj0iNSIgZmlsbD0iI2RlZTJlNiI+PC9jaXJjbGU+PHRleHQgeD0iMzIwIiB5PSIzNCIgdGV4dC1hbmNob3I9Im1pZGRsZSIgZm9udC13ZWlnaHQ9IjcwMCIgZm9udC1zaXplPSIxNSIgZmlsbD0iIzJDM0U1MCI+bXlfc3R1ZHkK4oCUIFJTdHVkaW88L3RleHQ+PGxpbmUgeDE9IjgiIHkxPSI0NiIgeDI9IjYzMiIgeTI9IjQ2IiBzdHJva2U9IiNkZWUyZTYiPjwvbGluZT48cmVjdCB4PSIyMCIgeT0iNTgiIHdpZHRoPSIyOTAiIGhlaWdodD0iMTkwIiByeD0iNiIgZmlsbD0iI2UyZTNmMiIgc3Ryb2tlPSIjNzM3N2I4IiAvPjxyZWN0IHg9IjIwIiB5PSI1OCIgd2lkdGg9IjI5MCIgaGVpZ2h0PSIyNCIgcng9IjYiIGZpbGw9IiNmZmZmZmYiIGZpbGwtb3BhY2l0eT0iMC41NSIgLz48dGV4dCB4PSIzMiIgeT0iNzUiIGZvbnQtc2l6ZT0iMTAiIGZpbGw9IiMyQzNFNTAiPmFuYWx5c2lzLnFtZDwvdGV4dD48cmVjdCB4PSIyNDAiIHk9IjYyIiB3aWR0aD0iNjIiIGhlaWdodD0iMTYiIHJ4PSIzIiBmaWxsPSIjNWY2M2E2IiAvPjx0ZXh0IHg9IjI3MSIgeT0iNzQiIHRleHQtYW5jaG9yPSJtaWRkbGUiIGZvbnQtc2l6ZT0iMTAiIGZvbnQtd2VpZ2h0PSI2MDAiIGZpbGw9IiNmZmZmZmYiPlJlbmRlcjwvdGV4dD48dGV4dCB4PSIzMiIgeT0iMTA0IiBmb250LXdlaWdodD0iNjAwIiBmb250LXNpemU9IjE0IiBmaWxsPSIjMkMzRTUwIj5Tb3VyY2U8L3RleHQ+PHRleHQgeD0iMjkyIiB5PSIxMDUiIHRleHQtYW5jaG9yPSJtaWRkbGUiIGZvbnQtc2l6ZT0iMTMiIGZpbGw9IiM2QjlFNUUiPuKWtjwvdGV4dD48dGV4dCB4PSIzMiIgeT0iMTI0IiBmb250LXNpemU9IjExIiBmaWxsPSIjMzMzIj5lZGl0IHByb3NlIGFuZCBjb2RlCmNodW5rcyBoZXJlPC90ZXh0PjxyZWN0IHg9IjMyIiB5PSIxMzYiIHdpZHRoPSIyNTIiIGhlaWdodD0iNjYiIHJ4PSI0IiBmaWxsPSIjZmZmZmZmIiBmaWxsLW9wYWNpdHk9IjAuOCIgc3Ryb2tlPSIjYzJjM2UwIiAvPjx0ZXh0IHg9IjQyIiB5PSIxNTQiIGZvbnQtc2l6ZT0iMTAuNSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSwgTWVubG8sIENvbnNvbGFzLCBtb25vc3BhY2UiIGZpbGw9IiM3YThiOTQiPmBgYHtyfTwvdGV4dD48dGV4dCB4PSI0MiIgeT0iMTc0IiBmb250LXNpemU9IjEwLjUiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsIE1lbmxvLCBDb25zb2xhcywgbW9ub3NwYWNlIiBmaWxsPSIjNDU0YTg1Ij5tZXhwCiZsdDstIG5vcm1hbGl6ZV9ieV9pc3RkKG1leHApPC90ZXh0Pjx0ZXh0IHg9IjQyIiB5PSIxOTQiIGZvbnQtc2l6ZT0iMTAuNSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSwgTWVubG8sIENvbnNvbGFzLCBtb25vc3BhY2UiIGZpbGw9IiM3YThiOTQiPmBgYDwvdGV4dD48dGV4dCB4PSIzMiIgeT0iMjI4IiBmb250LXNpemU9IjExIiBmaWxsPSIjMzMzIj7ilrYgcnVucyBhIGNodW5rIMK3IFJlbmRlcgpidWlsZHMgdGhlIHJlcG9ydDwvdGV4dD48cmVjdCB4PSIzMjYiIHk9IjU4IiB3aWR0aD0iMjk0IiBoZWlnaHQ9IjE5MCIgcng9IjYiIGZpbGw9IiNkN2U4ZTUiIHN0cm9rZT0iIzVjOWE5NCIgLz48dGV4dCB4PSIzMzgiIHk9Ijg2IiBmb250LXdlaWdodD0iNjAwIiBmb250LXNpemU9IjE0IiBmaWxsPSIjMkMzRTUwIj5FbnZpcm9ubWVudDwvdGV4dD48dGV4dCB4PSIzMzgiIHk9IjExNCIgZm9udC1zaXplPSIxMC41IiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLCBNZW5sbywgQ29uc29sYXMsIG1vbm9zcGFjZSIgZmlsbD0iIzJlNjI1ZCI+bWV4cApNUk1odWJFeHBlcmltZW50PC90ZXh0Pjx0ZXh0IHg9IjMzOCIgeT0iMTQ4IiBmb250LXNpemU9IjExIiBmaWxsPSIjMzMzIj50aGUgb2JqZWN0cyB0aGF0IGV4aXN0CnJpZ2h0IG5vdyDigJQ8L3RleHQ+PHRleHQgeD0iMzM4IiB5PSIxNjgiIGZvbnQtc2l6ZT0iMTEiIGZpbGw9IiMzMzMiPmVtcHR5IGFnYWluIGluIGEgZnJlc2gKc2Vzc2lvbjwvdGV4dD48dGV4dCB4PSIzMzgiIHk9IjE5NiIgZm9udC1zaXplPSIxMSIgZmlsbD0iIzMzMyI+Y2xpY2sgYQpuYW1lIHRvIGluc3BlY3QgaXQ8L3RleHQ+PHJlY3QgeD0iMjAiIHk9IjI1OCIgd2lkdGg9IjI5MCIgaGVpZ2h0PSIxNzAiIHJ4PSI2IiBmaWxsPSIjZWNlNWNjIiBzdHJva2U9IiNhOTk1NGYiIC8+PHRleHQgeD0iMzIiIHk9IjI4NiIgZm9udC13ZWlnaHQ9IjYwMCIgZm9udC1zaXplPSIxNCIgZmlsbD0iIzJDM0U1MCI+Q29uc29sZTwvdGV4dD48dGV4dCB4PSIzMiIgeT0iMzEyIiBmb250LXNpemU9IjEwLjUiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsIE1lbmxvLCBDb25zb2xhcywgbW9ub3NwYWNlIiBmaWxsPSIjN2I2YTJhIj4mZ3Q7CnBhazo6cGFrKCZxdW90O1NMSU5HaHViL01STWh1YiZxdW90Oyk8L3RleHQ+PHRleHQgeD0iMzIiIHk9IjMzMiIgZm9udC1zaXplPSIxMC41IiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLCBNZW5sbywgQ29uc29sYXMsIG1vbm9zcGFjZSIgZmlsbD0iIzdiNmEyYSI+Jmd0Owptcm1odWI6OmJ1aWxkX3dvcmtmbG93KCk8L3RleHQ+PHRleHQgeD0iMzIiIHk9IjM1MiIgZm9udC1zaXplPSIxMC41IiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLCBNZW5sbywgQ29uc29sYXMsIG1vbm9zcGFjZSIgZmlsbD0iIzNhNWYzMCI+4pyUCk5vcm1hbGl6ZWQgODQgZmVhdHVyZXMgYnkgSVNURDwvdGV4dD48dGV4dCB4PSIzMiIgeT0iMzg0IiBmb250LXNpemU9IjExIiBmaWxsPSIjMzMzIj5ydW5zIGEgc2luZ2xlIGxpbmUgb2YgUgppbW1lZGlhdGVseTs8L3RleHQ+PHRleHQgeD0iMzIiIHk9IjQwNCIgZm9udC1zaXplPSIxMSIgZmlsbD0iIzMzMyI+TVJNaHVi4oCZcyBzdGVwIG1lc3NhZ2VzCmFycml2ZSBoZXJlPC90ZXh0PjxyZWN0IHg9IjMyNiIgeT0iMjU4IiB3aWR0aD0iMjk0IiBoZWlnaHQ9IjE3MCIgcng9IjYiIGZpbGw9IiNlOGRjZWMiIHN0cm9rZT0iIzlhN2JhOCIgLz48dGV4dCB4PSIzMzgiIHk9IjI4NiIgZm9udC13ZWlnaHQ9IjYwMCIgZm9udC1zaXplPSIxNCIgZmlsbD0iIzJDM0U1MCI+RmlsZXMKwrcgUGxvdHMgwrcgSGVscDwvdGV4dD48dGV4dCB4PSIzMzgiIHk9IjMxNiIgZm9udC1zaXplPSIxMSIgZmlsbD0iIzMzMyI+YnJvd3NlIGRhdGEvIGFuZApvdXRwdXQvPC90ZXh0Pjx0ZXh0IHg9IjMzOCIgeT0iMzQyIiBmb250LXNpemU9IjExIiBmaWxsPSIjMzMzIj52aWV3CmZpZ3VyZXMgaW4gUGxvdHM8L3RleHQ+PHRleHQgeD0iMzM4IiB5PSIzNjgiIGZvbnQtc2l6ZT0iMTEiIGZpbGw9IiMzMzMiPnJlYWQgP2Z1bmN0aW9uIHBhZ2VzIGluCkhlbHA8L3RleHQ+PHRleHQgeD0iMzIwIiB5PSI0NTgiIHRleHQtYW5jaG9yPSJtaWRkbGUiIGZvbnQtc2l6ZT0iMTEiIGZpbGw9IiM2NjYiPlJTdHVkaW/igJlzCmRlZmF1bHQgZm91ci1wYW5lIGxheW91dCwgd2l0aCB0aGUgcHJvamVjdCBmb2xkZXIgb3BlbiBhcwpteV9zdHVkeTwvdGV4dD48L3N2Zz4=)

The panes can be resized or rearranged, but the defaults are fine to
start; nothing here needs configuring.

## 3. Install MRMhub

With R and RStudio installed, open RStudio and install MRMhub from the
Console (the bottom-left pane). The first line installs `pak`, a package
installer; the second uses it to fetch MRMhub and its dependencies:

``` r

if (!require("pak")) install.packages("pak")
pak::pak("SLINGhub/MRMhub")
```

Installing is a once-per-machine step, and running the same two lines
again later updates MRMhub to the current version. Making its functions
available is a separate, per-session step —
[`library(mrmhub)`](https://github.com/SLINGhub/MRMhub) — which belongs
in the notebook rather than the Console, so that every render loads the
package itself.

If the installation reports an error, the [Installation
guide](https://slinghub.github.io/MRMhub/quant/articles/manual-00-installation.md)
lists the common causes (a missing compiler on Windows or macOS, a
firewall blocking the download) and their fixes.

## 4. Create a Quarto project

A **project** keeps everything for one analysis — data, code, and
results — in a single folder that the IDE treats as a unit. In RStudio,
choose *File → New Project → New Directory → Quarto Project*, give it a
name, and create it. Quarto itself ships with RStudio, so nothing
further needs installing; if the *Quarto Project* entry is missing,
update RStudio or install Quarto from
[quarto.org](https://quarto.org/docs/download/). Quarto’s [project
documentation](https://quarto.org/docs/tools/rstudio/) covers the dialog
in detail.

The dialog creates the folder, a first `.qmd` document, and an `.Rproj`
file. That `.Rproj` file is how the project is reopened later — by
double-clicking it, or through the project menu at the top-right of the
RStudio window. Opening the project, rather than the `.qmd` on its own,
is what points R at the right folder.

Inside the new project, add two folders to keep raw inputs separate from
generated results — the convention MRMhub’s own workflows follow:

    my_study/
    ├── my_study.Rproj   # opens the project
    ├── data/            # raw INTEGRATOR output and metadata files
    ├── output/          # exported CSVs, PDFs, and reports
    └── analysis.qmd     # this document

Paths in your code are written relative to this project folder: RStudio
treats it as the working directory, so `data/my_file.csv` points to the
same place on any machine, without a full path. This is why the `data/`
and `output/` folders above are all the analysis needs to find its
files, and why the whole folder can be zipped and shared as a
self-contained unit.

## 5. Write text and code in a `.qmd`

A `.qmd` file is plain text with three kinds of content: a header,
prose, and code chunks.

At the top, a short **header** fenced by `---` sets the title and the
output format — `html`, `pdf`, or `docx`. A new project starts with a
sensible HTML header, and [Quarto
workflows](https://slinghub.github.io/MRMhub/quant/articles/manual-11-quarto-workflows.md)
covers the options that matter for a MRMhub report.

Below the header, **prose** is written in Markdown — plain paragraphs,
with `#` for headings, `**bold**`, and `-` for lists. Quarto’s [Markdown
basics](https://quarto.org/docs/authoring/markdown-basics.html) is the
full reference for tables, figures, cross-references, and citations.

**Code** lives in *chunks*: R code fenced between ```` ```{r} ```` and
```` ``` ````. In RStudio, *Insert → Code Chunk* (or Ctrl/Cmd + Alt + I)
adds an empty one. A chunk that loads the MRMhub package, with a
sentence of prose introducing it, looks like this:

```` markdown
Load the package before calling any of its functions.

```{r}
library(mrmhub)
```
````

### Chunk options

Each chunk can carry **options** that control whether its code runs,
whether the code itself is shown, and which parts of its output reach
the report. They are written as `#|` comment lines directly below the
chunk’s opening fence, one per line, as `option: value`:

```` markdown
```{r}
#| label: normalize
#| message: true
mexp <- normalize_by_istd(mexp)
```
````

The options a processing notebook needs are few:

| Option | What it controls |
|----|----|
| `#| label:` | A unique name for the chunk; also names any figure it produces. |
| `#| eval:` | Whether the code runs. `false` shows the code without executing it. |
| `#| echo:` | Whether the code itself appears in the report. |
| `#| output:` | Whether the results appear — printed values, tables, figures. |
| `#| message:` | Whether messages appear. MRMhub’s step feedback travels here. |
| `#| warning:` | Whether warnings appear. |
| `#| include:` | `false` runs the chunk but hides both code and output — used for setup chunks. |
| `#| cache:` | Stores the result, so an unchanged chunk is not re-run on the next render. |
| `#| fig-width:`, `#| fig-height:` | Size, in inches, of the figures the chunk produces. |

MRMhub reports what each processing step did as a console message — a
count, and a truncated list of the features or analyses affected — so
keeping `#| message: true` on the chunks that run a step turns the
rendered report into a record of the processing. Defaults for the whole
document are set in the header instead of chunk by chunk:

``` yaml
execute:
  warning: true
  message: true
```

Quarto’s [execution
options](https://quarto.org/docs/computations/execution-options.html)
page is the complete reference for both forms.

RStudio offers two ways to edit a `.qmd`: the **Source** editor shows
the raw Markdown, while the **Visual** editor (the *Visual* toggle,
top-left of the document) shows a formatted, word-processor-like view.
Both edit the same file, and Quarto’s [authoring
guide](https://quarto.org/docs/get-started/hello/rstudio.html)
introduces both. You may also meet the older R Markdown format (`.Rmd`),
which Quarto renders unchanged; it writes the same options inside the
fence, as `{r, message=TRUE}`.

## 6. Run code and render the report

There are two distinct actions. **Running a chunk** executes its code
immediately and shows the result inline: click the green ▶ arrow at the
chunk’s top-right, or press Ctrl/Cmd + Shift + Enter with the cursor
inside it. Because each chunk builds on the objects the earlier ones
created, *Run → Run All Chunks Above* (Ctrl/Cmd + Alt + P) is the way
back to a working state after reopening the project, when the session
starts with an empty Environment.

**Rendering** turns the whole document into a finished report: click
**Render** (Ctrl/Cmd + Shift + K), and Quarto runs every chunk in order
and assembles the output — `analysis.html` alongside the document —
which opens in the Preview pane and refreshes on each render.

Rendering runs in a **fresh R session**, top to bottom, so the report is
built from what the document itself contains and nothing else. A chunk
that works interactively because a needed object is still in the
Environment pane will fail on render if no chunk creates it. This is the
point of rendering: it proves the analysis reproduces from the raw data.
While developing, run chunks one at a time to check each step; render at
the end to produce the shareable report.

Try it now: insert a chunk into your document, put
[`library(mrmhub)`](https://github.com/SLINGhub/MRMhub) in it, and run
it. Loading MRMhub without error confirms the installation worked.

``` r

library(mrmhub)
```

If a chunk stops with an error, the Console prints the message under the
offending call; the last line is usually the informative one.
[Troubleshooting &
FAQ](https://slinghub.github.io/MRMhub/quant/articles/manual-10-troubleshooting.md)
collects the errors that come up most often, and what each one means.

## 7. Reading the code you’ll run

The next tutorial uses MRMhub functions and no custom R, but three
pieces of R syntax recur throughout. Recognising them is enough to
follow along:

- **Assignment** (`<-`) stores a result under a name.
  `mexp <- MRMhubExperiment()` creates a data object and names it
  `mexp`; writing `mexp` again later refers back to it.
- **Function calls with named arguments.** In
  `import_data_mrmhub(mexp, path = demo_file)`, the function acts on
  `mexp`, and `path =` names which input the file is. Most MRMhub
  functions take the data object first and options as named arguments.
- **The pipe** (`|>`) passes a result straight into the next function,
  so `plot_pca(mexp) |> save_plot("pca.pdf")` plots and then saves in
  one line, with no temporary name.

Each processing step follows the same shape — take the data object,
return an updated one, and store it back under the same name:
`mexp <- normalize_by_istd(mexp)`. The functions do not modify the
object in place, so the assignment is what carries the result forward;
running `normalize_by_istd(mexp)` on its own leaves `mexp` as it was.
All the documentation names the object `mexp`, and keeping that one name
throughout a notebook avoids running a later step on an earlier version
of the data.

## 8. Getting help

To see what a function does and which arguments it takes, type `?`
followed by its name in the Console:

``` r

?plot_pca
```

Its help page opens in the **Help** pane, listing every argument with an
explanation and, usually, examples that can be copied and run. The same
pages for every function are in the [function
reference](https://slinghub.github.io/MRMhub/quant/reference/index.md),
the [MRMhub
overview](https://slinghub.github.io/MRMhub/quant/articles/manual-01-key-concepts.md)
introduces the concepts they build on, and problems that look like a bug
belong in the [issue
tracker](https://github.com/SLINGhub/MRMhub/issues).

With the software installed, the project set up, and the syntax
demystified, you are ready to run a real analysis. Continue with
[Getting started with
MRMhub](https://slinghub.github.io/MRMhub/quant/articles/tutorial-02-getting-started-mrmhub.md),
which imports the demo data and takes it through to an exported report.

## Next steps

- [Getting started with
  MRMhub](https://slinghub.github.io/MRMhub/quant/articles/tutorial-02-getting-started-mrmhub.md):
  run a complete analysis in the project you just created
- [Quarto
  workflows](https://slinghub.github.io/MRMhub/quant/articles/manual-11-quarto-workflows.md):
  rendering, figure sizing, and report options
- [Installation
  guide](https://slinghub.github.io/MRMhub/quant/articles/manual-00-installation.md):
  detailed setup and troubleshooting
