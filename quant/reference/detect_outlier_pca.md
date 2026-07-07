# Get list of analyses classified as technical outliers

Retrieves analysis IDs of data outliers based the principal components
PCA with SD or MAD fences

## Usage

``` r
detect_outlier_pca(
  data = NULL,
  variable,
  filter_data,
  pca_component,
  qc_types = NA,
  fence_multiplicator,
  summarize_fun = c("pca", "rma"),
  outlier_detection = c("sd", "mad"),
  log_transform = TRUE
)
```

## Arguments

- data:

  MRMhubExperiment object

- variable:

  Feature variable used for outlier detection

- filter_data:

  Use all (default) or qc-filtered data

- pca_component:

  PCA component to be used

- qc_types:

  QC types included in the outlier detection

- fence_multiplicator:

  Multiplicator for SD or MAD, respectively.

- summarize_fun:

  Function used to summarize the features, either "pca" based on PCA, or
  "rma" based on mean relative abundance (RMA) of all features

- outlier_detection:

  Outlier detection method, either based on "sd" or "mad"

- log_transform:

  Log-transform data for outlier detection

## Value

MRMhubExperiment object
