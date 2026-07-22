#' Load an example `MRMhubExperiment` dataset
#' @description
#' Load an example `MRMhubExperiment` dataset: a small, preprocessed subset of a
#' plasma lipidomics dataset (Tan et al., ATVB, 2022).
#'
#' @param data [`MRMhubExperiment`][MRMhubExperiment-class] object, optional. Data will be overwritten if provided.
#' @param dataset Which example dataset to load. Currently only `1` (the default) is available.
#'
#' @return [`MRMhubExperiment`][MRMhubExperiment-class] object
#' @examples
#' myexp <- MRMhubExperiment()
#' myexp <- data_load_example(myexp)
#' myexp

#' @export
data_load_example <- function(data = NULL, dataset = 1) {
  if (dataset != 1) {
    cli::cli_abort(
      "{.arg dataset} must be {.val {1}}; only dataset 1 is currently available."
    )
  }
  data <- lipidomics_dataset
  check_data(data)

  n_analyses <- dplyr::n_distinct(data@dataset_orig$analysis_id)
  n_features <- dplyr::n_distinct(data@dataset_orig$feature_id)
  mh_success(
    "Loaded example dataset {dataset}: {n_analyses} analys{?is/es} and {n_features} feature{?s}."
  )
  data
}
