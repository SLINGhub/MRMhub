# Augments the committed metadata-template workbook with the two `mrm_pattern`
# input columns for isotopic interference correction. Run from the repo root:
#
#   Rscript data-raw/make_metadata_template.R
#
# It reads inst/extdata/mrmhub_metadata_templates.xlsx, adds two columns to the
# `Features` sheet -- an optional `polarity` filter and the stored `mrm_pattern`
# -- with a dependent dropdown (polarity narrows the pattern list), a hidden
# `lists` sheet holding the dropdown sources, and colour warnings; every other
# sheet is left untouched. It re-saves the file in place (the committed
# deliverable) and writes a throwaway copy at the repo root for eyeballing.
#
# Everything is derived from `licar_template_choices()` (the shared source of the
# labels), so the dropdowns can never drift from what the package accepts;
# test-metadata-template.R reads the committed file back and fails if they do --
# the signal to re-run this script.
#
# Uses openxlsx2 (build-time only). isotope-licar.R is not self-contained, so we
# load the package rather than sourcing a single file.

suppressPackageStartupMessages({
  library(openxlsx2)
  pkgload::load_all(".", quiet = TRUE)
})

TEMPLATE <- "inst/extdata/mrmhub_metadata_templates.xlsx"
N_VALIDATED_ROWS <- 500 # rows the dropdowns + colour warnings cover
last <- N_VALIDATED_ROWS + 1

# ---- Choices driven by the shared source ------------------------------------

tc <- licar_template_choices() # excludes RPLC + broken classes
polarities <- c("Pos", "Neg")

# Labels, optionally narrowed to a polarity. A label with no intrinsic polarity
# (NA, e.g. "LPC d9 ...") belongs to BOTH polarity sub-lists so it stays
# selectable whatever polarity the user picks.
labels_for <- function(polarity = NULL) {
  rows <- tc
  if (!is.null(polarity)) {
    rows <- rows[is.na(rows$polarity) | rows$polarity == polarity, ]
  }
  rows$label
}

# Expected species-name prefix per label, for the name/pattern class warning.
# Mirrors the `prefix_override` in validate_mrm_pattern().
prefix_override <- c(
  "LPC-O" = "LPC",
  "PE-P" = "PE",
  "PCO" = "PC",
  "PCP" = "PC",
  "PEO" = "PE",
  "PEP" = "PE",
  "S1Pql" = "S1P"
)
lead <- sub(" .*$", "", tc$label)
tc$name_prefix <- ifelse(
  lead %in% names(prefix_override),
  prefix_override[lead],
  lead
)

# ---- Load the workbook + locate the Features columns ------------------------

wb <- wb_load(TEMPLATE)

# The Features sheet is header-only, so the header names come back as the column
# names (0 data rows). Reading with an explicit over-wide range instead would
# materialise empty cells as the string "NA" and write phantom header columns.
hdr <- names(wb_to_df(wb, sheet = "Features", col_names = TRUE))
insert_at <- match("interference_feature_id", hdr)
if (is.na(insert_at)) {
  stop(
    "`interference_feature_id` not found on the Features header; layout changed."
  )
}
new_hdr <- append(hdr, c("polarity", "mrm_pattern"), after = insert_at - 1L)
ncol_new <- length(new_hdr)

# Column letters of the two new inputs and the feature-name column.
col_pol <- int2col(insert_at) # polarity
col_pat <- int2col(insert_at + 1L) # mrm_pattern
col_name <- int2col(match("feature_id", new_hdr)) # feature_id (== "A")

# Preserve the header look: required columns (feature_id, istd_feature_id) carry
# one style, optional columns another. Capture both before we overwrite the row.
style_req <- wb$get_cell_style(sheet = "Features", dims = "A1")[[1]]
style_opt <- wb$get_cell_style(sheet = "Features", dims = "C1")[[1]]

# ---- Rewrite the Features header row ----------------------------------------

wb$add_data(
  "Features",
  x = as.data.frame(as.list(new_hdr), stringsAsFactors = FALSE),
  start_col = 1,
  start_row = 1,
  col_names = FALSE
)
last_col <- int2col(ncol_new)
wb$set_cell_style("Features", dims = "A1:B1", style = style_req)
wb$set_cell_style(
  "Features",
  dims = paste0("C1:", last_col, "1"),
  style = style_opt
)
wb$set_col_widths(
  "Features",
  cols = c(insert_at, insert_at + 1L),
  widths = c(9, 26)
)

# Hover notes on the two new headers.
notes <- c(
  "polarity (optional): Pos or Neg. If set, it narrows the mrm_pattern choices. Leave blank to see all patterns.",
  "mrm_pattern: the class + MRM pattern for this feature, used by derive_interferences(). Pick from the dropdown; choices narrow with polarity if set. A name/pattern class mismatch is highlighted and warned about on import."
)
wb$add_comment(
  "Features",
  dims = paste0(col_pol, "1"),
  comment = wb_comment(text = notes[[1]], author = "mrmhub", visible = FALSE)
)
wb$add_comment(
  "Features",
  dims = paste0(col_pat, "1"),
  comment = wb_comment(text = notes[[2]], author = "mrmhub", visible = FALSE)
)

# ---- Hidden `lists` sheet: dropdown sources + label -> prefix map ------------

wb$add_worksheet("lists", visible = "hidden")

