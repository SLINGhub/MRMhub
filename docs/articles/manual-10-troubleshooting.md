# Troubleshooting and FAQ

## Installation Issues

The single most common cause of failed installations is that one of
MRMhub’s dependencies is currently *loaded* in the active R session —
typically `rlang`, `cli`, `vctrs`, `dplyr`, `tibble`, or `ggplot2`.
RStudio and Positron load several of these on startup (Environment pane,
Plots pane), so a “fresh session” via *Restart R* is sometimes not
enough on Windows. When in doubt, **quit the IDE entirely** and reopen
it before installing.

**“cannot remove prior installation of package ‘X’” or “permission
denied”** (Windows, most common)

A dependency DLL is locked by another running R session, RStudio, or
Positron. Restarting R does not always release the lock on Windows.

``` r

# Fix:
# 1. Quit RStudio / Positron entirely (close all windows, not just the project)
# 2. Make sure no other R.exe / Rterm.exe is running in Task Manager
# 3. Reopen RStudio / Positron in a new session (NOT loading a project that
#    auto-attaches mrmhub or any tidyverse package via an .Rprofile)
# 4. Immediately, before opening any project, run the install command
remotes::install_github("SLINGhub/mrmhub")
```

If the message names a specific package (e.g. `'rlang'` is locked),
install just that package first into a fresh session, then retry MRMhub.

**“namespace ‘rlang’ is already loaded”**

A package that other packages depend on is locked into the current
namespace. Quitting RStudio entirely (see above) usually resolves it;
the lighter touch is:

``` r

# 1. Restart R: Session > Restart R (or Ctrl+Shift+F10)
# 2. Update the locked package first in the fresh session
install.packages("rlang")
# 3. Then retry mrmhub installation
```

**“Rtools is required to build R packages”** (Windows)

