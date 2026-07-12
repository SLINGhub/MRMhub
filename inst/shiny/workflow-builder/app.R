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
  "MRMhub / INTEGRATOR long" = "mrmhub",
  "MassHunter" = "masshunter",
  "Skyline" = "skyline",
  "Generic CSV (long)" = "csv_long",
  "Generic CSV (wide)" = "csv_wide"
)
metadata_choices <- c(
  "Embedded in data file" = "embedded",
  "MSOrganiser (.xlsx)" = "msorganiser",
  "Metadata tables (.xlsx)" = "tables",
  "None" = "none"
)

ui <- page_sidebar(
  title = "MRMhub Workflow Builder",
  theme = bs_theme(bootswatch = "sandstone"),

  sidebar = sidebar(
    width = 380,
    fileInput("data_file", "Data file", accept = c(".csv", ".tsv", ".txt")),
    selectInput("importer", "Importer", choices = importer_choices),
    fileInput("metadata_file", "Metadata file (optional)", accept = c(".xlsx", ".csv")),
    selectInput("metadata_route", "Metadata source", choices = metadata_choices),
    actionButton("load_demo", "Load bundled demo data", class = "btn-outline-secondary btn-sm"),

    hr(),
    textInput("project_dir", "Analysis project folder (optional)", placeholder = "/path/to/project"),
    helpText(
      "If set, uploaded files are copied into ", tags$code("<folder>/data/"),
      " and the report is written to ", tags$code("<folder>/output/"),
      ". Leave empty to reference the data file by path instead."
    ),
    uiOutput("path_controls"),

    hr(),
    tags$strong("Processing steps"),
    uiOutput("steps_ui"),

    hr(),
    selectInput("variable", "Variable to correct / plot",
      choices = c("conc", "norm_intensity", "intensity"), selected = "conc"),
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
        downloadButton("download_qmd", "Download .qmd", class = "btn-primary btn-sm")
      ),
      verbatimTextOutput("qmd_preview")
    )
  )
)

server <- function(input, output, session) {
  # ---- Data / metadata sources --------------------------------------------
  demo <- reactiveVal(NULL)

  observeEvent(input$load_demo, {
    demo(system.file("extdata", "MRMhub_demo.tsv", package = "mrmhub"))
    updateSelectInput(session, "importer", selected = "mrmhub")
    updateSelectInput(session, "metadata_route", selected = "embedded")
  })
  observeEvent(input$data_file, demo(NULL))

  # Real on-disk path used for import / copying.
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
  metadata_path <- reactive(if (is.null(input$metadata_file)) NULL else input$metadata_file$datapath)
  metadata_name <- reactive(if (is.null(input$metadata_file)) NULL else input$metadata_file$name)

  has_data <- reactive(!is.null(demo()) || !is.null(input$data_file))

  # ---- Project vs. portable path handling ---------------------------------
  project_mode <- reactive(nzchar(trimws(input$project_dir %||% "")))

  # Sensible default for the portable data-path field: an absolute path when we
  # know one (the demo), otherwise just the uploaded filename.
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
        textInput("data_path_override", "Path to data file in the workflow",
          value = default_data_path()),
        textInput("output_xlsx", "Report output path", value = "results.xlsx")
      )
    }
  })

  # Paths as they should appear inside the generated .qmd.
  data_qmd_path <- reactive({
    if (project_mode()) file.path("data", data_name() %||% "your_data.tsv")
    else (input$data_path_override %||% default_data_path())
  })
  metadata_qmd_path <- reactive({
    if (is.null(metadata_name())) return(NULL)
    if (project_mode()) file.path("data", metadata_name()) else metadata_name()
  })
  output_qmd_path <- reactive({
    if (project_mode()) "output/results.xlsx" else (input$output_xlsx %||% "results.xlsx")
  })

  # ---- Imported experiment (drives gating + validation) -------------------
  mexp_r <- reactive({
    req(data_path())
    tryCatch(
      suppressMessages(mrmhub:::build_experiment(
        data_path(), input$importer, metadata_path(), input$metadata_route
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

  # Selected steps = ticked AND currently enabled.
  selected_steps <- reactive({
    av <- availability_r()
    enabled_ids <- vapply(av, function(s) s$id, character(1))[
      vapply(av, function(s) isTRUE(s$enabled), logical(1))
    ]
    enabled_ids[vapply(enabled_ids, function(id) isTRUE(input[[paste0("step_", id)]]), logical(1))]
  })

  # ---- Contextual argument controls ---------------------------------------
  output$ref_qc_ui <- renderUI({
    m <- mexp_r()
    choices <- if (inherits(m, "MRMhubExperiment")) {
      sort(unique(as.character(stats::na.omit(m@dataset$qc_type))))
    } else {
      character()
    }
    if (length(choices) == 0) choices <- "SPL"
    selectInput("ref_qc_types", "Reference QC type(s) for drift / batch",
      choices = choices, selected = intersect("SPL", choices), multiple = TRUE)
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
      steps = selected_steps(),
      variable = input$variable,
      ref_qc_types = input$ref_qc_types,
      reference_sample_id = input$reference_sample_id,
      output_xlsx = output_qmd_path(),
      formats = input$formats %||% "html"
    )
  })

  output$qmd_preview <- renderText(generate_workflow_qmd(spec_r()))

  output$issues <- renderUI({
    if (!has_data()) {
      return(div(class = "text-muted", "Upload a data file or load the demo to validate."))
    }
    res <- tryCatch(
      mrmhub:::validate_workflow_inputs(
        data_path(), input$importer, metadata_path(), input$metadata_route, selected_steps()
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

  # Project mode: copy inputs into <project>/data/ and write the .qmd + output/.
  observeEvent(input$write_project, {
    req(project_mode(), data_path())
    proj <- normalizePath(trimws(input$project_dir), mustWork = FALSE)
    data_dir <- file.path(proj, "data")
    out_dir <- file.path(proj, "output")
    ok <- tryCatch({
      dir.create(data_dir, recursive = TRUE, showWarnings = FALSE)
      dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
      file.copy(data_path(), file.path(data_dir, data_name()), overwrite = TRUE)
      if (!is.null(metadata_path())) {
        file.copy(metadata_path(), file.path(data_dir, metadata_name()), overwrite = TRUE)
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
        paste0("Project written to ", proj,
          " (data/, output/, mrmhub_workflow.qmd)."),
        type = "message", duration = 10
      )
    }
  })
}

shinyApp(ui, server)
