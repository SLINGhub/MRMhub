# Tests for check_setup(): the environment / dependency diagnostics helper.

test_that("check_setup() returns a structured result invisibly", {
  expect_invisible(check_setup(verbose = FALSE))

  res <- check_setup(verbose = FALSE)
  expect_named(res, c("r_version", "required", "optional"))

  # The suite itself runs on a supported R with every hard dependency present.
  expect_true(res$r_version$pass)
  expect_type(res$r_version$version, "character")
  expect_true(all(vapply(res$required, function(x) x$pass, logical(1))))
  expect_true("cli" %in% names(res$required))
  expect_type(res$required$cli$version, "character")
  expect_type(res$optional, "list")
})

test_that("check_setup(verbose = TRUE) runs the full report path", {
  # cli writes to the message stream; we only care that the verbose branches run
  # and the structured result is still returned.
  suppressMessages(invisible(capture.output(
    res <- check_setup(verbose = TRUE)
  )))
  expect_named(res, c("r_version", "required", "optional"))
  expect_true(res$r_version$pass)
})

test_that("check_setup() flags a missing required package", {
  # Make only ggh4x look absent; every other requireNamespace() succeeds so the
  # verbose danger / summary-warning / install-hint branches are exercised.
  local_mocked_bindings(
    requireNamespace = function(package, ...) !identical(package, "ggh4x"),
    .package = "base"
  )
  suppressMessages(invisible(capture.output(
    res <- check_setup(verbose = TRUE)
  )))

  expect_false(res$required$ggh4x$pass)
  expect_true(is.na(res$required$ggh4x$version))
  expect_false(all(vapply(res$required, function(x) x$pass, logical(1))))
})

test_that("check_pkg_installed() passes silently when packages are present", {
  expect_invisible(check_pkg_installed("cli"))
  expect_true(check_pkg_installed(c("cli", "dplyr")))
})

test_that("check_pkg_installed() never prompts, also in interactive sessions", {
  # rlang::check_installed() would open a menu() here, which a notebook front
  # end cannot answer; we always abort with an install hint instead.
  withr::local_options(rlang_interactive = TRUE)

  expect_error(
    check_pkg_installed("mrmhubnotapackage", reason = "to plot the curves."),
    "to plot the curves"
  )
  expect_snapshot(
    check_pkg_installed(
      c("mrmhubnotapackage", "mrmhubalsonotapackage"),
      reason = "to run this example."
    ),
    error = TRUE
  )
})

test_that("install hints follow the package source", {
  expect_equal(pkg_install_hints("ggvenn"), 'install.packages("ggvenn")')
  expect_equal(
    pkg_install_hints(c("ggvenn", "patchwork")),
    'install.packages(c("ggvenn", "patchwork"))'
  )
  expect_match(pkg_install_hints("sva"), 'BiocManager::install\\("sva"\\)')
  expect_match(pkg_install_hints("lancer"), 'pak::pak\\("SLINGhub/lancer"\\)')

  # One command per source, CRAN first.
  hints <- pkg_install_hints(c("sva", "ggvenn", "lancer"))
  expect_length(hints, 3)
  expect_match(hints[[1]], "install.packages", fixed = TRUE)
})
