# Derive isotopic interference relationships

Automatically discovers isotopic (M+2) interference relationships
between measured features and stores them in the `annot_interferences`
slot, ready for
[`correct_isotopic_interferences()`](https://slinghub.github.io/MRMhub/quant/reference/correct_isotopic_interferences.md).
Two levels are supported:

- **`"MRM"`** (default): fragment-based front/back correction for
  class-based LC-MRM data, derived from the LICAR method (see the
  manual). Requires precursor **and** product m/z and an `mrm_pattern`
  per feature.

- **`"MS1"`**: whole-molecule M+2 correction for **MS1 / full-scan**
  acquisitions. The factor is the M+2 relative abundance of each
  species' molecular formula; interfering pairs are matched by precursor
  m/z (~2 Da apart) within a feature class. Requires precursor m/z only.

## Usage

``` r
calc_isotopic_interferences(
  data = NULL,
  level = c("MRM", "MS1"),
  mz_tol = 0.5,
  min_contribution = 0,
  check_coelution = FALSE
)
```

## Arguments

- data:

  A `MRMhubExperiment` object.

- level:

  Correction level, `"MRM"` or `"MS1"`. See description.

- mz_tol:

  Precursor m/z tolerance (Da) for matching interfering pairs at the MS1
  level (MRM uses a fixed 2 +/- 0.2 Da precursor window). Default `0.5`.

- min_contribution:

  Drop derived edges whose contribution factor `K` is below this value.
  Default `0` (keep all). Raise to skip negligible or borderline pairs
  (e.g. `0.002`).

- check_coelution:

  *(experimental)* If `TRUE`, an m/z-matched edge is kept only if the
  interferer and victim co-elute – the interferer's peak apex falls
  within the victim's integration window (imported borders
  `feature_int_start`/`feature_int_end`, else `feature_rt +/- FWHM`).
  Chromatographically resolved pairs are dropped. Default `FALSE` while
  the gate is validated.

## Value

The `MRMhubExperiment` with a populated `annot_interferences` slot.

## Details

**Important — MS1 is not a fallback for MRM.** For MRM data the isotopic
correction must be *fragment-based*: the contribution of heavy isotopes
to a transition depends on the isotope's location relative to the
fragmentation (Gao et al. 2021). The whole-molecule (`"MS1"`) level is
only valid for genuine MS1/full-scan measurements and must **not** be
used as a substitute for MRM data that happens to lack a product m/z.

Derived factors are sensitive to the enviPat version; version 2.8 is the
reference. Existing manual interferences (`source == "manual"`) are
preserved; previously derived (`"auto"`) rows are replaced.

### How the contribution factor is computed

The contribution `K` is the fraction of a lighter species' signal that
appears at M+2; it is subtracted downstream by
[`correct_isotopic_interferences()`](https://slinghub.github.io/MRMhub/quant/reference/correct_isotopic_interferences.md)
as \\value\_{corrected} = value\_{raw} - K \cdot value\_{interferer}\\.

- **MS1 (whole-molecule):** \\K = \sum ab(\text{peaks within } \pm 0.5
  \text{ Da of } M_0 + 2)\\ /\\ ab(M_0)\\, computed from the species'
  molecular formula with enviPat `isopattern` (see
  `mN_rel_abundance()`).

- **MRM (fragment-based, LICAR):** the fragment elemental formula is
  built from the precursor carbon/hydrogen count plus a per-class offset
  `c(C, H, O, N)`, with \\H = 2C + c_H - 2 H\_{raw}\\; `K` is that
  fragment's M+2 isotopologue fraction from enviPat `isowrap`
  (centroided, algorithm 2 — chosen over `isopattern` for parity with
  published LICAR values). *Front* vs *back* distinguishes whether the
  heavy isotope lands on the retained product ion or the neutral loss;
  FA/LCB species carry a front + back pair, and LCB inverts the
  front/back assignment relative to FA.

## References

Gao L. et al. (2021). LICAR: An Application for Isotopic Correction of
Targeted Lipidomic Data Acquired with Class-Based Chromatographic
Separations Using Multiple Reaction Monitoring. *Analytical Chemistry*,
93(6), 3163-3171.
[doi:10.1021/acs.analchem.0c04565](https://doi.org/10.1021/acs.analchem.0c04565)
