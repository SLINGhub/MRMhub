# Integration/parity tests using the actual installed QUANT package.
# From the repository root:
# Rscript --vanilla integrator_w_gui/gui/tests/quant-runner.R /absolute/path/to/R/library
lib <- normalizePath(commandArgs(trailingOnly = TRUE)[[1]])
.libPaths(c(lib, .libPaths()))
suppressPackageStartupMessages(library(mrmhub, lib.loc = lib))
root <- normalizePath(".")
runner <- file.path(root, "integrator_w_gui/gui/src-tauri/quant/runner.R")
engine <- tempfile("quant-parity-"); dir.create(engine)
file.copy(file.path(root, "integrator_w_gui/gui/src-tauri/quant/catalog.R"), file.path(engine, "catalog.R"))
source(file.path(engine, "catalog.R"))
counter <- 0L
run <- function(request, success = TRUE, mode = "run") {
  counter <<- counter + 1L
  work <- file.path(engine, paste0("job-", counter)); dir.create(work)
  jsonlite::write_json(request, file.path(work, "request.json"), auto_unbox = TRUE, null = "null", digits = NA)
  status <- system2(file.path(R.home("bin"), "Rscript"), c("--vanilla", shQuote(runner), mode, shQuote(engine), shQuote(work), shQuote(lib)), stdout = file.path(work, "run.log"), stderr = file.path(work, "run.log"))
  if (success && status != 0) stop(paste(readLines(file.path(work, "run.log")), collapse = "\n"))
  if (!success && status == 0) stop("Expected operation to fail")
  list(work = work, checkpoint = file.path(work, "experiment.rds"), result = if (status == 0) jsonlite::read_json(file.path(work, "result.json"), simplifyVector = TRUE) else NULL)
}
catalog <- run(list(), mode = "catalog")
stopifnot(nrow(catalog$result$operations) == length(quant_catalog()))
stopifnot(identical(catalog$result$operations$stage[1], "1 \u00b7 Import"))
cat("PASS original function parameter discovery\n")
input <- file.path(root, "inst/extdata/MRMhub_demo.tsv")
imported <- run(list(action = "run", operation = "import_data_mrmhub", checkpoint = "", title = "Parity", analysisType = "lipidomics", parameters = list(path = input, import_metadata = TRUE)))
direct <- import_data_mrmhub(MRMhubExperiment(title = "Parity", analysis_type = "lipidomics"), path = input, import_metadata = TRUE)
stopifnot(identical(readRDS(imported$checkpoint), direct))
cat("PASS MRMhub import: exact S4 object parity\n")
if (file.exists("ASSAY/long.csv")) {
  assay_path <- normalizePath("ASSAY/long.csv")
  assay <- run(list(action = "run", operation = "import_data_mrmhub", checkpoint = "", title = "ASSAY", analysisType = "metabolomics", parameters = list(path = assay_path, import_metadata = TRUE)))
  assay_direct <- import_data_mrmhub(MRMhubExperiment(title = "ASSAY", analysis_type = "metabolomics"), path = assay_path, import_metadata = TRUE)
  stopifnot(identical(readRDS(assay$checkpoint), assay_direct))
  cat("PASS actual ASSAY long.csv: exact S4 object parity\n")
}
tbl <- run(list(action = "table", checkpoint = imported$checkpoint, table = "dataset", offset = 0, limit = 50))
stopifnot(tbl$result$total == nrow(direct@dataset), nrow(tbl$result$rows) == 50)
tail_tbl <- run(list(action = "table", checkpoint = imported$checkpoint, table = "dataset", offset = nrow(direct@dataset) + 1, limit = 50))
stopifnot(length(tail_tbl$result$rows) == 0)
cat("PASS bounded table pagination\n")
base_hash <- tools::md5sum(imported$checkpoint)
failed <- run(list(action = "run", operation = "quantify_by_istd", checkpoint = imported$checkpoint, parameters = list()), success = FALSE)
stopifnot(identical(base_hash, tools::md5sum(imported$checkpoint)), !file.exists(failed$checkpoint))
cat("PASS missing prerequisites fail without changing the previous checkpoint\n")
run(list(action = "run", operation = "system", checkpoint = imported$checkpoint, parameters = list()), success = FALSE)
run(list(action = "run", operation = "set_intensity_var", checkpoint = imported$checkpoint, parameters = list(data = "injected", variable_name = "area")), success = FALSE)
cat("PASS operation and parameter allowlists\n")

