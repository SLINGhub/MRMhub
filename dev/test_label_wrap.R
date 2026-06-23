devtools::load_all(quiet = TRUE)

library(dplyr)

# Build mexp
mexp <- lipidomics_dataset
mexp <- normalize_by_istd(mexp)
mexp <- calc_qc_metrics(mexp)

# Inject very long feature_id names into a copy
long_ids <- c(
  "Ceramide d18:1/16:0 long name feature label",
  "Phosphatidylcholine PC 34:1 with extra long annotation text",
  "Lysophosphatidylethanolamine LPE 18:2 very long descriptor label"
)
orig_ids <- unique(mexp@dataset$feature_id)[1:3]
names(long_ids) <- orig_ids

mexp_long <- mexp
mexp_long@dataset <- mexp_long@dataset |>
  mutate(
    feature_id = case_when(
      .data$feature_id == orig_ids[1] ~ long_ids[1],
      .data$feature_id == orig_ids[2] ~ long_ids[2],
      .data$feature_id == orig_ids[3] ~ long_ids[3],
      .default = .data$feature_id
    )
  )

# ── plot_responsecurves examples ───────────────────────────────────────────────

# Test 1: curve_layout = "overlay", label_wrap = TRUE
p1 <- plot_responsecurves(
  data = mexp_long,
  variable = "intensity",
  rows_page = 3,
  cols_page = 3,
  curve_layout = "overlay",
  specific_page = 1,
  return_plots = TRUE,
  show_progress = FALSE,
  label_wrap = TRUE,
  label_wrap_width = 25
)
print(p1[[1]])

# Test 2: curve_layout = "cols", label_wrap = TRUE
p2 <- plot_responsecurves(
  data = mexp_long,
  variable = "intensity",
  rows_page = 3,
  cols_page = 3,
  curve_layout = "cols",
  specific_page = 1,
  return_plots = TRUE,
  show_progress = FALSE,
  label_wrap = TRUE,
  label_wrap_width = 25
)
print(p2[[1]])

# Test 3: label_wrap = FALSE (default, no wrapping)
p3 <- plot_responsecurves(
  data = mexp_long,
  variable = "intensity",
  rows_page = 3,
  cols_page = 3,
  curve_layout = "overlay",
  specific_page = 1,
  return_plots = TRUE,
  show_progress = FALSE,
  label_wrap = FALSE
)
print(p3[[1]])

# ── plot_runscatter examples ───────────────────────────────────────────────────

# Test 4: label_wrap = TRUE, width = 20 (tight — forces 2-3 lines)
p4 <- plot_runscatter(
  data = mexp_long,
  variable = "intensity",
  rows_page = 3,
  cols_page = 4,
  specific_page = 1,
  return_plots = TRUE,
  label_wrap = TRUE,
  label_wrap_width = 20
)
print(p4[[1]])

# Test 5: label_wrap = TRUE, width = 30 (looser — fewer line breaks)
p5 <- plot_runscatter(
  data = mexp_long,
  variable = "intensity",
  rows_page = 3,
  cols_page = 4,
  specific_page = 1,
  return_plots = TRUE,
  label_wrap = TRUE,
  label_wrap_width = 30
)
print(p5[[1]])

# Test 6: label_wrap = FALSE (default — labels overflow strips)
p6 <- plot_runscatter(
  data = mexp_long,
  variable = "intensity",
  rows_page = 3,
  cols_page = 4,
  specific_page = 1,
  return_plots = TRUE,
  label_wrap = FALSE
)
print(p6[[1]])
