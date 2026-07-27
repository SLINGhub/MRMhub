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
  # is.na() is TRUE for NaN, so a cell R parsed to NaN (e.g. INTEGRATOR's "NaN"
  # for an unmeasurable FWHM) would be misread as a parse failure — exclude it.
  failed <- !is.na(chr) & is.na(out) & !is.nan(out)
  if (any(failed)) {
    bad <- unique(chr[failed])
    cli::cli_warn(c(
      "!" = "{sum(failed)} value{?s} in column {.field {column}} could not be parsed as {if (integer) 'a whole number' else 'a number'} and {cli::qty(sum(failed))}{?was/were} set to {.val {NA}}.",
      "i" = "Unparseable value{?s}: {.val {mh_vec(bad)}}"
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
      "i" = "Unrecognized value{?s}: {.val {mh_vec(bad)}}",
      "i" = "Recognized (case-insensitive): {.val {c('TRUE', 'FALSE', 'yes', 'no', 'y', 'n', '1', '0')}}."
    ))
  }
  out
}

#' Whitespace-normalize identifier columns of a table
#'
#' Applies [stringr::str_squish()] (trim leading/trailing, collapse internal
#' runs) to the named identifier columns, coercing to character first so
#' factor/numeric IDs are handled uniformly. Columns absent from `tbl` are
#' silently skipped, so one call can cover the full ID set of any importer's
#' table. A whitespace-only difference between an ID in the data and the same ID
#' in the metadata otherwise causes a silent join mismatch; normalizing both
#' sides identically is what makes `"QC  01"` match `"QC 01"` instead of failing
#' to join. Use as a backstop -- it does not substitute for squishing the parts
#' of a *composite* key before they are pasted together (a space adjacent to an
#' internal separator cannot be removed after the fact).
#'
#' @param tbl A tibble/data.frame.
#' @param cols Character vector of identifier column names to normalize.
#' @return `tbl` with the present `cols` whitespace-normalized.
#' @keywords internal
#' @noRd
squish_ids <- function(tbl, cols) {
  cols <- intersect(cols, names(tbl))
  if (length(cols) == 0) {
    return(tbl)
  }
  dplyr::mutate(
    tbl,
    dplyr::across(
      dplyr::all_of(cols),
      \(x) stringr::str_squish(as.character(x))
    )
  )
}

#' Normalize an analysis identifier by stripping a raw-data file extension
#'
#' Removes a trailing raw-data extension (`.mzML`, `.d`, `.raw`, `.wiff`,
#' `.wiff2`, `.lcd`, `.chrom`, case-insensitive) from an identifier so that IDs derived
#' from a data-file name match those typed into metadata. The regex is
#' **anchored** (`$`): only a genuine trailing extension is removed, never a
#' substring such as the `.d` inside `Study.data_01.d`, which an unanchored
#' first-match replace would corrupt into `Studyata_01.d`. The value is squished
#' first, so a trailing space (`"Study_01.d "`) does not defeat the anchor and
#' the strip/squish order is irrelevant.
#'
#' The data and metadata import paths must both route through this single helper:
#' only identical cleaning on both sides makes the `analysis_id` inner join match
#' instead of silently dropping rows (the metadata side historically used an
#' unanchored regex missing `.wiff2`).
#'
#' @param x A character (or coercible) vector of identifiers.
#' @return A character vector, whitespace-normalized with any trailing raw-data
#'   extension removed.
#' @keywords internal
#' @noRd
strip_raw_extension <- function(x) {
  x <- stringr::str_squish(as.character(x))
  stringr::str_remove(
    x,
    stringr::regex(
      "\\.mzML$|\\.d$|\\.raw$|\\.wiff$|\\.wiff2$|\\.lcd$|\\.chrom$",
      ignore_case = TRUE
    )
  )
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
      "i" = "Duplicated value{?s}: {.val {mh_vec(dups)}}"
    ))
  }
  invisible(ids)
}

