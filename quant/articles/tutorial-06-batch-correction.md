# Batch-effect correction

MRMhub currently supports median centering-based batch effect
correction.

The data must be provided via a MRMhubExperiment object, whereby raw
data that was imported or processed data can be corrected, such as
`intensity` or `conc` values.

**Time:** ~10 min  \|  **Level:** Intermediate  \|  **Prerequisites:**
[Basic
workflow](https://slinghub.github.io/MRMhub/quant/articles/tutorial-02-basic-workflow.md)

## Import data

This tutorial imports pre-calculated concentration values from a CSV
file. The file must contain a column with batch information
(`batch_id`); see
[`import_data_csv_wide()`](https://slinghub.github.io/MRMhub/quant/reference/import_data_csv_wide.md)
for details.

``` r

library(mrmhub)

myexp <- mrmhub::MRMhubExperiment()

myexp <- import_data_csv_wide(
  myexp,
  path = "simdata-u1000-sd100_7batches.csv",
  variable_name = "conc",
  import_metadata = TRUE)
```

## Apply batch-centering

The concentration values of each batch are centered on a reference QC
type, here the samples (`ref_qc_types = "SPL"`). The `correct_scale`
parameter controls whether the batch-to-batch differences in variance
(scale) are also corrected. Here it is set to `FALSE`, so only the
median (location) of each batch is aligned; variance scaling is
disabled.

``` r

myexp <- correct_batch_centering(
  data = myexp, 
  variable = "conc",
  ref_qc_types = "SPL", 
  correct_scale = FALSE
)
#> ℹ Adding batch correction to `conc` data.
#> ✔ Batch median-centering of 7 batches was applied to raw concentrations of all 1 features.
#> ℹ The median CV change of all features in study samples was -30.49% (range: -30.50% to -30.50%).  The median absolute CV of all features decreased from 44.05% to 13.56%.
```

The data before and after batch correction are compared below. The
batches are now aligned. Note: if the samples or other quality control
types do not follow the reference samples, they may not be corrected
appropriately.

``` r

plot_runscatter(myexp, variable = "conc_before", rows_page = 1, cols_page = 1)
```

![RunScatter plots before and after batch correction
](tutorial-06-batch-correction_files/figure-html/unnamed-chunk-3-1.png)

``` r

plot_runscatter(myexp, variable = "conc", rows_page = 1, cols_page = 1)
```

![RunScatter plots before and after batch correction
](tutorial-06-batch-correction_files/figure-html/unnamed-chunk-3-2.png)

## Batch-centering with variance scaling

Although the batches are aligned, the spread (variance) of the data
points varies considerably between the batches. This can be corrected by
scaling the variance via `correct_scale = TRUE`. In the plot below, the
variance of the data points is now fairly consistent across the batches.

``` r

myexp <- mrmhub::correct_batch_centering(
  myexp, 
  ref_qc_types = "SPL", 
  variable = "conc",
  correct_scale = TRUE
)
#> ℹ Replacing previous `conc` batch correction.
#> ✔ Batch median-centering of 7 batches was applied to raw concentrations of all 1 features.
#> ℹ The median CV change of all features in study samples was -32.20% (range: -32.20% to -32.20%).  The median absolute CV of all features decreased from 44.05% to 11.85%.
```

``` r

plot_runscatter(myexp, variable = "conc", rows_page = 1, cols_page = 1)
```

![RunScatter plots before and after batch correction
](tutorial-06-batch-correction_files/figure-html/unnamed-chunk-5-1.png)

## Export batch-corrected data

The corrected data can be processed further with `MRMhub` functions, or
exported.

``` r

save_dataset_csv(
  myexp, 
  path = "batch-corrected-conc-data.csv", 
  variable = "conc", 
  filter_data = FALSE
  )
#> ✔ Concentration values for 700 analyses and 1 features have been exported to 'batch-corrected-conc-data.csv'.
```

## Next Steps

- [Drift
  Correction](https://slinghub.github.io/MRMhub/quant/articles/tutorial-04-drift-correction.md)
  — correct signal drift within a batch
- [Calibration by Reference
  Sample](https://slinghub.github.io/MRMhub/quant/articles/tutorial-07-calibration-reference.md)
  — normalise to a reference
- [External Calibration &
  QC](https://slinghub.github.io/MRMhub/quant/articles/recipe-01-ext-calibration-qc.md)
  — quantify with calibration curves
