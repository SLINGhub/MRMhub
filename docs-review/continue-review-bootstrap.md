# Bootstrap — continue mrmhub code review (post Tier-2)

Paste into a new chat (or say: "Read docs-review/continue-review-bootstrap.md and continue the review").

## Context

Pragmatic, data-integrity-focused review of the `mrmhub` R package (repo root = package root;
branch `development`). Full audit: `docs-review/code-review-2026-07.md`.

**Tier-1 (14 Blocking) DONE. Tier-2 (Groups A–E) DONE. Monkey-fix #1 (batch-centering) DONE.**
Remaining: monkey-fix #2, perf wins, stale-code deletion, regression tests (see **Next steps**).

## Working rules (follow exactly)

1. **One finding at a time.** investigate → apply fix → verify (tests) → show the diff →
   **wait for the maintainer (Bo) to check** → commit only when they say so. Batching multiple items
   in one turn is fine **when no clarification is needed**; otherwise ask. Group D/E-style judgment
   calls (abort vs NA+warn vs leave) → **present a recommendation and ASK**.
2. **Never edit existing tests without explicit consent.** They are manually verified. If a fix breaks
   a passing test, **stop and surface it**; do not "fix" the test. Adding a *new* `test_that()` block is
   fine and encouraged for regressions (prefer `expect_snapshot()` for new warning/error tests).
3. **Builds permitted.** `test()`, `document()`, `check()`. `test()` is slow due to vdiffr — always
   `RUN_VDIFFR=false`, and **after any full/vdiffr-off run: `git checkout -- tests/testthat/_snaps`**
   (pruning hazard). For **shared/stateful paths** (metadata-import, data-import, calc-*, correct-*,
   qc-filtering) run the **full suite** before calling verified, not just the per-file test.
4. **`air format <file>`** each touched file — BUT some files carry heavy pre-existing air debt. If
   `air format` reflows large unrelated regions, **restore the file and re-apply only your change**;
   keep the diff minimal. Conventions: base pipe `|>`, `cli::cli_abort/warn/inform`, `\()` anon fns.
5. **Concurrency / remote.** The parallel chat is **CLOSED**. `origin/development` and local
   `development` were **IN SYNC** as of the last push (`6eb5548`). Still: **stage only your own files**
   (`git add <path>`, never `-A`); **commit promptly** once approved. Pushing is now allowed (the
   maintainer reconciled the histories); before a push, `git fetch` + check
   `git rev-list --left-right --count origin/development...development` and fast-forward only.
   Re-read a file before editing (line numbers below are approximate — grep/verify).
6. **Commit style:** conventional (`fix:`/`refactor:`/`test:`), body explains the failure mode, end with
   `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.

## Done so far (newest last)

- **Tier-1 (14 Blocking):** all resolved earlier — see git history + `code-review-2026-07.md`.
- **Tier-2 A** (length-0/NA `if`), **B** (`1:n`/`1:nrow` empty), **C** (defeated/wrong logic): committed
  earlier (see the archived `docs-review/tier2-bootstrap.md` for the per-commit list).
- **Tier-2 D** (unguarded divisions → Inf/NaN):
  - `534f753` `cv()` → NA on zero/NA/non-numeric denominator (+test).
  - `2f62908` abort on zero/negative ISTD molecular weight (`quantify_by_istd`).
  - `87ce8a7` guard non-positive `sample_amount` — folded into the missing-amount check (warn+NA under
    `ignore_missing_annotation`, else abort) + coerce `<= 0` → NA at the divide.
  - `5253b11` `calibrate_by_reference`: NA + warn on zero/empty/non-finite reference divisor
    (`var_normalized` and `feature_conc_ratio`).
  - `51e85a2` drift correction: guard `y_fit == 0` → NA in the ratio-scale (non-log) branch of
    loess/cspline/gam.
  - Verified safe / **no change**: `functions-math.R` z-score methods (`z_robust` already guards
    `mad_val==0`; others additive). **Deliberately LEFT:** the O(n²) gaussian-kernel `sum(wt)==0` → NaN
    (address in the Phase-4 kernel rewrite — see Next steps #2).
- **Tier-2 E** (silent `as.numeric`/`as.integer`/`as.logical` coercion → NA):
  - `cb18b09` added internal `coerce_checked()` (numeric/integer; warns on non-blank parse failures;
    preserves precision of already-numeric input) and `coerce_logical_checked()` (broadens accepted
    boolean tokens to `yes/no·y/n·1/0·true/false`, warns on the rest) in `R/utils.R`; routed the
    user-facing sites in `data-import.R` + `metadata-import.R`; added `tests/testthat/test-utils.R`
    (8 blocks). The intentional internal version parse (`metadata-import.R:~1287`) left untouched.
    Both helpers are `@noRd`/internal → **no `document()` needed**.
- **Monkey-fix #1:** `6eb5548` guard zero/non-finite batch-centering divisors (`xloc` in the
  location-only linear branch; `sca.batch[b]` MAD in the scale branch) → NA; mirrored the Inf/NaN
  input-cleaning into the location-only branch; resolved the `# TODO: confirm if this is ok` at
  `correct-drift-batch.R:~1984`. Default paths (log-space, `correct_scale=FALSE`) are byte-identical.
