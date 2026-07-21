#' @param include_feature_filter Feature(s) to include by `feature_id`, as a
#'   character vector. Each element is matched exactly when it names an existing
#'   feature, otherwise treated as a regex; elements combine with OR. A full ID
#'   (e.g. `"S1P d18:0 [M>60]"`) needs no escaping, while patterns like `"PC|PE"`
#'   still work. `NA` or `""` ignores the filter.
#' @param exclude_feature_filter Feature(s) to exclude by `feature_id`, matched
#'   the same way as `include_feature_filter`. `NA` or `""` ignores the filter.
