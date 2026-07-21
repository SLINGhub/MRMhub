# NA

## Plan: Full (front+back) isotope correction, self-contained in MRMhub

**Status:** Not started. Design + pre-port review complete. Awaiting
implementation.

**TL;DR** — Make MRMhub perform LICAR’s *full* isotopic interference
correction end-to-end, with no manual LICAR round-trip. **One new
Feature-Metadata column, `mrm_pattern`** (the LICAR display label),
declares each feature’s transition; the LICAR group/origin and the
internal class code are **derived from it** (labels are globally unique
— verified). **Copied+hardened LICAR functions** derive the front/back
M+2 correction factors from the lipid name and **auto-discover the
interfering pairs by m/z** (scoped per `mrm_pattern`); MRMhub’s existing
subtraction engine — extended to **two interferers per feature** —
applies `X − front − back`. This spec is self-contained: it carries
absolute paths into the LICAR source so no LICAR context is needed.

> **Cross-repo note.** LICAR source lives at
> `/Users/lsibjb/Documents/Code/LICAR-1`. All `LICAR:R/...#Lxxx`
> references below are absolute to that repo, used **read-only as the
> source to copy**. **Do the LICAR bug fixes in the MRMhub copy, in this
> (MRMhub) session — the LICAR repo is NOT modified.** Copy the
> functions, then harden the parsing + add the `check_chemform` guard in
> the MRMhub copy. Cross-check the copied factors against LICAR’s golden
> values (`LICAR:tests/testthat/golden/`, tolerance 1e-6) for parity.
> (LICAR is not a package — no DESCRIPTION/NAMESPACE — so MRMhub cannot
> depend on it; a copy is required regardless.)

------------------------------------------------------------------------

## Why

LICAR corrects two overlaps on the *same* feature: a **front**
(neutral-fragment, product delta `DiffPro=0`) and a **back**
(product-ion, `DiffPro=2`) overlap — each a *different* interfering
feature with its own M+2 factor. MRMhub today (`correct_interferences`)
supports exactly **one** interfering feature per affected feature, and
the factor is entered manually (from a LICAR app run). Goal: derive
factors *and* pairs inside MRMhub so the whole workflow stays here, and
lift the one-interferer limit so both overlaps are corrected.

Confirmed feasible in review: MRMhub’s inner subtraction already
composes `X − front − back` across iterations; the blockers are only the
metadata schema (one-interferer) and the single-parent chain orderer.
Factor + pairing logic is a pure function of name + m/z, so it ports
cleanly as an edge-emitting step in front of MRMhub’s engine.

## Decisions (locked)

1.  **Auto-discover pairs by m/z** (port LICAR’s Δm/z matching), not
    user-entered pairs.
2.  **Copy the LICAR chemistry into MRMhub** (accepting Table S1
    constant duplication) — mitigated by a golden parity test vs LICAR.
3.  **Harden the parsing** — fix the crash-on-valid-name bugs **in the
    MRMhub copy** (the LICAR repo is not modified). See robustness fixes
    below.
4.  **Match LICAR’s negative-value handling exactly** (immediate
    0-clamp) so corrected numbers reproduce LICAR to 1e-6 — but **gate
    it to the new LICAR-derived path**; do not silently change the
    existing manual single-interferer correction behaviour.
5.  Scope split by how the interference is produced:
    - **Auto path (this work):** M+2 **front/back**, within-class,
      m/z-matched, LICAR-derived.
    - **Manual path (existing MRMhub facility):** M+1, M+3, and **RPLC**
      (cross-class SM→PC M+3, PC-P→PC-O M+2) — rare/irregular, so the
      user names the interfering feature **pair** and the **factor**
      (obtainable from LICAR’s rel-abundance export, which computes
      M+1/M+3). No auto-derivation, no chemistry in MRMhub for these.
      The per-`mrm_pattern` scoping constrains only the auto path;
      manual rows name their pair explicitly, so cross-class RPLC is
      fine. The engine subtracts every interference identically
      (`factor × interferer`), so a manual M+1/M+3/RPLC edge is just
      another edge — no per-isotope logic. This is why **long storage is
      preferred**: auto M+2 and manual M+1/M+3/RPLC coexist as rows in
      one relationship table feeding one engine (wide would push the
      manual kinds into a separate store the engine must also union).

