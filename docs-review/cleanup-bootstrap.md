# Bootstrap — remaining code-review cleanup items (new chat)

Paste into a new chat (or say: "Read docs-review/cleanup-bootstrap.md and start the cleanup work").

## STATUS — COMPLETE (2026-07-15)

All three items done; the audit's "Monkey-fixes" + stale-code bucket is closed.

1. **Calibration-join in `calc_qc_metrics`** — investigated, **not a live bug** (fragile-but-correct;
   verified empirically: no mis-map, no dropped/collided columns, one row/feature, symmetric
   missing-metrics branch). Replaced the `#TODOTODO` with an explanatory comment. Commit `20cb686`.
2. **Drift/batch debug output** — the only *active* debug line (`print(e$message)`) silenced, matching its
   siblings. Found + fixed a real adjacent bug: `fun_gauss.kernel.smooth()`'s error branch returned
   `y_adj` instead of `y_predicted`, dropping the `y_adj` column on all-error runs. Regression test added.
   Commit `8d7901c`.
3. **Old lipidomics parsing** — premise was wrong: nothing is unused (all reachable from the active
   `parse_lipid_feature_names()`). No functions removed; swept 22 lines of commented-out dead code + the
   obsolete rgoslin TODO. Commit `7bc46b5`.

Follow-up (same session): replaced brittle exact PDF-`file_size` string assertions
(`== "118K"` etc.) with the codebase's robust `size_kb ± tolerance` idiom across
`test-plot-runscatter.R`, `test-plot-qc-correlations.R`, `test-plots-calibcurves.R` — a maintainer plot
tweak had nudged the runscatter PDF 118.8→"119K", tripping the exact match.

Left as-is per scope: isotope full-copy perf loop; `save_summarizedexperiment()` skeleton.

---

_Original bootstrap (for history):_

## Context

Continuing the pragmatic, data-integrity-focused review of the `mrmhub` R package (repo root = package
root; branch `development`). Full audit: `docs-review/code-review-2026-07.md`. **All prior phases are DONE
and committed**: Tier-1, Tier-2, all Tier-3 larger refactors, dead-code cleanup, the two safe perf wins,
and **Phase 3 (regression tests)** — the latter tracked in the `project_test_coverage_phase3` memory
(commits `e0adeb3` → `d279ed6`, incl. three authorized production fixes: `parse_lipid_feature_names`
empty-input guard, I/O wide-pivot duplicate-key guard, `quantify_by_calibration` empty-input guard).

This task is the **final cleanup bucket** — the audit's "Monkey-fixes" table (§ ~191) and remaining
scaffolding (§ "Stale / dead code" ~209). It is a mix of one probable bug and some cosmetic cleanup.
It is **not** additive-tests-only: some items are production changes. Surface bugs and ASK before fixing
(don't silently "fix"); pair any behavioural fix with a regression test.

## Working rules (follow exactly)

1. **One item at a time.** Investigate → propose → **wait for the maintainer (Bo) to check** → make the
   change → show the diff → wait again → commit only when they say "commit"/"ok". Then next.
2. **Surface, don't silently fix.** If investigation confirms a bug, describe root cause + proposed fix and
   ASK. If an item turns out to be intentional / not-a-bug, say so and skip rather than churn.
3. **Never edit existing tests without explicit consent.** Adding a new `test_that()` block is fine.
4. **Builds:** `test()`, `document()`, `check()`. The maintainer prefers to run these — **don't run them
   automatically; ask and report back**. Lightweight `load_all()` / parsing / targeted `test_file()` for
   your own verification is fine. `test()` is slow (vdiffr) — always `RUN_VDIFFR=false`, and **after any
   full/vdiffr-off run: `git checkout -- tests/testthat/_snaps`** (pruning hazard). For shared/stateful
   paths (qc-filtering, calc-*, correct-*, metadata/data-import) run the **full suite** before calling
   verified:
   ```bash
   RUN_VDIFFR=false Rscript -e 'options(crayon.enabled=FALSE); res<-as.data.frame(suppressWarnings(suppressMessages(devtools::test(stop_on_failure=FALSE)))); cat(sprintf("FAILED:%d PASSED:%d\n", sum(res$failed), sum(res$passed))); print(res[res$failed>0,c("file","test","failed")])'
   git checkout -- tests/testthat/_snaps
   ```
5. **`air format <file>`** each touched file; if it reflows unrelated regions, restore and hand-apply only
   your hunk. Conventions: base pipe `|>`, `testthat` 3e, `cli::cli_abort/cli_warn`.
6. **Stage only your own files** (`git add <file>`), never `git add -A`. The maintainer edits files
   concurrently in the IDE (plots, vignettes, calc-calibrations) — **always check `git status` and stage
   only what you changed**; leave their WIP and generated `man/*.Rd` untouched. **Do not push/pull**
   (`origin/development` has diverged; maintainer reconciles).
7. **Commit style:** conventional (`fix:` / `refactor:` / `chore:`), body explains what/why, end with
   `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>` (keep the trailer WITH the email).

## The items (priority order)

1. **PROBABLE BUG — temp calibration-join in `calc_qc_metrics`** (`R/qc-filtering.R:~699`, the
   `#TODOTODO: IMPORTANT temp solution- align with response curve function/error checking`). A hand-rolled
   `left_join` of `metrics_calibration` into `metrics_qc` with `rename_with("_cal_1" -> "_cal")` /
   `"cal_cal" -> "cal"` string surgery and `select(-is_quantifier, -fit_cal)`. The audit flags it as
   diverging from the response-curve function's error/validation path — **investigate whether the rename
   surgery can mis-map or drop columns, and whether the missing-metrics branch matches the response-curve
   error checks.** Surface findings + ASK before changing. Pair any fix with a regression test.

2. **Scaffolding — debug output in drift/batch correction** (`R/correct-drift-batch.R`, ~4 spots:
   `txtProgressBar` / stray `print()`). Cosmetic console-noise removal; confirm none are load-bearing
   (some drift code is *active-but-unused* so removal can change console output slightly — verify against
   a real `correct_drift_*` run before/after).

3. **Old lipidomics parsing (active-but-unused)** (`R/lipidomics.R`). Lower priority; confirm truly unused
   (grep call sites) before removing, and that it isn't reachable via any exported path.

## Explicitly NOT in scope (leave as-is)

- **Isotope full-copy perf loop** (`correct-isotope.R`) — intentionally skipped: sequential/chained-
  correction dependency, negligible real-world cost, high rewrite risk.
- **`save_summarizedexperiment()`** — parked feature; skeleton kept in `data-export.R` (don't delete). See
  the `project_save_summarizedexperiment` memory.

## Technique that worked well (reuse it)

To prove a change is behaviour-preserving, A/B against `git show HEAD:R/<file>.R` sourced into
`new.env(parent = asNamespace("mrmhub"))` and compare outputs on a package fixture (`lipidomics_dataset`,
`quant_lcms_dataset`). For a suspected bug, build the smallest failing repro first, confirm it, then guard.
