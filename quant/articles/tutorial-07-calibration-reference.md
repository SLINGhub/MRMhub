# Calibration by a reference sample

Tutorial Prerequisites: [Full
workflow](https://slinghub.github.io/MRMhub/quant/articles/tutorial-03-lipidomics-workflow.md),
[External
calibration](https://slinghub.github.io/MRMhub/quant/articles/tutorial-06-external-calibration.md)

Feature abundances in samples can also be calibrated to corresponding
abundances in a specified reference sample. MRMhub supports absolute
(re-)calibration and normalization (relative calibration).

Absolute calibration of feature abundances is based on known metabolite
concentrations in a reference sample (e.g. NIST SRM1950 plasma).
Normalization (relative calibration) is based on calculating the
abundance ratios of features in samples and a reference sample.

Both absolute and relative calibration are demonstrated below using NIST
SRM1950 plasma samples that were measured as part of the same analysis.

## 1. Import data and metadata

``` r

library(mrmhub)
library(dplyr)

# Get example data paths
dat_file <- system.file("extdata", "S1P_MHQuant.csv", package = "mrmhub")
meta_file <- system.file("extdata", "S1P_metadata_tables.xlsx", package = "mrmhub")

# Load data and metadata
mexp <- MRMhubExperiment()
mexp <- import_data_masshunter(mexp, dat_file, import_metadata = FALSE)
mexp <- import_metadata_analyses(mexp, path = meta_file, sheet = "Analyses")
mexp <- import_metadata_features(mexp, path = meta_file, sheet = "Features")
mexp <- import_metadata_istds(mexp, path = meta_file, sheet = "ISTDs")
```

## 2. Load known concentrations of the reference sample

A table of known analyte concentrations for the NIST SRM1950 reference
sample is added to the `MRMhubExperiment` object. The S1P concentrations
in this table are for illustration only; the actual absolute S1P
concentrations in NIST SRM1950 may differ significantly.

``` r

mexp <- import_metadata_qcconcentrations(mexp, path = meta_file, sheet = "QCconcentrations")
```

    ✔ Analysis metadata associated with 65 analyses.

    ✔ Feature metadata associated with 16 features.

    ✔ Internal Standard metadata associated with 2 ISTDs.

    ✔ QC concentration metadata associated with 1 samples and 6 analytes

## 3. Process the data

The analysis was performed using HILIC chromatography; the isotope
interferences from S1P 18:2;O2 M+2 and S1P 18:1;O2 M+2 must therefore be
corrected. Initial quantification is then done using the spiked-in ISTD
concentration.

``` r

# Isotope-interference correction
mexp <- correct_custom_interferences(mexp)
```

    ✔ Interference correction applied to 4 of 16 feature(s) (0 isotopic, 4 custom edge(s)).

``` r


# Quantify against the internal standards
mexp <- normalize_by_istd(mexp)
```

    ✔ 14 features normalized with 2 ISTDs in 65 analyses.

``` r

mexp <- quantify_by_istd(mexp)
```

    ✔ 14 feature concentrations calculated based on 2 ISTDs and sample amounts of 65 analyses.

    ✔ Concentrations are given in μmol/L.

## 4. Absolute calibration

Absolute re-calibration is performed with
[`calibrate_by_reference()`](https://slinghub.github.io/MRMhub/quant/reference/calibrate_by_reference.md).
The reference sample is set via `reference_sample_id`. Where multiple
analyses of the same reference sample are present in the dataset, either
their mean or median is used (defined via `summarize_fun`).

The calibrated concentration is calculated as:

``` math
c_\text{calibrated}^\text{Analyte} = \frac{c_\text{sample}^\text{Analyte}}{c_\text{ref}^\text{Analyte}} \times c_\text{known}^\text{Analyte}
```

``` r

mexp_res <- calibrate_by_reference(
  data = mexp,
  variable = "conc",
  reference_sample_id = "SRM1950",
  absolute_calibration = TRUE,
  batch_wise = FALSE,
  summarize_fun = "mean",
  undefined_conc_action = "na")
```

    ! One or more feature concentration are not defined in the reference sample SRM1950. `NA` will be returned for these features. To change this, modify `undefined_conc_action` argument.

    ✔ 12 feature concentrations were re-calibrated using the reference sample SRM1950.

    ✔ Concentrations are given in umol/L.

The re-calibrated concentrations are written to the variable `conc`,
overwriting any previously calculated concentrations; the values from
before calibration remain available as `conc_beforecal`. They can be
exported as usual and also appear as concentrations in the MRMhub XLSX
report.

``` r

# Export absolute-calibrated concentrations
save_dataset_csv(mexp_res, tempfile(fileext = ".csv"), variable = "conc")
```

    ✔ Concentration values for 65 analyses and 7 features have been exported to '/tmp/RtmpGJzoKl/file3d474cecf000.csv'.

``` r


# Export non-calibrated concentrations
save_dataset_csv(mexp_res, tempfile(fileext = ".csv"), variable = "conc_beforecal")
```

    ✔ Conc_beforecal values for 65 analyses and 16 features have been exported to '/tmp/RtmpGJzoKl/file3d474eacb882.csv'.

``` r


# Create XLSX report with calibrated concentrations as filtered dataset
save_report_xlsx(mexp_res, tempfile(fileext = ".xlsx"), filtered_variable = "conc")
```

    ✔ The data processing report has been saved to /tmp/RtmpGJzoKl/file3d474eb07800.xlsx.

## 5. Normalization (relative calibration)

Normalization against a reference sample is performed with the same
function, setting `absolute_calibration = FALSE`. Where multiple
analyses of the reference sample are present, either their mean or
median is used (defined via `summarize_fun`).

``` r

mexp_res <- calibrate_by_reference(
  data = mexp,
  variable = "conc",
  reference_sample_id = "SRM1950",
  absolute_calibration = FALSE,
  summarize_fun = "mean")
```

    ✔ All features were normalized with reference sample SRM1950 features.

    ✔ Unit is: sample [conc] / SRM1950 [conc]

Unlike absolute calibration, the normalization results are stored as
**ratios** in a new variable, `[VARIABLE]_normalized`, where
`[VARIABLE]` is the input variable, e.g. `conc_normalized` or
`intensity_normalized`.

The normalized values can be exported as `[VARIABLE]_normalized` with
[`save_dataset_csv()`](https://slinghub.github.io/MRMhub/quant/reference/save_dataset_csv.md).
In the MRMhub XLSX report from
[`save_report_xlsx()`](https://slinghub.github.io/MRMhub/quant/reference/save_report_xlsx.md),
the unfiltered dataset with normalized concentrations is included by
default; to include them as the filtered dataset, set
`filtered_variable = "[VARIABLE]_normalized"`.

``` r

# Export NIST SRM1950-normalized concentrations
save_dataset_csv(mexp_res, "norm.csv", variable = "conc_normalized")
```

    ✔ Conc_normalized values for 65 analyses and 16 features have been exported to 'norm.csv'.

``` r


# Create XLSX report with normalized concentrations as filtered dataset
save_report_xlsx(
  mexp_res,
  path = tempfile(fileext = ".xlsx"),
  filtered_variable = "conc_normalized")
```

    ✔ The data processing report has been saved to /tmp/RtmpGJzoKl/file3d4777adaa91.xlsx.

## 6. Batch-wise calibration

Calibration can also be applied batch-wise, in which case each batch is
calibrated separately using the reference sample in the same batch. Set
`batch_wise = TRUE`; this works for both absolute and relative
calibration. It is useful to correct batches, assays, or plates using a
reference material shared across them.

``` r

mexp_res <- calibrate_by_reference(
  data = mexp,
  variable = "conc",
  reference_sample_id = "SRM1950",
  absolute_calibration = TRUE,
  batch_wise = TRUE,
  summarize_fun = "mean",
  undefined_conc_action = "na")
```

    ! One or more feature concentration are not defined in the reference sample SRM1950. `NA` will be returned for these features. To change this, modify `undefined_conc_action` argument.

    ✔ 12 feature concentrations were batch-wise re-calibrated using the reference sample SRM1950.

    ✔ Concentrations are given in umol/L.

``` r


save_dataset_csv(mexp_res, tempfile(fileext = ".csv"), variable = "conc_beforecal")
```

    ✔ Conc_beforecal values for 65 analyses and 16 features have been exported to '/tmp/RtmpGJzoKl/file3d47640ef292.csv'.

## 7. Concentration ratio and bias

To examine the ratio between measured and expected (known)
concentrations in the reference samples, a table of concentration ratios
can be generated with `store_conc_ratio = TRUE`. The ratio is

``` math
R_\text{ratio}^\text{Analyte} = \frac{c_\text{measured}^\text{Analyte}}{c_\text{expected}^\text{Analyte}}
```

``` r

mexp_res <- calibrate_by_reference(
  data = mexp,
  variable = "conc",
  reference_sample_id = "SRM1950",
  absolute_calibration = TRUE,
  summarize_fun = "mean",
  undefined_conc_action = "na",
  store_conc_ratio = TRUE)
```

    ! One or more feature concentration are not defined in the reference sample SRM1950. `NA` will be returned for these features. To change this, modify `undefined_conc_action` argument.

    ✔ 12 feature concentrations were re-calibrated using the reference sample SRM1950.

    ✔ Concentrations are given in umol/L.

``` r


tbl_ref_bias <- mexp_res$dataset |>
  filter(sample_id == "SRM1950", is_quantifier) |>
  group_by(feature_id) |>
  summarise(bias_mean = mean(feature_conc_ratio))

gt::gt(tbl_ref_bias)
```

| feature_id                        | bias_mean |
|-----------------------------------|-----------|
| S1P d16:1 \[M\>60\]               | 0.4323975 |
| S1P d17:1 \[M\>60\]               | 0.3452700 |
| S1P d18:0 \[M\>60\]               | 0.2917255 |
| S1P d18:1 13C2D2 (ISTD) \[M\>60\] | NA        |
| S1P d18:1 \[M\>60\]               | 0.3453086 |
| S1P d18:2 \[M\>60\]               | 0.3554366 |
| S1P d19:1 \[M\>60\]               | 0.3081062 |
| S1P d20:1 \[M\>60\]               | NA        |

A ratio of 1 indicates perfect agreement between the measured and
expected concentrations; values above 1 suggest overestimation and
values below 1 underestimation. The ratios can also be visualised or
analysed further to identify outliers or investigate issues in the
analytical process or calibration.

The ratio and bias of QC samples can also be obtained directly, without
applying
[`calibrate_by_reference()`](https://slinghub.github.io/MRMhub/quant/reference/calibrate_by_reference.md).
For illustration we compute them on the re-calibrated data above, where
all corrected feature concentrations in the reference sample are
expected to have no bias (0%) and a ratio of 1.

``` r

tbl <- get_qc_bias_variability(mexp_res, qc_types = "NIST")
gt::gt(tbl) |> gt::fmt_number(decimals = 3)
```

| feature_id | sample_id | qc_type | n | conc_target | conc_mean | conc_sd | cv_intra | bias |
|----|----|----|----|----|----|----|----|----|
| S1P d16:1 \[M\>60\] | SRM1950 | NIST | 2.000 | 0.107 | 0.107 | 0.016 | 14.771 | 0.000 |
| S1P d17:1 \[M\>60\] | SRM1950 | NIST | 2.000 | 0.028 | 0.028 | 0.001 | 3.550 | 0.000 |
| S1P d18:0 \[M\>60\] | SRM1950 | NIST | 2.000 | 0.149 | 0.149 | 0.001 | 0.995 | 0.000 |
| S1P d18:1 \[M\>60\] | SRM1950 | NIST | 2.000 | 0.985 | 0.985 | 0.000 | 0.040 | 0.000 |
| S1P d18:2 \[M\>60\] | SRM1950 | NIST | 2.000 | 0.290 | 0.290 | 0.004 | 1.460 | 0.000 |
| S1P d19:1 \[M\>60\] | SRM1950 | NIST | 2.000 | 0.025 | 0.025 | 0.002 | 9.713 | 0.000 |

The bias and concentration ratios before re-calibration can be viewed
from the `MRMhubExperiment` object that had no calibration applied.

``` r

tbl <- get_qc_bias_variability(mexp, qc_types = "NIST", with_conc_ratio = TRUE)
gt::gt(tbl) |> gt::fmt_number(decimals = 3)
```

| feature_id | sample_id | qc_type | n | conc_target | conc_mean | conc_sd | cv_intra | bias | conc_ratio |
|----|----|----|----|----|----|----|----|----|----|
| S1P d16:1 \[M\>60\] | SRM1950 | NIST | 2.000 | 0.107 | 0.046 | 0.007 | 14.771 | −56.760 | 0.432 |
| S1P d17:1 \[M\>60\] | SRM1950 | NIST | 2.000 | 0.028 | 0.010 | 0.000 | 3.550 | −65.473 | 0.345 |
| S1P d18:0 \[M\>60\] | SRM1950 | NIST | 2.000 | 0.149 | 0.043 | 0.000 | 0.995 | −70.827 | 0.292 |
| S1P d18:1 \[M\>60\] | SRM1950 | NIST | 2.000 | 0.985 | 0.340 | 0.000 | 0.040 | −65.469 | 0.345 |
| S1P d18:2 \[M\>60\] | SRM1950 | NIST | 2.000 | 0.290 | 0.103 | 0.002 | 1.460 | −64.456 | 0.355 |
| S1P d19:1 \[M\>60\] | SRM1950 | NIST | 2.000 | 0.025 | 0.008 | 0.001 | 9.713 | −69.189 | 0.308 |

## Next steps

- [External calibration and
  QC](https://slinghub.github.io/MRMhub/quant/articles/tutorial-06-external-calibration.md):
  full calibration-curve workflow with QC
- [Lipidomics
  workflow](https://slinghub.github.io/MRMhub/quant/articles/tutorial-03-lipidomics-workflow.md):
  revisit the full pipeline
