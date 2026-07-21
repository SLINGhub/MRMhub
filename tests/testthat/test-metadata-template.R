# The committed metadata template carries the `mrm_pattern` dropdown, generated
# from licar_template_choices() by data-raw/make_metadata_template.R (kept out of
# the build). These read the file back and fail if the dropdown lists diverge
# from the choices -- the signal to re-run the generator -- and guard against the
# malformed-XML class of bug (an unescaped "&" in a data-validation formula that
# openxlsx2 reads happily but Excel refuses).

template_path <- function() {
  system.file("extdata", "mrmhub_metadata_templates.xlsx", package = "mrmhub")
}

test_that("the Features sheet exposes polarity + mrm_pattern before the manual columns", {
  wb <- openxlsx2::wb_load(template_path())
  hdr <- names(openxlsx2::wb_to_df(wb, sheet = "Features", col_names = TRUE))

  expect_true(all(c("polarity", "mrm_pattern") %in% hdr))
  # Grouped with the manual interference overrides they drive.
  expect_equal(which(hdr == "polarity"), which(hdr == "mrm_pattern") - 1L)
  expect_equal(
    which(hdr == "mrm_pattern"),
    which(hdr == "interference_feature_id") - 1L
  )
})

test_that("the template's dropdown lists match licar_template_choices()", {
  wb <- openxlsx2::wb_load(template_path())
  tc <- licar_template_choices()
  region <- function(name) {
    as.character(openxlsx2::wb_to_df(
      wb,
      named_region = name,
      col_names = FALSE
    )[[1]])
  }

  # Flat pattern list (no product_origin column: the label alone carries origin).
  expect_setequal(region("AllPatterns"), tc$label)

  # Each polarity sub-list. A label with no intrinsic polarity belongs to both.
  for (pol in c("Pos", "Neg")) {
    expected <- tc$label[is.na(tc$polarity) | tc$polarity == pol]
    expect_setequal(region(paste0("AllPatterns", pol)), expected)
  }

  # RPLC + broken classes are excluded from the dropdown.
  expect_false(any(c("PC_d9", "MG", "MGSIM") %in% region("AllPatterns")))
  expect_false(any(grepl("->", region("AllPatterns"), fixed = TRUE))) # RPLC labels
})

test_that("the label -> prefix map covers every offered pattern", {
  wb <- openxlsx2::wb_load(template_path())
  tc <- licar_template_choices()
  pm <- openxlsx2::wb_to_df(wb, named_region = "prefix_map", col_names = FALSE)

  expect_equal(nrow(pm), nrow(tc))
  expect_setequal(as.character(pm[[1]]), tc$label)
})

test_that("every XML part of the template is well-formed", {
  # openxlsx2 reads a slightly-malformed .xlsx without complaint, but Excel
  # refuses it and strips the broken part. This is the only check that catches
  # that class of bug -- e.g. an unescaped "&" in a data-validation formula.
  skip_if_not_installed("xml2")

  tmp <- withr::local_tempdir()
  utils::unzip(template_path(), exdir = tmp)
  parts <- list.files(
    tmp,
    pattern = "\\.(xml|vml)$",
    recursive = TRUE,
    full.names = TRUE
  )
  expect_true(length(parts) > 0)
  for (part in parts) {
    expect_no_error(xml2::read_xml(part))
  }
})
