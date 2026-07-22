# Ported LICAR chemistry for fragment-based (MRM) isotopic interference
# correction. The class choices, per-class fragment offsets and the M+2
# calculation are copied from LICAR (Gao et al. 2021,
# https://github.com/SLINGhub/LICAR) so derived factors reproduce the published
# values; the abundance primitive is LICAR's isowrap-based `mCalcIsotope`
# (isopattern is ~0.4% off and would not reproduce the golden). Chain parsing
# uses rgoslin instead of LICAR's fragile positional parser.

# ---- Class choices (verbatim from LICAR R/lipid_choices.R) ------------------

# origin -> (label, value=class code). `label` is the user-facing mrm_pattern;
# labels are globally unique, codes are not (RPLC reuses PC/PCO).
LICAR_CHOICES <- rbind(
  data.frame(
    origin = "Head Group",
    stringsAsFactors = FALSE,
    rbind(
      c("AcylCarnitine (Pos) Pro=85", "AcylCarnitine"),
      c("LPC (Pos) Pro=184.1", "LPC"),
      c("LPC (Pos) Pro=104.1", "LPCql"),
      c("LPC d9 Pro=193.1", "LPC_d9"),
      c("LPC-O (Pos) Pro=104.1", "LPCO"),
      c("LPC-O (Pos, qualifier) Pro=184.1", "LPCOql"),
      c("LPE (Pos) Pre-Pro=141", "LPE"),
      c("LPE (Neg) Pro=196.1", "LPENHG"),
      c("LPI (Pos) Pre-Pro=277", "LPI"),
      c("PC (Pos) Pro=184.1", "PC"),
      c("PC d9 Pro=193.1", "PC_d9"),
      c("PCO (Pos) Pro=184.1", "PCO"),
      c("PCP (Pos) Pro=184.1", "PCP"),
      c("PE (Pos) Pre-Pro=141", "PE"),
      c("PE (Neg) Pro=196.1", "PENHG"),
      c("PG (Pos) Pre-Pro=189", "PG"),
      c("PG (Neg) Pro=153", "PGNHG"),
      c("PI (Pos) Pre-Pro=277", "PI"),
      c("PI (Neg) Pro=241", "PINHG"),
      c("PS (Pos) Pre-Pro=185", "PS"),
      c("PS (Neg) Pre-Pro=87", "PSNHG"),
      c("S1P (Pos) Pro=60.1", "S1P"),
      c("S1Pql (Pos, QL) Pro=113", "S1Pql"),
      c("SM (Pos) Pro=184.1", "SM")
    )
  ),
  data.frame(
    origin = "FA",
    stringsAsFactors = FALSE,
    rbind(
      c("CL (Neg) FA", "CLNFA"),
      c("LPC (Neg, FA) FA", "LPCNFA"),
      c("LPC (Neg, AA) FA", "LPCNFA_2"),
      c("LPC (Neg, -CH3) FA", "LPCNFA_3"),
      c("LPE (Neg) FA", "LPENFA"),
      c("LPI (Neg) FA", "LPINFA"),
      c("LPG (Neg) FA", "LPGNFA"),
      c("FA (Neg) SIM", "FA"),
      c("PC (Neg, FA) FA", "PCNFA"),
      c("PCO (Neg, FA) FA", "PCONFA"),
      c("PCP (Neg, FA) FA", "PCPNFA"),
      c("PC (Neg, AA) FA", "PCNFA_2"),
      c("PC (Neg, -CH3) FA", "PCNFA_3"),
      c("PCO (Neg, AA) FA", "PCONFA_2"),
      c("PCO (Neg, -CH3) FA", "PCONFA_3"),
      c("PCP (Neg, AA) FA", "PCPNFA_2"),
      c("PCP (Neg, -CH3) FA", "PCPNFA_3"),
      c("PE (Neg) FA", "PENFA"),
      c("PEO (Neg) FA", "PEONFA"),
      c("PEP (Neg) FA", "PEPNFA"),
      c("PE-P (Pos) FA", "PEP"),
      c("PG (Neg) FA", "PGNFA"),
      c("PI (Neg) FA", "PINFA"),
      c("PS (Neg) FA", "PSNFA")
    )
  ),
  data.frame(
    origin = "LCB",
    stringsAsFactors = FALSE,
    rbind(
      c("Hex1Sph (Pos) SphB-H2O", "Hex1Sph"),
      c("Cer (Pos) SphB-2H2O", "Cer"),
      c("deoxyCer (Pos) SphB-H2O", "deoxyCer"),
      c("dhCer (Pos) SphB-H2O", "dhCer"),
      c("dhCer (Pos) SphB-2H2O", "dhCer_2"),
      c("GM3 (Pos) SphB-2H2O", "GM3"),
      c("Hex1Cer (Pos) SphB-2H2O", "Hex1Cer"),
      c("Hex2Cer (Pos) SphB-2H2O", "Hex2Cer"),
      c("Hex3Cer (Pos) SphB-2H2O", "Hex3Cer")
    )
  ),
  data.frame(
    origin = "Neutral",
    stringsAsFactors = FALSE,
    rbind(
      c("CE (Pos) FANL", "CE"),
      c("DG (Pos) FANL", "DG"),
      c("TG (Pos) FANL", "TG"),
      c("MG (Pos) Pre-Pro=109", "MG"),
      c("MG (Pos) SIM)", "MGSIM")
    )
  ),
  data.frame(
    origin = "RPLC",
    stringsAsFactors = FALSE,
    rbind(
      c("SM -> PC Pro=184.1", "PC"),
      c("PC-P -> PC-O Pro=184.1", "PCO")
    )
  )
)
colnames(LICAR_CHOICES) <- c("origin", "label", "value")
rownames(LICAR_CHOICES) <- NULL
LICAR_CHOICES$polarity <- ifelse(
  grepl("(Pos", LICAR_CHOICES$label, fixed = TRUE),
  "Pos",
  ifelse(grepl("(Neg", LICAR_CHOICES$label, fixed = TRUE), "Neg", NA)
)

