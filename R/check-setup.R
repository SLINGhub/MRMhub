#' Check MRMhub setup
#'
#' Validates that the user's R environment is correctly configured to use
#' mrmhub. Checks R version, key dependencies, and optional packages.
#'
#' @param verbose Logical. If `TRUE` (default), prints detailed results.
#'   If `FALSE`, returns results invisibly.
#'
#' @return A list (invisibly) with elements `r_version`, `required`, and
#'   `optional`, each containing pass/fail status.
#'
#' @examples
#' check_setup()
#'
#' @export
check_setup <- function(verbose = TRUE) {
  results <- list(
    r_version = list(pass = FALSE, message = ""),
    required = list(),
    optional = list()
  )

  # --- R version check ---
  r_ver <- getRversion()
  min_ver <- "4.2.0"
  r_ok <- r_ver >= min_ver
  results$r_version <- list(pass = r_ok, version = as.character(r_ver))

  if (verbose) {
    if (r_ok) {
      cli::cli_alert_success("R version {r_ver} (>= {min_ver} required)")
    } else {
      cli::cli_alert_danger(
        "R version {r_ver} -- please upgrade to >= {min_ver}"
      )
    }
  }

  # --- Required packages ---
  required_pkgs <- c(
    "cli",
    "dplyr",
    "tibble",
    "tidyr",
    "purrr",
    "readr",
    "rlang",
    "ggplot2",
    "stringr",
    "glue",
    "forcats",
    "lubridate",
    "fs",
    "openxlsx2",
    "scales",
    "ggh4x",
    "assertr"
  )

  if (verbose) {
    cli::cli_h2("Required packages")
  }

  for (pkg in required_pkgs) {
    installed <- requireNamespace(pkg, quietly = TRUE)
    ver <- if (installed) as.character(utils::packageVersion(pkg)) else
      NA_character_
    results$required[[pkg]] <- list(pass = installed, version = ver)

    if (verbose) {
      if (installed) {
        cli::cli_alert_success("{pkg} ({ver})")
      } else {
        cli::cli_alert_danger("{pkg} -- not installed")
      }
    }
  }

  # --- Optional (suggested) packages ---
  optional_pkgs <- c(
    "knitr",
    "rmarkdown",
    "testthat",
    "patchwork",
    "ggrepel",
    "ComplexHeatmap",
    "rgoslin",
    "lancer",
    "enviPat"
  )

  if (verbose) {
    cli::cli_h2("Optional packages")
  }

  for (pkg in optional_pkgs) {
    installed <- requireNamespace(pkg, quietly = TRUE)
    ver <- if (installed) as.character(utils::packageVersion(pkg)) else
      NA_character_
    results$optional[[pkg]] <- list(pass = installed, version = ver)

    if (verbose) {
      if (installed) {
        cli::cli_alert_success("{pkg} ({ver})")
      } else {
        cli::cli_alert_info("{pkg} -- not installed (optional)")
      }
    }
  }

  # --- Summary ---
  req_ok <- all(vapply(results$required, function(x) x$pass, logical(1)))

  if (verbose) {
    cli::cli_h2("Summary")
    if (r_ok && req_ok) {
      cli::cli_alert_success("All good! mrmhub is ready to use.")
    } else {
      cli::cli_alert_warning(
        "Some issues found. Install missing packages with:"
      )
      missing <- names(Filter(function(x) !x$pass, results$required))
      if (length(missing) > 0) {
        cli::cli_code(
          paste0(
            'install.packages(c("',
            paste(missing, collapse = '", "'),
            '"))'
          )
        )
      }
    }
  }

  invisible(results)
}
