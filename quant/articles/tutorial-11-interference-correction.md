# Interference Correction

In targeted MRM assays, the signal of one transition can be perturbed by
contributions from a co-eluting compound. The most common cause in
lipidomics is overlap of natural-abundance isotopologues (M+1, M+2 from
¹³C, ²H, ¹⁵N) with the precursor or product window of an adjacent
species. MRMhub implements a contribution-based subtraction
(LICAR-style) (Gao et al. 2021) that removes the proportional signal of
an *interfering feature* from a *target feature* on a per-injection
basis.

This tutorial covers when to apply interference correction, how to
define interference relationships in the feature annotation, and how to
apply both batch and manual corrections.

**Time:** ~15 min  \|  **Level:** Advanced  \|  **Prerequisites:**
[Basic
workflow](https://slinghub.github.io/MRMhub/quant/articles/tutorial-02-basic-workflow.md)

## 1. When is correction needed?

Interference correction should be considered when:

1.  blank injections show a non-zero signal in a feature that should be
    zero;
2.  two features that should be biologically uncorrelated show a strong
    injection-to-injection correlation suggestive of cross-talk;
3.  the theoretical M+1 / M+2 contribution from an adjacent species is
    large enough to bias the measurement (typically more than a few
    percent of the target signal at expected concentrations).

Small contributions (below ~1% of target signal) rarely justify
correction; they should be documented but not necessarily subtracted,
since the propagated uncertainty of the correction can exceed the bias
removed.

## 2. Setup

``` r

library(mrmhub)

mexp <- readRDS("results/mexp_processed.rds")
```

Interference correction operates on raw feature intensities
(`feature_intensity`). Apply it before ISTD normalisation, drift, and
batch correction, so that those downstream steps use corrected raw
signals.

## 3. Inspecting candidate pairs

[`plot_qc_interferences()`](https://slinghub.github.io/MRMhub/quant/reference/plot_qc_interferences.md)
provides a visual overview of features flagged as potentially
interfering. For an exploratory check, retrieve the long-format dataset
and correlate suspect features across injections:

``` r

d <- get_analyticaldata(mexp, annotated = TRUE)

d_wide <- d |>
  dplyr::select(analysis_id, feature_id, feature_intensity) |>
  tidyr::pivot_wider(names_from = feature_id, values_from = feature_intensity)

# Pearson correlation across QC injections for a suspected pair
suspect <- c("Cer 18:1;O2/16:0", "Cer 18:1;O2/16:0 M+2")
cor(d_wide[, suspect], use = "pairwise.complete.obs")
```

A correlation close to 1 between a species and a `M+2` shoulder
consistent with isotopologue overlap is a strong indicator that
subtraction is warranted.

## 4. Batch correction via feature annotation

[`correct_interferences()`](https://slinghub.github.io/MRMhub/quant/reference/correct_interferences.md)
reads the interference relationships defined in `annot_features`. Two
columns are consulted:

| Column | Description |
|----|----|
| `interference_feature_id` | `feature_id` of the feature contributing to the target signal |
| `interference_contribution` | Fraction (0–1) of the interfering feature’s intensity contributing to the target |

Features without an interference assignment leave these columns empty
(`NA`). When relationships are chained (A → B → C, i.e. C interferes
with B which interferes with A), set `sequential_correction = TRUE`
(default) so that downstream features are corrected first.

``` r

mexp <- correct_interferences(mexp,
                              variable = "feature_intensity",
                              sequential_correction = TRUE,
                              neg_to_na = FALSE)
```

For each affected feature the correction subtracts the interfering
contribution:

``` math
\text{Value}_\text{corrected} = \text{Value}_\text{target} -
   f_\text{contribution} \cdot \text{Value}_\text{interfering}
```

Negative results are kept by default; setting `neg_to_na = TRUE`
replaces them with `NA` and emits a warning. Circular dependencies in
the interference graph (A → B → A) are detected and aborted with an
informative error.

**Required annotation column placement**

Add `interference_feature_id` and `interference_contribution` to the
`annot_features` table — the same table that defines feature classes and
ISTD assignments. The `MRMhub Metadata Organizer` template includes
these columns; the plain
[`save_metadata_templates()`](https://slinghub.github.io/MRMhub/quant/reference/save_metadata_templates.md)
output does as well in recent versions of the package.

## 5. Manual correction of a single pair

For one-off corrections, or when validating a contribution factor before
adding it to the annotation, use
[`correct_interference_manual()`](https://slinghub.github.io/MRMhub/quant/reference/correct_interference_manual.md).
Note that `variable` here is the *actual* column name in `dataset`
(`feature_intensity`), not the short form accepted by the plotting
functions.

``` r

mexp <- correct_interference_manual(
  mexp,
  variable                  = "feature_intensity",
  feature                   = "PC 32:0",
  interfering_feature       = "PC 32:0 | SM 36:1 M+3",
  interference_contribution = 0.0107,
  neg_to_na                 = FALSE,
  updated_feature_id        = NA
)
```

Setting `updated_feature_id` renames the corrected feature so the
original and corrected values can coexist in the dataset under different
IDs — useful when reporting both raw and corrected channels.

## 6. Verifying the correction

After correction the original raw values are preserved in
`feature_intensity_orig` so that before/after comparisons remain
available.

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
approach zero. A non-zero median in blanks after correction often
indicates that the contribution factor is underestimated.

## 7. Sourcing contribution factors

Contribution factors can be derived from three sources of varying
confidence:

1.  **Theoretical natural-abundance isotopologue calculation** — compute
    the M+*n* fraction from the neutral formula using `enviPat` (Loos et
    al. 2015) or comparable tools, then scale by any instrument-specific
    transmission differences across the two transitions.
2.  **Empirical measurement** — inject the pure standard of the
    interfering species and measure the ratio of its signal in the
    target transition to its signal in its own transition. This captures
    instrument-specific effects (Q1/Q3 resolution, cross-talk, in-source
    fragmentation) that the theoretical calculation omits.
3.  **Published values** — class-level interference tables published for
    lipid panels with shared precursor scans. Useful as a starting point
    but should be verified empirically when migrating methods between
    instruments.

**Example: theoretical M+2 fraction with enviPat**

``` r

library(enviPat)
data(isotopes)

# PC 32:0 — neutral formula C40H80NO8P
pattern <- isopattern(isotopes, "C40H80NO8P", charge = 1, threshold = 0.01)

# M+2 abundance relative to M+0
m_plus_2 <- pattern[[1]]
m_plus_2[, "abundance"] / max(m_plus_2[, "abundance"])
```

The reported M+2 fraction is the theoretical isotopologue abundance
only. A real interference factor also depends on Q1/Q3 transmission,
in-source fragmentation, and chromatographic resolution of the two
species. Validate against blank or pure-standard injections before
applying broadly.

## 8. Recommendations

- Apply interference correction on raw `feature_intensity` *before*
  normalisation, drift, and batch correction.
- Document every contribution factor and its provenance (theoretical,
  empirical, or published) in the annotation file or a companion
  notebook.
- Re-validate factors after any method change (Q1/Q3 resolution,
  gradient, source temperature).
- For small contributions (\< 1% of target signal) the propagated
  uncertainty often exceeds the removed bias; document the relationship
  but consider leaving it uncorrected.
- After correction, verify blank residual signal approaches zero.

## Next Steps

- [Drift
  Correction](https://slinghub.github.io/MRMhub/quant/articles/tutorial-04-drift-correction.md)
  — apply after interference correction
- [The MRMhub
  Workflow](https://slinghub.github.io/MRMhub/quant/articles/tutorial-02-basic-workflow.md)
  — full processing pipeline
- [Design
  Decisions](https://slinghub.github.io/MRMhub/quant/articles/manual-10-design-decisions.md)
  — rationale for the processing order
- [Feature
  Variables](https://slinghub.github.io/MRMhub/quant/articles/manual-03-feature-variables.md)
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
