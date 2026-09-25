library(ggplot2)

mexp_orig <- lipidomics_dataset
mexp_orig <- normalize_by_istd(mexp_orig)
mexp_orig <- calc_qc_metrics(mexp_orig)

mexp <- mexp_orig
mexp@annot_features[
  str_detect(mexp@annot_features$feature_id, "LPC 18:1 \\((a|b)\\)"),
]$analyte_id <- "LPC 18:1"

mexp <- mrmhub:::link_data_metadata(mexp)

test_that("Default plot_matrixeffects looks as expected", {
  mexp_dedup <- data_sum_features(mexp)
  expect_true("LPC 18:1" %in% mexp_dedup@annot_features$feature_id)
  expect_false("LPC 18:1 (a)" %in% mexp_dedup@annot_features$feature_id)
  expect_false("LPC 18:1 (b)" %in% mexp_dedup@annot_features$feature_id)
  expect_true(
    "LPC 18:1 (ab) d7 (ISTD)" %in% mexp_dedup@annot_features$feature_id
  )
  expect_true("LPC 18:1" %in% unique(mexp_dedup@dataset$feature_id))
  expect_false("LPC 18:1 (a)" %in% unique(mexp_dedup@dataset$feature_id))
  expect_false("LPC 18:1 (ab)" %in% unique(mexp_dedup@dataset$feature_id))
})

mexp2 <- mexp_orig
mexp2@annot_features[
  str_detect(mexp2@annot_features$feature_id, "^PC") &
    !mexp2@annot_features$is_istd,
]$analyte_id <- "PC"
mexp2@annot_features[
  str_detect(mexp2@annot_features$feature_id, "^PC 4"),
]$is_quantifier <- FALSE
# summed transitions must agree on their interference
mexp2@annot_features$interference_feature_id <- NA_character_
mexp2@annot_features$interference_contribution <- NA_real_
mexp2 <- mrmhub:::link_data_metadata(mexp2)

test_that("Default plot_matrixeffects looks as expected", {
  mexp2_dedup <- data_sum_features(mexp2, qualifier_action = "separate")
  expect_true("PC" %in% unique(mexp2_dedup@dataset$feature_id))
  expect_false("PC 40:6" %in% unique(mexp2_dedup@dataset$feature_id))
  expect_false("PC 32:1" %in% unique(mexp2_dedup@dataset$feature_id))

  sum_pc <- sum(
    mexp2_dedup@dataset[
      mexp2_dedup@dataset$feature_id == "PC",
    ]$feature_intensity
  )
  expect_equal(sum_pc, 1017024332.8)
  sum_pc <- sum(
    mexp2_dedup@dataset[
      mexp2_dedup@dataset$feature_id == "PC_qual",
    ]$feature_intensity
  )
  expect_equal(sum_pc, 1715685212.3)

  mexp2_dedup <- data_sum_features(mexp2, qualifier_action = "include")
  expect_true("PC" %in% unique(mexp2_dedup@dataset$feature_id))
  expect_false("PC 40:6" %in% unique(mexp2_dedup@dataset$feature_id))
  expect_false("PC 32:1" %in% unique(mexp2_dedup@dataset$feature_id))

  sum_pc <- sum(
    mexp2_dedup@dataset[
      mexp2_dedup@dataset$feature_id == "PC",
    ]$feature_intensity
  )
  expect_equal(sum_pc, 2732709545.1)

  mexp2_dedup <- data_sum_features(mexp2, qualifier_action = "exclude")
  expect_true("PC" %in% unique(mexp2_dedup@dataset$feature_id))
  # qualifiers are not summed and stay as they are
  expect_true("PC 40:6" %in% unique(mexp2_dedup@dataset$feature_id))
  expect_false("PC 32:1" %in% unique(mexp2_dedup@dataset$feature_id))

  sum_pc <- sum(
    mexp2_dedup@dataset[
      mexp2_dedup@dataset$feature_id == "PC",
    ]$feature_intensity
  )
  expect_equal(sum_pc, 1017024332.8)
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
  expect_equal(
    merged$feature_area,
    sum(constituents$feature_area, na.rm = TRUE)
  )
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
    f <- c("Cer d18:1/16:0", "Cer d18:1/24:0") # same ISTD
    m@annot_features$analyte_id[m@annot_features$feature_id %in% f] <- "M"
    m@annot_features$is_quantifier[m@annot_features$feature_id %in% f] <- c(
      q1,
      q2
    )
    m@dataset$analyte_id[m@dataset$feature_id %in% f] <- "M"
    m@dataset$is_quantifier[m@dataset$feature_id == f[1]] <- q1
    m@dataset$is_quantifier[m@dataset$feature_id == f[2]] <- q2
    suppressWarnings(suppressMessages(
      data_sum_features(m, qualifier_action = "include")
    ))
  }
  quantifier_of <- function(ded) {
    annot <- ded@annot_features$is_quantifier[
      ded@annot_features$feature_id == "M"
    ]
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

  ded <- suppressMessages(data_sum_features(
    drift,
    qualifier_action = "include"
  ))

  # no stale `_before` / `_fit` / `_raw` columns survive the merge as all-NA
  expect_false(any(grepl(
    "^feature_(intensity|norm_intensity|conc)_",
    names(ded@dataset)
  )))
  expect_false(any(ded@var_drift_corrected))
})

