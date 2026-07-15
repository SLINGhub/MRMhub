# Bootstrap — continue mrmhub code review at Tier-3 (suggestions)

Paste into a new chat (or say: "Read docs-review/tier3-bootstrap.md and continue Tier-3").

## Context

Pragmatic, data-integrity-focused review of the `mrmhub` R package (repo root = package root;
branch `development`). Full audit: `docs-review/code-review-2026-07.md` (§ "Tier 3 — Suggestions",
lines ~163-188). **Tier-1 (14 Blocking) DONE. Tier-2 (Groups A–E) DONE.** Tier-3 is *suggestions*:
complexity / fragility / footguns — none are silent-wrong-result bugs, so severity is lower and each
needs a judgment call on whether it's worth touching.

Line numbers below were **re-verified on `development`** as of this writing (they had drifted from the
original audit). Still **re-grep before editing** — a parallel chat also edits this repo.

## Working rules (follow exactly)

1. **One finding at a time.** investigate → apply fix → verify (tests) → show the diff →
   **wait for the maintainer (Bo) to check** → commit only when they say "commit"/"ok"/"all good". Then next.
   (For a batch of trivial one-liners the maintainer may say "do more at once" — still show diffs.)
2. **Never edit existing tests without explicit consent.** They are manually verified. Adding a *new*
   `test_that()` block is fine and encouraged for regressions.
3. **Builds permitted.** `test()`, `document()`, `check()`. `test()` is slow due to vdiffr — always
   `RUN_VDIFFR=false`, and **after any full/vdiffr-off run: `git checkout -- tests/testthat/_snaps`**
   (pruning hazard). For **shared/stateful paths** (metadata-import, data-import, calc-*, correct-*,
   qc-filtering, helper.R, functions-math.R) run the **full suite** before calling verified, not just
   the per-file test.
4. **`air format <file>`** each touched file — BUT some files carry heavy pre-existing air debt
   (`functions-math.R`, `test-correct-drift-batch.R`, …) and there is **no air check in CI**. If
   `air format` reflows large unrelated regions, **restore the file and re-apply only your change**
   (hand-write the edit air-clean). Keep the diff minimal. Conventions: base pipe `|>`,
   `cli::cli_abort/warn/inform`, `\()` one-line anon fns.
5. **Concurrency — IMPORTANT.** A parallel chat edits this repo and has, at least once, **committed the
   whole working tree** ("commit all"), sweeping in-progress work into commits. Consequences:
   - **Commit promptly** once the maintainer approves, so your uncommitted work isn't swept.
   - **Stage only your own files** (`git add <path>`), never `git add -A`.
   - Re-read a file before editing (line numbers are approximate — grep/verify).
   - `origin/development` and local `development` have **diverged**. **Do not push/pull** without the
     maintainer explicitly reconciling first.
