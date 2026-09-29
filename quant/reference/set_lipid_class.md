# Set feature classes from lipid names

Derives lipid classes from the `feature_id`s with the Goslin lipid name
parser and writes them to `feature_class` in the feature metadata, the
dataset and the QC metrics. For sphingolipids, the class includes the
number of oxygens on the sphingoid base (e.g. `Cer;O2`, `SM;O2`).
Requires the Bioconductor package `rgoslin`
(`BiocManager::install("rgoslin")`).

## Usage

``` r
set_lipid_class(data = NULL, overwrite = FALSE)
```

## Arguments

- data:

  A `MRMhubExperiment` object.

- overwrite:

  Logical. If `FALSE` (default), only features without a `feature_class`
  get one; if `TRUE`, all classes are replaced. Features whose name
  cannot be parsed keep their class.

## Value

[`MRMhubExperiment`](https://slinghub.github.io/MRMhub/quant/reference/MRMhubExperiment-class.md)
object with updated `feature_class`.

## See also

[`parse_lipid_feature_names()`](https://slinghub.github.io/MRMhub/quant/reference/parse_lipid_feature_names.md)
