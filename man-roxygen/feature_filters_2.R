#' @param include_feature_filter A regex pattern or a vector of feature names
#'   used to filter features by `feature_id`. If `NA` or an empty string (`""`)
#'   is provided, the filter is ignored. When a vector of length > 1 is
#'   supplied, only features with exactly these names are selected (applied
#'   individually as OR conditions).
#' @param exclude_feature_filter A regex pattern or a vector of feature names
#'   used to exclude features by `feature_id`. If `NA` or an empty string
#'   (`""`) is provided, the filter is ignored. When a vector of length > 1 is
#'   supplied, only features with exactly these names are excluded (applied
#'   individually as OR conditions).
