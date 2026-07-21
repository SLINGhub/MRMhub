# Correct automatically derived isotopic interferences

Applies the isotopic (M+2) interference corrections previously
discovered by
[`calc_isotopic_interferences()`](https://slinghub.github.io/MRMhub/quant/reference/calc_isotopic_interferences.md)
(and any declared interferences, see
[`correct_custom_interferences()`](https://slinghub.github.io/MRMhub/quant/reference/correct_custom_interferences.md))
to the raw feature intensities. Aborts with guidance if no interferences
have been derived yet.

The subtraction is \$\$value\_{corrected} = value\_{raw} - K \cdot
value\_{interferer}\$\$ applied on the raw `feature_intensity`. For
auto-derived (`source == "auto"`) edges the interferer is clamped at 0
before subtraction and the result clamped at 0 (LICAR parity); declared
(`"manual"`) edges are unclamped. See
[`calc_isotopic_interferences()`](https://slinghub.github.io/MRMhub/quant/reference/calc_isotopic_interferences.md)
for how `K` is computed.

A chain (e.g. PC 34:2 \> PC 34:1 \> PC 34:0) is corrected sequentially
by default, each feature using its already-corrected interferer; set
`sequential_correction = FALSE` to correct each from the raw interferer.
The raw signal is preserved in `feature_intensity_orig`, and the
correction is idempotent (re-running restores from raw first).

## Usage

``` r
correct_isotopic_interferences(
  data = NULL,
  variable = "feature_intensity",
  sequential_correction = TRUE,
  neg_to_na = FALSE
)
```

## Arguments

- data:

  MRMhubExperiment object.

- variable:

  Name of the variable to correct. Only `"feature_intensity"` (the raw
  intensity) is supported. Default: `"feature_intensity"`.

- sequential_correction:

  Logical. If `TRUE` (default), a chain of interferences is corrected
  sequentially so each feature uses the already-corrected signal of its
  interferer (propagates along the chain). If `FALSE`, each feature is
  corrected from the raw interferer, without propagation.

- neg_to_na:

  If `TRUE`, negative or zero values after correction are replaced with
  `NA`. Default: `FALSE`.

## Value

MRMhubExperiment object with feature intensities corrected.

## References

Gao L., Ji S, Burla B, Wenk MR, Torta F, & Cazenave-Gassiot A (2021).
LICAR: An Application for Isotopic Correction of Targeted Lipidomic Data
Acquired with Class-Based Chromatographic Separations Using Multiple
Reaction Monitoring. *Analytical Chemistry*, 93(6), 3163-3171.
<https://doi.org/10.1021/acs.analchem.0c04565>
