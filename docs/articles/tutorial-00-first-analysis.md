# Your first analysis

Tutorial Beginner Prerequisites: [MRMhub
installed](https://slinghub.github.io/MRMhub/quant/articles/manual-00-installation.md)

This walkthrough takes an MRMhub result from import to a normalized,
exportable dataset in a handful of lines, using demo data bundled with
the package so nothing external is needed. It is the shortest path
through the pipeline; the workflow tutorials that follow unpack each
step in full.

## 1. Run the complete workflow

The block below is the whole analysis: import the demo result, normalize
each feature by its internal standard, and print the resulting object.
Run it and you have a processed dataset.

``` r

library(mrmhub)

demo_file <- system.file("extdata", "MRMhub_demo.tsv", package = "mrmhub")

mexp <- MRMhubExperiment()
mexp <- import_data_mrmhub(mexp, path = demo_file, import_metadata = TRUE)
```

    ✔ Imported 499 analyses with 28 features.

    ℹ feature_area selected as default feature intensity. Modify with `set_intensity_var()`.

    ✔ Analysis metadata associated with 499 analyses.

    ✔ Feature metadata associated with 28 features.

``` r

mexp <- normalize_by_istd(mexp)
```

    ✔ 19 features normalized with 9 ISTDs in 499 analyses.

``` r

mexp
```

    ── MRMhubExperiment:  ──────────────────────────────────────────────────────────

    NA | 499 analyses and 28 features | signal: feature_area

    Last step: ISTD-normalized data

    Normalized ✔ Quantitated ✖ Drift/batch ✖ Filtered ✖

    ℹ Use `status()` for the full processing and metadata report

We then look at the normalized signal across the analytical run, the
first thing to inspect for run-order drift.

``` r

plot_runscatter(mexp, variable = "norm_intensity")
```

![RunScatter of ISTD-normalized feature intensities against run
order](tutorial-00-first-analysis_files/figure-html/runscatter-1.png)

Figure 1. Internal-standard–normalized signal of each feature plotted
against injection order.

![RunScatter of ISTD-normalized feature intensities against run
order](tutorial-00-first-analysis_files/figure-html/runscatter-2.png)

Figure 1. Internal-standard–normalized signal of each feature plotted
against injection order.

![RunScatter of ISTD-normalized feature intensities against run
order](tutorial-00-first-analysis_files/figure-html/runscatter-3.png)

Figure 1. Internal-standard–normalized signal of each feature plotted
against injection order.

![RunScatter of ISTD-normalized feature intensities against run
order](tutorial-00-first-analysis_files/figure-html/runscatter-4.png)

Figure 1. Internal-standard–normalized signal of each feature plotted
against injection order.

Printing the object returns a compact status overview: `status(mexp)`
prints the full report. If you prefer not to write code,
[`build_workflow()`](https://slinghub.github.io/MRMhub/quant/reference/build_workflow.md)
opens an interactive application that validates your data and metadata,
flags pipeline mismatches, and generates an equivalent Quarto workflow
to download (see [Build a workflow without
code](https://slinghub.github.io/MRMhub/quant/articles/tutorial-12-workflow-builder.md));
the script above remains the reproducible path.

## 2. What the script does

The importer returns an `MRMhubExperiment`: a structured container
holding the peak-area data, the sample annotations, and the feature
metadata together.
[`normalize_by_istd()`](https://slinghub.github.io/MRMhub/quant/reference/normalize_by_istd.md)
divides each feature by its assigned internal standard, correcting for
extraction and injection variability. The ratio is stored in
`feature_norm_intensity`, the `is_istd_normalized` flag is set, and the
raw import is left untouched in the `dataset_orig` slot. A few helpers
report what was imported:

``` r

get_analysis_count(mexp)   # number of analyses
get_feature_count(mexp)    # number of features
get_featurelist(mexp)      # the measured features
```

## 3. Export the results

Write the processed data to a multi-sheet Excel report, or to a single
tidy CSV:

``` r

save_report_xlsx(mexp, path = "my_first_results.xlsx")
save_dataset_csv(mexp, path = "my_first_results.csv")
```

## Next steps

- [Key concepts and
  glossary](https://slinghub.github.io/MRMhub/quant/articles/manual-01-key-concepts.md):
  understand the data model
- [Preparing and importing
  data](https://slinghub.github.io/MRMhub/quant/articles/tutorial-01-prep-data.md):
  import your own data and metadata
- [Basic MRMhub
  workflow](https://slinghub.github.io/MRMhub/quant/articles/tutorial-02-basic-workflow.md):
  the full end-to-end pipeline
- [Lipidomics data
  processing](https://slinghub.github.io/MRMhub/quant/articles/tutorial-03-lipidomics-workflow.md):
  a detailed real-world workflow
- [Customising
  plots](https://slinghub.github.io/MRMhub/quant/articles/manual-13-plot-customization.md):
  size text, legends and points for reports