#' Abort when a per-key attribute lookup carries conflicting values
#'
#' Sibling of `assert_unique_ids()` for the importers, which build small
#' per-analysis / per-feature attribute lookups with [dplyr::distinct()] and join
#' them back onto every data row. A key whose attributes disagree between rows of
#' the raw file survives `distinct()` as more than one row, so the join then
#' duplicates every measurement of that key. There is no safe guess about which
#' spelling was intended, so abort naming the column that actually disagrees --
#' otherwise the fan-out only surfaces further downstream as a "duplicated
#' reportings" error blaming the user's file for duplicates it does not contain.
#'
#' @param d_lookup Per-key attribute table, expected to hold one row per `key`.
#' @param key Name of the key column.
#' @param table Display name (prose) of the source the lookup was built from.
#' @return `d_lookup`, invisibly, when consistent.
#' @keywords internal
#' @noRd
assert_consistent_attributes <- function(d_lookup, key, table) {
  dup_keys <- unique(d_lookup[[key]][duplicated(d_lookup[[key]])])
  if (length(dup_keys) == 0) {
    return(invisible(d_lookup))
  }
  d_conflict <- d_lookup[d_lookup[[key]] %in% dup_keys, , drop = FALSE]
  attr_cols <- setdiff(names(d_lookup), key)
  conflicting <- attr_cols[vapply(
    attr_cols,
    function(col) {
      any(tapply(d_conflict[[col]], d_conflict[[key]], dplyr::n_distinct) > 1)
    },
    logical(1)
  )]
  n <- length(dup_keys)
  cli::cli_abort(c(
    "Inconsistent {.field {key}} metadata in {table}.",
    "x" = "{n} {.field {key}} value{cli::qty(n)}{?s} {cli::qty(n)}{?carries/carry} more than one {.field {conflicting}}: {.val {mh_vec(dup_keys)}}",
    "i" = "Each {.field {key}} must carry the same {.field {conflicting}} in every row, otherwise every measurement of it is duplicated."
  ))
}

#' Drop leftover stray rows and headerless columns from spreadsheet metadata
#'
#' Spreadsheet metadata often carries stray content: a value or formula remnant
#' left in a cell with no identifier. Two shapes are trimmed here, both warned so
#' the removal stays attributable:
#'
#' * **Headerless columns** -- a column whose name is missing/blank (a leftover
#'   column with no header). It cannot be a real field, so drop it. (Named-but-
#'   unknown columns are the user's own extras; those are left for the trailing
#'   `select()` in each cleaner to handle.)
#' * **Keyless rows** -- a row where *all* key columns are `NA`. It has no usable
#'   key, cannot join to anything, and left in place inflates row counts and can
#'   trip uniqueness checks. (A row with a *partial* key is a genuine data error,
#'   left for the assertion layer.) The upstream all-`NA` row filter misses these
#'   because a stray value elsewhere keeps the row non-empty.
#'
#' @param tbl A tibble/data.frame.
#' @param key_cols Character vector of key column names. Columns absent from
#'   `tbl` are ignored.
#' @param table Display name of the table, used in the warning messages.
#' @return `tbl` with stray columns and rows removed.
#' @keywords internal
#' @noRd
trim_stray_cells <- function(tbl, key_cols, table) {
  # Headerless (blank / NA name) columns -> genuine leftover columns.
  nms <- names(tbl)
  blank_col <- is.na(nms) | trimws(nms) == ""
  if (any(blank_col)) {
    n_col <- sum(blank_col)
    cli::cli_warn(
      c(
        "!" = "{n_col} unnamed column{?s} in the {table} metadata {?was/were} dropped (no header -- likely a stray spreadsheet column)."
      )
    )
    tbl <- tbl[, !blank_col, drop = FALSE]
  }

  keys <- intersect(key_cols, names(tbl))
  if (length(keys) == 0 || nrow(tbl) == 0) {
    return(tbl)
  }
  stray <- rowSums(!is.na(tbl[keys])) == 0
  if (any(stray)) {
    n_stray <- sum(stray)
    cli::cli_warn(c(
      "!" = "{n_stray} stray row{?s} in the {table} metadata {?was/were} dropped ({cli::qty(length(keys))}no value in key column{?s} {.field {keys}}).",
      "i" = "This usually indicates a leftover cell in the source spreadsheet."
    ))
    tbl <- tbl[!stray, , drop = FALSE]
  }
  tbl
}
