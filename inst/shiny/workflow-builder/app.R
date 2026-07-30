# MRMhub Workflow Builder -- thin Shiny UI over the pure generator/validator in
# R/build-workflow.R. Launched by mrmhub::build_workflow(). The heavy lifting
# (generate_workflow_qmd(), workflow_steps(), workflow_step_availability(),
# workflow_step_issues()) lives in the package; this file only wires inputs to
# those functions and presents the result. It is a "get started / learn MRMhub"
# tool, not a full UI for the package -- kept deliberately small and lenient.

library(shiny)
library(bslib)
library(mrmhub)

# Raise Shiny's default 5 MB upload cap -- INTEGRATOR long.csv files are larger.
options(shiny.maxRequestSize = 500 * 1024^2)

# `%||%` is a base operator only from R 4.4; define it for older R.
`%||%` <- function(x, y) if (is.null(x) || length(x) == 0) y else x

# Brand palette -- mirrors docs-site/_brand.yml (steel blue + navy) and the wider
# set in plan-workflowDiagrams.prompt.md. Mirrored inline (not read from
# _brand.yml) so the app carries no extra runtime dependency, exactly as the
# pkgdown site mirrors the same values in _pkgdown.yml.
mrm <- list(
  blue = "#5B8FA8",
  navy = "#2C3E50",
  orange = "#D4914E",
  green = "#6B9E5E",
  rose = "#C27171",
  mist = "#F5F6F7"
)

importer_choices <- c(
  "MRMhub-INTEGRATOR (long .csv/.tsv)" = "mrmhub",
  "Agilent MassHunter (.csv)" = "masshunter",
  "Skyline (.csv)" = "skyline",
  "Generic long CSV (one row per analysis x feature)" = "csv_long",
  "Generic wide CSV (analyses x features matrix)" = "csv_wide"
)
# Three metadata sources: read from the data file, or attach one workbook.
metadata_choices <- c(
  "Embedded in the data file" = "embedded",
  "MSOrganiser workbook (.xlsx)" = "msorganiser",
  "Metadata tables (.xlsx)" = "tables"
)
# Optional dataset_orig columns that signal embedded (in-file) metadata.
embedded_hint_cols <- c(
  "sample_type",
  "qc_type",
  "analysis_order",
  "batch_id",
  "feature_class",
  "chem_formula",
  "molecular_weight",
  "precursor_mz",
  "product_mz",
  "istd_feature_id",
  "is_quantifier"
)
long_value_types <- c(
  "Peak area" = "feature_area",
  "Peak height" = "feature_height",
  "Intensity" = "feature_intensity",
  "Concentration" = "feature_conc",
  "Normalised intensity" = "feature_norm_intensity"
)
wide_value_types <- c(
  "Peak area" = "area",
  "Peak height" = "height",
  "Intensity" = "intensity",
  "Concentration" = "conc",
  "Normalised intensity" = "norm_intensity",
  "Response" = "response"
)
# Pooled QC types usable as a drift/batch reference (study samples excluded).
# Sourced from the package's single source of truth, not hard-coded here.
drift_ref_pool <- setdiff(
  mrmhub:::pkg.env$qc_type_annotation$qc_type_levels_nonblank,
  "SPL"
)

# Read just the column names of a delimited file (for the mapping dialog).
read_columns <- function(path) {
  ext <- tolower(tools::file_ext(path))
  sep <- if (ext %in% c("tsv", "txt")) "\t" else ","
  tryCatch(
    names(readr::read_delim(
      path,
      delim = sep,
      n_max = 0,
      show_col_types = FALSE
    )),
    error = function(e) character()
  )
}

# First column whose name matches any of `patterns` (case-insensitive), else the
# first column -- a sensible default selection in the mapping dialog.
guess_col <- function(cols, patterns) {
  if (length(cols) == 0) return(NULL)
  hit <- which(tolower(cols) %in% tolower(patterns))
  if (length(hit) == 0) {
    hit <- which(Reduce(
      `|`,
      lapply(patterns, function(p) grepl(p, cols, ignore.case = TRUE))
    ))
  }
  if (length(hit) > 0) cols[hit[1]] else cols[1]
}

# A coloured numbered disc + label, used for the sidebar section headers so they
# echo the numbered steps on the welcome screen.
section_badge <- function(n, color, label) {
  tagList(
    span(
      class = "d-inline-flex align-items-center justify-content-center fw-bold text-white me-2",
      style = sprintf(
        "width:1.4rem;height:1.4rem;border-radius:50%%;background:%s;font-size:.8rem;flex:0 0 auto;",
        color
      ),
      n
    ),
    span(label)
  )
}

