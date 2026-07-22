# Tutorial style spec

**Date:** 2026-07-21
**Author:** Bo Burla (with Claude Code)
**Status:** Approved for implementation
**Applies to:** `vignettes/articles/tutorial-*.Rmd` (pkgdown site, QUANT / `mrmhub`)

## Purpose

Define a consistent house style for the `mrmhub` pkgdown **tutorials** and apply it to
three worked examples. The Claude-era tutorials drifted toward verbosity and away from
the measured academic voice of the original (pre-Claude) tutorials on `main`. This spec
restores that voice, tightens prose, and standardises structure, figures, and console
output.

**Governing principle — judge case by case.** The rules below are guidelines, applied
with editorial judgement, not mechanical enforcement. Where a rule would hurt clarity in
a specific spot, the clearer option wins. This is deliberate; a linter-style pass is not
the goal.

## Scope

**Deliverable:** this spec + apply it to three tutorials as worked examples, building the
shared tooling once:

- `tutorial-02-basic-workflow.Rmd` — entry-point workflow.
- `tutorial-03-lipidomics-workflow.Rmd` — flagship end-to-end workflow (descends from the
  main-branch `T01_targetlipidomics_workflow.Rmd`).
- `tutorial-04-drift-correction.Rmd` — testbed for the colored-console rendering.

Shared tooling: `vignettes/_common.R` (or per-article setup chunk), a knitr caption hook,
a knitr console-output hook, and `.r-output` CSS in `pkgdown/extra.css`.

**Out of scope:** recipes, manuals, the INTEGRATOR/landing `.qmd` sites; and any
restructuring of which article explains what, beyond relocating stray digressions out of
tutorials. Rollout to the remaining tutorials happens in later passes once these three
validate the spec.

## 1. Voice and language

