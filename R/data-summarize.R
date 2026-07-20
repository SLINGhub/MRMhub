#' Sum up feature intensities per analyte
#'
#' @description
#' This function sums up feature intensities per analyte_id.
#'
#' This is useful when you have multiple features (e.g. adducts, isotopes, in-source
#' fragments) or isomers that you want to combine into a single analyte intensity
#' value, such as LPC sn1 and sn2 species.
#'
#' @section Experimental:
#' This function is **experimental** and its behaviour may change. It overwrites the
#' `feature_id` of features sharing an `analyte_id` in both the dataset and the
#' analysis metadata, and the original `feature_id` is not backed up anywhere. It is
#' intended to run early (before normalization/quantitation); running it on a
#' processed object drops the derived variables (see Details). Use with caution and
#' check the results carefully.
#'
#' @details
#' Only raw signal variables are aggregated across the transitions of an analyte:
#' `feature_intensity`, `feature_height` and `feature_area` are summed, and
#' `feature_rt` is averaged. `feature_fwhm` and `feature_width` are set to `NA`
#' for merged analytes: the constituents are separate chromatographic peaks, so
#' no aggregate of their peak widths describes the merged quantity.
#'
#' Summing transitions redefines `feature_intensity`, so all values *derived*
#' from the pre-merge intensities are invalidated and removed: normalized
#' intensities, concentrations, drift/batch correction results and QC metrics.
#' Re-run [normalize_by_istd()] and the quantitation/correction steps after
#' merging. A message reports this when such values were present.
#'
#' A merged analyte inherits the feature metadata (`feature_class`,
#' `feature_label`, `istd_feature_id`) of its *first* constituent transition. A
#' warning is issued when the constituents disagree, since the value that wins is
#' then arbitrary -- for `istd_feature_id` it silently decides which internal
#' standard the merged analyte is normalized against.
#'
#' `is_quantifier` is not inherited but determined by the merge: the merged
#' analyte is a quantifier if any of its constituents is one. A quantifier
#' combined with either a qualifier or another quantifier therefore yields a
#' quantifier, whereas qualifiers merged among themselves remain a qualifier.
#'
#' @param data MRMhubExperiment object
#' @param qualifier_action Character. How to handle qualifier features. To sum them up separately select "separate",
#' to include them in the sum if quantifier select "include", to not sum them up select "exclude".
#'
#' @return MRMhubExperiment object
#' @export
#'
# EXPERIMENTAL (see @section Experimental in the roxygen above): overwrites
# feature_id for features sharing an analyte_id with no backup, and is intended
# to run before normalization/quantitation. Behaviour may still change.
data_sum_features <- function(
  data,
  qualifier_action = "include"
) {
  qualifier_action <- rlang::arg_match(
    qualifier_action,
    c("separate", "include", "exclude")
  )
  warn_inconsistent_merged_metadata(data@annot_features)
  ds <- data@dataset

  ds_na_analytes <- ds |> dplyr::filter(is.na(.data$analyte_id))
  ds_to_process <- ds |> dplyr::filter(!is.na(.data$analyte_id))

  aggregate_quant <- function(df) {
    if (nrow(df) == 0) {
      return(df)
    }

    feature_cols <- setdiff(
      names(df)[sapply(df, is.numeric) & grepl("^feature_", names(df))],
      c("feature_id", "feature_class")
    )
    metadata_cols <- c("feature_class", "feature_label")
    # `is_quantifier` is decided by the merge (below), not inherited from the
    # first constituent, so it is kept out of the first-wins metadata block.
    other_cols <- setdiff(
      names(df),
      c(feature_cols, "feature_id", "is_quantifier")
    )

    agg_numeric <- df |>
      dplyr::group_by(.data$analysis_id, .data$analyte_id) |>
      dplyr::summarise(
        dplyr::across(
          any_of(c("feature_intensity", "feature_height", "feature_area")),
          # An all-missing group must stay NA, not become a fabricated 0.
          ~ if (all(is.na(.x))) NA_real_ else sum(.x, na.rm = TRUE)
        ),
        dplyr::across(
          any_of(c("feature_rt")),
          ~ if (all(is.na(.x))) NA_real_ else mean(.x, na.rm = TRUE)
        ),
        # The constituents are separate chromatographic peaks, so neither summing
        # nor averaging their widths describes the merged analyte. Set to NA
        # explicitly rather than reporting a meaningless aggregate.
        dplyr::across(any_of(c("feature_fwhm", "feature_width")), ~NA_real_),
        # The merged analyte quantifies if any constituent does: quant + qual and
        # quant + quant give a quantifier, qual + qual stays a qualifier.
        dplyr::across(
          any_of("is_quantifier"),
          ~ if (all(is.na(.x))) NA else any(.x, na.rm = TRUE)
        ),
        .groups = "drop"
      )

    agg_meta <- df |>
      dplyr::select(
        "analysis_id",
        "analyte_id",
        all_of(metadata_cols),
        all_of(setdiff(other_cols, metadata_cols))
      ) |>
      dplyr::distinct(.data$analysis_id, .data$analyte_id, .keep_all = TRUE)

    agg <- dplyr::left_join(
      agg_numeric,
      agg_meta,
      by = c("analysis_id", "analyte_id")
    )
    agg$feature_id <- agg$analyte_id
    agg
  }

  # --- MODIFICATION: Add a 'suffix' argument to the helper function ---
  process_and_aggregate_subset <- function(df, suffix = "") {
    if (nrow(df) == 0) {
      return(df)
    }

    df_tagged <- df |>
      dplyr::group_by(.data$analysis_id, .data$analyte_id) |>
      dplyr::mutate(.group_size = n()) |>
      dplyr::ungroup()

    rows_to_aggregate <- df_tagged |> dplyr::filter(.data$.group_size > 1)
    rows_to_keep <- df_tagged |>
      dplyr::filter(.data$.group_size <= 1) |>
      dplyr::select(-".group_size")

    aggregated_data <- aggregate_quant(rows_to_aggregate)

    # --- MODIFICATION: Apply the suffix if provided ---
    # This targets ONLY the newly aggregated rows.
    if (nchar(suffix) > 0 && nrow(aggregated_data) > 0) {
      aggregated_data <- aggregated_data |>
        dplyr::mutate(feature_id = paste0(.data$feature_id, suffix))
    }

    dplyr::bind_rows(aggregated_data, rows_to_keep)
  }

  # `is_quantifier` is set by the merge rule in `aggregate_quant()`, not forced
  # here: a blanket TRUE also relabelled unmerged features and turned a
  # qualifier-only analyte into a quantifier.
  if (qualifier_action == "include") {
    ds_res <- process_and_aggregate_subset(ds_to_process)
  } else if (qualifier_action == "exclude") {
    quant_rows <- dplyr::filter(ds_to_process, .data$is_quantifier)
    ds_res <- process_and_aggregate_subset(quant_rows)
  } else {
    # separate
    quant_rows <- dplyr::filter(ds_to_process, .data$is_quantifier)
    qual_rows <- dplyr::filter(ds_to_process, !.data$is_quantifier)

    processed_quants <- process_and_aggregate_subset(quant_rows)

    # --- MODIFICATION: Pass the suffix when processing qualifiers ---
    processed_quals <- process_and_aggregate_subset(qual_rows, suffix = "_qual")

    ds_res <- dplyr::bind_rows(processed_quants, processed_quals)
  }

  ds_res <- dplyr::bind_rows(ds_res, ds_na_analytes)

  ds_res <- ds_res |>
    dplyr::select(any_of(names(data@dataset)))

  data@dataset <- ds_res

  annot <- data@annot_features |>
    mutate(
      is_duplicate = duplicated(.data$analyte_id) |
        duplicated(.data$analyte_id, fromLast = TRUE)
    ) |>
    mutate(
      feature_id = if_else(
        !is.na(.data$analyte_id) & .data$analyte_id != "" & .data$is_duplicate,
        .data$analyte_id,
        .data$feature_id
      )
    ) |>
    # Same merge rule as `aggregate_quant()` above, so the feature metadata and
    # `@dataset` cannot disagree about the merged analyte.
    mutate(
      is_quantifier = if (all(is.na(.data$is_quantifier))) {
        NA
      } else {
        any(.data$is_quantifier, na.rm = TRUE)
      },
      .by = "feature_id"
    ) |>
    # Keyed on `feature_id`, not the whole row: constituents legitimately differ
    # (`feature_class`, `feature_label`), so a full-row `distinct()` kept every
    # one and left a duplicated `feature_id` behind. The first transition's
    # metadata wins, as documented.
    distinct(.data$feature_id, .keep_all = TRUE)

  data@annot_features <- annot

  # Summing transitions redefines `feature_intensity`, so every value derived
  # from the pre-merge intensities no longer describes the data. Invalidate them
  # (removes the columns and informs the user) instead of leaving stale or all-NA
  # values behind, mirroring `correct_interferences()`.
  data <- update_after_normalization(data, FALSE)
  data@var_drift_corrected <- c(
    feature_intensity = FALSE,
    feature_norm_intensity = FALSE,
    feature_conc = FALSE
  )
  data@var_batch_corrected <- c(
    feature_intensity = FALSE,
    feature_norm_intensity = FALSE,
    feature_conc = FALSE
  )
  data@metrics_qc <- data@metrics_qc[FALSE, ]

  # `update_after_normalization()` drops the normalized/quantitated variables
  # themselves, but not the correction snapshots derived from them (`_orig`,
  # `_before`, `_fit`, ...), which would otherwise linger as all-NA columns for
  # the merged analytes.
  derived_vars <- names(data@dataset)[
    grepl("^feature_(intensity|norm_intensity|conc)_", names(data@dataset))
  ]
  data@dataset <- data@dataset |>
    select(-all_of(derived_vars), -any_of("feature_pmol_total"))

  data
}

