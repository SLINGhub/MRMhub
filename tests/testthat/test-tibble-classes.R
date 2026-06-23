# Tests for the assertr_tibble class (metadata validation-report presentation).
# The styled report is produced by print.assertr_tibble() — cli only, no pillar.

# --- as_assertr_tibble() -----------------------------------------------------

test_that("as_assertr_tibble correctly converts data.frame to assertr_tibble", {
  df <- tibble::as_tibble(data.frame(a = 1:3, b = c("x", "y", "z")))
  assertr_tbl <- as_assertr_tibble(df)

  expect_s3_class(assertr_tbl, "assertr_tibble")
  expect_s3_class(assertr_tbl, "tbl_df")
  expect_s3_class(assertr_tbl, "data.frame")
})

test_that("as_assertr_tibble throws error if input is not a data.frame", {
  expect_error(as_assertr_tibble(123), "x must be a data.frame")
  expect_error(as_assertr_tibble("not a data.frame"), "x must be a data.frame")
})

# --- print.assertr_tibble() --------------------------------------------------
# Replaces the tibble header ("# A tibble: N x M") and the type-chip row with a
# divider banner, and appends an italic severity legend.

assertr_print_output <- function(x) {
  cli::ansi_strip(paste(utils::capture.output(print(x)), collapse = "\n"))
}

test_that("print.assertr_tibble shows the divider banner and severity legend", {
  assertr_tbl <- as_assertr_tibble(
    tibble::as_tibble(data.frame(a = 1:3, b = c("x", "y", "z")))
  )
  out <- assertr_print_output(assertr_tbl)

  expect_match(
    out,
    "E = Error, W = Warning, W* = Suppressed Warning, N = Note",
    fixed = TRUE
  )
  expect_match(out, "-{20,}") # divider line of dashes
})

test_that("print.assertr_tibble suppresses the tibble summary line", {
  assertr_tbl <- as_assertr_tibble(
    tibble::as_tibble(data.frame(a = 1:3, b = c("x", "y", "z")))
  )
  out <- assertr_print_output(assertr_tbl)

  expect_false(grepl("# A tibble:", out))
})

test_that("print.assertr_tibble shows the data body", {
  assertr_tbl <- as_assertr_tibble(
    tibble::as_tibble(data.frame(ColumnA = 1:3, ColumnB = c("x", "y", "z")))
  )
  out <- assertr_print_output(assertr_tbl)

  expect_match(out, "ColumnA")
  expect_match(out, "x")
})
