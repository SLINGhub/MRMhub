# Bootstrap — continue mrmhub code review at Tier-2 Group D (divisions)

Paste into a new chat (or say: "Read docs-review/tier2-groupD-bootstrap.md and continue Group D").

## Context

Pragmatic, data-integrity-focused review of the `mrmhub` R package (repo root = package root;
branch `development`). Full audit: `docs-review/code-review-2026-07.md`. Tier-1 (14 Blocking) DONE.
Tier-2 **Groups A, B, C are DONE and committed**; **Group D is in progress** (first item `cv()` done),
Group E not started. See `docs-review/tier2-bootstrap.md` for the original full Tier-2 worklist.

## Working rules (follow exactly)

1. **One finding at a time.** investigate → apply fix → verify (tests) → show the diff →
   **wait for the maintainer (Bo) to check** → commit only when they say "commit"/"ok"/"all good". Then next.
2. **Never edit existing tests without explicit consent.** They are manually verified. If a fix breaks a
   passing test, **stop and surface it** (show failure + reasoning); do not "fix" the test. Adding a *new*
   `test_that()` block is fine and encouraged for regressions.
3. **Builds permitted.** `test()`, `document()`, `check()`. `test()` is slow due to vdiffr — always
   `RUN_VDIFFR=false`, and **after any full/vdiffr-off run: `git checkout -- tests/testthat/_snaps`**
   (pruning hazard). Per-file recipe:
   `RUN_VDIFFR=false Rscript -e 'suppressMessages(devtools::load_all(quiet=TRUE)); print(as.data.frame(suppressWarnings(suppressMessages(testthat::test_file("tests/testthat/test-<x>.R", reporter="silent", stop_on_failure=FALSE))))[c("test","failed","passed")])'`
   For **shared/stateful paths** (metadata-import, data-import, calc-*, correct-*) run the **full suite**
   before calling verified — a Group-A fix passed per-file but broke two other files' tests (only the full
   suite caught it).
4. **`air format <file>`** each touched file — BUT some files carry heavy pre-existing air debt
   (e.g. `functions-math.R`) and there is **no air check in CI**. If `air format` reflows large unrelated
   regions, **restore the file and re-apply only your change** (your edit is usually already air-clean); keep
   the diff minimal. Conventions: base pipe `|>`, `cli::cli_abort/warn/inform`, `\()` one-line anon fns.
5. **Concurrency — IMPORTANT.** A parallel chat edits this repo and has, at least once, **committed the
   whole working tree** ("commit all"), sweeping in-progress work into commits. Consequences:
   - **Commit promptly** once the maintainer approves, so your uncommitted work isn't swept by the other chat.
   - **Stage only your own files** (`git add <path>`), never `git add -A`.
   - Re-read a file before editing (line numbers below are approximate — grep/verify).
   - `origin/development` and local `development` have **diverged** (origin +14 / local +61 as of this
     writing). **Do not push/pull** without the maintainer explicitly reconciling first.
