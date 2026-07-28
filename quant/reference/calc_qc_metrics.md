# Calculate quality control (QC) metrics for features

Computes various quality control (QC) metrics for each feature in a
`MRMhubExperiment` object. Metrics are derived from different sample
types and can be computed either across the full dataset or as medians
of batch-wise calculations.

## Usage

``` r
calc_qc_metrics(
  data = NULL,
  use_batch_medians = FALSE,
  use_robust_cv = FALSE,
  include_norm_intensity_stats = NA,
  include_conc_stats = NA,
  include_response_stats = NA,
  include_calibration_results = NA
)
```

## Arguments

- data:

  A
  [`MRMhubExperiment`](https://slinghub.github.io/MRMhub/quant/reference/MRMhubExperiment-class.md)
  object containing data and metadata, whereby data needs to be
  normalized and quantitated for specific QC metrics, such as statistics
  based on normalized intensities and concentrations.

- use_batch_medians:

  Logical, whether to compute QC metrics using the median of batch-wise
  derived values instead of the full dataset. Default is `FALSE`.

- use_robust_cv:

  Logical, whether to use robust coefficient of variation (MAD/median)
  or the standard coefficient of variation (SD/mean) for intensity,
  norm_intensity and concentration metrics.

- include_norm_intensity_stats:

  Logical. If `NA` (default), statistics on normalized intensity values
  are included if the data is available. If `TRUE`, they are always
  calculated, raising an error if data is missing.

- include_conc_stats:

  Logical. If `NA` (default), concentration-related statistics are
  included if concentration data is available. If `TRUE`, they are
  always calculated, raising an error if data is missing.

- include_response_stats:

  Logical. If `NA` (default), response curve statistics are included if
  the required data is available. If `TRUE`, they are always calculated,
  raising an error if data is missing.

- include_calibration_results:

  Logical. If `NA` (default), external calibration results are
  incorporated into the QC metrics table if available. If `TRUE`, they
  are always incorporated.

## Value

A
[`MRMhubExperiment`](https://slinghub.github.io/MRMhub/quant/reference/MRMhubExperiment-class.md)
object with an updated `metrics_qc` table containing computed QC metrics
for each feature.

## Details

**Batch-wise calculations**: The function computes the following QC
metrics for each feature and for different QC sample types (e.g., SPL,
TQC, BQC, PBLK, NIST, LTR)

The format for the metrics is standardized as `metric_name_qc_type`,
where `qc_type` refers to the specific QC sample type for which the
metric is calculated. For example: `intensity_min_spl` refers to the
minimum intensity Statistics of normalized intensities, external
calibration, and response curves can be included by setting the relevant
arguments (`include_norm_intensity_stats`, `include_conc_stats`,
`include_response_stats`, `include_calibration_results`) to `TRUE`.

**Note** when corresponding underlying processed data is not available,
the function will not raise an error but will return `NA` values for the
respective metrics. This, however, does not apply for the optional
metrics mentioned above. For these cases an error will be raised if the
underlying data is missing.

If `use_batch_medians = TRUE`, batch-specific QC statistics are computed
first, and then the median of these values is returned for each feature.
However, response curve and calibration statistics are calculated per
curve, irrespective of batches and `use_batch_medians` settings.

The calculated metrics are stored in the `metrics_qc` table of the
`MRMhubExperiment` objects and comprises following details

- **Feature details**: Specific feature information extracted from the
  feature metadata table, such as feature class, associated ISTD,
  quantifier status.

- **Feature MS Method Information** (if method variables are available
  in the analysis data). Extracts and summarizes method-related
  variables for each feature. If multiple values exist for the same
  feature, these will be concatenated into a string. The latter would
  indicate inconsistent analysis conditions.

  - `precursor_mz`: The m/z value of the precursor ion(s),

  - `product_mz`: The m/z value of the product ion(s), concatenated if
    multiple values exist for the same feature.

  - `collision_energy`: The collision energy used for fragmentation,
    concatenated if multiple values exist for the same feature.

- **Missing Value Metrics**:

  - `missing_intensity_prop_spl`: Proportion of missing intensities for
    the SPL sample type.

  - `missing_norm_intensity_prop_spl`: Proportion of missing normalized
    intensities for SPL samples.

  - `missing_conc_prop_spl`: Proportion of missing concentration values
    for SPL samples.

  - `na_in_all`: Indicator if a feature has all missing intensities
    across all samples

- **Retention Time (RT) Metrics**: Requires that retention time data are
  available.

  - `rt_min_*`: Minimum retention time across different QC sample types
    (e.g., SPL, BQC, TQC).

  - `rt_max_*`: Maximum retention time across different QC sample types.

  - `rt_median_*`: Median retention time for specific QC sample types
    like PBLK, SPL, BQC, TQC, etc.

- **Intensity Metrics**:

  - `intensity_min_*`: Minimum intensity value for features across
    different QC sample types such as SPL, TQC, BQC, etc.

  - `intensity_max_*`: Maximum intensity values across sample types.

  - `intensity_median_*`: Median intensity for various QC sample types.

  - `intensity_cv_*`: Coefficient of variation (CV) of intensity values
    for specific QC types.

  - `sb_ratio_*`: Signal-to-blank ratios such as the ratio of intensity
    values for SPL vs PBLK, UBLK, or SBLK.

  - `intensity_q10_*`: The 10th percentile of intensity values for the
    SPL sample type.

- **Normalized Intensity Metrics** (only if
  `include_norm_intensity_stats = TRUE`): Requires that raw intensities
  were normalized, see
  [`normalize_by_istd()`](https://slinghub.github.io/MRMhub/quant/reference/normalize_by_istd.md)
  for details.

  - `norm_intensity_cv_*`: Coefficient of variation (CV) of normalized
    intensities for QC sample types like TQC, BQC, SPL, etc.

- **Concentration Metrics** (only if `include_conc_stats = TRUE`):
  Requires that concentration were calculated, see
  [`quantify_by_istd()`](https://slinghub.github.io/MRMhub/quant/reference/quantify_by_istd.md)
  or
  [`quantify_by_calibration()`](https://slinghub.github.io/MRMhub/quant/reference/quantify_by_calibration.md)
  for details.

  - `conc_median_*`: Median concentration values for different QC sample
    types like TQC, BQC, SPL, NIST, and LTR.

  - `conc_cv_*`: Coefficient of variation (CV) for concentration values.

  - `conc_dratio_sd_*`: The ratio of standard deviations of
    concentration between BQC or TQC and SPL samples.

  - `conc_dratio_mad_*`: The ratio of median absolute deviations (MAD)
    between BQC or TQC and SPL concentrations.

- **Response Curve Metrics** (if `include_response_stats = TRUE`):
  Calculates response curve statistics for each feature and each curve
  (where `#` refers to the curve identifier). Requires that response
  curves are defined in the data. See
  [`get_response_curve_stats()`](https://slinghub.github.io/MRMhub/quant/reference/get_response_curve_stats.md)
  for additional details.

  - `r2_rqc_#`: R² value of the linear regression for the response
    curve, representing the goodness of fit.

  - `slopenorm_rqc_#`: Normalized slope of the linear regression for the
    response curve, indicating the relationship between the response and
    concentration.

  - `y0norm_rqc_#`: Normalized intercept of the linear regression for
    the response curve, representing the baseline or starting value.

- **External Calibration Results** Incorporates external calibration
  results, if `include_calibration_results = TRUE` and calibration
  curves are defined in the data:

  - `fit_model`: The regression model used for curve fitting.

  - `fit_weighting`: The weighting method applied during curve fitting.

  - `lowest_cal`: The lowest nonzero calibration concentration.

  - `highest_cal`: The highest calibration concentration.

  - `r.squared`: R² value indicating the goodness of fit.

  - `coef_a`: The intercept of the regression line (both **linear** and
    **quadratic** fits).

  - `coef_b`:

    - For **linear fits**, the slope of the regression line.

    - For **quadratic fits**, the coefficient of the linear term (`x`).

  - `coef_c`:

    - For **quadratic fits**, the coefficient of the quadratic term
      (`x²`).

    - Set to `NA` for linear fits.

  - `sigma`: The residual standard error of the regression model.

  - `reg_failed`: Boolean flag indicating if regression fitting failed.