col <- 1
add_list <- function(name, values) {
  colL <- int2col(col)
  wb$add_data("lists", name, start_col = col, start_row = 1, col_names = FALSE)
  # An empty subset still needs a valid, non-reversed named range: anchor it on a
  # single blank cell -> an empty dropdown. (Both polarities are non-empty here,
  # but keep the guard so the generator is robust to future edits.)
  if (length(values) == 0) {
    wb$add_data("lists", "", start_col = col, start_row = 2, col_names = FALSE)
    wb$add_named_region(
      "lists",
      dims = paste0(colL, "2:", colL, "2"),
      name = name
    )
  } else {
    wb$add_data(
      "lists",
      values,
      start_col = col,
      start_row = 2,
      col_names = FALSE
    )
    wb$add_named_region(
      "lists",
      dims = paste0(colL, "2:", colL, 1 + length(values)),
      name = name
    )
  }
  col <<- col + 1
}

# The flat pattern list + one narrowed list per polarity. The dropdown formula
# INDIRECT("AllPatterns" & polarity) resolves to the full list when polarity is
# blank (concatenating nothing) and to the narrowed list when it is set -- how a
# blank polarity "ignores the filter".
add_list("AllPatterns", labels_for())
for (p in polarities) add_list(paste0("AllPatterns", p), labels_for(p))
add_list("polarities", polarities)

# label -> expected-prefix table (for the name/pattern mismatch VLOOKUP).
mColL <- int2col(col)
mColL2 <- int2col(col + 1)
wb$add_data(
  "lists",
  data.frame(label = tc$label, prefix = tc$name_prefix),
  start_col = col,
  start_row = 1,
  col_names = TRUE
)
wb$add_named_region(
  "lists",
  dims = paste0(mColL, "2:", mColL2, 1 + nrow(tc)),
  name = "prefix_map"
)

# ---- Data validation (the dropdowns) ----------------------------------------

# error_style = "stop" refuses free text not in the list (dropdown/type-to-search
# still works); allow_blank keeps an empty cell legal.
wb$add_data_validation(
  "Features",
  dims = paste0(col_pol, "2:", col_pol, last),
  type = "list",
  value = "polarities",
  allow_blank = TRUE,
  error_style = "stop"
)
# mrm_pattern narrowed by polarity. NOTE the "&amp;": openxlsx2 escapes "&" in
# conditional-formatting formulas but NOT in data-validation formulas, so a raw
# "&" here produces invalid XML that Excel offers to "recover" (stripping the
# validation). "&amp;" passes through verbatim.
wb$add_data_validation(
  "Features",
  dims = paste0(col_pat, "2:", col_pat, last),
  type = "list",
  value = paste0('INDIRECT("AllPatterns"&amp;$', col_pol, "2)"),
  allow_blank = TRUE,
  error_style = "stop"
)

# ---- Colour warnings --------------------------------------------------------

#   red    = a hard problem: the polarity/pattern do not form a valid combination.
#   yellow = a likely mistake: the pattern is valid, but the species name's class
#            disagrees with the pattern's class.
wb$add_dxfs_style(
  "bad",
  bg_fill = wb_color(hex = "FFFFC7CE"),
  font_color = wb_color(hex = "FF9C0006")
)
wb$add_dxfs_style(
  "check",
  bg_fill = wb_color(hex = "FFFFEB3B"),
  font_color = wb_color(hex = "FF7F6000")
)

# (1) mrm_pattern not valid for the chosen polarity. Excel validates a dependent
# dropdown only on entry, so changing polarity leaves a stale pattern in place;
# .xlsx cannot auto-clear it (that needs a macro). Flag polarity+pattern red.
invalid_rule <- sprintf(
  'AND($%s2<>"",$%s2<>"",ISNA(MATCH($%s2,INDIRECT("AllPatterns"&$%s2),0)))',
  col_pol,
  col_pat,
  col_pat,
  col_pol
)
wb$add_conditional_formatting(
  "Features",
  dims = paste0(col_pol, "2:", col_pat, last),
  rule = invalid_rule,
  style = "bad",
  type = "expression"
)

# (2) species name whose class disagrees with the chosen pattern's class. Guarded
# by NOT(ISNA(MATCH ...)) so it never fires on an invalid pattern -- rule (1) owns
# that; the two are mutually exclusive. Flag feature_id + mrm_pattern yellow.
mismatch_rule <- sprintf(
  paste0(
    'AND($%s2<>"",$%s2<>"",',
    'NOT(ISNA(MATCH($%s2,INDIRECT("AllPatterns"&$%s2),0))),',
    'LEFT($%s2,LEN(VLOOKUP($%s2,prefix_map,2,FALSE))+1)<>',
    '(VLOOKUP($%s2,prefix_map,2,FALSE)&" "))'
  ),
  col_name,
  col_pat,
  col_pat,
  col_pol,
  col_name,
  col_pat,
  col_pat
)
for (dims in c(
  paste0(col_name, "2:", col_name, last),
  paste0(col_pat, "2:", col_pat, last)
)) {
  wb$add_conditional_formatting(
    "Features",
    dims = dims,
    rule = mismatch_rule,
    style = "check",
    type = "expression"
  )
}

# ---- Save -------------------------------------------------------------------

wb$save(TEMPLATE)
preview <- "data-raw/mrmhub_metadata_template_preview.xlsx" # eyeball copy (data-raw is .Rbuildignore'd)
file.copy(TEMPLATE, preview, overwrite = TRUE)
cat("Wrote", TEMPLATE, "and preview", preview, "\n")
