#' @param include_feature_filter A character or regex pattern used to filter
#'   features by `feature_id`. If `NA` or an empty string (`""`) is provided,
#'   the filter is ignored. When a vector of length > 1 is supplied, only
#'   features with exactly these names are selected (applied individually as
#'   OR conditions).
#' @param exclude_feature_filter A character or regex pattern used to exclude
#'   features by `feature_id`. If `NA` or an empty string (`""`) is provided,
#'   the filter is ignored. When a vector of length > 1 is supplied, only
#'   features with exactly these names are excluded (applied individually as
#'   OR conditions).
#' @param min_median_value Minimum median feature value across the selected
#'   QC-type samples required for a feature to be included. `NA` (default)
#'   applies no filtering. This is a fast way to exclude noisy features; for
#'   principled QC-based filtering use [filter_features_qc()].
