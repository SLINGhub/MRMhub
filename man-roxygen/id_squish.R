#' @section Identifier normalization:
#' All imported identifiers are whitespace-normalized on import: leading and
#' trailing spaces are removed and internal runs of whitespace are collapsed to
#' a single space (for example `"QC  01"` becomes `"QC 01"`). Raw-data file
#' extensions (`.mzML`, `.d`, `.raw`, `.wiff`, `.wiff2`, `.lcd`, `.chrom`,
#' case-insensitive) are stripped from `analysis_id`.
#'
#' The same normalization is applied to both the data and the metadata, which is
#' what lets an `analysis_id` typed into metadata match the one derived from a
#' data-file name instead of silently failing to join. A consequence is that two
#' identifiers differing only by whitespace collapse to one and are then reported
#' as duplicates.
