# Minimal MS1-style experiment: one feature per precursor species (no
# transitions), same class, precursors ~2 Da apart -> a double-bond series.
ms1_experiment <- function() {
  mexp <- MRMhubExperiment()
  mexp@dataset_orig <- dplyr::tibble(
    analysis_id = "a1",
    raw_data_filename = "f1",
    acquisition_time_stamp = as.Date("2024-01-01"),
    feature_id = c("PC 34:2", "PC 34:1", "PC 34:0"),
    method_precursor_mz = c("758.57", "760.59", "762.60")
  )
  mexp@annot_features <- dplyr::tibble(
    feature_id = c("PC 34:2", "PC 34:1", "PC 34:0"),
    feature_class = "PC",
    chem_formula = c("C42H80NO8P", "C42H82NO8P", "C42H84NO8P"),
    is_istd = FALSE
  )
  mexp
}

test_that("calc_isotopic_interferences(MS1) pairs same-class species ~2 Da apart", {
  res <- suppressMessages(calc_isotopic_interferences(
    ms1_experiment(),
    level = "MS1"
  ))
  e <- res@annot_interferences

  expect_equal(nrow(e), 2)
  expect_setequal(e$feature_id, c("PC 34:1", "PC 34:0"))
  # The lighter (more-unsaturated) species interferes with the ~2 Da heavier one.
  expect_equal(e$interference_feature_id[e$feature_id == "PC 34:1"], "PC 34:2")
  expect_equal(e$interference_feature_id[e$feature_id == "PC 34:0"], "PC 34:1")
  expect_true(all(e$overlap_type == "ms1_m2"))
  expect_true(all(e$source == "auto"))
})

test_that("calc_isotopic_interferences(MS1) contribution is the interferer's M+2 abundance", {
  skip_if_not_installed("enviPat")
  res <- suppressMessages(calc_isotopic_interferences(
    ms1_experiment(),
    level = "MS1"
  ))
  e <- res@annot_interferences

  expect_equal(
    e$interference_contribution[e$feature_id == "PC 34:1"],
    mN_rel_abundance("C42H80NO8P", 2L),
    tolerance = 1e-6
  )
  expect_equal(
    e$interference_contribution[e$feature_id == "PC 34:0"],
    mN_rel_abundance("C42H82NO8P", 2L),
    tolerance = 1e-6
  )
})

test_that("calc_isotopic_interferences(MS1) preserves manual edges, replaces auto", {
  mexp <- ms1_experiment()
  mexp@annot_interferences <- dplyr::tibble(
    feature_id = "PC 34:1",
    interference_feature_id = "SM 34:1",
    interference_contribution = 0.01,
    overlap_type = "manual",
    source = "manual"
  )
  res <- suppressMessages(calc_isotopic_interferences(mexp, level = "MS1"))
  e <- res@annot_interferences

  expect_equal(sum(e$source == "manual"), 1)
  expect_true(any(e$source == "auto"))
  expect_true("SM 34:1" %in% e$interference_feature_id)
})

test_that("calc_isotopic_interferences(MS1) aborts without precursor m/z", {
  mexp <- ms1_experiment()
  mexp@dataset_orig <- dplyr::select(mexp@dataset_orig, -"method_precursor_mz")
  expect_error(
    suppressMessages(calc_isotopic_interferences(mexp, level = "MS1")),
    "precursor m/z"
  )
})

test_that("calc_isotopic_interferences MRM aborts without an mrm_pattern column", {
  expect_error(
    suppressMessages(calc_isotopic_interferences(
      ms1_experiment(),
      level = "MRM"
    )),
    "mrm_pattern"
  )
})


test_that("co-elution gate drops resolved pairs, keeps co-eluting ones", {
  mexp <- ms1_experiment()
  # Add retention data: 34:2 and 34:1 co-elute (rt 5.0); 34:0 is resolved (rt 8.0)
  mexp@dataset_orig$feature_rt <- c(5.0, 5.0, 8.0)[match(
    mexp@dataset_orig$feature_id,
    c("PC 34:2", "PC 34:1", "PC 34:0")
  )]
  mexp@dataset_orig$feature_int_start <- mexp@dataset_orig$feature_rt - 0.1
  mexp@dataset_orig$feature_int_end <- mexp@dataset_orig$feature_rt + 0.1

  on <- suppressMessages(calc_isotopic_interferences(
    mexp,
    level = "MS1",
    check_coelution = TRUE
  ))
  off <- suppressMessages(calc_isotopic_interferences(
    mexp,
    level = "MS1",
    check_coelution = FALSE
  ))

  # Without the gate: both edges (34:1<-34:2 co-eluting, 34:0<-34:1 resolved).
  expect_equal(nrow(off@annot_interferences), 2)
  # With the gate: the resolved 34:0<-34:1 edge (interferer apex 5.0 outside
  # victim window ~[7.9,8.1]) is dropped; the co-eluting one is kept.
  e <- on@annot_interferences
  expect_equal(nrow(e), 1)
  expect_equal(e$feature_id, "PC 34:1")
  expect_equal(e$interference_feature_id, "PC 34:2")
})


test_that("calc_isotopic_interferences(MS1) warns when product m/z differs from precursor (MRM data)", {
  mexp <- ms1_experiment()
  mexp@dataset_orig$method_product_mz <- c("184.1", "184.1", "184.1")
  expect_message(
    calc_isotopic_interferences(mexp, level = "MS1"),
    "differs from the precursor"
  )
})

test_that("calc_isotopic_interferences(MS1) does not warn for pseudo-MS1 (product == precursor)", {
  mexp <- ms1_experiment()
  mexp@dataset_orig$method_product_mz <- mexp@dataset_orig$method_precursor_mz
  msgs <- testthat::capture_messages(
    calc_isotopic_interferences(mexp, level = "MS1")
  )
  expect_false(any(grepl("differs from the precursor", msgs)))
})


test_that("MS1 derivation warns and names features missing a precursor m/z", {
  mexp <- ms1_experiment()
  mexp@dataset_orig$method_precursor_mz[
    mexp@dataset_orig$feature_id == "PC 34:1"
  ] <- NA
  expect_message(
    derive_isotopic_interferences(mexp, level = "MS1"),
    "No precursor m/z.*PC 34:1"
  )
})
