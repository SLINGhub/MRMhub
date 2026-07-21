#' Derive isotopic interference relationships
#'
#' @description Automatically discovers isotopic (M+2) interference relationships
#' between measured features and stores them in the `annot_interferences` slot,
#' ready for [correct_interferences()]. Two levels are supported:
#'
#' - **`"MRM"`** (default): fragment-based front/back correction for class-based
#'   LC-MRM data, derived from the LICAR method (see the manual). Requires
#'   precursor **and** product m/z and an `mrm_pattern` per feature.
#' - **`"MS1"`**: whole-molecule M+2 correction for **MS1 / full-scan**
#'   acquisitions. The factor is the M+2 relative abundance of each species'
#'   molecular formula; interfering pairs are matched by precursor m/z (~2 Da
#'   apart) within a feature class. Requires precursor m/z only.
#'
#' @details **Important — MS1 is not a fallback for MRM.** For MRM data the
#' isotopic correction must be *fragment-based*: the contribution of heavy
#' isotopes to a transition depends on the isotope's location relative to the
#' fragmentation (Gao et al. 2021). The whole-molecule (`"MS1"`) level is only
#' valid for genuine MS1/full-scan measurements and must **not** be used as a
#' substitute for MRM data that happens to lack a product m/z.
#'
#' Derived factors are sensitive to the \pkg{enviPat} version; version 2.8 is the
#' reference. Existing manual interferences (`source == "manual"`) are preserved;
#' previously derived (`"auto"`) rows are replaced.
#'
#' @param data A `MRMhubExperiment` object.
#' @param level Correction level, `"MRM"` or `"MS1"`. See description.
#' @param mz_tol Precursor m/z tolerance (Da) for matching interfering pairs.
#'   Default `0.5`.
#' @param check_coelution If `TRUE` (default, when retention data are present),
#'   an m/z-matched edge is kept only if the interferer and victim co-elute --
#'   the interferer's peak apex falls within the victim's integration window.
#'   Chromatographically resolved pairs are dropped (subtracting them would remove
#'   real signal). Uses the imported integration borders
#'   (`feature_int_start`/`feature_int_end`), falling back to `feature_rt +/- FWHM`.
#' @return The `MRMhubExperiment` with a populated `annot_interferences` slot.
#' @references Gao L. et al. (2021). LICAR: An Application for Isotopic Correction
#'   of Targeted Lipidomic Data Acquired with Class-Based Chromatographic
#'   Separations Using Multiple Reaction Monitoring. *Analytical Chemistry*,
#'   93(6), 3163-3171. \doi{10.1021/acs.analchem.0c04565}
#' @export
derive_interferences <- function(
  data = NULL,
  level = c("MRM", "MS1"),
  mz_tol = 0.5,
  check_coelution = TRUE
) {
  check_data(data)
  level <- rlang::arg_match(level)

  if (utils::packageVersion("enviPat") != "2.8") {
    mh_warn(
      "Installed enviPat is {utils::packageVersion('enviPat')}, not the reference version 2.8; derived factors may differ slightly from published LICAR values."
    )
  }

  edges <- switch(
    level,
    MS1 = derive_ms1_edges(data, mz_tol = mz_tol),
    MRM = derive_mrm_edges(data, mz_tol = mz_tol)
  )

  if (check_coelution) {
    edges <- apply_coelution_gate(data, edges)
  }

  # Preserve manual interferences; replace any previously derived (auto) rows.
  kept <- data@annot_interferences |> filter(.data$source != "auto")
  data@annot_interferences <- bind_rows(kept, edges)

  mh_success(
    "Derived {nrow(edges)} interference edge(s) ({level} level) for {length(unique(edges$feature_id))} feature(s)."
  )
  data
}


