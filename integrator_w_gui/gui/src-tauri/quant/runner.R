# Noninteractive, file-based results. stdout/stderr are logs, with reserved
# __MRMHUB_QUANT_PROGRESS__ JSON records for Legacy progress events only.
args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) >= 4L)
mode <- args[[1]]; engine <- args[[2]]; work <- args[[3]]; library_path <- args[[4]]
dir.create(library_path, recursive = TRUE, showWarnings = FALSE)
reused_libraries <- strsplit(Sys.getenv("MRMHUB_QUANT_LIBRARIES"), .Platform$path.sep, fixed = TRUE)[[1]]
.libPaths(c(library_path, reused_libraries[nzchar(reused_libraries)], .libPaths()))
options(cli.num_colors = 1L, crayon.enabled = FALSE, width = 100, timeout = 1200)
Sys.setenv(R_CLI_NUM_COLORS = "1", RGL_USE_NULL = "TRUE")
if (!l10n_info()[["UTF-8"]] && .Platform$OS.type == "unix") {
  for (locale in c("en_US.UTF-8", "C.UTF-8")) {
    if (nzchar(suppressWarnings(Sys.setlocale("LC_CTYPE", locale)))) break
  }
}
# A plotting function that prints internally must never open Quartz/X11/Windows.
options(device = function(...) grDevices::pdf(file = NULL))

if (mode == "setup") {
  # Package-install subprocesses must also see reused dependencies.
  Sys.setenv(R_LIBS_USER = paste(.libPaths(), collapse = .Platform$path.sep))
  if (file.exists(file.path(library_path, "ready"))) unlink(file.path(library_path, "ready"))
  desc <- read.dcf(file.path(engine, "package", "DESCRIPTION"))
  imports <- trimws(gsub("\\s*\\(.*?\\)", "", strsplit(desc[1, "Imports"], ",")[[1]]))
  needed <- unique(c(imports, "jsonlite", "BiocManager", "patchwork", "ggvenn", "MASS", "mgcv", "ggbeeswarm", "ggforce", "ggExtra", "ggpmisc", "ragg"))
  needed <- setdiff(needed, "methods")
  # Only the app-owned library is changed. install.packages resolves Imports
  # and LinkingTo; it does not pull unrelated Bioconductor/Shiny suggestions.
  missing <- needed[!vapply(needed, requireNamespace, logical(1), quietly = TRUE)]
  if (length(missing)) install.packages(missing, lib = library_path, repos = "https://cloud.r-project.org", Ncpus = max(1L, min(4L, parallel::detectCores())), dependencies = NA)
  missing <- needed[!vapply(needed, requireNamespace, logical(1), quietly = TRUE)]
  if (length(missing)) stop("Packages could not be installed: ", paste(missing, collapse = ", "), ". Check network access and R build tools, then retry.")
  if (!requireNamespace("rgoslin", quietly = TRUE)) BiocManager::install("rgoslin", lib = library_path, ask = FALSE, update = FALSE)
  if (!requireNamespace("rgoslin", quietly = TRUE)) stop("The Bioconductor lipid parser rgoslin could not be installed. Use an R version supported by Bioconductor and retry.")
  optional_file <- file.path(work, "optional-packages.txt")
  optional <- if (file.exists(optional_file)) readLines(optional_file, warn = FALSE) else character()
  if (any(!optional %in% c("sva", "ranger", "rgoslin", "enviPat"))) stop("Unsupported optional dependency.")
  for (pkg in intersect(optional, c("ranger", "enviPat"))) if (!requireNamespace(pkg, quietly = TRUE)) install.packages(pkg, lib = library_path, repos = "https://cloud.r-project.org")
  if ("sva" %in% optional && !requireNamespace("sva", quietly = TRUE)) BiocManager::install("sva", lib = library_path, ask = FALSE, update = FALSE)
  if (any(!vapply(optional, requireNamespace, logical(1), quietly = TRUE))) stop("An optional dependency could not be installed; see Activity.")
  # The new mrmhub itself is always installed in library_path.
  install.packages(file.path(engine, "package"), repos = NULL, type = "source", lib = library_path, INSTALL_opts = c("--no-multiarch", "--no-docs", "--no-html"))
  loadNamespace("mrmhub", lib.loc = library_path)
  writeLines(as.character(getRversion()), file.path(library_path, "ready"))
  cat("QUANT engine is ready.\n")
  quit(status = 0L)
}

