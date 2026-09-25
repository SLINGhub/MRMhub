##### UNDER REVISION #####
# Need overhaul due to all changes made

#' Combines a list of `MRMhubExperiment` objects into one
#'
#' @param ... [`MRMhubExperiment`][MRMhubExperiment-class] objects
#' @param ordered_by_runsequence Boolean if list of provided [`MRMhubExperiment`][MRMhubExperiment-class] objects is in the run order
#' @noRd

combine_experiments <- function(..., ordered_by_runsequence) {
  exp_list <- list(...)

  #TODO: check class of all objects

  if (is.null(attr(exp_list, which = "class")[[1]])) {
    exp_list <- exp_list[[1]]
  }

  mexp <- MRMhubExperiment()
  mexp@dataset_orig <- purrr::map_dfr(.x = exp_list, .f = \(x) {
    x@dataset_orig
  }) |>
    dplyr::distinct()
  mexp@dataset <- purrr::map_dfr(.x = exp_list, .f = \(x) x@dataset) |>
    dplyr::distinct()
  mexp@annot_analyses <- purrr::map_dfr(.x = exp_list, .f = \(x) {
    x@annot_analyses
  }) |>
    dplyr::distinct() |>
    mutate(analysis_order = dplyr::row_number())
  mexp@annot_istds <- purrr::map_dfr(.x = exp_list, .f = \(x) x@annot_istds) |>
    dplyr::distinct()
  mexp@annot_features <- purrr::map_dfr(.x = exp_list, .f = \(x) {
    x@annot_features
  }) |>
    dplyr::distinct()
  # ToDo: Combine batch and curve id to give unique curve id over the combined experiment
  mexp@annot_responsecurves <- purrr::map_dfr(.x = exp_list, .f = \(x) {
    x@annot_responsecurves
  }) |>
    dplyr::distinct()

  mexp@dataset <- mexp@dataset |>
    dplyr::rename(batch_analysis_order = .data$analysis_order) |>
    dplyr::group_by(.data$feature_id) |>
    dplyr::mutate(
      analysis_order = dplyr::row_number(),
      .before = .data$batch_analysis_order
    ) |>
    dplyr::ungroup()

  mexp@annot_batches <- get_metadata_batches(mexp@annot_analyses)
  mexp
}
