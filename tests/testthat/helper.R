# global constants for tests

MH_CSV_QUANTIFIER_FEATURES <- 16
MH_CSV_QUALIFIER_FEATURES <- 9


# An experiment with `metrics_calibration` populated from an external
# calibration curve. Used to assert that steps which rewrite intensities or
# concentrations clear the calibration metrics those fits no longer describe.
calibrated_experiment <- function() {
  suppressMessages({
    mexp <- normalize_by_istd(quant_lcms_dataset)
    mexp <- calc_calibration_results(
      mexp,
      fit_overwrite = TRUE,
      fit_model = "linear",
      fit_weighting = "1/x"
    )
    quantify_by_calibration(mexp, fit_overwrite = FALSE)
  })
}
