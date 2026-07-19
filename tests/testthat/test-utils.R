test_that("coerce_checked parses clean values without warning", {
  expect_silent(res <- coerce_checked(c("1.5", "2", "3"), column = "x"))
  expect_equal(res, c(1.5, 2, 3))

  expect_silent(
    resi <- coerce_checked(c("1", "2", "3"), column = "x", integer = TRUE)
  )
  expect_identical(resi, c(1L, 2L, 3L))
})

test_that("coerce_checked handles decimal commas and factors", {
  expect_equal(
    coerce_checked(c("1,5", "2,25"), column = "x", decimal_comma = TRUE),
    c(1.5, 2.25)
  )
  expect_equal(
    coerce_checked(factor(c("1.5", "2")), column = "x"),
    c(1.5, 2)
  )
})

test_that("coerce_checked preserves precision of already-numeric input", {
  x <- c(1.234567890123, 2.5, pi)
  # No character round-trip: values must be returned bit-for-bit.
  expect_identical(coerce_checked(x, column = "x"), x)
})

test_that("coerce_checked treats blanks as NA without warning", {
  expect_silent(res <- coerce_checked(c("1", "", "  ", NA), column = "x"))
  expect_equal(res, c(1, NA, NA, NA))
})

test_that("coerce_checked warns on non-blank parse failures and names the column", {
  expect_warning(
    res <- coerce_checked(c("1.2", "oops", "3", "N/A"), column = "myCol"),
    "myCol"
  )
  expect_equal(res, c(1.2, NA, 3, NA))

  # The warning reports the count and the offending values.
  expect_warning(
    coerce_checked(c("1.2", "oops", "N/A"), column = "myCol"),
    "2 values"
  )
  expect_warning(
    coerce_checked(c("1.2", "oops", "3"), column = "myCol"),
    "oops"
  )
})

test_that("coerce_logical_checked accepts broadened boolean tokens", {
  expect_silent(
    res <- coerce_logical_checked(
      c("TRUE", "true", "T", "yes", "Y", "1", "FALSE", "no", "N", "0"),
      column = "is_istd"
    )
  )
  expect_equal(
    res,
    c(TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, FALSE, FALSE, FALSE, FALSE)
  )
})

test_that("coerce_logical_checked passes logical through and handles blanks", {
  expect_identical(
    coerce_logical_checked(c(TRUE, FALSE, NA), column = "x"),
    c(TRUE, FALSE, NA)
  )
  expect_silent(
    res <- coerce_logical_checked(c("yes", "", "  ", NA), column = "x")
  )
  expect_equal(res, c(TRUE, NA, NA, NA))
})

test_that("coerce_logical_checked warns on unrecognized non-blank tokens", {
  expect_warning(
    res <- coerce_logical_checked(
      c("yes", "no", "maybe", "x"),
      column = "is_istd"
    ),
    "is_istd"
  )
  expect_equal(res, c(TRUE, FALSE, NA, NA))
  expect_warning(
    coerce_logical_checked(c("yes", "maybe"), column = "is_istd"),
    "maybe"
  )
})

test_that("check_single_pivot_value passes single values and aborts on duplicates", {
  expect_equal(check_single_pivot_value(5), 5)
  expect_equal(check_single_pivot_value("a"), "a")
  expect_equal(check_single_pivot_value(numeric(0)), numeric(0))
  expect_error(
    check_single_pivot_value(c(1, 2)),
    "more than one value per cell"
  )

  # As a pivot_wider values_fn it is a no-op on clean data and errors on a
  # duplicated (id, name) cell instead of silently producing a list-column.
  clean <- tibble::tibble(id = c("a", "b"), name = c("x", "x"), val = c(1, 2))
  expect_equal(
    tidyr::pivot_wider(
      clean,
      names_from = "name",
      values_from = "val",
      values_fn = check_single_pivot_value
    ),
    tidyr::pivot_wider(clean, names_from = "name", values_from = "val")
  )
  dup <- tibble::tibble(id = c("a", "a"), name = c("x", "x"), val = c(1, 2))
  expect_error(
    tidyr::pivot_wider(
      dup,
      names_from = "name",
      values_from = "val",
      values_fn = check_single_pivot_value
    ),
    "more than one value per cell"
  )
})

test_that("strip_raw_extension removes only a trailing raw-data extension", {
  # Anchored: a genuine trailing extension is removed ...
  expect_equal(strip_raw_extension("Study_01.d"), "Study_01")
  expect_equal(strip_raw_extension("sample.mzML"), "sample")
  expect_equal(strip_raw_extension("run.raw"), "run")
  expect_equal(strip_raw_extension("a.wiff"), "a")
  expect_equal(strip_raw_extension("a.lcd"), "a")
  expect_equal(strip_raw_extension("a.chrom"), "a")
  # ... but an extension-like substring earlier in the name is preserved.
  expect_equal(strip_raw_extension("Study.data_01.d"), "Study.data_01")
  expect_equal(strip_raw_extension("Study.data_01"), "Study.data_01")
})

test_that("strip_raw_extension handles .wiff2 (regression: metadata regex omitted it)", {
  expect_equal(strip_raw_extension("sample.wiff2"), "sample")
  # Not corrupted to "sample2" by an unanchored/short match.
  expect_false(strip_raw_extension("sample.wiff2") == "sample2")
})

test_that("strip_raw_extension is case-insensitive and squish-order-independent", {
  expect_equal(strip_raw_extension("run.MZML"), "run")
  expect_equal(strip_raw_extension("run.D"), "run")
  # A trailing space must not defeat the `$` anchor: squish happens first.
  expect_equal(strip_raw_extension("Study_01.d "), "Study_01")
  expect_equal(strip_raw_extension("  Study_01.d  "), "Study_01")
  # Internal whitespace runs are collapsed too.
  expect_equal(strip_raw_extension("Study  01.d"), "Study 01")
})

test_that("squish_ids normalizes named id columns and ignores absent ones", {
  tbl <- tibble::tibble(
    analysis_id = c(" QC  01 ", "QC 02"),
    feature_id = c("PC  32:1", " PC 34:1"),
    other = c("keep  me", "as is")
  )
  out <- squish_ids(tbl, c("analysis_id", "feature_id", "not_a_column"))
  expect_equal(out$analysis_id, c("QC 01", "QC 02"))
  expect_equal(out$feature_id, c("PC 32:1", "PC 34:1"))
  # A non-id column is untouched, and an absent column name is silently skipped.
  expect_equal(out$other, c("keep  me", "as is"))
})

test_that("squish_ids coerces non-character id columns and is a no-op on empty selection", {
  tbl <- tibble::tibble(
    batch_id = c(1L, 2L),
    feature_id = factor(c("a ", " a"))
  )
  out <- squish_ids(tbl, c("batch_id", "feature_id"))
  expect_equal(out$batch_id, c("1", "2"))
  expect_equal(out$feature_id, c("a", "a")) # both collapse to one value
  expect_identical(squish_ids(tbl, character(0)), tbl)
})