# The shipped lipidomics example has annotated ISTD concentrations and batches.
data(lipidomics_dataset)
# The shipped .rda predates the conc_analyte_unit slot. Copy its existing
# slots into the current class prototype without changing any measurements.
direct <- MRMhubExperiment()
for (name in intersect(slotNames(direct), names(attributes(lipidomics_dataset)))) slot(direct, name) <- slot(lipidomics_dataset, name)
checkpoint <- file.path(engine, "lipidomics.rds"); saveRDS(direct, checkpoint)
compare <- function(operation, parameters = list()) {
  next_step <- run(list(action = "run", operation = operation, checkpoint = checkpoint, parameters = parameters))
  expected <- do.call(getExportedValue("mrmhub", operation), c(list(data = direct), parameters))
  actual <- readRDS(next_step$checkpoint)
  if (!isTRUE(all.equal(actual, expected, tolerance = 0))) stop("Parity failure: ", operation, "\n", paste(all.equal(actual, expected), collapse = "\n"))
  direct <<- expected; checkpoint <<- next_step$checkpoint
  cat("PASS exact numerical parity:", operation, "\n")
}
compare("set_analysis_order", list(order_by = "resultfile"))
compare("set_intensity_var", list(variable_name = "area"))
compare("correct_custom_interferences")
compare("normalize_by_istd")
compare("quantify_by_istd")
compare("correct_drift_gaussiankernel", list(variable = "conc", ref_qc_types = "SPL", kernel_size = 10, recalc_trend_after = TRUE, show_progress = FALSE)[c("variable", "ref_qc_types", "kernel_size", "recalc_trend_after")])
compare("correct_batch_centering", list(variable = "conc", ref_qc_types = "SPL", correct_scale = TRUE, log_transform_internal = TRUE))
compare("filter_features_qc", list(include_qualifier = FALSE, include_istd = FALSE, min.intensity.median.spl = 100, max.cv.conc.bqc = 25, recalc_metrics = TRUE))

# Native original metadata importer validates edits, including numeric types.
edited <- run(list(action = "edit", checkpoint = checkpoint, table = "annot_analyses", changes = list(list(row = 0, column = "sample_amount", value = "12.5"))))
metadata <- direct@annot_analyses; metadata$sample_amount[1] <- 12.5
expected <- import_metadata_analyses(direct, table = metadata, ignore_warnings = FALSE)
stopifnot(isTRUE(all.equal(readRDS(edited$checkpoint), expected, tolerance = 0)))
run(list(action = "edit", checkpoint = checkpoint, table = "annot_analyses", changes = list(list(row = 0, column = "sample_amount", value = "abc"))), success = FALSE)
cat("PASS validated numeric metadata edits, original importer parity\n")

for (operation in c("plot_runsequence", "plot_abundanceprofile", "plot_rt_vs_chain", "plot_rla_boxplot", "plot_pca", "plot_runscatter", "plot_responsecurves", "plot_interference_correction", "plot_normalization_qc", "plot_qc_summary_byclass", "plot_qc_summary_overall")) {
  entry <- Filter(function(x) x$id == operation, quant_catalog())[[1]]
  parameters <- entry$defaults
  if (operation %in% c("plot_runscatter", "plot_responsecurves")) parameters$include_feature_filter <- "^CE 18:1$"
  result <- run(list(action = "run", operation = operation, checkpoint = checkpoint, parameters = parameters))
  stopifnot(file.exists(file.path(result$work, "plots.pdf")), file.exists(file.path(result$work, "plot-001.png")), identical(readRDS(result$checkpoint), direct), !file.exists(file.path(result$work, "plots.rds")))
  # Read PNG IHDR only; do not allocate a full decoded 300-DPI page in tests.
  header <- readBin(file.path(result$work, "plot-001.png"), "raw", n = 24)
  dimensions <- readBin(header[17:24], "integer", n = 2, size = 4, endian = "big")
  stopifnot(all(abs(dimensions - c(297, 210) / 25.4 * 300) < 2))
  cat("PASS original plot rendering, PDF and PNG:", operation, "\n")
}
export <- run(list(action = "run", operation = "save_dataset_csv", checkpoint = checkpoint, parameters = list(variable = "conc", qc_types = "SPL", filter_data = TRUE, include_qualifier = FALSE)))
save_dataset_csv(direct, path = file.path(engine, "direct.csv"), variable = "conc", qc_types = "SPL", filter_data = TRUE, include_qualifier = FALSE)
stopifnot(identical(readBin(file.path(export$work, "dataset.csv"), "raw", n = 1e8), readBin(file.path(engine, "direct.csv"), "raw", n = 1e8)))
run(list(action = "run", operation = "save_report_xlsx", checkpoint = checkpoint, parameters = list(filtered_variable = "conc")))
run(list(action = "run", operation = "save_metadata_templates", checkpoint = checkpoint, parameters = list()))
cat("PASS byte-identical CSV export, Excel report and metadata template\n")
cat("All QUANT integration tests passed. Test artifacts:", engine, "\n")
