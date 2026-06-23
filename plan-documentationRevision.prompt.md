## Plan: MRMhub Documentation Reorganization for Progressive Onboarding

**Status (post-implementation).** Phases 1, 2, 3, and 5 are complete (incl. the structural split
of INTEGRATOR docs out of QUANT pkgdown into the Quarto `docs-site/`, the onboarding-focused
landing-page rewrite of `README.md` / `docs-site/index.qmd` / `quant/pkgdown/index.md`, and the
review pass over all 20 existing articles). Phase 4 deliverables — screencast GIFs, learnr
tutorials, R-version-matrix CI badge — remain deferred. The Shiny walkthrough app and
`check_setup()` are shipped.

**TL;DR** — Restructure MRMhub documentation from its current expert-oriented, fragmented layout into a progressive, persona-based system. Two separate GitHub Pages sites: (1) pkgdown for the `quant` R package, (2) Quarto website for INTEGRATOR + overarching MRMhub landing. Add a Shiny walkthrough app, `check_setup()` function, animated GIFs, learnr tutorials, and CI badges. Target audience: academic researchers and core facility staff with at least basic R skills.

---

## Critical Review of Current Documentation

### Structural Problems

| Issue | Severity | Detail |
|-------|----------|--------|
| **Orphan articles** | 🔴 High | `00_get_started.Rmd` and `02_QualityControl.Rmd` exist but are NOT in `_pkgdown.yml` navbar — invisible to users |
| **No clear entry point** | 🔴 High | No "Start Here" visible; main vignette `mrmhub.rmd` is boilerplate |
| **Manual vs Tutorial overlap** | 🔴 High | `T01_prepdata.Rmd` (Tutorial) and `04_dataimport.Rmd` (Manual) cover same ground at different granularity |
| **Dead-end Recipes section** | 🟡 Medium | Navbar separator with only one recipe (`R01_quantms.Rmd`) |
| **Numbering gap in Manual** | 🟡 Medium | Jumps from `05` to `07` — signals incompleteness, confuses readers |
| **No "which importer?" guide** | 🔴 High | 6+ `import_data_*()` functions with no decision tree |
| **INTEGRATOR monolith** | 🔴 High | Single `.qmd` manual — users can't find specific param help |
| **Mixed doc formats** | 🟡 Medium | `.Rmd` articles + `.qmd` for INTEGRATOR — inconsistent tooling |
| **No troubleshooting section** | 🔴 High | #1 user pain (installation) has zero documentation |
| **Unclear INTEGRATOR↔quant relationship** | 🔴 High | Users confused that one is standalone Python, other is R package |

### What Exemplary Packages Do Better

| Package | Pattern | MRMhub Gap |
|---------|---------|------------|
| **dplyr** | Single progressive intro vignette: data → verbs → pipe → combine. Every example uses bundled `starwars` data with output shown inline. | MRMhub jumps between concepts; demo data exists but isn't used in a coherent narrative |
| **mixOmics** | Numbered "Get Started" steps: (1) Install → (2) Choose method → (3) Apply → (4) If stuck. Links to webinars, forums, book, workshops. Method selector guide. | MRMhub has no pathway, no method selector, no community link, no "if stuck" section |
| **ggplot2** | Visual layer diagram explaining composable architecture; "you need at least 3 things" framing | MRMhub has no visual architecture overview |
| **tidymodels** | Role-based landing: "I want to build a model" vs "I want to tune" vs "I want to deploy" | MRMhub has flat list of articles with no routing by task or skill |

### Content Audit Summary

**Current navbar structure:**
```
INTEGRATOR Manual → 2 articles (manual + msconvert)
QUANT Tutorials  → 8 articles (T01 × 2, T02, T_Drift, T_RunScatter, T_Batch, T_CalibRef, R01)
QUANT Manual     → 7 articles (01-07, gaps)
Reference        → Function groups
News             → Changelog
```

**Problems with this structure:**
1. Users must already know whether they need a "Tutorial" or "Manual" — beginners don't
2. No installation/setup guidance visible in navigation
3. INTEGRATOR docs live inside the R package site despite being a separate Python tool
4. "Recipes" section is half-baked (1 recipe, styled as a separator not a section)
5. No cross-linking between related Manual/Tutorial articles

---

## Proposed Architecture

