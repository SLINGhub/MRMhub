# MRMhub Workflow Builder -- thin Shiny UI over the pure generator/validator in
# R/build-workflow.R. Launched by mrmhub::build_workflow(). The heavy lifting
# (generate_workflow_qmd(), validate_workflow_inputs(), workflow_steps(),
# workflow_step_availability()) lives in the package; this file only wires
# inputs to those functions.

library(shiny)
library(bslib)
library(mrmhub)

# Raise Shiny's default 5 MB upload cap -- INTEGRATOR long.csv files are larger.
options(shiny.maxRequestSize = 500 * 1024^2)

# `%||%` is a base operator only from R 4.4; define it for older R (mrmhub
# supports >= 4.2 and does not export its internal copy).
`%||%` <- function(x, y) if (is.null(x) || length(x) == 0) y else x

importer_choices <- c(
  "MRMhub / INTEGRATOR (long .tsv/.csv)" = "mrmhub",
  "Agilent MassHunter (.csv)" = "masshunter",
  "Skyline (.csv)" = "skyline",
  "Generic long CSV (one row per analysis x feature)" = "csv_long",
  "Generic wide CSV (analyses x features matrix)" = "csv_wide"
)
metadata_choices <- c(
  "Embedded in data file" = "embedded",
  "MSOrganiser (.xlsx)" = "msorganiser",
  "Metadata tables (.xlsx)" = "tables",
  "Individual files (analyses / features / ISTDs)" = "individual",
  "None" = "none"
)
# Canonical value-column names offered when mapping a generic long CSV.
long_value_types <- c(
  "Peak area" = "feature_area",
  "Peak height" = "feature_height",
  "Intensity" = "feature_intensity",
  "Concentration" = "feature_conc",
  "Normalised intensity" = "feature_norm_intensity"
)
wide_value_types <- c(
  "Peak area" = "area", "Peak height" = "height", "Intensity" = "intensity",
  "Concentration" = "conc", "Normalised intensity" = "norm_intensity",
  "Response" = "response"
)

# Read just the column names of a delimited file (for the mapping dialog).
read_columns <- function(path) {
  ext <- tolower(tools::file_ext(path))
  sep <- if (ext %in% c("tsv", "txt")) "\t" else ","
  tryCatch(
    names(readr::read_delim(path, delim = sep, n_max = 0, show_col_types = FALSE)),
    error = function(e) character()
  )
}

# First column whose name matches any of `patterns` (case-insensitive), else the
# first column -- a sensible default selection in the mapping dialog.
guess_col <- function(cols, patterns) {
  if (length(cols) == 0) return(NULL)
  hit <- which(tolower(cols) %in% tolower(patterns))
  if (length(hit) == 0) {
    hit <- which(Reduce(`|`, lapply(patterns, function(p) grepl(p, cols, ignore.case = TRUE))))
  }
  if (length(hit) > 0) cols[hit[1]] else cols[1]
}

# Folder picker for a locally-run app. Prefers the OS-native dialog so it looks
# right (Finder on macOS, Explorer on Windows); falls back to the IDE API or Tk.
# Returns a path, "" when the user cancels a dialog that did open, or NULL when
# no picker backend is available (so the caller can advise typing the path).
choose_dir_interactive <- function() {
  usable <- function(p) !is.null(p) && length(p) == 1 && !is.na(p) && nzchar(p)
  os <- Sys.info()[["sysname"]]

  # macOS: native Finder dialog via AppleScript.
  if (identical(os, "Darwin") && nzchar(Sys.which("osascript"))) {
    p <- tryCatch(
      suppressWarnings(system2(
        "osascript",
        args = c("-e", shQuote('POSIX path of (choose folder with prompt "Select project folder")')),
        stdout = TRUE, stderr = FALSE
      )),
      error = function(e) character()
    )
    p <- trimws(paste(p, collapse = ""))
    return(if (usable(p)) sub("/$", "", p) else "") # "" = user cancelled
  }

  # Windows: native folder chooser.
  if (identical(os, "Windows") && exists("choose.dir", where = asNamespace("utils"))) {
    p <- tryCatch(utils::choose.dir(caption = "Select project folder"), error = function(e) NULL)
    return(if (usable(p)) p else "")
  }

  # IDE API (RStudio; Positron where implemented).
  if (requireNamespace("rstudioapi", quietly = TRUE) &&
    rstudioapi::isAvailable() && rstudioapi::hasFun("selectDirectory")) {
    p <- tryCatch(rstudioapi::selectDirectory(caption = "Select project folder"),
      error = function(e) NULL)
    if (usable(p)) return(p)
  }
  # Last resort: Tk dialog (Linux without zenity, etc.).
  if (isTRUE(capabilities("tcltk")) && requireNamespace("tcltk", quietly = TRUE)) {
    p <- tryCatch(tcltk::tk_choose.dir(caption = "Select project folder"),
      error = function(e) NULL)
    if (usable(p)) return(p)
  }
  NULL
}

