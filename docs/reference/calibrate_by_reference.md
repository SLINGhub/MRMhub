# Calibrate feature values using a reference sample

This function calibrates feature abundances based on a specified
reference sample. Calibration can be applied to the entire dataset using
one or more reference samples, or batch-wise using reference sample
analyses present within each batch. For both approaches, multiple
measurements of the same reference sample are summarized using either
`mean` (default) or `median` (set by the `summarize_fun` argument).

## Usage

``` r
calibrate_by_reference(
  data,
  variable,
  reference_sample_id,
  absolute_calibration,
  batch_wise = FALSE,
  summarize_fun = "mean",
  store_conc_ratio = NULL,
  undefined_conc_action = NULL,
  store_normalized = FALSE
)
```

## Arguments

- data:

  A `MRMhubExperiment` object containing the metabolomics data to be
  normalized

- variable:

  Character string indicating which data type to calibrate Must be one
  of: "intensity", "norm_intensity", or "conc"

- reference_sample_id:

  Character vector specifying the sample ID(s) to use as reference(s) or
  standards

- absolute_calibration:

  Logical indicating whether to perform absolute calibration using known
  concentrations of the reference sample (TRUE) or relative calibration
  (FALSE).

- batch_wise:

  Logical indicating whether to perform calibration for each batch
  seperately (TRUE) or for all samples together (FALSE).

- summarize_fun:

  Either "mean" or "median". If `absolute_calibration = TRUE`, this
  function is used to summarize the reference sample concentrations
  across analyses of specified `reference_sample_id`. Default is "mean".

- store_conc_ratio:

  Logical. Whether to store the ratio of measured (non-calibrated)
  compared to the expected (known) concentrations. Only applied if
  `absolute_calibration = TRUE`. This ratio is stored under the feature
  variable `feature_conc_ratio`. By default it is `TRUE` when
  `variable = 'conc'`, otherwise `FALSE`.

- undefined_conc_action:

  Character string specifying how to handle features without defined
  concentrations in reference samples when
  `absolute_calibration = TRUE`. Must be one of `"original"` (keep
  original values), `"na"` (set to `NA`), or `"error"`. Required when
  `absolute_calibration = TRUE` (no default).

- store_normalized:

  Logical indicating whether to keep the normalized values in the
  dataset when `absolute_calibration = TRUE`. Default is FALSE. These
  values are then stored as `[VARIABLE]_normalized`, where `[VARIABLE]`
  is the input variable, e.g., `conc`.

## Value

A `MRMhubExperiment` object with calibrated data

## Details

Calibration can be performed in two ways, either absolute, resulting in
concentrations, or relative, resulting in ratios:

1.  Absolute calibration (when `absolute_calibration = TRUE`)

    Calibrates (or re-calibrates) feature abundances based on known
    concentrations of the corresponding features defined for a reference
    sample. The calibrated concentration for a given analyte is
    calculated as:

    \$\$c\_\textrm{cal}^\textrm{Analyte} =
    \frac{c\_\textrm{sample}^\textrm{Analyte}}{c\_\textrm{ref}^\textrm{Analyte}}
    \times c\_\textrm{known}^\textrm{Analyte}\$\$

    The input variable can either `conc`, `norm_intensity`, or
    `intensity, whereas the result will always be stored under the variable`conc\`
    (concentration), in the unit defined for the feature concentrations
    in the reference sample.

    Metadata requirements:

    - `sample_id` and `analyte_id` must be defined for the reference
      sample and features in the analysis and feature metadata,
      respectively.

    - Known analyte concentrations must be defined in the
      `QC concentration` metadata for the for the reference sample

    - An error will be raised if no concentrations are defined for any
      features

    Missing analyte concentrations for the reference sample can be
    handled via `undefined_conc_action` with following options:

    - `original`: Keep original feature values, i.e. the non-calibrated
      values will be returned. *Note*: this is only available when
      `variable = conc`. Use with caution to avoid mixing units.

    - `na`: Set affected features values to `NA`

    - `error`: The function stops with error in case of any undefined
      reference sample feature concentration.

    - In case all feature concentrations are undefined, the function
      will stop with an error.

    The re-calibrated feature concentrations are stored as `conc`,
    overwriting existing `conc` values. The original `conc` values are
    stored as `conc_beforecal`.

    The ratio between the measured and expected (known) concentrations
    in the reference sample is available via the feature variable
    `feature_conc_ratio` and is calculated as follows:

    \$\$c\_\textrm{ratio}^\textrm{Analyte} =
    \frac{c\_\textrm{measured}^\textrm{Analyte}}{c\_\textrm{expected}^\textrm{Analyte}}\$\$

    where \\c\_\textrm{measured}\\ is the measured (non-calibrated)
    concentration, and \\c\_\textrm{expected}\\ is the known or
    reference concentration for the same analyte. A bias value of 1
    indicates perfect agreement; values above or below 1 indicate over-
    or underestimation.

    To export the calibrated concentrations use
    [`save_dataset_csv()`](https://slinghub.github.io/MRMhub/quant/reference/save_dataset_csv.md)
    with
    `variable = "conc", or to export non-calibrated values with `variable
    =
    "conc_beforecal"`. When saving the MRMhub XLSX report, the calibrated concentrations will also be stored as `conc\`.

2.  Normalization (relative calibration, `absolute_calibration = FALSE`)

    Normalizes features abundances with corresponding feature abundances
    in a reference sample, resulting in ratios. Any available feature
    abundance variable (i.e., `conc`, `norm_intensity`, or `intensity`)
    can be used as input. The normalization is calculate for all present
    features. The resulting output will be stored as
    `[VARIABLE]_normalized`, whereby `[VARIABLE]` is the input variable,
    e.g., `conc_normalized`.

    To export the normalized abundances , use
    [`save_dataset_csv()`](https://slinghub.github.io/MRMhub/quant/reference/save_dataset_csv.md)
    with `variable = "[VARIABLE]_normalized"` For MRMhub XLSX report,
    use
    [`save_report_xlsx()`](https://slinghub.github.io/MRMhub/quant/reference/save_report_xlsx.md)
    with same variable setting as for
    [`save_dataset_csv()`](https://slinghub.github.io/MRMhub/quant/reference/save_dataset_csv.md)
    to When saving the MRMhub XLSX report via
    [`save_report_xlsx()`](https://slinghub.github.io/MRMhub/quant/reference/save_report_xlsx.md),
    availble unfiltered normalized feature abundances will be included
    by default. To include filtered normalized feature abundances, set
    `filtered_variable = "[VARIABLE]_normalized"`.

## See also

[`normalize_by_istd()`](https://slinghub.github.io/MRMhub/quant/reference/normalize_by_istd.md),
[`quantify_by_istd()`](https://slinghub.github.io/MRMhub/quant/reference/quantify_by_istd.md),
[`quantify_by_calibration()`](https://slinghub.github.io/MRMhub/quant/reference/quantify_by_calibration.md)
