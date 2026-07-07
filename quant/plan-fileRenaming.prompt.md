# NA

## Plan: Documentation File Renaming

**Status:** Implemented. The renames in the table below have been
applied. The two `integrator-*` files have since been **moved out** of
`quant/vignettes/articles/` into the Quarto site at `docs-site/` (see
*Update, post-implementation* note below); the `integrator-NN-` prefix
was dropped at the move because it only disambiguated siblings of
`manual-NN-*` / `tutorial-NN-*` inside `quant/vignettes/articles/`.

**TL;DR** — Rename all vignette/article files in
`quant/vignettes/articles/` to a consistent `{category}-{nn}-{slug}.Rmd`
naming convention. Categories: `manual-`, `tutorial-`, `recipe-`,
`integrator-`. Update all references in `_pkgdown.yml`. Delete the stub
`02_QualityControl.Rmd`.

------------------------------------------------------------------------

## Rename Table

| Current | New |
|----|----|
| `00_get_started.Rmd` | `manual-00-get-started.Rmd` |
| `01_datastructure.Rmd` | `manual-01-data-structure.Rmd` |
| `02_keydataids.Rmd` | `manual-02-data-identifiers.Rmd` |
| `02b_keyfeaturevar.Rmd` | `manual-03-feature-variables.Rmd` |
| `03_mrmhubexperiment.Rmd` | `manual-04-mrmhub-experiment.Rmd` |
| `04_dataimport.Rmd` | `manual-05-data-import.Rmd` |
| `05_metadataimport.Rmd` | `manual-06-metadata-import.Rmd` |
| `07_driftbatchcorr.Rmd` | `manual-07-drift-batch-correction.Rmd` |
| `T01_prepdata.Rmd` | `tutorial-01-prep-data.Rmd` |
| `T02_settingup_workflow.Rmd` | `tutorial-02-basic-workflow.Rmd` |
| `T01_targetlipidomics_workflow.Rmd` | `tutorial-03-lipidomics-workflow.Rmd` |
| `T_DriftCorrect.Rmd` | `tutorial-04-drift-correction.Rmd` |
| `T_RunScatter.Rmd` | `tutorial-05-run-scatter.Rmd` |
| `T_BatchCorrect.Rmd` | `tutorial-06-batch-correction.Rmd` |
| `T_CalibRef.Rmd` | `tutorial-07-calibration-reference.Rmd` |
| `R01_quantms.Rmd` | `recipe-01-ext-calibration-qc.Rmd` |
| `Integrator_manual.qmd` | `integrator-01-integrator-manual.qmd` → later moved to `docs-site/integrator-manual.qmd` (see note below) |
| `msconvert_manual.qmd` | `integrator-02-msconvert.qmd` → later moved to `docs-site/msconvert.qmd` (see note below) |

**Delete:** `02_QualityControl.Rmd` (14-line stub with no content)

> **Update, post-implementation.** The two `integrator-*` files were
> later moved out of `quant/vignettes/articles/` into the Quarto site at
> `docs-site/`, executing the two-site architecture from
> `plan-documentationRevision.prompt.md` (Site 1 QUANT pkgdown / Site 2
> INTEGRATOR + landing). At the move the `integrator-NN-` prefix was
> dropped, because in `docs-site/` these files are no longer siblings of
> `manual-NN-*` / `tutorial-NN-*` and the prefix served only as sibling
> disambiguation. Current canonical paths:
> `docs-site/integrator-manual.qmd` and `docs-site/msconvert.qmd`. The
> corresponding `quant/_pkgdown.yml` INTEGRATOR submenu was replaced
> with a single cross-link entry pointing at the docs-site Quarto pages.

------------------------------------------------------------------------

## Steps

1.  Run `git mv` for each file in `quant/vignettes/articles/`
2.  Update all `href:` paths in
    [`quant/_pkgdown.yml`](https://slinghub.github.io/MRMhub/quant/quant/_pkgdown.yml)
3.  Update any cross-references in
    [`quant/pkgdown/index.md`](https://slinghub.github.io/MRMhub/quant/quant/pkgdown/index.md)
4.  Remove duplicate `docs/articles/msconvert_manual.qmd` if present
5.  Delete `02_QualityControl.Rmd`

## Verification

- [`pkgdown::build_site()`](https://pkgdown.r-lib.org/reference/build_site.html)
  completes without broken link warnings
- All navbar items resolve correctly
- `git status` shows clean renames (not delete+add)

## Decisions

| Decision | Rationale |
|----|----|
| `manual-` / `tutorial-` / `recipe-` / `integrator-` prefixes | Clear category at a glance; sorts logically in file explorer |
| Kebab-case with zero-padded numbers | Consistent, sortable, URL-friendly |
| Delete QC stub rather than rename | 14 lines, no real content, would mislead users |
| Keep `get-started` as manual-00 | Preserves its “first thing to read” position |