#' MS1 (whole-molecule) interference edges
#'
#' Matches, within each feature class, a lighter species whose M+2 isotopologue
#' overlaps the monoisotopic precursor of a ~2 Da heavier species, and records the
#' lighter species' whole-molecule M+2 abundance as the contribution.
#'
#' @param data A `MRMhubExperiment`.
#' @param mz_tol Precursor m/z tolerance (Da).
#' @return A long interference edge tibble (`source == "auto"`).
#' @keywords internal
#' @noRd
derive_ms1_edges <- function(data, mz_tol = 0.5) {
  if (!"method_precursor_mz" %in% names(data@dataset_orig)) {
    cli_abort(
      "MS1 interference derivation requires precursor m/z (`method_precursor_mz`) in the analysis data."
    )
  }
  # MS1 correction is precursor-only and thus intended for MS1/full-scan data.
  # Product m/z signals MRM data, where correction must be fragment-based and
  # several transitions can share one precursor (see `?derive_interferences`).
  if ("method_product_mz" %in% names(data@dataset_orig)) {
    mh_warn(
      "The data contain product m/z (MRM). MS1 whole-molecule correction is intended for MS1/full-scan data and is not a substitute for MRM correction (`level = \"MRM\"`)."
    )
  }

  # One representative precursor m/z per feature.
  d_mz <- data@dataset_orig |>
    select("feature_id", "method_precursor_mz") |>
    mutate(precursor_mz = suppressWarnings(as.numeric(.data$method_precursor_mz))) |>
    group_by(.data$feature_id) |>
    summarise(
      precursor_mz = stats::median(.data$precursor_mz, na.rm = TRUE),
      .groups = "drop"
    )

  # Molecular formula per feature: the metadata `chem_formula` if present, else
  # derived from the feature name via rgoslin (parse_lipid_feature_names()).
  feats <- data@annot_features |>
    select("feature_id", "feature_class", "chem_formula", "is_istd")
  need <- is.na(feats$chem_formula) | !nzchar(feats$chem_formula)
  if (any(need)) {
    parsed <- parse_lipid_feature_names(
      dplyr::tibble(feature_id = feats$feature_id[need]),
      add_chain_composition = FALSE
    )
    feats$chem_formula[need] <- parsed$chem_formula[
      match(feats$feature_id[need], parsed$feature_id)
    ]
  }

  feats$m2 <- mN_rel_abundance(feats$chem_formula, 2L)

  tbl <- feats |>
    left_join(d_mz, by = "feature_id") |>
    filter(
      !.data$is_istd,
      !is.na(.data$precursor_mz),
      !is.na(.data$m2),
      !is.na(.data$feature_class),
      nzchar(.data$feature_class)
    )

  if (nrow(tbl) == 0) {
    mh_warn(
      "MS1 derivation found no features with a molecular formula, precursor m/z and class. Nothing derived."
    )
    return(pkg.env$table_templates$annot_interferences_template)
  }

  # Within a class, pair a lighter interferer with a ~2 Da heavier victim; the
  # interferer's M+2 abundance is the contribution.
  interferers <- tbl |>
    select(
      interference_feature_id = "feature_id",
      "feature_class",
      prec_a = "precursor_mz",
      contribution = "m2"
    )
  victims <- tbl |>
    select(feature_id = "feature_id", "feature_class", prec_b = "precursor_mz")

  edges <- interferers |>
    inner_join(victims, by = "feature_class", relationship = "many-to-many") |>
    filter(
      .data$interference_feature_id != .data$feature_id,
      abs((.data$prec_b - .data$prec_a) - 2) <= mz_tol
    ) |>
    mutate(
      interference_contribution = .data$contribution,
      overlap_type = "ms1_m2",
      source = "auto"
    ) |>
    select(
      "feature_id",
      "interference_feature_id",
      "interference_contribution",
      "overlap_type",
      "source"
    ) |>
    distinct()

  edges
}


#' Co-elution gate: keep only edges whose species share an elution window
#'
#' An isotopologue elutes at its monoisotopic apex, so an interferer's M+2 lands
#' in a victim's integrated area only if they co-elute. Keeps an edge when the
#' interferer's apex (`feature_rt`) falls inside the victim's integration window
#' (`feature_int_start`..`feature_int_end`, or `feature_rt +/- FWHM` when borders
#' are absent). Chromatographically resolved pairs are dropped and reported. When
#' no retention data exist, co-elution cannot be verified and edges are kept.
#'
#' @param data A `MRMhubExperiment`.
#' @param edges A long interference edge tibble.
#' @return `edges` with resolved-pair rows removed.
#' @keywords internal
#' @noRd
apply_coelution_gate <- function(data, edges) {
  if (nrow(edges) == 0) {
    return(edges)
  }
  do <- data@dataset_orig
  rt_cols <- c("feature_rt", "feature_int_start", "feature_int_end", "feature_fwhm")
  if (!"feature_rt" %in% names(do)) {
    mh_warn(
      "Co-elution could not be verified (no retention time in the data); all m/z-matched edges were kept."
    )
    return(edges)
  }

  win <- do |>
    select("feature_id", any_of(rt_cols)) |>
    group_by(.data$feature_id) |>
    summarise(
      across(
        any_of(rt_cols),
        ~ stats::median(suppressWarnings(as.numeric(.x)), na.rm = TRUE)
      ),
      .groups = "drop"
    )
  has_border <- all(c("feature_int_start", "feature_int_end") %in% names(win))
  has_fwhm <- "feature_fwhm" %in% names(win)

  # Victim integration window: borders if available, else apex +/- FWHM.
  win$lo <- if (has_border) win$feature_int_start else NA_real_
  win$hi <- if (has_border) win$feature_int_end else NA_real_
  if (has_fwhm) {
    need <- is.na(win$lo) | is.na(win$hi)
    win$lo[need] <- win$feature_rt[need] - win$feature_fwhm[need]
    win$hi[need] <- win$feature_rt[need] + win$feature_fwhm[need]
  }

  apex <- stats::setNames(win$feature_rt, win$feature_id)
  lo <- stats::setNames(win$lo, win$feature_id)
  hi <- stats::setNames(win$hi, win$feature_id)

  a_apex <- apex[edges$interference_feature_id]
  b_lo <- lo[edges$feature_id]
  b_hi <- hi[edges$feature_id]
  # Keep when co-eluting, or when the window/apex is unknown (unverifiable).
  keep <- is.na(a_apex) | is.na(b_lo) | is.na(b_hi) |
    (a_apex >= b_lo & a_apex <= b_hi)

  n_drop <- sum(!keep)
  if (n_drop > 0) {
    mh_warn(
      "Co-elution gate dropped {n_drop} m/z-matched edge(s) whose species are chromatographically resolved (interferer apex outside the victim's integration window)."
    )
  }
  edges[keep, , drop = FALSE]
}
