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
#' feature metadata, and the original `feature_id` is not backed up anywhere. Run
#' it after importing metadata and after any exclusions, [set_analysis_order()]
#' or [set_intensity_var()], and before normalization/quantitation: these steps
#' rebuild the dataset from the imported data and stop with an error once
#' features were summed. Running it on a processed object drops the derived
#' variables (see Details).
#'
#' @details
#' Features are summed when they share an `analyte_id` (an empty one counts as
#' missing): with `qualifier_action = "include"` all of them, with `"separate"`
#' quantifiers and qualifiers each into their own feature (the qualifier sum is
#' named `<analyte_id>_qual`), and with `"exclude"` only the quantifiers, while
#' qualifiers are kept as they are. An analyte with a single feature in its group
#' keeps its `feature_id`. Only features present in the dataset are summed:
#' excluded features and features listed only in the metadata keep their
#' `feature_id` and do not affect the sum.
#'
#' Only raw signal variables are aggregated across the transitions of an analyte:
#' `feature_intensity`, `feature_height` and `feature_area` are summed, and
#' `feature_rt` is averaged. A sum is `NA` in an analysis where a constituent is
#' missing, since a partial sum would look like a valid value; a warning reports
#' these analyses. `feature_fwhm`, `feature_width`, `feature_int_start` and
#' `feature_int_end` are set to `NA` for merged analytes: the constituents are
#' separate chromatographic peaks, so no aggregate of their peak widths or
#' borders describes the merged quantity.
#'
#' Summing transitions redefines `feature_intensity`, so all values *derived*
#' from the pre-merge intensities are invalidated and removed: normalized
#' intensities, concentrations, drift/batch correction results and QC metrics.
#' Re-run [normalize_by_istd()] and the quantitation/correction steps after
#' merging. A message reports this when such values were present.
#'
#' The summed features must be measured and quantified alike: an error is raised
#' when they combine internal standards with analytes, or differ in
#' `istd_feature_id`, `quant_istd_feature_id`, `response_factor` or
#' `interference_feature_id`. An error is also raised when a summed id equals
#' the `feature_id` of another feature. Transitions of one internal standard can
#' be summed; references to summed features in the feature, ISTD and
#' interference metadata are updated, and interferences between transitions
#' summed into one feature are removed. Other metadata (`feature_class`,
#' `feature_label`) comes from the first constituent, with a warning when the
#' constituents disagree.
#'
#' `is_quantifier` is not inherited but determined by the merge: the merged
#' analyte is a quantifier if any of its constituents is one.
#'
#' @param data [`MRMhubExperiment`][MRMhubExperiment-class] object
#' @param qualifier_action Character. How to handle qualifier features. To sum them up separately select "separate",
#' to include them in the sum if quantifier select "include", to not sum them up select "exclude".
#'
#' @return [`MRMhubExperiment`][MRMhubExperiment-class] object
#' @export
#'
data_sum_features <- function(
  data,
  qualifier_action = "include"
) {
  check_data(data)
  qualifier_action <- rlang::arg_match(
    qualifier_action,
    c("separate", "include", "exclude")
  )
  af <- data@annot_features |>
    dplyr::left_join(
      sum_feature_mapping(
        data@annot_features,
        qualifier_action,
        unique(data@dataset$feature_id)
      ),
      by = "feature_id"
    )
  remap <- function(x) {
    dplyr::if_else(x %in% af$feature_id, af$new_id[match(x, af$feature_id)], x)
  }
  # ISTD and interference references follow the summed ids (an ISTD refers to
  # itself)
  af <- af |>
    mutate(across(
      any_of(c(
        "istd_feature_id",
        "quant_istd_feature_id",
        "interference_feature_id"
      )),
      remap
    ))
  af <- drop_internal_interferences(af)
  check_merged_metadata(af)

  # Feature metadata: one row per new id; a merged analyte is a quantifier if
  # any constituent is one, other metadata comes from the first constituent.
  annot <- af |>
    mutate(
      is_quantifier = if (all(is.na(.data$is_quantifier))) {
        NA
      } else {
        any(.data$is_quantifier, na.rm = TRUE)
      },
      .by = "new_id"
    ) |>
    distinct(.data$new_id, .keep_all = TRUE) |>
    mutate(feature_id = .data$new_id) |>
    select(-"new_id", -"n_members")

  # Dataset: sum the raw signals per analysis and new id. A sum is NA when a
  # constituent is missing in that analysis, as a partial sum would look valid.
  annot_cols <- setdiff(
    intersect(names(annot), names(data@dataset)),
    "feature_id"
  )
  sum_vars <- intersect(
    c("feature_intensity", "feature_height", "feature_area"),
    names(data@dataset)
  )
  peak_vars <- c(
    "feature_fwhm",
    "feature_width",
    "feature_int_start",
    "feature_int_end"
  )
  ds <- data@dataset |>
    select(-all_of(annot_cols)) |>
    dplyr::left_join(
      af |> select("feature_id", "new_id", "n_members"),
      by = "feature_id"
    )
  ds_merged <- ds |>
    filter(.data$n_members > 1) |>
    summarise(
      .n_obs = sum(!is.na(.data$feature_intensity)),
      .complete = dplyr::n() == dplyr::first(.data$n_members),
      across(all_of(sum_vars), sum),
      across(
        any_of("feature_rt"),
        ~ if (all(is.na(.x))) NA_real_ else mean(.x, na.rm = TRUE)
      ),
      # The constituents are separate chromatographic peaks, so no aggregate of
      # their widths or borders describes the merged analyte.
      across(any_of(peak_vars), ~NA_real_),
      across(
        -any_of(c(
          sum_vars,
          "feature_rt",
          peak_vars,
          "feature_id",
          "n_members"
        )),
        dplyr::first
      ),
      .by = c("analysis_id", "new_id")
    ) |>
    mutate(across(all_of(sum_vars), ~ if_else(.data$.complete, .x, NA_real_)))

  partial <- ds_merged |>
    filter(.data$.n_obs > 0, is.na(.data$feature_intensity)) |>
    dplyr::count(.data$new_id)
  if (nrow(partial) > 0) {
    cli::cli_warn(c(
      "!" = "Summed intensities set to {.val {NA}} in analyses with a missing constituent transition.",
      "i" = "Affected analytes (analyses): {.val {mh_vec(paste0(partial$new_id, ' (', partial$n, ')'))}}"
    ))
  }

  ds_res <- dplyr::bind_rows(
    ds_merged |> select(-".n_obs", -".complete"),
    ds |> filter(.data$n_members == 1 | is.na(.data$n_members))
  ) |>
    mutate(feature_id = dplyr::coalesce(.data$new_id, .data$feature_id)) |>
    dplyr::left_join(
      annot |> select("feature_id", all_of(annot_cols)),
      by = "feature_id"
    ) |>
    select(all_of(names(data@dataset)))

  data@dataset <- ds_res
  data@annot_features <- annot
  if (any(af$n_members > 1)) {
    attr(data@dataset_orig, "summed_features") <- TRUE
  }
  data@annot_istds <- remap_istd_table(data@annot_istds, remap)
  data@annot_interferences <- remap_interferences(
    data@annot_interferences,
    remap
  )

  # Summing transitions redefines `feature_intensity`, so every value derived
  # from the pre-merge intensities no longer describes the data. Invalidate them
  # (removes the columns and informs the user) instead of leaving stale or all-NA
  # values behind, mirroring the interference-correction functions.
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
  # Per-feature fits are orphaned once transitions are merged into analytes.
  data@metrics_calibration <- data@metrics_calibration[FALSE, ]

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

# Maps each feature to the id it has after summing (`new_id`) and the number of
# transitions summed into it (`n_members`). Features in the data (`present`)
# share a group when they share an `analyte_id` (an empty one counts as missing)
# and, depending on `qualifier_action`, their quantifier role; a group of one
# and features absent from the data (excluded, metadata-only) keep their id.
sum_feature_mapping <- function(annot_features, qualifier_action, present) {
  analyte <- dplyr::na_if(annot_features$analyte_id, "")
  analyte[!annot_features$feature_id %in% present] <- NA
  qual <- !annot_features$is_quantifier %in% TRUE
  suffix <- switch(
    qualifier_action,
    include = rep("", length(analyte)),
    exclude = dplyr::if_else(qual, NA_character_, ""),
    separate = dplyr::if_else(qual, "_qual", "")
  )
  group <- dplyr::if_else(is.na(suffix), NA_character_, paste0(analyte, suffix))
  group[is.na(analyte)] <- NA
  tibble(feature_id = annot_features$feature_id, group = group) |>
    mutate(n_members = dplyr::n(), .by = "group") |>
    mutate(
      n_members = dplyr::if_else(is.na(.data$group), 1L, .data$n_members),
      new_id = dplyr::if_else(
        .data$n_members > 1,
        .data$group,
        .data$feature_id
      )
    ) |>
    select("feature_id", "new_id", "n_members")
}

# Summing is only sound for transitions of one analyte measured and quantified
# alike: abort when a group mixes ISTDs and analytes or uses different ISTDs or
# response factors. Other differing metadata (class, label) takes the first
# constituent's value, with a warning.
check_merged_metadata <- function(af) {
  merged <- af |> filter(.data$n_members > 1)
  if (nrow(merged) == 0) {
    return(invisible(NULL))
  }
  clash <- intersect(merged$new_id, af$feature_id[af$n_members == 1])
  if (length(clash) > 0) {
    cli::cli_abort(
      c(
        "x" = "Summed feature id{?s} {.val {mh_vec(clash)}} {?is/are} already used by another feature.",
        "i" = "Change the {.field analyte_id} of the summed transitions, or give the other feature the same {.field analyte_id} to include it in the sum."
      ),
      call = rlang::caller_env()
    )
  }
  differs <- function(cols) {
    cols <- intersect(cols, names(merged))
    merged |>
      summarise(
        across(all_of(cols), ~ dplyr::n_distinct(.x) > 1),
        .by = "new_id"
      ) |>
      tidyr::pivot_longer(-"new_id", names_to = "field") |>
      filter(.data$value)
  }

  mixed <- differs("is_istd")
  if (nrow(mixed) > 0) {
    cli::cli_abort(
      c(
        "x" = "Summed features must not combine internal standards and analytes: {.val {mh_vec(mixed$new_id)}}.",
        "i" = "Give the internal standards their own {.field analyte_id} in the feature metadata."
      ),
      call = rlang::caller_env()
    )
  }
  quant <- differs(c(
    "istd_feature_id",
    "quant_istd_feature_id",
    "response_factor",
    "interference_feature_id"
  ))
  if (nrow(quant) > 0) {
    cli::cli_abort(
      c(
        "x" = "Features summed into {.val {mh_vec(unique(quant$new_id))}} differ in {.field {unique(quant$field)}}.",
        "i" = "Harmonise these values in the feature metadata before summing."
      ),
      call = rlang::caller_env()
    )
  }
  other <- differs(c("feature_class", "feature_label"))
  if (nrow(other) > 0) {
    cli::cli_warn(c(
      "!" = "{dplyr::n_distinct(other$new_id)} merged analyte{?s} {?has/have} transitions with differing feature metadata.",
      "i" = "The first transition's value is used for {.field {unique(other$field)}}.",
      "i" = "Affected: {.val {mh_vec(unique(other$new_id))}}"
    ))
  }
  invisible(NULL)
}

# An interference between transitions summed into one feature no longer
# describes an interference: it is removed from the feature metadata.
drop_internal_interferences <- function(af) {
  self <- af$n_members > 1 &
    (af$interference_feature_id == af$new_id) %in% TRUE
  if (any(self)) {
    cli::cli_warn(c(
      "!" = "Interferences between transitions summed into one feature were removed from the feature metadata.",
      "i" = "Affected: {.val {mh_vec(unique(af$new_id[self]))}}"
    ))
    af$interference_feature_id[self] <- NA_character_
    af$interference_contribution[self] <- NA_real_
  }
  af
}

# ISTD rows follow the summed ISTD ids; rows that collapse must agree on the
# spiked concentration.
remap_istd_table <- function(annot_istds, remap) {
  if (nrow(annot_istds) == 0) {
    return(annot_istds)
  }
  out <- annot_istds |>
    mutate(across(
      any_of(c("istd_feature_id", "quant_istd_feature_id")),
      remap
    ))
  key <- intersect(c("istd_feature_id", "quant_istd_feature_id"), names(out))
  conflicting <- out |>
    summarise(
      n = dplyr::n_distinct(dplyr::pick(dplyr::starts_with("istd_conc"))),
      .by = all_of(key)
    ) |>
    filter(.data$n > 1)
  if (nrow(conflicting) > 0) {
    ids <- unique(conflicting[[key[length(key)]]])
    cli::cli_abort(
      c(
        "x" = "Internal standards summed into {.val {mh_vec(ids)}} have different concentrations in the ISTD metadata.",
        "i" = "Use one concentration for these transitions in the ISTD metadata, or give them different {.field analyte_id}s."
      ),
      call = rlang::caller_env()
    )
  }
  out[!duplicated(out[key]), ]
}

# Interference pairs follow the summed ids; a pair within one summed feature no
# longer describes an interference and is dropped.
remap_interferences <- function(annot_interferences, remap) {
  if (nrow(annot_interferences) == 0) {
    return(annot_interferences)
  }
  out <- annot_interferences |>
    mutate(across(c("feature_id", "interference_feature_id"), remap))
  self <- out$feature_id == out$interference_feature_id
  if (any(self)) {
    cli::cli_warn(
      "{sum(self)} interference pair{?s} within a summed feature {?was/were} removed."
    )
  }
  out[!self, ]
}


#' Summarize interference relationships
#'
#' @description Prints and returns a rollup of the interference relationships
#' defined for the experiment -- automatically derived
#' ([calc_isotopic_interferences()]) and declared (custom) -- so they can be
#' reviewed before, and after, applying a correction. Reports the affected
#' features, a split by source and overlap type, the contribution-factor range
#' and, once the data are corrected, the per-feature median impact.
#'
#' @param data A [`MRMhubExperiment`][MRMhubExperiment-class].
#' @return Invisibly, a tibble of the assembled, de-duplicated interference edges
#'   (with a `pct_impact` column when the data are already corrected). Called
#'   mainly for the printed summary.
#' @seealso [calc_isotopic_interferences()], [correct_isotopic_interferences()],
#'   [correct_custom_interferences()]
#' @export
summarize_interferences <- function(data = NULL) {
  check_data(data)
  edges <- assemble_interference_edges(data)
  if (nrow(edges) == 0) {
    mh_info("No interferences are defined (none derived or declared).")
    return(invisible(edges))
  }

  n_total <- sum(!isTRUE_col(data@annot_features$is_istd))
  n_affected <- dplyr::n_distinct(edges$feature_id)
  n_interferers <- dplyr::n_distinct(edges$interference_feature_id)
  n_auto <- sum(edges$source == "auto")
  n_custom <- nrow(edges) - n_auto
  k <- edges$interference_contribution[!is.na(edges$interference_contribution)]

  # Per-feature median impact (% of raw signal removed), when correction ran.
  pct <- NULL
  if (
    all(
      c("feature_intensity_orig", "interference_corrected") %in%
        names(data@dataset)
    )
  ) {
    pct <- data@dataset |>
      filter(
        .data$interference_corrected,
        !is.na(.data$feature_intensity_orig),
        .data$feature_intensity_orig > 0
      ) |>
      mutate(
        pct = 100 *
          (.data$feature_intensity_orig - .data$feature_intensity) /
          .data$feature_intensity_orig
      ) |>
      group_by(.data$feature_id) |>
      summarise(
        pct_impact = stats::median(.data$pct, na.rm = TRUE),
        .groups = "drop"
      )
  }

  bullets <- c(
    "*" = "Affected features: {n_affected} of {n_total}",
    "*" = "Edges: {nrow(edges)} ({n_auto} auto / {n_custom} custom){interference_type_breakdown(edges)}",
    "*" = "Interferer features: {n_interferers}"
  )
  if (length(k) > 0) {
    bullets <- c(
      bullets,
      "*" = "Contribution K: {signif(min(k), 2)}-{signif(max(k), 2)}"
    )
  }
  if (!is.null(pct) && nrow(pct) > 0) {
    bullets <- c(
      bullets,
      "*" = "Median impact: {round(stats::median(pct$pct_impact), 1)}% (max {round(max(pct$pct_impact), 1)}%)"
    )
  }
  cli::cli_h3("Interference summary")
  cli::cli_bullets(bullets)

  out <- edges
  if (!is.null(pct)) {
    out <- left_join(out, pct, by = "feature_id")
  }
  invisible(out)
}
