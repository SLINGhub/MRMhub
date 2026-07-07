# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working
with code in this repository.

## Repository layout

This repo bundles two complementary tools that share a common workflow
but are independent code bases:

- **Repo root** — **R package `mrmhub`**. `DESCRIPTION`, `R/`, `tests/`,
  `vignettes/`, `man/`, `_pkgdown.yml` all live at the top level: the
  repo root *is* the package root, so `R CMD check`, `devtools::*`,
  `pkgload`, RStudio, and CI all run from here — **no `cd` needed**.
  Non-package top-level items (`integrator/`, `docs-site/`, `docs/`,
  `CLAUDE.md`, `plan-*.prompt.md`, `justfile`, `.vscode/`, …) are hidden
  from the package build via `.Rbuildignore` — add an entry there when
  introducing a new top-level file, or `R CMD check` emits a
  “non-standard files at top level” NOTE.
- `integrator/` — **INTEGRATOR**, a stand-alone application for raw peak
  detection / picking / integration on MRM data, shipped as a pre-built
  executable. Being rewritten in **Rust** (self-contained crate in
  `integrator/`, built + released by
  `.github/workflows/integrator-release.yml`); the Python in
  `integrator/src/*.py` is the legacy reference implementation.
  `integrator/MRMhub_plot.r` is a separate base-R script the executable
  shells out to for PDF plotting — **not** part of `mrmhub`, no
  dependency on it. `integrator/docs/` is the **independent multi-page
  INTEGRATOR Quarto site**, published to `/integrator/` — co-located
  with the tool it documents, just as QUANT’s pkgdown docs live with the
  R package. Pages: `index.qmd` (overview), `quickstart.qmd`,
  `setup.qmd` (download + per-project setup — INTEGRATOR is a portable
  executable, *not* installed), `input-files.qmd`, `running.qmd`,
  `viz.qmd`, `sharing.qmd`, `msconvert.qmd`, shared `images/`; navbar
  (Home / Quick Start / Manual ▾) + sidebar are defined in
  `integrator/docs/_quarto.yml`. These `.qmd` use Quarto-native syntax
  (`::: {.callout-*}`, `.grid`) — unlike the pkgdown articles.
- `docs-site/` — Quarto site source for the **project landing page
  only** (`index.qmd` — routes to INTEGRATOR + QUANT), published to the
  Pages root. The INTEGRATOR manual lives in `integrator/docs/`, not
  here.