6. **Commit style:** conventional (`fix:`/`refactor:`), body explains the failure mode / rationale, end with
   `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.
7. Tier-3 is judgment-heavy: several items may be intentional or not worth the churn. **Present a
   recommendation and ASK** rather than assume — especially for behavior-adjacent changes (hardcoded
   `SPL`, version validation, MassHunter parsing).

## Tier-3 status (verified, newest work last)

**Footgun batch DONE** (all 9, committed in the originating chat — see table below). The three larger
refactors remain and are the reason for this handoff doc.

### Footguns — small, low-risk (ALL DONE)

| Item | Current location | Resolution |
|---|---|---|
| `call. = FALSE` passed to `cli_abort`/cli (base `stop` arg, silently ignored) | `classes.R:166,173`; `data-managment.R:663` | ✅ `call = NULL` — `53e4794` |
| NA-unsafe `any()` in `if` | `data-import.R:666,670`; `data-managment.R:100` | ✅ `na.rm = TRUE` (real crash on NA feature_id/qc_type) — `fdc9be9` |
| param `c` shadows `base::c` | `calc-calibrations.R:139` | ✅ renamed `a/b/c` → `coef_a/coef_b/coef_c` — `c9163ef` |
| local `mad <- mad(x)` shadows `base::mad` | `functions-math.R:249` | ✅ `mad` → `mad_val` — `c9163ef` |
| blanket `suppressWarnings(lm(...))` "hides" rank-deficiency | `calc-calibrations.R:407` | ✅ leave + comment — outcome already surfaced via `reg_failed` (NA coefs) — `c0f78ac` |
| FP `!=` to detect "was corrected" (noise/NA → false positives) | `correct-isotope.R:377` | ✅ membership `feature_id %in% features_to_correct$feature_id` (+repro shown) — `4ddd06a` |
| `get(operator)` vs safer `match.fun` | `helper.R:101` | ✅ `match.fun(operator)` — `c9163ef` |
| `order_chained_columns_tbl` drops dup keys via `setNames` | `helper.R:302` | ✅ fail-loud guard on duplicate `from_col` +regression test (not reachable via sole caller, but future-proofed) — `ae34457` |
| hardcoded `qc_type == "SPL"` while `ref_qc_types` is configurable | `correct-drift-batch.R:737,738,914,915,980,993,1843,1844` | ✅ **leave as-is — NOT a bug**: SPL is the canonical/default study-sample label (`metadata-import.R:1237,1719`); all 8 sites are *assessment* metrics that must NOT use `ref_qc_types` (the fitting set) per Broadhurst. Consistent with package-wide `_spl` idiom. |

<details><summary>Original footgun table (pre-resolution, for reference)</summary>

| Item | Current location | Notes |
|---|---|---|
| `call. = FALSE` passed to `cli_abort`/cli (base `stop` arg, silently ignored) | `classes.R:166,173`; `data-managment.R:663` | replace with `call = NULL` (or drop) |
| NA-unsafe `any()` in `if` | `data-import.R:670` (`any(...$integration_qualifier)`); `data-managment.R:100` (`any(str_detect(qc_type, …))`) | add `na.rm = TRUE` / drop NA — **closer to a real bug** (NA in `if` → error) |
| param `c` shadows `base::c` | `calc-calibrations.R:139` (`function(a, b, c, x, lo, hi)`) | rename param (e.g. `cc`/`coef_c`) |
| local `mad <- mad(x)` shadows `base::mad` | `functions-math.R:249` | rename local (e.g. `mad_val`, as siblings already do at 163/193) |
| blanket `suppressWarnings(lm(...))` hides rank-deficiency | `calc-calibrations.R:407` | scope/inspect; surface rank-deficient fits |
| FP `!=` to detect "was corrected" (noise/NA → false positives) | `correct-isotope.R:377` (`interference_corrected = feature_intensity != …`) | **closer to a real bug** — use tolerance or an explicit flag |
| hardcoded `qc_type == "SPL"` while `ref_qc_types` is configurable | `correct-drift-batch.R:737,738,914,915,980,993,1843,1844` | behavior-adjacent — **ASK** before changing CV-basis semantics |
| `get(operator)` vs safer `match.fun` | `helper.R:101` | `match.fun(operator)` |
| `order_chained_columns_tbl` drops dup keys via `setNames` | `helper.R:302` | dedupe/validate keys (cf. Tier-2 `339d0fb` did this for `column_mapping`) |

</details>

### Larger refactors — higher effort / behavior-adjacent (this handoff's target)

1. **MassHunter parser positional fragility** — `data-import.R:729-840` (`parse_masshunter_csv`, ~380 lines).
   Drives off hardcoded rows/cols: `datWide[2, ]`, `datWide[[1, 1]]`, `select(-where(~ .x[2] == ""))`
   (errors on `NA` 2nd cell). Any export-layout shift silently mis-parses. Harden with name-based lookup +
   NA-safe predicates. **Biggest / riskiest item** — this importer has fixture tests; run the full suite.
2. **Version validation by magic cell + regex** — `metadata-import.R:1285-1294`: reads version from fixed
   `d_about[[3, 3]]`, strips the 2nd dot with `str_replace("(\\.[^.]*)\\.", "\\1")` to force numeric
   (`"1.9.2"` → `"1.92"`), then `as.numeric` + `is.na` check. Magic bounds referenced in error text
   (`v0.2`) may contradict documented required versions — reconcile with the actual template spec.
3. **Duplicated builders / blocks** — `calc-calibrations.R:436-503` (four ~15-field `coef_c` result lists
   differing only in one field), `correct-drift-batch.R` (five hardcoded QC-type blocks in the out-of-span
   report ~941-1004 region; other `qc_type`s silently dropped), `qc-filtering.R` (nine near-identical
   reconciliation branches ~1345-1429,1552-1584). High drift risk; a single builder / loop over
   `unique(qc_type)` removes it. **Watch the "silently dropped qc_type" behavior — may be a latent bug.**

## Verification recipe
```bash
cd /Users/lsibjb/Documents/Code/MRMhub
air format R/<file>.R    # if it reflows unrelated regions, restore + re-apply your change only
RUN_VDIFFR=false Rscript -e 'options(crayon.enabled=FALSE); res<-as.data.frame(suppressWarnings(suppressMessages(devtools::test(stop_on_failure=FALSE)))); cat(sprintf("failed:%d passed:%d\n", sum(res$failed), sum(res$passed))); print(res[res$failed>0,c("file","test","failed")])'
git checkout -- tests/testthat/_snaps      # ALWAYS after a full/vdiffr-off run
git add R/<file>.R && git commit           # only your files; conventional msg + Co-Authored-By trailer
```

## After Tier-3 (see code-review-2026-07.md)
Monkey-fixes (§ ~191-205; several already done in Tier-2, e.g. `correct-drift-batch.R:1972` batch
centering = `6aedde2`/`6eb5548`); stale/dead code (§ ~209-227: 3 large commented-out fns +
scaffolding); Phase-3 regression tests (§ ~253); Phase-4 perf (§ ~231: O(n²) gaussian kernel — note the
`sum(wt)==0` guard already landed in `05ac5c7`; isotope full-copy loop; gate `polyroot` to quadratic rows).
