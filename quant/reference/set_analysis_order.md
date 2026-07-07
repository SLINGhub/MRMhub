# Set Analysis Order

Determines the sequence of analyses using either instrument timestamps,
the order in the imported raw data file, or the order defined in the
Analysis metadata. Note: After changing the analysis order, all post
processing steps must be rerun.

## Usage

``` r
set_analysis_order(
  data = NULL,
  order_by = c("timestamp", "resultfile", "metadata")
)
```

## Arguments

- data:

  A `MRMhubExperiment` object

- order_by:

  Character string specifying the ordering method. Must be one of
  "timestamp" (requires timestamp data in imported results),
  "resultfile" (uses order from imported data file), or "metadata" (uses
  order from analysis metadata)

## Value

An updated `MRMhubExperiment` object with ordered analyses

## Examples

``` r
file_path <- system.file("extdata", "MRMhub_demo.tsv", package = "mrmhub")
mexp <- MRMhubExperiment()
mexp <- import_data_mrmhub(mexp, path = file_path, import_metadata = TRUE)
#> ✔ Imported 499 analyses with 28 features
#> ℹ `feature_area` selected as default feature intensity. Modify with `set_intensity_var()`.
#> ✔ Analysis metadata associated with 499 analyses.
#> ✔ Feature metadata associated with 28 features.

# Order by timestamp (if available)
mexp <- set_analysis_order(mexp, "timestamp")
#> ✔ Analysis order set to "timestamp"

# Order by metadata definition
mexp <- set_analysis_order(mexp, "metadata")
#> ✔ Analysis order set to "metadata"
```
