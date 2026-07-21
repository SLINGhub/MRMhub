# Drift and Batch Correction

Tutorial

MRMhub provides functions for run-order drift correction, differing by
the employed smoothing algorithm and suited to either QC- or
study-sample-based correction, and for batch-effect correction by median
centering. The data must be provided via an MRMhubExperiment object; raw
data that was imported or processed data can be corrected, such as
`intensity` or `conc` values. These functions have various options for
customization; please refer to the manual page on [Drift and Batch
Correction](https://slinghub.github.io/MRMhub/quant/articles/manual-07-corrections.md)
for more details. This tutorial first demonstrates the drift-correction
methods, then batch-effect correction and how the two are combined.

**Time** ~20 min  ·  **Level** Intermediate  ·  **Prerequisites** [Basic
workflow](https://slinghub.github.io/MRMhub/quant/articles/tutorial-02-basic-workflow.md)

## Import data

In this tutorial, we import pre-calculated raw concentration values from
a CSV file. This file must contain a column with batch information
(`batch_id`) if batch-wise correction should be applied, see
[`import_data_csv_wide()`](https://slinghub.github.io/MRMhub/quant/reference/import_data_csv_wide.md)
for more information.

``` r

library(mrmhub)

myexp <- mrmhub::MRMhubExperiment()

myexp <- import_data_csv_wide(
  myexp,
  path = "smooth-testdata.csv",
  variable_name = "conc",
  import_metadata = TRUE)
```

## QC-based smoothing

We apply a QC-based drift correction using cubic spline. See
[`correct_drift_cubicspline()`](https://slinghub.github.io/MRMhub/quant/reference/correct_drift_cubicspline.md)
for more information.

``` r

mexp_drift <- correct_drift_cubicspline(
  myexp,
  batch_wise = FALSE,
  variable = "conc",
  ref_qc_types = "BQC",
  recalc_trend_after = TRUE)
#> ✔ Applying `conc` drift correction...
#> ✔ Drift correction was applied to 3 of 3 features (across all batches).
#> ℹ The median CV change of all features in study samples was -4.69% (range: -8.21% to 1.17%). The median absolute CV of all features decreased from 30.56% to 28.52%.
```

Next, we inspect the data before and after the correction. We observe
that the green trendline follows the QC samples (in red). After the
correction, the trend has been fully smoothed out, resulting in a
straight line.

``` r

plot_runscatter(mexp_drift, variable = "conc_before", qc_types = c("BQC", "SPL"),
                rows_page = 1, cols_page = 3, show_trend = TRUE)
```

![RunScatter plots before and after batch correction
](tutorial-04-drift-correction_files/figure-html/unnamed-chunk-3-1.png)

``` r

plot_runscatter(mexp_drift, variable = "conc", qc_types = c("BQC", "SPL"),
                rows_page = 1, cols_page = 3, show_trend = TRUE)
```

![RunScatter plots before and after batch correction
](tutorial-04-drift-correction_files/figure-html/unnamed-chunk-3-2.png)

## Sample trend-based smoothing

Above, we observe that the QC samples do not fully represent the trends
of the study samples. This discrepancy can occur when the QC samples,
which often based on pooled samples, differ in handling or properties
from the study samples.

We therefore apply a sample-based drift correction using gaussian kernel
smoothing. See
[`correct_drift_gaussiankernel()`](https://slinghub.github.io/MRMhub/quant/reference/correct_drift_gaussiankernel.md)
for more information.

``` r

mexp_drift <- correct_drift_gaussiankernel(
  myexp,
  variable = "conc",
  kernel_size = 10,
  batch_wise = FALSE,
  ref_qc_types = "SPL",
  recalc_trend_after = TRUE)
#> ✔ Applying `conc` drift correction...
#> ✔ Drift correction was applied to 3 of 3 features (across all batches).
#> ℹ The median CV change of all features in study samples was -6.18% (range: -11.46% to -1.49%). The median absolute CV of all features decreased from 30.56% to 25.86%.
```

Again, we inspect the data before and after the correction. We observe
that the green trendline follows the samples (in grey). After the
correction, the trend has been fully smoothed out, resulting in a
straight line.

``` r

plot_runscatter(mexp_drift, variable = "conc_before", qc_types = c("BQC", "SPL"),
                rows_page = 1, cols_page = 3, show_trend = TRUE)
```

![RunScatter plots before and after batch correction
](tutorial-04-drift-correction_files/figure-html/unnamed-chunk-5-1.png)

``` r

plot_runscatter(mexp_drift, variable = "conc", qc_types = c("BQC", "SPL"),
                rows_page = 1, cols_page = 3, show_trend = TRUE)    
```

![RunScatter plots before and after batch correction
](tutorial-04-drift-correction_files/figure-html/unnamed-chunk-6-1.png)
Now, the trends of the study samples appear to be fairly well corrected.
However, in this example, the differences compared to the previous
QC-based smoothing are not very pronounced.

## Within-batch drift correction

In the examples before we applied drift correction across all batches.
However, if batch-effects are present that break the drifts, it is
recommended to apply drift correction within each batch.

We explore a within-batch drift correction using a sample-based gaussian
kernel smoothing from above in this next example, by setting
`batch_wise = TRUE`.

``` r

mexp_drift <- correct_drift_gaussiankernel(
  myexp,
  variable = "conc",
  kernel_size = 10,
  batch_wise = TRUE,
  ref_qc_types = "SPL",
  recalc_trend_after = TRUE)
#> ✔ Applying `conc` drift correction...
#> ✔ Drift correction was applied to 3 of 3 features (batch-wise).
#> ℹ The median CV change of all features in study samples was -1.20% (range: -1.88% to -0.61%). The median absolute CV of all features across batches decreased from 26.28% to 25.67%.
```

Now, each batch has its own trendline corresponding the trend in each
batch of each feature. Contrary to the previous correction across
batches, we now observe clear differences in the trends still present
after the correction. This is an effect of the correction applied
independently to each batch, due to different sample sizes and present
batch effects. Therefore, it is often necessary to apply batch
correction after batch-wise drift correction

``` r

plot_runscatter(mexp_drift, variable = "conc_before", qc_types = c("BQC", "SPL"),
                rows_page = 1, cols_page = 3, show_trend = TRUE)
```

![RunScatter plots before and after batch correction
](tutorial-04-drift-correction_files/figure-html/unnamed-chunk-8-1.png)

``` r

plot_runscatter(mexp_drift, variable = "conc", qc_types = c("BQC", "SPL"),
                rows_page = 1, cols_page = 3, show_trend = TRUE)
```

![RunScatter plots before and after batch correction
](tutorial-04-drift-correction_files/figure-html/unnamed-chunk-8-2.png)

We therefore apply a subsequent batch correction using median-centering,
resulting in an alignment of the batches.

``` r

mexp_drift <- mrmhub::correct_batch_centering(
  mexp_drift, 
  ref_qc_types = "SPL", 
  variable = "conc",
  correct_scale = TRUE
)
#> ! Adding batch correction on top of `conc` drift-correction.
#> ✔ Batch median-centering of 6 batches was applied to drift-corrected concentrations of all 3 features.
#> ℹ The median CV change of all features in study samples was -5.38% (range: -8.80% to -0.60%).  The median absolute CV of all features decreased from 30.00% to 25.68%.

plot_runscatter(mexp_drift, variable = "conc", qc_types = c("BQC", "SPL"),
                rows_page = 1, cols_page = 3, show_trend = TRUE)
#> Generating plots (1 page)...
```

![RunScatter plots before and after batch correction
](tutorial-04-drift-correction_files/figure-html/unnamed-chunk-9-1.png)

## Batch-effect correction

Batch effects — systematic differences between analytical batches — are
corrected by median centering with
[`correct_batch_centering()`](https://slinghub.github.io/MRMhub/quant/reference/correct_batch_centering.md).
The following example uses a separate dataset of seven batches to show
the effect clearly.

``` r

myexp_batch <- mrmhub::MRMhubExperiment()
myexp_batch <- import_data_csv_wide(
  myexp_batch,
  path = "simdata-u1000-sd100_7batches.csv",
  variable_name = "conc",
  import_metadata = TRUE)
```

The concentration values of each batch are centered on a reference QC
type, here the study samples (`ref_qc_types = "SPL"`). The
`correct_scale` parameter controls whether the batch-to-batch
differences in variance (scale) are also corrected; with
`correct_scale = FALSE` only the median (location) of each batch is
aligned.

``` r

myexp_batch <- correct_batch_centering(
  data = myexp_batch,
  variable = "conc",
  ref_qc_types = "SPL",
  correct_scale = FALSE
)
#> ! Adding batch correction to `conc` data.
#> ✔ Batch median-centering of 7 batches was applied to raw concentrations of all 1 features.
#> ℹ The median CV change of all features in study samples was -30.49% (range: -30.50% to -30.50%).  The median absolute CV of all features decreased from 44.05% to 13.56%.
```

The data before and after batch correction are compared below; the
batches are now aligned. If the study samples or other QC types do not
follow the reference samples, they may not be corrected appropriately.

``` r

plot_runscatter(myexp_batch, variable = "conc_before", rows_page = 1, cols_page = 1)
```

![RunScatter plots before and after batch correction
](tutorial-04-drift-correction_files/figure-html/unnamed-chunk-12-1.png)

``` r

plot_runscatter(myexp_batch, variable = "conc", rows_page = 1, cols_page = 1)
```

![RunScatter plots before and after batch correction
](tutorial-04-drift-correction_files/figure-html/unnamed-chunk-12-2.png)

### Correcting variance as well as location

Although the batches are aligned, the spread (variance) of the points
still varies considerably between batches. This is corrected by scaling
the variance with `correct_scale = TRUE`, after which the spread is
fairly consistent across batches.

``` r

myexp_batch <- mrmhub::correct_batch_centering(
  myexp_batch,
  ref_qc_types = "SPL",
  variable = "conc",
  correct_scale = TRUE
)

plot_runscatter(myexp_batch, variable = "conc", rows_page = 1, cols_page = 1)
```

![RunScatter plot after batch correction with variance scaling
](tutorial-04-drift-correction_files/figure-html/unnamed-chunk-13-1.png)

## Method comparison

`MRMhub` provides four drift correction methods. Loess and cubic spline
are typically used with QC samples as the reference, gaussian kernel
smoothing with study samples; a fourth method, generalized additive
model (GAM) smoothing via
[`correct_drift_gam()`](https://slinghub.github.io/MRMhub/quant/reference/correct_drift_gam.md),
is also available. The method comparison below summarises the typical
use cases of the three most common — see the [Drift and Batch Correction
(reference)](https://slinghub.github.io/MRMhub/quant/articles/manual-07-corrections.md)
for the full parameter description of all four.

| Method | Function | Reference samples | Typical use |
|----|----|----|----|
| Loess | [`correct_drift_loess()`](https://slinghub.github.io/MRMhub/quant/reference/correct_drift_loess.md) | QC samples | Frequent QC injections; smooth trends; robust to single-point outliers |
| Cubic Spline | [`correct_drift_cubicspline()`](https://slinghub.github.io/MRMhub/quant/reference/correct_drift_cubicspline.md) | QC samples | Frequent QC injections; flexible curves; sensitive to outlier QC points |
| Gaussian Kernel | [`correct_drift_gaussiankernel()`](https://slinghub.github.io/MRMhub/quant/reference/correct_drift_gaussiankernel.md) | Study samples | Sparse QCs; only suitable for large, well-randomised sample sets |

## Loess drift correction

Loess uses locally weighted polynomial regression and is less sensitive
to individual outlier QC points than cubic spline. The `span` parameter
controls smoothness (higher = smoother).

``` r

mexp_drift_loess <- correct_drift_loess(
  myexp,
  variable = "conc",
  batch_wise = TRUE,
  ref_qc_types = "BQC",
  recalc_trend_after = TRUE)
#> ✔ Applying `conc` drift correction...
#> ! 4 of 41 TQCs, 3 of 3 LTRs were excluded from correction as they fall outside the regions spanned by the QCs/samples used for smoothing (BQC).
#> ✔ Drift correction was applied to 3 of 3 features (batch-wise).
#> ℹ The median CV change of all features in study samples was 0.33% (range: 0.02% to 1.08%). The median absolute CV of all features across batches increased from 26.28% to 27.36%.
```

Inspect the result with
[`plot_runscatter()`](https://slinghub.github.io/MRMhub/quant/reference/plot_runscatter.md)
before exporting.

## Export corrected data

Next, we can either continue to work with the corrected data using
`MRMhub` functions or export the data.

``` r

save_dataset_csv(
  mexp_drift, 
  path = "drift-batch-corrected-conc-data.csv", 
  variable = "conc", 
  filter_data = FALSE
  )
#> ✔ Concentration values for 498 analyses and 3 features have been exported to 'drift-batch-corrected-conc-data.csv'.
```

## Next steps

- [RunScatter and PCA QC
  exploration](https://slinghub.github.io/MRMhub/quant/articles/tutorial-05-run-scatter.md)
  — visualise run-order and batch effects
- [Drift and Batch Correction
  (reference)](https://slinghub.github.io/MRMhub/quant/articles/manual-07-corrections.md)
  — full method documentation
- [Calibration by Reference
  Sample](https://slinghub.github.io/MRMhub/quant/articles/tutorial-07-calibration-reference.md)
  — normalise to a reference material
