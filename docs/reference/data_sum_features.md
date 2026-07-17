# Sum up feature intensities per analyte

This function sums up feature intensities per analyte_id.

THis is is useful when you have multiple features (e.g. adducts,
isotopes, in-source fragments) or isomers that you want to combine into
a single analyte intensity value, such as LPC sn1 and sn2 species.

NOTE: This is still an experimental function! It will overwrite the
feature_id in the dataset and analysis metadata of featured that share
same analyte_id. Currently the original feature_id is not backed up
anywhere. Use with caution and check results carefully!

## Usage

``` r
data_sum_features(data, qualifier_action = "include")
```

## Arguments

- data:

  MRMhubExperiment object

- qualifier_action:

  Character. How to handle qualifier features. To sum them up separately
  select "separate", to include them in the sum if quantifier select
  "include", to not sum them up select "exclude".

## Value

MRMhubExperiment object

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
