---
name: pkgdown-article-style
description: Use when writing or revising an mrmhub QUANT pkgdown article (a vignettes/articles/*.Rmd tutorial, manual, or recipe), or rolling the house documentation style out across the site. Covers voice, structure, code formatting, cli console output, figure captions, the header meta line, and Diátaxis mode discipline.
---

# pkgdown Article Style (mrmhub / QUANT)

## Overview

House style for the QUANT pkgdown articles in `vignettes/articles/*.Rmd`. The **full
rationale and every decision live in the spec** — read it first and treat it as the source
of truth: `docs/superpowers/specs/2026-07-21-tutorial-style-design.md`. The **reference
implementation** is `tutorial-04-drift-correction.Rmd`; match it. This skill is the
operational checklist + tooling map + verify loop.

## When to use

- Revising or writing any `tutorial-*`, `manual-*`, or `recipe-*` `.Rmd`.
- Rolling the style out article-by-article across the site.

Not for: the Quarto sites (`docs-site/`, `integrator/docs/`) — those have their own
conventions.

## Quick reference — the conventions

**Voice & prose**
- Measured first-person-plural "we" for narration; imperative lead-in right before a code
  chunk. Academic, concise. Target ~20–30% tighter than a first draft.
- **Tone: serious yet inviting** — a knowledgeable colleague at a whiteboard, not a cheerful
  tour guide or a stiff manual. Warmth comes from clarity + anticipating the reader (the
  inclusive "we", pre-empting a likely confusion, naming what the figure shows, revealing
  the result, plain words, varied rhythm). Avoid the false-friendly register (exclamation
  marks, "let's dive in", "it's easy", emoji, walls of tip-boxes) — reads as templated.
- No lone 1–2 sentence paragraphs — merge a trailing observation up into the step's lead-in
  or into a fuller post-figure paragraph.
- **Restrained inline code:** package/product names (**MRMhub**) are NEVER code font; only
  class names (`MRMhubExperiment`), args, values, expressions get backticks. Keep grey
  `code` spans sparse in prose; prefer plain words for concept lists.
- Explanation lives in prose; keep tutorial code **near comment-free** (a `# comment` only
  for a micro point-of-use detail, never to restate prose).

**Structure**
- Title: sentence case, no terminal period. YAML `description:` one focused line.
- Header meta line (raw HTML `<p class="page-meta">`): type chip + `<span class="page-level">`
  + `<span class="page-prereq">Prerequisites: …</span>` — Prerequisites first-class but
  **only if a real one exists**; supports multiple (comma-separated). No time estimate.
- Numbered sections (`## 1.`, `## 2.`) for tutorials; manuals/recipes unnumbered.
- No `<details>` Exercise blocks — fold any useful misconception into prose.
- Close with `## Next steps` (2–4 bare relative `.html` links). Prerequisites (top) and Next
  steps (bottom) never overlap.

**Code formatting** (semantic; `.Rmd` chunks aren't air-formatted)
- Object/first positional on its own line; **analytical args one per line**; **incidental
  display args grouped** on one line; closing `)` on its own line.
- Keep every real code line **≤ ~76 chars** → never a horizontal scrollbar. (`#|`
  chunk-option lines aren't echoed.)

**Figures** — `#| fig.cap: !expr fig_cap("…")` (auto-numbered "Figure N.", ≤2 lines,
standalone) + a `#| fig.alt:`. Split before/after pairs into separate captioned chunks.

**Console output (cli)** — `source("_common.R")` in a hidden setup chunk; `message = FALSE`
globally, opt in per chunk with `#| message: true`. Renders as a flat light
`.cell-output-stderr` band, no `#>`, colored. See Tooling.

**Diátaxis** — one mode per page: `tutorial-*` = learning (one happy path, minimal why,
link out), `recipe-*` = task how-to, `manual-*` = reference/explanation. Push "why" out of
tutorials into a `manual-*` and link.

## By article type — what differs

The Quick reference above is tutorial-calibrated. Adjust per mode:

**`tutorial-*` (learning)** — everything above as written: "we"+imperative voice, numbered
sections, header meta with **Level + Prerequisites**, numbered result-figures, cli console
output shown at meaningful steps, one happy path.

**`manual-*` (reference / explanation)** — the biggest shift is **voice**: third-person
*descriptive* (reference states facts) or *expository* (explanation reasons about why), **not**
the "we…" walkthrough and no imperative step lead-ins. Header = the **chip only** (no Level,
no Prerequisites — a reference isn't leveled or sequenced); **no numbered sections**. Favor
**lookup structures** (`DT::datatable`, kable/markdown tables, decision trees, definition
lists) and, for explanation, inline-SVG brand diagrams + `<details>` "alternatives
considered". Code is **minimal** — signature illustrations + reference links, not a threaded
walkthrough; **no cli console-output narration** (so `_common.R` is tutorial-only). Enforce
**one Diátaxis mode per page**: reference has no procedures and no "why" digressions;
explanation has no step-by-step. Push any procedure to a recipe/tutorial and link (the
`manual-05` split is the worked example). *Manual conventions are less battle-tested than
tutorial ones — validate and refine on the first full manual pass.*

**`recipe-*` (how-to)** — task-framed and imperative/"we" like tutorials, but goal-oriented;
Prerequisites optional, no numbered sections; may show results. `recipe-05-import-metadata`
is the reference.

Shared across all three: sentence-case titles, the tone note, restrained inline code (package
names never coded), no lone short paragraphs, sparing callouts, `## Next steps`, navbar sync,
≤76-char / semantic code where code appears.

## Scientific review — two personas (approval-gated)

Beyond style, review each article for **structure, content, scientific correctness, and
usefulness**, reading it through two reader lenses:

- **Analytical / LC-MS scientist** — is the MS / QC / quantitation methodology correct and
  current (QC-only drift & batch fitting, ISTD normalization, calibration, interference /
  isotope correction)? Is the terminology what a mass-spec lab actually uses? Does the
  workflow reflect real bench practice, and would an analyst trust and follow it?
- **Bioinformatics / metabolomics data scientist** (some LC-MS know-how) — are the data
  structures, reproducibility, and statistical reasoning sound? Is the R / tidyverse
  idiomatic and correct? Is the pipeline order and rationale defensible, the output usable
  downstream, and are the claims about the data honest?

Assess four dimensions: **structure** (does the flow serve the reader's goal?), **content**
(complete, no gaps or errors), **scientific correctness** (methods and claims are right),
**usefulness** (does it actually help these two readers do their work?).

**APPROVAL GATE — major changes require the user's explicit OK, every time.**

| Change type | Action |
|---|---|
| **Minor** — the style/formatting/prose conventions in this skill | Apply directly. |
| **Major** — restructuring sections, changing or correcting scientific content/claims, reworking the workflow or its order, substantial language rewrites, adding/removing whole sections | **Propose, then STOP and wait for the user's explicit approval before editing.** |

Rules for the gate (no loopholes):
- Ask **each time**, even when the change seems obviously correct. "It's clearly an
  improvement" is not a reason to skip approval.
- Present each major proposal concisely: *what*, *why*, and *from which persona's view*.
- **Never** batch several major changes into a silent rewrite. One proposal, one approval.
- The maintainer is the domain expert — surface a suspected scientific error for their
  judgement rather than "fixing" it unilaterally.

## Tooling map

- `vignettes/articles/_common.R` — sourced by each tutorial's setup chunk. Sets chunk opts
  (`comment = ""`), calls `mrmhub_enable_cli_color()`, defines `fig_cap()`.
- `pkgdown/extra.css` — `.page-meta` / `.page-kind` / `.page-level` / `.page-prereq`,
  `.cell-output-stderr` console band, figure-caption sizing. Add CSS here, never inline.
- Console rendering fact: **pkgdown 2.2.x renders cli output itself** (native
  `.cell-output-stderr` + fansi); `mrmhub_enable_cli_color()`'s hook is bypassed in pkgdown
  and only applies to plain-knit/Quarto. Transient "starting/please wait" statuses are gated
  to `rlang::is_interactive()` in the package so they don't leak into renders.

## Verify loop

1. **R-code changes need `devtools::install()` before `build_site()`** — pkgdown renders
   each article in a subprocess that loads the *installed* package; `load_all()` does NOT
   reach it. (`.Rmd`, `_common.R`, `extra.css` are read fresh — no reinstall.)
2. Build one article to preview: `pkgdown::build_article("articles/<name>")`.
3. Checks: code parses; no real code line > 76 chars; figures numbered; cross-link targets
   exist; console band has no `#>`.
4. Update `_pkgdown.yml` navbar for any new/renamed article (orphan = #1 doc bug).

## Rollout status

Done: `tutorial-04-drift-correction` (reference implementation); `manual-05` Diátaxis split
→ `recipe-05-import-metadata`. Remaining tutorials to bring to style: `tutorial-02`,
`tutorial-03`, then the rest (`tutorial-00/01/05/07/10/11/12`).

## Common mistakes

- Package name in code font (`MRMhub` → MRMhub).
- Trailing lone-sentence paragraph after a figure (merge it up).
- Wide code line → horizontal scrollbar (wrap it; ≤76 chars).
- Editing `docs/` by hand, or committing partial `docs/` previews — regenerate with a full
  `build_site` instead.
- Forgetting the navbar entry for a new article.
- Expecting an R-code fix to appear on the site after only `load_all()` (must `install()`).