### Site 1: `quant` R Package (pkgdown, GitHub Pages)

**New navbar structure:**
```
Get Started ─────────────────────────────────────────────
  ├── Welcome & Installation
  ├── Your First Analysis (5-minute demo)
  ├── Key Concepts & Glossary
  └── Troubleshooting Installation

Import Data ─────────────────────────────────────────────
  ├── Which Importer Do I Need? (decision tree)
  ├── From INTEGRATOR output
  ├── From MassHunter
  ├── From Skyline
  └── From generic CSV/Excel

Workflows ───────────────────────────────────────────────
  ├── Basic: Import → QC → Normalize → Report
  ├── Lipidomics (current T01_targetlipidomics)
  ├── Quantitative Assay with Calibration (current R01)
  └── Batch Study with Drift Correction

Advanced ────────────────────────────────────────────────
  ├── The MRMhubExperiment Object
  ├── Data Identifiers & Feature Variables
  ├── Drift & Batch Correction Methods
  └── Custom QC workflows

Reference ───────────────────────────────────────────────
  (grouped by category, as current)

News ────────────────────────────────────────────────────
```

### Site 2: INTEGRATOR + MRMhub Landing (Quarto website, separate GitHub Pages)

```
Home (Landing) ──────────────────────────────────────────
  ├── What is MRMhub? (visual workflow diagram)
  ├── Which tool do I need? (INTEGRATOR vs quant vs both)
  └── Links to both sites

INTEGRATOR Guide ────────────────────────────────────────
  ├── Installation & Requirements
  ├── Preparing Input Files
  │     ├── run_order.csv
  │     ├── Transition list
  │     └── Raw data (mzML via msconvert)
  ├── Parameter Reference (param.txt)
  │     ├── Annotated template
  │     ├── Parameter-by-parameter guide with defaults/ranges/effects
  │     └── Common presets (lipidomics, metabolomics, S1P)
  ├── Running INTEGRATOR
  ├── Interpreting Output
  ├── Troubleshooting & Common Errors
  └── msconvert Instructions

Resources ───────────────────────────────────────────────
  ├── Video walkthroughs
  ├── Shiny app link
  └── FAQ
```

---

## Implementation Steps

### Phase 1: Foundation (Critical — do first)

**Step 1.** Create `check_setup()` function in [`R/`](R/)
- Validates: R version ≥ 4.2, key dependencies installed & loadable, no namespace conflicts
- Reports: clear pass/fail messages via `cli` with fix suggestions
- Pattern: similar to `devtools::session_info()` but prescriptive

**Step 2.** Write "Welcome & Installation" article replacing invisible `00_get_started.Rmd`
- Copy-paste install block (address `subdir = "quant"` explicitly)
- "Before you install" checklist: R version, restart R session, update packages
- Common errors table with solutions (Rtools missing, old rlang, loaded packages)
- End with `mrmhub::check_setup()` verification

**Step 3.** Write "Your First Analysis" (5-minute quick start)
- Single narrative from `library(mrmhub)` → `import_data_mrmhub(demo_file)` → `normalize()` → `export_xlsx()`
- Uses bundled `inst/extdata/MRMhub_demo.tsv` — no external files needed
- Show output inline (following dplyr pattern)
- Max 50 lines of user code

**Step 4.** Write "Key Concepts & Glossary" article
- Plain-language definitions: `analysis_id`, `feature_id`, ISTD, RQC, qualifier/quantifier, MRMhubExperiment
- Visual diagram of MRMhubExperiment slots
- "How MRMhub thinks about your data" framing

**Step 5.** Create visual workflow diagram (SVG/PNG)
- Shows: Raw data → msconvert → mzML → INTEGRATOR → long.csv → quant R pkg → report
- Mark optional paths (vendor software users skip INTEGRATOR)
- Embed in: README, pkgdown landing, INTEGRATOR landing, Quick Start

**Step 6.** Restructure [`_pkgdown.yml`](quant/_pkgdown.yml) navbar to new structure

### Phase 2: Import & INTEGRATOR Clarity

**Step 7.** Write "Which Importer Do I Need?" decision-tree article
- Flowchart: What software produced your data? → use this function
- Table mapping: source → function → required columns → demo file