ui <- page_sidebar(
  title = "MRMhub Workflow Builder",
  theme = bs_theme(bootswatch = "sandstone"),

  sidebar = sidebar(
    width = 400,

    tags$strong("1 · Data source"),
    selectInput("importer", "Where does your data come from?", choices = importer_choices),
    helpText("Pick the tool or file format that produced your data — this selects the matching importer."),
    fileInput("data_file", "Data file", accept = c(".csv", ".tsv", ".txt")),
    uiOutput("csv_config_ui"),

    hr(),
    tags$strong("2 · Metadata"),
    selectInput("metadata_route", "Metadata source", choices = metadata_choices),
    uiOutput("metadata_inputs"),
    actionButton("load_demo", "Load bundled demo data", class = "btn-outline-secondary btn-sm"),

    hr(),
    tags$strong("3 · Project folder"),
    div(
      class = "d-flex align-items-end gap-2",
      div(class = "flex-grow-1",
        textInput("project_dir", "Analysis project folder (optional)", placeholder = "/path/to/project")),
      actionButton("browse_project", "Browse…", class = "btn-outline-secondary")
    ),
    helpText(
      "If set, uploaded files are copied into ", tags$code("<folder>/data/"),
      " and the report is written to ", tags$code("<folder>/output/"), "."
    ),
    uiOutput("path_controls"),

    hr(),
    tags$strong("4 · Processing steps"),
    uiOutput("steps_ui"),

    hr(),
    uiOutput("drift_method_ui"),
    uiOutput("ref_qc_ui"),
    uiOutput("reference_sample_ui"),

    hr(),
    checkboxGroupInput("formats", "Output format(s)",
      choices = c("HTML" = "html", "Word (.docx)" = "docx", "PDF (sans-serif)" = "pdf"),
      selected = "html")
  ),

  layout_columns(
    col_widths = c(5, 7),
    card(
      card_header("Validation"),
      uiOutput("issues")
    ),
    card(
      card_header(
        class = "d-flex justify-content-between align-items-center",
        "Generated workflow (.qmd)",
        div(
          class = "d-flex gap-2",
          tags$button(
            type = "button", class = "btn btn-outline-secondary btn-sm",
            onclick = paste0(
              "navigator.clipboard.writeText(",
              "document.getElementById('qmd_preview').innerText).then(()=>{",
              "this.innerText='Copied!';setTimeout(()=>this.innerText='Copy code',1200)})"
            ),
            "Copy code"
          ),
          downloadButton("download_qmd", "Download .qmd", class = "btn-primary btn-sm")
        )
      ),
      verbatimTextOutput("qmd_preview")
    )
  )
)

