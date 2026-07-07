# Your First Analysis

This walkthrough produces a normalized dataset in under 5 minutes using
bundled demo data; no external files are needed.

**Time:** ~5 min  \|  **Level:** Beginner  \|  **Prerequisites:** MRMhub
installed
([`check_setup()`](https://slinghub.github.io/MRMhub/quant/reference/check_setup.md)
passes)

## The complete workflow in one script

The complete workflow on the bundled demo data is shown below. The
printed summary and plot are produced by this code.

``` r

library(mrmhub)

# 1. Import the bundled demo dataset (produced by INTEGRATOR)
demo_file <- system.file("extdata", "MRMhub_demo.tsv", package = "mrmhub")
mexp <- MRMhubExperiment()
mexp <- import_data_mrmhub(mexp, path = demo_file, import_metadata = TRUE)
mexp

# 2. Normalise each feature by its internal standard
mexp <- normalize_by_istd(mexp)

# 3. Inspect the normalised signal across the analytical run
plot_runscatter(mexp, variable = "norm_intensity")
```

![](tutorial-00-first-analysis_files/figure-html/whole-thing-1.png)![](tutorial-00-first-analysis_files/figure-html/whole-thing-2.png)![](tutorial-00-first-analysis_files/figure-html/whole-thing-3.png)![](tutorial-00-first-analysis_files/figure-html/whole-thing-4.png)

To save the processed data to an Excel report (or a tidy CSV), add one
line:

``` r

save_report_xlsx(mexp, path = "my_first_results.xlsx")
```

**Interactive alternative.**
[`run_walkthrough()`](https://slinghub.github.io/MRMhub/quant/reference/run_walkthrough.md)
opens a point-and-click application that validates the data, generates
the equivalent workflow script, and displays the results. The code-first
workflow above remains the reproducible path.

## Step by step

The rest of this page explains each step of the script above.

### Step 1: Load MRMhub

``` r

library(mrmhub)
```

### Step 2: Import Demo Data

MRMhub ships with a demo dataset produced by INTEGRATOR. Import it with
[`import_data_mrmhub()`](https://slinghub.github.io/MRMhub/quant/reference/import_data_mrmhub.md):

``` r

demo_file <- system.file("extdata", "MRMhub_demo.tsv", package = "mrmhub")
mexp <- MRMhubExperiment()
mexp <- import_data_mrmhub(mexp, path = demo_file, import_metadata = TRUE)
mexp
```

The result is an `MRMhubExperiment` object, a structured container
holding the peak area data, sample annotations, and feature metadata.

### Step 3: Explore the Data

``` r

# Dimensions: samples × features
get_analysis_count(mexp)
get_feature_count(mexp)

# First few sample annotations
head(mexp@annot_analyses)

# Feature list
get_featurelist(mexp)
```

### Step 4: Normalize by Internal Standard

Apply ISTD normalization to correct for extraction and injection
variability:

``` r

mexp <- normalize_by_istd(mexp)
```

After this step, `mexp@is_istd_normalized` is `TRUE`. The original data
is preserved in `dataset_orig`.

### Step 5: Visualise

Check the run sequence for signal drift:

``` r

plot_runscatter(mexp, variable = "norm_intensity")
```

### Step 6: Export

Export the processed data to Excel or CSV:

``` r

# Excel report (multiple sheets)
save_report_xlsx(mexp, path = "my_first_results.xlsx")

# Or as tidy CSV
save_dataset_csv(mexp, path = "my_first_results.csv")
```

## Next Steps

- [Key
  Concepts](https://slinghub.github.io/MRMhub/quant/articles/manual-00-key-concepts.md)
  — understand the data model
- [Lipidomics
  Workflow](https://slinghub.github.io/MRMhub/quant/articles/tutorial-03-lipidomics-workflow.md)
  — full lipidomics workflow
- [Drift
  Correction](https://slinghub.github.io/MRMhub/quant/articles/tutorial-04-drift-correction.md)
  — drift & batch correction
- [External
  Calibration](https://slinghub.github.io/MRMhub/quant/articles/recipe-01-ext-calibration-qc.md)
  — quantitative assay with calibration
