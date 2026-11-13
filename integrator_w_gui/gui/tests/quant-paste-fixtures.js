// Representative rendered tutorial output. Expected code is compared with R's
// parser too, so cleanup cannot quietly change a scientific expression.
export const pasteFixtures = [
  {
    name: "step 3 tibble",
    pasted: 'print(mexp@dataset)\n# A tibble: 250,997 × 21\n   analysis_order analysis_id qc_type\n            <int> <chr> <chr>\n 1              1 Longit_BLANK SBLK\n# ℹ 250,987 more rows',
    expected: 'print(mexp@dataset)',
  },
  {
    name: "later one-column tibble and following calculations",
    pasted: 'print(summary_table)\n# A tibble: 2 × 1\n  value\n  <dbl>\n1 4\n2 5\n\nx <- 1 + 2\n!is.na(x)',
    expected: 'print(summary_table)\nx <- 1 + 2\n!is.na(x)',
  },
  {
    name: "step 8 metadata report",
    pasted: 'mexp <- import_metadata_msorganiser(mexp, path = "metadata.xlsx", ignore_warnings = TRUE)\nFound no errors, 2 warnings, and no notes in the metadata.\n------------\n  Type Table Column Issue Count\n1 W* Analyses analysis_id Analyses not in analysis data 2\n2 W* Features feature_id Features without metadata 1\n\n------------\nE = Error, W = Warning, W* = Suppressed Warning, N = Note\n------------\n✔ Analysis metadata associated with 25 analyses.\nmexp <- set_analysis_order(mexp, order_by = "timestamp")\n✔ Analysis order set to "timestamp"\nmexp <- set_intensity_var(mexp, variable_name = "area")',
    expected: 'mexp <- import_metadata_msorganiser(mexp, path = "metadata.xlsx", ignore_warnings = TRUE)\nmexp <- set_analysis_order(mexp, order_by = "timestamp")\nmexp <- set_intensity_var(mexp, variable_name = "area")',
  },
  {
    name: "step 14 normalization messages",
    pasted: 'mexp <- normalize_by_istd(mexp)\n✔ 20 features normalized with 5 ISTDs in 25 analyses.\nmexp <- quantify_by_istd(mexp)\n✔ 20 feature concentrations calculated.\n✔ Concentrations are given in μmol/L.',
    expected: 'mexp <- normalize_by_istd(mexp)\nmexp <- quantify_by_istd(mexp)',
  },
  {
    name: "step 16 warnings containing unmatched backticks/apostrophes",
    pasted: 'mexp <- correct_drift_gaussiankernel(mexp, variable = "conc")\n! 4 feature(s) contain one or more zero or negative `conc` values.\n! 1 features showed no variation in the study sample\'s original values across analyses.\n! 1 features have invalid values after smoothing. Set `use_original_if_fail = FALSE to return original values.\n! Smoothing failed for 1 feature(s) in all batches.\n✔ Drift correction was applied to 20 features.\nℹ The median per-feature CV change was -1.00%.\nmy_trend_plot("conc", "PC 40:8")',
    expected: 'mexp <- correct_drift_gaussiankernel(mexp, variable = "conc")\nmy_trend_plot("conc", "PC 40:8")',
  },
  {
    name: "step 19 QC warnings and step 22 export message",
    pasted: 'mexp <- filter_features_qc(mexp, max.cv.conc.bqc = 25)\n! %CV not computed for 4 feature×QC-type×variable combinations with fewer than 3 replicates.\n✔ QC metrics calculated for 25 features.\n! The QC parameter min.intensity.median.spl contains NAs for the following features: PC 34:5.\n! The following features were forced to be retained despite not meeting filtering criteria: CE 16:0\n✔ New feature QC filters were defined: 20 features meet criteria.\nsave_report_xlsx(mexp, path = "report.xlsx")\n✔ The data processing report has been saved to report.xlsx.',
    expected: 'mexp <- filter_features_qc(mexp, max.cv.conc.bqc = 25)\nsave_report_xlsx(mexp, path = "report.xlsx")',
  },
];
