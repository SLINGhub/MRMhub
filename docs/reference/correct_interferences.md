# Apply interference correction

This function corrects lipidomics feature intensities by subtracting
interference (e.g., isotope overlap or in-source fragments). The
correction is applied using the following formula: \$\$value\\corrected
= value\\raw - value\\raw\\interfering\\feature \times
proportion\\interference\$\$

The interfering features and their relative contributions must be
defined in the feature metadata.

By default, sequential series of interferences (e.g., isotopic M+2
interferences of PC 34:2 \> PC 34:“1 \> PC 34:0) will be corrected in a
sequential manner. This means that the correction will applied
iteratively, starting with the most downstream feature in the series. To
disable this behavior, basing each correction on the raw signal of the
interfering feature set `sequential_correction = FALSE`

## Usage

``` r
correct_interferences(
  data = NULL,
  variable = "feature_intensity",
  sequential_correction = TRUE,
  neg_to_na = FALSE
)
```

## Arguments

- data:

  MRMhubExperiment object containing lipidomics data.

- variable:

  Name of the variable to be corrected. Default: `feature_intensity`.

- sequential_correction:

  A logical indicating whether to apply corrections sequentially,
  starting with the most downstream feature. If `FALSE`, corrections are
  based on the raw signal of the interfering features. If `FALSE`, the
  correction will be based on the raw signal of the interfering feature.

- neg_to_na:

  If `TRUE`, negative or zero values after correction will be replaced
  with `NA`. Default: `FALSE`.

## Value

MRMhubExperiment object with feature intensities corrected for
interferences.

## Details

For isotopic interference correction of MRM/PRM data, the relative
isotope abundances needed for the calculation
('proportion_interference') can be calculated using the LICAR
application (Gao et al., 2021), see below..

## References

Gao L., Ji S, Burla B, Wenk MR, Torta F, Wenk MR, & Cazenave-Gassiot A
(2021). LICAR: An Application for Isotopic Correction of Targeted
Lipidomic Data Acquired with Class-Based Chromatographic Separations
Using Multiple Reaction Monitoring. *Analytical Chemistry*, 93(6),
3163-3171. <https://doi.org/10.1021/acs.analchem.0c04565>