**Step 8.** Split INTEGRATOR manual into progressive pages (Quarto website)
- Separate `param.txt` into its own page with annotated template
- Every parameter: name, default, range, plain-English effect, "when to change"
- Add "Common presets" page (e.g., "for lipidomics, use these settings")

**Step 9.** Write explicit "INTEGRATOR vs quant" explainer
- INTEGRATOR = standalone Python tool for peak integration (replaces vendor software)
- quant = R package for everything after integration (QC, normalization, reporting)
- "You might not need INTEGRATOR if..."

**Step 10.** Add Troubleshooting pages to both sites
- quant: installation errors, common runtime errors, FAQ
- INTEGRATOR: crashes, wrong output, file format issues

### Phase 3: Shiny Walkthrough App

**Step 11.** Build Shiny app in `quant/inst/shiny/walkthrough/`
- Tab 1: Data format validator (upload CSV → check columns → report issues)
- Tab 2: Interactive workflow guide (step-by-step with code generation)
- Tab 3: Results explorer (upload/connect to MRMhubExperiment → visualize)
- Launch via `mrmhub::run_walkthrough()`
- Also deploy to shinyapps.io for zero-install access

### Phase 4: Multimedia & Interactive Learning

**Step 12.** Record 3 short screencasts (< 2 min each, GIF + YouTube)
- (a) Installing MRMhub and running `check_setup()`
- (b) Setting up INTEGRATOR `param.txt` and running integration
- (c) Importing data and generating a report
- Tools: `asciinema` for terminal, screen recording for RStudio/Positron

**Step 13.** Create learnr tutorials (downloadable, run locally)
- Tutorial 1: "Your First MRMhub Analysis" (mirrors Quick Start with exercises)
- Tutorial 2: "Understanding Your Data" (explore MRMhubExperiment interactively)
- Install via `learnr::run_tutorial("first-analysis", package = "mrmhub")`

**Step 14.** Add CI badges to README
- R-CMD-check matrix badge showing tested: R 4.2/4.3/4.4/4.5 × Windows/Mac/Linux
- Gives users instant confidence about compatibility

### Phase 5: Cleanup & Polish

**Step 15.** Retire/merge overlapping articles
- Merge `T01_prepdata.Rmd` content into the new "Which Importer?" + workflow articles
- Merge `T02_settingup_workflow.Rmd` into "Your First Analysis"
- Keep specialized tutorials (Drift, Batch, CalibRef) but add "Prerequisites" boxes and cross-links

**Step 16.** Fix existing issues
- Link orphan `00_get_started.Rmd` and `02_QualityControl.Rmd` in navbar (or retire)
- Fix case mismatch `03_mrmhubexperiment.Rmd` vs navbar link
- Fill numbering gap (06 = normalization? or remove numbers entirely)
- Remove TODO placeholders in data import vignette
- Add consistent "Prerequisites" and "See also" sections to all articles

---

## Verification

- **Smoke test:** New user with R 4.3+ can go from `install.packages` to a report in < 15 minutes using only the docs
- **Site builds:** `pkgdown::build_site()` and `quarto render` both succeed cleanly
- **Shiny app:** `mrmhub::run_walkthrough()` launches without error
- **CI:** GitHub Actions R-CMD-check passes on matrix of R versions/OS
- **User test:** Ask 2-3 target users (academic + core facility) to follow "Your First Analysis" cold — observe friction points

---

## Decisions Made

| Decision | Rationale |
|----------|-----------|
| Two separate GitHub Pages sites | INTEGRATOR is Python, quant is R — separate audiences, separate update cycles |
| pkgdown + Quarto (not "Great Docs") | Great Docs is Python-only; pkgdown is canonical for R; Quarto adds rich features for non-package docs |
| Shiny app: full scope (validate + guide + explore) | Users confirmed as willing to maintain; addresses all 3 pain points |
| `check_setup()` function | Proactive solution for #1 support issue (installation failures) |
| CI badges | Instant trust signal; users know which R versions work |
| learnr over Quarto Live/webr | More mature, works offline, integrates with RStudio/Positron |
| GIFs over full video course | Low maintenance, inline in docs, no hosting/editing burden |
| Progressive disclosure over comprehensive | Hide advanced content; surface "just enough" for each skill level |
| Recommend "team up with R user" for level-a users | Honest, inclusive — don't pretend the tool requires zero R knowledge |
