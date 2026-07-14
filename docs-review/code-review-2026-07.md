# mrmhub code review — 2026-07

**Scope:** whole-package audit of the `mrmhub` R sources (~25.5k lines, `R/*.R`), focused on
robustness, silent data errors / data loss, memory & performance, overcomplicated/fragile lines,
monkey-fixes, and stale code. Produced by a structured multi-agent review (critical-code-reviewer
lens + Posit R skills).

**Every fix below is a proposal, gated on maintainer consent.** Existing tests are never edited.

### Fixes applied so far (2026-07-14, maintainer-approved, walkthrough)

| Finding | File | Change | Verification |
|---------|------|--------|--------------|
| #5 | `data-import.R:1641/1647/1653` | `any_of(names(c(...)))` → `any_of(c(...))` | applied |
| #6 | `metadata-import.R:858` | `is_uniq("...")` → `is_uniq(.data$quant_istd_feature_id)` | applied |
| #7 | `data-managment.R:839` | 2nd reset block now targets `var_batch_corrected` | applied |
| #1/#2 | `calc-calibrations.R` | range-aware quadratic root; `c==0`→linear; complex→NA; NA+warn | fixture: test values 101.4036661 / 42.2 / 101.4981448 all **MATCH** |
| #4 | `calc-calibrations.R:120` | linear branch guards `coef_b_cal_1 == 0`/NA → NA | applied |
| #3 | `calc-istd-normalization.R:99` | single-value divisor + zero-ISTD guard (NA+warn) + **abort** if >1 ISTD row per group (loud on the should-never-happen case, not silent-first-pick) | fixture: old vs new NA pattern **identical** (45=45), no finite value changed; abort verified to fire only on an injected duplicate ISTD row, never on valid data |

**Out-of-calibration-range tracking (feature, maintainer-approved):**
- `quantify_by_calibration()` now uses the calibrated range to **select** the physical quadratic root
  (not to gate) — all prior concentrations preserved — and records a per-value logical
  **`feature_conc_out_of_range`** column (kept only when external calibration ran).
- Forwarded (optional, only when calibration applied): `calc_qc_metrics()` adds
  `conc_out_of_range_prop_spl` to `metrics_qc` (→ xlsx `Feature_QC_metrics` sheet,
  `save_feature_qc_metrics()`); `get_qc_bias_variability(with_conc_out_of_range = TRUE)` adds
  `frac_conc_out_of_range`. Added the flag to the two `select(-any_of(...))` lifecycle drop-lists.
- `get_qc_bias_variability(with_conc_out_of_range = TRUE)` **by default** (maintainer choice). Only
  two verified `names()` assertions were updated (with consent) to include `frac_conc_out_of_range`
  ([test-calc-calibrations.R:290, 315](../tests/testthat/test-calc-calibrations.R)) — no logic/value
  change.
- Verified: full suite **`FAIL 0 | WARN 0 | SKIP 101 | PASS 1744`**; the conditional `metrics_qc`
  column leaves non-calibrated schema unchanged, so no other verified test needed editing.

**Pending maintainer run:** `devtools::document()` (new `@param with_conc_out_of_range` on the exported
`get_qc_bias_variability()`), then `devtools::check()`. `air format` already applied to touched files.

