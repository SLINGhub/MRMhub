# Derive isotopic interference relationships

Automatically discovers isotopic (M+2) interference relationships
between measured features and stores them in the `annot_interferences`
slot, ready for
[`correct_interferences()`](https://slinghub.github.io/MRMhub/quant/reference/correct_interferences.md).
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
derive_interferences(
  data = NULL,
  level = c("MRM", "MS1"),
  mz_tol = 0.5,
  check_coelution = TRUE
)
```

## Arguments

- data:

  A `MRMhubExperiment` object.

- level:

  Correction level, `"MRM"` or `"MS1"`. See description.

- mz_tol:

  Precursor m/z tolerance (Da) for matching interfering pairs. Default
  `0.5`.

- check_coelution:

  If `TRUE` (default, when retention data are present), an m/z-matched
  edge is kept only if the interferer and victim co-elute – the
  interferer's peak apex falls within the victim's integration window.
  Chromatographically resolved pairs are dropped (subtracting them would
  remove real signal). Uses the imported integration borders
  (`feature_int_start`/`feature_int_end`), falling back to
  `feature_rt +/- FWHM`.

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

## References

Gao L. et al. (2021). LICAR: An Application for Isotopic Correction of
Targeted Lipidomic Data Acquired with Class-Based Chromatographic
Separations Using Multiple Reaction Monitoring. *Analytical Chemistry*,
93(6), 3163-3171.
[doi:10.1021/acs.analchem.0c04565](https://doi.org/10.1021/acs.analchem.0c04565)
