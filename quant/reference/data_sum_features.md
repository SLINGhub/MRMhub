# Sum up feature intensities per analyte

This function sums up feature intensities per analyte_id.

This is useful when you have multiple features (e.g. adducts, isotopes,
in-source fragments) or isomers that you want to combine into a single
analyte intensity value, such as LPC sn1 and sn2 species.

## Usage

``` r
data_sum_features(data, qualifier_action = "include")
```

## Arguments

- data:

  [`MRMhubExperiment`](https://slinghub.github.io/MRMhub/quant/reference/MRMhubExperiment-class.md)
  object

- qualifier_action:

  Character. How to handle qualifier features. To sum them up separately
  select "separate", to include them in the sum if quantifier select
  "include", to not sum them up select "exclude".

## Value

[`MRMhubExperiment`](https://slinghub.github.io/MRMhub/quant/reference/MRMhubExperiment-class.md)
object

## Details

Only raw signal variables are aggregated across the transitions of an
analyte: `feature_intensity`, `feature_height` and `feature_area` are
summed, and `feature_rt` is averaged. `feature_fwhm` and `feature_width`
are set to `NA` for merged analytes: the constituents are separate
chromatographic peaks, so no aggregate of their peak widths describes
the merged quantity.

Summing transitions redefines `feature_intensity`, so all values
*derived* from the pre-merge intensities are invalidated and removed:
normalized intensities, concentrations, drift/batch correction results
and QC metrics. Re-run
[`normalize_by_istd()`](https://slinghub.github.io/MRMhub/quant/reference/normalize_by_istd.md)
and the quantitation/correction steps after merging. A message reports
this when such values were present.

A merged analyte inherits the feature metadata (`feature_class`,
`feature_label`, `istd_feature_id`) of its *first* constituent
transition. A warning is issued when the constituents disagree, since
the value that wins is then arbitrary – for `istd_feature_id` it
silently decides which internal standard the merged analyte is
normalized against.

`is_quantifier` is not inherited but determined by the merge: the merged
analyte is a quantifier if any of its constituents is one. A quantifier
combined with either a qualifier or another quantifier therefore yields
a quantifier, whereas qualifiers merged among themselves remain a
qualifier.

## Experimental

This function is **experimental** and its behaviour may change. It
overwrites the `feature_id` of features sharing an `analyte_id` in both
the dataset and the analysis metadata, and the original `feature_id` is
not backed up anywhere. It is intended to run early (before
normalization/quantitation); running it on a processed object drops the
derived variables (see Details). Use with caution and check the results
carefully.