- **Merge:** `fcc31ba` merged origin's INTEGRATOR GUI/Rust work (`integrator_w_gui/`, disjoint from R).

Full suite after Group E + monkey-fix #1: **FAIL 0 | PASS 1772** (`RUN_VDIFFR=false`). A fresh
`devtools::check()` before the next release is advisable (last known: 0 errors / 0 warnings / 2
environmental NOTEs — non-portable long testdata paths; future file timestamps).

⚠ **Repo hygiene (origin-side, not yet addressed):** the merged INTEGRATOR commits checked **build
artifacts** into git — `integrator_w_gui/gui/src-tauri/target/`, a ~10 MB `.exe`, a ~5 MB `.pdb`.
`.gitignore` now ignores `target/` going forward, but the already-tracked binaries persist until
`git rm --cached`'d. Flag to the maintainer; not part of the code review.

## Next steps (one at a time; ASK on judgment calls)

1. **Monkey-fix #2 — `qc-filtering.R:~680`** `#TODOTODO: IMPORTANT temp solution- align with response
   curve` around the calibration-join. Flagged **likely a bug**: the temp calibration-join logic
   diverges from the response-curve error checking. Investigate against the response-curve path,
   present findings + a recommendation before changing logic.

2. **Perf wins** (behavior-preserving; verify **numerically-identical** output + **unchanged** vdiffr
   snapshots on a fixture):
   - **O(n²) gaussian-kernel smoother** — `correct-drift-batch.R:~57-65,77-84`: nested `for (i in ...)`
     recomputes a full-length `dnorm` weight vector per point, **twice**. → single `outer()`/matrix
     `dnorm` pass. **Address the left-over `sum(wt)==0` → NaN guard (Tier-2 D) here at the same time.**
   - **Isotope full-dataset-copy loop** — `correct-isotope.R:~356-364`: per-corrected-feature loop
     re-groups + copies the whole long table each iteration. → single grouped pass. (Also fix the
     `for (i in 1:nrow(...))` empty-input bug there → `seq_len`.)
   - **`polyroot` over all rows** — `calc-calibrations.R:~117-145`: `case_when` eagerly evaluates the
     row-wise `pmap_dbl(polyroot)` branch for **every** row. → run only on `fit_model == "quadratic"`.

3. **Stale-code deletion** (mechanical — do **last / in a separate commit** to keep review diffs clean;
   all git-recoverable). Large commented-out functions: `data-import.R:~1824-1897`
   (`parse_mrmhub_result_wide`, 74 lines), `plots-qc-pca.R:~724-877` (`plot_pca_pairs`, 154 lines),
   `data-export.R:~705-714` (`save_summarizedexperiment` skeleton); plus the scaffolding/debug leftovers
   enumerated under "Stale / dead code" in `code-review-2026-07.md`.

4. **Regression tests** (Phase 3 — **ADD only**, never edit verified tests): `add_metadata` (zero direct
   tests — dup metadata keys → error; missing keys → documented drop + warning; `NA valid_*`);
   zero-denominator paths (ISTD area 0, calibration slope 0, empty reference set); empty / zero-row
   inputs into `normalize_by_istd` / `calc_qc_metrics` / `quantify_by_calibration`; `qc_type` outside
   `qc_type_levels`; export `pivot_wider` with duplicate keys.

## Verification recipe
```bash
cd /Users/lsibjb/Documents/Code/MRMhub
air format R/<file>.R    # if it reflows unrelated regions, restore + re-apply your change only
RUN_VDIFFR=false Rscript -e 'options(crayon.enabled=FALSE); res<-as.data.frame(devtools::test(stop_on_failure=FALSE)); cat(sprintf("failed:%d passed:%d\n", sum(res$failed), sum(res$passed))); print(res[res$failed>0,c("file","test","failed")])'
git checkout -- tests/testthat/_snaps      # ALWAYS after a full/vdiffr-off run
git add R/<file>.R && git commit           # only your files; conventional msg + Co-Authored-By trailer
```
