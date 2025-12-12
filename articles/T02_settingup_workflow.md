# A basic MRMhub workflow

This tutorial outlines some key steps in a MRMhub workflow, based on a
lipidomics dataset. See the tutorial [Lipidomics Data
Processing](https://slinghub.github.io/MRMhub/articles/articles/T01_targetlipidomics_workflow.md)
for a more detailed example.

Keep in mind that these examples below are simplified and may not be
applicable to your data and experimental setup. Please consult other
tutorials and recipes for information on other workflows and data types.

## Setting up a RStudio project

To start a new MRMhub data analysis, creating a RStudio project is
recommended. (See [Using RStudio
Projects](https://support.posit.co/hc/en-us/articles/200526207-Using-RStudio-Projects)).
This will help to keep the data analysis organized and makes it easier
to share with others. The project should contain the following
subfolders: `data` and `output`. Add data and metadata files to the
`data` folder.

Notebooks such as R/Notebook (.rmd) or [Quarto
Notebook](https://docs.posit.co/ide/user/ide/guide/documents/quarto-project.html)
(.qmd) are good choices to create documented data processing workflows.
These formats allow combining code with formatted text to document the
data processing steps.

Start with a new notebook or R script and load the `mrmhub` package

``` r
library(mrmhub)
```

## Creating a MRMhubExperiment object

The `MRMhubExperiment` object is the main **data container** used in the
MRMhub workflow. See (The `MRMhubExperiment` data
object)\[articles/03_MRMhubExperiment.html\] for more information.

We start by creating a new `MRMhubExperiment` object (`myexp`), which
will be used in all subsequent steps.

``` r
myexp <- MRMhubExperiment()
```

## Importing analysis results

As introduced in [Preparing and importing
data](https://slinghub.github.io/MRMhub/articles/articles/T01_prepdata.md)  
we first import the analytical data, in this case from
[MRMhub](https://github.com/MRMhub/MRMhub) file. This file also contains
some metadata, such as `qc_type` and `batch_id` (see [Data Identifiers
in
MRMhub](https://slinghub.github.io/MRMhub/articles/articles/02_keydataids.md))
which we will import as well.

``` r
myexp <- import_data_mrmhub(data = myexp, 
                            path = "datasets/sPerfect_MRMhub.tsv", 
                            import_metadata = TRUE)
#> ✔ Imported 499 analyses with 503 features
#> ℹ `feature_area` selected as default feature intensity. Modify with `set_intensity_var()`.
#> ✔ Analysis metadata associated with 499 analyses.
#> ✔ Feature metadata associated with 503 features.
```

## Adding metadata

The subsequent processing steps require additional infomation that is
not available from the imported analysis data. This includes information
such as which internal standards are used to normalize, their
concentrations and the sample amounts analysed. These metadata can be
imported from separate files or R data frames as described in [Preparing
and importing
data](https://slinghub.github.io/MRMhub/articles/articles/T01_prepdata.md).
To keep the code concience in this example, we will import metadata from
an msorganiser template. The validation checks result in some warnings,
which will by default result in a failed metadata import. However,
assuming we understand what we are doing, we decided to ignore these
warnings by setting `ignore_warnings = TRUE`. They will still be shown
in the table printed in the console, labelled with an asterix (\*) in
the `status` column.

``` r
myexp <- import_metadata_msorganiser(
  myexp, 
  path = "datasets/sPerfect_Metadata.xlsm", 
  ignore_warnings = TRUE
)
#> ! Metadata has following warnings and notifications:
#> --------------------------------------------------------------------------------------------
#>   Type Table    Column                Issue                           Count
#> 1 W*   Analyses analysis_id           Analyses not in analysis data      15
#> 2 W*   Features feature_id            Feature(s) not in analysis data     4
#> 3 W*   Features feature_id            Feature(s) without metadata         1
#> 4 W*   ISTDs    quant_istd_feature_id Internal standard(s) not used       1
#> --------------------------------------------------------------------------------------------
#> E = Error, W = Warning, W* = Supressed Warning, N = Note
#> --------------------------------------------------------------------------------------------
#> ✔ Analysis metadata associated with 499 analyses.
#> ✔ Feature metadata associated with 502 features.
#> ✔ Internal Standard metadata associated with 17 ISTDs.
#> ✔ Response curve metadata associated with 12 annotated analyses.
```

## Applying Data Processing

Now we are ready to proceed with data processing. In this example we
will employ some basic data processing steps, whereby the corresponding
code should be self explanatory. At the end of this code block we also
set criteria based on which features are filtered on demand later in the
workflow.

``` r
myexp <- normalize_by_istd(myexp)
#> ! Interfering features defined in metadata, but no correction was applied. Use `correct_interferences()` to correct.
#> ✔ 460 features normalized with 17 ISTDs in 499 analyses.
myexp <- quantify_by_istd(myexp)
#> ✔ 460 feature concentrations calculated based on 42 ISTDs and sample amounts of 499 analyses.
#> ℹ Concentrations are given in μmol/L.

myexp <- correct_drift_gaussiankernel(
  data = myexp,
  variable = "conc",
  ref_qc_types = c("SPL"))
#> ℹ Applying `conc` drift correction...
#> ℹ 2 feature(s) contain one or more zero or negative `conc` values. Verify your data or use `log_transform_internal = FALSE`.
#>  ■■■■■■■■■■■■■                     41% |  ETA:  5s
#>  ■■■■■■■■■■■■■■■■■■■■■■■■■         78% |  ETA:  2s
#> ! 1 features showed no variation in the study sample's original values across analyses. 
#> ! 1 features have invalid values after smoothing. NA will be be returned for all values of these faetures. Set `use_original_if_fail = FALSE to return orginal values..
#> ✔ Drift correction was applied to 459 of 460 features (batch-wise).
#> ℹ The median CV change of all features in study samples was -0.56% (range: -10.22% to 2.49%). The median absolute CV of all features across batches decreased from 38.96% to 38.56%.

myexp <- mrmhub::correct_batch_centering(
  myexp, 
  variable = "conc",
  ref_qc_types = "SPL")
#> ℹ Adding batch correction on top of `conc` drift-correction.
#> ✔ Batch median-centering of 6 batches was applied to drift-corrected concentrations of all 502 features.
#> ℹ The median CV change of all features in study samples was -0.44% (range: -27.90% to 10.30%).  The median absolute CV of all features decreased from 38.99% to 38.76%.

myexp <- filter_features_qc(
  data = myexp,
  include_qualifier = FALSE,
  include_istd = FALSE, 
  min.signalblank.median.spl.sblk = 10,
  max.cv.conc.bqc = 25)
#> Calculating feature QC metrics - please wait...
#> ! The QC parameter `min.signalblank.median.spl.sblk` contains NAs for following features: LPC O-22:1, PC 34:5, PC 35:1, PG 36:2, SM 35:1|PC P_32:1 M+1, and SM 35:1|PC .... 
#> These features failed QC.
#> ! The QC parameter `max.cv.conc.bqc` contains NAs for following features: Cer d18:1/12:0 (ISTD) [M-H20>264], Cer d18:1/25:0 (ISTD) [M-H20>264], Hex2Cer.... 
#> These features failed QC.
#> ✔ New feature QC filters were defined: 181 of 423 quantifier features meet QC criteria (not including the 25 quantifier ISTD features).
```

## Plotting data

MRMhub provides various plot function that can be useful in
understanding analytical performance, trends and isses in the data.
Plots are also available to inspect the effect of data processing
(e.g. drift/bath-effect correction) and QC-based feature filtering.

Below we create a `runscatter` plot to visualize the concentration of
specific features across the analytical series in different QC sample
types. The plot can also be saved to a PDF file.

``` r
  plot_runscatter(
    data = myexp,
    variable = "conc",
    include_feature_filter = "PC 4",
    include_istd = FALSE,
    cap_outliers = TRUE,
    log_scale = FALSE,
    output_pdf = FALSE,
    path = "./output/runscatter_PC408_beforecorr.pdf",
    cols_page = 3, rows_page = 2,
  )
#> Generating plots (1 page)...
```

![RunScatter plot with 2x3
panels](T02_settingup_workflow_files/figure-html/unnamed-chunk-4-1.png)

## Exporting and sharing data

Finally, we can export specific datasets as plain csv tables, create a
detailed data report, and share the entire `MRMhubExperiment` object
with someone else without any code, who can run own data processing,
plots and QC checks.

``` r
# Saves a detailed report in Excel format with multiple sheets
mrmhub::save_report_xlsx(myexp, path = tempfile(fileext = ".xlsx"))
#> Saving report to disk - please wait...
#> ✔ The data processing report has been saved to '/tmp/RtmpmOSjpX/file43373bece13e.xlsx'.

# Saves flat csv table with concentration values that passed the previously set
# QC criteria, for each feature in each sample. 
mrmhub::save_dataset_csv(
  data = myexp, 
  path = tempfile(fileext = ".csv"),
  variable = "conc", 
  qc_types = "SPL", 
  include_qualifier = FALSE,
  filter_data = TRUE)
#> ✔ Concentration values for 378 analyses and 181 features have been exported to '/tmp/RtmpmOSjpX/file433743f712f9.csv'.

# Saves the entire MRMhubExperiment object as an RDS file, which can be
# opened in R without MRMhub or used with MRMhub again.
saveRDS(myexp, file = tempfile(fileext = ".rds"), compress = TRUE)
```
