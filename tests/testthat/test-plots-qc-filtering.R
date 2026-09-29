# library(fs)
# library(vdiffr)
# library(ggplot2)
# library(testthat)
# library(scales)

mexp_orig <- lipidomics_dataset
mexp <- normalize_by_istd(mexp_orig)
mexp <- quantify_by_istd(mexp)
mexp_proc <- calc_qc_metrics(mexp, use_batch_medians = FALSE)

mexp_filt_all <- filter_features_qc(
  mexp_proc,
  clear_existing = TRUE,
  include_qualifier = FALSE,
  include_istd = FALSE,
  min.intensity.lowest.tqc = 0
)

get_feature_n <- function(plt) {
  df <- ggplot2::ggplot_build(plt)$data |> as.data.frame() |> filter(group == 1)
  sum(df$y)
}


test_that("plot_qc_summary_byclass plots correctly", {
  mexp_res <- filter_features_qc(
    mexp_proc,
    clear_existing = TRUE,
    include_qualifier = FALSE,
    include_istd = FALSE,
    min.intensity.lowest.tqc = 0
  )

  p <- plot_qc_summary_byclass(mexp_res)
  expect_equal(get_feature_n(p), 19)

  p <- plot_qc_summary_overall(mexp_res)
  expect_doppelganger_cond("plot_qc_summary_summ with no fails ", p)

  mexp_res <- filter_features_qc(
    mexp_proc,
    clear_existing = TRUE,
    include_qualifier = TRUE,
    include_istd = TRUE,
    min.intensity.lowest.tqc = 0
  )

  p <- plot_qc_summary_byclass(mexp_res)
  expect_equal(get_feature_n(p), 29)
  p <- plot_qc_summary_overall(mexp_res)
  expect_doppelganger_cond(
    "plot_qc_summary_summ with no fails with qual ",
    p
  )

  mexp_res2 <- filter_features_qc(
    mexp_proc,
    include_qualifier = FALSE,
    include_istd = FALSE,
    clear_existing = TRUE,
    min.signalblank.median.spl.pblk = 100,
    min.intensity.median.bqc = 1E3,
    max.cv.conc.bqc = 23,
    max.dratio.sd.conc.bqc = 0.7,
    max.prop.missing.conc.spl = 0.1,
    response.curves.selection = c(1, 2),
    response.curves.summary = "best",
    max.slope.response = 1.05
  )

  p <- plot_qc_summary_byclass(mexp_res2)
  expect_equal(get_feature_n(p), 19)
  expect_doppelganger_cond("plot_qc_summary_byclass with fails 1", p)

  p <- plot_qc_summary_overall(mexp_res2)
  expect_doppelganger_cond("plot_qc_summary_summ with fails ", p)

  p <- plot_qc_summary_overall(mexp_res2, with_venn = FALSE)
  expect_doppelganger_cond("plot_qc_summary_summ with fails no venn", p)
})


test_that("QC summary plots count each feature once, incl. kept features", {
  mexp_res <- filter_features_qc(
    mexp_proc,
    include_qualifier = FALSE,
    include_istd = FALSE,
    max.cv.conc.bqc = 5,
    features.to.keep = "CE 18:1"
  )
  p <- plot_qc_summary_overall(mexp_res, with_venn = FALSE)
  bars <- ggplot2::ggplot_build(p)$data[[1]]
  expect_equal(sum(bars$y), 19)
  expect_equal(p$data$count_pass[p$data$qc_criteria == "kept_failed_qc"], 1)

  p <- plot_qc_summary_byclass(mexp_res)
  expect_equal(sum(p$data$count_pass), 19)
  ce <- p$data[p$data$feature_class == "CE" & p$data$count_pass > 0, ]
  expect_equal(as.character(ce$qc_criteria), "kept_failed_qc")
})


test_that("the Venn diagram covers the same features as the bars", {
  mexp_res <- filter_features_qc(
    mexp_proc,
    include_qualifier = FALSE,
    include_istd = FALSE,
    min.signalblank.median.spl.pblk = 10,
    max.cv.conc.bqc = 10
  )
  p_venn <- plot_qc_summary_overall(mexp_res)[[2]]
  venn_ids <- unlist(lapply(ggplot2::ggplot_build(p_venn)$data, \(d) {
    unlist(d[vapply(d, is.character, logical(1))])
  }))
  m <- mexp_res@metrics_qc
  out_of_scope <- m$feature_id[m$is_istd | !m$is_quantifier]
  expect_false(any(out_of_scope %in% venn_ids))
})


test_that("plot_qc_summary_x handle errors", {
  expect_error(
    plot_qc_summary_byclass(mexp_proc),
    "Feature QC filter has not yet been applied"
  )

  expect_error(
    plot_qc_summary_overall(mexp_proc),
    "Feature QC filter has not yet been applied"
  )

  # No feature class defined
  mexp_temp <- mexp_filt_all
  mexp_temp@metrics_qc$feature_class <- NA

  expect_error(
    plot_qc_summary_byclass(mexp_temp),
    "This plot requires the `feature_class` to be defined in the data"
  )

  expect_no_error(
    plot_qc_summary_overall(mexp_temp)
  )
})

test_that("QC summary plots label the categories in words", {
  mexp_res <- filter_features_qc(
    mexp_proc,
    include_qualifier = FALSE,
    include_istd = FALSE,
    clear_existing = TRUE,
    min.signalblank.median.spl.pblk = 100,
    max.cv.conc.bqc = 23,
    max.dratio.sd.conc.bqc = 0.7
  )
  p <- plot_qc_summary_byclass(mexp_res)
  lab <- ggplot2::get_guide_data(p, "fill")$.label
  expect_true(all(c("passed", "< min S/B", "> max CV") %in% lab))
  expect_false(any(grepl("_", lab)))

  p <- plot_qc_summary_overall(mexp_res, with_venn = FALSE)
  lab <- ggplot2::get_guide_data(p, "y")$.label # flipped
  expect_true(all(c("passed", "< min S/B", "> max CV") %in% lab))
  expect_false(any(grepl("_", lab)))
})
