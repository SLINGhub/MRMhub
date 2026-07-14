# Bootstrap — continue mrmhub code review at Tier 2

Paste this into a new chat (or say: "Read docs-review/tier2-bootstrap.md and continue with Tier 2").

## Context

We are running a pragmatic, data-integrity-focused code review of the `mrmhub` R package
(repo root = package root; branch `development`). The full audit is in
`docs-review/code-review-2026-07.md` (5 dimensions: data-integrity, perf/memory, overcomplicated/risky
lines, monkey-fixes, stale code). **Tier-1 (all 14 Blocking findings) is DONE and committed.**
Now working through **Tier-2 (Required)**.

## Working rules (established with the maintainer, Bo — follow exactly)

1. **One finding at a time.** For each: investigate → apply fix → verify (run tests) → show the diff →
   **wait for the maintainer to check** → commit only when they say "commit"/"proceed". Then next.
2. **Never edit existing tests without explicit consent.** They are manually verified. If a fix breaks a
   currently-passing test, **stop and surface it** (show the failure + reasoning); do not "fix" the test.
   If the maintainer approves, update only the minimal expectation.
3. **Running builds is permitted** (as of 2026-07-14): `devtools::test()`, `document()`, `check()`.
   BUT `test()` is slow due to vdiffr snapshots — always run **`RUN_VDIFFR=false`** (suite self-skips
   vdiffr) and **after any full/vdiffr-off run: `git checkout -- tests/testthat/_snaps`** (pruning hazard).
   Prefer per-file: `RUN_VDIFFR=false Rscript -e 'devtools::load_all(quiet=TRUE); as.data.frame(testthat::test_file("tests/testthat/test-<x>.R", reporter="silent", stop_on_failure=FALSE))'`.
4. **`air format <file>`** each touched file before showing the diff. Conventions: base pipe `|>` only,
   `cli::cli_abort/cli_warn/cli_inform` for messages, `\()` for one-line anon fns.
5. **Concurrency:** a parallel session edits this repo (esp. `metadata-import.R`, `build-workflow.R`,
   docs). **Stage only your own files** (`git add <path>`), never `git add -A`. Re-read a file before
   editing if it may have shifted.