# One friendly numbered step on the welcome screen: a coloured disc + title/body.
welcome_step <- function(n, color, title, body) {
  div(
    class = "d-flex align-items-start gap-3",
    span(
      class = "d-flex align-items-center justify-content-center fw-bold flex-shrink-0 text-white",
      style = sprintf(
        "width:2rem;height:2rem;border-radius:50%%;background:%s;",
        color
      ),
      n
    ),
    div(
      div(class = "fw-semibold", title),
      div(class = "small", body)
    )
  )
}

# Slim, colourful status banner (bslib contextual theme colours + white/dark
# text). `details` is an optional issues tibble shown behind a disclosure.
status_bar <- function(theme, title, subtitle = NULL, details = NULL) {
  ic <- switch(
    theme,
    success = "circle-check",
    warning = "triangle-exclamation",
    danger = "circle-exclamation",
    "circle-info"
  )
  txt <- if (identical(theme, "warning")) "text-dark" else "text-white"
  div(
    class = sprintf(
      "d-flex align-items-start gap-3 p-3 rounded-3 h-100 bg-%s %s",
      theme,
      txt
    ),
    span(icon(ic), style = "font-size:1.5rem;line-height:1.3;"),
    div(
      class = "flex-grow-1",
      div(class = "fw-bold", title),
      if (!is.null(subtitle)) div(class = "small", subtitle),
      if (!is.null(details) && nrow(details) > 0) {
        tags$details(
          class = "mt-1",
          tags$summary(
            class = "small",
            sprintf(
              "Show %d detail%s",
              nrow(details),
              if (nrow(details) > 1) "s" else ""
            )
          ),
          tags$ul(
            class = "small mb-0 mt-1",
            lapply(
              seq_len(nrow(details)),
              function(i) tags$li(details$message[i])
            )
          )
        )
      }
    )
  )
}

# ---- Static main-area panels -----------------------------------------------

# Welcome screen -- shown until a data file is loaded. Explains where data comes
# from, offers the bundled example, and lays out the three-step flow.
welcome_panel <- card(
  class = "mx-auto border-0 shadow-sm",
  style = "max-width: 900px;",
  card_body(
    class = "py-3",
    # Hero: small hex, title, one-line subtitle, and the primary actions -- kept
    # tight so the buttons sit above the fold in a normal-sized window.
    div(
      class = "text-center",
      tags$img(
        src = "logo.png",
        alt = "MRMhub hex logo",
        height = "84",
        class = "mb-2"
      ),
      tags$h4(
        class = "fw-bold mb-1",
        style = sprintf("color:%s;", mrm$navy),
        "Build a MRMhub workflow"
      ),
      tags$p(
        class = "mb-1",
        "Select your data file into a runnable Quarto (.qmd) analysis notebook, customize and download."
      ),
      tags$p(
        class = "small fw-semibold mb-2",
        style = sprintf("color:%s;", mrm$blue),
        icon("graduation-cap"),
        " A hands-on way to learn MRMhub."
      ),
      div(
        class = "d-flex flex-wrap gap-2 justify-content-center mb-1",
        actionButton(
          "load_demo",
          tagList(icon("play"), " Load example"),
          class = "btn-primary"
        ),
        downloadButton(
          "download_example",
          "Download example data",
          class = "btn-outline-primary",
          # Tell the user where the zip landed + to unzip it (the download is
          # client-side, so nudge a server-side notification on click).
          onclick = "Shiny.setInputValue('example_downloaded', Date.now(), {priority: 'event'})"
        )
      ),
      tags$p(
        class = "small mb-0",
        "New here? The example loads a small bundled demo dataset, metadata included."
      )
    ),
    hr(class = "my-3"),
    # Two compact columns (stack on narrow screens): where the data comes from,
    # and the three-step flow.
    layout_columns(
      col_widths = c(6, 6),
      div(
        tags$h6(class = "fw-bold mb-2", "Where does the data come from?"),
        tags$ul(
          class = "small mb-0 ps-3",
          tags$li(
            tags$strong("MRMhub-INTEGRATOR"),
            " -- (long ",
            tags$code(".csv/.tsv"),
            ")"
          ),
          tags$li(
            tags$strong("Agilent MassHunter"),
            " or ",
            tags$strong("Skyline"),
            " -- (",
            tags$code(".csv"),
            ")"
          ),
          tags$li(
            tags$strong("Plain CSV"),
            " (long or wide) ",
            tags$em("with"),
            " column mapping."
          )
        )
      ),
      div(
        tags$h6(class = "fw-bold mb-2", "Three steps to your report"),
        div(
          class = "d-flex flex-column gap-2",
          welcome_step(
            1,
            mrm$blue,
            "Point at your data",
            "Pick the tool or format that produced it, then upload."
          ),
          welcome_step(
            2,
            mrm$green,
            "Choose your steps",
            "Tick the steps -- the builder checks them against your metadata."
          ),
          welcome_step(
            3,
            mrm$rose,
            "Download & render",
            "Save the .qmd, open it in your editor, and render."
          )
        )
      )
    ),
    tags$p(
      class = "small mt-3 mb-0",
      "More detail: the ",
      tags$a(
        href = "https://slinghub.github.io/MRMhub/quant/articles/tutorial-12-workflow-builder.html",
        target = "_blank",
        "workflow-builder guide"
      ),
      " and the ",
      tags$a(
        href = "https://slinghub.github.io/MRMhub/",
        target = "_blank",
        "MRMhub website"
      ),
      "."
    )
  )
)