- `docs/` — generated pkgdown output (committed). Don’t hand-edit;
  regenerate with
  [`pkgdown::build_site()`](https://pkgdown.r-lib.org/reference/build_site.html)
  from the repo root (or `just site`).
- `README.md` at the repo root is the package README (GitHub home);
  `integrator/README.md` covers the Rust tool. The detailed manual +
  tutorials live as `vignettes/articles/*.Rmd`, published via pkgdown.

The two tools talk only through files: INTEGRATOR emits `long.csv` /
`quant_raw.csv`, which `mrmhub::import_data_*()` then ingests.

**Task runner.** A `justfile` at the root wraps the common commands —
`just test`, `just check`, `just document`, `just site`, `just format`
(R package) and `just build-rust` (INTEGRATOR). Install `just` with
`brew install just`; `just --list` shows the menu.

> **Published URL note:** the GitHub Pages site (`gh-pages` branch)
> hosts **three independent sites** that share the branch: - **root**
> `https://slinghub.github.io/MRMhub/` — the landing page (Quarto
> `docs-site/`). - **`/integrator/`**
> `https://slinghub.github.io/MRMhub/integrator/` — the INTEGRATOR
> manual (Quarto `integrator/docs/`). - **`/quant/`**
> `https://slinghub.github.io/MRMhub/quant/` — the QUANT pkgdown site
> (matches `_pkgdown.yml: url`; don’t “fix” it).
>
> Two workflows build them: `.github/workflows/quarto.yaml` renders
> **both** Quarto sites — landing → root (`clean: true`,
> `clean-exclude: quant` + `integrator`) and INTEGRATOR → `/integrator/`
> (`target-folder: integrator`, `clean` scoped there);
> `.github/workflows/pkgdown.yaml` deploys QUANT → `/quant/`
> (`target-folder: quant`, `clean` scoped there). The scoped cleans mean
> no deploy clobbers another’s subfolder. Cross-links rely on this
> layout: both the landing page and the pkgdown navbar link to
> `/integrator/` (absolute URLs); the INTEGRATOR and landing sites link
> to `/quant/`. After a structural change to the gh-pages layout,
> trigger the `quarto` workflow once (it owns the root) to clear stale
> files.

## Active documentation work

Three plan files at the repo root drive an ongoing documentation
overhaul and are **living context, not scratch**:

- `plan-documentationRevision.prompt.md` — overall reorg into
  progressive, persona-based onboarding (pkgdown for QUANT, Quarto for
  INTEGRATOR/landing).
- `plan-fileRenaming.prompt.md` — canonical `{category}-{nn}-{slug}.Rmd`
  naming convention (`manual-*`, `tutorial-*`, `recipe-*`,
  `integrator-*`). Use this as the source of truth when naming new
  articles.
- `plan-workflowDiagrams.prompt.md` — brand colour palette and design
  rules for inline-SVG/HTML flowcharts on the landing pages.

Consult them before structural changes to vignettes or the navbar. The
untracked `tutorial-09-pca-exploration.Rmd`,
`tutorial-10-metadata-validation.Rmd`,
`tutorial-11-interference-correction.Rmd`, and
`manual-08-visualization.Rmd` are work-in-progress outputs of this
effort.

## Common commands (run from the repo root)

``` r

# Install deps + load for interactive dev
devtools::install_deps(dependencies = TRUE)
devtools::load_all()

# Tests
devtools::test()                                  # full suite
testthat::test_file("tests/testthat/test-classes.R")  # one file
testthat::test_file("tests/testthat/test-classes.R", filter = "Construct")  # single test

# Docs / namespace
devtools::document()        # regenerate man/ + NAMESPACE from roxygen
pkgdown::build_site()       # rebuild docs/ (pkgdown output is committed)

# Full package check (matches CI)
devtools::check()           # or: R CMD check --no-manual mrmhub_*.tar.gz
```

``` bash
# Or via the justfile (preferred): just test / just document / just site / just check / just format

# Format R sources (Posit's air formatter — config at air.toml)
air format .                 # in-place format all R/ + tests/
air format --check .         # CI / pre-commit drift check
air format R/calc-eda.R      # one file
```

CI (`.github/workflows/R-CMD-check.yml`) runs `R CMD check` on
macOS/Windows/Ubuntu from the repo root; `paths-ignore` skips R CI for
`integrator/`- and `docs-site/`-only changes. **`RUN_VDIFFR=false` in
CI** — visual-diff (vdiffr) snapshot tests are skipped on GitHub
Actions; if you change plotting code, run `devtools::test()` locally
with vdiffr enabled and inspect `tests/testthat/_snaps/` before
committing.

## Architecture: the `MRMhubExperiment` object

Everything in `mrmhub` revolves around a single **S4 class
`MRMhubExperiment`** (`R/classes.R`). It’s a container for all tibbles +
processing state for one experiment. Functions are mostly **pure-ish
transforms** of the shape `mexp -> mexp` — they take an
`MRMhubExperiment`, return a new one with updated slots, and flip status
flags (`is_istd_normalized`, `is_quantitated`, `is_filtered`,
`is_isotope_corr`, etc.). **This is the load-bearing convention** — new
processing functions must follow it (first arg = `MRMhubExperiment`,
return = `MRMhubExperiment`, update flags, never mutate `dataset_orig`).
Functions returning a bare tibble or accepting raw columns break
composability of the pipeline and will not feel native to the API.

**Recommended pipeline order** (enforced by status flags, not hard
errors — see `manual-10-design-decisions.Rmd`): `import_data_*` →
`add_metadata` → `set_analysis_order` → `normalize_by_istd` →
`correct_drift_*` → `correct_batch_*` → `quantify_by_istd` /
`quantify_by_calibration` → `calc_qc_metrics` → `filter_features_qc` →
`save_report_xlsx`. Drift and batch correction are **QC-sample-based
only** (Broadhurst 2018) — never use study samples for fitting.

**Importer family** (`manual-05a-which-importer.Rmd` has the decision
tree): `import_data_mrmhub` (preferred — INTEGRATOR’s long output),
`import_data_masshunter`, `import_data_skyline`, `import_data_csv_wide`,
`import_data_csv_long`, `import_data_folder` (multi-file batches).

**Feature variables** carry a `_orig` / `_raw` / `_before` /
`_beforecal` / `_fit` postfix when a step overwrites them. See
`manual-03-feature-variables.Rmd`. Don’t invent new postfixes — extend
the existing set.

Key slots (see `R/classes.R` for the full list and
`R/mrmhub-global-definitions.R` for the column templates):

- `dataset_orig` — long-format tibble of raw imported data (one row per
  analysis × feature). Required cols: `analysis_id`,
  `raw_data_filename`, `acquisition_time_stamp`, `feature_id`.
- `dataset` — long-format working tibble after metadata join +
  processing. Carries `feature_intensity`, `feature_norm_intensity`,
  `feature_conc`, `qc_type`, `batch_id`, etc.
- `dataset_filtered` — same shape as `dataset`, populated by
  [`filter_features_qc()`](https://slinghub.github.io/MRMhub/quant/reference/filter_features_qc.md).
- `annot_*` — metadata tables (`annot_analyses`, `annot_features`,
  `annot_istds`, `annot_responsecurves`, `annot_qcconcentrations`,
  `annot_studysamples`, `annot_batches`).
- `metrics_qc`, `metrics_calibration` — derived QC/calibration metrics
  per feature.
- `parameters_processing`, `status_processing` — record of what was run.
- `var_drift_corrected`, `var_batch_corrected` — per-variable booleans
  tracking which of `feature_intensity` / `feature_norm_intensity` /
  `feature_conc` have been corrected.

**S4 + tibbles:** `R/mrmhub-global-definitions.R` does
`setOldClass(c("tbl_df","tbl","data.frame"))` so tibbles can occupy
`"tbl_df"` slots. Empty prototypes for each slot are stored on
`pkg.env$table_templates` and consulted both by the class prototype and
by import functions to enforce schema. If you add a column to a
dataset/annot table, update the matching template in
`mrmhub-global-definitions.R` or downstream code will silently drop or
mis-type it.

## R source file conventions

The file layout in `R/` is functional, not by class — the `Collate:`
field in `DESCRIPTION` is hand-maintained and must list every `.R` file:

- `calc-*.R` — quantitation / normalization / calibration calculations.
- `correct-*.R` — drift, batch, isotope, interference corrections.
- `data-*.R` — import, export, combine, manage, outlier, summarize.
- `plot-*.R` / `plots-*.R` — ggplot-based plotting (singular = one chart
  family, plural = QC dashboards). vdiffr snapshots live next to the
  corresponding `tests/testthat/test-plot*.R`.
- `qc-filtering.R` — feature/sample exclusion logic feeding
  `dataset_filtered`.
- `mrmhub-package.R` — central `@importFrom` declarations. Most imports
  are declared here in one block rather than per-function; **add new
  imports here** when introducing a new dependency call, not via inline
  roxygen on the consumer.
- `mrmhub-global-definitions.R` must be loaded before `classes.R`
  (enforced via `@include` and the `Collate:` order).

After adding/removing exported functions or changing roxygen, run
`devtools::document()` — `NAMESPACE` is generated and shouldn’t be
edited by hand.

**Do not hand-edit generated outputs.** `NAMESPACE` (roxygen),
`man/*.Rd` (roxygen), and `docs/` (pkgdown) are regenerated from source
— edits to them will be silently overwritten on the next `document()` /
`build_site()`. If you need a change there, change the upstream roxygen
block or pkgdown config.

**Running checks.** The maintainer prefers to run `devtools::test()` /
`document()` / `check()` and
[`pkgdown::build_site()`](https://pkgdown.r-lib.org/reference/build_site.html)
themselves — **don’t invoke these automatically**; ask and report back
(the `justfile` wraps them: `just test`, `just check`, `just document`,
`just site`). Lightweight read-only sanity (`devtools::load_all()`,
parsing a file) is fine.

## Vignettes / docs

`vignettes/articles/` contains ~30 long-form `.Rmd` articles organised
by prefix: `manual-*` (concept/reference), `tutorial-*` (step-by-step
workflows), `recipe-*` (specific tasks), `integrator-*` (INTEGRATOR
usage). The navbar in `_pkgdown.yml` is the source of truth for which
articles appear in the published site and in what order — if you add or
rename an article, update `_pkgdown.yml` too or it will be orphaned.
`vignettes/mrmhub.rmd` is the only “real” package vignette (built into
`inst/doc/`); the `articles/` subtree is pkgdown-only.

**Article style conventions** (match the existing patterns — these are
deliberate, not accidental):

- **Diagrams**: hand-rolled inline `<svg>` (see
  `manual-00-architecture.Rmd`, `manual-00-key-concepts.Rmd`,
  `manual-05a-which-importer.Rmd`). Use the brand palette in
  `plan-workflowDiagrams.prompt.md` (steel blue `#5B8FA8`, warm orange
  `#D4914E`, muted green `#6B9E5E`, dusty rose `#C27171`, navy
  `#2C3E50`) with ~15–30 % opacity fills. No ASCII art, no
  externally-rendered PNG/mermaid for flowcharts.
- **Tables**:
  [`DT::datatable()`](https://rdrr.io/pkg/DT/man/datatable.html) with
  `class = "compact stripe"` for anything filterable/sortable
  (glossaries, comparisons). Plain Markdown tables are fine for short
  reference matrices.
- **Callouts**: Modest
  `<div class="callout callout-{note|tip|caution}">...</div>` boxes
  (styles in `pkgdown/extra.css` — steel blue Note, warm orange Tip,
  dusty rose Caution). Use sparingly — plain prose by default. Bootstrap
  `alert-*` still renders but reads too loudly on onboarding pages.
  **Never** use Quarto `::: callout-*` syntax — articles render through
  pkgdown/rmarkdown, not Quarto.
- **Collapsibles**:
  `<details><summary><strong>Title</strong></summary> ... </details>`
  for “alternatives considered”, troubleshooting steps, full slot trees,
  etc.
- **Cross-links + Next Steps**: every article ends with a
  `## Next Steps` (or equivalent) list of 2–4 links to related articles.
  Use bare relative `.html` links
  (e.g. `manual-05a-which-importer.html`), not absolute URLs.
- **Navbar sync**: any new/renamed article must be added to
  `_pkgdown.yml` in the same change. Orphan articles are the \#1 doc bug
  here.

The Quarto `.qmd` files under `docs-site/` (landing page) and
`integrator/docs/` (INTEGRATOR manual) are separate sites and *can* use
Quarto-native syntax — don’t cross-apply the pkgdown conventions there.

## Working on INTEGRATOR (`integrator/`)

INTEGRATOR is being rewritten in **Rust** — a self-contained crate in
`integrator/` (no root `Cargo.toml`, so it doesn’t clutter the R package
top level). It’s shipped as a pre-built executable via GitHub Releases:
`.github/workflows/integrator-release.yml` cross-compiles for macOS +
Windows and attaches the binary when a Release is published (the
workflow is a guarded no-op until `integrator/Cargo.toml` exists). Build
locally with `just build-rust` (or
`cd integrator && cargo build --release`).

The legacy Python reference implementation lives in
`integrator/src/*.py` (`MRMcwt.py` CWT peak picking, `MRMgetpeak.py`
peak selection, `MRMistd.py` ISTDs, `MRMcorrect.py` RT correction,
`MRMeic.py` EICs, `MRM_RT.py` RT alignment, `commonfn.py` shared utils
imported by all the others). It reads parameters via
`commonfn.read_param()` from a `param.txt` in the working directory.
INTEGRATOR and `mrmhub` are decoupled — they communicate only through
`long.csv` / `quant_raw.csv`.

`integrator/MRMhub_plot.r` is invoked by the executable’s “Step 4” to
produce per-transition PDFs; it expects a `misc/trans_R.csv` and other
artefacts in the current working directory. It uses base R + `parallel`
only, no `mrmhub` package dependency.