# Offered in the UI but with no working correction path; excluded from the
# template so a user cannot build a table that errors on upload.
LICAR_BROKEN_CLASSES <- c("PC_d9", "MG", "MGSIM")


#' Valid MRM-pattern labels
#'
#' @description The labels a feature's `mrm_pattern` may take, optionally for one
#' product-ion origin. Single source of truth shared by metadata validation and
#' the Excel template dropdown (so they cannot drift).
#'
#' @param origin Optional origin filter (`"Head Group"`, `"FA"`, `"LCB"`,
#'   `"Neutral"`, `"RPLC"`).
#' @return A character vector of labels.
#' @export
licar_pattern_choices <- function(origin = NULL) {
  x <- LICAR_CHOICES
  if (!is.null(origin)) {
    x <- x[x$origin %in% origin, ]
  }
  x$label
}

# Choices offered in the metadata-template dropdown: everything except RPLC
# (whose labels reuse the PC/PCO head-group codes and would mis-derive) and the
# broken classes with no working path. Shared by the `data-raw/` template
# generator and its round-trip test so the two cannot drift.
# @keywords internal
# @noRd
licar_template_choices <- function() {
  x <- LICAR_CHOICES[
    LICAR_CHOICES$origin != "RPLC" &
      !(LICAR_CHOICES$value %in% LICAR_BROKEN_CLASSES),
  ]
  rownames(x) <- NULL
  x
}