ui <- page_sidebar(
  title = tagList(
    tags$span(
      class = "wb-title",
      style = "color:#fff;",
      "MRMhub Workflow Builder"
    ),
    div(
      id = "wb-header-right",
      class = "d-flex align-items-center gap-3",
      # ? + QUANT manual -- one link to the online documentation.
      tags$a(
        href = "https://slinghub.github.io/MRMhub/quant/",
        target = "_blank",
        rel = "noopener",
        class = "wb-headlink small",
        title = "MRMhub documentation",
        icon("circle-question"),
        " QUANT manual"
      ),
      # Hex -- the online MRMhub (QUANT) documentation home.
      tags$a(
        href = "https://slinghub.github.io/MRMhub/quant/",
        target = "_blank",
        rel = "noopener",
        title = "MRMhub documentation",
        tags$img(
          src = "logo.png",
          alt = "MRMhub documentation",
          style = "height:34px;width:auto;"
        )
      )
    )
  ),
  # Brand colours mirrored from docs-site/_brand.yml (see `mrm` above). No
  # bootswatch preset -- the semantic contextual colours carry the identity.
  theme = bs_theme(
    version = 5,
    primary = mrm$blue,
    success = mrm$green,
    warning = mrm$orange,
    danger = mrm$rose
  ),

  sidebar = sidebar(
    width = 380,

    tags$head(
      tags$style(HTML(
        "
      /* Brand identity (palette mirrors docs-site/_brand.yml): navy header, soft
         app background, white sidebar + cards so the content panels stand out. */
      .navbar.navbar-static-top { background-color: #2C3E50; box-shadow: 0 1px 4px rgba(44,62,80,.18); position: relative; }
      .navbar.navbar-static-top .navbar-brand,
      .navbar.navbar-static-top .bslib-page-title,
      .wb-title { color: #fff !important; font-weight: 600; }
      /* Header actions pinned to the top-right (home, help, manual, hex logo). */
      #wb-header-right { position: absolute; right: 1rem; top: 50%; transform: translateY(-50%); }
      .wb-headlink, .wb-headlink:hover, #wb-header-right a { color: #fff !important; text-decoration: none; }
      .wb-headlink { font-size: 1.15rem; opacity: .9; }
      .wb-headlink.small { font-size: .85rem; }
      .wb-headlink:hover { opacity: 1; }
      body { background-color: #F5F6F7; }
      .bslib-sidebar-layout > .sidebar { background-color: #fff; }
      /* Soft grey-blue tint on inputs so they read as interactive. */
      .form-control, .form-select { background-color: #F4F7F9; }
      .form-control:focus, .form-select:focus { border-color: #5B8FA8; box-shadow: 0 0 0 .2rem rgba(91,143,168,.18); }
      .input-group-text { background-color: #EBF0F3; }
      /* Primary (steel-blue) buttons: force white label (BS auto-picks dark). */
      .btn-primary, .btn-primary:hover, .btn-primary:focus, .btn-primary:active { color: #fff !important; }
      /* One scrollbar only: the panel scrolls as a whole and the preview grows
         to fit its content (no inner vertical scrollbar -> no double scrollbar). */
      #qmd_preview { overflow-x: auto; margin: 0; }
      /* Prominent square Home (start-over) button beside the status banner. */
      .wb-home-btn { flex: 0 0 92px; width: 92px; border: 2px solid #5B8FA8; border-radius: .75rem; background: #fff; color: #2C3E50; }
      .wb-home-btn:hover, .wb-home-btn:focus { background: #5B8FA8; color: #fff; }
      .wb-home-btn .fa, .wb-home-btn svg { font-size: 1.7rem; }
      /* Collapsible section headers: a very light grey-blue tint so tiles read as distinct. */
      .bslib-sidebar-layout .accordion-button { background-color: #F4F7F9; }
      .bslib-sidebar-layout .accordion-button:not(.collapsed) { background-color: #EBF0F3; color: #2C3E50; box-shadow: none; }
      /* Each collapsible section reads as its own card (matching section 1). */
      .bslib-sidebar-layout .accordion-item { margin-bottom: .6rem; border: 1px solid var(--bs-border-color, #dee2e6); border-radius: .5rem; overflow: hidden; }
      /* qmd syntax tokens (lightweight in-app highlighter). */
      #qmd_preview .tok-fence { color: #8a949e; }
      #qmd_preview .tok-head  { color: #2C3E50; font-weight: 600; }
      #qmd_preview .tok-opt   { color: #5B8FA8; }
      #qmd_preview .tok-com   { color: #6B9E5E; }
      #qmd_preview .tok-str   { color: #C27171; }
      #qmd_preview .tok-fn    { color: #2C3E50; font-weight: 600; }
      /* compact sidebar rhythm */
      .sidebar hr { margin: .5rem 0; }
      #steps_ui .shiny-input-container, #steps_ui .form-check { margin-bottom: .15rem; }
    "
      )),
      tags$script(src = "highlight.js")
    ),

    # Section 1 lives in its own always-open accordion so it matches the tiles
    # for sections 2–4 below. Wrapped in a plain div so bslib does not full-bleed
    # it to the sidebar edges (a direct-child accordion is offset from the nested
    # tiles below, which sit inside the conditionalPanel wrapper).
    div(
      accordion(
        accordion_panel(
          section_badge(1, mrm$blue, "Data source"),
          value = "data",
          selectInput(
            "importer",
            "Where does your data come from?",
            choices = importer_choices
          ),
          fileInput(
            "data_file",
            "Data file",
            accept = c(".csv", ".tsv", ".txt")
          ),
          uiOutput("csv_config_ui")
        )
      )
    ),

    # Sections 2–4 -- collapsed into an accordion to keep the sidebar compact --
    # appear once a data file has been loaded. ("Home" lives in the header.)
    conditionalPanel(
      condition = "output.has_data",

      accordion(
        open = c("metadata", "steps"),
        accordion_panel(
          section_badge(2, mrm$green, "Metadata"),
          value = "metadata",
          radioButtons(
            "metadata_route",
            "Metadata source",
            choices = metadata_choices,
            selected = "embedded"
          ),
          uiOutput("metadata_inputs")
        ),
        accordion_panel(
          section_badge(3, mrm$orange, "Processing steps"),
          value = "steps",
          uiOutput("steps_ui")
        ),
        accordion_panel(
          section_badge(4, mrm$rose, "Report format"),
          value = "output",
          checkboxGroupInput(
            "formats",
            "Render the report to",
            choices = c(
              "HTML" = "html",
              "Word (.docx)" = "docx",
              "PDF" = "pdf"
            ),
            selected = "html"
          ),
          tags$p(
            class = "small mb-0 mt-1",
            "The generated .qmd renders to the format(s) you tick."
          )
        )
      )
    )
  ),

  # Welcome screen before any data; the builder view once data is loaded.
  conditionalPanel("!output.has_data", welcome_panel),
  conditionalPanel(
    "output.has_data",
    # Status banner + a prominent square Home (start-over) button beside it.
    div(
      class = "d-flex align-items-stretch gap-3 mb-3",
      div(class = "flex-grow-1", uiOutput("status_banner")),
      tags$a(
        href = "#",
        onclick = "location.reload(); return false;",
        class = "wb-home-btn d-flex flex-column align-items-center justify-content-center text-decoration-none flex-shrink-0",
        title = "Start over from the beginning",
        icon("house"),
        tags$span(class = "small fw-semibold mt-1", "Home")
      )
    ),
    card(
      class = "border-0 shadow-sm",
      card_header(
        class = "d-flex justify-content-between align-items-center fw-semibold",
        tagList(icon("file-code"), " Generated workflow (.qmd)"),
        div(
          class = "d-flex gap-2",
          tags$button(
            type = "button",
            class = "btn btn-outline-secondary btn-sm",
            onclick = paste0(
              "navigator.clipboard.writeText(",
              "document.getElementById('qmd_preview').innerText).then(()=>{",
              "this.innerText='Copied!';setTimeout(()=>this.innerText='Copy code',1200)})"
            ),
            "Copy code"
          ),
          downloadButton(
            "download_qmd",
            "Download .qmd",
            class = "btn-primary btn-sm"
          )
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
    configured = FALSE,
    column_mapping = NULL,
    variable_name = "area",
    analysis_id_col = NA,
    first_feature_column = NA
  )

  observeEvent(input$load_demo, {
    demo(system.file("extdata", "MRMhub_demo.tsv", package = "mrmhub"))
    updateSelectInput(session, "importer", selected = "mrmhub")
    updateRadioButtons(session, "metadata_route", selected = "embedded")
  })
  observeEvent(input$data_file, demo(NULL))
  # The bundled demo is an MRMhub-INTEGRATOR file. If the user switches to a
  # different importer, drop the demo so it is not parsed with the wrong reader.
  observeEvent(
    input$importer,
    if (!is.null(demo()) && !identical(input$importer, "mrmhub")) demo(NULL),
    ignoreInit = TRUE
  )

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

  # Drives the conditionalPanels (welcome vs builder, and sidebar sections 2–4).
  output$has_data <- reactive(has_data())
  outputOptions(output, "has_data", suspendWhenHidden = FALSE)

  # Bundled example available to download -- the demo data plus a blank metadata
  # template (zipped) so a newcomer sees both the data and the metadata format.
  output$download_example <- downloadHandler(
    filename = function() "MRMhub_example.zip",
    content = function(file) {
      files <- c(
        system.file("extdata", "MRMhub_demo.tsv", package = "mrmhub"),
        system.file(
          "extdata",
          "mrmhub_metadata_templates.xlsx",
          package = "mrmhub"
        )
      )
      files <- files[nzchar(files)]
      utils::zip(zipfile = file, files = files, flags = "-jq")
    }
  )

  # Confirm the download and tell the user to unzip it (the browser saves the
  # zip on its own, so this is the only feedback we can give).
  observeEvent(input$example_downloaded, {
    showNotification(
      tagList(
        tags$strong("Example data downloaded."),
        tags$br(),
        "Find ",
        tags$code("MRMhub_example.zip"),
        " in your browser's downloads (usually the ",
        tags$strong("Downloads"),
        " folder), then ",
        tags$strong("unzip"),
        " it. Upload ",
        tags$code("MRMhub_demo.tsv"),
        " above and keep ",
        tags$strong("Metadata source = Embedded"),
        " -- the demo carries its own metadata. The included ",
        tags$code(".xlsx"),
        " is a ",
        tags$strong("Metadata tables"),
        " workbook: pick that source if you adapt it for your own data."
      ),
      type = "message",
      duration = 20
    )
  })

  # Metadata input UI depends on the chosen source.
  output$metadata_inputs <- renderUI({
    switch(
      input$metadata_route,
      msorganiser = ,
      tables = fileInput(
        "metadata_file",
        "Metadata file (.xlsx)",
        accept = c(".xlsx")
      ),
      embedded = tags$p(
        class = "small mb-2",
        "Metadata are read directly from the data."
      ),
      NULL
    )
  })

  # Metadata file (datapath for validation; name for the generated data/ path).
  meta_selected <- reactive({
    input$metadata_route %in%
      c("msorganiser", "tables") &&
      !is.null(input$metadata_file)
  })
  metadata_arg <- reactive({
    if (meta_selected()) input$metadata_file$datapath else NULL
  })
  metadata_name <- reactive({
    if (meta_selected()) input$metadata_file$name else NULL
  })

  # Light format check on an uploaded metadata workbook: confirm it is a
  # readable .xlsx and that its sheets match the chosen source, so a mismatched
  # file is caught here rather than surfacing later as a cryptic import error.
  observeEvent(input$metadata_file, {
    req(input$metadata_file)
    sheets <- tryCatch(
      openxlsx2::wb_get_sheet_names(
        openxlsx2::wb_load(input$metadata_file$datapath)
      ),
      error = function(e) NULL
    )
    if (is.null(sheets)) {
      showNotification(
        "Could not read that file as an Excel (.xlsx) workbook -- please upload a valid .xlsx metadata file.",
        type = "error",
        duration = 8
      )
      return()
    }
    # A Metadata-tables workbook has plain "Analyses"/"Features"/"ISTDs" sheets;
    # an MSOrganiser workbook uses "Analyses (Samples)"/"Internal Standards".
    has_tables <- any(c("Analyses", "Features", "ISTDs") %in% sheets)
    looks_msorg <- any(
      c("Internal Standards", "Analyses (Samples)") %in% sheets
    )
    if (identical(input$metadata_route, "tables") && !has_tables) {
      msg <- if (looks_msorg) {
        tagList(
          tags$strong("This is an MSOrganiser workbook."),
          tags$br(),
          "Its sheets (",
          tags$code("Analyses (Samples)"),
          ", ",
          tags$code("Internal Standards"),
          ", ...) are the MSOrganiser layout. Choose ",
          tags$strong("MSOrganiser workbook"),
          " as the metadata source instead."
        )
      } else {
        tagList(
          tags$strong("This doesn't look like a Metadata tables workbook."),
          tags$br(),
          "It has no ",
          tags$code("Analyses"),
          " / ",
          tags$code("Features"),
          " / ",
          tags$code("ISTDs"),
          " sheet."
        )
      }
      showNotification(msg, type = "warning", duration = 10)
    } else if (
      identical(input$metadata_route, "msorganiser") &&
        has_tables &&
        !looks_msorg
    ) {
      showNotification(
        tagList(
          tags$strong("This looks like a Metadata tables workbook."),
          tags$br(),
          "It has ",
          tags$code("Analyses"),
          "/",
          tags$code("Features"),
          "/",
          tags$code("ISTDs"),
          " sheets -- choose ",
          tags$strong("Metadata tables (.xlsx)"),
          " as the source instead."
        ),
        type = "warning",
        duration = 10
      )
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
        title = "Map generic long-format columns",
        easyClose = TRUE,
        p(
          "One row per analysis × feature. Tell MRMhub which columns hold the identifiers and the measured value."
        ),
        selectInput(
          "cfg_analysis_id",
          "Analysis id column",
          choices = cols,
          selected = guess_col(
            cols,
            c("analysis_id", "sample", "sample_name", "filename", "replicate")
          )
        ),
        selectInput(
          "cfg_feature_id",
          "Feature id column",
          choices = cols,
          selected = guess_col(
            cols,
            c(
              "feature_id",
              "feature_name",
              "compound",
              "molecule",
              "transition"
            )
          )
        ),
        selectInput(
          "cfg_value_col",
          "Value column",
          choices = cols,
          selected = guess_col(
            cols,
            c("area", "intensity", "height", "conc", "response")
          )
        ),
        selectInput(
          "cfg_value_type",
          "The value column represents",
          choices = long_value_types
        ),
        footer = tagList(
          modalButton("Cancel"),
          actionButton("apply_csv", "Apply", class = "btn-primary")
        )
      )
    } else {
      modalDialog(
        title = "Configure generic wide-format import",
        easyClose = TRUE,
        p("One row per analysis, one column per feature."),
        selectInput(
          "cfg_variable_name",
          "The matrix values represent",
          choices = wide_value_types
        ),
        selectInput(
          "cfg_analysis_id_col",
          "Analysis id column",
          choices = c("(auto: first column)" = "", cols)
        ),
        numericInput(
          "cfg_first_feature_column",
          "First feature column (number, optional)",
          value = NA,
          min = 2,
          step = 1
        ),
        footer = tagList(
          modalButton("Cancel"),
          actionButton("apply_csv", "Apply", class = "btn-primary")
        )
      )
    }
  }

  # Reset configuration and auto-open the dialog when a generic CSV is chosen.
  observeEvent(
    list(input$importer, input$data_file, demo()),
    {
      csv_cfg$configured <- FALSE
      csv_cfg$column_mapping <- NULL
      if (is_generic_csv() && has_data()) {
        showModal(csv_modal(read_columns(data_path())))
      }
    },
    ignoreInit = TRUE
  )

  observeEvent(
    input$open_csv_cfg,
    showModal(csv_modal(read_columns(data_path())))
  )

  observeEvent(input$apply_csv, {
    if (identical(input$importer, "csv_long")) {
      cm <- c(
        analysis_id = input$cfg_analysis_id,
        feature_id = input$cfg_feature_id
      )
      cm[[input$cfg_value_type]] <- input$cfg_value_col
      csv_cfg$column_mapping <- cm
    } else {
      csv_cfg$variable_name <- input$cfg_variable_name
      csv_cfg$analysis_id_col <- if (nzchar(input$cfg_analysis_id_col)) {
        input$cfg_analysis_id_col
      } else {
        NA
      }
      csv_cfg$first_feature_column <- if (
        isTRUE(is.na(input$cfg_first_feature_column))
      ) {
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
      actionButton(
        "open_csv_cfg",
        "Configure columns…",
        class = "btn-outline-secondary btn-sm"
      ),
      if (isTRUE(csv_cfg$configured)) {
        span(
          class = "ms-2 fw-semibold",
          style = sprintf("color:%s;", mrm$green),
          "✓ columns configured"
        )
      } else {
        span(
          class = "ms-2 fw-semibold",
          style = sprintf("color:%s;", mrm$orange),
          "⚠ columns need configuration"
        )
      }
    )
  })

  # ---- Generated file paths (always relative to a local data/ folder) ------
  data_qmd_path <- reactive(file.path("data", data_name() %||% "your_data.tsv"))
  metadata_qmd_path <- reactive({
    nm <- metadata_name()
    if (is.null(nm)) NULL else file.path("data", nm)
  })
  output_qmd_path <- reactive("results.xlsx")

  # ---- Imported experiment (drives gating + validation) -------------------
  mexp_r <- reactive({
    # Return NULL (not req-halt) when there is nothing to import yet, so the step
    # list and other controls still render with their defaults.
    if (!has_data()) return(NULL)
    if (is_generic_csv() && !isTRUE(csv_cfg$configured)) return(NULL)
    withProgress(message = "Importing data & metadata…", value = 1, {
      tryCatch(
        suppressMessages(mrmhub:::build_experiment(
          data_path(),
          input$importer,
          metadata_arg(),
          input$metadata_route,
          csv_opts_r()
        )),
        error = function(e) e
      )
    })
  })

  # Whether dataset_orig carries embedded-metadata hint columns. These columns
  # are present in dataset_orig regardless of the metadata route, so reuse the
  # already-imported experiment (no second parse of a possibly-large file) and
  # only fall back to a clean metadata-off probe when the import itself failed
  # (e.g. a malformed embedded block) so the hints are still detected.
  has_embedded_metadata <- reactive({
    if (!has_data()) return(FALSE)
    if (is_generic_csv() && !isTRUE(csv_cfg$configured)) return(FALSE)
    m <- mexp_r()
    if (inherits(m, "MRMhubExperiment")) {
      return(any(embedded_hint_cols %in% names(m@dataset_orig)))
    }
    m2 <- withProgress(message = "Reading your data file…", value = 1, {
      tryCatch(
        suppressMessages(mrmhub:::build_experiment(
          data_path(),
          input$importer,
          NULL,
          "none",
          csv_opts_r()
        )),
        error = function(e) NULL
      )
    })
    inherits(m2, "MRMhubExperiment") &&
      any(embedded_hint_cols %in% names(m2@dataset_orig))
  })

  # Offer "Embedded in the data file" only when the data actually carries it.
  # Before a file is loaded we can't tell, so keep the full choice set (with
  # "embedded" as the default) and only narrow it once there is data to judge --
  # otherwise the startup pass would strip "embedded" and the demo loader could
  # not select it back.
  observeEvent(
    has_embedded_metadata(),
    {
      if (!has_data()) return()
      ch <- if (has_embedded_metadata()) {
        metadata_choices
      } else {
        metadata_choices[metadata_choices != "embedded"]
      }
      sel <- if (isTRUE(input$metadata_route %in% ch)) {
        input$metadata_route
      } else {
        unname(ch[[1]])
      }
      updateRadioButtons(
        session,
        "metadata_route",
        choices = ch,
        selected = sel
      )
    },
    ignoreNULL = FALSE
  )

  availability_r <- reactive({
    m <- mexp_r()
    mrmhub:::workflow_step_availability(
      if (inherits(m, "MRMhubExperiment")) m else NULL
    )
  })

  # ---- Dynamic step list: enable/disable by available metadata ------------
  # Quantitation is kept to internal-standard only here (calibration + reference
  # calibration are full-package steps, out of scope for this get-started tool).
  hidden_steps <- c("quantify_cal", "calibrate_ref")

  output$steps_ui <- renderUI({
    av <- Filter(function(s) !s$id %in% hidden_steps, availability_r())
    rows <- lapply(av, function(s) {
      cb_id <- paste0("step_", s$id)
      if (s$enabled) {
        prev <- isolate(input[[cb_id]])
        checked <- if (!is.null(prev)) {
          isTRUE(prev)
        } else {
          isTRUE(s$default_selected)
        }
        div(class = "mb-1", checkboxInput(cb_id, s$label, value = checked))
      } else {
        # Compact: one muted line + a "?" help icon whose tooltip carries the
        # reason and the how-to-enable detail (keeps the sidebar short).
        div(
          class = "mb-1 d-flex align-items-center gap-2 text-muted",
          tags$input(
            type = "checkbox",
            disabled = NA,
            class = "form-check-input flex-shrink-0"
          ),
          span(class = "small", s$label),
          bslib::tooltip(
            span(
              shiny::icon("circle-question"),
              class = "small flex-shrink-0",
              style = "cursor: help;"
            ),
            paste0(s$reason, " -- ", s$detail)
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
    enabled_ids <- setdiff(enabled_ids, hidden_steps)
    enabled_ids[vapply(
      enabled_ids,
      function(id) isTRUE(input[[paste0("step_", id)]]),
      logical(1)
    )]
  })

  # ---- Drift/batch reference: auto-pick a QC present in the data ----------
  present_qc <- reactive({
    m <- mexp_r()
    if (inherits(m, "MRMhubExperiment")) {
      sort(unique(as.character(stats::na.omit(m@dataset$qc_type))))
    } else {
      character()
    }
  })
  # First pooled QC actually present; NULL when none -> the generator emits the
  # drift/batch call commented out with a hint to import QC metadata.
  drift_qc_ref <- reactive({
    hit <- intersect(drift_ref_pool, present_qc())
    if (length(hit) > 0) hit[1] else NULL
  })

  # ---- Spec, preview, validation, outputs ---------------------------------
  spec_r <- reactive({
    list(
      importer = input$importer,
      data_path = data_qmd_path(),
      metadata_route = input$metadata_route,
      metadata_path = metadata_qmd_path(),
      steps = selected_steps(),
      drift_method = "spline",
      ref_qc_types = drift_qc_ref(),
      output_xlsx = output_qmd_path(),
      formats = input$formats %||% "html",
      column_mapping = if (identical(input$importer, "csv_long")) {
        csv_cfg$column_mapping
      } else {
        NULL
      },
      variable_name = if (identical(input$importer, "csv_wide")) {
        csv_cfg$variable_name
      } else {
        NULL
      },
      analysis_id_col = if (identical(input$importer, "csv_wide")) {
        csv_cfg$analysis_id_col
      } else {
        NULL
      },
      first_feature_column = if (identical(input$importer, "csv_wide")) {
        csv_cfg$first_feature_column
      } else {
        NULL
      }
    )
  })

  # Single source for the generated workflow -- both the live preview and the
  # download read this one reactive, so they never drift apart.
  qmd_r <- reactive(generate_workflow_qmd(spec_r()))

  output$qmd_preview <- renderText(qmd_r())

  # Slim, colourful status banner. Validation is intentionally light: only hard
  # errors (failed import, an impossible step) flip it red; otherwise it is green
  # -- the builder is a get-started tool, not a full metadata validator.
  output$status_banner <- renderUI({
    if (is_generic_csv() && !isTRUE(csv_cfg$configured)) {
      return(status_bar(
        "warning",
        "Configure your columns",
        "Map the generic-CSV columns (top of the sidebar) so the builder can read your data."
      ))
    }
    m <- mexp_r()
    # Red is reserved for something genuinely broken: a file we cannot read.
    if (inherits(m, "condition")) {
      return(status_bar(
        "danger",
        "Couldn't read your data file",
        subtitle = paste0(
          "Import failed: ",
          conditionMessage(m),
          " -- check the format matches the source you picked above."
        )
      ))
    }
    if (!inherits(m, "MRMhubExperiment")) {
      return(status_bar(
        "danger",
        "Couldn't read your data file",
        subtitle = "Check the format matches the source you picked above."
      ))
    }
    res <- tryCatch(
      mrmhub:::workflow_step_issues(m, selected_steps()),
      error = function(e)
        mrmhub:::wf_issue("app", "warning", conditionMessage(e))
    )
    problems <- res[res$severity %in% c("error", "warning"), , drop = FALSE]
    if (nrow(problems) == 0) {
      return(status_bar(
        "success",
        "Ready to render",
        "Download the .qmd, put your data (and any metadata) in a data/ folder beside it, then run: quarto render mrmhub_workflow.qmd"
      ))
    }
    # Anything short of an unreadable file is a friendly amber nudge, not a red
    # error -- usually "add metadata to unlock a step" hints.
    headline <- sprintf(
      "%d thing%s worth a look",
      nrow(problems),
      if (nrow(problems) > 1) "s" else ""
    )
    status_bar("warning", headline, subtitle = NULL, details = problems)
  })

  output$download_qmd <- downloadHandler(
    filename = function() "mrmhub_workflow.qmd",
    content = function(file) writeLines(qmd_r(), file)
  )
}

shinyApp(ui, server)