6. **Commit style:** conventional (`fix:`/`refactor:`), body explains the failure mode, end with
   `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.
7. **Line numbers below are approximate** (files shifted during Tier-1) — grep/verify before editing.
8. When a fix needs a genuine domain decision (behavior change, abort-vs-warn), **ask** rather than assume.

## What's already done (committed on `development`)

Tier-1 + a feature, newest first:
`82af184` #14 qualifier-count copy-paste · `78127a3` #13 core-join `relationship=` ·
`583a082` #12 `diff(units=)`→seconds · `1234470` #11 pivot `values_fn` guard ·
`97ffc14` #10 `qc_type` warn · `b9ac46b` #9 `valid_analysis` typo guard ·
`c5e8f0c` #8 `na_strings` forwarding · `140cefb` #1–7 (calibration/ISTD guards) + out-of-cal-range feature.

**Still pending maintainer run:** `devtools::document()` (a new `@param with_conc_out_of_range` was added
to exported `get_qc_bias_variability()`), then `devtools::check()`. `man/get_qc_bias_variability.Rd` was
already regenerated once.

## Tier-2 (Required) worklist — tackle one at a time

**A. Length-zero / NA-condition `if` crashes** (R ≥ 4.3 errors on `&&`/`if` with length ≠ 1)
- `helper.R:~202` — `get_conc_unit`: `analyte_amount_unit == "pmol" && (...)` errors when concentration
  units aren't unique (fed `unique(...)`); it computes deduped `analyte_units` at ~193 then ignores it.
- `qc-filtering.R:~1405,1411,1421` — `if (!all(pass_istd == pass_istd_before))` is `NA` when `is_istd`
  is `NA` (incomplete feature metadata) → "missing value where TRUE/FALSE needed". Use `isTRUE(all(...))`.
- `metadata-import.R:~439-449, 1081, 1104, 1146, 1163, 1192` — `&` (non-short-circuit) with possibly-NULL
  attribute / `nrow(NULL)` → `logical(0)` → `if` error. Use `&&`. (⚠ parallel session edits this file.)
- `data-import.R:~1587` — `!is.null(x) & !is.na(x)`; `is.na(NULL)` is `logical(0)`. Use `&&`.
- `correct-isotope.R:~36-40, 76` — `NULL` `updated_feature_id` collapses through `ifelse` to
  `character(0)` then crashes the `if`. Handle `NULL` before `is.na`; use `||`.

**B. `1:n` / `1:nrow()` empty-input bugs** (iterate `c(1,0)` backwards when n = 0)
- `correct-isotope.R:~358` — `for (i in 1:nrow(features_to_correct))` crashes when no interferences.
  → `seq_len(nrow(...))`. (Same idiom: `correct-drift-batch.R:~57,77,1927`; `data-import.R:~934`
  `-1:-tail(...)` errors when `grep` returns `integer(0)`.)

**C. Defeated / wrong logic (mostly mechanical)**
- `metadata-import.R:~27` — `mutate(..., before = 1)` should be `.before = 1` (silently adds a `before`
  column, does not relocate). (⚠ parallel session.)
- `metadata-import.R:~432` — `arrange("Type","Table","Count")` sorts string constants (no-op) → bare names.
- `data-managment.R:~934` (`"featue_norm_intensity"`) and `data-import.R:~620`
  (`"feauture_norm_intensity"`) — typo'd column names defeat the "drop stale normalized data" guard.
  (NOTE: `data-managment.R` calc_cols already gained `feature_conc_out_of_range` in Tier-1; the typo
  was left intentionally for Tier-2.)
- `data-import.R:~1242-1249` — duplicate keys in default `column_mapping` (`qc_type`, `feature_height`)
  → `rename(!!!...)` duplicated names. Remove duplicates.
- `correct-drift-batch.R:~594-596` — `fun_smooth` only assigned in the `is.character(smooth_fun)` branch;
  passing a function (the documented contract) leaves it undefined. Add `else fun_smooth <- smooth_fun`.
- `calc-ref-normalization.R:~186,216,236-240,280,340` — `reference_sample_id` treated as scalar though
  documented "one or more"; use `%in%`, summarize without a per-row scalar column.
- `data-export.R:~87` — `str_detect(path, ".xlsx")` unanchored + `.` wildcard → `"\\.xlsx$"`.
- `correct-drift-batch.R:~1669` — batch-status text keyed off `var_drift_corrected[[variable]]` (should
  be `var_batch_corrected`) — message-only mislabel.

**D. Unguarded divisions → Inf/NaN silently propagated** (beyond Tier-1's #3/#4)
- `calc-istd-normalization.R:~297` (`* 1000 / molecular_weight`), `~374` (`/ sample_amount`, only NA
  guarded not 0); `calc-ref-normalization.R:~189,299`; `correct-drift-batch.R:~174,262,348` (`/ y_fit`)
  and kernel weight sums `~62,64,82` (sum 0 → NaN); `functions-math.R:~26,28,187` (`cv`, MAD z-score when
  mean/median/MAD = 0). `cv()`'s roxygen even *claims* it returns `NA_real_` on zero — either enforce or
  fix the doc.

**E. Silent `as.numeric` coercion → NA** with no reporting
- `data-import.R:~1477-1486`, `metadata-import.R:~1665,1908,1960`. A mistyped source cell becomes NA
  invisibly. Consider reporting coercion failures (or at least document intent).

## After Tier-2, remaining review buckets (see `code-review-2026-07.md`)
- **Tier-3 suggestions** (complexity/fragility: MassHunter positional parser, magic-cell version check,
  duplicated builders, shadowed `c`/`mad`, FP `!=`, hardcoded `qc_type=="SPL"`, `call.=` to cli_abort).
- **Monkey-fixes** — 2 flagged as likely real bugs: `correct-drift-batch.R:~1972` (Inf/NaN→NA batch
  centering) and `qc-filtering.R:~680` ("temp" calibration-join). Plus cosmetic ones.
- **Stale code** — 3 large commented-out functions (`data-import.R` `parse_mrmhub_result_wide`,
  `plots-qc-pca.R` `plot_pca_pairs`, `data-export.R` `save_summarizedexperiment`) + scaffolding.
- **Phase 3** — regression tests for the data-loss gaps (esp. `add_metadata` = zero direct tests;
  also #12 time-gap, #13 fan-out, #11 dup-key export, #9/#10 metadata validation).
- **Phase 4** — safe perf wins: O(n²) gaussian kernel (`correct-drift-batch.R:~57-84`), isotope
  full-dataset-copy loop (`correct-isotope.R:~356-364`), gate `polyroot` to quadratic rows
  (`calc-calibrations.R`, now range-aware).

## Verification recipe (copy/paste)
```bash
cd /Users/lsibjb/Documents/Code/MRMhub
air format R/<file>.R
RUN_VDIFFR=false Rscript -e 'suppressMessages(devtools::load_all(quiet=TRUE)); print(as.data.frame(suppressWarnings(suppressMessages(testthat::test_file("tests/testthat/test-<x>.R", reporter="silent", stop_on_failure=FALSE))))[c("test","failed","passed")])'
# full suite only when warranted:
RUN_VDIFFR=false Rscript -e 'devtools::test(stop_on_failure=FALSE)'; git checkout -- tests/testthat/_snaps
git add R/<file>.R && git commit -m "fix: ...\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```
