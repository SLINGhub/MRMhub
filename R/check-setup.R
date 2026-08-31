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
  min_ver <- "4.1.0"
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
    "ggvenn",
    "ggbeeswarm",
    "rgoslin",
    "lancer",
    "enviPat",
    "SummarizedExperiment",
    "lipidr"
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


# Suggested packages that do not come from CRAN. Everything else is installed
# with `install.packages()`.
pkg_source_bioc <- c(
  "sva",
  "SummarizedExperiment",
  "S4Vectors",
  "lipidr",
  "rgoslin"
)
pkg_source_github <- c(
  lancer = "SLINGhub/lancer",
  rmzTabM = "lifs-tools/rmzTabM"
)

# Quote a package vector as R code: "a" or c("a", "b")
pkg_code <- function(x) {
  if (length(x) == 1) {
    paste0('"', x, '"')
  } else {
    paste0('c("', paste(x, collapse = '", "'), '")')
  }
}

# One install command per package source, bootstrapping the installer itself
# when it is missing.
pkg_install_hints <- function(pkgs) {
  hints <- character()

  cran <- setdiff(pkgs, c(pkg_source_bioc, names(pkg_source_github)))
  if (length(cran) > 0) {
    hints <- c(hints, paste0("install.packages(", pkg_code(cran), ")"))
  }

  bioc <- intersect(pkgs, pkg_source_bioc)
  if (length(bioc) > 0) {
    boot <- if (is_installed("BiocManager")) "" else
      'install.packages("BiocManager"); '
    hints <- c(
      hints,
      paste0(boot, "BiocManager::install(", pkg_code(bioc), ")")
    )
  }

  gh <- pkg_source_github[intersect(names(pkg_source_github), pkgs)]
  if (length(gh) > 0) {
    boot <- if (is_installed("pak")) "" else 'install.packages("pak"); '
    hints <- c(hints, paste0(boot, "pak::pak(", pkg_code(unname(gh)), ")"))
  }

  hints
}

#' Require suggested packages
#'
#' Replacement for [rlang::check_installed()] that never prompts. The prompt
#' only works at a plain R console: in a notebook the `menu()` question is
#' either invisible or swallows the code sent after it, leaving the user with
#' no way to answer. This always aborts instead, naming the packages and the
#' command that installs them (CRAN, Bioconductor or GitHub as appropriate).
#'
#' @param pkg Character vector of package names.
#' @param reason Sentence completing "The package(s) ... are required", with
#'   its own trailing period.
#' @param call Calling environment, used for the error message.
#'
#' @return Invisibly `TRUE` if all packages are installed, otherwise an error.
#' @noRd
check_pkg_installed <- function(pkg, reason = NULL, call = caller_env()) {
  missing <- pkg[!vapply(pkg, is_installed, logical(1))]
  if (length(missing) == 0) {
    return(invisible(TRUE))
  }

  reason <- if (is.null(reason)) "." else paste0(" ", reason)
  hints <- pkg_install_hints(missing)

  cli_abort(
    c(
      paste0("The package{?s} {.pkg {missing}} {?is/are} required", reason),
      set_names(
        paste0("Install with {.code ", hints, "}"),
        rep("i", length(hints))
      )
    ),
    call = call
  )
}
