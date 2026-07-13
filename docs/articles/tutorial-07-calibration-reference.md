# Calibration by a Reference Sample

Tutorial

Feature abundances in samples can also be calibrated to corresponding
abundances in a specified reference sample. MRMhub supports absolute
(re-)calibration and normalization (relative calibration).

Absolute calibration of feature abundances is based on known metabolite
concentrations in a reference sample (e.g., NIST SRM1950 plasma).
Normalization (relative calibration) is based on calculating the
abundance ratios of features in samples and a reference sample.

Both absolute and relative calibration are demonstrated below using NIST
SRM1950 plasma samples that were measured as part of the same analysis.

**Time:** ~15 min  \|  **Level:** Intermediate  \|  **Prerequisites:**
[Basic
workflow](https://slinghub.github.io/MRMhub/quant/articles/tutorial-02-basic-workflow.md)

## Import data and metadata

``` r

library(mrmhub)
library(dplyr)

# Get example data paths
dat_file = system.file("extdata", "S1P_MHQuant.csv", package = "mrmhub")
meta_file = system.file("extdata", "S1P_metadata_tables.xlsx", package = "mrmhub")

# Load data and metadata
mexp <- MRMhubExperiment()
mexp <- import_data_masshunter(mexp, dat_file, import_metadata = FALSE)
mexp <- import_metadata_analyses(mexp, path = meta_file, sheet = "Analyses")
mexp <- import_metadata_features(mexp, path = meta_file, sheet = "Features")
mexp <- import_metadata_istds(mexp, path = meta_file, sheet = "ISTDs")
```

## Load known analyte concentrations of the reference sample

A table of known analyte concentrations for the NIST SRM1950 reference
sample is added to the `MRMhubExperiment object`. Note that the S1P
concentrations in this table are for illustration only; the actual
absolute S1P concentrations in NIST SRM1950 may differ significantly.

``` r

mexp <- import_metadata_qcconcentrations(mexp, path = meta_file, sheet = "QCconcentrations")
#> ! Metadata has following warnings and notifications:
#> ✔ Analysis metadata associated with 65 analyses.
#> ✔ Feature metadata associated with 16 features.
#> ✔ Internal Standard metadata associated with 2 ISTDs.
#> ✔ QC concentration metadata associated with 1 annotated samples and 6 annotated analytes
```

## Process the data

The analysis was performed using HILIC chromatography; the isotope
interferences from S1P 18:2;O2 M+2 and S1P 18:1;O2 M+2 must therefore be
corrected. Initial quantification is then done using the spiked-in ISTD
concentration.

``` r

# Isotope correction
mexp <- mrmhub::correct_interferences(mexp)
#> ✔ Interference-correction has been applied to 4 of the 16 features.

# Quantify the data
mexp <- normalize_by_istd(mexp)
#> ✔ 14 features normalized with 2 ISTDs in 65 analyses.
mexp <- quantify_by_istd(mexp)
#> ✔ 14 feature concentrations calculated based on 2 ISTDs and sample amounts of 65 analyses.
#> ℹ Concentrations are given in μmol/L.
```

## Absolute calibration

Absolute re-calibration is performed with the function
[`calibrate_by_reference()`](https://slinghub.github.io/MRMhub/quant/reference/calibrate_by_reference.md).
The reference sample is set via `reference_sample_id`. Where multiple
analyses of the same reference sample are present in the dataset, either
the mean or median is calculated (defined via `summarize_fun`).

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
    undefined_conc_action = "na"
  )
#> ! One or more feature concentration are not defined in the reference sample SRM1950. `NA` will be returned for these features. To change this, modify `undefined_conc_action` argument.
#> ✔ 6 feature concentrations were re-calibrated using the reference sample SRM1950.
#> ℹ Concentrations are given in umol/L.
```

The re-calibrated concentrations are stored in the variable `conc` ,
overwriting any previously calculated concentrations. The original
concentrations, however, are still available via the variable
`conc_beforecal`.

The re-calibrated concentrations can be exported as usual, and they also
appear in the MRMhub XLSX report as concentrations.

``` r

# Export absolute calibration concentrations
save_dataset_csv(mexp, tempfile(fileext = ".csv"), variable = "conc")
#> ✔ Concentration values for 65 analyses and 7 features have been exported to '/var/folders/3r/ywcsb3896zj4_0xlb_70yvlh0000gn/T//RtmppmlkyP/file178611991f708.csv'.
  
# Export non-calibrated concentrations
save_dataset_csv(mexp_res, tempfile(fileext = ".csv"), variable = "conc_beforecal")
#> ✔ Conc_beforecal values for 65 analyses and 16 features have been exported to '/var/folders/3r/ywcsb3896zj4_0xlb_70yvlh0000gn/T//RtmppmlkyP/file178613df13b55.csv'.

# Create XLSX report with calibrated concentrations as filtered dataset
save_report_xlsx(mexp_res, tempfile(fileext = ".xlsx"), filtered_variable = "conc")
#> Saving report to disk - please wait...
#> ✔ The data processing report has been saved to '/var/folders/3r/ywcsb3896zj4_0xlb_70yvlh0000gn/T//RtmppmlkyP/file17861286e6938.xlsx'.
```

## Normalization (relative calibration)

Normalization with a reference sample is performed with the
[`calibrate_by_reference()`](https://slinghub.github.io/MRMhub/quant/reference/calibrate_by_reference.md)
function, setting `absolute_calibration = FALSE`. As above, where
multiple analyses of the same reference sample are present in the
dataset, either the mean or median is calculated (defined via
`summarize_fun`).

``` r

mexp_res <- calibrate_by_reference(
    data = mexp,
    variable = "conc",
    reference_sample_id = "SRM1950",
    absolute_calibration = FALSE,
    summarize_fun = "mean"
  )
#> ✔ All features were normalized with reference sample SRM1950 features.
#> ℹ Unit is: sample [conc] / SRM1950 [conc]
```

The results of the normalization are stored, unlike for the absolute
calibration, as ratios, in a new variable, `[VARIABLE]_normalized`,
where
``` math
VARIABLE
```
is the input variable, e.g., `conc_normalized` or
`intensity_normalized`.

The normalized concentrations can be exported as
``` math
VARIABLE
```
\_normalized using
[`save_dataset_csv()`](https://slinghub.github.io/MRMhub/quant/reference/save_dataset_csv.md).
In the MRMhub XLSX report generated by
[`save_report_xlsx()`](https://slinghub.github.io/MRMhub/quant/reference/save_report_xlsx.md),
the unfiltered dataset with normalized concentrations is included by
default. To include the normalized concentrations as the filtered
dataset, set `filtered_variable = “[VARIABLE]_normalized` as an
argument.

``` r

# Export NIST1950-normalized concentrations
save_dataset_csv(mexp_res, "norm.csv", variable = "conc_normalized")
#> ✔ Conc_normalized values for 65 analyses and 16 features have been exported to 'norm.csv'.

# Create XLSX report with normalized concentrations as filtered dataset
save_report_xlsx(mexp_res, path = tempfile(fileext = ".xlsx"), filtered_variable = "conc_normalized")
#> Saving report to disk - please wait...
#> ✔ The data processing report has been saved to '/var/folders/3r/ywcsb3896zj4_0xlb_70yvlh0000gn/T//RtmppmlkyP/file178613b84c59d.xlsx'.
```

## Batch-wise calibration

Calibration can also be applied batch-wise, in which case each batch is
calibrated separately with the data from the reference sample in the
same batch. This is done by setting `batch_wise = TRUE` and can be used
in both absolute and relative calibration.

This approach can be used to correct batches or assays/plates using a
reference material shared across the batches.

``` r

mexp_res <- calibrate_by_reference(
    data = mexp,
    variable = "conc",
    reference_sample_id = "SRM1950",
    absolute_calibration = TRUE,
    batch_wise = TRUE,
    summarize_fun = "mean",
    undefined_conc_action = "na"
  )
#> ! One or more feature concentration are not defined in the reference sample SRM1950. `NA` will be returned for these features. To change this, modify `undefined_conc_action` argument.
#> ✔ 6 feature concentrations were batch-wise re-calibrated using the reference sample SRM1950.
#> ℹ Concentrations are given in umol/L.

save_dataset_csv(mexp_res, tempfile(fileext = ".csv"), variable = "conc_beforecal")
#> ✔ Conc_beforecal values for 65 analyses and 16 features have been exported to '/var/folders/3r/ywcsb3896zj4_0xlb_70yvlh0000gn/T//RtmppmlkyP/file1786149723bdd.csv'.
```

## Concentration ratio and bias

To examine the ratio between measured and expected (known)
concentrations in the reference samples, a table with concentration
ratios can be generated using the code below.

The ratio is calculated as follows:

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
    store_conc_ratio = TRUE
  )
#> ! One or more feature concentration are not defined in the reference sample SRM1950. `NA` will be returned for these features. To change this, modify `undefined_conc_action` argument.
#> ✔ 6 feature concentrations were re-calibrated using the reference sample SRM1950.
#> ℹ Concentrations are given in umol/L.

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

A ratio value of 1 indicates perfect agreement between the measured and
expected concentrations.\
Values greater than 1 suggest overestimation, while values less than 1
indicate underestimation.\
The ratio values can also be visualized or further analyzed to identify
outliers or investigate potential issues in the analytical process or
calibration.

The ratio and bias of QC samples can also be calculated directly,
without applying
[`calibrate_by_reference()`](https://slinghub.github.io/MRMhub/quant/reference/calibrate_by_reference.md).
For illustration, the ratio and bias of the QC samples are calculated
using the re-calibrated data from above; all corrected feature
concentrations in the reference sample are expected to have no bias (0%)
and a ratio of 1.

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

The bias and concentration ratios before the re-calibration can be
viewed by using the `MRMhubExperiment` object that had no calibration
applied

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

- [External Calibration &
  QC](https://slinghub.github.io/MRMhub/quant/articles/recipe-01-ext-calibration-qc.md)
  — full calibration workflow with QC
- [Basic MRMhub
  Workflow](https://slinghub.github.io/MRMhub/quant/articles/tutorial-02-basic-workflow.md)
  — revisit the full pipeline
