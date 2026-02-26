devtools::load_all("/Users/lsibjb/Documents/Code/MRMhub/quant", quiet = TRUE)

library(dplyr)

# Build mexp the same way as in tests
mexp <- lipidomics_dataset
mexp <- normalize_by_istd(mexp)
mexp <- calc_qc_metrics(mexp)

# Inject very long feature_id names into a copy
mexp_long <- mexp
long_ids <- c(
  "Ceramide d18:1/16:0 long name feature label",
  "Phosphatidylcholine PC 34:1 with extra long annotation text",
  "Lysophosphatidylethanolamine LPE 18:2 very long descriptor label"
)
orig_ids <- unique(mexp_long@dataset$feature_id)[1:3]
names(long_ids) <- orig_ids
mexp_long@dataset <- mexp_long@dataset |>
  mutate(
    feature_id = dplyr::case_match(
      .data$feature_id,
      names(long_ids)[1] ~ long_ids[1],
      names(long_ids)[2] ~ long_ids[2],
      names(long_ids)[3] ~ long_ids[3],
      .default = .data$feature_id
    )
  )

# --- Test 1: split_by_curve = TRUE, label_wrap = TRUE, fixed_scale_curves = FALSE ---
p1 <- plot_responsecurves(
  data = mexp_long,
  variable = "intensity",
  rows_page = 3,
  split_by_curve = TRUE,
  fixed_scale_curves = FALSE,
  specific_page = 1,
  return_plots = TRUE,
  show_progress = FALSE,
  label_wrap = TRUE,
  label_wrap_width = 25
)
print(p1[[1]])

# --- Test 2: split_by_curve = TRUE, label_wrap = TRUE, fixed_scale_curves = TRUE ---
p2 <- plot_responsecurves(
  data = mexp_long,
  variable = "intensity",
  rows_page = 3,
  split_by_curve = TRUE,
  fixed_scale_curves = TRUE,
  specific_page = 1,
  return_plots = TRUE,
  show_progress = FALSE,
  label_wrap = TRUE,
  label_wrap_width = 25
)
print(p2[[1]])

# --- Test 3: split_by_curve = FALSE, label_wrap = TRUE (facet_wrap2 mode) ---
p3 <- plot_responsecurves(
  data = mexp_long,
  variable = "intensity",
  rows_page = 3,
  cols_page = 2,
  split_by_curve = FALSE,
  specific_page = 1,
  return_plots = TRUE,
  show_progress = FALSE,
  label_wrap = TRUE,
  label_wrap_width = 25
)
print(p3[[1]])

# --- Test 4: label_wrap = FALSE (no wrapping) ---
p4 <- plot_responsecurves(
  data = mexp_long,
  variable = "intensity",
  rows_page = 3,
  split_by_curve = TRUE,
  specific_page = 1,
  return_plots = TRUE,
  show_progress = FALSE,
  label_wrap = FALSE
)
print(p4[[1]])
