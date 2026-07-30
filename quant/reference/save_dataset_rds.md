# Save a complete `MRMhubExperiment` as an RDS file

Writes the whole
[`MRMhubExperiment`](https://slinghub.github.io/MRMhub/quant/reference/MRMhubExperiment-class.md)
to a single `.rds` file: raw data, metadata joins, calibration fits,
quantification results and processing history all travel together. This
makes the `.rds` a self-contained, portable snapshot of a complete
analysis project — a collaborator can open it with
[`readRDS()`](https://rdrr.io/r/base/readRDS.html) to inspect, or load
mrmhub to re-plot and re-process, without reconstructing the original
file paths, input files or metadata versions.

By default a content fingerprint of the object
([`rlang::hash()`](https://rlang.r-lib.org/reference/hash.html)) is
embedded in the saved file and printed. Record it (or compare printed
fingerprints) to confirm that a reloaded file — or a copy shared with a
colleague — holds the identical object.
[`read_dataset_rds()`](https://slinghub.github.io/MRMhub/quant/reference/read_dataset_rds.md)
reads the file back and verifies the fingerprint.

## Usage

``` r
save_dataset_rds(
  data = NULL,
  path,
  hash = TRUE,
  compress = TRUE,
  overwrite = TRUE,
  create_dir = TRUE
)
```

## Arguments

- data:

  A
  [`MRMhubExperiment`](https://slinghub.github.io/MRMhub/quant/reference/MRMhubExperiment-class.md)
  object to save.

- path:

  A character string with the file path. If it does not end in `.rds`,
  the extension is appended automatically.

- hash:

  A logical value. If `TRUE` (default), a content fingerprint of the
  object is computed with
  [`rlang::hash()`](https://rlang.r-lib.org/reference/hash.html),
  embedded in the saved file and printed. The fingerprint is stored as
  an object attribute and is stripped again by
  [`read_dataset_rds()`](https://slinghub.github.io/MRMhub/quant/reference/read_dataset_rds.md),
  so it does not affect the reloaded object.

- compress:

  A logical value passed to
  [`saveRDS()`](https://rdrr.io/r/base/readRDS.html). If `TRUE` (the
  default), the file is gzip-compressed (typically about ten times
  smaller); `FALSE` writes it uncompressed (faster, but much larger).
  Either way the file is read back identically — the compression is
  detected automatically on load.

- overwrite:

  A logical value indicating whether to overwrite the file if it already
  exists. Default is `TRUE`.

- create_dir:

  A logical value. If `TRUE` (the default), the parent directory of
  `path` is created if it does not yet exist.

## Value

The `path` written to, invisibly.

## Archiving

The file is a plain R serialization, so it can always be reopened with
base R's [`readRDS()`](https://rdrr.io/r/base/readRDS.html) — mrmhub is
not required just to read it. Every slot (the `dataset`, the `annot_*`
metadata tables, and the QC and calibration metrics) is stored as an
ordinary tibble and can be inspected via the `@` slots or
[`attributes()`](https://rdrr.io/r/base/attributes.html), which makes
the `.rds` a convenient self-contained archive of a complete analysis.
mrmhub (a compatible version) is only needed to re-plot or re-process
the object through its methods. For long-term, cross-tool preservation,
complement the `.rds` with an open-standard export
([`save_dataset_mztab()`](https://slinghub.github.io/MRMhub/quant/reference/save_dataset_mztab.md),
[`save_dataset_summarizedexperiment()`](https://slinghub.github.io/MRMhub/quant/reference/save_dataset_summarizedexperiment.md)
or
[`save_dataset_csv()`](https://slinghub.github.io/MRMhub/quant/reference/save_dataset_csv.md)).

## See also

[`read_dataset_rds()`](https://slinghub.github.io/MRMhub/quant/reference/read_dataset_rds.md),
[`save_report_xlsx()`](https://slinghub.github.io/MRMhub/quant/reference/save_report_xlsx.md),
[`save_dataset_summarizedexperiment()`](https://slinghub.github.io/MRMhub/quant/reference/save_dataset_summarizedexperiment.md)

## Examples

``` r
mexp <- data_load_example()
#> ✔ Loaded example dataset 1: 499 analyses and 29 features.
path <- file.path(tempdir(), "example_mexp.rds")
save_dataset_rds(mexp, path)
#> ✔ MRMhubExperiment saved to /tmp/RtmpJxTTT1/example_mexp.rds.
#> Content fingerprint: "9ae74b50441d6dee639148d92a688e24"
```
