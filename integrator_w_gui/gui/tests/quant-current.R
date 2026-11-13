# Current-engine adapter regressions, including the published Dataset4 workflow.
# Uses temporary outputs only; never modifies input datasets or the app library.
lib <- normalizePath(commandArgs(trailingOnly = TRUE)[[1]])
.libPaths(c(lib, .libPaths()))
suppressPackageStartupMessages(library(mrmhub, lib.loc = lib))
root <- normalizePath(".")
engine <- tempfile("quant-current-"); dir.create(engine)
file.copy(file.path(root, "integrator_w_gui/gui/src-tauri/quant/catalog.R"), engine)
source(file.path(engine, "catalog.R"))
runner <- file.path(root, "integrator_w_gui/gui/src-tauri/quant/runner.R")
counter <- 0L
run <- function(request, success = TRUE) {
  counter <<- counter + 1L
  work <- file.path(engine, paste0("run-", counter)); dir.create(work)
  jsonlite::write_json(request, file.path(work, "request.json"), auto_unbox = TRUE, null = "null", digits = NA)
  status <- system2(file.path(R.home("bin"), "Rscript"), c("--vanilla", shQuote(runner), "run", shQuote(engine), shQuote(work), shQuote(lib)), stdout = file.path(work,"run.log"), stderr = file.path(work,"run.log"))
  if (success && status != 0) stop(paste(readLines(file.path(work,"run.log")),collapse="\n"))
  if (!success && status == 0) stop("Expected validation failure")
  list(work=work, checkpoint=file.path(work,"experiment.rds"), result=if(status==0) jsonlite::read_json(file.path(work,"result.json"),simplifyVector=TRUE) else NULL)
}
for (e in quant_catalog()) {
  original <- names(formals(getExportedValue("mrmhub",e$id)))
  stopifnot(all(names(e$defaults) %in% original), all(vapply(quant_schema(e)$fields, `[[`, "", "name") %in% original))
}
field <- function(op, name) Filter(function(f) f$name == name, quant_schema(Filter(function(e)e$id==op,quant_catalog())[[1]])$fields)[[1]]
stopifnot(field("exclude_features","features")$vector, field("exclude_features","features")$lineSeparated,
          field("exclude_features","clear_existing")$type == "boolean",
          field("set_lipid_class","overwrite")$type == "boolean",
          "1/sqrt(x)" %in% field("quantify_by_calibration","fit_weighting")$choices,
          field("import_data_csv_long","column_mapping")$type == "mapping")
cat("PASS all current catalog functions/defaults and typed controls\n")

input <- file.path(root,"vignettes/articles/datasets/Dataset4_MRMhub-INTEGRATOR_ASSAY.csv")
metadata <- file.path(root,"vignettes/articles/datasets/Dataset4_Metadata.xlsx")
base <- run(list(action="run", operation="import_data_mrmhub", title="Dataset4", analysisType="metabolomics", parameters=list(path=input,import_metadata=TRUE)))
direct <- import_data_mrmhub(MRMhubExperiment(title="Dataset4",analysis_type="metabolomics"),input,import_metadata=TRUE)
stopifnot(identical(readRDS(base$checkpoint),direct))
invisible(run(list(action="run",operation="import_metadata_msorganiser",checkpoint=base$checkpoint,parameters=list(path=metadata)), success=FALSE))
checkpoint <- base$checkpoint
compare <- function(operation, parameters=list()) {
  result <- run(list(action="run",operation=operation,checkpoint=checkpoint,parameters=parameters))
  expected <- do.call(getExportedValue("mrmhub",operation),c(list(data=direct),parameters))
  actual <- readRDS(result$checkpoint)
  if (!isTRUE(all.equal(actual,expected,tolerance=0))) stop("Parity failure: ",operation,"\n",paste(all.equal(actual,expected),collapse="\n"))
  direct <<- expected; checkpoint <<- result$checkpoint
  cat("PASS original-function parity:",operation,"\n")
  result
}
linked <- compare("import_metadata_msorganiser",list(path=metadata,excl_unmatched_analyses=TRUE,ignore_warnings=TRUE))
stopifnot(linked$result$samples==20, linked$result$features==30, linked$result$metadataCoverage$features$missing==34)
linked_direct <- direct; linked_checkpoint <- checkpoint
original <- direct@dataset_orig
ids <- direct@annot_analyses$analysis_id[direct@annot_analyses$analysis_id %in% direct@dataset$analysis_id][1:2]
invisible(compare("exclude_analyses",list(analyses=ids[1],clear_existing=FALSE)))
invisible(compare("exclude_analyses",list(analyses=ids[2],clear_existing=FALSE)))
stopifnot(all(ids %in% direct@analyses_excluded), identical(direct@dataset_orig,original))
invisible(compare("exclude_analyses",list(analyses=NA,clear_existing=TRUE)))
invisible(compare("exclude_features",list(features=direct@annot_features$feature_id[1:2],clear_existing=FALSE)))
stopifnot(identical(direct@dataset_orig,original))
invisible(compare("exclude_features",list(features=NA,clear_existing=TRUE)))
invisible(run(list(action="run",operation="exclude_features",checkpoint=checkpoint,parameters=list(features="not a feature",clear_existing=FALSE)),success=FALSE))
preview <- run(list(action="table",checkpoint=checkpoint,table="annot_analyses",offset=0,limit=50))
stopifnot(preview$result$types$valid_analysis=="logical")
edited <- run(list(action="edit",checkpoint=checkpoint,table="annot_analyses",changes=list(list(row=0,column="valid_analysis",value="false"))))
tbl <- direct@annot_analyses; tbl$valid_analysis[1] <- FALSE
expected <- import_metadata_analyses(direct,table=tbl,ignore_warnings=FALSE)
stopifnot(isTRUE(all.equal(readRDS(edited$checkpoint),expected,tolerance=0)))
cat("PASS additive exclusions, restore, invalid IDs and Valid_Analysis edits\n")

