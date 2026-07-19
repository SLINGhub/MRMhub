# Package-internal cli helpers. The full-line red/yellow/green look of mrmhub's
# console feedback is defined here, once, instead of being re-applied with a
# `cli::col_*()` wrap at every call site. Each `mh_*()` forwards to the matching
# `cli::cli_alert_*()` and colours the whole line, so alerts keep today's
# saturated appearance while the colour stays local (no global cli theme, no
# `.onLoad` state). Interpolation, pluralization (`{?s}`) and inline classes work
# exactly as in a bare `cli_alert_*()` call because `.envir` is forwarded to the
# caller's frame.

#' Coloured cli alert wrappers
#'
#' Thin wrappers over [cli::cli_alert_success()] / `_info()` / `_warning()` /
#' `_danger()` that wrap the whole message in the matching `cli::col_*()` so the
#' entire line is coloured (success = green, warning = yellow, danger = red).
#' `mh_info()` is left uncoloured (the neutral cli default). Call these instead
#' of wrapping messages in `col_*()` inline.
#'
#' @param text Message text, with cli inline markup / interpolation.
#' @param .envir Environment for glue-style interpolation; defaults to the
#'   calling frame so `{var}` resolves against the caller's variables.
#' @return Called for the side effect of printing an alert; returns `NULL`
#'   invisibly.
#' @keywords internal
#' @noRd
mh_success <- function(text, .envir = parent.frame()) {
  cli::cli_alert_success(cli::col_green(text), .envir = .envir)
}

#' @rdname mh_success
#' @keywords internal
#' @noRd
mh_info <- function(text, .envir = parent.frame()) {
  cli::cli_alert_info(text, .envir = .envir)
}

#' @rdname mh_success
#' @keywords internal
#' @noRd
mh_warn <- function(text, .envir = parent.frame()) {
  cli::cli_alert_warning(cli::col_yellow(text), .envir = .envir)
}

#' @rdname mh_success
#' @keywords internal
#' @noRd
mh_danger <- function(text, .envir = parent.frame()) {
  cli::cli_alert_danger(cli::col_red(text), .envir = .envir)
}

#' Truncate a reported vector at a settable maximum
#'
#' Wraps a vector in [cli::cli_vec()] with a `vec-trunc` style so cli collapses
#' it to at most `max_items` values (both-ends style, `a, b, ..., y, z`) inside
#' a message. Defines the report-list truncation limit in one place; the global
#' knob is `options(mrmhub.max_report_items = ...)`.
#'
#' @param x A vector to report inside a cli message (e.g. `{.val {mh_vec(ids)}}`).
#' @param max_items Maximum number of elements to show before truncating.
#'   Defaults to `getOption("mrmhub.max_report_items", 10L)`.
#' @return A `cli_vec` carrying the truncation style.
#' @keywords internal
#' @noRd
mh_vec <- function(x, max_items = getOption("mrmhub.max_report_items", 10L)) {
  cli::cli_vec(x, style = list("vec-trunc" = max_items))
}
