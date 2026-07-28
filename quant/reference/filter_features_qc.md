# Feature filtering based on QC criteria

Filters a dataset based on quality control (QC) criteria, including
intensity, coefficient of variation (CV), signal-to-blank ratios,
D-ratio, response curve properties, and proportion of missing values.
Criteria apply to different QC types (BQC, TQC) and measurement
variables (concentration, intensity, and normalized intensity).

To clear all existing filters, run `filter_features_qc()` with
`clear_existing = TRUE` and without any filtering criteria.

## Usage

``` r
filter_features_qc(
  data = NULL,
  clear_existing = TRUE,
  recalc_metrics = FALSE,
  use_batch_medians = FALSE,
  use_robust_cv = FALSE,
  include_qualifier = FALSE,
  include_istd = FALSE,
  features.to.keep = NA,
  max.prop.missing.intensity.spl = NA,
  max.prop.missing.normintensity.spl = NA,
  max.prop.missing.conc.spl = NA,
  min.intensity.lowest.bqc = NA,
  min.intensity.lowest.tqc = NA,
  min.intensity.lowest.spl = NA,
  min.intensity.median.bqc = NA,
  min.intensity.median.tqc = NA,
  min.intensity.median.spl = NA,
  min.intensity.highest.spl = NA,
  min.signalblank.median.spl.pblk = NA,
  min.signalblank.median.spl.ublk = NA,
  min.signalblank.median.spl.sblk = NA,
  max.cv.intensity.bqc = NA,
  max.cv.intensity.tqc = NA,
  max.cv.normintensity.bqc = NA,
  max.cv.normintensity.tqc = NA,
  max.cv.conc.bqc = NA,
  max.cv.conc.tqc = NA,
  response.curves.selection = NA,
  response.curves.summary = NA,
  min.rsquare.response = NA,
  min.slope.response = NA,
  max.slope.response = NA,
  max.yintercept.response = NA,
  max.dratio.sd.conc.bqc = NA,
  max.dratio.sd.conc.tqc = NA,
  max.dratio.mad.conc.bqc = NA,
  max.dratio.mad.conc.tqc = NA,
  max.dratio.sd.normint.bqc = NA,
  max.dratio.sd.normint.tqc = NA,
  max.dratio.mad.normint.bqc = NA,
  max.dratio.mad.normint.tqc = NA
)
```

## Arguments

