library(shiny)
library(bslib)

ui <- page_navbar(

  title = "MRMhub Walkthrough",
  theme = bs_theme(bootswatch = "sandstone"),
  id = "main_nav",

  # Tab 1: Data Format Validator

  nav_panel(
    title = "Validate Data",
    icon = icon("check-circle"),
    layout_sidebar(
      sidebar = sidebar(
        fileInput("upload_data", "Upload your data file (.csv, .tsv)",
                  accept = c(".csv", ".tsv", ".txt")),
        selectInput("expected_format", "Expected format",
                    choices = c("MRMhub (long)" = "mrmhub",
                                "MassHunter (wide)" = "masshunter",
                                "Skyline (long)" = "skyline",
                                "Generic wide" = "wide",
                                "Generic long" = "long")),
        actionButton("validate_btn", "Validate", class = "btn-primary")
      ),
      card(
        card_header("Validation Results"),
        uiOutput("validation_results")
      ),
      card(
        card_header("Data Preview"),
        tableOutput("data_preview")
      )
    )
  ),

  # Tab 2: Workflow Guide
  nav_panel(
    title = "Workflow Guide",
    icon = icon("route"),
    layout_sidebar(
      sidebar = sidebar(
        h5("Answer these questions:"),
        selectInput("has_integrator", "Did you use INTEGRATOR?",
                    choices = c("Yes" = "yes", "No" = "no")),
        selectInput("data_source", "Data source software?",
                    choices = c("INTEGRATOR" = "mrmhub",
                                "MassHunter" = "masshunter",
                                "Skyline" = "skyline",
                                "Other" = "generic")),
        selectInput("need_drift", "Need drift/batch correction?",
                    choices = c("Not sure" = "unsure",
                                "Yes" = "yes",
                                "No" = "no")),
        selectInput("need_calibration", "Need external calibration?",
                    choices = c("No" = "no",
                                "Yes" = "yes")),
        actionButton("generate_code", "Generate Code", class = "btn-primary")
      ),
      card(
        card_header("Your Workflow"),
        verbatimTextOutput("workflow_code")
      ),
      card(
        card_header("Explanation"),
        uiOutput("workflow_explanation")
      )
    )
  ),

  # Tab 3: Results Explorer
  nav_panel(
    title = "Explore Results",
    icon = icon("chart-line"),
    layout_sidebar(
      sidebar = sidebar(
        fileInput("upload_rds", "Upload MRMhubExperiment (.rds)",
                  accept = ".rds"),
        uiOutput("explorer_controls")
      ),
      card(
        card_header("Summary"),
        verbatimTextOutput("exp_summary")
      ),
      card(
        card_header("Visualization"),
        plotOutput("exp_plot", height = "400px")
      )
    )
  )
)

server <- function(input, output, session) {


  # --- Tab 1: Validate Data ---
  uploaded_data <- reactive({
    req(input$upload_data)
    ext <- tools::file_ext(input$upload_data$name)
    if (ext %in% c("tsv", "txt")) {
      utils::read.delim(input$upload_data$datapath, nrows = 100)
    } else {
      utils::read.csv(input$upload_data$datapath, nrows = 100)
    }
  })

  output$data_preview <- renderTable({
    req(uploaded_data())
    head(uploaded_data(), 5)
  })

  observeEvent(input$validate_btn, {
    req(uploaded_data())
    df <- uploaded_data()
    fmt <- input$expected_format
    issues <- character(0)
    passes <- character(0)

    if (fmt %in% c("mrmhub", "long")) {
      required <- c("analysis_id", "feature_id")
      found <- required %in% names(df)
      if (all(found)) {
        passes <- c(passes, "✓ Required columns found: analysis_id, feature_id")
      } else {
        issues <- c(issues, paste("✗ Missing columns:", paste(required[!found], collapse = ", ")))
      }
      if ("area" %in% names(df)) {
        passes <- c(passes, "✓ 'area' column found")
      } else {
        issues <- c(issues, "⚠ No 'area' column — check if values are in another column")
      }
    }

    if (fmt %in% c("masshunter", "wide")) {
      if (ncol(df) > 3) {
        passes <- c(passes, paste("✓ Wide format detected:", ncol(df), "columns"))
      } else {
        issues <- c(issues, "⚠ Very few columns — expected samples × features matrix")
      }
    }

    # Check for common problems
    if (any(duplicated(names(df)))) {
      issues <- c(issues, "✗ Duplicate column names detected")
    }
    if (nrow(df) == 0) {
      issues <- c(issues, "✗ File appears empty")
    }

    output$validation_results <- renderUI({
      tags$div(
        if (length(passes) > 0) tags$div(
          style = "color: green;",
          lapply(passes, tags$p)
        ),
        if (length(issues) > 0) tags$div(
          style = "color: red;",
          lapply(issues, tags$p)
        ),
        if (length(issues) == 0) tags$p(
          style = "color: green; font-weight: bold;",
          "All checks passed! Your file looks ready for import."
        )
      )
    })
  })

  # --- Tab 2: Workflow Guide ---
  observeEvent(input$generate_code, {
    src <- input$data_source
    drift <- input$need_drift
    calib <- input$need_calibration

    import_fn <- switch(src,
      mrmhub = 'import_data_mrmhub("your_data.tsv")',
      masshunter = 'import_data_masshunter("your_data.csv")',
      skyline = 'import_data_skyline("your_data.csv")',
      generic = 'import_data_csv_long("your_data.csv")'
    )

    lines <- c(
      "library(mrmhub)",
      "",
      "# 1. Import data",
      paste0("exp <- ", import_fn),
      ""
    )

    if (drift %in% c("yes", "unsure")) {
      lines <- c(lines,
        "# 2. Apply drift/batch correction",
        "exp <- correct_drift(exp)",
        ""
      )
    }

    if (calib == "yes") {
      lines <- c(lines,
        "# 3. External calibration",
        "exp <- calibrate_external(exp)",
        ""
      )
    }

    lines <- c(lines,
      "# Final: Export results",
      'export_xlsx(exp, "results.xlsx")'
    )

    output$workflow_code <- renderText(paste(lines, collapse = "\n"))

    output$workflow_explanation <- renderUI({
      tags$div(
        tags$p("This code provides a starting template for your workflow."),
        tags$p("Copy it into your R script and adjust file paths and parameters."),
        tags$p(tags$a(href = "https://slinghub.github.io/MRMhub/articles/tutorial-00-first-analysis.html",
                      "See the full tutorial for details."))
      )
    })
  })

  # --- Tab 3: Results Explorer ---
  exp_data <- reactive({
    req(input$upload_rds)
    readRDS(input$upload_rds$datapath)
  })

  output$explorer_controls <- renderUI({
    req(exp_data())
    tagList(
      selectInput("plot_type", "Plot type",
                  choices = c("Run scatter" = "runscatter",
                              "CV distribution" = "cv",
                              "PCA" = "pca"))
    )
  })

  output$exp_summary <- renderPrint({
    req(exp_data())
    exp_data()
  })

  output$exp_plot <- renderPlot({
    req(exp_data(), input$plot_type)
    # Placeholder - actual plotting depends on mrmhub plot functions
    plot(1, type = "n", main = "Upload an MRMhubExperiment to visualize")
  })
}

shinyApp(ui, server)
