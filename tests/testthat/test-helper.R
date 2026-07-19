test_that("some_na works", {
  expect_true(some_na(c(NA, 1, 2)))
  expect_false(some_na(c(NA, NA, NA)))
  expect_false(some_na(c(1, 2, 3)))
  expect_false(some_na(NA))
  expect_false(some_na(1))
  expect_false(some_na(NULL))
})

test_that("safe_min works", {
  expect_equal(safe_min(c(4, 3, 2, 1)), 1)
  expect_equal(safe_min(c(NA, NA, 3, 2, 1)), NA_real_)
  expect_equal(safe_min(c(NA, NA, 3, 2, 1), na.rm = TRUE), 1)
  expect_equal(safe_min(c(NaN, NaN, 3, 2, 1)), NA_real_)
  expect_equal(safe_min(c(NaN, NaN, 3, 2, 1), na.rm = TRUE), 1)
  expect_equal(safe_min(c(NA, NaN, 1, 2, 3), na.rm = FALSE), NA_real_)
  expect_equal(safe_min(c(NA, NaN, 1, 2, 3), na.rm = TRUE), 1)
  expect_equal(safe_min(c(NA, NaN, NA)), NA_real_)
  expect_equal(safe_min(c(NaN, NaN, NaN)), NA_real_)
})

test_that("safe_max works", {
  expect_equal(safe_max(c(4, 3, 2, 1)), 4)
  expect_equal(safe_max(c(NA, NA, 3, 2, 1)), NA_real_)
  expect_equal(safe_max(c(NA, NA, 3, 2, 1), na.rm = TRUE), 3)
  expect_equal(safe_max(c(NaN, NaN, 3, 2, 1)), NA_real_)
  expect_equal(safe_max(c(NaN, NaN, 3, 2, 1), na.rm = TRUE), 3)
  expect_equal(safe_max(c(NA, NaN, 1, 2, 3), na.rm = FALSE), NA_real_)
  expect_equal(safe_max(c(NA, NaN, 1, 2, 3), na.rm = TRUE), 3)
  expect_equal(safe_max(c(NA, NaN, NA)), NA_real_)
  expect_equal(safe_max(c(NaN, NaN, NaN)), NA_real_)
})


test_that("check_groupwise_identical_ids works", {
  df_identical <- dplyr::tibble(
    group = c("A", "A", "A", "B", "B"),
    id = c(1, 1, 1, 2, 2),
    other_col = c(11, 21, 31, 41, 51)
  )
  expect_true(check_groupwise_identical_ids(
    df_identical,
    group_col = group,
    id_col = id
  ))

  df_non_identical <- dplyr::tibble(
    group = c("A", "A", "A", "B", "B"),
    id = c(1, 2, 1, 2, 3)
  )
  expect_false(check_groupwise_identical_ids(
    df_non_identical,
    group_col = group,
    id_col = id
  ))

  df_missing <- dplyr::tibble(
    group = c("A", "A", "B", "B"),
    id = c(1, NA, 2, 3)
  )
  expect_false(check_groupwise_identical_ids(
    df_missing,
    group_col = group,
    id_col = id
  ))

  df_single <- dplyr::tibble(group = "A", id = 1)
  expect_true(check_groupwise_identical_ids(
    df_single,
    group_col = group,
    id_col = id
  ))

  df_empty <- dplyr::tibble(
    group = character(0),
    id = integer(0)
  )
  expect_error(
    check_groupwise_identical_ids(df_empty, group_col = group, id_col = id),
    "data has no rows"
  )
})

