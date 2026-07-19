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
#' Replaces the standard tibble header (`# A tibble: N x M`) with a pluralized
#' severity-count summary line and a divider, hides the column-type chip row
#' (`<chr> <int> ...`), and adds an italic legend explaining the E / W / W* / N
#' severity codes used by `assert_metadata()`. The summary and divider replace
#' the separate `cli_alert` banner that previously printed on a different stream,
#' so the whole report (summary, table, legend) now renders as one block.
#' Implemented with `cli` only (no pillar dependency).
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
  # Strip pillar's ANSI styling so the header/chip-row filters match (a coloured
  # `# A tibble:` line is ANSI-prefixed) and the report stays plain text in a
  # notebook render, where the E / W / N letters carry the severity.
  body <- cli::ansi_strip(body)
  body <- body[!grepl("^# A tibble:", body)]
  body <- body[!grepl("^\\s*<[a-z0-9_]+>(?:\\s+<[a-z0-9_]+>)*\\s*$", body)]

  # Pluralized severity-count headline, derived from the Type column (W* is a
  # suppressed warning, still a warning). The letters remain the primary,
  # colour-independent severity signal.
  if ("Type" %in% names(x)) {
    nD <- sum(x$Type == "D")
    nE <- sum(x$Type == "E")
    nW <- sum(x$Type %in% c("W", "W*"))
    nN <- sum(x$Type == "N")
    summary_line <- if (nD > 0) {
      cli::format_inline(
        "Found {cli::no(nD)} defect{?s}, {cli::no(nE)} error{?s}, {cli::no(nW)} warning{?s}, and {cli::no(nN)} note{?s} in the metadata."
      )
    } else {
      cli::format_inline(
        "Found {cli::no(nE)} error{?s}, {cli::no(nW)} warning{?s}, and {cli::no(nN)} note{?s} in the metadata."
      )
    }
    cat(cli::ansi_strip(summary_line), "\n", sep = "")
  }

  cat(divider, "\n", sep = "")
  cat(body, sep = "\n")
  cat("\n", .assertr_legend(divider), "\n", sep = "")

  invisible(x)
}
