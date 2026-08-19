# Read a complete `MRMhubExperiment` from an RDS file

Reads an `.rds` file written by
[`save_dataset_rds()`](https://slinghub.github.io/MRMhub/quant/reference/save_dataset_rds.md)
(or a bare [`saveRDS()`](https://rdrr.io/r/base/readRDS.html)) back into
an
[`MRMhubExperiment`](https://slinghub.github.io/MRMhub/quant/reference/MRMhubExperiment-class.md),
with feedback and a class check. The `.rds` is a self-contained snapshot
of a complete analysis project, so the reloaded object can be inspected,
re-plotted or re-processed with mrmhub without the original input files
or metadata.

If the file carries an embedded content fingerprint (see
[`save_dataset_rds()`](https://slinghub.github.io/MRMhub/quant/reference/save_dataset_rds.md)),
it is verified against the reloaded object: a match confirms the file
holds the object it was saved from, and the fingerprint is printed so it
can be compared with a recorded value.

This function only adds the class check, fingerprint verification and
console feedback on top of
[`readRDS()`](https://rdrr.io/r/base/readRDS.html); the file itself is a
plain R serialization. It can therefore always be reopened with base R's
[`readRDS()`](https://rdrr.io/r/base/readRDS.html) without mrmhub, and
every slot (the `dataset`, the `annot_*` metadata tables, the QC and
calibration metrics) is stored as an ordinary tibble that can be
inspected via the `@` slots or
[`attributes()`](https://rdrr.io/r/base/attributes.html). mrmhub is only
required to re-plot or re-process the object — which makes the `.rds` a
convenient self-contained archive of a complete analysis.

## Usage

``` r
read_dataset_rds(path, verify = TRUE, show_status = FALSE)
```

## Arguments

- path:

  A character string with the path to the `.rds` file.

- verify:

  A logical value. If `TRUE` (default) and the file carries an embedded
  fingerprint, it is recomputed and compared; a mismatch triggers a
  warning (the object is still returned).

- show_status:

  A logical value. If `TRUE`, the full processing and metadata report
  ([`mrmhub_status()`](https://slinghub.github.io/MRMhub/quant/reference/mrmhub_status.md))
  is printed after loading. Default is `FALSE`, which prints only the
  compact one-line overview.

## Value

The loaded
[`MRMhubExperiment`](https://slinghub.github.io/MRMhub/quant/reference/MRMhubExperiment-class.md)
object.

## See also

[`save_dataset_rds()`](https://slinghub.github.io/MRMhub/quant/reference/save_dataset_rds.md),
[`mrmhub_status()`](https://slinghub.github.io/MRMhub/quant/reference/mrmhub_status.md)

## Examples

``` r
mexp <- data_load_example()
#> ✔ Loaded example dataset 1: 499 analyses and 29 features.
path <- file.path(tempdir(), "example_mexp.rds")
save_dataset_rds(mexp, path)
#> ✔ MRMhubExperiment saved to /tmp/Rtmp69iboe/example_mexp.rds.
#> Content fingerprint: "fb438f5a8ba7698bd3b1ae00576dca2d"
mexp2 <- read_dataset_rds(path)
#> ✔ Content fingerprint verified: "fb438f5a8ba7698bd3b1ae00576dca2d".
#> ✔ Loaded MRMhubExperiment from /tmp/Rtmp69iboe/example_mexp.rds.
```
