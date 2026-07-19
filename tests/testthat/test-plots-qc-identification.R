mexp <- mrmhub::MRMhubExperiment(title = "sPerfect")

data_path <- test_path("testdata/mrmhub/FullPanelFewSamples_MRMkit_interror.csv")
mexp <- import_data_mrmhub(
  data = mexp,
  path = data_path,
  import_metadata = TRUE
)


test_that("plot_rt_vs_chain works", {
  p <- plot_rt_vs_chain(mexp, qc_types = "SPL", x_var = "total_c")
  expect_doppelganger_cond("default plot_rt_vs_chain", p)
})

# Regre
test_that("plot_rt_vs_chain works with x axis db", {
  p <- plot_rt_vs_chain(mexp, qc_types = "SPL", x_var = "total_db")
  expect_doppelganger_cond("plot_rt_vs_chain xaxis db", p)
})

test_that("plot_rt_vs_chain works with x axis db", {
  p <- plot_rt_vs_chain(mexp, qc_types = "SPL", x_var = "ecn")
  expect_doppelganger_cond("plot_rt_vs_chain xaxis ecn", p)
})

test_that("plot_rt_vs_chain no robust regress", {
  p <- plot_rt_vs_chain(
    mexp,
    qc_types = "SPL",
    x_var = "total_c",
    robust_regression = FALSE
  )
  expect_doppelganger_cond(" plot_rtr_vs_chain norobustreg", p)
})

test_that("plot_rt_vs_chain include qualifier", {
  mexp_temp <- mexp
  mexp_temp@dataset[
    str_detect(mexp_temp@dataset$feature_id, "PC 3"),
  ]$is_quantifier <- FALSE
  p <- plot_rt_vs_chain(
    mexp_temp,
    qc_types = "SPL",
    x_var = "total_c",
    include_qualifier = TRUE
  )
  expect_doppelganger_cond("plot_rt_vs_chain with qual", p)

  p <- plot_rt_vs_chain(
    mexp_temp,
    qc_types = "SPL",
    x_var = "total_c",
    include_qualifier = FALSE
  )
  expect_doppelganger_cond("plot_rt_vs_chain no qual", p)
})

test_that("plot_rt_vs_chain no robust regress", {
  p <- plot_rt_vs_chain(
    mexp,
    qc_types = "SPL",
    x_var = "total_c",
    outliers_highlight = FALSE
  )
  expect_doppelganger_cond(" plot_rtr_vs_chain hide outlierpoint", p)
})


test_that("plot_rt_vs_chain with outlier report", {
  expect_message(
    p <- plot_rt_vs_chain(
      mexp,
      qc_types = "SPL",
      x_var = "total_c",
      outlier_print = TRUE
    ),
    "were flagged as potential annotation outliers: DG 18:1_20:0",
    fixed = TRUE
  )

  expect_no_message(
    p <- plot_rt_vs_chain(
      mexp,
      qc_types = "SPL",
      x_var = "total_c",
      outlier_print = FALSE
    )
  )
})


test_that("plot_rt_vs_chain no outlier report", {
  df <- tibble::tibble(
    feature = c(
      "LPC 18:1",
      "LPC 20:1",
      "LPC 22:1",
      "LPE 18:1",
      "LPE 20:1",
      "LPE 22:1"
    ),
    value = c(1.1, 2.2, 2.8, 2.1, 3.2, 4.8)
  )
  expect_message(
    p <- plot_rt_vs_chain(
      df,
      qc_types = "SPL",
      x_var = "total_c"
    ),
    "No potential annotation outliers were detected",
    fixed = TRUE
  )

  expect_doppelganger_cond(" plot_rtr_vs_chain tibble data", p)
})

# Regression: the documented default `qc_types = NA` (@template qc_types: "plots
# any of the non-blank QC types") used to filter to zero rows -- `%in% NA` is
# FALSE -- and then crash in the lipid-class grouping. It must plot the present
# non-blank QC types instead, as the sibling QC plots already do.
test_that("plot_rt_vs_chain plots data on the default qc_types = NA", {
  expect_no_error(
    p <- suppressMessages(suppressWarnings(
      plot_rt_vs_chain(mexp, x_var = "total_c")
    ))
  )
  b <- ggplot2::ggplot_build(p)
  expect_gt(sum(vapply(b$data, nrow, integer(1))), 0)
})

test_that("plot_rt_vs_chain draws a single merged colour/fill legend", {
  # The points map colour and fill to the same variable; the two scales must
  # share identical breaks/values so ggplot merges them into ONE legend instead
  # of drawing a duplicate (previously two same-titled legends whose order
  # flipped between renders). Open shapes (circle 1 / asterisk 8) mark outliers.
  for (xv in c("total_c", "total_db", "ecn")) {
    p <- suppressMessages(suppressWarnings(
      plot_rt_vs_chain(mexp, qc_types = "SPL", x_var = xv)
    ))
    cd <- ggplot2::get_guide_data(p, "colour")
    fd <- ggplot2::get_guide_data(p, "fill")
    expect_identical(cd$.label, fd$.label)
    expect_identical(cd$.value, fd$.value)
    # legend is sorted (colour otherwise trains on points + fitted lines)
    expect_false(is.unsorted(as.numeric(cd$.label)))
  }
  # points use open shapes (circle 1 / asterisk 8)
  b <- ggplot2::ggplot_build(suppressMessages(suppressWarnings(
    plot_rt_vs_chain(mexp, qc_types = "SPL", x_var = "total_c")
  )))
  shapes <- unique(stats::na.omit(unlist(lapply(
    b$data,
    function(d) if ("shape" %in% names(d)) d$shape
  ))))
  expect_true(all(shapes %in% c(1, 8)))
})