#' Validate the `mrm_pattern` feature-metadata column at import
#'
#' 1. every non-NA `mrm_pattern` must be a known LICAR label (error);
#' 2. warns when the feature name's class disagrees with the pattern's class;
#' 3. warns when an FA/LCB pattern (two-fragment) has a sum-only name that cannot
#'    be split into front/back chains.
#' @keywords internal
#' @noRd
validate_mrm_pattern <- function(annot_features) {
  if (!"mrm_pattern" %in% names(annot_features)) {
    return(invisible())
  }
  mp <- annot_features$mrm_pattern
  fid <- annot_features$feature_id
  has <- !is.na(mp) & nzchar(mp)
  if (!any(has)) {
    return(invisible())
  }

  # 1. valid label (error)
  bad <- has & !(mp %in% LICAR_CHOICES$label)
  if (any(bad)) {
    cli_abort(
      "Invalid `mrm_pattern` label(s) in the feature metadata: {glue::glue_collapse(unique(mp[bad]), sep = ', ')}. See {.code licar_pattern_choices()} for valid labels."
    )
  }

  lut <- licar_label_lookup(mp[has])
  # Expected species-name prefix per label (lead class token, with the same
  # overrides LICAR uses for ether/plasmalogen/lyso forms).
  prefix_override <- c(
    "LPC-O" = "LPC",
    "PE-P" = "PE",
    "PCO" = "PC",
    "PCP" = "PC",
    "PEO" = "PE",
    "PEP" = "PE",
    "S1Pql" = "S1P"
  )
  lead <- sub(" .*$", "", mp[has])
  expected <- ifelse(
    lead %in% names(prefix_override),
    prefix_override[lead],
    lead
  )

  parsed <- suppressWarnings(suppressMessages(parse_lipid_feature_names(
    dplyr::tibble(feature_id = fid[has]),
    add_chain_composition = TRUE
  )))
  got_class <- parsed$lipid_class[match(fid[has], parsed$feature_id)]

  # 2. name class vs pattern class (warning)
  mism <- !is.na(got_class) & got_class != expected
  if (any(mism)) {
    mh_warn(
      "{sum(mism)} feature(s) have an `mrm_pattern` whose class disagrees with the feature name (e.g. {.val {fid[has][which(mism)[1]]}} named {.val {got_class[which(mism)[1]]}} but pattern {.val {mp[has][which(mism)[1]]}}). Please verify."
    )
  }

  # 3. FA/LCB pattern needs chain-resolved names (warning)
  two_frag <- lut$code %in% c(names(LICAR_FA_OFFSETS), names(LICAR_LCB_OFFSETS))
  sum_only <- two_frag & !grepl("/", fid[has])
  if (any(sum_only)) {
    mh_warn(
      "{sum(sum_only)} feature(s) have an FA/LCB `mrm_pattern` but a sum-only name (no chain resolution); they cannot be auto-corrected at MRM level: {glue::glue_collapse(unique(fid[has][sum_only]), sep = ', ')}."
    )
  }
  invisible()
}


# Label -> (origin, class code). Labels are globally unique, so keyed on label.
licar_label_lookup <- function(label) {
  idx <- match(label, LICAR_CHOICES$label)
  data.frame(
    label = label,
    origin = LICAR_CHOICES$origin[idx],
    code = LICAR_CHOICES$value[idx],
    stringsAsFactors = FALSE
  )
}


# ---- Per-class fragment offsets (verbatim from LICAR isoCorrect_*) ----------

# Head-group / single-fragment classes: c(C, H, O, N) offsets applied to the
# summed acyl composition. The FA classes that LICAR delegates to isoCorrect_head
# (lyso-FA and free FA) are single-fragment too and share the c(0,-1,2,0) offset.
LICAR_HEAD_OFFSETS <- list(
  AcylCarnitine = c(3, 3, 2, 1),
  LPC = c(3, -2, 3, 0),
  LPCql = c(3, -1, 6, 0),
  LPC_d9 = c(3, -2, 3, 0),
  LPCO = c(3, 1, 5, 0),
  LPCOql = c(3, 0, 2, 0),
  LPE = c(3, -1, 3, 0),
  LPENHG = c(0, 0, 2, 0),
  LPI = c(3, -1, 3, 0),
  PC = c(3, -4, 4, 0),
  PCO = c(3, -2, 3, 0),
  PCP = c(3, -4, 3, 0),
  PE = c(3, -3, 4, 0),
  PENHG = c(0, -2, 3, 0),
  PG = c(3, -3, 4, 0),
  PGNHG = c(3, -2, 5, 0),
  PI = c(3, -3, 4, 0),
  PINHG = c(3, -2, 5, 0),
  PS = c(3, -3, 4, 0),
  PSNHG = c(3, -2, 8, 0),
  S1P = c(1, 1, 5, 0),
  S1Pql = c(3, 1, 1, 1),
  SM = c(0, -1, 2, 1),
  # FA classes that LICAR routes through isoCorrect_head (single FA fragment):
  LPCNFA = c(0, -1, 2, 0),
  LPCNFA_2 = c(0, -1, 2, 0),
  LPCNFA_3 = c(0, -1, 2, 0),
  LPENFA = c(0, -1, 2, 0),
  LPINFA = c(0, -1, 2, 0),
  LPGNFA = c(0, -1, 2, 0),
  FA = c(0, -1, 2, 0),
  # LCB delegating class:
  Hex1Sph = c(0, 2, 1, 1)
)