server <- function(input, output, session) {
  # ---- Data / metadata sources --------------------------------------------
  demo <- reactiveVal(NULL)
  csv_cfg <- reactiveValues(
    configured = FALSE, column_mapping = NULL,
    variable_name = "area", analysis_id_col = NA, first_feature_column = NA
  )

  observeEvent(input$load_demo, {
    demo(system.file("extdata", "MRMhub_demo.tsv", package = "mrmhub"))
    updateSelectInput(session, "importer", selected = "mrmhub")
    updateSelectInput(session, "metadata_route", selected = "embedded")
  })
  observeEvent(input$data_file, demo(NULL))

  data_path <- reactive({
    if (!is.null(demo())) return(demo())
    req(input$data_file)
    input$data_file$datapath
  })
  data_name <- reactive({
    if (!is.null(demo())) return("MRMhub_demo.tsv")
    if (!is.null(input$data_file)) return(input$data_file$name)
    NULL
  })
  has_data <- reactive(!is.null(demo()) || !is.null(input$data_file))
  is_generic_csv <- reactive(input$importer %in% c("csv_long", "csv_wide"))

  # Metadata input UI depends on the chosen source.
  output$metadata_inputs <- renderUI({
    switch(
      input$metadata_route,
      msorganiser = fileInput("metadata_file", "MSOrganiser file (.xlsx)", accept = ".xlsx"),
      tables = fileInput("metadata_file", "Metadata tables file (.xlsx)", accept = ".xlsx"),
      individual = tagList(
        fileInput("metadata_analyses", "Analyses metadata (.csv)", accept = c(".csv", ".tsv")),
        fileInput("metadata_features", "Features metadata (.csv)", accept = c(".csv", ".tsv")),
        fileInput("metadata_istds", "ISTDs metadata (.csv)", accept = c(".csv", ".tsv"))
      ),
      NULL # embedded / none: metadata comes from the data file, or none
    )
  })

  # Metadata argument for build_experiment(): a single path, or a named list of
  # per-table paths for the "individual" route.
  metadata_arg <- reactive({
    switch(
      input$metadata_route,
      individual = list(
        analyses = input$metadata_analyses$datapath,
        features = input$metadata_features$datapath,
        istds = input$metadata_istds$datapath
      ),
      msorganiser = ,
      tables = if (is.null(input$metadata_file)) NULL else input$metadata_file$datapath,
      NULL
    )
  })

  # Files to copy in project mode: (datapath, name) pairs for whatever metadata
  # inputs are present.
  meta_files_to_copy <- reactive({
    if (identical(input$metadata_route, "individual")) {
      fs <- Filter(Negate(is.null),
        list(input$metadata_analyses, input$metadata_features, input$metadata_istds))
      lapply(fs, function(f) list(datapath = f$datapath, name = f$name))
    } else if (!is.null(input$metadata_file)) {
      list(list(datapath = input$metadata_file$datapath, name = input$metadata_file$name))
    } else {
      list()
    }
  })

  # ---- Generic-CSV column configuration -----------------------------------
  csv_opts_r <- reactive({
    if (identical(input$importer, "csv_long")) {
      list(column_mapping = csv_cfg$column_mapping)
    } else if (identical(input$importer, "csv_wide")) {
      list(
        variable_name = csv_cfg$variable_name,
        analysis_id_col = csv_cfg$analysis_id_col,
        first_feature_column = csv_cfg$first_feature_column
      )
    } else {
      list()
    }
  })

  csv_modal <- function(cols) {
    if (identical(input$importer, "csv_long")) {
      modalDialog(
        title = "Map generic long-format columns", easyClose = TRUE,
        p("One row per analysis × feature. Tell MRMhub which columns hold the identifiers and the measured value."),
        selectInput("cfg_analysis_id", "Analysis id column", choices = cols,
          selected = guess_col(cols, c("analysis_id", "sample", "sample_name", "filename", "replicate"))),
        selectInput("cfg_feature_id", "Feature id column", choices = cols,
          selected = guess_col(cols, c("feature_id", "feature_name", "compound", "molecule", "transition"))),
        selectInput("cfg_value_col", "Value column", choices = cols,
          selected = guess_col(cols, c("area", "intensity", "height", "conc", "response"))),
        selectInput("cfg_value_type", "The value column represents", choices = long_value_types),
        footer = tagList(modalButton("Cancel"), actionButton("apply_csv", "Apply", class = "btn-primary"))
      )
    } else {
      modalDialog(
        title = "Configure generic wide-format import", easyClose = TRUE,
        p("One row per analysis, one column per feature."),
        selectInput("cfg_variable_name", "The matrix values represent", choices = wide_value_types),
        selectInput("cfg_analysis_id_col", "Analysis id column",
          choices = c("(auto: first column)" = "", cols)),
        numericInput("cfg_first_feature_column", "First feature column (number, optional)",
          value = NA, min = 2, step = 1),
        footer = tagList(modalButton("Cancel"), actionButton("apply_csv", "Apply", class = "btn-primary"))
      )
    }
  }

  # Reset configuration and auto-open the dialog when a generic CSV is chosen.
  observeEvent(list(input$importer, input$data_file, demo()), {
    csv_cfg$configured <- FALSE
    csv_cfg$column_mapping <- NULL
    if (is_generic_csv() && has_data()) {
      showModal(csv_modal(read_columns(data_path())))
    }
  }, ignoreInit = TRUE)

  observeEvent(input$open_csv_cfg, showModal(csv_modal(read_columns(data_path()))))

  observeEvent(input$apply_csv, {
    if (identical(input$importer, "csv_long")) {
      cm <- c(analysis_id = input$cfg_analysis_id, feature_id = input$cfg_feature_id)
      cm[[input$cfg_value_type]] <- input$cfg_value_col
      csv_cfg$column_mapping <- cm
    } else {
      csv_cfg$variable_name <- input$cfg_variable_name
      csv_cfg$analysis_id_col <- if (nzchar(input$cfg_analysis_id_col)) input$cfg_analysis_id_col else NA
      csv_cfg$first_feature_column <- if (isTRUE(is.na(input$cfg_first_feature_column))) {
        NA
      } else {
        as.integer(input$cfg_first_feature_column)
      }
    }
    csv_cfg$configured <- TRUE
    removeModal()
  })

  output$csv_config_ui <- renderUI({
    if (!is_generic_csv() || !has_data()) return(NULL)
    div(
      class = "mb-2",
      actionButton("open_csv_cfg", "Configure columns…", class = "btn-outline-secondary btn-sm"),
      if (isTRUE(csv_cfg$configured)) {
        span(class = "text-success ms-2", "✓ columns configured")
      } else {
        span(class = "text-warning ms-2", "⚠ columns need configuration")
      }
    )
  })

  # ---- Project folder -----------------------------------------------------
  observeEvent(input$browse_project, {
    p <- choose_dir_interactive()
    if (is.null(p)) {
      showNotification(
        "Could not open a folder dialog in this environment -- type or paste the folder path instead.",
        type = "warning", duration = 6
      )
    } else if (nzchar(p)) {
      updateTextInput(session, "project_dir", value = p)
    }
    # p == "" means the dialog opened and the user cancelled: do nothing.
  })

  project_mode <- reactive(nzchar(trimws(input$project_dir %||% "")))

  default_data_path <- reactive({
    if (!is.null(demo())) demo() else if (has_data()) data_name() else ""
  })

  output$path_controls <- renderUI({
    if (project_mode()) {
      tagList(
        tags$small(class = "text-muted d-block mb-2",
          "Workflow will reference ", tags$code(file.path("data", data_name() %||% "your_data")),
          " and write to ", tags$code("output/results.xlsx"), "."),
        actionButton("write_project", "Create project & write .qmd", class = "btn-success btn-sm")
      )
    } else {
      tagList(
        textInput("data_path_override", "Data file path (as written in the code)",
          value = default_data_path()),
        helpText(
          "Goes into the generated ", tags$code("import_data_*()"),
          " call — set it to where the data file will sit relative to the .qmd, ",
          "or an absolute path. (Set a project folder above to copy files and use ",
          tags$code("data/"), " automatically.)"
        ),
        textInput("output_xlsx", "Report output path", value = "results.xlsx")
      )
    }
  })

  data_qmd_path <- reactive({
    if (project_mode()) file.path("data", data_name() %||% "your_data.tsv")
    else (input$data_path_override %||% default_data_path())
  })
  # In project mode, a copied file is referenced as data/<name>; otherwise by name.
  ref_name <- function(nm) {
    if (is.null(nm)) return(NULL)
    if (project_mode()) file.path("data", nm) else nm
  }
  metadata_qmd_path <- reactive({
    if (is.null(input$metadata_file)) return(NULL)
    ref_name(input$metadata_file$name)
  })
  metadata_individual_qmd <- reactive({
    if (!identical(input$metadata_route, "individual")) return(NULL)
    nm <- function(f) if (is.null(f)) NULL else ref_name(f$name)
    list(
      analyses = nm(input$metadata_analyses),
      features = nm(input$metadata_features),
      istds = nm(input$metadata_istds)
    )
  })
  output_qmd_path <- reactive({
    if (project_mode()) "output/results.xlsx" else (input$output_xlsx %||% "results.xlsx")
  })

  # ---- Imported experiment (drives gating + validation) -------------------
  mexp_r <- reactive({
    # Return NULL (not req-halt) when there is nothing to import yet, so the step
    # list and other controls still render with their defaults.
    if (!has_data()) return(NULL)
    if (is_generic_csv() && !isTRUE(csv_cfg$configured)) return(NULL)
    tryCatch(
      suppressMessages(mrmhub:::build_experiment(
        data_path(), input$importer, metadata_arg(), input$metadata_route, csv_opts_r()
      )),
      error = function(e) e
    )
  })

  availability_r <- reactive({
    m <- mexp_r()
    mrmhub:::workflow_step_availability(if (inherits(m, "MRMhubExperiment")) m else NULL)
  })

  # ---- Dynamic step list: enable/disable by available metadata ------------
  output$steps_ui <- renderUI({
    av <- availability_r()
    rows <- lapply(av, function(s) {
      cb_id <- paste0("step_", s$id)
      if (s$enabled) {
        prev <- isolate(input[[cb_id]])
        checked <- if (!is.null(prev)) isTRUE(prev) else isTRUE(s$default_selected)
        div(class = "mb-1", checkboxInput(cb_id, s$label, value = checked))
      } else {
        div(
          class = "mb-1 d-flex align-items-center gap-2",
          tags$input(type = "checkbox", disabled = NA, class = "form-check-input flex-shrink-0"),
          span(class = "text-muted", s$label),
          span(class = "badge rounded-pill text-bg-warning", s$reason),
          bslib::tooltip(
            span(shiny::icon("circle-info"), class = "text-secondary", style = "cursor: help;"),
            s$detail
          )
        )
      }
    })
    tagList(rows)
  })

  selected_steps <- reactive({
    av <- availability_r()
    enabled_ids <- vapply(av, function(s) s$id, character(1))[
      vapply(av, function(s) isTRUE(s$enabled), logical(1))
    ]
    enabled_ids[vapply(enabled_ids, function(id) isTRUE(input[[paste0("step_", id)]]), logical(1))]
  })

  # ---- Contextual argument controls ---------------------------------------
  present_qc <- reactive({
    m <- mexp_r()
    if (inherits(m, "MRMhubExperiment")) {
      sort(unique(as.character(stats::na.omit(m@dataset$qc_type))))
    } else {
      character()
    }
  })

  # Reference QC rule: Gaussian kernel -> SPL; spline/loess -> first present of
  # BQC / TQC / QC. Batch correction reuses this (matches the drift method).
  auto_ref <- reactive({
    if (identical(input$drift_method %||% "gaussian", "gaussian")) {
      "SPL"
    } else {
      pick <- intersect(c("BQC", "TQC", "QC"), present_qc())
      if (length(pick) > 0) pick[1] else "BQC"
    }
  })

  needs_ref <- reactive(any(c("correct_drift", "correct_batch") %in% selected_steps()))

  output$drift_method_ui <- renderUI({
    if (!needs_ref()) return(NULL)
    selectInput("drift_method", "Drift method (also sets the batch reference)",
      choices = c("Gaussian kernel" = "gaussian", "Cubic spline" = "spline", "LOESS" = "loess"),
      selected = input$drift_method %||% "gaussian")
  })

  output$ref_qc_ui <- renderUI({
    if (!needs_ref()) return(NULL)
    choices <- present_qc()
    if (length(choices) == 0) choices <- c("SPL", "BQC", "TQC", "QC")
    selectInput("ref_qc_types", "Reference QC type(s) for drift / batch",
      choices = union(choices, auto_ref()), selected = auto_ref(), multiple = TRUE)
  })

  output$reference_sample_ui <- renderUI({
    if (!"calibrate_ref" %in% selected_steps()) return(NULL)
    m <- mexp_r()
    sids <- if (inherits(m, "MRMhubExperiment") && "sample_id" %in% names(m@annot_analyses)) {
      sort(unique(stats::na.omit(m@annot_analyses$sample_id)))
    } else {
      character()
    }
    selectInput("reference_sample_id", "Reference sample id", choices = sids)
  })

  # ---- Spec, preview, validation, outputs ---------------------------------
  spec_r <- reactive({
    list(
      importer = input$importer,
      data_path = data_qmd_path(),
      metadata_route = input$metadata_route,
      metadata_path = metadata_qmd_path(),
      metadata_individual = metadata_individual_qmd(),
      steps = selected_steps(),
      drift_method = input$drift_method %||% "gaussian",
      ref_qc_types = input$ref_qc_types,
      reference_sample_id = input$reference_sample_id,
      output_xlsx = output_qmd_path(),
      formats = input$formats %||% "html",
      column_mapping = if (identical(input$importer, "csv_long")) csv_cfg$column_mapping else NULL,
      variable_name = if (identical(input$importer, "csv_wide")) csv_cfg$variable_name else NULL,
      analysis_id_col = if (identical(input$importer, "csv_wide")) csv_cfg$analysis_id_col else NULL,
      first_feature_column = if (identical(input$importer, "csv_wide")) csv_cfg$first_feature_column else NULL
    )
  })

  output$qmd_preview <- renderText(generate_workflow_qmd(spec_r()))

  output$issues <- renderUI({
    if (!has_data()) {
      return(div(class = "text-muted", "Upload a data file or load the demo to validate."))
    }
    if (is_generic_csv() && !isTRUE(csv_cfg$configured)) {
      return(div(class = "alert alert-warning py-2 my-2",
        "Configure the generic-CSV columns to validate this data."))
    }
    res <- tryCatch(
      mrmhub:::validate_workflow_inputs(
        data_path(), input$importer, metadata_arg(), input$metadata_route,
        selected_steps(), csv_opts_r()
      ),
      error = function(e) mrmhub:::wf_issue("app", "error", conditionMessage(e))
    )
    palette <- c(error = "danger", warning = "warning", ok = "success")
    icons <- c(error = "✗", warning = "⚠", ok = "✓")
    tagList(lapply(seq_len(nrow(res)), function(i) {
      sev <- res$severity[i]
      div(
        class = paste0("alert alert-", palette[[sev]], " py-2 my-2"),
        tags$strong(paste0(icons[[sev]], " ")), res$message[i]
      )
    }))
  })

  output$download_qmd <- downloadHandler(
    filename = function() "mrmhub_workflow.qmd",
    content = function(file) writeLines(generate_workflow_qmd(spec_r()), file)
  )

  observeEvent(input$write_project, {
    req(project_mode(), data_path())
    proj <- normalizePath(trimws(input$project_dir), mustWork = FALSE)
    data_dir <- file.path(proj, "data")
    out_dir <- file.path(proj, "output")
    ok <- tryCatch({
      dir.create(data_dir, recursive = TRUE, showWarnings = FALSE)
      dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
      file.copy(data_path(), file.path(data_dir, data_name()), overwrite = TRUE)
      for (mf in meta_files_to_copy()) {
        file.copy(mf$datapath, file.path(data_dir, mf$name), overwrite = TRUE)
      }
      writeLines(generate_workflow_qmd(spec_r()), file.path(proj, "mrmhub_workflow.qmd"))
      TRUE
    }, error = function(e) {
      showNotification(paste("Could not write project:", conditionMessage(e)),
        type = "error", duration = 10)
      FALSE
    })
    if (isTRUE(ok)) {
      showNotification(
        paste0("Project written to ", proj, " (data/, output/, mrmhub_workflow.qmd)."),
        type = "message", duration = 10
      )
    }
  })
}

shinyApp(ui, server)