- **Default voice:** first-person-plural "we" for narration ("We import the result file…
  We observe that the trend is flat after correction."), dropping into the **imperative**
  for the action immediately before a code chunk ("Apply a QC-based drift correction:").
  This is the field norm for scientific R tutorials (Bioconductor, tidyverse, rOpenSci)
  and matches the original main-branch voice.
- **Register:** academic, measured, third-person-ish, concise technical language. No
  breezy second-person ("you'll want to…"), no filler wind-ups ("It is important to note
  that…", "In order to…" → "To…").
- **Tone — serious yet inviting.** Warmth in technical writing comes from *clarity and
  anticipating the reader*, not from casual chattiness. The target voice is a knowledgeable
  colleague at a whiteboard: direct, unhurried, occasionally anticipating your question —
  not a cheerful tour guide, not a stiff manual. Levers that add warmth without losing
  rigor: the inclusive "we"; a sentence that pre-empts a likely confusion; naming what the
  reader sees in a figure ("the green trendline follows the QC points"); revealing the
  result so they can self-verify; plain words where jargon is not load-bearing; varied
  sentence rhythm; brief "because" explanations. Avoid the false-friendly register
  (exclamation marks, "Let's dive in!", "it's easy", "don't worry", emoji, walls of
  tip-boxes) — it reads as patronizing and templated.
- **Prose rules (Google dev-docs style, cherry-picked — fills the gap the tidyverse
  style guide leaves, which is code-only):** active voice, present tense ("the function
  returns…", not "will be returned"); **descriptive link text**, never "see here" / "click
  here"; sentence-case headings; define a term on first use, then stay consistent. Google's
  "use second person" rule is deliberately **not** adopted — we keep "we".
- **Conciseness:** target a **20–30 % word cut** versus the current drafts, without losing
  information. One idea per sentence; delete redundant modifiers and hedging.
- **Restrained inline code.** Package/product names (**MRMhub**) are **never** in code font
  (tidyverse rule); only class names (`MRMhubExperiment`), arguments, values and expressions
  get backticks. Keep inline-code density low in prose — a paragraph broken up by many grey
  `code` spans reads crowded. In an intro especially, prefer plain words for a concept list
  ("raw intensities, normalized intensities, or concentrations") over a run of coded
  variable names; the exact identifiers appear in the code chunks anyway.
- Applied case by case — a sentence of plain second-person or a slightly longer aside is
  fine where it genuinely reads better.

## 2. Structure

- **Title:** passive, technical, short; sentence case, no terminal period
  (e.g. "Drift and batch correction").
- **YAML `description:`** one focused line (also the pkgdown index subtitle). Longer only
  when the topic genuinely needs it.
- **Opening intro:** a few focused sentences framing what the tutorial does, before the
  first code chunk.
- **Header meta (no callout box):** a single `.page-meta` line — the type chip, then
  **Level** (`.page-level`), then **Prerequisites** (`.page-prereq`) inline after a middot,
  shown **only when a real prerequisite exists**. Prerequisites support **one or more**
  links (comma-separated), each a genuine precondition (a prior tutorial or a concept the
  reader must know first). No time estimate (an invented number that reads as filler).
  Prerequisites stay at the **top** — a precondition the reader needs *before* starting;
  they are deliberately **not** folded into the bottom **Next Steps**. Prerequisites
  (read-before) and Next Steps (read-after) are the complementary ends of the linear
  reading path and must never list the same article.
- **Numbered sections:** tutorials use `## 1.`, `## 2.`, … to signal an ordered
  walkthrough. Manuals and recipes stay unnumbered (reference, not sequence).
- **Combine** any 1–2 line sections into a single block; avoid a heading per sentence.
- **No Exercise blocks.** The main-branch `<details>` Exercises are dropped: collapsed,
  easy to miss, and — with no solution given — they clutter more than they teach when the
  prose already explains the concept. Where a misconception is genuinely worth flagging
  (e.g. "a QC-based correction does not necessarily straighten the study-sample trend"),
  fold it into the surrounding prose as a plain sentence rather than a hidden prompt. An
  optional one-line learning objective in the intro ("After this tutorial you can…") is
  still fine where it helps.
- **Next Steps:** keep the mandatory closing list of 2–4 bare relative `.html` links.

## 3. Explanation discipline (Diátaxis-lean)

Tutorials follow **one happy path**. Trim "you could also…" alternatives and long "why"
digressions; a sentence or two of inline rationale is fine where it helps a first-time
reader, and anything longer links out to the relevant `manual-*` article. Judge case by
case — do not mechanically strip every explanatory clause.

## 4. Figures

- Every plot gets a short (**≤ 2 line**) **visible caption**, auto-numbered
  "**Figure N.** …", where N increments per tutorial via a knitr caption hook + counter.
- Captions are **standalone**: interpretable from caption + figure alone, without the body
  text. Short declarative title, then the essential what-it-shows.
- Keep the existing invisible `fig.alt` for accessibility (separate from the visible
  caption; see the `alt-text` skill).
- Mechanism: a `fig_cap()` helper in `vignettes/articles/_common.R` maintains a per-article
  counter and prepends `Figure N.`; each figure chunk sets
  `#| fig.cap: !expr fig_cap("…")`. `html_vignette` does not auto-number figures on its own.
  Chunks producing a before/after pair are split so each panel is numbered and captioned
  individually.

## 5. Console output (colored CLI, no `#>` prefix)

The `mrmhub` cli messages (green ✔ success alerts, grey info notes) render as a
**real-colored console block with no `#>` comment prefix**, distinct from normal R code
output.

- **pkgdown 2.2.1 renders cli output itself.** It captures the message stream, converts
  the ANSI via fansi, and wraps each message in `<div class="cell-output cell-output-stderr">`
  — so in the pkgdown site `mrmhub_enable_cli_color()`'s own knitr hook is **bypassed**.
  Still call the helper once from `vignettes/articles/_common.R`: it sets
  `cli.num_colors`/`crayon.enabled` so cli emits ANSI for pkgdown/fansi to colour, and its
  hook remains the render path for **plain-knit / Quarto** articles (e.g. `manual-11`), where
  the strip-`#>` + trim-trailing-newline fix it now carries still applies.
- **No `#>` prefix.** pkgdown applies the chunk `comment` to message output, so `_common.R`
  sets `comment = ""` (these tutorials print no raw R output, so it only affects the cli
  blocks). `message = FALSE` globally; show console feedback per chunk with `#| message:
  true` at meaningful points (import, each correction, export) — decided to **keep all
  output at those points**, not trim to one line.
- **Styling — flat light band, no nested box (`pkgdown/extra.css`).** Do **not** box the
  `.cell-output-stderr` div: Bootstrap already styles the inner `<pre>` as a bordered,
  rounded box, so an outer box nests. Instead flatten that `<pre>` (drop its border /
  radius / default background / padding) and restyle it as a flat band with a muted-green
  left accent; `white-space: normal` on the `code` collapses pkgdown's appended trailing
  newline (safe — these are single-line alerts) so there is no blank line and no fragile
  clipping. Small top margin (hug the code chunk), larger bottom margin (separate from the
  following prose).
- **Light band is WCAG-driven.** A dark/navy terminal block was rejected: cli's info notes
  use `col_grey`, which **fails WCAG 4.5:1 on navy**; on the light band both green success
  and grey info clear it.

## 6. Examples

Tidyverse idiom throughout; base pipe `|>` exclusively (per repo convention). Attach with
`library(mrmhub)`, never `load_all()`.

- **Keep code lines short** (≈ ≤ 76 chars) so a rendered code block **never** needs a
  horizontal scrollbar. Wrap multi-argument calls across lines rather than compressing them
  onto one wide line. (`#|` chunk-option lines are not echoed, so only real code lines
  count.)
- **Semantic call formatting.** When a call breaks across lines: the object / first
  positional on its own line; **analytical arguments** (those that determine what the
  operation does — `variable`, `ref_qc_types`, `batch_wise`, `kernel_size`, `correct_scale`,
  `path`, …) **one per line** so they stand out and are easy to edit; **incidental
  display/layout arguments** (`rows_page`, `cols_page`, `show_trend`) **consolidated onto one
  line**; the closing `)` on its own line (tidyverse/air standard). The consistency is in
  the rule (meaningful args prominent, cosmetics compact), not in literal uniformity.
- Function names auto-highlight and link to their reference via downlit; argument names stay
  default-uncoloured while variables get the variable colour — the standard R convention,
  left as-is.
- **Explanation lives in prose; tutorial code stays near comment-free.** The narrative
  carries the "what" and "why" — do **not** migrate prose into `# comments`, which
  duplicates it and turns the chunk into a wall of green. Reserve inline comments for micro
  point-of-use detail tied to a specific arg/line that would clutter prose
  (e.g. `kernel_size = 10,  # ~10-sample smoothing window`), and never to restate the
  adjacent prose. Tutorial-04 currently carries zero comments, which is the target baseline.

## Implementation notes / risks

- **`.Rbuildignore`:** `docs/superpowers/` must be added to `.Rbuildignore` (new top-level
  path) so `R CMD check` does not flag non-standard files.
- **vdiffr:** adding captions/hooks changes rendered articles, not plot objects — no
  snapshot churn expected, but run `devtools::test()` locally with vdiffr on before
  committing plotting-adjacent edits, and `git checkout -- _snaps` if the vignette-render
  path prunes svgs.
- **`_common.R`:** if `vignettes/_common.R` does not yet exist, create it and `source()` it
  from each article's setup chunk; keep hooks in one place.
- **Regeneration:** after edits, the maintainer runs `pkgdown::build_site()` / `just site`
  — do not auto-run (per CLAUDE.md).
- **Per-tutorial application is itself case-by-case:** the three worked examples validate
  the spec; expect small spec amendments as real content pushes back.

## Open questions (resolve during implementation)

- Exact caption-hook API (`fig.cap` prefix vs. a dedicated chunk option) — pick the
  simplest that survives pkgdown.
- Whether the terminal block should also carry a small "console" label/prompt glyph, or
  stay unadorned.
