# Builds the bundled LICAR HILIC demo dataset used by the interference-correction
# tutorial. Run from the repo root:
#
#   Rscript data-raw/make_licar_hilic_demo.R
#
# It combines the six single-class LICAR "golden" raw templates
# (tests/testthat/testdata/licar-golden/raw/*.csv, from Gao et al. 2021,
# https://github.com/SLINGhub/LICAR) into one multi-class HILIC-style lipidomics
# dataset spanning PC, SM, Cer, dhCer (positive mode) and PC/PE via the negative
# FA-fragment patterns. The five injections are all study samples (SPL); the raw
# templates carry no blanks/QCs.
#
# Two plain-CSV deliverables are written to inst/extdata:
#   * licar_hilic_demo.csv          -- long-format analysis data with precursor
#                                      + product m/z and polarity (the "analysis
#                                      data" the MRM derivation reads), imported
#                                      with import_data_csv_long().
#   * licar_hilic_demo_features.csv -- feature metadata (feature_class,
#                                      mrm_pattern, is_istd), imported with
#                                      import_metadata_features().
#
# Together they exercise the automatic calc_isotopic_interferences(level = "MRM")
# derivation. Derived factors reproduce the published LICAR values under the
# pinned enviPat 2.8 (see tests/testthat/testdata/licar-golden/enviPat-version.txt).

raw_dir <- "tests/testthat/testdata/licar-golden/raw"

# class file -> stored mrm_pattern, reported feature_class, acquisition polarity
spec <- list(
  PC = list(pattern = "PC (Pos) Pro=184.1", class = "PC", polarity = "+"),
  SM = list(pattern = "SM (Pos) Pro=184.1", class = "SM", polarity = "+"),
  Cer = list(pattern = "Cer (Pos) SphB-2H2O", class = "Cer", polarity = "+"),
  dhCer = list(
    pattern = "dhCer (Pos) SphB-H2O",
    class = "dhCer",
    polarity = "+"
  ),
  PCNFA = list(pattern = "PC (Neg, FA) FA", class = "PC", polarity = "-"),
  PENFA = list(pattern = "PE (Neg) FA", class = "PE", polarity = "-")
)

long_parts <- list()
feature_parts <- list()

for (nm in names(spec)) {
  raw <- utils::read.csv(
    file.path(raw_dir, paste0(nm, ".csv")),
    check.names = FALSE
  )
  samples <- names(raw)[4:ncol(raw)]
  analysis_ids <- sprintf("SPL%02d", seq_along(samples))
  s <- spec[[nm]]

  long_parts[[nm]] <- do.call(
    rbind,
    lapply(seq_along(samples), function(i) {
      data.frame(
        analysis_id = analysis_ids[i],
        feature_id = raw$Name,
        qc_type = "SPL",
        batch_id = 1L,
        precursor_mz = raw$Precursor,
        product_mz = raw$Product,
        polarity = s$polarity,
        area = raw[[samples[i]]],
        stringsAsFactors = FALSE
      )
    })
  )

  feature_parts[[nm]] <- data.frame(
    feature_id = raw$Name,
    feature_class = s$class,
    mrm_pattern = s$pattern,
    is_istd = grepl("\\(IS\\)", raw$Name),
    stringsAsFactors = FALSE
  )
}

long <- do.call(rbind, long_parts)
features <- do.call(rbind, feature_parts)
rownames(long) <- NULL
rownames(features) <- NULL

if (anyDuplicated(features$feature_id)) {
  stop("Duplicate feature_id across classes -- names must be unique.")
}

utils::write.csv(
  long,
  "inst/extdata/licar_hilic_demo.csv",
  row.names = FALSE
)
utils::write.csv(
  features,
  "inst/extdata/licar_hilic_demo_features.csv",
  row.names = FALSE
)

message(sprintf(
  "Wrote %d features across %d classes, %d analyses.",
  nrow(features),
  length(unique(features$feature_class)),
  length(unique(long$analysis_id))
))
