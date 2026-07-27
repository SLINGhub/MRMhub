# Package-internal cli helpers. The full-line green/yellow/red look of mrmhub's
# console feedback is defined here, once, instead of being re-applied with a
# `cli::col_*()` wrap at every call site. Each `mh_*()` forwards to the matching
# `cli::cli_alert_*()` with the message body coloured as one uniform colour, so
# alerts keep today's saturated appearance while the colour stays local (no
# global cli theme, no `.onLoad` state).
#
# Colouring is done by `mh_paint()`: render the cli markup to text first, strip
# cli's own inline colours, then apply a single `col_*()`. A naive
# `col_green(text)` wrap around the *raw markup* breaks up, because cli's inline
# classes (`.field`, `.file`, `.val`, `.fn`, ...) each paint their own colour and
# close with a reset-to-default; that reset lands *inside* the outer colour and
# turns the remainder of the line black (and leaves e.g. file paths blue).
# Rendering-then-stripping-then-colouring yields a line that is one colour end to
# end, while the literal transforms of those classes (backticks, quotes) survive.
# Interpolation and pluralization (`{?s}`) still work because `.envir` is
# forwarded to `format_inline()`.

#' Render cli markup and paint the whole message one colour
#'
#' @param text Message text, with cli inline markup / interpolation.
#' @param col_fn A `cli::col_*()` function applied to the rendered, colour-
#'   stripped text.
#' @param .envir Environment for glue-style interpolation.
#' @return A single-colour ANSI string ready to hand to `cli_alert_*()`.
#' @keywords internal
#' @noRd
mh_paint <- function(text, col_fn, .envir) {
  col_fn(cli::ansi_strip(cli::format_inline(text, .envir = .envir)))
}

#' Coloured cli alert wrappers
#'
#' Thin wrappers over [cli::cli_alert_success()] / `_info()` / `_warning()` /
#' `_danger()` that colour the whole message body one colour via `mh_paint()`
#' (success = green, info = green, warning = yellow, danger = red). Call these
#' instead of wrapping messages in `col_*()` inline.
#'
#' @param text Message text, with cli inline markup / interpolation.
#' @param .envir Environment for glue-style interpolation; defaults to the
#'   calling frame so `{var}` resolves against the caller's variables.
#' @return Called for the side effect of printing an alert; returns `NULL`
#'   invisibly.
#' @keywords internal
#' @noRd
mh_success <- function(text, .envir = parent.frame()) {
  cli::cli_alert_success(mh_paint(text, cli::col_green, .envir))
}

#' @rdname mh_success
#' @keywords internal
#' @noRd
mh_info <- function(text, .envir = parent.frame()) {
  cli::cli_alert_info(mh_paint(text, cli::col_green, .envir))
}

#' @rdname mh_success
#' @keywords internal
#' @noRd
mh_warn <- function(text, .envir = parent.frame()) {
  cli::cli_alert_warning(mh_paint(text, cli::col_yellow, .envir))
}

#' @rdname mh_success
#' @keywords internal
#' @noRd
mh_danger <- function(text, .envir = parent.frame()) {
  cli::cli_alert_danger(mh_paint(text, cli::col_red, .envir))
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
          # knitr prepends the chunk `comment` (e.g. "#> ") to each line and the
          # message carries a trailing newline; strip both so the styled console
          # block is not a commented block and has no dangling blank line.
          if (length(options$comment) && nzchar(options$comment)) {
            x <- gsub(
              paste0("(?m)^\\Q", options$comment, "\\E ?"),
              "",
              x,
              perl = TRUE
            )
          }
          x <- sub("[\r\n]+$", "", x)
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
