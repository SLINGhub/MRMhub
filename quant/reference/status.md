# Detailed processing and metadata report for a `MRMhubExperiment`

Prints the full status dashboard for a
[`MRMhubExperiment`](https://slinghub.github.io/MRMhub/quant/reference/MRMhubExperiment-class.md):
sample and feature composition, which metadata tables are populated, the
state of each processing step, and any manually excluded analyses or
features. Printing the object directly gives the compact one-screen
overview instead.

## Usage

``` r
status(object)
```

## Arguments

- object:

  A
  [`MRMhubExperiment`](https://slinghub.github.io/MRMhub/quant/reference/MRMhubExperiment-class.md)
  object.

## Value

The `object`, invisibly.

## Examples

``` r
status(MRMhubExperiment(title = "Test", analysis_type = "lipidomics"))
#> 
#> ── MRMhubExperiment ────────────────────────────────────────────────────────────
#> Title: Test
#> Last step: No Data | signal: not set
#> 
#> ── Samples (0 analyses, 0 batches) ──
#> 
#> • No annotated samples
#> 
#> ── Features (0) ──
#> 
#> • Analytes: 0 Internal standards: 0
#> • Quantifiers: 0 Qualifiers: 0
#> 
#> ── Metadata ──
#> 
#> • Analyses/samples: ✖ Features/analytes: ✖ Internal standards: ✖
#> • Response curves: ✖ Calibrants/QC concentrations: ✖ Study samples: ✖
#> Interferences: ✖
#> 
#> ── Processing Status ──
#> 
#> • Isotope / interference corrected: ✖
#> • ISTD normalized: ✖ Quantitated: ✖
#> • Drift corrected variables: ✖
#> • Batch corrected variables: ✖
#> • QC metrics calculated: ✖ Feature filtering applied: ✖
#> 
#> ── Exclusion of Analyses and Features ──
#> 
#> • Analyses manually excluded (`analysis_id`): ✖
#> • Features manually excluded (`feature_id`): ✖
```
