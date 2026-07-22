##### UNDER REVISION #####
# Need re-consider this function and needs overhaul due to all changes made and

#' Get list of analyses classified as technical outliers
#'
#' @description
#' Retrieves analysis IDs of data outliers based on the principal components (PCA)
#' with SD or MAD fences
#'
#' @param data [`MRMhubExperiment`][MRMhubExperiment-class] object
#' @param variable Feature variable used for outlier detection
#' @param filter_data Use all (default) or qc-filtered data
#' @param pca_component PCA component to be used
#' @param qc_types QC types included in the outlier detection
#' @param fence_multiplicator Multiplier for SD or MAD.
#' @param summarize_fun Function used to summarize the features, either "pca" based on PCA, or "rma" based on Relative Mean Abundance (RMA) of all features
#' @param outlier_detection Outlier detection method, either based on "sd" or "mad"
#' @param log_transform Log-transform data for outlier detection
#' @return [`MRMhubExperiment`][MRMhubExperiment-class] object
#' @export

detect_outlier_pca <- function(
  data = NULL,
  variable,
  filter_data,
  pca_component,
  qc_types = NA,
  fence_multiplicator,
  summarize_fun = c("pca", "rma"),
  outlier_detection = c("sd", "mad"),
  log_transform = TRUE
) {
  check_data(data)

  # Mirror the numeric-positive guards on `kernel_size` / `outlier_ksd` in
  # correct_drift_gaussiankernel(); both args lack a default, so also catch the
  # missing case before the obscure "argument ... is missing" further down.
  if (missing(pca_component) || is.na(pca_component) || pca_component <= 0) {
    cli::cli_abort("{.arg pca_component} must be greater than 0.")
  }
  if (
    missing(fence_multiplicator) ||
      is.na(fence_multiplicator) ||
      fence_multiplicator <= 0
  ) {
    cli::cli_abort("{.arg fence_multiplicator} must be greater than 0.")
  }

  variable <- str_remove(variable, "feature_")
  rlang::arg_match(
    variable,
    c(
      "area",
      "height",
      "intensity",
      "response",
      "conc",
      "conc_raw",
      "rt",
      "fwhm"
    )
  )
  variable <- stringr::str_c("feature_", variable)
  check_var_in_dataset(data@dataset, variable)

  if (all(is.na(qc_types))) {
    qc_types <- c("BQC", "TQC", "SPL", "LTR", "NIST", "QC")
  } else {
    missing_qc_types <- setdiff(qc_types, unique(data@dataset$qc_type))

    if (length(missing_qc_types) > 0) {
      cli::cli_abort(
        "The following specified QC types are missing in the dataset: {.val {missing_qc_types}}."
      )
    }
  }

  summarize_fun <- rlang::arg_match(summarize_fun, c("pca", "rma"))
  outlier_detection <- rlang::arg_match(outlier_detection, c("sd", "mad"))

  # Filter data if filter_data is TRUE
  if (filter_data) {
    d_sel <- data@dataset_filtered |> dplyr::ungroup()
    if (!data@is_filtered) {
      cli::cli_abort(
        "Data has not been qc filtered, or has changed. Please run `filter_features_qc` first."
      )
    }
  } else {
    d_sel <- data@dataset |> dplyr::ungroup()
  }

  pc_x <- rlang::sym(paste0(".fittedPC", pca_component))

  if (summarize_fun == "rma") {
    cli::cli_abort(
      "Relative Mean Abundance has not yet been implemented. Please use 'pca'"
    )
  }

  d_filt <- d_sel |>
    filter(.data$qc_type %in% qc_types) |>
    filter(!.data$is_istd) |>
    dplyr::select(
      "analysis_id",
      "qc_type",
      "batch_id",
      "feature_id",
      {{ variable }}
    )

  d_wide <- d_filt |>
    tidyr::pivot_wider(
      id_cols = "analysis_id",
      names_from = "feature_id",
      values_from = {{ variable }}
    )

  d_wide <- d_wide |>
    filter(if_any(dplyr::where(is.numeric), ~ !is.na(.))) |>
    dplyr::select(where(~ !any(is.na(.) | is.nan(.) | is.infinite(.) | . <= 0)))

  m_raw <- d_wide |>
    tibble::column_to_rownames("analysis_id") |>
    as.matrix()

  if (log_transform) {
    m_raw <- log2(m_raw)
  }
  pca_res <- prcomp(m_raw, scale = TRUE, center = TRUE)

  d_metadata <- d_filt |>
    dplyr::select("analysis_id", "qc_type", "batch_id") |>
    dplyr::distinct()
  pca_annot <- pca_augment(pca_res, d_metadata)

  if (outlier_detection == "sd") {
    d_outlier <- pca_annot |>
      filter(
        {{ pc_x }} > (mean({{ pc_x }}) + fence_multiplicator * sd({{ pc_x }})) |
          {{ pc_x }} < (mean({{ pc_x }}) - fence_multiplicator * sd({{ pc_x }}))
      )
  } else {
    d_outlier <- pca_annot |>
      filter(
        {{ pc_x }} >
          (median({{ pc_x }}) + fence_multiplicator * mad({{ pc_x }})) |
          {{ pc_x }} <
            (median({{ pc_x }}) - fence_multiplicator * mad({{ pc_x }}))
      )
  }

  if (nrow(d_outlier) > 0) {
    return(d_outlier$analysis_id)
  } else {
    return(NULL)
  }
}
