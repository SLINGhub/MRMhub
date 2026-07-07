# Docs structure review — first-time-user & persona audit

> Living context for the documentation overhaul. Companion to
> `plan-documentationRevision.prompt.md`, `plan-fileRenaming.prompt.md`,
> `plan-workflowDiagrams.prompt.md`. Written 2026-07-07.

## Scope of this review

Structure and organization of the three published sites, evaluated from four
viewpoints with emphasis on the **first-time landing experience** ("what is this
all about"):

- Analytical scientist — little/no R, and some R
- Student new to analytics / MS / metabolomics — little/no R, and some R
- Bioinformatician with metabolomics background
- **Chosen primary target user (tie-breaker):** a biochemist with some RStudio
  know-how who *runs* R scripts but does *not* write code.

Surfaces read: hub landing (`docs-site/index.qmd`), QUANT pkgdown home
(`README.md` + `_pkgdown.yml` navbar), INTEGRATOR home (`integrator/docs/index.qmd`
+ `_quarto.yml`), the 5-min on-ramp (`tutorial-00-first-analysis.Rmd`).

## One-sentence diagnosis

The docs are well-built but **front-load a routing decision before answering
"what is this."** A newcomer is asked to self-route between INTEGRATOR and QUANT
before being shown what the tool does or seeing a single result. That — not the
writing quality, which is good — is the source of the "overwhelming and confusing"
feeling.

## Three structural problems that cause the overwhelm

1. **Four "homes," no single front door.** GitHub `README.md`, the hub
   `…/MRMhub/`, `…/quant/`, and `…/integrator/` each carry their own "what is
   MRMhub" pitch and their own near-duplicate "choose your path" table
   (`docs-site/index.qmd` "Choosing the right tool" vs `README.md` "Choose your
   path"). A newcomer lands on a different pitch depending on arrival route; the
   three routing tables will drift.

2. **Five names for a two-part thing:** `MRMhub`, `mrmhub` (lowercase pkgdown
   tab), `QUANT`, `MRMhub-QUANT` (brand), `INTEGRATOR`. Reads as "which of these
   do I install?"

3. **"What is this" is *defined*, never *shown*.** Every home opens with
   "open-source toolchain for targeted MRM mass spectrometry" — accurate, but
   there is no screenshot of the deliverable (QC report, RunScatter plot,
   before/after). One picture of the output would answer the question faster than
   the prose.

## Per-persona verdict

| Persona | Verdict | Where they bounce |
|---|---|---|
| Analytical scientist, little/no R | Underserved | Module-choice + `long.csv`/`msconvert` jargon before value; then "install the R package / run R scripts." Their lifeline `run_walkthrough()` (GUI) is a footnote in one tutorial. |
| Analytical scientist, some R | Reachable but slow | The 5-min first-analysis tutorial is right for them but sits 3 clicks deep, behind the module split. |
| Student, new to MS/metabolomics | Underserved | Landing assumes BQC/TQC/ISTD/drift vocabulary; the Key Concepts glossary is buried in a menu, not offered as "new to the field, start here." ~20-item Manual menu intimidates. |
| Bioinformatician | Well served (arguably over-served) | Module split, importer decision tree, function reference, reproducibility story — all present and prominent. The site is tuned for this persona, which is why the other three feel lost. |

Pattern: **the site is optimized for the one persona who needs the least help.**
Reference-grade material (MRMhubExperiment object, feature-variable postfixes,
design decisions) sits at the same navbar altitude as "import your data."

## Under the chosen target user (biochemist, RStudio, runs scripts, no code)

- **QUANT is the 80% path.** They receive integrated peaks or vendor output;
  INTEGRATOR (separate executable + msconvert + mzML) is a minority path. Yet the
  landing gives the two modules equal visual weight, and INTEGRATOR appears first
  in the workflow diagram and in 2 of 3 table rows. The lede is buried.
- **"Runs scripts, doesn't write code"** ⇒ the copy-paste 5-min tutorial and
  `run_walkthrough()` are the product for them; they should be the hero, not the
  module taxonomy.
- They don't need "INTEGRATOR vs QUANT" as the first question. They need "here's
  what you'll get, here's the 3 lines to get it."

## Recommended direction (priority order)

1. **One canonical front door: "what + show + go" before any split.** Above the
   module choice: one sentence of what you *get*, one screenshot of the output,
   one primary button → the 5-min first analysis. The INTEGRATOR-vs-QUANT
   decision drops below the fold / into a "Do you have raw files?" secondary path.
2. **Collapse the naming.** "MRMhub = the project; two tools, INTEGRATOR and
   QUANT" — said identically everywhere. Drop `mrmhub`/`MRMhub-QUANT` from
   user-facing surfaces (keep the package name only where R requires it).
3. **De-weight the Manual for newcomers.** Introduce tiers: *Start here (3 pages)
   → How-to → Reference.* Keep reference material accessible but not at top
   altitude.
4. **Promote the two low/no-code on-ramps** (`run_walkthrough()` GUI + 5-min
   tutorial) to the front door.
5. **Single-source the routing table** — one block, reused, not three
   hand-maintained copies.

## Next step

Brainstorm the redesign (front-door concept + Start-here/How-to/Reference tiers),
then write an execution plan. Optionally mock the new hub `index.qmd` first so
there's something concrete to react to.