# Two-fragment FA classes: front (acyl) + back offsets. Back is c(0,-1,2,0)
# except PEP. CLNFA (special front) is handled separately and not listed here.
LICAR_FA_OFFSETS <- list(
  PCNFA = list(front = c(9, 0, 8, 1), back = c(0, -1, 2, 0)),
  PCONFA = list(front = c(9, 2, 7, 1), back = c(0, -1, 2, 0)),
  PCPNFA = list(front = c(9, 0, 7, 1), back = c(0, -1, 2, 0)),
  PCNFA_2 = list(front = c(10, 0, 8, 1), back = c(0, -1, 2, 0)),
  PCNFA_3 = list(front = c(7, 0, 6, 1), back = c(0, -1, 2, 0)),
  PCONFA_2 = list(front = c(10, 2, 7, 1), back = c(0, -1, 2, 0)),
  PCONFA_3 = list(front = c(7, 2, 5, 1), back = c(0, -1, 2, 0)),
  PCPNFA_2 = list(front = c(10, 0, 7, 1), back = c(0, -1, 2, 0)),
  PCPNFA_3 = list(front = c(7, 0, 5, 1), back = c(0, -1, 2, 0)),
  PENFA = list(front = c(5, 0, 6, 1), back = c(0, -1, 2, 0)),
  PEONFA = list(front = c(5, 2, 5, 1), back = c(0, -1, 2, 0)),
  PEPNFA = list(front = c(5, 0, 5, 1), back = c(0, -1, 2, 0)),
  PEP = list(front = c(2, 2, 4, 1), back = c(3, -1, 3, 0)),
  PGNFA = list(front = c(6, -1, 8, 0), back = c(0, -1, 2, 0)),
  PINFA = list(front = c(9, -3, 11, 0), back = c(0, -1, 2, 0)),
  PSNFA = list(front = c(6, -2, 8, 1), back = c(0, -1, 2, 0))
)

# Two-fragment LCB classes: front (sphingoid) + back (FA) offsets. NOTE the
# front/back K assignment is INVERTED relative to FA in the matching (LICAR:
# same-product overlap uses K_back, +2-product overlap uses K_front).
LICAR_LCB_OFFSETS <- list(
  Cer = list(front = c(0, 0, 0, 1), back = c(0, 2, 3, 0)),
  deoxyCer = list(front = c(0, 2, 0, 1), back = c(0, 0, 2, 0)),
  dhCer = list(front = c(0, 2, 1, 1), back = c(0, 0, 2, 0)),
  dhCer_2 = list(front = c(0, 0, 0, 1), back = c(0, 2, 3, 0)),
  GM3 = list(front = c(0, 0, 0, 1), back = c(23, -7, 21, 1)),
  Hex1Cer = list(front = c(0, 0, 0, 1), back = c(6, 0, 8, 0)),
  Hex2Cer = list(front = c(0, 0, 0, 1), back = c(12, -2, 13, 0)),
  Hex3Cer = list(front = c(0, 0, 0, 1), back = c(18, -4, 18, 0))
)


#' Per-chain (front/back) carbon + double-bond annotation via rgoslin
#'
#' Front/back follow LICAR's textual chain order: for glycerophospholipids
#' (rgoslin category GP) front = FA1, back = FA2; for sphingolipids (SP) front =
#' the sphingoid base (LCB), back = the N-acyl FA1.
#' @return `data.frame(feature_id, front_c, front_db, back_c, back_db)`.
#' @keywords internal
#' @noRd
licar_chain_annotation <- function(feature_ids) {
  nm <- get_analyte_id(feature_ids, remove_nl_transitions = FALSE)
  nm <- normalize_isotope_labels(nm)
  nm <- stringr::str_trim(stringr::str_replace(nm, "\\[.*?\\]", ""))
  nm <- stringr::str_replace(nm, "\\s*\\(.*?\\)", "")
  nm <- stringr::str_replace(nm, "\\s*/\\s*", "/")
  nm <- stringr::str_replace(nm, "^(\\S+\\s+\\S+).*", "\\1")

  r <- suppressWarnings(rgoslin::parseLipidNames(nm))
  getcol <- function(col)
    if (col %in% names(r)) r[[col]] else rep(NA_real_, nrow(r))
  cat_ <- if ("Lipid.Maps.Category" %in% names(r)) r$Lipid.Maps.Category else
    rep(NA_character_, nrow(r))
  is_sp <- !is.na(cat_) & cat_ == "SP"

  data.frame(
    feature_id = feature_ids,
    front_c = ifelse(is_sp, getcol("LCB.C"), getcol("FA1.C")),
    front_db = ifelse(is_sp, getcol("LCB.DB"), getcol("FA1.DB")),
    back_c = ifelse(is_sp, getcol("FA1.C"), getcol("FA2.C")),
    back_db = ifelse(is_sp, getcol("FA1.DB"), getcol("FA2.DB")),
    stringsAsFactors = FALSE
  )
}