test_that("compare_values works", {
  tbl <- dplyr::tibble(
    feature_id = c("feat1", "feat2", "feat3", "feat4"),
    value1 = c(1, 2, NA, 4),
    value2 = c(5, NA, 7, 8)
  )

  expect_error(
    compare_values(
      tbl,
      val = "non_existing_column",
      threshold = 5,
      operator = ">"
    ),
    "QC parameter is not available. Please verify the argument "
  )

  tbl_with_na <- dplyr::tibble(value1 = c(NA, NA, NA, NA))
  expect_equal(
    compare_values(tbl_with_na, val = "value1", threshold = NA, operator = ">"),
    c(NA, NA, NA, NA)
  )

  expect_equal(
    compare_values(tbl, val = "value1", threshold = 3, operator = ">"),
    c(FALSE, FALSE, FALSE, TRUE)
  )
  expect_equal(
    compare_values(tbl, val = "value1", threshold = 3, operator = "<"),
    c(TRUE, TRUE, FALSE, FALSE)
  )
  expect_equal(
    compare_values(tbl, val = "value1", threshold = 2, operator = "=="),
    c(FALSE, TRUE, FALSE, FALSE)
  )
  expect_equal(
    compare_values(tbl, val = "value2", threshold = 8, operator = "=="),
    c(FALSE, FALSE, FALSE, TRUE)
  )

  df_empty <- dplyr::tibble(a = character(0), b = integer(0))
  expect_error(
    compare_values(df_empty, val = "value1", threshold = 3, operator = ">"),
    "tbl has no rows"
  )
})


test_that("comp_lgl_vec works as it should", {
  expect_equal(
    comp_lgl_vec(
      list(c(TRUE, TRUE, TRUE), c(FALSE, TRUE, TRUE)),
      .operator = "AND"
    ),
    c(FALSE, TRUE, TRUE)
  )

  expect_equal(
    comp_lgl_vec(
      list(c(TRUE, TRUE, TRUE), c(FALSE, TRUE, TRUE)),
      .operator = "OR"
    ),
    c(TRUE, TRUE, TRUE)
  )

  expect_equal(
    comp_lgl_vec(
      list(c(TRUE, TRUE, TRUE), c(FALSE, TRUE, TRUE)),
      .operator = "XOR"
    ),
    c(TRUE, FALSE, FALSE)
  )

  expect_equal(
    comp_lgl_vec(list(c(NA, NA, NA), c(NA, NA, NA)), .operator = "AND"),
    c(NA, NA, NA)
  )

  expect_error(
    comp_lgl_vec(
      list(c(TRUE, FALSE, TRUE), c(TRUE, TRUE, FALSE)),
      .operator = "XAND"
    ),
    "Unsupported operator"
  )
})

test_that("has_any_name works in assertr::verify as it should", {
  dt <- tibble(
    col_a = c(1, 2, 3, 4, 5),
    col_b = c(1, 2, 3, 4, 5),
    col_c = c(1, 2, 3, 4, 5)
  )
  expect_equal(
    dim(
      dt |>
        assertr::verify(
          has_any_name("col_a"),
          obligatory = TRUE,
          description = ""
        )
    ),
    c(5, 3)
  )
  expect_equal(
    dim(
      dt |>
        assertr::verify(
          has_any_name("col_a", "col_b"),
          obligatory = TRUE,
          description = ""
        )
    ),
    c(5, 3)
  )
  res <- dt |>
    assertr::verify(
      has_any_name("col_noexist"),
      obligatory = TRUE,
      description = "",
      error_fun = assertr::error_df_return
    )
  expect_equal(dim(res), c(1, 6)) # means it is an rrror deta frame
  res <- dt |>
    assertr::verify(
      has_any_name("col_a", "col_noexist"),
      obligatory = TRUE,
      description = "",
      error_fun = assertr::error_df_return
    )
  expect_equal(dim(res), c(5, 3))
})

test_that("add_missing_column works", {
  # Create a sample data frame without the target column
  dt <- tibble(A = 1:5, B = 6:10)

  result <- add_missing_column(dt, "c", 99, make_lowercase = FALSE)
  expect_equal(result$c, rep(99, 5))

  result <- add_missing_column(dt, "A", 99, make_lowercase = TRUE)
  expect_equal(result$a, 1:5)
  result <- add_missing_column(dt, "A", 99, make_lowercase = FALSE)
  expect_equal(result$A, 1:5)
})


test_that("get_conc_unit works as expected", {
  expect_equal(get_conc_unit("ul", "pmol"), "\U003BCmol/L")
  expect_equal(get_conc_unit("mL", "pmol"), "pmol/mL")
  expect_equal(get_conc_unit("L", "pmol"), "pmol/L")
  expect_equal(
    get_conc_unit(c("ul", "ml"), "pmol"),
    "pmol/sample amount unit (multiple units)"
  )
  expect_equal(get_conc_unit("mg", "pmol"), "pmol/mg")
  expect_equal(get_conc_unit("Ul", "pmol"), "\U003BCmol/L")
  expect_equal(get_conc_unit("L", "ng/L"), "ng/L")
  expect_equal(get_conc_unit("mL", "ng"), "ng/mL")
})