test_that("data_sum_features warns when merged transitions disagree on feature metadata", {
  mexp_conflict <- mexp
  mexp_conflict@annot_features$feature_label[
    mexp_conflict@annot_features$feature_id == "LPC 18:1 (b)"
  ] <- "other label"

  expect_warning(
    suppressMessages(data_sum_features(
      mexp_conflict,
      qualifier_action = "include"
    )),
    "differing feature metadata"
  )
})

test_that("data_sum_features aborts when merged transitions use different ISTDs", {
  mexp_conflict <- mexp
  mexp_conflict@annot_features$istd_feature_id[
    mexp_conflict@annot_features$feature_id == "LPC 18:1 (b)"
  ] <- "CE 18:1 d7 (ISTD)"
  expect_error(
    data_sum_features(mexp_conflict, qualifier_action = "include"),
    "LPC 18:1"
  )
})

test_that("data_sum_features aborts when an ISTD is merged with analytes", {
  mexp_istd <- mexp_orig
  pc <- str_detect(mexp_istd@annot_features$feature_id, "^PC (32|33)")
  mexp_istd@annot_features$analyte_id[pc] <- "PC"
  mexp_istd <- mrmhub:::link_data_metadata(mexp_istd)
  expect_error(
    data_sum_features(mexp_istd, qualifier_action = "include"),
    "internal standard"
  )
})

# The dataset and the feature metadata must list the same features after summing
expect_consistent_ids <- function(ded) {
  expect_setequal(
    unique(ded@dataset$feature_id),
    ded@annot_features$feature_id[
      ded@annot_features$feature_id %in%
        unique(ded@dataset$feature_id) |
        !ded@annot_features$feature_id %in% ded@dataset_orig$feature_id
    ]
  )
  expect_true(all(
    unique(ded@dataset$feature_id) %in% ded@annot_features$feature_id
  ))
}

test_that("data_sum_features keeps dataset and feature metadata consistent in every mode", {
  for (action in c("include", "separate", "exclude")) {
    ded <- suppressWarnings(suppressMessages(
      data_sum_features(mexp2, qualifier_action = action)
    ))
    expect_consistent_ids(ded)
  }
  ded <- suppressMessages(data_sum_features(
    mexp2,
    qualifier_action = "separate"
  ))
  expect_true("PC_qual" %in% ded@annot_features$feature_id)
  expect_false(anyNA(ded@dataset$feature_class[
    ded@dataset$feature_id == "PC_qual"
  ]))
})

test_that("a quantifier-qualifier pair is left unmerged in separate and exclude mode", {
  mexp_pe <- mexp_orig
  pe <- str_detect(mexp_pe@annot_features$feature_id, "^PE P-16:0/18:1")
  mexp_pe@annot_features$analyte_id[pe] <- "PE P-16:0/18:1"
  mexp_pe <- mrmhub:::link_data_metadata(mexp_pe)
  ids <- mexp_pe@annot_features$feature_id[pe]
  for (action in c("separate", "exclude")) {
    ded <- suppressMessages(data_sum_features(
      mexp_pe,
      qualifier_action = action
    ))
    expect_true(all(ids %in% unique(ded@dataset$feature_id)))
    expect_true(all(ids %in% ded@annot_features$feature_id))
  }
  ded <- suppressMessages(data_sum_features(
    mexp_pe,
    qualifier_action = "include"
  ))
  expect_true("PE P-16:0/18:1" %in% unique(ded@dataset$feature_id))
  expect_consistent_ids(ded)
})