#' Fragment formula from summed composition + class offsets (LICAR CH_K)
#'
#' `C = C_raw + cC`; `H = C*2 + cH - 2*H_raw`; formula carries the optional N/O.
#' @keywords internal
#' @noRd
licar_fragment_formula <- function(c_raw, h_raw, offset) {
  cc <- c_raw + offset[[1]]
  hh <- cc * 2 + offset[[2]] - 2 * h_raw
  o <- offset[[3]]
  n <- offset[[4]]
  f <- paste0("C", cc, "H", hh)
  if (n > 0) f <- paste0(f, "N", n)
  if (o > 0) f <- paste0(f, "O", o)
  f
}


# ---- Abundance: LICAR mCalcIsotope (isowrap) --------------------------------

#' M+n relative abundance via LICAR's isowrap calculation
#'
#' @description Ports LICAR's `mCalcIsotope`: the centroided M+`n` abundance from
#' `enviPat::isowrap` at a fixed resolution, relative to the base peak. Verified
#' to reproduce LICAR's published factors (unlike `isopattern`, which differs by
#' ~0.4%). Memoized per (formula, n).
#'
#' @param formula Character vector of neutral fragment formulas.
#' @param n Integer isotopologue offset (default 2).
#' @return Numeric vector of M+n factors; `NA` for invalid/missing formulas.
#' @keywords internal
#' @noRd
licar_mCalc <- function(formula, n = 2L) {
  rlang::check_installed("enviPat")
  if (is.null(pkg.env$licar_resolution)) {
    e <- new.env()
    utils::data("resolution_list", package = "enviPat", envir = e)
    pkg.env$licar_resolution <- e$resolution_list[[7]]
    pkg.env$licar_mcalc_cache <- new.env(parent = emptyenv())
  }
  vapply(
    formula,
    function(f) {
      if (is.na(f) || !nzchar(f)) {
        return(NA_real_)
      }
      key <- paste0(f, "|", n)
      cached <- pkg.env$licar_mcalc_cache[[key]]
      if (!is.null(cached)) {
        return(cached)
      }
      checked <- enviPat::check_chemform(isotopes = isotopes, chemforms = f)
      if (checked$warning) {
        mh_warn("Invalid fragment formula skipped: {f}.")
        return(NA_real_)
      }
      centro <- suppressMessages(utils::capture.output(
        cp <- enviPat::isowrap(
          isotopes,
          checked,
          resmass = pkg.env$licar_resolution,
          resolution = FALSE,
          nknots = 4,
          spar = 0.2,
          threshold = 0.1,
          charge = 1,
          emass = 0.00054858,
          algo = 2,
          ppm = FALSE,
          dmz = "get",
          frac = 1 / 4,
          env = "Gaussian",
          detect = "centroid",
          plotit = FALSE
        )
      ))
      m <- as.data.frame(cp[[1]])
      k <- m[[2]][n + 1] / 100
      pkg.env$licar_mcalc_cache[[key]] <- k
      k
    },
    numeric(1),
    USE.NAMES = FALSE
  )
}


# ---- MRM derivation ---------------------------------------------------------