------------------------------------------------------------------------

## Source of truth — LICAR functions to copy (absolute paths)

All in `/Users/lsibjb/Documents/Code/LICAR-1/R/LICAR_functions.R` unless
noted:

| Purpose | Function | Lines |
|----|----|----|
| Abundance primitive (formula → M+n rel. abundance) | `mCalcIsotope`, `mCalc`(M+2), `mCalc3`(M+3) | \#L18–L50 |
| Formula-capture + rel-abundance export (reference for the parity test) | `licar_set_formulas`, `licar_formulas`, `licar_rel_abundance` | \#L61–L124 |
| Chain-name parsing → front/back C & double-bonds | `CH_raw` | \#L488–L502 |
| Offsets → fragment formula → K | `CH_K` | \#L514–L540 |
| Single-fragment (head-group) parse + factor | `isoCorrect_head` | \#L357–L413 |
| Per-class `constant_C/H/O/N` offsets (head group) | `isoCorrect_headGroup` | \#L422–L480 |
| Per-class offsets (FA) + the Δm/z **matching sweep** | `isoCorrect_FA` | offsets \#L550–L731, sweep \#L735–L761 |
| Per-class offsets (LCB) + sweep (front/back roles inverted vs FA) | `isoCorrect_LCB` | offsets \#L779–L820, sweep \#L823–L848 |
| Label→class-code map + choices | `LICAR_CHOICES`, `licar_label_to_class`, `licar_class_choices` | `LICAR:R/lipid_choices.R` |
| Golden factors to pin against | template CSVs | `LICAR:tests/testthat/golden/` |

**Key facts about this code (verified in review):** - The factor is a
property of the **interfering** feature’s own fragment formula
(`K_front[i]`/ `K_back[i]` at the *source* row) — independent of the
affected feature and of intensities. - The offsets exist only as
**inline literals** inside the sweep-bearing `isoCorrect_*` bodies. Lift
them into a **data-driven lookup keyed by class code** when copying. -
Branch selection uses both class code **and** an m/z guard on `Product`
/ `Precursor−Product`. MRMhub features carry
`precursor_mz`/`product_mz`, so the guards still work. - The FA/LCB
sweeps interleave matching + subtraction. **Refactor the copy to emit
edges**
`(affected_feature, interfering_feature, contribution, overlap_type)`
instead of subtracting. Match guards read only m/z, so edge extraction
is order- and intensity-independent.

------------------------------------------------------------------------

## Work items

### A. Metadata — persist the derived front/back interferers + factors

**The only hard requirement:** the M+2 factors and the front/back
interfering feature IDs that `derive_interferences()` (item B) computes
must be **persisted on the MRMhubExperiment** and read by the correction
engine (item C). Both storage shapes below work; **long is preferred**
because it also holds the manual M+1/M+3/RPLC interferences in the same
table/engine (Decision 5). Wide is viable if you keep those manual kinds
in MRMhub’s existing separate interference store.

