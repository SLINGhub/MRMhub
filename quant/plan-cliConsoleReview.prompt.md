# Plan: Standardize & correct all CLI console output in mrmhub

## Context

`mrmhub`’s console feedback (errors, warnings, progress, and the
metadata E/W/N validation report) is a **deliberate, distinctive
feature** — it gives line-by-line usage feedback and, in Quarto
notebooks, an instant colored summary of what each step did. That value
is currently undermined by drift and ad-hoc styling across **~460 CLI
call sites in 36 of 42 `R/` files**:

- **A redundant second color system.**
  [`cli::col_red`](https://cli.r-lib.org/reference/ansi-styles.html)
  (×206), `col_yellow` (×65), `col_green` (×54) wrap whole messages
  *outside* cli calls (`cli_abort(col_red("…"))`,
  `cli_alert_info(col_yellow("…"))`). But `cli_abort` is already red,
  `cli_alert_warning` yellow, `cli_alert_success` green — so the
  wrapping is redundant, prevents theming, and makes color fragile in
  Quarto.
- **Same concept styled three ways** — column/feature-variable names as
  `{.field}` (×7) vs `{.var}` (×5) vs backticks-inside-`col_*()`;
  argument names as `{.arg}` (×19) vs
  `"Argument \`x\`“`inside`col_red\`.
- **Redundant/unsafe
  [`glue::glue()`](https://glue.tidyverse.org/reference/glue.html)
  nested inside cli calls** (cli already interpolates
  [`{}`](https://rdrr.io/r/base/Paren.html)), including an empty
  `cli_abort(glue::glue(""))` in `classes.R`.
- **Inconsistent message structure** — single strings vs color-wrapped
  vs idiomatic named-bullet vectors; only a subset uses `x`/`i`/`!`/`v`
  bullets.
- **Leftover base R messaging** —
  [`stop()`](https://rdrr.io/r/base/stop.html)/[`warning()`](https://rdrr.io/r/base/warning.html)/[`cat()`](https://rdrr.io/r/base/cat.html)/[`message()`](https://rdrr.io/r/base/message.html)
  in `helper.R`, `tibble-classes.R`, `plot-featureprofile.R`,
  `calc-eda.R`, `data-example.R`, plus ad-hoc `message(" done!")` + `\r`
  progress in `plot-runscatter.R`, `plot-qc-correlations.R`,
  `data-export.R`, `qc-filtering.R` (natural `cli_progress_*` candidates
  — none used today).
- **No cli theme, no `.onLoad`, no `options(cli.*)`** — nothing
  configures color for non-interactive (Quarto) rendering.
- **Errors collapse the traceback.** The validation-report aborts pass
  `trace = NULL`, hiding the backtrace, and `call` handling is
  inconsistent — users cannot always tell which function raised the
  error.
- **Some reported numbers are wrong** (not just mis-styled). A count
  audit found several messages whose interpolated number does not
  measure what the sentence claims (metadata-row counts sold as “feature
  concentrations re-calibrated”, all-dataset denominators,
  non-intersected exclusion counts). A wrong number silently misleads in
  a way bad styling never does — this is the highest-value fix.
- **Some transforms give no feedback at all.** A few exported mexp→mexp
  steps run silently on success — most importantly the core pipeline
  verb
  [`calc_qc_metrics()`](https://slinghub.github.io/MRMhub/quant/reference/calc_qc_metrics.md)
  — so the user can’t tell the step ran or what it did.
- **Input validation is ad hoc.** There’s a shared entry guard
  (`check_data`) and a column guard (`check_var_in_dataset`), but no
  shared “required arg / right type / valid value” helper, so several
  exported functions accept missing or wrong args and fail later with an
  obscure `@`/“object not found” error instead of a friendly one.

### Decisions locked with the user

1.  **Scope:** full standardization pass over all call sites.
2.  **Color:** keep the current *full-line* red/yellow/green look, but
    relocate it into **a few package-internal wrapper helpers**
    (`mh_success/mh_info/mh_warn/mh_danger`) and replace the ~325
    scattered `col_*()` wraps with calls to them. Net visual result ≈
    today, now defined once, local, no global state. (Chosen over a
    global cli theme, which would clobber the user’s session theme — see
    Scope discipline.)
3.  **Quarto color:** implement the rendering mechanism **and** document
    it (setup chunk + verification), not just diagnose.
4.  **E/W/N report:** verify + improve rendering (unify output streams,
    add a pluralized summary count line, keep the letters so info
    survives losing color).
5.  **Errors (new requirement):** every `cli_abort` must surface the
    emitting function
    (`Error in \`fn()\`:`) via`call`, and keep the traceback **collapsed** inline (clean rlang default — full tree still reachable via`rlang::last_trace()\`).

## Critical review — scope discipline (keep it lean, low-risk)

A self-review as an R/tidyverse maintainer. The plan as first drafted
over-reaches in several places; the value is real but concentrated in a
few workstreams, and the risk is concentrated in others. Adjustments:

**Sequence into independent, individually-shippable commits — NOT one
42-file big-bang** (unreviewable, huge blast radius, and every reworded
message breaks a text-matching test). Recommended order by value ÷
risk: 1. **F — numeric correctness** (highest value, isolated,
pre-existing bugs unrelated to styling). Caveat: each fix *changes a
reported count*, and some need domain judgment (e.g. should the analyses
denominator include blanks?). Treat as **propose fix + confirm intended
semantics with the maintainer**, not a silent unilateral change. Ship as
its own commit. 2. **D (E/W/N report) + G (only `calc_qc_metrics`)** —
contained, user-visible wins. 3. **A + B — colour relocation
(wrappers) + Quarto rendering mechanism** (see A revision). 4. **J —
`manual-11-quarto-workflows` guide +
[`generate_workflow_qmd()`](https://slinghub.github.io/MRMhub/quant/reference/generate_workflow_qmd.md)
alignment** (depends on B’s colour setup being settled, since the page
and the scaffold both embed it). 5. **C + I — styling sweep +
truncation/retrievability** — largest churn, lowest per-change value; do
last, mechanically. 6. **H — validation, minimal** (see revision).

**De-scoped to avoid over-engineering:** - **A: use lightweight internal
wrapper helpers, NOT a global cli theme.** Registering
`options(cli.theme = …)` in `.onLoad` clobbers the user’s (and other
packages’) theme for the whole session — an anti-pattern. And since the
chosen look is *full-line* color, `col_*()` is the *mechanism*, not
redundancy — we are **relocating** color, not deleting it. A few
internal helpers (`mh_success/mh_info/mh_warn/mh_danger`) that apply
`col_*()` once reproduce today’s look exactly, stay local, add zero
global state, and are trivial to maintain. Drop the `zzz.R` theme
registration. - **Error policy: fix only the sites that actually break
it** — the handful passing `trace = NULL` (the metadata-import report
aborts). Do **not** mass-edit ~279 aborts to set `call =`; `cli_abort()`
already infers the caller correctly almost everywhere. - **Drop the
`cli::` namespacing normalization and the wholesale base-R→cli
migration** — cosmetic, high churn, low value. Leave legitimate
[`cat()`](https://rdrr.io/r/base/cat.html)/[`print()`](https://rdrr.io/r/base/print.html)
in S3 print/format methods (`tibble-classes.R`) alone. - **Defer
`cli_progress_*` conversion** — new behavior with non-interactive/Quarto
edge cases; ad-hoc `message("done")` works and is outside the
correctness/consistency ask. - **`{.field}` vs `{.var}` unification:
KEPT as a dedicated pass** (maintainer chose full class consistency) —
standardize column/feature-variable names on `{.field}` across all
sites. Accept the extra test churn for a uniform end state. - **Removing
nested [`glue::glue()`](https://glue.tidyverse.org/reference/glue.html):
valuable but not blind** — confirm each string uses no glue-only feature
before deleting the wrapper; keep `glue_collapse` et al. - **H stays
minimal & idiomatic:** lean on what’s free — `arg_match()` already emits
“did you mean” for enums; `check_data()` already guards the object. **Do
not build a fuzzy-match/validation framework** (drop the `agrepl` “did
you mean” helper). Add only the high-impact guards
(`data_sum_features`→`check_data`; `add_metadata` type; `smooth_fun`
enum; `save_*(path)` scalar; the 2 numeric-positive checks that
otherwise fail cryptically). Skip the ~35 filter thresholds. Be
permissive on types. New guards can break loose-but-valid existing calls
— add each guard with its test, run the suite. - **G: do
`calc_qc_metrics` (core, stable) now; defer `detect_outlier_pca` /
`data_sum_features`** — both are flagged experimental/under-revision;
low ROI to polish.

**Guiding rule:** change a message’s wording only where it buys
correctness or clarity — not for pure style — to keep test churn (the
real hidden cost) and risk bounded.

## Canonical styling conventions (the source of truth for the pass)

| Concept | Class | Notes |
|----|----|----|
| Function name | `{.fn name}` / `{.fn pkg::fn}` | never bare backticks |
| Function argument | `{.arg name}` | never spell out `Argument \`x\``; drop the word "Argument" | | Table / dataset **column** & **feature variable** (`feature_conc`,`qc_type`,`batch_id`,`analysis_id`, …) | **``** | **single chosen convention**; reserve``only for genuine R object/variable names in code. (This is the one convention the user may want flipped globally — trivially reversible via find/replace.) | | Value / level / literal |`{.val {x}}`| quotes chars, not numbers; collapses vectors | | File |``· Directory |``| | Package |``· Class |``| | Emphasis |``(critical),``(sparingly) | | | Multi-line error/warn context | named bullets`“x”`,`“i”`,`“!”`,`“v”`,`“\>”\` |

**Language & grammar rules:** sentence case; alerts concise with no
trailing period unless multi-sentence; aborts/warnings are full
sentences with periods and bullet structure; uniform validation phrasing
`"{.arg x} must be {.val a} or {.val b}."`; fix grammar bugs
(e.g. `"must larger than 0"` → `"must be greater than 0"`); consistent
domain nouns (feature, analysis, QC type, batch). Rewrite unclear /
ungrammatical / badly-punctuated messages for clarity. **Length is
directional, not absolute:** default to *shortening* (drop filler like
“Please verify … and try again” where a bullet already says it); but
where a message is genuinely under-informative — missing information the
user needs to understand or act on — **add** that information even if it
lengthens, when there is no more concise phrasing. (Namespacing
normalization and base-R→cli migration are **out of scope** — see Scope
discipline.)

**Message-layout discipline (avoid ragged multi-line output):** -
**Success/info summaries are single-line** — one
`mh_success()`/`mh_info()` (=one `cli_alert_*`) call, **no embedded
`\n`, no bullet vectors**. cli soft-wraps a long line to the console
width with an aligned hanging indent (tidy), so length ≠ mess; the
shorten rule keeps them from wrapping much anyway. - **Multi-line bullet
blocks (`c(headline, "x"=…, "i"=…)`) are for `cli_abort`/`cli_warn`
only** — where the extra context earns the vertical space. Cap at ~3–4
bullets; do not use the bullet form for routine success messages. -
**Delete existing messiness sources:** manual `\n` in strings,
multi-line
[`glue::glue()`](https://glue.tidyverse.org/reference/glue.html), and
the ad-hoc [`cat()`](https://rdrr.io/r/base/cat.html)/`\r`+`"done!"`
progress (all removed in the sweep). - **Long lists stay one (wrapped)
line** via §I truncation — never dozens of lines. - The **only**
intentional multi-line block is the E/W/N report, unified in §D. - Keep
summaries short so they don’t soft-wrap awkwardly in a narrow PDF/HTML
column; the `manual-11` setup chunk documents a sane `options(width)`.

**Efficiency rules:** remove nested
[`glue::glue()`](https://glue.tidyverse.org/reference/glue.html) inside
cli (carefully — only where no glue-only feature is used); use `{?s}` /
[`cli::qty()`](https://cli.r-lib.org/reference/pluralization-helpers.html)
/
[`cli::no()`](https://cli.r-lib.org/reference/pluralization-helpers.html)
for counts instead of `ifelse`; use vector collapsing instead of manual
`paste(collapse=)`. (`cli_progress_*` conversion is **deferred** — see
Scope discipline.)

## Work breakdown

### A. New infrastructure (do first — the sweep depends on the wrappers)

- **`R/mrmhub-cli.R`** (new): a few thin package-internal wrapper
  helpers — `mh_success()`, `mh_info()`, `mh_warn()`, `mh_danger()` —
  each calling the matching `cli::cli_alert_*()` with the message
  wrapped once in the corresponding `col_*()` so the *whole line* keeps
  today’s saturated color. This is the single place color is defined;
  call sites lose their inline `col_*()`. No global state, no `.onLoad`,
  no `options(cli.theme)` override. `@keywords internal`.
- **Add `R/mrmhub-cli.R` to `DESCRIPTION` `Collate:`** (hand-maintained)
  and add `fansi` to `Suggests` (knitr uses it for ANSI→HTML). No
  `zzz.R` needed.
- **Error/traceback policy — targeted, not a sweep:** fix only the sites
  that actually break attribution/backtrace — the aborts passing
  `trace = NULL` (`metadata-import.R` report aborts ~456/485/499/519):
  drop `trace = NULL` so rlang keeps the trace *collapsed* inline
  (reachable via
  [`rlang::last_trace()`](https://rlang.r-lib.org/reference/last_error.html))
  and set `call` so
  `Error in \`fn()\`:`names the function. Leave the ~279 other`cli_abort`calls alone —`cli_abort()\`
  already infers the caller correctly there.

### B. Quarto color rendering (implement + document)

- The mechanism: cli must **emit** ANSI in a non-interactive render, and
  knitr converts SGR→HTML via `fansi`. Provide a documented setup chunk:
  `options(cli.num_colors = 256L)` (belt-and-suspenders:
  `crayon.enabled = TRUE`).
- **Documentation for this lives in the new
  `manual-11-quarto-workflows.Rmd` (§J)** — the separate
  console-feedback article is dropped; its content (what the feedback
  conveys, the colour setup chunk, console vs. notebook behaviour, and
  the “recover the full list” recipe from §I) is absorbed there.
- Optional convenience: exported
  [`mrmhub_enable_cli_color()`](https://slinghub.github.io/MRMhub/quant/reference/mrmhub_enable_cli_color.md)
  wrapping the options for notebook users (decide during build; document
  either way).
- Verify with a throwaway `.qmd` render that alerts + the E/W/N report
  show colour in HTML.

> **STATUS (2026-07-20): D+G committed `0f3bc4a`; A+B committed
> `3954b05`; C+I committed + pushed `de0f0ad` (branch
> `feat/cli-console-review`, off `development` after F `cdfce27`).
> `devtools::document()` run (pre-C+I). Remaining: H (arg-validation),
> then re-run `document()`.** - **C+I done (`de0f0ad`)**: ~320 `col_*()`
> wraps relocated to `mh_*()`; nested
> [`glue::glue()`](https://glue.tidyverse.org/reference/glue.html)
> unwrapped; `{.arg}` (11) + `{.field}` (4) unified; `mh_vec()`
> truncation on the `head(x,5)` sites + 3 uncapped lists. Fixed 2
> pre-existing broken messages (data-outlier QC-type list;
> data-managment trailing-comma abort) + the “must larger than 0”
> grammar bugs. Kept `mh_` prefix (user confirmed; `cli_warn`/`cli_vec`
> would collide with real cli fns). Affected tests green; `_snaps`
> untouched. Left intentionally: classes.R `show()` status symbols,
> base-[`message()`](https://rdrr.io/r/base/message.html) `\r` progress
> in plot-runscatter (progress-bar conversion deferred). Note: stray
> untracked `tests/testthat/_problems/` is a testthat run artifact —
> clear it. -
> [`mrmhub_enable_cli_color()`](https://slinghub.github.io/MRMhub/quant/reference/mrmhub_enable_cli_color.md)
> (exported, in `R/mrmhub-cli.R`) sets `cli.num_colors`/
> `crayon.enabled` AND registers a knitr `message` hook: HTML →
> [`fansi::sgr_to_html`](https://rdrr.io/pkg/fansi/man/sgr_to_html.html)
> wrapped in a `<div class="cell-output cell-output-stderr">` (bare
> `<pre>` is dropped by some Quarto formats); non-HTML → `ansi_strip` +
> default rendering. - **VERIFIED**: coloured alerts + clean E/W/N
> report render correctly in **HTML**; **PDF** renders clean plain
> sans-serif text (colour is HTML-only — correct). Confirmed by
> throwaway `.qmd` renders (HTML colour spans present, PDF screenshot
> legible, no raw-ANSI leak in either). - Fixed a latent bug:
> `print.assertr_tibble` now `ansi_strip`s the captured body, so the
> `# A tibble:`/chip-row filters still match when pillar emits colour
> (previously the report header leaked once colour was on). Legend
> `style_italic` dropped (leaked in HTML). - **KNOWN LIMITATION —
> `revealjs` slides colour UNRESOLVED (gave up 2026-07-20).** cli’s
> alert output does not reliably reach the knitr `message` hook under a
> Quarto `revealjs` render (an inline always-HTML hook coloured it; the
> function-based hook did not — the hook was never invoked for the
> alert, suggesting cli routes the alert to a different stream in that
> context). HTML documents are the primary target and work; `manual-11`
> §Slides now carries an honest caution. Revisit only if slide colour
> becomes a priority.

### C. Per-file standardization sweep (core + class consistency; **last**, mechanical)

Scope = **core of C + the `{.field}`/`{.var}` unification pass**
(maintainer’s choice); **excludes** namespacing normalization,
base-R→cli migration, and progress-bar conversion. Concretely, across
all 36 files: 1. Replace every inline `col_*()` wrap with the `mh_*()`
wrapper helpers from §A. 2. Fix grammar / punctuation / clarity and
shorten (per the language rules). 3. Remove nested
[`glue::glue()`](https://glue.tidyverse.org/reference/glue.html)
(carefully; incl. the empty `cli_abort(glue::glue(""))` in `classes.R`).
4. Standardize argument names to `{.arg}` (drop spelled-out
`` "Argument `x`" ``, e.g. the `col_red` backticked-arg aborts in
`correct-drift-batch.R`). 5. Standardize all column/feature-variable
names on `{.field}` (the dedicated consistency pass).

Highest-density / worst-drift files first: `classes.R` (~51),
`metadata-import.R` (~47), `data-managment.R` (~47),
`correct-drift-batch.R` (~42), `data-import.R` (~39),
`calc-istd-normalization.R`, `calc-ref-normalization.R`,
`calc-calibrations.R`, `qc-filtering.R`. Target style = the
*already-idiomatic* `R/utils.R` (`{.field}`, `{.val}`, `{?s}`,
[`cli::qty()`](https://cli.r-lib.org/reference/pluralization-helpers.html),
no manual color).

### D. E/W/N validation report (`metadata-import.R` + `tibble-classes.R`)

- **Unify output streams.** Today the banner (`cli_alert_warning`,
  message stream) + detail table (`cat(capture.output(print(tibble)))`,
  stdout) + `cli_abort` land in up to three blocks and split in Quarto.
  Render the whole report (banner → table → legend) through **one**
  path, then raise the abort separately with a short message
  (`"Metadata invalid — see report above."`, with `call` set, trace
  preserved).
- **Add a pluralized summary line** before the table:
  `"Found {no(nE)} error{?s}, {nW} warning{?s}, {nN} note{?s}."` (via
  [`cli::qty`](https://cli.r-lib.org/reference/pluralization-helpers.html)/`no`).
- \*\*Keep E/W/W\*/N letters\*\* as the primary, color-independent
  severity signal; optionally tint the letters through the theme.
- Replace `cli::col_black(divider)` (invisible on dark themes; raw ANSI
  in Quarto) with
  [`cli::rule()`](https://cli.r-lib.org/reference/rule.html) / a neutral
  divider.
- Keep severity still hard-coded in the assertion `description` strings
  (out of scope); only the *rendering* changes.

### E. Tests & snapshots (must move in lockstep)

- ~20+ `expect_message()` / `expect_error()` / `expect_warning()`
  assertions match **exact text**
  (e.g. `test-calc-istd-normalization.R`, `test-metadata-import.R`,
  `test-calc-ref-normalization.R`); shortening/rewording **will** break
  them — update each in the same change.
- `test-tibble-classes.R` matches the legend string and divider — update
  for the report changes.
- Snapshot files `_snaps/data-import.md`, `_snaps/data-mztab.md` capture
  `cat`/`print` output — re-check after divider/report edits.
- **Snapshot hazard (from memory):** running the full suite / covr with
  `RUN_VDIFFR=false` PRUNES `_snaps/*.svg`; after any such run,
  `git checkout -- tests/testthat/_snaps` to restore vdiffr snapshots.

### F. Correctness of reported quantities (highest priority — real bugs, not styling)

> **LOCKED DECISIONS (2026-07-19):** - Guiding principle: **measure the
> reported count directly from the returned data** (distinct entities
> with the value), not `total − excluded` arithmetic or metadata rows. -
> “Concentrations calculated for N analyses” → **N = distinct
> `analysis_id` with ≥1 non-NA `feature_conc`** (measured from
> output). - Interference neg/zero message → report **“N values in M
> features”** in *both* the single-feature and batch paths.
>
> **PROGRESS (branch `feat/cli-console-review`, uncommitted):** - \[x\]
> `calc-calibrations.R`: `{?falls/fall}` grammar; rewrote quantify
> summary to
> `{n_features_with_conc} feature{?s} in {n_analyses_with_conc} analys{?is/es}`
> (measured); removed dead `if/else`, `text_failed`,
> `samples_no_amounts`, `count_*`, `n_features`. - \[x\]
> `calc-istd-normalization.R` normalize summary: measured
> `n_features_normalized`, dropped `n_features - length(istds)`
> double-subtraction + nested
> [`glue::glue`](https://glue.tidyverse.org/reference/glue.html). -
> \[x\] `calc-istd-normalization.R` quantify summary (measured
> `n_analyses_with_conc`). - \[x\] `calc-ref-normalization.R` (measured
> distinct features w/ conc, not metadata rows). - \[x\]
> `metadata-import.R` invalid analyses/features (intersect w/
> `dataset_orig`). - \[x\] `data-managment.R` exclude\_\* ×4 (intersect
> w/ `dataset_orig`, extracted vars). - \[x\] `data-import.R` quant/qual
> partition via per-feature `any(integration_qualifier)`. - \[x\]
> `lipidomics.R` count listed feature_ids; reworded phrasing. - \[x\]
> `correct-isotope.R` unified both paths to “N value(s) in M
> feature(s)”. - \[x\] `air format` on all 8 touched files; all
> parse-check OK. **F COMMITTED as `cdfce27`** on branch
> `feat/cli-console-review` (off `development`). **F COMPLETE
> (2026-07-19):** all 8 code files fixed + calc-ref count refined (the
> first fix over-counted pass-through features under
> `undefined_conc_action="original"`; now counts distinct features with
> a defined `ref_conc`, `ungroup()`ed for batch-wise). All shifted
> numbers investigated & verified reasonable: data-managment counts
> unchanged (dropped “A total of”); correct-isotope preserved 478/1,
> surfaced new 495; calc-calib 25→24 correctly excludes a no-conc
> analysis; calc-ref 3(analyte rows)→6(features). Tests updated in
> `test-calc-calibrations.R`, `test-calc-ref-normalization.R`,
> `test-data-managment.R`, `test-correct-isotope.R`; all 7 affected test
> files PASS; `_snaps` untouched. NOTE: unrelated R 4.2→4.1 change sits
> in the tree (DESCRIPTION, check-setup.R, README, app.R,
> manual-00-installation.Rmd) — exclude from the F commit.
>
> *(historical: assertions updated — numbers re-derived from the
> run:)* - `test-calc-calibrations.R` L229,252
> (`"Concentrations of these features were calculated for 25 analyses"`),
> L340 (`"...the other features were calculated"`) → new form
> `"Concentrations calculated for N feature(s) in M analys(is/es)"`. -
> `test-calc-istd-normalization.R` L139,184,210
> (`"...sample amounts of N analyses"` — measured count may differ),
> L68,83,108,174 (`"13 features normalized with 2 ISTDs in 64"` — likely
> unchanged, but wording now pluralized). -
> `test-calc-ref-normalization.R` L176,188,467
> (`"3 feature concentrations were [re-]calibrated"` →
> `"concentration(s) was/were"`; count likely unchanged). -
> `test-data-managment.R` L593,619,705,731 (dropped “A total of”;
> `"is/are"`, `"was/were"`, `analys(is/es)`/`feature(s)`; counts likely
> unchanged). - `test-data-import.R` L617-715,1047,…
> (`"Imported N analyses with M features (Q quantifiers, R qualifiers)"`
> → pluralized + trailing period; 8/8 likely same). -
> `test-correct-isotope.R` L338,358 (value count kept, now
> `"...value(s) in K feature(s) (samples/QCs)"` — **needs the new K**),
> L375,387 (batch path now same “N value(s) in M feature(s)” form —
> needs both numbers). - `test-metadata-import.R`: check
> invalid-analyses/features assertions (grep found none for “were
> excluded”, but verify pluralization didn’t break others).

Verify each numeric claim measures what its sentence says; fix the
mismatches below. For each: confirm the intended quantity with the
surrounding code, correct the computed expression, and align `{?s}`/verb
agreement to the (possibly new) count.

- **`calc-ref-normalization.R` (~L392/396)** — “{n} feature
  concentrations … re-calibrated” counts `annot_qcconcentrations` rows
  for the reference sample(s); with \>1 reference sample it multiplies,
  and includes analytes absent from the data. Recompute from the actual
  re-calibrated dataset feature count.
- **`calc-calibrations.R` (~L277/281)** & **`calc-istd-normalization.R`
  (~L475)** — “for {N} analyses” uses `get_analysis_count(data)` (all
  analyses incl. blanks/QC/ invalid) minus only *valid* missing-amount
  analyses. Use a like-for-like denominator. Also remove the **dead
  `if/else`** at calc-calibrations ~L275–282 (both branches emit the
  same string) and give `quantify_by_calibration` an actual feature
  **count** instead of “these / the other features”.
- **`metadata-import.R` (~L1099/1130)** & **`data-managment.R`
  (~L1019/1029/1086/1096)** — “{N} invalid/excluded features/analyses”
  use [`nrow()`](https://rdrr.io/r/base/nrow.html) of the metadata table
  **without** intersecting the dataset (unlike the paired “associated
  with {n_match}” line). Intersect with the data so the count reflects
  entities actually present/excluded.
- **`calc-istd-normalization.R` (~L169)** — replace the convoluted
  `n_features - length(istds)` (over-subtracts when an ISTD is defined
  but absent from data; `istds` not `semi_join`ed) with a direct
  distinct-feature count.
- **`calc-calibrations.R` (~L209)** — hard-coded plural verb “fall”
  against a `{?s}` noun; use `{?falls/fall}` (or
  [`cli::qty`](https://cli.r-lib.org/reference/pluralization-helpers.html))
  so count 1 reads correctly.
- **`lipidomics.R` (~L165)** — numerator counts unparseable name-rows
  while the list shows feature_ids; reconcile (count the listed
  feature_ids) and de-awkward the phrasing.
- **`data-import.R` (~L672)** — quantifier/qualifier split by
  `integration_qualifier` can double-count a feature whose flag varies
  across rows; count distinct per class so quantifiers + qualifiers ≤
  features.

Cross-function consistency to settle while here: `correct-isotope.R`
reports the same “negative/zero after interference correction” event as
a **value** count in the single-feature path (~L111) but a **feature**
count in the batch path (~L394) — pick one.

### G. Feedback-coverage gaps (silent transforms that should speak)

Add a terminal `cli_alert_success`/`_info` summary (counts + what
changed, per the convention table) to exported mexp→mexp transforms that
currently return silently:

- **[`calc_qc_metrics()`](https://slinghub.github.io/MRMhub/quant/reference/calc_qc_metrics.md)
  — `R/qc-filtering.R:138`** (SILENT; **core pipeline verb** — top
  priority). Summarize features and QC/sample types processed and which
  metric groups were added (norm-intensity / conc / response /
  calibration stats).
- **[`detect_outlier_pca()`](https://slinghub.github.io/MRMhub/quant/reference/detect_outlier_pca.md)
  — `R/data-outlier.R:22`** (SILENT). Report flagged analyses of total +
  method (`sd`/`mad`), fence multiplier, PC.
- **[`data_sum_features()`](https://slinghub.github.io/MRMhub/quant/reference/data_sum_features.md)
  — `R/data-summarize.R:23`** (SILENT, experimental + *destructive*
  overwrite). Report features→analytes collapsed (before→after) and
  qualifier handling; a confirmation is especially warranted given it
  overwrites `feature_id` unbacked.
- Minor:
  [`data_load_example()`](https://slinghub.github.io/MRMhub/quant/reference/data_load_example.md)
  (silent loader — report analyses/features loaded);
  [`correct_interference_manual()`](https://slinghub.github.io/MRMhub/quant/reference/correct_interference_manual.md)
  (~L154, names the feature but gives no count).

### H. Argument-validation robustness (friendly failures for missing / wrong args)

Make exported functions fail *early and friendly* when a user omits a
required arg, passes the wrong type, or gives an invalid value/name —
instead of an obscure downstream S4/`@`/“object not found” error.
**Reuse existing infrastructure**, don’t reinvent: `check_data()`
(`classes.R:281`, the standard first-arg `MRMhubExperiment` guard,
already used in ~60 transforms), `check_var_in_dataset()`
(`data-managment.R:469`, feature-variable existence),
[`rlang::arg_match()`](https://rlang.r-lib.org/reference/arg_match.html)
(already standard for enums), and the
[`correct_interference_manual()`](https://slinghub.github.io/MRMhub/quant/reference/correct_interference_manual.md)
block (`correct-isotope.R:24`) + `compare_values()` (`helper.R:47`) as
the templates for “value must be a known feature/column” messages.

Add a small **shared validation helper set** (in `R/utils.R`, next to
`coerce_checked`) for the three patterns currently re-implemented or
omitted everywhere: required-arg present, numeric-scalar-in-range, and
value-is-a-known-member (with a “did you mean …” hint via
`agrepl`/closest match). Then close the gaps:

- **Missing first-arg guard:**
  [`data_sum_features()`](https://slinghub.github.io/MRMhub/quant/reference/data_sum_features.md)
  (`data-summarize.R:23`) goes straight to `data@dataset` with no
  `check_data(data)` — add it (every sibling has it).
- **Required args with no guard** (obscure “argument … missing” later):
  [`detect_outlier_pca()`](https://slinghub.github.io/MRMhub/quant/reference/detect_outlier_pca.md)
  (`variable`, `filter_data`, `pca_component`, `fence_multiplicator`),
  [`correct_drift()`](https://slinghub.github.io/MRMhub/quant/reference/correct_drift.md)
  (`smooth_fun`, `batch_wise`),
  [`calibrate_by_reference()`](https://slinghub.github.io/MRMhub/quant/reference/calibrate_by_reference.md)
  (`absolute_calibration`),
  [`quantify_by_calibration()`](https://slinghub.github.io/MRMhub/quant/reference/quantify_by_calibration.md)
  (`fit_overwrite`),
  [`add_metadata()`](https://slinghub.github.io/MRMhub/quant/reference/add_metadata.md)
  (`metadata` — also check it’s a list bundle with `annot_*`),
  [`save_feature_qc_metrics()`](https://slinghub.github.io/MRMhub/quant/reference/save_feature_qc_metrics.md)
  /
  [`save_dataset_csv()`](https://slinghub.github.io/MRMhub/quant/reference/save_dataset_csv.md)
  (`path`).
- **Enum by hand / via [`get()`](https://rdrr.io/r/base/get.html):**
  [`correct_drift()`](https://slinghub.github.io/MRMhub/quant/reference/correct_drift.md)
  `smooth_fun` is resolved with `get(smooth_fun, mode="function")` →
  “object not found” on a typo; guard against the known smoother set
  (loess/gam/cubicspline/gaussiankernel) with a friendly list. Convert
  `MRMhubExperiment(analysis_type=)` hand-check to `arg_match` **and**
  reconcile its valid set with the documented one
  (`others`/`externalcalib` mismatch).
- **Numeric/threshold args unchecked:**
  [`detect_outlier_pca()`](https://slinghub.github.io/MRMhub/quant/reference/detect_outlier_pca.md)
  `pca_component` / `fence_multiplicator` — add numeric-positive checks
  mirroring the `kernel_size` / `outlier_ksd` guards
  (`correct-drift-batch.R:1178`; note those two messages carry the “must
  larger than 0” grammar bug and `col_red` wrap — fixed under §C).
- **Known-member gaps:** give `check_var_in_dataset()` an `else` branch
  (an unknown variable name currently passes silently) with a “not a
  known variable — did you mean …” message; verify
  `filter_features_qc(features.to.keep=)` is validated against actual
  `feature_id`s (a typo silently keeps the wrong set).

### I. Reported-list truncation & retrievability

Context: cli **already** truncates collapsed vectors at 20 by default
(both-ends style: `a, b, c, …, y, z`), so nothing is dumping hundreds of
ids today. The real problems are (1) an inconsistent limit — `utils.R`
etc. hard-code `head(x, 5)`, which also hides *how many* were omitted;
(2) a few genuinely uncapped sites; (3) the full set is often
unrecoverable from the returned object.

**Tier 1 — truncation with a settable max** (mechanical; folds into
§C): - Add to `R/mrmhub-cli.R`, beside the `mh_*()` wrappers:
`mh_vec(x, max_items = getOption("mrmhub.max_report_items", 10L))` →
`cli::cli_vec(x, style = list("vec-trunc" = max_items))`. Truncation
defined once. - Replace the hard-coded `utils::head(x, 5)` sites
(`utils.R` ×4, `data-managment.R` ×2, `data-import.R`,
`data-summarize.R`) with `mh_vec()`. - Cap the 3 currently-uncapped list
sites: `helper.R:283`, `lipidomics.R:166`, `calc-calibrations.R:652`
(raw `glue_collapse`/bare `{.val {vec}}`). - Expose
`max_report_items = getOption("mrmhub.max_report_items", 10L)` as an
optional arg **only** on user-facing functions that actually report
lists — not package-wide (avoid signature bloat); the option is the
global knob. - **Do NOT truncate:** `data-import.R` `unmapped` columns
(the list *is* the deliverable — the user needs the names to write
`column_mapping`); the bounded token sets in `metadata-import.R`
(unrecognized `valid_analysis` / `qc_type`);
`plots-qc-identification.R:398` (gated behind opt-in `outlier_print` —
the user asked for the list; consider returning it invisibly instead).

**Tier 2 — pointers where the data already persists** (free): generalize
the pattern that currently exists exactly **once**
(`calc-calibrations.R:210`,
`"(retained, flagged in {.field feature_conc_out_of_range})"`) to:
`features_no_calib` / `reg_failed_cal_1` → `metrics_calibration`;
`features_no_istd` → `annot_features`; the two `valid_*`-NA sites in
`data-managment.R` → `annot_*` (word it carefully — filtering the annot
table yields a *superset* of the reported `dropped` set); unrecognized
`qc_type` → `annot_analyses`; lipidomics unparsed →
`annot_features$lipid_class_lcb`.

**Tier 3 — persist a flag for the two highest-value losses only:** -
**`calc-istd-normalization`** — persist a cause flag so the three
distinct causes (no ISTD assigned / no ISTD row in group / ISTD
intensity zero) stay distinguishable instead of collapsing into one
undifferentiated `feature_norm_intensity = NA`. -
**`correct-drift-batch`** — persist `was_corrected` before the
`select()` (~L1925). Currently *completely* unrecoverable: values are
left unchanged, so there is no NA signature to re-derive from. - Both
need the matching template updated in `R/mrmhub-global-definitions.R`
(per `CLAUDE.md`) and a check of export/report columns.
`feature_conc_out_of_range` is the precedent — this is a known path, but
it is **not** a one-line change. - **Deferred:** the back-calc-NA flag
(`calc-calibrations` ~L225) and the bad-ref-group flag
(`calc-ref-normalization` ~L228). For the latter, at minimum reword the
message: it computes `d_bad_ref` and discards it, so it never actually
names the affected groups it implies it will.

### J. Quarto workflow guide + scaffolder alignment

**New page `vignettes/articles/manual-11-quarto-workflows.Rmd`** —
registered under Manual → *Preparing and running* in `_pkgdown.yml`
**and** in the hand-maintained `manual-index.Rmd` (orphan-article rule).
Absorbs the console-feedback content (§B). Sections: 1. **Project
layout** — cross-link `tutorial-02`’s three-folder sketch; do not
restate. 2. **Global setup chunk** — the recommended `#| include: false`
setup: execution options, `options(cli.num_colors = …)`,
`options(mrmhub.max_report_items = …)`, seed, dplyr print options. Model
on `tutorial-03`’s
`knitr::opts_chunk$set(collapse = TRUE, message = TRUE, comment = "#>")`
but expressed in Quarto `execute:` / `#|` idiom. 3. **Cell options** —
`#| eval`, `#| echo`, `#| output`, `#| warning`, `#| message`,
`#| label`, `#| cache`, `#| fig-width/height`, and an eval/echo strategy
for long-running steps (`tutorial-03:490` already hints: “set
`show_progress = FALSE` when rendering”). 4. **CLI output in colour,
nicely formatted** (absorbed from §B): the colour setup; what the
messages convey (**count** + illustrative **truncated list**); the
recover-the-full- list recipe (§I) — filter the pointer column,
`write_csv()`; `max_report_items`; and why aborts have no object to
filter. 5. **Output formats — HTML / PDF / Word**: TinyTeX prerequisite
for PDF, the sans-serif PDF rationale (mirror what the scaffolder
emits), docx caveats. Cross-link `tutorial-12` (rendering) and
`recipe-02` (parameterized reports) rather than restate. 6. **Slides —
short section**: revealjs format, reusing the workflow doc,
`echo`/output basics for showing results on slides. 7. `## Next Steps`
with 2–4 links (article convention).

Style: **pkgdown `.Rmd` conventions** — fenced-div callouts with the
base class (`::: {.callout .callout-note}`),
`DT::datatable(class = "compact stripe")` for any cell- option matrix,
academic third-person tone — **not** Quarto-native syntax, even though
the subject *is* Quarto (the page itself renders through
pkgdown/rmarkdown).

**Scaffolder alignment — `R/build-workflow.R`:** make
[`generate_workflow_qmd()`](https://slinghub.github.io/MRMhub/quant/reference/generate_workflow_qmd.md)
emit what the page recommends, so scaffold and docs agree: - emit a
`#| include: false` setup chunk (library + colour/reporting options), -
emit sensible `#|` labels/options on step chunks, - **extend, don’t
churn** the existing YAML shape (`toc`, `execute: warning: true`, the
format list incl. the sans-serif PDF header). - Lockstep updates:
[`generate_workflow_qmd()`](https://slinghub.github.io/MRMhub/quant/reference/generate_workflow_qmd.md)
is a pure string builder with a roxygen `@examples` that
[`cat()`](https://rdrr.io/r/base/cat.html)s its output; and
**`tutorial-12-workflow-builder.Rmd:118-180` quotes the emitted YAML
verbatim** — both must be updated with it, plus the `build-workflow`
tests.

## Files touched (representative, not exhaustive)

- New: `R/mrmhub-cli.R` (wrapper helpers),
  `vignettes/articles/manual-11-quarto-workflows.Rmd`
- Config: `DESCRIPTION` (`Collate:`, `Suggests: fansi`), `_pkgdown.yml`,
  `vignettes/articles/manual-index.Rmd`
- Quarto guide + scaffolder (§J): `R/build-workflow.R`,
  `vignettes/articles/tutorial-12-workflow-builder.Rmd` (quotes the
  emitted YAML verbatim — update in lockstep),
  `tests/testthat/test-build-workflow.R`
- Core sweep: all 36 `R/` files with CLI calls; heaviest listed in §C
- Report: `R/metadata-import.R`, `R/tibble-classes.R`
- Numeric fixes (§F): `R/calc-ref-normalization.R`,
  `R/calc-calibrations.R`, `R/calc-istd-normalization.R`,
  `R/metadata-import.R`, `R/data-managment.R`, `R/lipidomics.R`,
  `R/data-import.R`, `R/correct-isotope.R`
- Feedback gaps (§G): `R/qc-filtering.R`, `R/data-outlier.R`,
  `R/data-summarize.R`
- Truncation/retrievability (§I): `R/mrmhub-cli.R` (`mh_vec`),
  `R/utils.R`, `R/helper.R`, `R/lipidomics.R`, `R/data-managment.R`,
  `R/calc-calibrations.R`, `R/calc-istd-normalization.R`,
  `R/correct-drift-batch.R`, and `R/mrmhub-global-definitions.R`
  (templates, for the 2 new flag columns)
- Validation (§H): shared helpers in `R/utils.R`; `R/data-summarize.R`,
  `R/data-outlier.R`, `R/correct-drift-batch.R`,
  `R/calc-ref-normalization.R`, `R/calc-calibrations.R`,
  `R/metadata-import.R`, `R/data-export.R`, `R/classes.R`,
  `R/data-managment.R`
- Tests: message-matching test files in §E; add validation-error tests
  for the new guards

## Do NOT

- Hand-edit `NAMESPACE` / `man/*.Rd` / `docs/` — regenerated by
  roxygen/pkgdown.
- Auto-run `devtools::test/document/check` or
  [`pkgdown::build_site()`](https://pkgdown.r-lib.org/reference/build_site.html)
  — the maintainer runs these (see verification).

**Handover workflow note:** batch as many edits as possible (across F
and the mechanical workstreams) **before** running the full test suite —
the suite is slow, so complete a coherent chunk of message/count
changes + their in-lockstep test-text updates first, then run
`devtools::test()` once. `air format` on touched files as you go is fine
(fast). Do NOT run the full suite after every individual edit.

## Verification (end-to-end)

1.  **Static:** `devtools::load_all()` parses cleanly; grep confirms
    zero remaining `col_red(`/`col_yellow(`/`col_green(` wraps and zero
    `glue::glue(` nested in cli.
2.  **Numeric claims (workstream F):** on
    [`data_load_example()`](https://slinghub.github.io/MRMhub/quant/reference/data_load_example.md)
    (or a small fixture), run each affected step and cross-check every
    corrected count against the data by hand (e.g. distinct
    re-calibrated `feature_id`s vs. the “N re-calibrated” line; excluded
    features actually present in the dataset). Confirm `{?s}`/verb
    agreement at count 0, 1, and \>1.
3.  **Console look:** in an interactive R session, trigger one success
    alert, one warning, one abort, and the E/W/N report; confirm
    full-line color matches today, the abort shows
    `Error in \`fn()\`:`, the inline traceback stays collapsed, and the full tree is still available via`rlang::last_trace()\`.
4.  **Quarto:** render a small `.qmd` with the documented setup chunk;
    confirm alerts + the unified E/W/N report render **in color** as one
    coherent block in the HTML.
5.  **Feedback gaps (workstream G):** run the newly-verbose transforms
    (`calc_qc_metrics`, `detect_outlier_pca`, `data_sum_features`) and
    confirm each now prints a truthful one-line summary.
6.  **Validation (workstream H):** call the guarded functions with a
    missing required arg, a wrong-type arg, and an invalid enum/name
    value; confirm each fails fast with a friendly `{.arg …}` message
    (naming the function via `call`) rather than an obscure `@`/“object
    not found” error.
7.  **Truncation & recovery (workstream I):** trigger a message with a
    long affected list; confirm it truncates at the default, that
    `options(mrmhub.max_report_items = 50)` and the per-call
    `max_report_items` both widen it, and that the pointer column named
    in the message actually returns the full set via
    [`filter()`](https://rdrr.io/r/stats/filter.html) (and the 2 new
    flags work).
8.  **Scaffolder + guide (workstream J):** run
    [`generate_workflow_qmd()`](https://slinghub.github.io/MRMhub/quant/reference/generate_workflow_qmd.md),
    write the result to a `.qmd`, and render it to **HTML, PDF, and
    Word** — confirm it renders clean out of the box and that cli output
    is coloured in the HTML. Confirm `tutorial-12`’s quoted YAML still
    matches the emitter.
9.  **Tests (ask the maintainer to run):** `just test` /
    `devtools::test()` green after test text updates; then
    `git checkout -- tests/testthat/_snaps` per the hazard note.
10. **Ask the maintainer** to run `devtools::document()` (new exports /
    the 2 new dataset columns) and `devtools::check()`; report results
    back.
