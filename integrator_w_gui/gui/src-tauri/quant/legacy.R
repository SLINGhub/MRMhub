# Deliberate trusted-code execution, like an R notebook, NOT a sandbox.
# Each successful block snapshots serializable objects; failed blocks never
# replace the previous snapshot. Explicit file/network side effects cannot roll back.
run_legacy <- function(request, work) {
  code <- request$code
  if (!is.character(code) || length(code) != 1L || !nzchar(trimws(code))) stop("Paste an R code block first.")
  writeLines(code, file.path(work, "code.R"), useBytes = TRUE)
  expressions <- tryCatch(parse(file.path(work, "code.R"), keep.source = TRUE), error = function(e) {
    hint <- if (grepl("# A tibble:", code, fixed = TRUE)) "\nCheck for unrecognized printed table output. Run automatically cleans recognized tutorial output; paste only R commands if the format is different." else if (grepl("[\u251c\u2514]\u2500", code)) "\nA folder-layout diagram is documentation, not R code. Start with library(mrmhub)." else "\nCheck the indicated line in the R editor. Paste code only, not console output."
    stop(conditionMessage(e), hint, call. = FALSE)
  })
  # Actual completed work units, not an elapsed-time estimate. Arbitrary R calls
  # cannot expose internal completion reliably, so never simulate their progress.
  total_units <- length(expressions) + 2L
  report_progress <- function(completed, message) {
    token <- request$progressToken
    if (is.null(token)) return(invisible(NULL))
    payload <- list(token = token, percent = 100 * completed / total_units, message = message)
    cat("\n__MRMHUB_QUANT_PROGRESS__", jsonlite::toJSON(payload, auto_unbox = TRUE, digits = 6), "\n", sep = "", file = stderr())
    flush(stderr())
  }
  report_progress(0, "Loading the saved R session and its packages…")
  session <- if (nzchar(request$checkpoint)) readRDS(request$checkpoint) else NULL
  workspace <- if (is.null(session)) new.env(parent = globalenv()) else session$workspace
  if (!is.environment(workspace)) stop("Invalid legacy session.")
  if (!is.null(session)) {
    for (package in rev(session$packages)) library(package, character.only = TRUE)
    if (length(session$plotDefaults)) do.call(mrmhub::mrmhub_set_plot_defaults, session$plotDefaults)
    if (!is.null(session$randomSeed)) assign(".Random.seed", session$randomSeed, envir = globalenv())
  }
  setwd(if (is.null(session)) request$project else session$directory)
  assign("dataset_dir", request$project, envir = workspace)
  assign("output_dir", work, envir = workspace)
  # Default device captures base and grid/ggplot graphics, including plots
  # printed internally by original QUANT functions. No scientific wrappers.
  device_number <- 0L
  options(device = function(...) {
    device_number <<- device_number + 1L
    ragg::agg_png(file.path(work, sprintf("legacy-%03d-%%03d.png", device_number)),
                  width = 1684 / 144, height = 1190 / 144, units = "in", res = 300)
  })
  on.exit(grDevices::graphics.off(), add = TRUE)
  # Notebook View() displays tabular text here, rather than opening an R window.
  assign("View", eval(quote(function(x, title = NULL, ...) print(x)), envir = baseenv()), envir = workspace)
  for (index in seq_along(expressions)) {
    expression <- expressions[[index]]
    label <- substr(paste(deparse(expression, width.cutoff = 100L, nlines = 1L), collapse = " "), 1L, 140L)
    report_progress(index, sprintf("Running R statement %d of %d: %s", index, length(expressions), label))
    value <- tryCatch(withVisible(eval(expression, envir = workspace)), error = function(e) {
      detail <- conditionMessage(e)
      hint <- if (grepl("object 'mexp' not found", detail, fixed = TRUE)) {
        "\nNo experiment named mexp is saved in this session. Run step 2 successfully first; a failed import does not create a checkpoint."
      } else if (grepl("not found|does not exist|do not exist|cannot open|No such file", detail, ignore.case = TRUE)) {
        paste0("\nWorking directory: ", getwd(), ". The tutorial's datasets/sPerfect files are example paths, not included in your dataset. Use Insert import for this dataset in step 2, or set the correct input path.")
      } else ""
      stop(detail, hint, call. = FALSE)
    })
    if (value$visible) print(value$value)
  }
  report_progress(length(expressions) + 1L, "Finishing plot files and saving the R session checkpoint…")
  grDevices::graphics.off()
  saveRDS(list(workspace = workspace, directory = getwd(),
               plotDefaults = mrmhub::mrmhub_get_plot_defaults(),
               packages = sub("^package:", "", grep("^package:", search(), value = TRUE)),
               randomSeed = get0(".Random.seed", envir = globalenv(), inherits = FALSE)),
          file.path(work, "workspace.rds"))
  capture.output(sessionInfo(), file = file.path(work, "session-info.txt"))
  experiment <- get0("mexp", envir = workspace, inherits = FALSE)
  tables <- list()
  if (methods::is(experiment, "MRMhubExperiment")) {
    # mexp is already in workspace.rds. Table previews read it there rather
    # than writing a second full copy of the measurements after every block.
    # Older upstream example objects can omit newly added scalar slots.
    # Inspect only stored slots; do not mutate the user's Legacy objects.
    names <- intersect(methods::slotNames(experiment), names(attributes(experiment)))
    names <- names[vapply(names, function(n) is.data.frame(methods::slot(experiment, n)), logical(1))]
    tables <- unname(lapply(names, function(n) list(name = n, rows = nrow(methods::slot(experiment, n)), editable = FALSE)))
  }
  objects <- ls(workspace, all.names = TRUE)
  objects <- setdiff(objects, c("View", "dataset_dir", "output_dir"))
  files <- list.files(work)
  files <- files[!dir.exists(file.path(work, files))]
  artifacts <- lapply(setdiff(files, c("request.json", "result.json", "error.txt", "run.log")), function(name) {
    list(name = name, kind = if (grepl("\\.png$", name, ignore.case = TRUE)) "image" else "file")
  })
  result <- list(title = "Legacy R session", tables = tables, artifacts = artifacts,
       objects = as.list(objects), workingDirectory = getwd(),
       samples = if (length(tables)) length(unique(experiment@dataset$analysis_id)) else 0L,
       features = if (length(tables)) length(unique(experiment@dataset$feature_id)) else 0L,
       packageVersion = as.character(packageVersion("mrmhub")))
  report_progress(total_units, "R statements and session save complete. Loading results…")
  result
}
