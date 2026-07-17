library(ggplot2)

mexp_orig <- lipidomics_dataset
mexp_orig <- normalize_by_istd(mexp_orig)
mexp_orig <- calc_qc_metrics(mexp_orig)

mexp <- mexp_orig 
mexp@annot_features[str_detect(mexp@annot_features$feature_id, "LPC 18:1 \\((a|b)\\)"), ]$analyte_id <- "LPC 18:1"

mexp <- mrmhub:::link_data_metadata(mexp)

test_that("Default plot_qc_matrixeffects looks as expected", {
  mexp_dedup <- data_sum_features(mexp)
  expect_true("LPC 18:1" %in% mexp_dedup@annot_features$feature_id)
  expect_false("LPC 18:1 (a)" %in% mexp_dedup@annot_features$feature_id)
  expect_false("LPC 18:1 (b)" %in% mexp_dedup@annot_features$feature_id)
  expect_true("LPC 18:1 (ab) d7 (ISTD)" %in% mexp_dedup@annot_features$feature_id)
  expect_true("LPC 18:1" %in% unique(mexp_dedup@dataset$feature_id))
  expect_false("LPC 18:1 (a)" %in% unique(mexp_dedup@dataset$feature_id))
  expect_false("LPC 18:1 (ab)" %in% unique(mexp_dedup@dataset$feature_id))

})

mexp2 <- mexp_orig
mexp2@annot_features[str_detect(mexp2@annot_features$feature_id, "^PC"), ]$analyte_id <- "PC"
mexp2@annot_features[str_detect(mexp2@annot_features$feature_id, "^PC 4"), ]$is_quantifier <- FALSE
mexp2 <- mrmhub:::link_data_metadata(mexp2)

test_that("Default plot_qc_matrixeffects looks as expected", {
  mexp2_dedup <- data_sum_features(mexp2, qualifier_action = "separate")
  expect_true("PC" %in% unique(mexp2_dedup@dataset$feature_id))
  expect_false("PC 40:6" %in% unique(mexp2_dedup@dataset$feature_id))
  expect_false("PC 32:1" %in% unique(mexp2_dedup@dataset$feature_id))

  sum_pc <-  sum(mexp2_dedup@dataset[mexp2_dedup@dataset$feature_id == "PC", ]$feature_intensity)
  expect_equal(sum_pc, 2937988066.1)
  sum_pc <-  sum(mexp2_dedup@dataset[mexp2_dedup@dataset$feature_id == "PC_qual", ]$feature_intensity)
  expect_equal(sum_pc, 1715685212.3)

  mexp2_dedup <- data_sum_features(mexp2, qualifier_action = "include")
  expect_true("PC" %in% unique(mexp2_dedup@dataset$feature_id))
  expect_false("PC 40:6" %in% unique(mexp2_dedup@dataset$feature_id))
  expect_false("PC 32:1" %in% unique(mexp2_dedup@dataset$feature_id))

  sum_pc <-  sum(mexp2_dedup@dataset[mexp2_dedup@dataset$feature_id == "PC", ]$feature_intensity)
  expect_equal(sum_pc, 4653673278.4)

  mexp2_dedup <- data_sum_features(mexp2, qualifier_action = "exclude")
  expect_true("PC" %in% unique(mexp2_dedup@dataset$feature_id))
  expect_false("PC 40:6" %in% unique(mexp2_dedup@dataset$feature_id))
  expect_false("PC 32:1" %in% unique(mexp2_dedup@dataset$feature_id))

  sum_pc <-  sum(mexp2_dedup@dataset[mexp2_dedup@dataset$feature_id == "PC", ]$feature_intensity)
  expect_equal(sum_pc, 2937988066.1)

})

test_that("data_sum_features sums feature_area and NAs the peak widths of merged analytes", {
  ded <- suppressMessages(data_sum_features(mexp, qualifier_action = "include"))

  an <- mexp@dataset$analysis_id[1]
  constituents <- mexp@dataset[
    mexp@dataset$analysis_id == an &
      stringr::str_detect(mexp@dataset$feature_id, "LPC 18:1 \\((a|b)\\)"),
  ]
  expect_gt(nrow(constituents), 1) # a real merge happens

  merged <- ded@dataset[
    ded@dataset$analysis_id == an & ded@dataset$feature_id == "LPC 18:1",
  ]
  expect_equal(nrow(merged), 1)

  # feature_area is an extensive signal variable and is summed like intensity /
  # height; previously it fell through the aggregation and became a silent NA.
  expect_equal(merged$feature_area, sum(constituents$feature_area, na.rm = TRUE))
  expect_equal(merged$feature_rt, mean(constituents$feature_rt, na.rm = TRUE))

  # a merged analyte is not a single chromatographic peak -> no meaningful width
  expect_true(is.na(merged$feature_fwhm))
  expect_true(is.na(merged$feature_width))

  # ... but unmerged features keep theirs
  kept <- ded@dataset[ded@dataset$feature_id == "CE 18:1", ]
  expect_false(all(is.na(kept$feature_fwhm)))
  expect_false(all(is.na(kept$feature_width)))
})