User-supplied input column (one, per feature): **`mrm_pattern`** — the
LICAR **display label** (e.g. `"PC (Neg, FA) FA"`), matching the LICAR
multi-class XLSX template. **`product_origin` is NOT stored** — the
origin *and* the internal class code are derived from `mrm_pattern` via
the copied `LICAR_CHOICES` lookup (all 64 labels are globally unique —
verified; the class *code* is NOT unique — `PC`/`PCO` recur under RPLC —
so key the lookup on the **label**, never the code). - Import/clean path
in `R/metadata-import.R`: add `mrm_pattern` via legacy renames
(~#L1448), `clean_feature_metadata` `add_missing_column` + the fixed
final `select()` (~#L1981), and an `assert_metadata` check that
`mrm_pattern` is a valid `LICAR_CHOICES` label. - **Invariant to
assert** (a unit test): labels in the copied choices are globally unique
— the “derive origin from pattern” simplification rests on it, so a
future collision must fail loudly.

Two equally-fine storage shapes for the derived relationships (both
engine-written, not hand-entered):

- **Wide** — four columns on `annot_features_template`
  (`R/mrmhub-global-definitions.R#L45`):
  `interference_feature_id_front/_back`,
  `interference_contribution_front/_back`. Keeps `annot_features`
  one-row-per-feature (`is_uniq` holds), the `left_join`
  (`R/correct-isotope.R#L251`) 1:1, and needs no new
  table/class-slot/import path. Cap of 2 pairs = exactly front+back.
- **Long** — a sibling `annot_interferences` table (feature_id,
  interference_feature_id, contribution, overlap_type), mirroring the
  `annot_istds` pattern (class slot `R/classes.R#L55`, prototype `#L83`,
  `$` allow-list `#L250`). More normalized; generalises to \>2
  interferers / M+1/M+3 later. Needs the sibling-table plumbing.

Either way, item C reads these into a **2-row-per-feature** form for the
topological sort. - Store interference **relationships** as a *derived*
long table (feature_id, interference_feature_id,
interference_contribution, overlap_type) produced by item B — not
hand-entered. Add it to the MRMhubExperiment mirroring the `annot_istds`
sibling pattern: class slot `R/classes.R#L55`, prototype default `#L83`,
`$` accessor allow-list `#L250`, optional `show` line `#L322`. Template
alongside the siblings at `R/mrmhub-global-definitions.R#L63–L85`.

### B. Ported LICAR factor + pairing module — new `R/isotope-licar.R`

- **Abundance:** copy `mCalcIsotope` **or** reuse MRMhub’s
  [`enviPat::isopattern`](https://rdrr.io/pkg/enviPat/man/isopattern.html) +
  the `isotopes` object already in `R/sysdata.rda` (used by
  `calc_average_molweight`, `R/functions-chem.R#L31`). Pick one and pin
  it with the golden test. **Add the `check_chemform` warning guard**
  the LICAR original omits (LICAR silently passes bad formulas into
  `isowrap`, which aborts obscurely).
- **Name→fragment:** copy `CH_raw` + `CH_K` and the per-class offsets
  (as a lookup table). **Harden parsing** (Decision 3): parse each
  chain’s `C:D` field with a regex around `/`/`_` instead of fixed
  2-char `substring`. LICAR crashes on single-digit **back-chain**
  carbon (`Cer d18:1/6:0`, PAF `PC O-16:0/2:0` → `C_back = NA`) and on
  sphingoid names fed to a head-group class (`SM d18:1/16:0` →
  `H_raw = NA`); also guard the single-row `CH_raw` reshape. These are
  genuine LICAR bugs (crashes on valid short-chain/sphingoid names);
  **fix them in the MRMhub copy** (LICAR repo untouched). The fixes turn
  crashes into values, so the happy-path factors still match LICAR’s
  golden values (the parity cross-check).
- **Label→code:** copy `LICAR_CHOICES` / `licar_label_to_class` from
  `LICAR:R/lipid_choices.R` (data table — low drift).
- **Pairing:** copy the Δm/z matching (`DiffPre`/`DiffPro` within ±0.2;
  `CLNFA_2` uses `DiffPre=1` for the 2+ ion), refactored to **record an
  edge + the interferer’s front/back factor per matched overlap type**,
  and **scoped strictly per `mrm_pattern`** (equivalently, per class —
  `mrm_pattern` is the finest transition id; divergence 2 below). Note
  the LCB front/back inversion vs FA.
- **Public entry** `derive_interferences(mexp)` → the long table for
  item A. Internally it maps each feature’s `mrm_pattern` → (origin,
  class code) via the copied `LICAR_CHOICES`, then runs the
  origin-appropriate parse/offset/matching.

### C. Correction engine — two interferers per feature (`R/correct-isotope.R`)

- Feed `features_to_correct` from the derived long table (two rows per
  affected feature) instead of the one-to-one scalar join at `#L251`.
  The inner subtraction (`correct_feature_intensity`, `#L327–L366`)
  already composes `X − front − back` across iterations — logic
  unchanged.
- Replace single-parent `order_chained_columns_tbl` (`R/helper.R#L275`;
  it **aborts on duplicate `from`** at `#L296` and builds a
  `setNames(to, from)` linear chain at `#L331`) with a **cycle-detecting
  topological sort** (Kahn/DFS) that tolerates two parents and processes
  **upstream-first** (interferers before dependents — the current code
  achieves this via `arrange(desc(row_number()))` at `#L321`; preserve
  that ordering). Keep the friendly “Circular dependency” abort the
  `tryCatch` at `#L287` greps for.
- **Negative handling (Decision 4):** 0-clamp each corrected value
  immediately (≡ LICAR’s per-use `max(0, source)` guard + end clamp).
  Gate this to the LICAR-derived path so the existing manual path (and
  its `neg_to_na` option) is unchanged.

### D. Tests (`tests/testthat/`)

- **Golden parity:** `derive_interferences()` factors == LICAR
  `licar_rel_abundance` on the same names (pin PC 34:2→34:1 front/back
  and a few others; guards Table S1 drift).
- **Two-parent correction:** extend
  `tests/testthat/test-correct-isotope.R` (fixtures at `#L1–L39`) with a
  feature that has a front + back interferer, assert `X − front − back`
  to 1e-6.
- **Regression:** the existing chain test (`#L54–L207`) and
  circular-chain abort (`#L411–L428`) must still pass under the new
  topological sort.
- Hardened-parsing unit tests: `Cer d18:1/6:0`, `SM d18:1/16:0`,
  single-row input — no crash.

------------------------------------------------------------------------

## The three port-divergences to get right (from the pre-port review)

1.  **Negative interferer.** LICAR skips a driven-negative source
    (`if(source>0)`, `LICAR:#L748/ L754`) and clamps negatives to 0
    (`#L763`); MRMhub `correct_feature_intensity` has no guard and no
    default clamp, so a negative source *adds* signal. Example
    (M/M+2/M+4, K=0.09, raw 100/5/5): LICAR M+4 = 5.00, naive MRMhub =
    5.36. → item C negative-handling.
2.  **Per-class scoping.** LICAR’s correctness vs false pairs relies on
    its one-class-per-file guard. A global m/z sweep would fabricate
    cross-class edges (features ~2 Da apart with equal product m/z). →
    item B must scope matching per `mrm_pattern` (= per class).
3.  **Multiple interferers per feature is real** (front + back = two
    different features). → items A+C.

## Reproducibility & storage

Interferences must be reproducible; the two Sources need different
handling:

- **Auto M+2 (derived):** the reproducible **input** is `mrm_pattern`
  per feature (+ name + m/z, already in metadata) —
  `derive_interferences()` regenerates identical edges given the ported
  code and a fixed enviPat version. **But factors are
  enviPat-version-sensitive** (LICAR KNOWN_ISSUES F1: 8.98%→8.9478%
  across enviPat versions; LICAR pins observed values + records
  `golden/enviPat-version.txt`). So **also persist a frozen snapshot**
  of the derived interference table (interferer IDs + factors +
  kind/source) so the exact factors survive an enviPat upgrade.
- **Manual M+1/M+3/RPLC (primary data):** stored verbatim in the
  interference metadata table (imported) — not derivable, exactly like
  today’s `interference_feature_id`/`interference_contribution`.

Physical storage (reuse existing MRMhub plumbing): - The (long)
interference table is a **slot on the `MRMhubExperiment`**, persisted by
`saveRDS(mexp)` and included in
[`save_report_xlsx()`](https://slinghub.github.io/MRMhub/quant/reference/save_report_xlsx.md). -
Make it **round-trippable via metadata import/export**
([`save_metadata_templates()`](https://slinghub.github.io/MRMhub/quant/reference/save_metadata_templates.md),
`R/data-export.R#L642`) so a re-run from raw data + metadata reproduces
corrections **without re-deriving** — freezing factors against enviPat
drift; one table for auto + manual. - **Provenance:** record enviPat (+
ported-LICAR) version — MRMhub already inspects package versions in
`R/check-setup.R`; the correction sets `status_processing` /
`is_isotope_corr`.

## Suggested execution

Dependency order **A → B → C → D**. Consider a dedicated branch off
`development` (e.g. `feature/isotope-correction-full`).
[`devtools::test()`](https://devtools.r-lib.org/reference/test.html) /
`R CMD check` green before merge. The working tree currently has
unrelated modified/`.new` plot snapshots — keep this work separate from
those.
