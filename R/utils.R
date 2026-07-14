utils::globalVariables("where")
utils::globalVariables(".")
utils::globalVariables(".data")
utils::globalVariables("lipidomics_dataset")
utils::globalVariables("weight")

#' Coerce a column to numeric/integer, warning on silent parse failures
#'
#' Wraps [as.numeric()] / [as.integer()] so that a non-blank source value that
#' fails to parse (and would otherwise become `NA` silently) triggers a warning
#' naming the column, the count, and a few offending values. Already-numeric
#' input is coerced directly, without a character round-trip that could perturb
#' precision. Intended for user-facing import coercions.
#'
#' @param x A vector to coerce (character, numeric, or factor).
#' @param column Column name used in the warning message.
#' @param integer If `TRUE`, coerce with [as.integer()] instead of [as.numeric()].
#' @param decimal_comma If `TRUE`, replace a decimal comma with a point before
#'   parsing (for locale-formatted numbers).
#' @return A numeric (or integer) vector the same length as `x`.
#' @keywords internal
#' @noRd
coerce_checked <- function(
  x,
  column = NULL,
  integer = FALSE,
  decimal_comma = FALSE
) {
  target <- if (integer) as.integer else as.numeric
  if (is.factor(x)) {
    x <- as.character(x)
  }
  # Already-numeric input can't hold a mistyped cell; coerce directly and skip
  # the character round-trip (which could perturb double precision).
  if (!is.character(x)) {
    return(suppressWarnings(target(x)))
  }
  chr <- stringr::str_squish(x)
  if (decimal_comma) {
    chr <- stringr::str_replace(chr, ",", ".")
  }
  chr[!is.na(chr) & chr == ""] <- NA_character_
  out <- suppressWarnings(target(chr))
  failed <- !is.na(chr) & is.na(out)
  if (any(failed)) {
    bad <- unique(chr[failed])
    cli::cli_warn(c(
      "!" = "{sum(failed)} value{?s} in column {.field {column}} could not be parsed as {if (integer) 'a whole number' else 'a number'} and {cli::qty(sum(failed))}{?was/were} set to {.val {NA}}.",
      "i" = "Unparseable value{?s}: {.val {utils::head(bad, 5)}}"
    ))
  }
  out
}

#' Coerce a column to logical, broadening tokens and warning on parse failures
#'
#' Unlike [as.logical()] (which recognizes only `TRUE`/`FALSE`/`T`/`F` and turns
#' everything else into `NA` silently), this accepts the boolean encodings people
#' commonly type in spreadsheets — `yes`/`no`, `y`/`n`, `1`/`0`, `true`/`false`
#' (case-insensitive) — and warns, naming the column and the offending values,
#' when a non-blank cell is still unrecognized. Intended for user-facing import
#' coercions of boolean flag columns.
#'
#' @param x A vector to coerce (character, logical, numeric, or factor).
#' @param column Column name used in the warning message.
#' @return A logical vector the same length as `x`.
#' @keywords internal
#' @noRd
coerce_logical_checked <- function(x, column = NULL) {
  if (is.logical(x)) {
    return(x)
  }
  if (is.factor(x)) {
    x <- as.character(x)
  }
  orig <- stringr::str_squish(as.character(x))
  orig[!is.na(orig) & orig == ""] <- NA_character_
  key <- tolower(orig)
  out <- rep(NA, length(key))
  out[key %in% c("true", "t", "yes", "y", "1")] <- TRUE
  out[key %in% c("false", "f", "no", "n", "0")] <- FALSE
  failed <- !is.na(key) & is.na(out)
  if (any(failed)) {
    bad <- unique(orig[failed])
    cli::cli_warn(c(
      "!" = "{sum(failed)} value{?s} in column {.field {column}} could not be interpreted as TRUE/FALSE and {cli::qty(sum(failed))}{?was/were} set to {.val {NA}}.",
      "i" = "Unrecognized value{?s}: {.val {utils::head(bad, 5)}}",
      "i" = "Recognized (case-insensitive): {.val {c('TRUE', 'FALSE', 'yes', 'no', 'y', 'n', '1', '0')}}."
    ))
  }
  out
}