6. **Commit style:** conventional (`fix:`/`refactor:`), body explains the failure mode, end with
   `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.
7. When a fix needs a genuine domain decision (behavior change, abort-vs-warn, enforce-vs-document),
   **ask** rather than assume. Group D is judgment-heavy: several divisions may be intentional or already
   guarded upstream — investigate before "fixing".

## Done so far on `development` (Tier-2, newest last)

A (length-0/NA `if`): `68844e7` get_conc_unit · `c0c3186` qc-filtering isTRUE(all) · `1063561` add_metadata
NULL guards · `deb4155`→`35cfe68` print_assertion_summary (deb4155 was a WRONG call — read arg instead of
the intentionally-persisted `excl_unmatched_analyses` attribute — 35cfe68 corrected it to `isTRUE(attr(...))`)
· `f31d87c` analysis_id_col · `a7f9724` updated_feature_id NULL collapse.
B (`1:n`/`1:nrow` empty-input): `2e725bc` isotope loop · `bf2fd5c` drift/batch seq_len · `59c826f` MassHunter
transition cols via `grep(value=TRUE)`.
C (defeated/wrong logic): `f089dda` `.before=1` · `798b52d` severity-ordered summary · `9b707eb`
feature_norm_intensity typos · `339d0fb` dup column_mapping keys · `a7ae7e9` smooth_fun function-passing ·
`14a7498` multi reference_sample_id (+regression test) · `c40002a` `\\.xlsx$` anchor · `9e622f2` dead
drift/batch status text.
D (started): **`534f753` `cv()` returns NA on zero/NA denominator + non-numeric (enforced; +test)** — was
committed by the parallel chat but content is exactly the intended minimal diff.

`devtools::check()` after Groups B+C: **0 errors, 0 warnings, 2 NOTEs** (both environmental/pre-existing:
"non-portable file paths" for long testdata filenames; "future file timestamps — unable to verify current
time"). `document()` is in sync (man/calibrate_by_reference.Rd, man/cv.Rd regenerated).

## Group D — remaining (unguarded divisions → Inf/NaN). One at a time; ASK on judgment calls.

- `calc-istd-normalization.R:~297` (`* 1000 / molecular_weight`) — molecular_weight 0/NA → Inf/NaN conc.
- `calc-istd-normalization.R:~374` (`/ sample_amount`) — only NA guarded, **not 0**.
- `calc-ref-normalization.R:~189,299` — reference/calibration divisions (note: this file was just changed by
  `14a7498`; **re-grep**). `~189` is the `var_normalized = value / summarize_fun(reference values)` divide.
- `correct-drift-batch.R:~174,262,348` (`/ y_fit`) — y_fit 0 → Inf. And **kernel weight sums** in
  `fun_gauss.kernel.smooth` (`~62,64,82` region, now shifted by seq_len edits): `sum(wt*..)/sum(wt)` → NaN
  when `sum(wt)=0`. This is also the O(n²) kernel flagged for Phase-4 perf.
- `functions-math.R` — **`cv()` DONE** (`534f753`). MAD z-score / `get_outlier_bounds` `z_robust` already
  guards `if (mad_val == 0) return(range(x))`; `z_normal`/`sd`/`mad` methods are additive (mu ± k·sd), no
  division — **verify these are already safe, likely nothing to do**.

Recurring decision for each: **abort** (bad metadata the user must fix, e.g. molecular_weight/sample_amount),
vs **NA + warn** (degenerate but tolerable, e.g. kernel sum 0), vs **leave** (already handled / intended).
The maintainer chose *enforce NA_real_* for cv(); expect similar case-by-case calls. Present a recommendation.

## Group E — silent `as.numeric` coercion → NA (not started)

- `data-import.R:~1477-1486`, `metadata-import.R:~1665,1908,1960` — a mistyped source cell becomes NA
  invisibly. Consider reporting coercion failures (count + which column), or at least documenting intent.
  ⚠ metadata-import.R is a parallel-session hotspot — re-read before editing.

## After Tier-2 (see code-review-2026-07.md)
Tier-3 suggestions; monkey-fixes (`correct-drift-batch.R` Inf/NaN→NA batch centering `~1972`;
`qc-filtering.R:~680` "temp" calibration-join); stale code (3 large commented-out fns); Phase-3 regression
tests; Phase-4 perf (O(n²) gaussian kernel, isotope full-copy loop, gate polyroot to quadratic rows).

## Verification recipe
```bash
cd /Users/lsibjb/Documents/Code/MRMhub
air format R/<file>.R    # if it reflows unrelated regions, restore + re-apply your change only
RUN_VDIFFR=false Rscript -e 'options(crayon.enabled=FALSE); res<-as.data.frame(devtools::test(stop_on_failure=FALSE)); cat(sprintf("failed:%d passed:%d\n", sum(res$failed), sum(res$passed))); print(res[res$failed>0,c("file","test","failed")])'
git checkout -- tests/testthat/_snaps      # ALWAYS after a full/vdiffr-off run
git add R/<file>.R && git commit           # only your files; conventional msg + Co-Authored-By trailer
```