- data:

  [`MRMhubExperiment`](https://slinghub.github.io/MRMhub/quant/reference/MRMhubExperiment-class.md)
  object.

- clear_existing:

  Logical. If `TRUE`, replaces any existing filters; if `FALSE`, adds
  new filters on top of existing ones. Default is `TRUE`.

- recalc_metrics:

  Logical. If `TRUE`, recalculates QC metrics before filtering. Default
  is `FALSE`.

- use_batch_medians:

  Logical. If `TRUE`, uses batch-wise median QC values for filtering.
  Default is `FALSE`.

- use_robust_cv:

  Logical. If `TRUE`, uses robust coefficient of variation (MAD/median)
  instead of standard CV (SD/mean). Default is `FALSE`.

- include_qualifier:

  Logical. If `TRUE`, includes qualifier features in the filtering
  process.

- include_istd:

  Logical. If `TRUE`, includes internal standards (ISTDs) in the
  filtering process.

- features.to.keep:

  A vector of feature identifiers to retain, even if they do not meet
  the filtering criteria.

- max.prop.missing.intensity.spl:

  Maximum proportion of missing intensity values among study samples
  (SPL). Default is `NA`.

- max.prop.missing.normintensity.spl:

  Maximum proportion of missing normalized intensity values among study
  samples (SPL). Default is `NA`.

- max.prop.missing.conc.spl:

  Maximum proportion of missing concentration values among study samples
  (SPL). Default is `NA`.

- min.intensity.lowest.bqc:

  Minimum intensity of the lowest BQC sample. Default is `NA`.

- min.intensity.lowest.tqc:

  Minimum intensity of the lowest TQC sample. Default is `NA`.

- min.intensity.lowest.spl:

  Minimum intensity of the lowest study sample (SPL). Default is `NA`.

- min.intensity.median.bqc:

  Minimum median intensity of BQC samples. Default is `NA`.

- min.intensity.median.tqc:

  Minimum median intensity of TQC samples. Default is `NA`.

- min.intensity.median.spl:

  Minimum median intensity of study samples (SPL). Default is `NA`.

- min.intensity.highest.spl:

  Minimum intensity of the highest intensity study sample (SPL). Default
  is `NA`.

- min.signalblank.median.spl.pblk:

  Minimum signal-to-blank ratio for SPL samples and PBLK. Default is
  `NA`.

- min.signalblank.median.spl.ublk:

  Minimum signal-to-blank ratio for SPL samples and UBLK. Default is
  `NA`.

- min.signalblank.median.spl.sblk:

  Minimum signal-to-blank ratio for SPL samples and SBLK. Default is
  `NA`.

- max.cv.intensity.bqc:

  Maximum CV for intensity in BQC samples. Default is `NA`.

- max.cv.intensity.tqc:

  Maximum CV for intensity in TQC samples. Default is `NA`.

- max.cv.normintensity.bqc:

  Maximum CV for normalized intensity in BQC samples. Default is `NA`.

- max.cv.normintensity.tqc:

  Maximum CV for normalized intensity in TQC samples. Default is `NA`.

- max.cv.conc.bqc:

  Maximum CV for concentration in BQC samples. Default is `NA`.

- max.cv.conc.tqc:

  Maximum CV for concentration in TQC samples. Default is `NA`.

- response.curves.selection:

  Select specific response curves by ID. Default is `NA`.

- response.curves.summary:

  Define the method to summarize multiple response curves. Default is
  `NA`.

- min.rsquare.response:

  Minimum R² value for the response curves. Default is `NA`.

- min.slope.response:

  Minimum slope for the response curve. Default is `NA`.

- max.slope.response:

  Maximum slope for the response curve. Default is `NA`.

- max.yintercept.response:

  Maximum y-intercept of the response curve. Default is `NA`.

- max.dratio.sd.conc.bqc:

  Maximum allowed D-ratio (SD of BQC / SD of SPL) using standard
  deviation for BQC samples. Default is `NA`.

- max.dratio.sd.conc.tqc:

  Maximum allowed D-ratio (SD of TQC / SD of SPL) using standard
  deviation for TQC samples. Default is `NA`.

- max.dratio.mad.conc.bqc:

  Maximum allowed D-ratio (MAD of BQC / MAD of SPL) using median
  absolute deviation for BQC samples. Default is `NA`.

- max.dratio.mad.conc.tqc:

  Maximum allowed D-ratio (MAD of TQC / MAD of SPL) using median
  absolute deviation for TQC samples. Default is `NA`.

- max.dratio.sd.normint.bqc:

  Maximum allowed D-ratio (SD of normalized intensity in BQC / SD of
  SPL) using standard deviation. Default is `NA`.

- max.dratio.sd.normint.tqc:

  Maximum allowed D-ratio (SD of normalized intensity in TQC / SD of
  SPL) using standard deviation. Default is `NA`.

- max.dratio.mad.normint.bqc:

  Maximum allowed D-ratio (MAD of normalized intensity in BQC / MAD of
  SPL) using median absolute deviation. Default is `NA`.

- max.dratio.mad.normint.tqc:

  Maximum allowed D-ratio (MAD of normalized intensity in TQC / MAD of
  SPL) using median absolute deviation. Default is `NA`.

## Value

The input
[`MRMhubExperiment`](https://slinghub.github.io/MRMhub/quant/reference/MRMhubExperiment-class.md)
object with the feature filtering criteria applied.

## Details

This function implements filtering criteria based on quality control
(QC) samples and additional analytical parameters, following
recommendations outlined by Broadhurst et al. (2018). The implemented
criteria evaluate data quality through analysis of QC samples, blanks,
and study samples.

## References

Broadhurst, D., Goodacre, R., Reinke, S. N., Kuligowski, J., Wilson, I.
D., Lewis, M. R., & Dunn, W. B. (2018). Guidelines and considerations
for the use of system suitability and quality control samples in mass
spectrometry assays applied in clinical studies. *Metabolomics*, 14(6),
72.
[doi:10.1007/s11306-018-1367-3](https://doi.org/10.1007/s11306-018-1367-3)
