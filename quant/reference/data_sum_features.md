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

Features are summed when they share an `analyte_id` (an empty one counts
as missing): with `qualifier_action = "include"` all of them, with
`"separate"` quantifiers and qualifiers each into their own feature (the
qualifier sum is named `<analyte_id>_qual`), and with `"exclude"` only
the quantifiers, while qualifiers are kept as they are. An analyte with
a single feature in its group keeps its `feature_id`. Only features
present in the dataset are summed: excluded features and features listed
only in the metadata keep their `feature_id` and do not affect the sum.

Only raw signal variables are aggregated across the transitions of an
analyte: `feature_intensity`, `feature_height` and `feature_area` are
summed, and `feature_rt` is averaged. A sum is `NA` in an analysis where
a constituent is missing, since a partial sum would look like a valid
value; a warning reports these analyses. A transition without a value in
any analysis is left out of its sum. `feature_fwhm`, `feature_width`,
`feature_int_start` and `feature_int_end` are set to `NA` for merged
analytes: the constituents are separate chromatographic peaks, so no
aggregate of their peak widths or borders describes the merged quantity.

Summing transitions redefines `feature_intensity`, so all values
*derived* from the pre-merge intensities are invalidated and removed:
normalized intensities, concentrations, drift/batch correction results
and QC metrics. Re-run
[`normalize_by_istd()`](https://slinghub.github.io/MRMhub/quant/reference/normalize_by_istd.md)
and the quantitation/correction steps after merging. A message reports
this when such values were present.

The summed features must be measured and quantified alike: an error is
raised when they combine internal standards with analytes, or differ in
`istd_feature_id`, `quant_istd_feature_id`, `response_factor` or
`interference_feature_id`. An error is also raised when a summed id
equals the `feature_id` of another feature. Transitions of one internal
standard can be summed; references to summed features in the feature,
ISTD and interference metadata are updated, and interferences between
transitions summed into one feature are removed. Other metadata
(`feature_class`, `feature_label`) comes from the first constituent,
with a warning when the constituents disagree.

`is_quantifier` is not inherited but determined by the merge: the merged
analyte is a quantifier if any of its constituents is one.

## Experimental

This function is **experimental** and its behaviour may change. It
overwrites the `feature_id` of features sharing an `analyte_id` in both
the dataset and the feature metadata, and the original `feature_id` is
not backed up anywhere. Run it after importing metadata and after any
exclusions,
[`set_analysis_order()`](https://slinghub.github.io/MRMhub/quant/reference/set_analysis_order.md)
or
[`set_intensity_var()`](https://slinghub.github.io/MRMhub/quant/reference/set_intensity_var.md),
and before normalization/quantitation: these steps rebuild the dataset
from the imported data and stop with an error once features were summed.
Running it on a processed object drops the derived variables (see
Details).
