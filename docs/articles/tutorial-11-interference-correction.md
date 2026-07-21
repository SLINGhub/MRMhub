# Interference Correction

Tutorial

In class-based targeted assays, the natural-abundance heavy
isotopologues of one species can overlap the transition of a species two
mass units heavier, inflating its measured area. MRMhub derives these
isotopic (M+2) interference relationships automatically from a
per-feature `mrm_pattern` annotation and removes them with a
contribution-based subtraction ported from the LICAR method (Gao et al.
2021). This tutorial walks through the end-to-end workflow; the concepts
(front/back overlaps, fragment-based-for-MRM, the co-elution
requirement) are documented in the [Isotopic interference
correction](https://slinghub.github.io/MRMhub/quant/articles/manual-12-interference-correction.md)
manual page.

**Time** ~15 min  ·  **Level** Advanced  ·  **Prerequisites** [Basic
workflow](https://slinghub.github.io/MRMhub/quant/articles/tutorial-02-basic-workflow.md)

## 1. When is correction needed?

Isotopic interference correction should be considered when:

1.  blank injections show a non-zero signal in a feature that should be
    zero;
2.  a species and an M+2 “shoulder” two mass units heavier show strong
    injection-to-injection correlation, suggestive of isotopologue
    overlap;
3.  the theoretical M+2 contribution from an adjacent same-class species
    is large enough to bias the measurement (more than a few percent of
    the target signal).

Correction operates on raw feature intensities (`feature_intensity`) and
should be applied *before* ISTD normalisation, drift, and batch
correction, so those downstream steps use corrected raw signals.

## 2. Annotate `mrm_pattern`

Automatic derivation needs one input: the `mrm_pattern` column on the
`Features` metadata sheet, giving each feature its class + MRM pattern
(e.g. `PC (Pos) Pro=184.1`, `Cer (Pos) SphB-2H2O`, `PC (Neg, FA) FA`).
The label encodes both the lipid class and the product-ion origin. The
valid labels are listed by
[`licar_pattern_choices()`](https://slinghub.github.io/MRMhub/quant/reference/licar_pattern_choices.md):

``` r

library(mrmhub)
licar_pattern_choices("Head Group")
```

The metadata template
([`save_metadata_templates()`](https://slinghub.github.io/MRMhub/quant/reference/save_metadata_templates.md))
provides `mrm_pattern` as a filtered dropdown on the `Features` sheet,
with an optional `polarity` column that narrows the choices and colour
warnings when a species name does not match the chosen pattern’s class.
On import, MRMhub validates the column: an unknown label is an error,
and a name/pattern class mismatch or a sum-only name under a
chain-resolved (FA/LCB) pattern is a warning.

``` r

mexp <- readRDS("results/mexp_processed.rds")
```

## 3. Derive interference relationships

[`derive_interferences()`](https://slinghub.github.io/MRMhub/quant/reference/derive_interferences.md)
discovers the M+2 overlaps and stores them in the `annot_interferences`
slot. Choose the derivation `level` to match the acquisition:

``` r

# Class-based LC-MRM: fragment-level front/back correction (needs precursor + product m/z).
mexp <- derive_interferences(mexp, level = "MRM")

# Genuine MS1 / full-scan: whole-molecule M+2 (needs precursor m/z only).
# mexp <- derive_interferences(mexp, level = "MS1")
```

**MS1 is not a fallback for MRM.** MRM correction must be
fragment-based, because a heavy isotope’s contribution depends on
whether it lands on the retained product ion or the neutral loss (Gao et
al. 2021). Use `level = "MS1"` only for genuine full-scan data — never
as a substitute for MRM data missing a product m/z. See the [manual
page](https://slinghub.github.io/MRMhub/quant/articles/manual-12-interference-correction.md)
for the full rationale.

By default (`check_coelution = TRUE`) an m/z-matched edge is kept only
when the interferer’s peak apex falls inside the victim’s integration
window; chromatographically resolved pairs are dropped and reported.
Derived factors are pinned to `enviPat` 2.8 (Loos et al. 2015) and are
deterministic, so re-importing the annotation and re-deriving reproduces
identical edges.

## 4. Inspect the derived relationships

The two-step API lets you review the derived edges before subtracting
anything. Each row is one overlap, with its contribution factor `K` and
an `overlap_type` (`m2_front`, `m2_back`, or `ms1_m2`):

``` r

mexp@annot_interferences
```

A victim carrying both a `m2_front` and a `m2_back` row is corrected
against two interferers. The `source` column distinguishes auto-derived
(`"auto"`) from manually annotated (`"manual"`) edges; both are applied
together.

## 5. Apply the correction

[`correct_interferences()`](https://slinghub.github.io/MRMhub/quant/reference/correct_interferences.md)
reads `annot_interferences` (unioned with any legacy manual annotation
columns) and subtracts every edge in one pass:

``` math
\text{Value}_\text{corrected} = \text{Value}_\text{target} -
   \sum_i K_i \cdot \text{Value}_{\text{interfering}_i}
```

``` r

mexp <- correct_interferences(mexp, variable = "feature_intensity")
```

Upstream features in a chain (A ← B ← C) are corrected first via a
topological ordering; circular dependencies are detected and aborted
with an informative error. For auto-derived edges, a subtraction is
skipped when the running-corrected interferer has already fallen to
zero, and corrected values are clamped at zero (LICAR parity). The
original raw values are preserved in `feature_intensity_orig`.

## 6. Manual correction of a single pair

For a one-off correction, or to validate a factor before trusting the
automatic derivation, use
[`correct_interference_manual()`](https://slinghub.github.io/MRMhub/quant/reference/correct_interference_manual.md).
`variable` here is the actual `dataset` column name
(`feature_intensity`).

``` r

mexp <- correct_interference_manual(
  mexp,
  variable                  = "feature_intensity",
  feature                   = "PC 32:0",
  interfering_feature       = "SM 36:1 M+3",
  interference_contribution = 0.0107,
  neg_to_na                 = FALSE,
  updated_feature_id        = NA
)
```

Setting `updated_feature_id` renames the corrected feature so raw and
corrected channels can coexist under different IDs. Manual factors can
be sourced from a theoretical isotopologue calculation (`enviPat`), an
empirical pure-standard injection (which also captures Q1/Q3
transmission and in-source effects), or published class-level
interference tables — verified empirically when moving a method between
instruments.

## 7. Verifying the correction

``` r

d <- get_analyticaldata(mexp, annotated = TRUE) |>
  dplyr::filter(feature_id == "PC 32:0") |>
  dplyr::select(analysis_id, qc_type,
                intensity_before = feature_intensity_orig,
                intensity_after  = feature_intensity) |>
  dplyr::mutate(pct_change = 100 * (intensity_after - intensity_before) / intensity_before)

summary(d$pct_change)
```

For blanks (`SBLK`/`PBLK`), residual signal after correction should
approach zero. A non-zero blank median often indicates an underestimated
contribution factor.

## Recommendations

- Apply interference correction on raw `feature_intensity` *before*
  normalisation, drift, and batch correction.
- Prefer `level = "MRM"` for MRM data and supply the product m/z;
  reserve `level = "MS1"` for genuine full-scan measurements.
- Inspect `annot_interferences` before applying, especially any pairs
  the co-elution gate dropped.
- Keep the `mrm_pattern` annotation with the project: it reproduces the
  derived factors under the `enviPat` 2.8 pin.
- After correction, verify that blank residual signal approaches zero.

## Next steps

- [Isotopic interference
  correction](https://slinghub.github.io/MRMhub/quant/articles/manual-12-interference-correction.md)
  — the conceptual reference
- [Drift and Batch
  Correction](https://slinghub.github.io/MRMhub/quant/articles/tutorial-04-drift-correction.md)
  — apply after interference correction
- [Basic MRMhub
  Workflow](https://slinghub.github.io/MRMhub/quant/articles/tutorial-02-basic-workflow.md)
  — full processing pipeline
- [The MRMhubExperiment Data
  Object](https://slinghub.github.io/MRMhub/quant/articles/manual-02-data-object.html#feature-variables)
  — how `_orig` postfixes preserve raw values

## References

Gao, Liang, Shanshan Ji, Bo Burla, Markus R. Wenk, Federico Torta, and
Amaury Cazenave-Gassiot. 2021. “LICAR: An Application for Isotopic
Correction of Targeted Lipidomic Data Acquired with Class-Based
Chromatographic Separations Using Multiple Reaction Monitoring.”
*Analytical Chemistry* 93 (6): 3163–71.
<https://doi.org/10.1021/acs.analchem.0c04565>.

Loos, Martin, Christian Gerber, Frederic Corona, Juliane Hollender, and
Heinz Singer. 2015. “Nontarget Screening with High-Resolution Mass
Spectrometry in the Environment: Ready to Go?” *Environmental Science &
Technology* 49 (3): 1857–65. <https://doi.org/10.1021/es5040179>.