#' MRM (fragment-based, LICAR) interference edges
#'
#' For each feature carrying an `mrm_pattern`, computes the class fragment M+2
#' factor(s) and matches a lighter interferer to a ~2 Da heavier victim within
#' each `mrm_pattern` scope. Head-group classes are single-fragment (matched by
#' precursor only). FA and LCB classes are two-fragment: the front vs back
#' overlap is resolved by the product-m/z delta (0 vs 2), with the K_front/K_back
#' assignment inverted for LCB (LICAR). Classes without a working path
#' (CLNFA / Neutral) are skipped with a note.
#'
#' @param data A [`MRMhubExperiment`][MRMhubExperiment-class].
#' @param mz_tol Unused at MRM level (LICAR fixes the window at 2 +/- 0.2 Da).
#' @return A long interference edge tibble (`source == "auto"`).
#' @keywords internal
#' @noRd
derive_mrm_edges <- function(data, mz_tol = 0.5) {
  af <- data@annot_features
  if (!"mrm_pattern" %in% names(af)) {
    cli_abort(
      "MRM interference derivation requires an `mrm_pattern` column in the feature metadata."
    )
  }
  if (
    !all(
      c("method_precursor_mz", "method_product_mz") %in%
        names(data@dataset_orig)
    )
  ) {
    cli_abort(
      "MRM interference derivation requires precursor and product m/z (`method_precursor_mz`, `method_product_mz`) in the analysis data."
    )
  }
  tmpl <- pkg.env$table_templates$annot_interferences_template

  feats <- af |>
    filter(!is.na(.data$mrm_pattern), nzchar(.data$mrm_pattern)) |>
    select("feature_id", "mrm_pattern")
  if (nrow(feats) == 0) {
    mh_warn("No features carry an `mrm_pattern`; nothing derived at MRM level.")
    return(tmpl)
  }

  feats$code <- licar_label_lookup(feats$mrm_pattern)$code
  feats$kind <- ifelse(
    feats$code %in% names(LICAR_HEAD_OFFSETS),
    "head",
    ifelse(
      feats$code %in% names(LICAR_FA_OFFSETS),
      "fa",
      ifelse(feats$code %in% names(LICAR_LCB_OFFSETS), "lcb", NA_character_)
    )
  )
  if (anyNA(feats$kind)) {
    skipped <- unique(feats$mrm_pattern[is.na(feats$kind)])
    mh_warn(
      "{length(skipped)} mrm_pattern(s) have no supported correction path (CLNFA/Neutral); skipped: {glue::glue_collapse(skipped, sep = ', ')}."
    )
    feats <- feats[!is.na(feats$kind), , drop = FALSE]
  }
  if (nrow(feats) == 0) {
    return(tmpl)
  }

  # Fragment M+2 factor(s) per feature: head -> k; fa/lcb -> k_front, k_back.
  feats$k <- NA_real_
  feats$k_front <- NA_real_
  feats$k_back <- NA_real_

  ih <- which(feats$kind == "head")
  if (length(ih)) {
    parsed <- parse_lipid_feature_names(
      dplyr::tibble(feature_id = feats$feature_id[ih]),
      add_chain_composition = TRUE
    )
    craw <- parsed$total_c[match(feats$feature_id[ih], parsed$feature_id)]
    hraw <- parsed$total_db[match(feats$feature_id[ih], parsed$feature_id)]
    forms <- vapply(
      seq_along(ih),
      function(j) {
        if (is.na(craw[j]) || is.na(hraw[j])) {
          return(NA_character_)
        }
        licar_fragment_formula(
          craw[j],
          hraw[j],
          LICAR_HEAD_OFFSETS[[feats$code[ih[j]]]]
        )
      },
      character(1)
    )
    feats$k[ih] <- licar_mCalc(forms, 2L)
  }

  itwo <- which(feats$kind %in% c("fa", "lcb"))
  if (length(itwo)) {
    ann <- licar_chain_annotation(feats$feature_id[itwo])
    for (j in seq_along(itwo)) {
      i <- itwo[j]
      if (is.na(ann$front_c[j]) || is.na(ann$back_c[j])) {
        next # sum-only / unparseable name -> no front/back split
      }
      off <- if (feats$kind[i] == "fa") {
        LICAR_FA_OFFSETS[[feats$code[i]]]
      } else {
        LICAR_LCB_OFFSETS[[feats$code[i]]]
      }
      feats$k_front[i] <- licar_mCalc(
        licar_fragment_formula(ann$front_c[j], ann$front_db[j], off$front),
        2L
      )
      feats$k_back[i] <- licar_mCalc(
        licar_fragment_formula(ann$back_c[j], ann$back_db[j], off$back),
        2L
      )
    }
    n_miss <- sum(
      feats$kind[itwo] %in% c("fa", "lcb") & is.na(feats$k_front[itwo])
    )
    if (n_miss > 0) {
      mh_warn(
        "{n_miss} FA/LCB feature(s) lack chain-resolved names and were skipped (sum-only names cannot be split into front/back)."
      )
    }
  }

  # Precursor + product m/z per feature.
  d_mz <- data@dataset_orig |>
    select("feature_id", "method_precursor_mz", "method_product_mz") |>
    mutate(
      precursor_mz = suppressWarnings(as.numeric(.data$method_precursor_mz)),
      product_mz = suppressWarnings(as.numeric(.data$method_product_mz))
    ) |>
    group_by(.data$feature_id) |>
    summarise(
      precursor_mz = stats::median(.data$precursor_mz, na.rm = TRUE),
      product_mz = stats::median(.data$product_mz, na.rm = TRUE),
      .groups = "drop"
    )

  joined <- feats |> left_join(d_mz, by = "feature_id")

  # Features that pass the pattern filter but lack the m/z the pairing needs are
  # dropped below; name them so the coverage gap is visible, not silent.
  no_prec <- joined$feature_id[is.na(joined$precursor_mz)]
  if (length(no_prec) > 0) {
    mh_warn(
      "No precursor m/z for {length(no_prec)} feature(s); excluded from MRM derivation: {.val {mh_vec(no_prec)}}."
    )
  }
  no_prod <- joined$feature_id[
    joined$kind %in%
      c("fa", "lcb") &
      !is.na(joined$precursor_mz) &
      is.na(joined$product_mz)
  ]
  if (length(no_prod) > 0) {
    mh_warn(
      "No product m/z for {length(no_prod)} chain-resolved (FA/LCB) feature(s); their fragment-level edges cannot be derived: {.val {mh_vec(no_prod)}}."
    )
  }

  tbl <- joined |> filter(!is.na(.data$precursor_mz))

  edge_cols <- c(
    "feature_id",
    "interference_feature_id",
    "interference_contribution",
    "overlap_type",
    "source"
  )

  # Head-group: single fragment, precursor-only match (all share the product).
  head_tbl <- tbl |> filter(.data$kind == "head", !is.na(.data$k))
  head_edges <- tmpl
  if (nrow(head_tbl) > 0) {
    a <- head_tbl |>
      select(
        interference_feature_id = "feature_id",
        scope = "mrm_pattern",
        prec_a = "precursor_mz",
        contribution = "k"
      )
    b <- head_tbl |>
      select(
        feature_id = "feature_id",
        scope = "mrm_pattern",
        prec_b = "precursor_mz"
      )
    head_edges <- a |>
      inner_join(b, by = "scope", relationship = "many-to-many") |>
      filter(
        .data$interference_feature_id != .data$feature_id,
        abs((.data$prec_b - .data$prec_a) - 2) <= 0.2
      ) |>
      mutate(
        interference_contribution = .data$contribution,
        overlap_type = "m2_head",
        source = "auto"
      ) |>
      select(all_of(edge_cols)) |>
      distinct()
  }

  # FA/LCB: two-fragment, front vs back resolved by product delta (0 vs 2).
  two_tbl <- tbl |>
    filter(.data$kind %in% c("fa", "lcb"), !is.na(.data$k_front))
  two_edges <- tmpl
  if (nrow(two_tbl) > 0) {
    a <- two_tbl |>
      select(
        interference_feature_id = "feature_id",
        scope = "mrm_pattern",
        "kind",
        prec_a = "precursor_mz",
        prod_a = "product_mz",
        kf = "k_front",
        kb = "k_back"
      )
    b <- two_tbl |>
      select(
        feature_id = "feature_id",
        scope = "mrm_pattern",
        prec_b = "precursor_mz",
        prod_b = "product_mz"
      )
    j <- a |>
      inner_join(b, by = "scope", relationship = "many-to-many") |>
      filter(
        .data$interference_feature_id != .data$feature_id,
        abs((.data$prec_b - .data$prec_a) - 2) <= 0.2
      ) |>
      mutate(dpro = .data$prod_b - .data$prod_a)
    # front branch (product delta ~0) and back branch (~2). LCB inverts which
    # fragment factor applies (front-product overlap uses K_back, and vice versa).
    front <- j |>
      filter(abs(.data$dpro) <= 0.2) |>
      mutate(
        interference_contribution = if_else(
          .data$kind == "lcb",
          .data$kb,
          .data$kf
        ),
        overlap_type = if_else(.data$kind == "lcb", "m2_back", "m2_front"),
        source = "auto"
      )
    back <- j |>
      filter(abs(.data$dpro - 2) <= 0.2) |>
      mutate(
        interference_contribution = if_else(
          .data$kind == "lcb",
          .data$kf,
          .data$kb
        ),
        overlap_type = if_else(.data$kind == "lcb", "m2_front", "m2_back"),
        source = "auto"
      )
    two_edges <- bind_rows(front, back) |>
      select(all_of(edge_cols)) |>
      distinct()
  }

  bind_rows(head_edges, two_edges) |> distinct()
}
