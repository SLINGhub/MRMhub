utils::globalVariables("where")
utils::globalVariables(".")
utils::globalVariables(".data")
utils::globalVariables("lipidomics_dataset")
utils::globalVariables("weight")

#' `values_fn` guard for wide pivots
#'
#' Passed as `values_fn` to [tidyr::pivot_wider()] so each output cell holds
#' exactly one value. More than one means duplicate rows (same key columns) in
#' the data, which `pivot_wider()` would otherwise silently collapse into a
#' list-column; abort loudly instead. A single value (or none) is returned
#' unchanged, so this is behaviour-preserving for well-formed data.
#'
#' @param x The values destined for one wide cell.
#' @return `x` unchanged when it holds at most one value.
#' @keywords internal
#' @noRd
check_single_pivot_value <- function(x) {
  if (length(x) > 1L) {
    cli::cli_abort(c(
      "Cannot pivot to a wide table: more than one value per cell.",
      "i" = "This indicates duplicate rows (same key columns) in the data."
    ))
  }
  x
}

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

#' Abort on a duplicated join key before it can fan out a join
#'
#' Defense-in-depth guard placed immediately before a join whose key must be
#' unique on one side. A duplicated key silently turns the join many-to-many,
#' multiplying rows and corrupting every downstream aggregate, so abort with a
#' clear, actionable message instead of letting a cryptic dplyr `many-to-one`
#' error surface deep in the pipeline. Cheap: a single [anyDuplicated()] on a
#' metadata column. Import-time validation already asserts these keys; this
#' catches hand-built or directly-mutated objects that bypass import.
#'
#' @param ids A vector of identifier values. For a composite key, paste the
#'   columns into one vector before calling.
#' @param field Display name of the key, used in the message (e.g. `"feature_id"`).
#' @param table Display name (prose) of the table the key belongs to.
#' @return `ids`, invisibly, when unique.
#' @keywords internal
#' @noRd
assert_unique_ids <- function(ids, field, table) {
  if (anyDuplicated(ids)) {
    dups <- unique(ids[duplicated(ids)])
    cli::cli_abort(c(
      "Duplicated {field} in {table}.",
      "x" = "{length(dups)} value{?s} occur{?s/} more than once; a join on this key would fan out and silently corrupt results.",
      "i" = "Duplicated value{?s}: {.val {utils::head(dups, 5)}}"
    ))
  }
  invisible(ids)
}
