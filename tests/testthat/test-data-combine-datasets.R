test_that("combine_experiments keeps the summed-features flag", {
  mexp_sum <- lipidomics_dataset
  lpc <- grepl("LPC 18:1 \\((a|b)\\)", mexp_sum@annot_features$feature_id)
  mexp_sum@annot_features$analyte_id[lpc] <- "LPC 18:1"
  mexp_sum <- mrmhub:::link_data_metadata(mexp_sum)
  mexp_sum <- suppressMessages(data_sum_features(mexp_sum))
  comb <- mrmhub:::combine_experiments(list(lipidomics_dataset, mexp_sum))
  expect_true(isTRUE(attr(comb@dataset_orig, "summed_features")))
})
