# Your First Analysis

This walkthrough takes you from zero to a normalized dataset in under 5
minutes using bundled demo data — no external files needed.

**Time:** ~5 minutes  \|  **Prerequisites:** MRMhub installed
([`check_setup()`](https://slinghub.github.io/MRMhub/quant/reference/check_setup.md)
passes)  \|  **Data:** Bundled demo (no downloads)

## Step 1: Load MRMhub

``` r

library(mrmhub)
```

## Step 2: Import Demo Data

MRMhub ships with a demo dataset produced by INTEGRATOR. Import it with
[`import_data_mrmhub()`](https://slinghub.github.io/MRMhub/quant/reference/import_data_mrmhub.md):

``` r

demo_file <- system.file("extdata", "MRMhub_demo.tsv", package = "mrmhub")
mexp <- import_data_mrmhub(demo_file)
mexp
```

The result is an `MRMhubExperiment` object — a structured container
holding your peak area data, sample annotations, and feature metadata.

## Step 3: Explore the Data

``` r

# Dimensions: samples × features
get_analysis_count(mexp)
get_feature_count(mexp)

# First few sample annotations
head(mexp@annot_analyses)

# Feature list
get_featurelist(mexp)
```

## Step 4: Normalize by Internal Standard

Apply ISTD normalization to correct for extraction and injection
variability:

``` r

mexp <- normalize_by_istd(mexp)
```

After this step, [`mexp@is`](mailto:mexp@is)`_istd_normalized` is
`TRUE`. The original data is preserved in `dataset_orig`.

## Step 5: Visualise

Check the run sequence for signal drift:

``` r

plot_runscatter(mexp, y = "area_normalized")
```

## Step 6: Export

Export the processed data to Excel or CSV:

``` r

# Excel report (multiple sheets)
save_report_xlsx(mexp, file = "my_first_results.xlsx")

# Or as tidy CSV
save_dataset_csv(mexp, file = "my_first_results.csv")
```

## What’s Next?

| Goal | Article |
|----|----|
| Understand the data model | [Key Concepts](https://slinghub.github.io/MRMhub/quant/articles/manual-00-key-concepts.md) |
| Full lipidomics workflow | [Lipidomics Workflow](https://slinghub.github.io/MRMhub/quant/articles/tutorial-03-lipidomics-workflow.md) |
| Drift & batch correction | [Drift Correction](https://slinghub.github.io/MRMhub/quant/articles/tutorial-04-drift-correction.md) |
| Quantitative assay with calibration | [External Calibration](https://slinghub.github.io/MRMhub/quant/articles/recipe-01-ext-calibration-qc.md) |