test_that("data_sum_features keeps feature_id unique when merged transitions disagree", {
  # `mexp2` merges several PC transitions into one analyte and marks the "PC 4*"
  # ones as qualifiers, so the constituents disagree on `is_quantifier` -- the
  # normal quantifier/qualifier merge. A full-row `distinct()` kept every
  # disagreeing row, leaving a duplicated `feature_id` in the feature metadata
  # that fans out (or now aborts) the next join on it.
  for (action in c("include", "separate", "exclude")) {
    ded <- suppressWarnings(suppressMessages(
      data_sum_features(mexp2, qualifier_action = action)
    ))
    expect_equal(sum(ded@annot_features$feature_id == "PC"), 1L)
    expect_false(anyDuplicated(ded@annot_features$feature_id) > 0)
  }

  # Metadata the merge does not decide still comes from the first constituent.
  ded <- suppressWarnings(suppressMessages(
    data_sum_features(mexp2, qualifier_action = "include")
  ))
  first <- mexp2@annot_features |>
    dplyr::filter(!is.na(.data$analyte_id), .data$analyte_id == "PC") |>
    head(1)
  merged <- ded@annot_features |> dplyr::filter(.data$feature_id == "PC")
  expect_equal(merged$istd_feature_id, first$istd_feature_id)
})

test_that("a merged analyte quantifies if any constituent does", {
  # quant + qual and quant + quant give a quantifier; qual + qual stays a
  # qualifier. `is_quantifier` is decided by the merge, so it must not depend on
  # the constituents' row order, and the feature metadata must agree with the
  # dataset.
  merge_two <- function(q1, q2) {
    m <- mexp_orig
    af <- m@annot_features
    f <- head(af$feature_id[!af$is_istd & !af$feature_id %in% af$istd_feature_id], 2)
    m@annot_features$analyte_id[m@annot_features$feature_id %in% f] <- "M"
    m@annot_features$is_quantifier[m@annot_features$feature_id %in% f] <- c(q1, q2)
    m@dataset$analyte_id[m@dataset$feature_id %in% f] <- "M"
    m@dataset$is_quantifier[m@dataset$feature_id == f[1]] <- q1
    m@dataset$is_quantifier[m@dataset$feature_id == f[2]] <- q2
    suppressWarnings(suppressMessages(
      data_sum_features(m, qualifier_action = "include")
    ))
  }
  quantifier_of <- function(ded) {
    annot <- ded@annot_features$is_quantifier[ded@annot_features$feature_id == "M"]
    ds <- unique(ded@dataset$is_quantifier[ded@dataset$feature_id == "M"])
    expect_equal(annot, ds) # the two tables must not disagree
    annot
  }

  expect_false(quantifier_of(merge_two(FALSE, FALSE))) # qual  + qual  = qual
  expect_true(quantifier_of(merge_two(TRUE, TRUE))) # quant + quant = quant
  expect_true(quantifier_of(merge_two(TRUE, FALSE))) # quant + qual  = quant
  expect_true(quantifier_of(merge_two(FALSE, TRUE))) # ... and order-independent
})

test_that("data_sum_features invalidates values derived from the pre-merge intensities", {
  norm <- suppressMessages(normalize_by_istd(mexp))
  expect_true("feature_norm_intensity" %in% names(norm@dataset))
  expect_true(norm@is_istd_normalized)

  expect_message(
    ded <- data_sum_features(norm, qualifier_action = "include"),
    "no longer valid"
  )

  # the derived column is removed, not left as a silent all-NA on merged analytes
  expect_false("feature_norm_intensity" %in% names(ded@dataset))
  expect_false(ded@is_istd_normalized)
  expect_false(ded@is_filtered)
  expect_equal(nrow(ded@metrics_qc), 0L)
  expect_false(any(ded@var_drift_corrected))
  expect_false(any(ded@var_batch_corrected))
})

test_that("data_sum_features removes correction snapshots of the merged variables", {
  norm <- suppressMessages(normalize_by_istd(mexp))
  drift <- suppressWarnings(suppressMessages(correct_drift_gaussiankernel(
    norm,
    variable = "feature_norm_intensity",
    ref_qc_types = "BQC"
  )))
  expect_true(any(grepl("^feature_norm_intensity_", names(drift@dataset))))

  ded <- suppressMessages(data_sum_features(drift, qualifier_action = "include"))

  # no stale `_before` / `_fit` / `_raw` columns survive the merge as all-NA
  expect_false(any(grepl(
    "^feature_(intensity|norm_intensity|conc)_",
    names(ded@dataset)
  )))
  expect_false(any(ded@var_drift_corrected))
})

test_that("data_sum_features warns when merged transitions disagree on feature metadata", {
  mexp_conflict <- mexp
  mexp_conflict@annot_features$istd_feature_id[
    mexp_conflict@annot_features$feature_id == "LPC 18:1 (b)"
  ] <- "CE 18:1 d7 (ISTD)"

  expect_warning(
    suppressMessages(data_sum_features(mexp_conflict, qualifier_action = "include")),
    "differing feature metadata"
  )
})

test_that("data_sum_features stays silent when merged transitions agree on feature metadata", {
  expect_no_warning(suppressMessages(data_sum_features(
    mexp,
    qualifier_action = "include"
  )))
})

test_that("data_sum_features returns NA (not a fabricated 0) when all merged transitions are missing", {
  mexp_na <- mexp
  an <- mexp_na@dataset$analysis_id[1]
  msk <- mexp_na@dataset$analysis_id == an &
    stringr::str_detect(mexp_na@dataset$feature_id, "LPC 18:1 \\((a|b)\\)")
  expect_gt(sum(msk), 1) # both (a) and (b) present -> real aggregation happens

  mexp_na@dataset$feature_intensity[msk] <- NA_real_

  ded <- data_sum_features(mexp_na, qualifier_action = "include")
  v <- ded@dataset$feature_intensity[
    ded@dataset$analysis_id == an & ded@dataset$feature_id == "LPC 18:1"
  ]
  expect_length(v, 1)
  expect_true(is.na(v))
})