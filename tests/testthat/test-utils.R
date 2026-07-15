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
