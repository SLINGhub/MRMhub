# End-to-end parity against LICAR's published golden values (Gao et al. 2021).
# Raw single-class inputs (data-raw templates) are corrected via the ported MRM
# derivation + the correction engine and compared to LICAR's corrected outputs.
# Factors are enviPat-version sensitive; the golden was produced with 2.8.

golden_dir <- test_path("testdata/licar-golden")
pinned_envipat <- trimws(readLines(file.path(golden_dir, "enviPat-version.txt")))

# class file -> its mrm_pattern label (covering head-group, FA and LCB)
golden_patterns <- list(
  PC = "PC (Pos) Pro=184.1",
  SM = "SM (Pos) Pro=184.1",
  Cer = "Cer (Pos) SphB-2H2O",
  dhCer = "dhCer (Pos) SphB-H2O",
  PCNFA = "PC (Neg, FA) FA",
  PENFA = "PE (Neg) FA"
)

build_from_template <- function(name, pattern) {
  raw <- utils::read.csv(
    file.path(golden_dir, "raw", paste0(name, ".csv")),
    check.names = FALSE
  )
  samp <- names(raw)[4:ncol(raw)]
  long <- do.call(rbind, lapply(samp, function(s) {
    data.frame(
      analysis_id = s, feature_id = raw$Name, qc_type = "SPL",
      feature_intensity = raw[[s]], stringsAsFactors = FALSE
    )
  }))
  mexp <- MRMhubExperiment()
  mexp@dataset <- dplyr::as_tibble(long) |> dplyr::mutate(qc_type = factor(qc_type))
  mexp@dataset_orig <- dplyr::tibble(
    analysis_id = "s1", raw_data_filename = "f",
    acquisition_time_stamp = as.Date("2024-01-01"),
    feature_id = raw$Name,
    method_precursor_mz = as.character(raw$Precursor),
    method_product_mz = as.character(raw$Product)
  )
  mexp@annot_features <- dplyr::tibble(
    feature_id = raw$Name, mrm_pattern = pattern, feature_class = name,
    is_istd = FALSE, interference_feature_id = NA_character_,
    interference_contribution = NA_real_
  )
  list(mexp = mexp, samp = samp)
}

for (nm in names(golden_patterns)) {
  local({
    name <- nm
    pattern <- golden_patterns[[nm]]
    test_that(paste0("MRM correction reproduces LICAR golden: ", name), {
      skip_if_not_installed("enviPat")
      skip_if_not_installed("rgoslin")
      skip_if(
        as.character(utils::packageVersion("enviPat")) != pinned_envipat,
        paste0("enviPat != ", pinned_envipat, " (golden factors differ)")
      )

      b <- build_from_template(name, pattern)
      res <- suppressWarnings(suppressMessages(
        derive_interferences(b$mexp, level = "MRM")
      ))
      res <- suppressWarnings(suppressMessages(
        correct_interferences(res, sequential_correction = TRUE)
      ))

      gold <- utils::read.csv(
        file.path(golden_dir, "golden", paste0(name, ".csv")),
        check.names = FALSE, row.names = 1
      )
      mine <- res@dataset
      mine <- reshape(
        as.data.frame(mine[, c("analysis_id", "feature_id", "feature_intensity")]),
        idvar = "feature_id", timevar = "analysis_id", direction = "wide"
      )
      rownames(mine) <- mine$feature_id

      for (f in rownames(gold)) {
        expect_equal(
          as.numeric(mine[f, paste0("feature_intensity.", b$samp)]),
          as.numeric(gold[f, 3:(2 + length(b$samp))]),
          tolerance = 1e-4,
          info = paste("feature", f)
        )
      }
    })
  })
}

test_that("LICAR_CHOICES labels are globally unique (derive-origin invariant)", {
  expect_false(any(duplicated(mrmhub:::LICAR_CHOICES$label)))
})
