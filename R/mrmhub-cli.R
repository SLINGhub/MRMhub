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

#' Enable coloured mrmhub console output in notebooks
#'
#' mrmhub's console feedback is coloured with cli. In an interactive session this
#' works out of the box, but in a non-interactive render (Quarto or R Markdown)
#' cli suppresses colour by default, and its alerts travel on the *message*
#' stream, which knitr does not colour-convert. Call this once in a setup chunk
#' to (1) advertise colour support to cli via `cli.num_colors` / `crayon.enabled`
#' and (2), when rendering to HTML, register a knitr message hook that converts
#' the emitted ANSI sequences to coloured HTML using the \pkg{fansi} package. For
#' PDF and Word the same hook strips the ANSI so messages stay clean plain text.
#'
#' @param num_colors Number of colours to advertise to cli. Defaults to `256`.
#' @return Invisibly, the previous values of the options it changed (as returned
#'   by [options()]), so the caller can restore them.
#' @examples
#' \dontrun{
#' # In a Quarto / R Markdown setup chunk:
#' mrmhub_enable_cli_color()
#' }
#' @export
mrmhub_enable_cli_color <- function(num_colors = 256L) {
  old <- options(
    cli.num_colors = num_colors,
    crayon.enabled = TRUE
  )

  # Inside a live render, colour cli's message-stream alerts: HTML gets fansi
  # SGR->HTML, other formats get the ANSI stripped and the default rendering.
  if (
    isTRUE(getOption("knitr.in.progress")) &&
      requireNamespace("knitr", quietly = TRUE) &&
      requireNamespace("fansi", quietly = TRUE)
  ) {
    default_message <- knitr::knit_hooks$get("message")
    knitr::knit_hooks$set(
      message = function(x, options) {
        if (knitr::is_html_output()) {
          # Wrap the converted output in Quarto's own stderr cell-output div, so
          # it survives every HTML format — plain HTML *and* revealjs, which
          # drops raw HTML that is not inside a recognised cell-output block.
          paste0(
            '<div class="cell-output cell-output-stderr"><pre><code>',
            fansi::sgr_to_html(x, warn = FALSE),
            "</code></pre></div>"
          )
        } else {
          default_message(cli::ansi_strip(x), options)
        }
      }
    )
  }

  invisible(old)
}