# Merging transitions attributes the *first* constituent's feature metadata to
# the merged analyte (`distinct(.keep_all = TRUE)` in `aggregate_quant()`). That
# is only safe while the constituents agree; a disagreement means an arbitrary
# value wins, which for `istd_feature_id` silently decides the ISTD the merged
# analyte is normalized against. Checked on the (small) feature metadata rather
# than on the long `@dataset`.
warn_inconsistent_merged_metadata <- function(annot_features) {
  cols <- intersect(
    c("feature_class", "feature_label", "istd_feature_id"),
    names(annot_features)
  )
  if (length(cols) == 0 || !"analyte_id" %in% names(annot_features)) {
    return(invisible(NULL))
  }

  merged <- annot_features |>
    dplyr::filter(!is.na(.data$analyte_id), .data$analyte_id != "") |>
    dplyr::group_by(.data$analyte_id) |>
    dplyr::filter(dplyr::n() > 1) |>
    dplyr::ungroup()
  if (nrow(merged) == 0) {
    return(invisible(NULL))
  }

  conflicts <- merged |>
    dplyr::group_by(.data$analyte_id) |>
    dplyr::summarise(
      dplyr::across(all_of(cols), ~ dplyr::n_distinct(.x) > 1),
      .groups = "drop"
    )
  fields <- cols[vapply(conflicts[cols], any, logical(1))]
  if (length(fields) == 0) {
    return(invisible(NULL))
  }

  analytes <- conflicts$analyte_id[Reduce(`|`, conflicts[fields])]
  cli::cli_warn(c(
    "!" = "{length(analytes)} merged analyte{?s} {?has/have} transitions with differing feature metadata.",
    "i" = "{cli::qty(length(fields))}The first transition's value is used for {?this field/these fields}: {.field {fields}}",
    "i" = "{cli::qty(length(analytes))}Affected analyte{?s}: {.val {mh_vec(analytes)}}"
  ))
  invisible(NULL)
}