Install [Rtools](https://cran.r-project.org/bin/windows/Rtools/) for
your R version (Rtools43 for R 4.3, Rtools44 for R 4.4, …), then restart
R and retry. Rtools is needed for compiling source packages, which some
MRMhub dependencies require when a Windows binary is not yet available.

**Use `pak` instead of `remotes`**

[`pak`](https://pak.r-lib.org/) handles locked packages more cleanly
than `remotes` on Windows, gives clearer error messages on transitive
failures, and parallelises downloads. If `remotes` fails:

``` r

install.packages("pak")
pak::pak("SLINGhub/mrmhub")
```

`pak` automatically restarts R if needed to release locks, and resolves
the dependency graph in one pass.

**“cannot open URL” or timeout during install**

The network is blocking GitHub or a CRAN mirror.

``` r

# Option 1: change download method
options(download.file.method = "libcurl")

# Option 2: clone locally and install
# In terminal: git clone https://github.com/SLINGhub/MRMhub.git
remotes::install_local("path/to/MRMhub")

# Option 3: if behind a corporate proxy, configure it before installing
Sys.setenv(http_proxy  = "http://proxy.example.com:8080")
Sys.setenv(https_proxy = "http://proxy.example.com:8080")
```

**“installation of package ‘X’ had non-zero exit status”** (Suggests
dependency failure)

By default `remotes::install_github(..., dependencies = TRUE)` installs
every Suggests dependency too. A single broken Suggests package —
e.g. `lancer` (a non-CRAN GitHub package required only for LICAR-style
interference correction) when the network blocks GitHub clones — aborts
the whole install. Fix:

``` r

# Install only the strictly required dependencies
remotes::install_github(
  "SLINGhub/mrmhub",
  dependencies = c("Depends", "Imports", "LinkingTo")
)
```

Optional packages can be added later as needed:
`install.packages(c("patchwork", "ggrepel"))`.

**Apple Silicon: package compilation fails / “no binary available”**

On Apple Silicon, if a dependency is not yet built as an `arm64` binary
on CRAN, R falls back to building from source, which then requires Xcode
Command Line Tools. Two fixes:

``` r

# Option A: install Xcode Command Line Tools (run in terminal, not R)
# xcode-select --install

# Option B: ask R to skip source builds when only a binary is missing
options(install.packages.compile.from.source = "never")
remotes::install_github("SLINGhub/mrmhub")
```

Option B may leave slightly older versions of those packages but avoids
the toolchain entirely.

------------------------------------------------------------------------

## Data Import Issues

**“Column X not found” or unexpected column names**

The CSV uses different column names than expected. Check with:

``` r

# Read the first few rows to inspect
readr::read_csv("your_file.csv", n_max = 5)
```

Common causes:

- MassHunter exports have locale-specific headers (e.g., German vs
  English)
- Extra BOM characters in UTF-8 files (open in a plain text editor to
  check)
- Delimiter mismatch: file uses `;` but R expects `,`

``` r

# For semicolon-separated files:
readr::read_csv2("your_file.csv", n_max = 5)
```

**“No features found” after import**

The feature names in the data file do not match those in the feature
annotation. Check for:

- Trailing whitespace: `"Compound A "` vs `"Compound A"`
- Case differences: `"compound_a"` vs `"Compound_A"`

``` r

# Debug: compare feature names
data_features <- unique(mexp@dataset$feature_id)
annot_features <- mexp@annot_features$feature_id

# Find mismatches
setdiff(data_features, annot_features)
setdiff(annot_features, data_features)
```

**Which importer should I use?**

See [Import and prepare data
files](https://slinghub.github.io/MRMhub/quant/articles/manual-04-data-import.md)
for a visual decision flowchart.

------------------------------------------------------------------------

## Processing Issues

**All values are NA after normalisation**

Most likely cause: the ISTD assignment is missing or incorrect.

``` r

# Check ISTD assignments
mexp@annot_features |>
  dplyr::select(feature_id, istd_feature_id) |>
  dplyr::filter(is.na(istd_feature_id))
```

If `istd_feature_id` is `NA`, normalization divides by nothing → `NA`
result.

**Drift correction makes data worse**

This can happen when:

- Too few QC samples (need ≥ 5 per batch for loess)
- QC samples are not evenly spaced across the run
- The drift is not systematic (random noise, not a trend)

``` r

# Visualise before correcting
plot_runscatter(mexp,
                variable = "norm_intensity",
                include_feature_filter = "your_feature",
                qc_types = c("BQC", "SPL"))
```

If the QC trend is flat, skip drift correction for that batch.

**Batch correction flattens real biological signal**

[`correct_batch_centering()`](https://slinghub.github.io/MRMhub/quant/reference/correct_batch_centering.md)
assumes QC samples have equal concentration across batches. If the QC
pool differs between batches, centering will introduce artefacts.

**Solution:** Ensure the same QC pool is used across all batches.

------------------------------------------------------------------------

## Object and Data Access

**How do I extract the final data as a data frame?**

``` r

# After all processing and filtering:
final_data <- get_analyticaldata(mexp, annotated = TRUE)

# Or the filtered dataset directly:
final_filtered <- mexp@dataset_filtered
```

**How do I check what processing has been applied?**

``` r

# Check processing status flags
mexp@is_istd_normalized
mexp@is_quantitated
mexp@var_drift_corrected
mexp@var_batch_corrected
```

**How do I go back to the original data?**

The original data is always preserved:

``` r

# Reset to original
mexp@dataset <- mexp@dataset_orig
```

------------------------------------------------------------------------

## QC and Filtering

**What do the QC metrics mean?**

| Metric     | Meaning                                  | Typical threshold |
|------------|------------------------------------------|-------------------|
| CV (%)     | Coefficient of variation in QC samples   | \< 20–30%         |
| Bias (%)   | Systematic deviation from expected value | \< 20%            |
| n_detected | Number of QC samples with signal         | ≥ 50–67% of QCs   |

**My features are all filtered out**

The thresholds may be too strict. Check:

``` r

# See QC metrics before filtering
mexp@metrics_qc |>
  dplyr::arrange(dplyr::desc(norm_intensity_cv_bqc))

# Use more lenient thresholds
mexp <- filter_features_qc(
  mexp,
  include_qualifier = FALSE,
  include_istd = FALSE,
  max.cv.normintensity.bqc = 40,
  max.prop.missing.normintensity.spl = 0.5
)
```

------------------------------------------------------------------------

## Calibration

**“No calibration points found”**

The calibration annotation does not match sample labels in the data.
Check that `annot_qcconcentrations` uses the same `analysis_id` values
as the data.

**Calibration curve has R² \< 0.9**

Consider:

- Removing outlier calibration points
- Using a different weighting scheme (1/x or 1/x²)
- Checking for saturation at high concentrations

``` r

# Inspect calibration metrics
get_calibration_metrics(mexp) |>
  dplyr::filter(r2 < 0.9)
```

------------------------------------------------------------------------

## FAQ

**Can I use MRMhub with non-MRM data (e.g., PRM, SRM)?**

Yes, provided the data can be formatted as a long CSV with feature IDs
and peak areas. The processing is agnostic to acquisition mode.

**Can I process only one batch?**

Yes. Do not apply batch correction. All other functions work with
single-batch data.

**Is there a size limit?**

No hard limit, but very large datasets (\>100k rows) may be slow for
drift correction. Consider processing batches separately and merging.

**Where do I report bugs?**

[GitHub Issues](https://github.com/SLINGhub/MRMhub/issues)

------------------------------------------------------------------------

## Next Steps

- [Design
  Overview](https://slinghub.github.io/MRMhub/quant/articles/manual-03-design-decisions.md)
  — understand the full pipeline
- [Installation](https://slinghub.github.io/MRMhub/quant/articles/manual-00-installation.md)
  — verify your setup with
  [`check_setup()`](https://slinghub.github.io/MRMhub/quant/reference/check_setup.md)