test_that("a sum with a missing constituent is NA and reported", {
  mexp_part <- mexp
  an <- mexp_part@dataset$analysis_id[1]
  mexp_part@dataset <- mexp_part@dataset |>
    dplyr::filter(
      !(.data$analysis_id == an & .data$feature_id == "LPC 18:1 (b)")
    )
  expect_warning(
    ded <- suppressMessages(data_sum_features(mexp_part)),
    "missing constituent"
  )
  v <- ded@dataset$feature_intensity[
    ded@dataset$analysis_id == an & ded@dataset$feature_id == "LPC 18:1"
  ]
  expect_length(v, 1)
  expect_true(is.na(v))
  expect_false("LPC 18:1 (a)" %in% ded@dataset$feature_id)
})

test_that("an empty analyte_id is treated as missing", {
  mexp_empty <- mexp_orig
  sm <- str_detect(mexp_empty@annot_features$feature_id, "^SM 3[24]:1")
  mexp_empty@annot_features$analyte_id[sm] <- ""
  mexp_empty <- mrmhub:::link_data_metadata(mexp_empty)
  ded <- suppressMessages(data_sum_features(mexp_empty))
  expect_true(all(c("SM 32:1", "SM 34:1") %in% ded@dataset$feature_id))
  expect_false("" %in% ded@dataset$feature_id)
})

test_that("summing ISTD transitions remaps the references to them", {
  mexp_tg <- mexp_orig
  tg <- mexp_tg@annot_features$feature_id %in%
    c("TG 48:1 d7 (ISTD) [-15:0]", "TG 48:1 d7 (ISTD) [SIM]")
  mexp_tg@annot_features$analyte_id[tg] <- "TG 48:1 d7 (ISTD)"
  mexp_tg <- mrmhub:::link_data_metadata(mexp_tg)
  ded <- suppressMessages(data_sum_features(mexp_tg))

  af <- ded@annot_features
  expect_false(any(
    c(af$istd_feature_id, af$quant_istd_feature_id) %in%
      c("TG 48:1 d7 (ISTD) [-15:0]", "TG 48:1 d7 (ISTD) [SIM]")
  ))
  expect_equal(
    sum(ded@annot_istds$quant_istd_feature_id == "TG 48:1 d7 (ISTD)"),
    1
  )
  expect_no_error(suppressMessages(normalize_by_istd(ded)))
})

test_that("relinking after data_sum_features aborts instead of dropping analytes", {
  ded <- suppressMessages(data_sum_features(mexp))
  expect_error(
    exclude_analyses(ded, ded@dataset$analysis_id[1], clear_existing = TRUE),
    "data_sum_features"
  )
})