**Session note:** HEAD advanced during this work (a parallel session committed docs/tests/roxygen and
`.Rbuildignore`'d `docs-review/`). The `#6` fix landed in HEAD via that parallel work. All other fixes
here are uncommitted in the working tree. Coordinate the `document()` run to avoid clobbering the
parallel session's roxygen regen.

> **Reading notes.** Line numbers are from the working tree at review time and may have shifted —
> verify each before acting. Findings quote the offending line so they can be relocated by search.
> Severity: **Blocking** = silent wrong results / data corruption; **Required** = crash on realistic
> (non-default) input, or defeated validation; **Suggestion** = fragility / complexity / footgun.
> A handful are marked **Verify** where the reviewer couldn't confirm intent.

---

## Summary (BLUF)

The package is well-architected: one S4 container, disciplined `mexp -> mexp` transforms, 463 tests
with genuinely good corrupt-file / duplicate-key import coverage. The problem is **not** structure —
it's a cluster of **silent-correctness defects** in the numeric core: a few produce wrong
concentrations with no error, and several "validations" are permanent no-ops (they check a string
literal, or select zero columns) so they protect nothing. These are cheap to fix and high-value.

The three highest-impact items to look at first, all silent:
1. Quadratic calibration picks an arbitrary root and keeps the real part even of complex roots
   (`calc-calibrations.R:147`) — wrong concentrations for every quadratic feature.
2. The quadratic degeneracy guard checks the wrong coefficient (`calc-calibrations.R:132`).
3. Two "guards" are no-ops: metadata type-coercion selects zero columns
   (`data-import.R:1641/1647/1653`) and the ISTD-uniqueness assertion tests a string literal
   (`metadata-import.R:860`).

Performance: three localized, behavior-preserving wins exist (O(n²) drift kernel, per-feature
full-dataset copy in isotope correction, `polyroot` over all rows). Memory: the object holds three
full long tibbles plus ~24 postfix columns — noted, but structural, so out of scope for now.

**Verdict: Request Changes** (on the Blocking + Required tiers). Complexity items are advisory.

---

## Tier 1 — Blocking: silent wrong results / data loss

| # | Location | Defect | Failure scenario | Suggested fix |
|---|----------|--------|------------------|---------------|
| 1 | `calc-calibrations.R:147` | Quadratic back-calc returns `Re(root[1])` blindly — always the first of two roots, keeps real part even when both roots are complex | Any `fit_model == "quadratic"` feature: concentration silently wrong / physically meaningless, no flag | Compute both roots, drop those with non-negligible `Im()`, pick the real root within `[lowest_cal, highest_cal]`; `NA` + warn if none |
| 2 | `calc-calibrations.R:132` | Degeneracy guard checks intercept `a == 0` instead of the quadratic coefficient `c == 0` | A quadratic fit with intercept ≈ 0 wrongly returns `NA`; a `c == 0` (actually linear) fit slips into a degenerate `polyroot` | Guard `c == 0`, not `a == 0` |
| 3 | `calc-istd-normalization.R:99` | `feature_intensity / feature_intensity[is_istd]` assumes exactly one ISTD row per `(istd_feature_id, analysis_id)` group; no div-by-zero guard | 2 ISTD rows → length-2 divisor recycled (garbled); 0 rows → `numeric(0)`; ISTD area 0 → `Inf` | Reduce divisor to one value (`[which(is_istd)[1]]`), error if count ≠ 1, guard 0 |
| 4 | `calc-calibrations.R:120-121` | Linear back-calc `(y - a)/b` has no `b == 0` guard (quadratic branch guards its lead term, linear does not) | Flat/failed calibration with slope 0 → `Inf` concentrations | Guard `b == 0` → `NA` + warn |
| 5 | `data-import.R:1641,1647,1653` | `any_of(names(c("qc_type","batch_id")))` — `names()` of an unnamed vector is `NULL`, so `any_of(NULL)` selects **zero** columns; all three metadata type-coercion `across()` blocks are no-ops | Wide-CSV import: `batch_id` stays numeric, `is_quantifier` stays text `"TRUE"`, `analysis_order` uncoerced | Drop `names()`: `any_of(c("qc_type","batch_id"))` etc. |
| 6 | `metadata-import.R:860` | `all(assertr::is_uniq("quant_istd_feature_id"))` runs on the string literal, not the column → permanently `TRUE` (cf. correct `.data$analysis_id` at :907) | ISTD table with a duplicated `quant_istd_feature_id` passes validation silently | `all(assertr::is_uniq(.data$quant_istd_feature_id))` |
| 7 | `data-managment.R:839-843` | Copy-paste: `var_drift_corrected` is reset twice; the second block should reset `var_batch_corrected`, which is therefore **never** reset by `link_data_metadata()` | Exclude an analysis after batch correction → `var_batch_corrected` still reports `TRUE` on re-linked-from-raw data | Change 2nd assignment LHS to `data@var_batch_corrected` |
| 8 | `data-import.R` (`import_data_main`, formal ~:547, `args` ~:570) | User-supplied `na_strings` is declared but never forwarded into `args`, so the parser uses its default `"NA"` | `import_data_csv_wide(..., na_strings = c("ND","n.d."))` — those strings stay as data, not `NA` | Forward `na_strings` into `args` (or let it flow via `...`) |
| 9 | `metadata-import.R:1669-1684` | `valid_analysis` tokens that don't match the yes/no lookup → `NA`; an **all-NA** column is then coerced to all-`TRUE` | A `Valid_Analysis` column entirely of typos silently marks every analysis valid | Reject unknown tokens (`cli_abort` listing them) instead of the all-TRUE fallback |
| 10 | `metadata-import.R:1673-1677` | `qc_type` is never validated against `qc_type_levels`; unknown values pass through | Downstream `factor(qc_type)` (`qc-filtering.R:298`) / `fct_*` in plots silently drop unknown QC types to `NA` — samples vanish from QC logic | Validate `qc_type %in% qc_type_levels`, error on unknowns |
| 11 | `data-export.R:586`, `:133-230`; `data-mztab.R` | `pivot_wider` called with no `values_fn` | Duplicate keys silently produce **list-columns** in the exported report | Add `values_fn` (or assert no duplicate keys before pivot) |
| 12 | `data-managment.R:333,394` | `diff(<POSIXct>, units = "secs")` — `units=` is ignored by `difftime`; units auto-chosen by magnitude, then compared as if seconds | ~2-min spacing renders as "mins"; `> break*60` compares a minutes number → break miscount / wrong analysis order segmentation | `as.numeric(diff(x), units = "secs")` |
| 13 | `data-managment.R:779-787` | Core join: `inner_join(annot_*)` then `filter(valid_*)`. Raw keys absent from metadata are **silently dropped** from `dataset`; duplicate metadata keys **fan out** rows (no `relationship=` guard anywhere); `NA` in `valid_*` drops the row | Feature/analysis present in data but not metadata disappears; duplicate `feature_id` in `annot_features` multiplies every data row | Add `relationship = "many-to-one"`; count + warn on dropped raw keys; handle `NA` valid_* explicitly |
| 14 | `calc-calibrations.R:182-183` (also `:577-578`, `data-import.R:664`) | Copy-paste: qualifier pass/count computed from the **quantifier** mask (`[is_quantifier]` / `[!integration_qualifier]` used for both terms) | Any run with failing qualifiers reports the quantifier count as the qualifier count in user-facing messages | Index the complement (`[!is_quantifier]` / `[integration_qualifier]`) |

---

## Tier 2 — Required: crashes on realistic input, or defeated logic

**Length-zero / `NA`-condition `if` crashes** (R ≥ 4.3 errors on `&&`/`if` with length ≠ 1):
- `helper.R:202` — `analyte_amount_unit == "pmol" && (...)` errors when concentration units aren't
  unique (`get_conc_unit` is fed `unique(...)`, which can be length > 1). It even computes
  `analyte_units` (deduped) at :193 then ignores it. → compare the deduped scalar.
- `qc-filtering.R:1405,1411,1421` — `if (!all(pass_istd == pass_istd_before))` is `NA` when
  `is_istd` is `NA` (incomplete feature metadata) → "missing value where TRUE/FALSE needed" on the
  incremental-filter path. → `isTRUE(all(...))`.
- `metadata-import.R:439-449, 1081, 1104, 1146, 1163, 1192` — `&` (non-short-circuit) with a
  possibly-`NULL` attribute / `nrow(NULL)` → `logical(0)` → `if` error. `add_metadata()` is exported
  and callable with a partial list. → use `&&`.
- `data-import.R:1587` — `!is.null(x) & !is.na(x)`; `is.na(NULL)` is `logical(0)`. → `&&`.
- `correct-isotope.R:36-40, 76` — `NULL` `updated_feature_id` collapses through `ifelse` to
  `character(0)` then crashes the `if` at :76. → handle `NULL` before `is.na`, use `||`.

**`1:n` / `1:nrow()` empty-input bugs** (iterate `c(1,0)` backwards when n = 0):
- `correct-isotope.R:358` — `for (i in 1:nrow(features_to_correct))` crashes when no interferences
  are annotated. → `seq_len(nrow(...))`. (Same idiom throughout `correct-drift-batch.R:57,77,1927,…`
  and `data-import.R:934` `-1:-tail(...)` which errors when `grep` returns `integer(0)`.)

**Defeated / wrong logic:**
- `metadata-import.R:27` — `mutate(analysis_order = row_number(), before = 1)` — `before` is not an
  arg (`.before`), so it silently adds a literal `before` column and does **not** relocate. → `.before = 1`.
- `metadata-import.R:432` — `arrange("Type","Table","Count")` sorts by string constants (no-op). → bare names.
- `data-managment.R:933` (`"featue_norm_intensity"`) and `data-import.R:620` (`"feauture_norm_intensity"`)
  — typo'd column names defeat the "drop stale normalized data" guard. → fix spelling.
- `data-import.R:1242-1249` — duplicate keys in default `column_mapping` (`qc_type`, `height`) →
  `rename(!!!...)` receives duplicated output names. → remove duplicates.
- `correct-drift-batch.R:594-596` — `fun_smooth` only assigned in the `is.character(smooth_fun)`
  branch; passing an actual function (the documented contract) leaves it undefined → error. → add `else`.
- `calc-ref-normalization.R:186,216,236-240,280,340` — `reference_sample_id` documented as "one or
  more" but treated as a scalar (`== reference_sample_id`, `ref_sample = reference_sample_id`);
  2+ reference IDs → recycling error / silent wrong recycle. → use `%in%`, summarize without per-row scalar.
- `data-export.R:87` — `str_detect(path, ".xlsx")` is unanchored + `.` is a wildcard, so
  `results_xlsx_draft` "already has" the extension and none is appended. → `"\\.xlsx$"`.
- `correct-drift-batch.R:1669` — batch-status text keyed off `var_drift_corrected[[variable]]`
  (should be `var_batch_corrected`) — mislabels state (message only).

**Unguarded divisions → `Inf`/`NaN` silently propagated** (beyond #3/#4 above):
- `calc-istd-normalization.R:297` (`* 1000 / molecular_weight`), `:374` (`/ sample_amount`, 0 not
  guarded, only `NA`); `calc-ref-normalization.R:189,299`; `correct-drift-batch.R:174,262,348`
  (`/ y_fit`), kernel weights `:62,64,82` (sum 0 → `NaN`); `functions-math.R:26,28,187`
  (`cv`, MAD z-score when mean/median/MAD = 0). Doc for `cv()` even *claims* it returns `NA_real_`
  on zero — it returns `Inf`/`NaN` (`functions-math.R:26,28`). → guard denominators, `NA` + warn,
  and/or fix the docstring.

**Silent `as.numeric` coercion → `NA`** with no reporting: `data-import.R:1477-1486`,
`metadata-import.R:1665,1908,1960`. A mistyped source cell becomes `NA` invisibly. → report coercion failures.

---

## Tier 3 — Suggestions: complexity, fragility, footguns

- **MassHunter parser positional fragility** — `data-import.R:721-833` (~380-line function) drives off
  hardcoded rows/cols (`datWide[2,]`, `datWide[[1,1]]`, `select(-where(~ .x[2] == ""))` which errors
  on an `NA` 2nd cell). Any export-layout shift silently mis-parses. Harden with name-based lookup +
  NA-safe predicates.
- **Version validation by magic cell + regex** — `metadata-import.R:1274-1290`: reads version from
  fixed `[3,3]`, strips the 2nd dot with a regex to force numeric (`"1.9.2"` → `"1.92"`), compares to
  magic bounds `0.2 … 0.3` that appear to contradict the documented required versions. Reconcile.
- **Duplicated builders / blocks** — `calc-calibrations.R:346-436` (four ~15-field result lists
  differing only by `coef_c`), `correct-drift-batch.R:941-1004` (five hardcoded QC-type blocks;
  other `qc_type`s silently dropped from the out-of-span report), `qc-filtering.R:1345-1429,1552-1584`
  (nine near-identical reconciliation branches). High drift risk; a single builder / loop over
  `unique(qc_type)` removes it.
- **Footguns:** param named `c` shadows `base::c` (`calc-calibrations.R:130`); local `mad <- mad(x)`
  shadows `base::mad` (`functions-math.R:239`); `blanket suppressWarnings(lm(...))` hides
  rank-deficiency (`calc-calibrations.R:335`); FP `!=` to detect "was corrected"
  (`correct-isotope.R:379`) — noise/NA → false positives; hardcoded `qc_type == "SPL"` for all CV
  computations while `ref_qc_types` is configurable (`correct-drift-batch.R:704,705,881-882,1814-1815`);
  `get(operator)` where `match.fun(operator)` is safer (`helper.R:98`); `order_chained_columns_tbl()`
  drops duplicate keys via `setNames` lookup (`helper.R:299,317`).
- **`call. = FALSE` passed to `cli::cli_abort`** (base `stop` arg, silently ignored) —
  `data-managment.R:655` and other cli calls. Use `call = NULL`.
- **NA-unsafe `any()`/`str_detect` in `if`** — `data-import.R:658,662`; `data-managment.R:100`. Add
  `na.rm = TRUE` / drop NA.

---

## Monkey-fixes (self-admitted hacks / stopgaps to resolve)

| Location | What | Risk |
|----------|------|------|
| `correct-drift-batch.R:1972` | `# TODO: confirm if this is ok…` then Inf/NaN → `NA_real_` in batch-centering location calc | Masks upstream div-by-zero in a correction feeding quantitation — **verify correctness** |
| `qc-filtering.R:680` | `#TODOTODO: IMPORTANT temp solution- align with response curve` around calibration-join | Temp calibration-join logic diverges from response-curve error checking — likely a bug |
| `build-workflow.R:309` | `tryCatch(s$gate(mexp), error = \(e) list(enabled = TRUE))` | Any gate bug silently → "step enabled"; catch narrowly / log |
| `data-import.R:705` | `suppressWarnings(suppressMessages(` around a whole read block | Legit parse warnings (coercion, malformed rows) hidden on import; scope to the noisy call |
| `metadata-import.R:573` | `#TODO remove: metadata$annot_analyses$qc_type[3] <- NA` | Debug data-tampering leftover — delete |
| `correct-drift-batch.R:144` | `} #TODO: suppressWarnings?` | Undecided warning policy in drift fitting |
| `data-import.R:1278` | `# TODO: A bit of a workaround…` (Skyline detection inlined) | Importer branching entangled; extract helper |
| `qc-filtering.R:151` | `# TODO: remove later when fixed` (lipidomics branch) | Stopgap branch lingering in production |
| `plots-qc-pca.R:735,748` | `# TODO: (IS as criteria for ISTD.. dangerous` — ISTD detected by name regex `\\(IS\\)| ISTD` | Brittle; rely on `is_istd` metadata |
| `plots-qc-filtering.R:454` | magic label-justification constants (`/1.5,-2,2`) "Here lies the magic" | Fragile layout tuning; document/derive |
| `plots-qc-identification.R:170,187,206` | per-feature `tryCatch`/`suppressWarnings` | Failing features silently dropped from plot; surface a skipped count |

---

## Stale / dead code (safe to delete — recoverable via git)

- **Large commented-out functions:** `data-import.R:1824-1897` (`parse_mrmhub_result_wide`, 74 lines),
  `plots-qc-pca.R:724-877` (`plot_pca_pairs`, 154 lines), `data-export.R:705-714`
  (`save_summarizedexperiment` skeleton).
- **Scaffolding/debug leftovers:** `correct-drift-batch.R:582-589,622-625,629-630,672-675`
  (`txtProgressBar`), `:187` (debug print), `:637` (commented pipe), `:1625`
  (`#correct_location = TRUE,` — obsolete signature arg), `:1848,1853` (uninterpolated `{var_names}`
  string, also immediately overwritten → dead), `:1867-1868` (commented `cli_alert_info`),
  `:1927` (`batch.order` computed, never used).
- **Lipidomics:** `lipidomics.R:1` (obsolete `# TODO: Replace with RGOSLIN !` — already using rgoslin),
  `:9,17,86-92` (old parsing), `:150-157` (superseded `dplyr::do`).
- **Misc:** `data-import.R:54,391,654-655,700-702,1516-1518`; `data-export.R:217-218,298-299,317-318,385,435,439-440`;
  `calc-eda.R:99` (`# drop_na(feature_conc)` — ambiguous intent).
- **Unresolved-intent TODOs worth tracking** (not bugs): `data-managment.R:906`, `data-import.R:1104,1143`,
  `metadata-import.R:838,847,895,964,1860,1869`, `qc-filtering.R:830,916,1467`,
  `plots-calibcurves.R:586,1001` (untested paths), `plots-eda.R:480` (`returns P = 1 currently`).
- **Not issues:** `linewidth = 0.0001` in plots (ggplot "no border"), narrow
  `suppressWarnings(as.numeric(...))` on single user-string coercions — benign.

---

## Performance & memory (safe localized wins only)

Behavior-preserving; each verifiable against existing tests / vdiffr snapshots.

1. **O(n²) gaussian-kernel smoother** — `correct-drift-batch.R:57-65,77-84`: nested `for (i in 1:n)`
   recomputes a full-length `dnorm` weight vector per point, twice. Dominant cost of the default
   drift method. → single `outer()`/matrix `dnorm` pass; assert identical output on a fixture.
2. **Isotope full-dataset-copy loop** — `correct-isotope.R:356-364`: per-corrected-feature loop
   re-groups + copies the whole long table each iteration (O(features × full dataset)). → single
   grouped pass over all corrections. (Fixing the `1:nrow` empty bug #Tier-2 belongs here too.)
3. **`polyroot` over all rows** — `calc-calibrations.R:117-145`: `case_when` eagerly evaluates the
   row-wise `pmap_dbl(polyroot)` branch for **every** row, even linear features. → run only on
   `fit_model == "quadratic"` rows.

**Memory (documented, structural — NOT in scope):** three full long tibbles held at once
(`dataset_orig`/`dataset`/`dataset_filtered`, `classes.R:47-49`) + ~24 postfix `_raw/_before/_fit`
columns from corrections (`correct-drift-batch.R:443-930`, `correct-isotope.R:347`). Batch centering
is serial (`:1797-1806`) while drift is parallelized — a future option, not a safe drop-in. Recorded
for later, deliberately excluded from the current change set.

---

## Test coverage gaps (regression tests to add)

463 tests, testthat 3e, strong on corrupt-file/duplicate imports. Gaps that map to the Blocking/Required
findings above:
- **`add_metadata` has zero direct tests** — the central join primitive. Add: duplicate metadata keys
  → error; missing keys → documented drop + warning; `NA valid_*`.
- **Zero-denominator paths** untested: ISTD area 0, calibration slope 0, empty reference set.
- **Empty / zero-row inputs** into `normalize_by_istd`, `calc_qc_metrics`, `quantify_by_calibration`.
- **`qc_type` outside `qc_type_levels`**; export `pivot_wider` with duplicate keys.
- Only **one `expect_warning`** in the whole suite — warning paths of the transforms are largely
  unasserted (per r-package-development skill, prefer `expect_snapshot()` for new warning/error tests).

> Constraint: existing tests are manually verified and will **not** be edited without consent; Phase 3
> only *adds* tests. A proposed fix that breaks a currently-passing test will be surfaced, not "fixed".

---

## Recommended remediation order (all gated on consent)

1. **Tier-1 no-ops & copy-paste** (#5,6,7,8,14 + `.before`/`arrange`/typos in Tier 2) — tiny, mechanical,
   high-value; each defeats a check or produces a wrong number today.
2. **Tier-1 numeric correctness** (#1,2,3,4) — the calibration/ISTD math; pair each with a regression test.
3. **Tier-2 crash guards** (`&&`, `seq_len`, `isTRUE(all(...))`, division guards).
4. **Perf wins** (3 items) — verify numerically-identical output + unchanged vdiffr snapshots.
5. **Monkey-fixes** — resolve the two flagged as likely bugs (`correct-drift-batch.R:1972`,
   `qc-filtering.R:680`) before the cosmetic ones.
6. **Stale-code deletion** — mechanical, do last / separately to keep review diffs clean.

*Review assisted by the critical-code-reviewer skill and Posit R skills.*
