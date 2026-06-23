# Classes and associated print methods for additional structures used by the
# package. Currently: `assertr_tibble`, the tibble subclass used to present
# metadata validation reports (errors / warnings / notes) returned by
# `assert_metadata()` and related functions.

#' Wrap a data.frame as an `assertr_tibble`
#'
#' Adds the `assertr_tibble` class so that `print()` uses the styled output
#' below (banner header + italic legend footer) without pulling pillar in as
#' a direct dependency.
#'
#' @keywords internal
#' @noRd
as_assertr_tibble <- function(x, ...) {
  if (!inherits(x, "data.frame")) {
    stop("x must be a data.frame")
  }
  x <- tibble::as_tibble(x)
  class(x) <- c("assertr_tibble", class(x))
  x
}

# Banner divider used in the styled validation-report print. Width adapts to
# the terminal up to a soft cap of 90 columns.
.assertr_divider <- function() {
  strrep("-", min(90, getOption("width", 80L)))
}

# Footer legend explaining the defect-severity codes used in the report.
.assertr_legend <- function(divider = .assertr_divider()) {
  paste0(
    divider,
    "\nE = Error, W = Warning, W* = Suppressed Warning, N = Note\n",
    divider
  )
}

#' Print method for validation-report tibbles
#'
#' Replaces the standard tibble header (`# A tibble: N x M`) with a black
#' divider line, hides the column-type chip row (`<chr> <int> ...`), and adds
#' an italic legend explaining the E / W / W* / N severity codes used by
#' `assert_metadata()`. Implemented with `cli` only (no pillar dependency).
#'
#' @param x An `assertr_tibble`.
#' @param n,width Forwarded to the underlying tibble print method.
#' @param ... Forwarded.
#' @keywords internal
#' @export
print.assertr_tibble <- function(x, n = NULL, width = NULL, ...) {
  divider <- .assertr_divider()

  # Strip our class so the parent tibble print formats the body normally, then
  # capture its output to drop the lines we don't want (the "# A tibble: ..."
  # summary line, and the column-type chip row like "<chr> <int>").
  body <- utils::capture.output(
    print(tibble::as_tibble(unclass(x)), n = n, width = width)
  )
  body <- body[!grepl("^# A tibble:", body)]
  body <- body[!grepl("^\\s*<[a-z0-9_]+>(?:\\s+<[a-z0-9_]+>)*\\s*$", body)]

  cat(cli::col_black(divider), "\n", sep = "")
  cat(body, sep = "\n")
  cat("\n", cli::style_italic(.assertr_legend(divider)), "\n", sep = "")

  invisible(x)
}
