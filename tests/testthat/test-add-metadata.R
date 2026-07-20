# Direct unit tests for add_metadata(), the metadata-join primitive.
# add_metadata() runs *after* assert_metadata() has validated the metadata list,
# so these tests cover the transfer/derive contract (slot population, is_istd
# derivation, skipping of unprovided tables, batch/order derivation, status
# flag), not the upstream validation that lives in assert_metadata().

test_that("add_metadata() transfers all provided annotation tables into the matching slots", {
  data(lipidomics_dataset, package = "mrmhub")
  full <- lipidomics_dataset

  # Bare, freshly-imported object carrying only the raw data
  bare <- mrmhub::MRMhubExperiment()
  bare@dataset_orig <- full@dataset_orig
  expect_equal(nrow(bare@annot_analyses), 0)
  expect_equal(nrow(bare@annot_features), 0)

  metadata <- list(
    annot_analyses = full@annot_analyses,
    annot_features = full@annot_features,
    annot_istds = full@annot_istds,
    annot_responsecurves = full@annot_responsecurves
  )

  out <- add_metadata(
    bare,
    metadata = metadata,
    excl_unmatched_analyses = FALSE
  )

  expect_equal(dim(out@annot_analyses), c(499, 13))
  expect_equal(dim(out@annot_features), c(29, 17))
  expect_equal(dim(out@annot_istds), c(9, 5))
  expect_equal(dim(out@annot_responsecurves), c(12, 5))
  expect_equal(
    out@status_processing,
    "Raw and metadata imported and associated"
  )
})

test_that("add_metadata() derives is_istd from istd_feature_id, positioned after feature_class", {
  data(lipidomics_dataset, package = "mrmhub")
  full <- lipidomics_dataset

  bare <- mrmhub::MRMhubExperiment()
  bare@dataset_orig <- full@dataset_orig

  # Drop the derived column so we test that add_metadata() re-creates it
  metadata <- list(
    annot_analyses = full@annot_analyses,
    annot_features = dplyr::select(full@annot_features, -"is_istd")
  )

  out <- add_metadata(bare, metadata = metadata)

  expect_true("is_istd" %in% names(out@annot_features))
  expect_type(out@annot_features$is_istd, "logical")
  expect_equal(sum(out@annot_features$is_istd), 9L)
  expect_equal(
    which(names(out@annot_features) == "is_istd"),
    which(names(out@annot_features) == "feature_class") + 1L
  )
})

test_that("add_metadata() derives batch and analysis-order metadata from the analysis table", {
  data(lipidomics_dataset, package = "mrmhub")
  full <- lipidomics_dataset

  bare <- mrmhub::MRMhubExperiment()
  bare@dataset_orig <- full@dataset_orig

  out <- add_metadata(
    bare,
    metadata = list(annot_analyses = full@annot_analyses)
  )

  expect_equal(dim(out@annot_batches), c(6, 4))
  expect_true(all(
    out@annot_batches$id_batch_start <= out@annot_batches$id_batch_end
  ))
})

test_that("add_metadata() leaves unprovided annotation slots at their empty template", {
  data(lipidomics_dataset, package = "mrmhub")
  full <- lipidomics_dataset

  bare <- mrmhub::MRMhubExperiment()
  bare@dataset_orig <- full@dataset_orig

  # Only analysis metadata supplied
  out <- add_metadata(
    bare,
    metadata = list(annot_analyses = full@annot_analyses)
  )

  expect_equal(nrow(out@annot_analyses), 499)
  expect_equal(nrow(out@annot_features), 0)
  expect_equal(nrow(out@annot_istds), 0)
  expect_equal(nrow(out@annot_responsecurves), 0)
  expect_equal(nrow(out@annot_qcconcentrations), 0)
  expect_equal(
    out@status_processing,
    "Raw and metadata imported and associated"
  )
})

test_that("add_metadata() rejects a NULL data argument", {
  data(lipidomics_dataset, package = "mrmhub")
  expect_error(
    add_metadata(
      NULL,
      metadata = list(annot_analyses = lipidomics_dataset@annot_analyses)
    ),
    "cannot be"
  )
})

test_that("add_metadata() rejects metadata that is not an annotation-table bundle", {
  bare <- mrmhub::MRMhubExperiment()
  bare@dataset_orig <- lipidomics_dataset@dataset_orig

  expect_error(
    add_metadata(bare, metadata = data.frame(x = 1)),
    "list of annotation tables"
  )
  expect_error(
    add_metadata(bare, metadata = list(foo = 1, bar = 2)),
    "does not contain any annotation tables"
  )
})
