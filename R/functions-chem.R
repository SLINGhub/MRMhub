#' Calculate average molecular weight from chemical formulas
#'
#' Calculates the average molecular weight of one or more chemical formulas, based on the natural isotopic distribution of elements.
#' The calculation uses the \pkg{enviPat} package to retrieve isotopic masses and abundances, and computes the weighted mean of the isotopic distribution.
#'
#' This function calculates the *average molecular weight* (not monoisotopic mass), which reflects the average of the isotopic distribution found in nature.
#'
#' Isotopes can be specified explicitly in the formula. Atomic mass numbers for isotopes must be enclosed in square brackets (e.g., `[13]C` for carbon-13).
#' Deuterium must be written as `D` instead of `[2]H`.
#'
#' @param formula A character vector of one or more chemical formulas to process.
#'
#' @return A numeric vector of average molecular weights, one for each formula.
#'
#' @details
#' The function uses the \pkg{enviPat} package to validate and parse chemical formulas, calculate isotopic patterns,
#' and determine the average molecular weight based on weighted means of isotopic abundances.
#'
#' @references
#' Loos, M., Gerber, C., Corona, F., Hollender, J., & Singer, H. (2015).
#' Accelerated Isotope Fine Structure Calculation Using Pruned Transition Trees.
#' *Analytical Chemistry*, 87(11), 5738–5744. \doi{10.1021/acs.analchem.5b00941}
#'
#' @examples
#' calc_average_molweight(c("C6H12O6", "[13]C6H12O6", "C8H10N4O2", "D2O"))
#'
#' @export

calc_average_molweight <- function(formula) {
  # Use enviPat to calculate the molecular weight

  if (length(formula) == 0)
    cli_abort(
      "No chemical formula provided. Please provide on or more valid chemical formula."
    )

  rlang::check_installed("enviPat")
  # isotopes was obtained via data(isotopes, package = "enviPat") and saved as internal dataset
  formula_checked <- enviPat::check_chemform(
    isotopes = isotopes,
    chemforms = formula
  )

  if (any(formula_checked$warning))
    cli_abort(
      "Following invalid chemical formula defined: {glue::glue_collapse(formula_checked[formula_checked$warning, ]$new_formula, sep = ', ')}. Please verify feature metadata."
    )

  # Calculate the molecular weight
  pattern <- enviPat::isopattern(
    isotopes = isotopes,
    chemforms = formula,
    threshold = 0.0001,
    plotit = FALSE,
    verbose = FALSE,
    charge = FALSE,
    emass = 0.00054858,
    algo = 1
  )

  # Calculate average mass by mean of the isotopic distribution
  weighted_means <- purrr::map_dbl(pattern, function(mat) {
    df <- as.data.frame(mat)
    stats::weighted.mean(df[[1]], df[[2]])
  })

  unname(weighted_means)
}


#' Relative abundance of the M+n isotopologue
#'
#' @description Computes the abundance of the nominal M+`n` isotopologue relative
#' to the monoisotopic (M0) peak for one or more chemical formulas, using the
#' \pkg{enviPat} `isopattern` calculation. This is the isotopic-interference
#' correction factor: an interfering species contributes `mN_rel_abundance()` of
#' its own signal into the transition/precursor of the species `n` mass units
#' heavier. Being a ratio, it is independent of the pattern normalization.
#'
#' @param formula Character vector of chemical formulas (neutral).
#' @param n Integer isotopologue offset (default 2, the dominant M+2 overlap).
#' @return Numeric vector of M+n / M0 relative abundances; `NA` for invalid or
#'   missing formulas (a warning names the invalid ones).
#' @keywords internal
#' @noRd
mN_rel_abundance <- function(formula, n = 2L) {
  rlang::check_installed("enviPat")
  out <- rep(NA_real_, length(formula))
  ok <- !is.na(formula) & nzchar(formula)
  if (!any(ok)) {
    return(out)
  }

  checked <- enviPat::check_chemform(isotopes = isotopes, chemforms = formula[ok])
  # Guard the primitive against invalid formulas (which would abort isopattern
  # obscurely): warn and leave them NA rather than failing the whole derivation.
  if (any(checked$warning)) {
    mh_warn(
      "Invalid chemical formula(s) skipped in the isotope calculation: {glue::glue_collapse(formula[ok][checked$warning], sep = ', ')}."
    )
  }
  valid <- !checked$warning
  idx <- which(ok)[valid]
  if (!length(idx)) {
    return(out)
  }

  pattern <- enviPat::isopattern(
    isotopes = isotopes,
    chemforms = checked$new_formula[valid],
    threshold = 0.001,
    plotit = FALSE,
    verbose = FALSE,
    charge = FALSE,
    algo = 1
  )

  out[idx] <- vapply(
    pattern,
    function(mat) {
      m <- as.data.frame(mat)
      mass <- m[[1]]
      ab <- m[[2]]
      m0 <- min(mass)
      # Sum the peaks in the nominal +n mass bin, relative to the M0 peak.
      sum(ab[abs(mass - (m0 + n)) < 0.5]) / ab[which.min(mass)]
    },
    numeric(1)
  )
  out
}
