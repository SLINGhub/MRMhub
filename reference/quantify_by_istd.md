# Calculate Analyte Concentrations Using Internal Standards

This function calculates analyte concentrations based on internal
standard (ISTD) normalized intensities and the corresponding spiked-in
ISTD amount, normalized by the sample amount.

## Usage

``` r
quantify_by_istd(
  data = NULL,
  concentration_unit = "molar",
  ignore_missing_annotation = FALSE,
  ignore_istds = FALSE
)
```

## Arguments

- data:

  A `MRMhubExperiment` object

- concentration_unit:

  Character string indicating the type of concentration to calculate and
  export. Must be either `"molar"` for molar concentrations (e.g.,
  µmol/L) or `"mass"` for mass concentrations (e.g., µg/L).

- ignore_missing_annotation:

  If `FALSE`, an error will be raised if any of the following
  information is missing: ISTD concentration, ISTD mix volume, and
  sample amounts for any feature. If `TRUE`, missing annotations will be
  ignored, and resulting feature concentration will be `NA`

- ignore_istds:

  If `TRUE`, ISTD features will be ignored in the concentration
  calculation and the resulting concentration will be `NA`. Default is
  `FALSE`.

## Value

A `MRMhubExperiment` object with the calculated analyte concentrations
added to the `dataset` table in the `feature_conc` column.

## Details

By default, concentrations are returned in molar units (e.g., µmol/L).
To return concentrations in mass units (e.g., µg/L), set
`concentration_unit = "mass"`. This requires either the chemical formula
or molecular weight for each feature to be specified in the feature
metadata.

Internal standard concentrations can also be provided in `ng/mL`. In
such cases, the function will convert these concentrations to molar
units for internal calculations. Here too, either the chemical formula
or the molecular weight must be defined for each ISTD in the feature
metadata.

The unit of the calculated concentrations is determined by the
`concentration_unit` argument and the `sample_amount_unit` field in the
analysis metadata of the `MRMhubExperiment` object. The function will
automatically adjust the sample amount to the appropriate unit based on
the provided `concentration_unit`. For example, if
`concentration_unit = "molar"` and `sample_amount_unit = "uL"`, the
calculated concentrations will be in µmol/L. If
`concentration_unit = "mass"`, the concentrations will be in `µg/L`.

The calculated concentrations are added to the `dataset` table as a new
column named `feature_conc`..

## See also

[`quantify_by_calibration()`](https://slinghub.github.io/MRMhub/reference/quantify_by_calibration.md)
for calculating concentrations based on external calibration curves.