# Test: Handling when there are no disconnected rows
test_that("order_chained_columns_tbl no disconnected rows", {
  df_no_disconnected <- data.frame(
    ColA = c("INSPECT", "VERIFY", "NULL", "NEW", "CREATE"),
    ColB = c("VERIFY", "PUBLISH", "NEW", "CREATE", "INSPECT"),
    colC = c("1", "11", "111", "1111", "11111"),
    stringsAsFactors = FALSE
  )
  result <- order_chained_columns_tbl(
    df_no_disconnected,
    "ColA",
    "ColB",
    include_chain_id = TRUE
  )

  # No disconnected rows, so the result should just be the connected chain
  expect_equal(nrow(result), 5) # 5 rows should be returned (no disconnected rows)
  expect_equal(names(result), c("ColA", "ColB", "chain_id", "colC")) # 5 rows should be returned (no disconnected rows)
})

test_that("order_chained_columns_tbl no disconnected rows", {
  df_no_disconnected <- data.frame(
    From = c("INSPECT", "VERIFY", "NULL", "NEW", "CREATE"),
    To = c("VERIFY", "PUBLISH", "NEW", "CREATE", "INSPECT"),
    colC = c("1", "11", "111", "1111", "11111"),
    stringsAsFactors = FALSE
  )
  result <- order_chained_columns_tbl(
    df_no_disconnected,
    "From",
    "To",
    FALSE,
    "exclude"
  )

  # No disconnected rows, so the result should just be the connected chain
  expect_equal(nrow(result), 5) # 5 rows should be returned (no disconnected rows)
  expect_equal(names(result), c("From", "To", "colC")) # 5 rows should be returned (no disconnected rows)
})


# Unordered sample data frame for testing
df_unordered <- data.frame(
  From = c(
    "INSPECT",
    "VERIFY",
    "START",
    "NULL",
    "NEW",
    "CREATE",
    "MID",
    "DIFFERENT",
    "OUTLIER"
  ),
  To = c(
    "VERIFY",
    "PUBLISH",
    "MID",
    "NEW",
    "CREATE",
    "INSPECT",
    "END",
    "NOTSAME",
    "INSIDER"
  ),
  stringsAsFactors = FALSE
)


# Test: Include disconnected rows
test_that("order_chained_columns_tbl remove disconnected rows", {
  result <- order_chained_columns_tbl(df_unordered, "From", "To", FALSE, "keep")
  # Check the expected structure of the result
  expect_equal(nrow(result), 9)
  expect_false("ISOLATED" %in% result$From)
  expect_false("LONELY" %in% result$To)
})

# Test: Remove disconnected rows
test_that("order_chained_columns_tbl remove disconnected rows", {
  result <- order_chained_columns_tbl(
    df_unordered,
    "From",
    "To",
    FALSE,
    "exclude"
  )
  # Check the expected structure of the result
  expect_equal(nrow(result), 7) # 7 rows should be returned after removing disconnected ones
  expect_false("ISOLATED" %in% result$From)
  expect_false("LONELY" %in% result$To)
})


# Test: Circular dependency detection
test_that("order_chained_columns_tbl fail circular dependency", {
  df_circular <- data.frame(
    From = c("A", "B", "C"),
    To = c("B", "C", "A"),
    stringsAsFactors = FALSE
  )
  expect_error(
    order_chained_columns_tbl(df_circular, "From", "To", "exclude"),
    "Circular dependency detected"
  )
})


# Test: Circular dependency detection
test_that("order_chained_columns_tbl fail circular dependency", {
  df_circular <- data.frame(
    From = c("A", "B", "C", "D"),
    To = c("B", "A", "D", "E"),
    stringsAsFactors = FALSE
  )
  expect_error(
    order_chained_columns_tbl(df_circular, "From", "To", FALSE, "exclude"),
    "Circular dependency detected"
  )
})


# Test: Check if chain_id is correctly assigned
test_that("order_chained_columns_tbl chain_id assignment", {
  result <- order_chained_columns_tbl(df_unordered, "From", "To", TRUE, "keep")
  # Check that chain_id is assigned properly to connected and disconnected rows
  expect_true(all(!is.na(result$chain_id)))
  expect_true(any(result$chain_id == 1)) # At least one connected chain
  expect_true(any(result$chain_id == 3)) # Disconnected chain at the end
})