dir.create(work, recursive = TRUE, showWarnings = FALSE)
tryCatch({
  if (!requireNamespace("jsonlite", quietly = TRUE)) stop("Set up the R engine first.")
  suppressPackageStartupMessages(library("mrmhub", lib.loc = library_path, character.only = TRUE))
  source(file.path(engine, "catalog.R"), local = TRUE, encoding = "UTF-8")
  write_json <- function(value, name) jsonlite::write_json(value, file.path(work, name), auto_unbox = TRUE, na = "null", null = "null", digits = NA, pretty = TRUE)
  if (mode == "catalog") {
    write_json(list(operations = lapply(quant_catalog(), quant_schema), version = as.character(packageVersion("mrmhub")), rVersion = R.version.string), "result.json")
    quit(status = 0L)
  }
  request <- jsonlite::read_json(file.path(work, "request.json"), simplifyVector = FALSE)
  if (mode == "legacy") {
    source(file.path(engine, "legacy.R"), local = TRUE, encoding = "UTF-8")
    write_json(run_legacy(request, work), "result.json")
    quit(status = 0L)
  }
  entries <- quant_catalog()
  names(entries) <- vapply(entries, `[[`, character(1), "id")
  editable <- c(annot_analyses = "import_metadata_analyses", annot_features = "import_metadata_features", annot_istds = "import_metadata_istds", annot_responsecurves = "import_metadata_responsecurves", annot_qcconcentrations = "import_metadata_qcconcentrations")
  complete_slots <- function(object) {
    if (!methods::is(object, "MRMhubExperiment")) return(object)
    missing <- setdiff(methods::slotNames(object), names(attributes(object)))
    if (length(missing)) {
      # Some upstream bundled/archived objects predate added class slots.
      # Supply only the current class defaults; never rewrite existing slots.
      prototype <- MRMhubExperiment()
      for (name in missing) methods::slot(object, name) <- methods::slot(prototype, name)
      message("Updated older experiment structure with defaults for: ", paste(missing, collapse = ", "))
    }
    object
  }
  input <- request$checkpoint
  data <- if (!is.null(input) && nzchar(input)) readRDS(input) else NULL
  if (isTRUE(request$legacyTable)) {
    data <- get0("mexp", envir = data$workspace, inherits = FALSE)
  }
  data <- complete_slots(data)
  if (!is.null(data) && !methods::is(data, "MRMhubExperiment")) stop("Invalid QUANT checkpoint.")
  table_names <- if (!is.null(data)) methods::slotNames(data)[vapply(methods::slotNames(data), function(n) is.data.frame(methods::slot(data, n)), logical(1))] else character()
  if (request$action == "table") {
    if (!request$table %in% table_names) stop("Unknown table.")
    tbl <- methods::slot(data, request$table)
    offset <- max(0L, as.integer(request$offset)); limit <- min(200L, max(1L, as.integer(request$limit)))
    rows <- if (offset >= nrow(tbl)) tbl[0, , drop = FALSE] else tbl[seq.int(offset + 1L, min(nrow(tbl), offset + limit)), , drop = FALSE]
    rows <- as.data.frame(rows)
    for (n in names(rows)) if (inherits(rows[[n]], c("POSIXt", "Date")) || is.factor(rows[[n]])) rows[[n]] <- as.character(rows[[n]])
    write_json(list(columns = names(tbl), types = as.list(vapply(tbl, function(v) class(v)[1], character(1))), rows = rows, total = nrow(tbl), offset = offset, editable = request$table %in% names(editable)), "result.json")
    quit(status = 0L)
  }
  artifacts <- list()
  if (request$action == "edit") {
    if (!request$table %in% names(editable)) stop("Only metadata tables are editable. Imported measurements remain unchanged.")
    tbl <- methods::slot(data, request$table)
    for (change in request$changes) {
      row <- as.integer(change$row) + 1L; col <- change$column
      if (!col %in% names(tbl) || row < 1 || row > nrow(tbl)) stop("Invalid metadata cell.")
      old <- tbl[[col]]; value <- change$value
      if (is.null(value)) value <- NA
      else if (is.numeric(old)) { value <- suppressWarnings(as.numeric(value)); if (is.na(value) || !is.finite(value)) stop("Enter a finite number for ", col) }
      else if (is.logical(old)) { if (!tolower(as.character(value)) %in% c("true", "false")) stop("Use true or false for ", col); value <- tolower(as.character(value)) == "true" }
      else if (inherits(old, "POSIXt")) { value <- as.POSIXct(value, tz = attr(old, "tzone")[1]); if (is.na(value)) stop("Invalid timestamp for ", col) }
      else value <- as.character(value)
      tbl[[col]][row] <- value
    }
    data <- do.call(getExportedValue("mrmhub", editable[[request$table]]), list(data = data, table = tibble::as_tibble(tbl), ignore_warnings = FALSE))
  } else {
    entry <- entries[[request$operation]]
    if (is.null(entry)) stop("Unknown QUANT operation.")
    missing_packages <- entry$packages[!vapply(entry$packages, requireNamespace, logical(1), quietly = TRUE)]
    if (length(missing_packages)) stop("Install optional dependencies for this operation first: ", paste(missing_packages, collapse = ", "))
    fun <- getExportedValue("mrmhub", entry$id)
    parameters <- request$parameters
    if (is.null(parameters)) parameters <- list()
    allowed <- vapply(quant_schema(entry)$fields, `[[`, character(1), "name")
    if (any(!names(parameters) %in% allowed)) stop("Unsupported parameter(s): ", paste(setdiff(names(parameters), allowed), collapse = ", "))
    parameters <- lapply(parameters, function(x) {
      if (is.null(x)) return(NA)
      if (is.list(x)) {
        if (any(vapply(x, is.list, logical(1)))) stop("Nested parameters are not supported.")
        return(unlist(lapply(x, function(v) if (is.null(v)) NA else v), use.names = !is.null(names(x))))
      }
      x
    })
    if (entry$kind == "import") {
      if (entry$id != "data_load_example" && (is.null(parameters$path) || !file.exists(parameters$path))) stop("Choose an existing results file.")
      data <- MRMhubExperiment(title = request$title, analysis_type = request$analysisType)
    } else if (is.null(data)) stop("Import a dataset first.")
    if ("show_progress" %in% names(formals(fun))) parameters$show_progress <- FALSE
    if (entry$kind == "plot") {
      if ("return_plots" %in% names(formals(fun))) parameters$return_plots <- TRUE
      if ("output_pdf" %in% names(formals(fun))) parameters$output_pdf <- FALSE
      if ("multithreading" %in% names(formals(fun))) parameters$multithreading <- FALSE
      if ("path" %in% names(parameters)) stop("Plot paths are managed by the GUI.")
      # Retain rendered PNG/PDF outputs, not a second serialized plot object
      # carrying another copy of the underlying measurements.
      plots <- do.call(fun, c(list(data = data), parameters))
      pages <- getFromNamespace("as_plot_list", "mrmhub")(plots)$plots
      size <- list(width = 297 / 25.4, height = 210 / 25.4)
      page_args <- intersect(names(parameters), c("page_width", "page_height", "page_units", "page_orientation"))
      if (length(page_args)) size <- do.call(getFromNamespace("resolve_page_size", "mrmhub"), parameters[page_args])
      for (i in seq_along(pages)) {
        name <- sprintf("plot-%03d.png", i)
        save_plot(pages[[i]], file.path(work, name), width = size$width, height = size$height, units = "in", dpi = 300, show_plot = FALSE)
        artifacts[[length(artifacts) + 1L]] <- list(name = name, kind = "image")
      }
      save_plot(plots, file.path(work, "plots.pdf"), width = size$width, height = size$height, units = "in", show_plot = FALSE)
    } else if (entry$kind == "export") {
      name <- switch(entry$id, save_dataset_csv = "dataset.csv", save_report_xlsx = "report.xlsx", save_dataset_rds = "archive.rds", save_feature_qc_metrics = "feature-qc.csv", "metadata.xlsx")
      parameters$path <- file.path(work, name)
      do.call(fun, c(if ("data" %in% names(formals(fun))) list(data = data) else list(), parameters))
    } else {
      data <- do.call(fun, c(if ("data" %in% names(formals(fun))) list(data = data) else list(), parameters))
      if (!methods::is(data, "MRMhubExperiment")) stop("QUANT did not return an experiment.")
      data <- complete_slots(data)
    }
  }
  # Rust retires the previous snapshot only after this run commits. Plot/export
  # operations do not change data: hard-link that snapshot when supported,
  # falling back to a normal save on filesystems without hard links.
  unchanged <- request$action == "run" && entry$kind %in% c("plot", "export")
  linked <- unchanged && !is.null(input) && nzchar(input) &&
    isTRUE(suppressWarnings(file.link(input, file.path(work, "experiment.rds"))))
  if (!linked) saveRDS(data, file.path(work, "experiment.rds"))
  capture.output(sessionInfo(), file = file.path(work, "session-info.txt"))
  table_names <- methods::slotNames(data)[vapply(methods::slotNames(data), function(n) is.data.frame(methods::slot(data, n)), logical(1))]
  tables <- lapply(table_names, function(n) list(name = n, rows = nrow(methods::slot(data, n)), editable = n %in% names(editable)))
  names(tables) <- NULL
  metadata_coverage <- function(ids, annotated, active) list(
    imported = length(unique(ids)), active = length(unique(active)),
    missing = length(setdiff(ids, annotated)), extra = length(setdiff(annotated, ids)))
  for (name in setdiff(list.files(work), c("request.json", "result.json", "error.txt", vapply(artifacts, `[[`, character(1), "name")))) {
    if (grepl("\\.(csv|xlsx|pdf|rds|txt)$", name)) artifacts[[length(artifacts) + 1L]] <- list(name = name, kind = "file")
  }
  write_json(list(title = data@title, analysisType = data@analysis_type, tables = tables, artifacts = artifacts,
                  samples = length(unique(data@dataset$analysis_id)), features = length(unique(data@dataset$feature_id)),
                  normalized = data@is_istd_normalized, quantitated = data@is_quantitated, filtered = data@is_filtered,
                  qcTypes = unique(data@annot_analyses$qc_type), packageVersion = as.character(packageVersion("mrmhub")),
                  metadataCoverage = list(analyses = metadata_coverage(data@dataset_orig$analysis_id, data@annot_analyses$analysis_id, data@dataset$analysis_id),
                                          features = metadata_coverage(data@dataset_orig$feature_id, data@annot_features$feature_id, data@dataset$feature_id))), "result.json")
}, error = function(e) {
  message(conditionMessage(e))
  writeLines(conditionMessage(e), file.path(work, "error.txt"))
  quit(status = 1L)
})
