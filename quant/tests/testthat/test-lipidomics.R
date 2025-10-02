mexp <- mrmhub::MRMhubExperiment(title = "")

data_path <- test_path("testdata/FullPanelFewSamples_MRMkit_interror.csv")
mexp <- import_data_mrmhub(
  data = mexp,
  path = data_path,
  import_metadata = TRUE
)

test_that("parse_lipid_feature_names works", {
  mexp_temp <- mexp

  mexp_temp@dataset <- parse_lipid_feature_names(
    mexp_temp@dataset,
    use_as_feature_class = "lipid_class_lcb",
    add_transition_names = TRUE
  )
  expect_true(all(
    c(
      "analyte_name",
      "lipid_class",
      "lipid_class_lcb",
      "lipid_class_base",
      "transition_name",
      "transition_group_id"
    ) %in%
      colnames(mexp_temp@dataset)
  ))

  lipids <- mexp_temp@dataset |> filter(analysis_id == "Longit_batch1_22")

  expect_equal(lipids$analyte_name[44], "Cer 18:1;O2/22:0")
  expect_equal(lipids$analyte_name[70], "DG 16:0_18:0")
  expect_equal(lipids$analyte_name[155], "LPC 17:1/0:0")
  expect_equal(lipids$analyte_name[329], "PE P-16:0/20:4")
  expect_equal(lipids$analyte_name[440], "TG 15:0_34:1")
  expect_equal(lipids$analyte_name[436], "TG 48:2")
  expect_equal(lipids$lipid_class[44], "Cer")
  expect_equal(lipids$lipid_class_lcb[44], "Cer;O2")
  expect_equal(lipids$feature_class[44], "Cer;O2")
  expect_equal(lipids$lipid_class_base[44], "SP")
  expect_equal(lipids$transition_name[327], "-FA-HG")
  expect_equal(lipids$transition_group_id[323], 1)
  expect_equal(lipids$analyte_name[330], "PE P-16:0/20:4")
  expect_equal(lipids$transition_name[330], "-FA")
  expect_equal(lipids$transition_group_id[330], 2)

  mexp_temp@dataset <- parse_lipid_feature_names(
    mexp_temp@dataset,
    use_as_feature_class = "lipid_class",
    add_transition_names = FALSE,
    add_chain_composition = FALSE
  )
  expect_true(all(
    c("analyte_name", "lipid_class", "lipid_class_lcb", "lipid_class_base") %in%
      colnames(mexp_temp@dataset)
  ))
  expect_equal(mexp_temp@dataset$feature_class[44], "Cer")
  expect_false(any(
    c("transition_name", "transition_group_id") %in% colnames(mexp_temp@dataset)
  ))
})
