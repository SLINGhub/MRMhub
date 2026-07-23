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
  display args grouped** on one line.
- **Tuck the closing `)` onto the last argument line** (`… max.cv.conc.bqc = 25)`), no
  dangling paren — saves a line and reads tighter. This deviates from the air/tidyverse
  house style in `R/`, but `.Rmd` chunks aren't air-formatted so it sticks; use it only in
  articles, not in package sources.
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

## Voice provenance — the main-branch original IS the baseline

Most current articles are Claude-era rewrites of pre-Claude originals the maintainer wrote.
**The maintainer's directive (standing): start from the main-branch original text as the base,
re-add as much of his actual prose as possible, and layer on only the revisions the plan already
calls for** (file-renaming, restructure/Diátaxis, and the style conventions in this skill). Do
**not** take the current Claude-era article and lightly edit it toward his voice — that keeps
Claude's words as the base and reintroduces the drift (dramatic callouts, editorialising, invented
claims). The Claude-era article is a reference for *structure* only (section order, splits, navbar,
what was renamed), never for the prose.

Concretely, to revise an article that has a main original: read the original with
`git show main:quant/vignettes/articles/<old-name>.Rmd`, bring its text across as the starting
point, then apply the planned changes on top — rename per `plan-fileRenaming.prompt.md`, restructure
per the Diátaxis split, add the header meta / numbered sections / figure captions / cli console
conventions, fold the `<details>` Exercises into prose, and tighten only where he was genuinely
too detailed / wrong / flat (see the deviation clause below). His plainer, more direct register is
the target, not a denser "academic" rewrite. **Exception:** an article with *no* main original
(a Claude-era feature page such as `tutorial-08-summarizedexperiment`) has nothing to baseline
against — there, generate/keep on-topic text in his voice per "His register" below.

- Main tutorials live at the **pre-restructure path** `quant/vignettes/articles/`, under
  their **old names** (renamed per `plan-fileRenaming.prompt.md`) — e.g.
  `tutorial-02-basic-workflow` ← `T02_settingup_workflow`, `tutorial-03-lipidomics-workflow`
  ← `T01_targetlipidomics_workflow`. Read with
  `git show main:quant/vignettes/articles/<old-name>.Rmd`.
- **Flag and cut "Claude-era" additions** — text present in the current article but absent
  from the main original that adds no reader value: methodological caveats or lecturing
  *after* a code block, gratuitous citations (e.g. "(Broadhurst et al. 2018)"), em-dash
  "recommended order — a, b, c" lists, dense wind-ups. A simplified example is meant to stay
  simple; do **not** annotate every parameter choice or add scope (extra caveats, citations,
  cross-links) the original deliberately omitted.
- Ask "does this read like the maintainer, or like Claude?" The tells: hedging, over-
  qualification, symmetrical em-dash asides, and explaining-the-obvious are Claude tells.
- Cutting this text is **content removal → approval-gated** (see the gate below): propose the
  specific cuts, cite the main baseline, and wait.

### His register — for no-original pages & judging deviations

Because the original is now the baseline, you rarely write his prose from scratch. This trait
list serves two narrower jobs: **(a) no-original pages** (Claude-era feature pages such as
`tutorial-08`, with nothing to baseline against), and **(b) judging when a deviation is warranted**.
His register, distilled from the main tutorial+recipe corpus (T01/T02 workflows,
T_DriftCorrect/BatchCorrect/CalibRef/RunScatter, R01_quantms, 03_mrmhubexperiment):

- **Purpose-first, in the analyst's terms** — a sentence of *analytical* rationale before the code
  (why the step matters), grounded in bench reality (ISTD spiking, matrix effects, QA-vs-QC,
  dynamic range), not ggplot/tidyverse mechanics. Often a scope line up top naming the application
  domain ("as used in clinical chemistry or environmental analysis").
- **Describe → run → observe.** Say what you'll do, run it, then narrate what the plot shows —
  usually before/after; reveal the result, don't leave the reader to infer it.
- **Candid about the example's limits** ("only a few features measured, so the trend is not well
  defined") — honesty over salesmanship.
- **Say where the result lands** — the variable now holding the output and the
  `_before`/`_beforecal`/`_raw` one holding the prior value; and the **governing equation when the
  method *is* a formula** (calibration/ratio in T_CalibRef).
- **Plain register:** "we" narrating the analyst's choices, descriptive section titles, a
  load-bearing citation only (never a decorative "(Author Year)"), a practical aside pointing at
  the knob, link out at the point of need. No hedging cascades, no symmetrical em-dash asides, no
  dramatic callouts, and close on a practical "export / save" beat.

Two recurring article shapes to recognise: the **threaded workflow** (`T01`/`T02` — one long
happy path, many steps) and the **option showcase** (`T_RunScatter`, `T_DriftCorrect` — one
short `##` section per parameter/option, a single sentence on what the knob does, then its
plot). Match the shape the article already is rather than forcing a workflow narrative onto a
parameter gallery.

Emulate the *content* register above, **not** the originals' surface roughness — their typos,
`#`-level (h1) headings, and `<details><summary>Exercises</summary>` blocks are superseded by this
skill's structural conventions (numbered `## N.` sections, folded misconceptions, no Exercise
blocks).

**Integrity (all pages).** Keep the on-topic what / why / how-to-interpret — that explanation *is*
the substance; "lean" means focused, not gutted. But:
- **Cut off-topic detours, not the explanation** — design-rationale digressions belong in a
  `manual-*` (link, don't inline); ecosystem tours and padding go.
- **Never invent facts.** State only what is verifiable from the codebase, the manuals, or the
  workflows site <https://slinghub.github.io/MRMhub-workflows/>. Don't guess a downstream tool's
  capabilities (`SummarizedExperiment` as "the entry point for `ComplexHeatmap`" is a wrong guess);
  only name a tool the code actually demonstrates, not an aspirational ecosystem list.

**Deviation from an original — allowed with cause.** Depart from a passage when the maintainer was
**too detailed** (digressive → tighten to the on-topic core), **wrong** (a factual/scientific slip
→ correct; scientific content is approval-gated — surface it, don't silently fix), or **flat** (a
step merely named, or a thin placeholder → enrich with on-topic what/why/interpret in his voice).
Name the reason; don't drift back into the denser "academic" Claude register.

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
- Added "Claude-era" verbosity absent from the main-branch original — methodological
  caveats after a code block, citations, em-dash lists. Diff against
  `git show main:quant/vignettes/articles/<old-name>.Rmd` and cut back to the maintainer's
  scope and voice.
- Inventing a downstream tool's capabilities or relationships not backed by the codebase,
  manuals, or the workflows site — or padding a how-to tutorial with "why"/background sauce
  instead of stepwise what-it-does + how-it's-configured.
- Forgetting the navbar entry for a new article.
- Expecting an R-code fix to appear on the site after only `load_all()` (must `install()`).
