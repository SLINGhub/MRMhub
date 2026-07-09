# Plan — Align the INTEGRATOR Quarto site with the MRMhub landing page

**Date:** 2026-07-08 **Status:** design approved, ready to implement
**Scope:** `integrator/docs/` (INTEGRATOR manual site, published to
`/integrator/`)

## Goal

Make the INTEGRATOR Quarto site read as the same brand family as the
MRMhub landing page (`docs-site/`, published to the Pages root). The two
sites already share the navy navbar, the steel-blue / navy `_brand.yml`
palette, the cosmo theme, the hex logo, and the right-hand info panel.
The remaining mismatch is the **title treatment** and the **typographic
system** on the INTEGRATOR home, which currently fall back to plain
cosmo defaults.

## What differs today

| Aspect | Landing (`docs-site/`) | INTEGRATOR (`integrator/docs/`) |
|----|----|----|
| Title | Custom navy H1 (2.7rem) + `.lead` subtitle + `.title-sep` rule | Quarto front-matter `title/subtitle/description` block (cosmo default) |
| Section headers | Quiet navy `h2`/`h3` (`.landing-grid h2`) | Plain cosmo defaults |
| Type system in `styles.css` | Full `.landing-grid` block (`h1`, `.lead`, `.title-sep`, `h2`/`h3`, `.hero-fig`, `.arrow-list`, `.module-list`) | Missing; plus **dead** `.workflow-diagram` rules |

Content width is intentionally *not* aligned: the landing page uses
`page-layout: full` capped at 1340px because it has **no sidebar**; the
INTEGRATOR home carries a left sidebar (Overview / Quick Start /
Manual), so forcing full-width would fight the sidebar.

## Changes

### 1. `integrator/docs/index.qmd` — title block

- Remove `title`, `subtitle`, and `description` from the YAML front
  matter (keep `toc: false`).
- Inside the `.g-col-12 .g-col-lg-9` content column, above the intro
  paragraph and after the hex `<img>`, add the landing-style title
  block:
  - `# INTEGRATOR`
  - `::: {.lead}` *Peak detection, picking, and integration for targeted
    MRM mass spectrometry* `:::`
  - `::: {.title-sep}` `:::`
- Everything else on the page (intro paragraphs, workflow SVG, “Where to
  start” grid, callouts, “Next step in the pipeline”, info panel) is
  unchanged.

**Accepted trade-off:** dropping front-matter `description` removes the
page’s SEO/social meta description. The landing page has none either, so
this matches precedent. (Revisit later with an explicit `<meta>` if SEO
becomes a concern.)

### 2. `integrator/docs/styles.css` — typography system

- **Remove** the unused `.workflow-diagram`, `.workflow-step`,
  `.workflow-arrow` rules (the homepage uses inline `.wf-box` SVG,
  confirmed by grep — no `.qmd` references these classes).
- **Add**, mirrored from `docs-site/styles.css`, the shared landing
  block: `.landing-grid h1`, `.landing-grid .lead`, `.title-sep`,
  `.landing-grid h2`/`h3`, `.hero-fig`, `.landing-grid` column-gap,
  `.arrow-list`, `.module-list`. Mark this block “keep in sync with
  docs-site/styles.css” — the same sync convention already used for
  `_brand.yml`.
- **Keep** existing `.hex-logo`, `.info-panel`, `.developer-list`, and
  the responsive `@media (max-width: 991.98px)` block (already mirror
  the landing).

## Out of scope

- Inner manual pages (quickstart, setup, running, algorithm, viz,
  sharing, input-files, msconvert) — they inherit the new header/lead
  styling automatically; no per-page edits.
- Content-width / `page-layout` changes (see rationale above).
- Navbar, palette, `_brand.yml`, hex logo (already shared).

## Verification

- Run `quarto preview integrator/docs` (or
  `quarto render integrator/docs`) and visually compare the INTEGRATOR
  home against the landing page: navy H1 with hairline rule, `.lead`
  subtitle, quiet navy section headers.
- Confirm inner pages still render (headers inherit navy styling, no
  regressions).
- Do **not** commit the generated `_site/` (it is `.gitignore`d in
  `integrator/docs/`).