direct <- linked_direct; checkpoint <- linked_checkpoint
invisible(compare("normalize_by_istd"))
invisible(compare("calc_calibration_results",list(fit_overwrite=TRUE,include_qualifier=FALSE,fit_model="quadratic",fit_weighting="1/x")))
invisible(compare("quantify_by_calibration",list(fit_overwrite=FALSE,include_qualifier=FALSE,ignore_failed_calibration=TRUE,fit_model="quadratic",fit_weighting="1/x")))
invisible(compare("calc_qc_metrics"))
plot <- run(list(action="run",operation="plot_calibrationcurves",checkpoint=checkpoint,parameters=list(fit_overwrite=FALSE,include_qualifier=FALSE,fit_model="quadratic",fit_weighting="1/x",page_width=120,page_height=80)))
stopifnot(file.exists(file.path(plot$work,"plots.pdf")),file.exists(file.path(plot$work,"plot-001.png")),!file.exists(file.path(plot$work,"plots.rds")),identical(readRDS(plot$checkpoint),direct))
png_header <- readBin(file.path(plot$work,"plot-001.png"),"raw",n=24)
dimensions <- readBin(png_header[17:24],"integer",n=2,size=4,endian="big")
stopifnot(all(abs(dimensions-c(120,80)/25.4*300)<2))
export <- run(list(action="run",operation="save_dataset_csv",checkpoint=checkpoint,parameters=list(variable="conc",filter_data=FALSE,include_qualifier=FALSE,include_istd=FALSE)))
save_dataset_csv(direct,file.path(engine,"expected.csv"),variable="conc",filter_data=FALSE,include_qualifier=FALSE,include_istd=FALSE)
stopifnot(identical(readBin(file.path(export$work,"dataset.csv"),"raw",n=1e7),readBin(file.path(engine,"expected.csv"),"raw",n=1e7)))
archive <- run(list(action="run",operation="save_dataset_rds",checkpoint=checkpoint,parameters=list()))
stopifnot(identical(read_dataset_rds(file.path(archive$work,"archive.rds")),direct))
restored <- run(list(action="run",operation="read_dataset_rds",title="ignored",analysisType="metabolomics",parameters=list(path=file.path(archive$work,"archive.rds"))))
stopifnot(identical(readRDS(restored$checkpoint),direct))
archive_log <- readLines(file.path(restored$work,"run.log"), warn=FALSE)
stopifnot(any(grepl("Content fingerprint verified",archive_log,fixed=TRUE)),
          !any(grepl("Fingerprint mismatch",archive_log,fixed=TRUE)))
cat(paste(archive_log,collapse="\n"),"\n")
qc <- run(list(action="run",operation="save_feature_qc_metrics",checkpoint=checkpoint,parameters=list()))
stopifnot(file.exists(file.path(qc$work,"feature-qc.csv")))
cat("PASS Dataset4 calibration, plots, byte-identical CSV, fingerprinted archive/reopen and QC export\n")

# A named mapping must arrive as a named R vector, never lose its keys.
csv <- file.path(engine,"mapped.csv")
write.csv(data.frame(sample=c("a","b"),feature=c("x","x"),signal=c(1,2)),csv,row.names=FALSE)
mapping <- c(analysis_id="sample",feature_id="feature",feature_area="signal")
mapped <- run(list(action="run",operation="import_data_csv_long",title="Mapped",analysisType="metabolomics",parameters=list(path=csv,column_mapping=as.list(mapping),import_metadata=FALSE)))
expected <- import_data_csv_long(MRMhubExperiment(title="Mapped",analysis_type="metabolomics"),path=csv,column_mapping=mapping,import_metadata=FALSE)
stopifnot(identical(readRDS(mapped$checkpoint),expected))
demo <- run(list(action="run",operation="data_load_example",title="Demo",analysisType="lipidomics",parameters=list()))
expected <- data_load_example(); actual <- readRDS(demo$checkpoint)
for (name in setdiff(names(attributes(expected)),"class")) stopifnot(identical(slot(actual,name),slot(expected,name)))
stopifnot(identical(actual@conc_analyte_unit,MRMhubExperiment()@conc_analyte_unit))
direct <- readRDS(demo$checkpoint); checkpoint <- demo$checkpoint
invisible(compare("set_lipid_class",list(overwrite=FALSE)))
cat("PASS named column mapping, bundled demo and lipid-class derivation\n")
cat("All current QUANT adapter tests passed.\n")