# Test: duplicate from-key is rejected (would silently drop mappings otherwise)
test_that("order_chained_columns_tbl fails on duplicate from-key", {
  df_dup <- data.frame(
    From = c("A", "A", "B"),
    To = c("B", "C", "C"),
    stringsAsFactors = FALSE
  )
  expect_error(
    order_chained_columns_tbl(df_dup, "From", "To", FALSE, "keep"),
    "Duplicate keys"
  )
})

# ---- pretty-axis helper (Branch 5) ---------------------------------------

test_that("pretty_n_breaks scales tick count down as panels grow", {
  expect_equal(pretty_n_breaks(1), 6L)
  expect_equal(pretty_n_breaks(4), 5L)
  expect_equal(pretty_n_breaks(9), 4L)
  expect_equal(pretty_n_breaks(20), 3L)
  # never below the >=3-label floor
  expect_gte(pretty_n_breaks(100), 3L)
})

# helper: non-empty axis labels a built plot actually renders. get_labels() may
# return character labels or `10^n` language objects (math_format), so count any
# element that is not a lone NA.
built_labels <- function(p, axis = "x") {
  b <- ggplot2::ggplot_build(p)
  lbl <- b$layout$panel_params[[1]][[axis]]$get_labels()
  keep <- !vapply(
    lbl,
    function(x) is.null(x) || (length(x) == 1 && is.na(x)) ||
      (is.character(x) && !nzchar(x)),
    logical(1)
  )
  lbl[keep]
}

test_that(".pretty_labels keys on the break VALUES, not a variable name", {
  # typical CV / RT / conc ranges -> plain comma numbers
  expect_equal(.pretty_labels(c(0, 10, 20, 30)), c("0", "10", "20", "30"))
  expect_equal(.pretty_labels(c(0, 30, 60, 90)), c("0", "30", "60", "90"))
  expect_equal(.pretty_labels(c(1, 10, 100, 1000)), c("1", "10", "100", "1,000"))
  # extreme magnitude -> superscript scientific expressions, not "e+05" strings
  sci <- .pretty_labels(c(0, 5e5, 1e6))
  expect_type(sci, "list")
  expect_true(any(vapply(sci, is.call, logical(1))))
  expect_false(any(grepl("e\\+", format(sci))))
})

test_that("scale_pretty linear labels are plain numbers for small ranges", {
  d <- data.frame(x = c(0, 40), y = c(2, 7))
  p <- ggplot2::ggplot(d, ggplot2::aes(x, y)) +
    ggplot2::geom_point() +
    scale_pretty_x(n = 5) +
    scale_pretty_y(n = 5)
  expect_gte(length(built_labels(p, "x")), 3)
  expect_gte(length(built_labels(p, "y")), 3)
  # plain numbers, no scientific "e"
  expect_false(any(grepl("e\\+|e-", as.character(built_labels(p, "x")))))
})

test_that("scale_pretty linear labels go superscript for extreme magnitudes", {
  d <- data.frame(x = c(0, 5e5), y = c(0, 8e5))
  p <- ggplot2::ggplot(d, ggplot2::aes(x, y)) +
    ggplot2::geom_point() +
    scale_pretty_x(n = 5) +
    scale_pretty_y(n = 5)
  expect_gte(length(built_labels(p, "x")), 3)
  expect_gte(length(built_labels(p, "y")), 3)
  # rendered as plotmath expressions (superscript), not "e+05" strings
  expect_true(any(vapply(built_labels(p, "x"), is.call, logical(1))))
})

test_that("scale_pretty_x/y give >=3 non-empty labels on a log range", {
  d <- data.frame(x = c(10, 1e5), y = c(1, 1e4))
  p <- ggplot2::ggplot(d, ggplot2::aes(x, y)) +
    ggplot2::geom_point() +
    scale_pretty_x(log = TRUE) +
    scale_pretty_y(log = TRUE)
  expect_gte(length(built_labels(p, "x")), 3)
  expect_gte(length(built_labels(p, "y")), 3)
})

test_that("pretty_logticks returns an annotation_logticks layer", {
  expect_s3_class(pretty_logticks("bl"), "ggproto")
})