test_that("feature metadata listing features absent from the data still links", {
  mexp_panel <- mexp_orig
  mexp_panel@annot_features <- dplyr::bind_rows(
    mexp_panel@annot_features,
    mexp_panel@annot_features[1, ] |> dplyr::mutate(feature_id = "not measured")
  )
  expect_no_error(mrmhub:::link_data_metadata(mexp_panel))
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

test_that("data_sum_features() rejects a non-MRMhubExperiment first arg", {
  expect_error(data_sum_features(data.frame(x = 1)), "MRMhubExperiment")
})

test_that("data_sum_features clears calibration metrics", {
  # Transitions are merged into analytes, so the per-feature fits are orphaned.
  mexp_cal <- calibrated_experiment()
  expect_gt(nrow(mexp_cal@metrics_calibration), 0)

  res <- suppressMessages(suppressWarnings(data_sum_features(mexp_cal)))
  expect_equal(nrow(res@metrics_calibration), 0)
})

test_that("an excluded or unmeasured transition does not void the sum", {
  mexp_ex <- suppressMessages(exclude_features(
    mexp,
    "LPC 18:1 (b)",
    clear_existing = TRUE
  ))
  ded <- suppressMessages(data_sum_features(mexp_ex))
  v <- ded@dataset$feature_intensity[ded@dataset$feature_id == "LPC 18:1 (a)"]
  expect_gt(sum(!is.na(v)), 0)
  expect_false("LPC 18:1" %in% ded@dataset$feature_id)

  mexp_panel <- mexp
  mexp_panel@annot_features <- dplyr::bind_rows(
    mexp_panel@annot_features,
    mexp_panel@annot_features |>
      dplyr::filter(.data$feature_id == "LPC 18:1 (a)") |>
      dplyr::mutate(feature_id = "LPC 18:1 (c)")
  )
  ded <- suppressMessages(data_sum_features(mexp_panel))
  v <- ded@dataset$feature_intensity[ded@dataset$feature_id == "LPC 18:1"]
  expect_gt(sum(!is.na(v)), 0)
})

test_that("a summed id that equals another feature_id aborts", {
  mexp_clash <- mexp_orig
  sm <- mexp_clash@annot_features$feature_id %in% c("SM 32:1", "PC 32:1")
  mexp_clash@annot_features$analyte_id[sm] <- "PE 34:1"
  mexp_clash@annot_features$istd_feature_id[sm] <- "PC 33:1 d7 (ISTD)"
  mexp_clash@annot_features$quant_istd_feature_id[sm] <- "PC 33:1 d7 (ISTD)"
  mexp_clash <- mrmhub:::link_data_metadata(mexp_clash)
  expect_error(data_sum_features(mexp_clash), "PE 34:1")
})

test_that("interference references in the feature metadata follow summed ids", {
  mexp_int <- mexp
  af <- mexp_int@annot_features
  af$interference_feature_id[af$feature_id == "PC 32:1"] <- "LPC 18:1 (a)"
  af$interference_contribution[af$feature_id == "PC 32:1"] <- 0.1
  mexp_int@annot_features <- af
  mexp_int <- mrmhub:::link_data_metadata(mexp_int)
  ded <- suppressMessages(data_sum_features(mexp_int))
  ref <- ded@annot_features$interference_feature_id[
    ded@annot_features$feature_id == "PC 32:1"
  ]
  expect_equal(ref, "LPC 18:1")
})

test_that("merged analytes get NA peak borders", {
  mexp_b <- mexp
  mexp_b@dataset$feature_int_start <- mexp_b@dataset$feature_rt - 0.1
  mexp_b@dataset$feature_int_end <- mexp_b@dataset$feature_rt + 0.1
  ded <- suppressMessages(data_sum_features(mexp_b))
  merged <- ded@dataset[ded@dataset$feature_id == "LPC 18:1", ]
  expect_true(all(is.na(merged$feature_int_start)))
  expect_true(all(is.na(merged$feature_int_end)))
  kept <- ded@dataset[ded@dataset$feature_id == "CE 18:1", ]
  expect_false(anyNA(kept$feature_int_start))
})

test_that("an interference within a summed feature is removed from the feature metadata", {
  mexp_int <- mexp
  af <- mexp_int@annot_features
  af$interference_feature_id[af$feature_id == "LPC 18:1 (a)"] <- "LPC 18:1 (b)"
  af$interference_contribution[af$feature_id == "LPC 18:1 (a)"] <- 0.1
  mexp_int@annot_features <- af
  mexp_int <- mrmhub:::link_data_metadata(mexp_int)
  expect_warning(
    ded <- suppressMessages(data_sum_features(mexp_int)),
    "LPC 18:1"
  )
  row <- ded@annot_features[ded@annot_features$feature_id == "LPC 18:1", ]
  expect_true(is.na(row$interference_feature_id))
  expect_true(is.na(row$interference_contribution))
})

test_that("summing ISTDs with different concentrations names them", {
  mexp_tg <- mexp_orig
  tg <- mexp_tg@annot_features$feature_id %in%
    c("TG 48:1 d7 (ISTD) [-15:0]", "TG 48:1 d7 (ISTD) [SIM]")
  mexp_tg@annot_features$analyte_id[tg] <- "TG 48:1 d7 (ISTD)"
  sim <- mexp_tg@annot_istds$quant_istd_feature_id == "TG 48:1 d7 (ISTD) [SIM]"
  mexp_tg@annot_istds$istd_conc_nmolar[sim] <- 99
  mexp_tg <- mrmhub:::link_data_metadata(mexp_tg)
  err <- expect_error(data_sum_features(mexp_tg), "TG 48:1 d7 \\(ISTD\\)")
  expect_equal(rlang::call_name(err$call), "data_sum_features")
})

test_that("data_sum_features errors name the user-facing function", {
  mexp_clash <- mexp_orig
  sm <- mexp_clash@annot_features$feature_id %in% c("SM 32:1", "PC 32:1")
  mexp_clash@annot_features$analyte_id[sm] <- "PE 34:1"
  mexp_clash <- mrmhub:::link_data_metadata(mexp_clash)
  err <- expect_error(data_sum_features(mexp_clash))
  expect_equal(rlang::call_name(err$call), "data_sum_features")

  ded <- suppressMessages(data_sum_features(mexp))
  err <- expect_error(
    exclude_analyses(ded, ded@dataset$analysis_id[1], clear_existing = TRUE),
    "would drop"
  )
  expect_equal(rlang::call_name(err$call), "exclude_analyses")
})
