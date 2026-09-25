#' @param qc_types A character vector specifying the QC types to plot. It must
#'   contain at least one element. The default `NA` plots any of the non-blank
#'   QC types ("SPL", "TQC", "BQC", "HQC", "MQC", "LQC", "NIST", "LTR") present
#'   in the dataset. A single value that is a QC type is matched exactly; any
#'   other single value is a regular expression, e.g. `"QC$"` for all QC types
#'   ending in "QC".
