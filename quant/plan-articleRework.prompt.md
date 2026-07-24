# Plan — Article rework (tutorials + recipes) to house style

**Goal.** Bring every QUANT pkgdown **tutorial** and **recipe** to the
house documentation style, reworked from the maintainer’s main-branch
original text. This is the tracking doc; do **one article per focused
chat** and update the Status column here as each lands.

## Method (do this per article — the skill has the full detail)

Invoke the **`pkgdown-article-style`** skill first; it is the source of
truth. In short:

1.  **Baseline = the main-branch original.** If the article has an
    original (see table), start from its text:
    `git show main:quant/vignettes/articles/<original>.Rmd`. Re-add as
    much of the maintainer’s actual prose as possible; the current
    Claude-era article is a reference for *structure only* (order,
    splits, navbar, renames), never for prose. A page with **no**
    original is generated/kept in his voice (don’t gut it).
2.  **Layer the planned revisions on top:** header meta line, numbered
    `## N.` sections (tutorials), `## Next steps`, figure captions
    (`fig_cap` + `fig.alt`), cli console setup (`_common.R`), semantic
    ≤76-char code with paren-tucks, fold every
    `<details>Exercises</details>` into prose, Diátaxis discipline (one
    mode per page). Update `_pkgdown.yml` if anything is renamed/added.
3.  **Two-persona scientific review** (analytical/LC-MS +
    bioinformatics/metabolomics) for structure, content, scientific
    correctness, usefulness.
4.  **Approval gate.** Minor style/prose fixes: apply directly. Major
    changes (restructure, scientific content/claims, whole-section
    add/remove, substantial rewrites): **propose and wait for Bo’s OK,
    each time.** Deviate from the original only when it was genuinely
    too detailed / wrong / flat, and name the reason.
5.  **Verify:** `devtools::install()` (only if R code changed) →
    `pkgdown::build_article(...)` to preview, then a full `build_site()`
    before the docs commit. Never hand-edit `docs/`.
6.  **Commit** in reviewed, well-scoped groups (source separate from the
    `docs/` rebuild). Never commit without Bo’s explicit OK on the diff.
    Work lands on `development`.

## Inventory & status

Baseline path = `main:quant/vignettes/articles/<original>.Rmd`.

| Article | Main-branch original | Mode | Status |
|----|----|----|----|
| tutorial-00-first-analysis | *(none — Claude-era)* | tutorial | to verify |
| tutorial-01-prep-data | `T01_prepdata` | tutorial | pending |
| tutorial-02-basic-workflow | `T02_settingup_workflow` | tutorial | done (OLD method — revisit?) |
| **tutorial-03-lipidomics-workflow** | `T01_targetlipidomics_workflow` | tutorial | **NEXT (flagship)** |
| tutorial-04-drift-correction | `T_DriftCorrect` | tutorial | done (OLD method — revisit?) |
| tutorial-05-run-scatter | `T_RunScatter` | tutorial | pending |
| tutorial-07-calibration-reference | `T_CalibRef` | tutorial | pending |
| tutorial-08-summarizedexperiment | *(none — Claude-era)* | tutorial | done |
| tutorial-10-metadata-validation | *(none — Claude-era)* | tutorial | to verify |
| tutorial-11-interference-correction | *(none — Claude-era)* | tutorial | to verify |
| tutorial-12-workflow-builder | *(none — Claude-era)* | tutorial | to verify |
| recipe-01-ext-calibration-qc | `R01_quantms` | recipe | pending |
| recipe-02-custom-qc-report | *(none — Claude-era)* | recipe | to verify |
| recipe-03-mztab-export | *(none — Claude-era)* | recipe | to verify |
| recipe-05-import-metadata | *(from manual-05 split)* | recipe | done |

Reference implementations already in-style:
`tutorial-04-drift-correction` (canonical) and
`tutorial-08-summarizedexperiment` (no-original page). `manual-*`
reworks are out of scope here.

## Recommended order

1.  **tutorial-03-lipidomics-workflow** — flagship; ~22 sections in the
    original, richest test of the main-baseline method + two-persona
    review. Do first to validate the approach end-to-end.
2.  Remaining originals, roughly workflow order: **tutorial-01**,
    **tutorial-05**, **tutorial-07**, **recipe-01**.
3.  No-original pages (generate/tidy in his voice, lighter touch):
    **tutorial-00**, **tutorial-10/11/12**, **recipe-02/03**.
4.  Revisit-decisions (see below): **tutorial-02**, **tutorial-04**.

## Open decisions / notes

- **Revisit tutorial-02 & tutorial-04?** Both were styled under the
  *old* method (edited from the Claude rewrite, not rebuilt from
  `T02_settingup_workflow` / `T_DriftCorrect`). Decide whether to redo
  them against their originals or leave as-is.
- **Orphaned original `T_BatchCorrect`.** The rename plan mapped it to
  `tutorial-06-batch-correction`, but no `tutorial-06` exists — its
  content appears folded into `tutorial-04-drift-correction`. When
  reworking tutorial-04, pull batch-correction prose from
  `T_BatchCorrect` too.
- **recipe-05-import-metadata** has no single original; it came from the
  `manual-05` Diátaxis split. Baseline against the metadata-import parts
  of `main:…/05_metadataimport.Rmd` + `04_dataimport.Rmd` if revisited.
- Keep `_pkgdown.yml` navbar in sync with any rename/add — orphan
  articles are the \#1 doc bug.
