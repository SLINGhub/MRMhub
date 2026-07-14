# Interactive workflow builder: validate data + metadata, then generate a
# runnable Quarto (.qmd) mrmhub workflow. The pure generator and validator live
# here (testable without Shiny); the thin UI lives in
# inst/shiny/workflow-builder/app.R and is launched by build_workflow().

# ---- Step registry ---------------------------------------------------------

#' Definitions of the optional pipeline steps offered by the workflow builder
#'
#' Single source of truth shared by the generator and the validator. Each entry
#' describes one tickable pipeline step: its label, canonical position, the R
#' code it emits into the `.qmd`, and a precondition check that inspects an
#' imported `MRMhubExperiment` and returns issues.
#'
#' `import_*` and `save_report_xlsx()` are always emitted (first / last chunks)
#' and are therefore not part of this registry.
#'
#' @return A named list of step definitions, each a list with `id`, `label`,
#'   `order`, `default_selected`, `heading`, `prose`, `emit(spec)`, and
#'   `precheck(mexp, spec)`.
#' @noRd
workflow_steps <- function() {
  list(
    normalize_istd = list(
      id = "normalize_istd",
      label = "Normalize by internal standard",
      order = 20,
      default_selected = TRUE,
      heading = "Normalize by internal standard",
      prose = "Divide each feature by its assigned internal standard to correct for extraction and injection variability.",
      emit = function(spec) "mexp <- normalize_by_istd(mexp)",
      gate = function(mexp) {
        if (nrow(mexp@annot_features) == 0) {
          return(list(
            enabled = FALSE,
            reason = "No feature metadata",
            detail = "normalize_by_istd() needs feature annotations carrying an 'istd_feature_id' column. Import feature metadata to enable this step."
          ))
        }
        if (all(is.na(mexp@annot_features$istd_feature_id))) {
          return(list(
            enabled = FALSE,
            reason = "No ISTDs defined",
            detail = "No feature has an 'istd_feature_id' assigned, so there is nothing to normalize against. Assign internal standards in the feature metadata."
          ))
        }
        list(enabled = TRUE)
      },
      precheck = function(mexp, spec) {
        if (nrow(mexp@annot_features) == 0) {
          return(wf_issue(
            "normalize_istd",
            "error",
            "No feature metadata imported -- normalize_by_istd() requires feature annotations with 'istd_feature_id'."
          ))
        }
        istd <- mexp@annot_features$istd_feature_id
        if (all(is.na(istd))) {
          wf_issue(
            "normalize_istd",
            "error",
            "No 'istd_feature_id' is defined in the feature metadata -- normalize_by_istd() will abort. Assign an internal standard to each feature."
          )
        } else if (any(is.na(istd))) {
          wf_issue(
            "normalize_istd",
            "warning",
            "Some features have no 'istd_feature_id' assigned -- they will be dropped, or set ignore_missing_annotation = TRUE."
          )
        }
      }
    ),
    quantify_istd = list(
      id = "quantify_istd",
      label = "Quantify by internal standard",
      order = 30,
      default_selected = TRUE,
      heading = "Quantify against internal-standard concentrations",
      prose = "Convert normalized signals to concentrations using the spiked internal-standard amounts.",
      emit = function(spec) "mexp <- quantify_by_istd(mexp)",
      gate = function(mexp) {
        if (nrow(mexp@annot_istds) == 0) {
          return(list(
            enabled = FALSE,
            reason = "No ISTD concentrations",
            detail = "quantify_by_istd() needs internal-standard concentrations (the annot_istds table). Import ISTD metadata to enable this step."
          ))
        }
        list(enabled = TRUE)
      },
      precheck = function(mexp, spec) {
        issues <- wf_issues()
        if (nrow(mexp@annot_istds) == 0) {
          issues <- dplyr::bind_rows(issues, wf_issue(
            "quantify_istd",
            "error",
            "No internal-standard concentrations imported (annot_istds is empty) -- quantify_by_istd() will abort."
          ))
        }
        if (!"normalize_istd" %in% spec$steps) {
          issues <- dplyr::bind_rows(issues, wf_issue(
            "quantify_istd",
            "warning",
            "quantify_by_istd() needs ISTD-normalized data -- also select 'Normalize by internal standard'."
          ))
        }
        aa <- mexp@annot_analyses
        missing_amt <- !all(c("sample_amount", "istd_volume") %in% names(aa)) ||
          all(is.na(aa$sample_amount)) || all(is.na(aa$istd_volume))
        if (nrow(aa) > 0 && missing_amt) {
          issues <- dplyr::bind_rows(issues, wf_issue(
            "quantify_istd",
            "warning",
            "'sample_amount' and/or 'istd_volume' are missing from analysis metadata -- needed for concentration units."
          ))
        }
        issues
      }
    ),
    quantify_cal = list(
      id = "quantify_cal",
      label = "Quantify by calibration curve",
      order = 32,
      default_selected = FALSE,
      heading = "Quantify against external calibration curves",
      prose = "Fit calibration curves from the QC-concentration metadata and quantify samples.",
      emit = function(spec) "mexp <- quantify_by_calibration(mexp, fit_overwrite = TRUE)",
      gate = function(mexp) {
        if (nrow(mexp@annot_qcconcentrations) == 0) {
          return(list(
            enabled = FALSE,
            reason = "No QC concentrations",
            detail = "External calibration needs QC-sample concentrations (the annot_qcconcentrations table). Import QC-concentration metadata to enable this step."
          ))
        }
        list(enabled = TRUE)
      },
      precheck = function(mexp, spec) {
        if (nrow(mexp@annot_qcconcentrations) == 0) {
          wf_issue(
            "quantify_cal",
            "error",
            "No QC-concentration metadata imported -- quantify_by_calibration() has no calibration points."
          )
        }
      }
    ),
    calibrate_ref = list(
      id = "calibrate_ref",
      label = "Calibrate by reference sample",
      order = 34,
      default_selected = FALSE,
      heading = "Calibrate against a reference sample",
      prose = "Anchor concentrations to a reference material (e.g. NIST SRM 1950) measured in the run.",
      emit = function(spec) {
        ref <- spec$reference_sample_id %||% "REFERENCE_SAMPLE_ID"
        var <- workflow_variable(spec)
        glue::glue(
          'mexp <- calibrate_by_reference(\n',
          '  mexp,\n',
          '  variable = "{var}",\n',
          '  reference_sample_id = "{ref}",\n',
          '  absolute_calibration = TRUE,\n',
          '  undefined_conc_action = "na"\n',
          ')'
        )
      },
      gate = function(mexp) {
        sids <- if ("sample_id" %in% names(mexp@annot_analyses)) {
          unique(stats::na.omit(mexp@annot_analyses$sample_id))
        } else {
          character()
        }
        if (length(sids) == 0) {
          return(list(
            enabled = FALSE,
            reason = "No sample_id metadata",
            detail = "Reference calibration needs analyses annotated with a 'sample_id' identifying the reference material. Import analysis metadata to enable this step."
          ))
        }
        list(enabled = TRUE)
      },
      precheck = function(mexp, spec) {
        ref <- spec$reference_sample_id
        sids <- if ("sample_id" %in% names(mexp@annot_analyses)) {
          unique(stats::na.omit(mexp@annot_analyses$sample_id))
        } else {
          character()
        }
        if (is.null(ref) || !nzchar(ref)) {
          wf_issue(
            "calibrate_ref",
            "warning",
            "No reference_sample_id chosen -- select the sample_id of the reference material."
          )
        } else if (!ref %in% sids) {
          wf_issue(
            "calibrate_ref",
            "error",
            glue::glue("Reference sample '{ref}' is not a 'sample_id' in the analysis metadata.")
          )
        }
      }
    ),
    correct_drift = list(
      id = "correct_drift",
      label = "Correct within-batch drift",
      order = 50,
      default_selected = FALSE,
      heading = "Correct within-batch signal drift",
      prose = "Model and remove smooth intra-batch drift using QC samples (Broadhurst 2018).",
      emit = function(spec) {
        var <- workflow_variable(spec)
        ref <- format_char_vec(drift_ref(spec))
        fn <- switch(
          spec$drift_method %||% "gaussian",
          spline = "correct_drift_cubicspline",
          loess = "correct_drift_loess",
          "correct_drift_gaussiankernel"
        )
        glue::glue('mexp <- {fn}(mexp, variable = "{var}", ref_qc_types = {ref})')
      },
      precheck = function(mexp, spec) precheck_qc_ref(mexp, spec, "correct_drift")
    ),
    correct_batch = list(
      id = "correct_batch",
      label = "Correct between-batch offsets",
      order = 60,
      default_selected = FALSE,
      heading = "Correct between-batch offsets",
      prose = "Centre each batch to remove systematic offsets between batches.",
      emit = function(spec) {
        var <- workflow_variable(spec)
        ref <- format_char_vec(drift_ref(spec)) # batch matches the drift method's reference
        glue::glue('mexp <- correct_batch_centering(mexp, variable = "{var}", ref_qc_types = {ref})')
      },
      gate = function(mexp) {
        n_batches <- length(unique(stats::na.omit(mexp@dataset$batch_id)))
        if (n_batches <= 1) {
          return(list(
            enabled = FALSE,
            reason = "Only one batch",
            detail = "Between-batch correction requires more than one 'batch_id'. With a single batch there is nothing to centre."
          ))
        }
        list(enabled = TRUE)
      },
      precheck = function(mexp, spec) {
        issues <- precheck_qc_ref(mexp, spec, "correct_batch")
        n_batches <- length(unique(stats::na.omit(mexp@dataset$batch_id)))
        if (n_batches <= 1) {
          issues <- dplyr::bind_rows(issues, wf_issue(
            "correct_batch",
            "warning",
            "Only one batch detected -- between-batch correction has no effect."
          ))
        }
        issues
      }
    ),
    qc_metrics = list(
      id = "qc_metrics",
      label = "Calculate QC metrics",
      order = 70,
      default_selected = TRUE,
      heading = "Calculate QC metrics",
      prose = "Compute per-feature QC statistics (CV, signal/blank, ...) used for filtering.",
      emit = function(spec) "mexp <- calc_qc_metrics(mexp)",
      precheck = function(mexp, spec) NULL
    ),
    filter_qc = list(
      id = "filter_qc",
      label = "Filter features by QC",
      order = 80,
      default_selected = TRUE,
      heading = "Filter features by QC criteria",
      prose = "Remove features that fail QC thresholds, populating the filtered dataset.",
      emit = function(spec) {
        "mexp <- filter_features_qc(mexp, include_qualifier = FALSE, include_istd = FALSE)"
      },
      precheck = function(mexp, spec) NULL
    ),
    plot_runscatter = list(
      id = "plot_runscatter",
      label = "Plot run-scatter (QC visual)",
      order = 90,
      default_selected = FALSE,
      heading = "Inspect the run-scatter",
      prose = "Plot each feature across the analytical run to visually confirm the processing.",
      emit = function(spec) {
        var <- workflow_variable(spec)
        glue::glue('plot_runscatter(mexp, variable = "{var}")')
      },
      precheck = function(mexp, spec) NULL
    )
  )
}

# Per-step availability given the imported experiment. Each step's `gate(mexp)`
# (metadata-only, independent of what else is selected) decides whether the step
# can run at all; steps without a gate are always available. Returns an ordered
# list of records used by the app to enable/disable the step checkboxes.
#' @noRd
workflow_step_availability <- function(mexp) {
  defs <- workflow_steps()
  defs <- defs[order(vapply(defs, function(s) s$order, numeric(1)))]
  lapply(unname(defs), function(s) {
    g <- if (!is.null(s$gate) && inherits(mexp, "MRMhubExperiment")) {
      tryCatch(s$gate(mexp), error = function(e) list(enabled = TRUE))
    } else {
      list(enabled = TRUE)
    }
    list(
      id = s$id,
      label = s$label,
      order = s$order,
      default_selected = isTRUE(s$default_selected),
      enabled = isTRUE(g$enabled),
      reason = g$reason %||% NA_character_,
      detail = g$detail %||% NA_character_
    )
  })
}

# Shared precheck: the chosen ref_qc_types must exist in the data, and the
# target variable column must be present (i.e. an upstream step produced it).
#' @noRd
precheck_qc_ref <- function(mexp, spec, step) {
  issues <- wf_issues()
  present <- unique(as.character(stats::na.omit(mexp@dataset$qc_type)))
  ref <- spec$ref_qc_types %||% "SPL"
  missing_ref <- setdiff(ref, present)
  if (length(missing_ref) > 0) {
    issues <- dplyr::bind_rows(issues, wf_issue(
      step,
      "error",
      glue::glue(
        "Reference QC type(s) {format_char_vec(missing_ref)} are not present in the data ",
        "(found: {format_char_vec(present)})."
      )
    ))
  }
  var <- workflow_variable(spec)
  col <- paste0("feature_", var)
  produced_by <- c(conc = "quantify_istd/quantify_cal", norm_intensity = "normalize_istd")
  if (!col %in% names(mexp@dataset)) {
    hint <- produced_by[[var]] %||% "an upstream step"
    issues <- dplyr::bind_rows(issues, wf_issue(
      step,
      "warning",
      glue::glue("Target variable '{col}' is not yet in the data -- select {hint} first.")
    ))
  }
  issues
}

# ---- Small helpers ---------------------------------------------------------

#' @noRd
`%||%` <- function(x, y) if (is.null(x) || length(x) == 0) y else x

# Highest processing level reached by the selected steps -- the feature variable
# that drift/batch/plot should act on: conc if quantified, else norm_intensity if
# ISTD-normalized, else raw intensity.
#' @noRd
workflow_variable <- function(spec) {
  steps <- spec$steps %||% character()
  if (any(c("quantify_istd", "quantify_cal", "calibrate_ref") %in% steps)) {
    "conc"
  } else if ("normalize_istd" %in% steps) {
    "norm_intensity"
  } else {
    "intensity"
  }
}

# Reference QC type(s) for drift/batch. An explicit spec$ref_qc_types wins;
# otherwise the drift method decides: Gaussian kernel uses study samples (SPL),
# spline/loess use pooled QCs (BQC by default; the app narrows this to the first
# of BQC / TQC / QC actually present in the data).
#' @noRd
drift_ref <- function(spec) {
  if (!is.null(spec$ref_qc_types) && length(spec$ref_qc_types) > 0) {
    return(spec$ref_qc_types)
  }
  if (identical(spec$drift_method %||% "gaussian", "gaussian")) "SPL" else "BQC"
}

# Format a character vector as R source: "SPL" or c("SPL", "BQC").
#' @noRd
format_char_vec <- function(x) {
  x <- as.character(x)
  if (length(x) == 1) {
    paste0('"', x, '"')
  } else {
    paste0('c(', paste0('"', x, '"', collapse = ", "), ')')
  }
}

# Format a named character vector as R source: c(analysis_id = "Sample", ...).
#' @noRd
format_named_vec <- function(x) {
  parts <- paste0(names(x), ' = "', unname(as.character(x)), '"')
  paste0("c(", paste(parts, collapse = ", "), ")")
}

#' @noRd
wf_issues <- function() {
  dplyr::tibble(
    step = character(),
    severity = character(),
    message = character()
  )
}

#' @noRd
wf_issue <- function(step, severity, message) {
  dplyr::tibble(step = step, severity = severity, message = as.character(message))
}

# ---- Validator -------------------------------------------------------------

#' Validate uploaded data + metadata against the selected workflow steps
#'
#' Builds an `MRMhubExperiment` from the given files using the real importers
#' (so every importer / metadata precondition is exercised), then runs each
#' selected step's precondition check. Import failures are captured and reported
#' rather than raised.
#'
#' @param data_file Path to the data file to import.
#' @param importer One of `"mrmhub"`, `"masshunter"`, `"skyline"`,
#'   `"csv_long"`, `"csv_wide"`.
#' @param metadata_file Optional path to a metadata file.
#' @param metadata_route One of `"embedded"` (metadata in the data file),
#'   `"msorganiser"`, `"tables"` (multi-sheet xlsx), or `"none"`.
#' @param steps Character vector of selected step ids (the ids defined in
#'   `workflow_steps()`).
#' @param csv_opts List of extra arguments for the generic CSV importers:
#'   `column_mapping` (csv_long) or `variable_name` / `analysis_id_col` /
#'   `first_feature_column` (csv_wide).
#'
#' @return A tibble with columns `step`, `severity` (`"error"`, `"warning"`, or
#'   `"ok"`), and `message`.
#' @noRd
validate_workflow_inputs <- function(
  data_file,
  importer = "mrmhub",
  metadata_file = NULL,
  metadata_route = "embedded",
  steps = character(),
  csv_opts = list()
) {
  spec <- list(steps = steps)

  mexp <- tryCatch(
    suppressMessages(build_experiment(data_file, importer, metadata_file, metadata_route, csv_opts)),
    error = function(e) e
  )

  if (inherits(mexp, "condition")) {
    return(wf_issue("import", "error", paste0("Import failed: ", conditionMessage(mexp))))
  }

  defs <- workflow_steps()
  issues <- purrr::map(steps, function(id) {
    def <- defs[[id]]
    if (is.null(def) || is.null(def$precheck)) {
      return(NULL)
    }
    def$precheck(mexp, spec)
  })
  issues <- dplyr::bind_rows(issues)

  if (nrow(issues) == 0) {
    wf_issue("import", "ok", "Data and metadata imported; selected steps have no issues.")
  } else {
    issues
  }
}

# Build the experiment from files using the real importers. Kept separate so
# validate_workflow_inputs() can wrap it in tryCatch.
#' @noRd
build_experiment <- function(data_file, importer, metadata_file, metadata_route, csv_opts = list()) {
  embedded <- identical(metadata_route, "embedded")
  mexp <- MRMhubExperiment()

  mexp <- switch(
    importer,
    mrmhub = import_data_mrmhub(mexp, path = data_file, import_metadata = embedded, silent = TRUE),
    masshunter = import_data_masshunter(mexp, path = data_file, import_metadata = embedded),
    skyline = import_data_skyline(mexp, path = data_file, import_metadata = embedded),
    csv_long = import_data_csv_long(
      mexp,
      path = data_file,
      import_metadata = embedded,
      column_mapping = csv_opts$column_mapping
    ),
    csv_wide = import_data_csv_wide(
      mexp,
      path = data_file,
      variable_name = csv_opts$variable_name %||% "area",
      analysis_id_col = csv_opts$analysis_id_col %||% NA,
      first_feature_column = csv_opts$first_feature_column %||% NA
    ),
    cli::cli_abort("Unknown importer {.val {importer}}.")
  )

  if (identical(metadata_route, "individual")) {
    mexp <- import_metadata_individual(mexp, if (is.list(metadata_file)) metadata_file else list())
  } else if (!is.null(metadata_file) && length(metadata_file) == 1 && nzchar(metadata_file)) {
    mexp <- switch(
      metadata_route,
      msorganiser = import_metadata_msorganiser(mexp, path = metadata_file, ignore_warnings = TRUE),
      tables = import_metadata_tables(mexp, metadata_file),
      mexp
    )
  }
  mexp
}

# Import separate per-table metadata CSVs. `files` is a named list with any of
# `analyses`, `features`, `istds`; missing / NULL entries are skipped.
#' @noRd
import_metadata_individual <- function(mexp, files) {
  if (!is.null(files$analyses)) {
    mexp <- import_metadata_analyses(mexp, path = files$analyses)
  }
  if (!is.null(files$features)) {
    mexp <- import_metadata_features(mexp, path = files$features)
  }
  if (!is.null(files$istds)) {
    mexp <- import_metadata_istds(mexp, path = files$istds)
  }
  mexp
}

# Import a multi-sheet metadata xlsx (Analyses / Features / ISTDs / ...),
# skipping sheets that are not present.
#' @noRd
import_metadata_tables <- function(mexp, path) {
  sheets <- openxlsx2::wb_get_sheet_names(openxlsx2::wb_load(path))
  if ("Analyses" %in% sheets) {
    mexp <- import_metadata_analyses(mexp, path = path, sheet = "Analyses")
  }
  if ("Features" %in% sheets) {
    mexp <- import_metadata_features(mexp, path = path, sheet = "Features")
  }
  if ("ISTDs" %in% sheets) {
    mexp <- import_metadata_istds(mexp, path = path, sheet = "ISTDs")
  }
  if ("QCconcentrations" %in% sheets) {
    mexp <- import_metadata_qcconcentrations(mexp, path = path, sheet = "QCconcentrations")
  }
  mexp
}

# ---- QMD generator ---------------------------------------------------------

#' Generate a runnable Quarto (.qmd) mrmhub workflow
#'
#' Assembles a self-contained Quarto document that imports data and metadata and
#' runs the selected processing steps, in canonical order, using the same
#' function calls and defaults as the package tutorials. This is a pure function
#' (no file I/O, no Shiny) so it can be tested and scripted directly; the
#' interactive [build_workflow()] app calls it to power its live preview.
#'
#' @param spec A list describing the workflow. Recognised fields:
#'   \describe{
#'     \item{`importer`}{One of `"mrmhub"`, `"masshunter"`, `"skyline"`,
#'       `"csv_long"`, `"csv_wide"`. Default `"mrmhub"`.}
#'     \item{`data_path`}{Path to the data file as it should appear in the
#'       generated document.}
#'     \item{`metadata_route`}{`"embedded"`, `"msorganiser"`, `"tables"`, or
#'       `"none"`. Default `"embedded"`.}
#'     \item{`metadata_path`}{Path to the metadata file (when not embedded).}
#'     \item{`steps`}{Character vector of step ids to include (the ids defined
#'       in `workflow_steps()`).}
#'     \item{`drift_method`}{Drift model for the drift step: `"gaussian"`
#'       (default), `"spline"`, or `"loess"`.}
#'     \item{`ref_qc_types`, `reference_sample_id`}{Optional reference QC type(s)
#'       and reference sample id for drift/batch/calibration. The corrected
#'       feature variable is derived automatically as the highest processing
#'       level reached by the selected steps.}
#'     \item{`column_mapping`}{Named character vector for `importer = "csv_long"`,
#'       mapping canonical names to file columns, e.g.
#'       `c(analysis_id = "Sample", feature_id = "Compound", feature_area = "Area")`.}
#'     \item{`variable_name`, `analysis_id_col`, `first_feature_column`}{Arguments
#'       for `importer = "csv_wide"`.}
#'     \item{`output_xlsx`}{Path for the exported report. Default
#'       `"results.xlsx"`.}
#'     \item{`formats`}{Character vector of Quarto output formats, any of
#'       `"html"`, `"docx"`, `"pdf"`. `"pdf"` is rendered sans-serif. Default
#'       `"html"`.}
#'     \item{`save_rds`}{Logical; also save the object as `.rds`. Default
#'       `FALSE`.}
#'     \item{`title`}{Document title. Default `"MRMhub Workflow"`.}
#'   }
#'
#' @return A length-1 character string containing the `.qmd` source.
#' @examples
#' cat(generate_workflow_qmd(list(
#'   importer = "mrmhub",
#'   data_path = "MRMhub_demo.tsv",
#'   steps = c("normalize_istd", "quantify_istd")
#' )))
#' @export
generate_workflow_qmd <- function(spec) {
  spec$importer <- spec$importer %||% "mrmhub"
  spec$data_path <- spec$data_path %||% "your_data.tsv"
  spec$metadata_route <- spec$metadata_route %||% "embedded"
  spec$steps <- spec$steps %||% character()
  spec$output_xlsx <- spec$output_xlsx %||% "results.xlsx"
  spec$title <- spec$title %||% "MRMhub Workflow"
  spec$formats <- spec$formats %||% "html"

  lines <- c(
    qmd_yaml(spec$title, spec$formats),
    "",
    qmd_prose("This workflow was generated by `mrmhub::build_workflow()`. Adjust file paths and parameters as needed, then run each chunk."),
    "",
    "## Setup",
    "",
    qmd_chunk("library(mrmhub)"),
    qmd_import_section(spec),
    qmd_steps_section(spec),
    qmd_export_section(spec)
  )

  paste(lines, collapse = "\n")
}

#' @noRd
qmd_yaml <- function(title, formats = "html") {
  fmt <- "format:"
  for (f in formats) {
    if (identical(f, "pdf")) {
      # Sans-serif PDF that works with the default pdflatex engine (no font
      # install): switch the LaTeX default family to sans.
      fmt <- c(
        fmt,
        "  pdf:",
        "    include-in-header:",
        "      text: |",
        "        \\renewcommand{\\familydefault}{\\sfdefault}"
      )
    } else {
      fmt <- c(fmt, paste0("  ", f, ": default"))
    }
  }
  c(
    "---",
    paste0('title: "', title, '"'),
    "toc: true",
    "execute:",
    "  warning: true",
    fmt,
    "---"
  )
}

#' @noRd
qmd_prose <- function(text) text

# One ```{r} code chunk. `code` may be a length-1 string (possibly multi-line)
# or a character vector of lines.
#' @noRd
qmd_chunk <- function(code) {
  code_lines <- unlist(strsplit(paste(code, collapse = "\n"), "\n", fixed = TRUE))
  c("```{r}", code_lines, "```", "")
}

#' @noRd
qmd_import_section <- function(spec) {
  embedded <- identical(spec$metadata_route, "embedded")
  import_call <- switch(
    spec$importer,
    mrmhub = glue::glue('mexp <- import_data_mrmhub(mexp, path = "{spec$data_path}", import_metadata = {toupper(as.character(embedded))})'),
    masshunter = glue::glue('mexp <- import_data_masshunter(mexp, path = "{spec$data_path}", import_metadata = {toupper(as.character(embedded))})'),
    skyline = glue::glue('mexp <- import_data_skyline(mexp, path = "{spec$data_path}", import_metadata = {toupper(as.character(embedded))})'),
    csv_long = qmd_import_csv_long(spec),
    csv_wide = qmd_import_csv_wide(spec),
    glue::glue('mexp <- import_data_mrmhub(mexp, path = "{spec$data_path}")')
  )

  code <- c("mexp <- MRMhubExperiment()", import_call)

  meta <- qmd_metadata_call(spec)

  c(
    "## Import data",
    "",
    qmd_prose("Create the experiment container and import the raw results."),
    "",
    qmd_chunk(code),
    if (length(meta) > 0) c("## Import metadata", "", qmd_prose("Attach sample, feature, and internal-standard annotations."), "", qmd_chunk(meta))
  )
}

# Generic long CSV: emit a column_mapping when the user has mapped columns, so
# the required analysis_id / feature_id / value columns are resolved.
#' @noRd
qmd_import_csv_long <- function(spec) {
  cm <- spec$column_mapping
  if (is.null(cm) || length(cm) == 0) {
    return(glue::glue('mexp <- import_data_csv_long(mexp, path = "{spec$data_path}")'))
  }
  paste0(
    "mexp <- import_data_csv_long(\n",
    "  mexp,\n",
    '  path = "', spec$data_path, '",\n',
    "  column_mapping = ", format_named_vec(cm), "\n",
    ")"
  )
}

# Generic wide CSV: variable_name is required; analysis_id_col / first_feature
# _column are emitted only when the user set them.
#' @noRd
qmd_import_csv_wide <- function(spec) {
  args <- glue::glue('variable_name = "{spec$variable_name %||% "area"}"')
  if (!is.null(spec$analysis_id_col) && nzchar(as.character(spec$analysis_id_col))) {
    args <- c(args, glue::glue('analysis_id_col = "{spec$analysis_id_col}"'))
  }
  if (!is.null(spec$first_feature_column) && !is.na(spec$first_feature_column)) {
    args <- c(args, glue::glue("first_feature_column = {spec$first_feature_column}"))
  }
  glue::glue('mexp <- import_data_csv_wide(mexp, path = "{spec$data_path}", {paste(args, collapse = ", ")})')
}

#' @noRd
qmd_metadata_call <- function(spec) {
  path <- spec$metadata_path %||% "your_metadata.xlsx"
  switch(
    spec$metadata_route,
    msorganiser = glue::glue('mexp <- import_metadata_msorganiser(mexp, path = "{path}")'),
    tables = c(
      glue::glue('mexp <- import_metadata_analyses(mexp, path = "{path}", sheet = "Analyses")'),
      glue::glue('mexp <- import_metadata_features(mexp, path = "{path}", sheet = "Features")'),
      glue::glue('mexp <- import_metadata_istds(mexp, path = "{path}", sheet = "ISTDs")')
    ),
    individual = {
      mi <- spec$metadata_individual %||% list()
      c(
        if (!is.null(mi$analyses)) glue::glue('mexp <- import_metadata_analyses(mexp, path = "{mi$analyses}")'),
        if (!is.null(mi$features)) glue::glue('mexp <- import_metadata_features(mexp, path = "{mi$features}")'),
        if (!is.null(mi$istds)) glue::glue('mexp <- import_metadata_istds(mexp, path = "{mi$istds}")')
      )
    },
    character()
  )
}

#' @noRd
qmd_steps_section <- function(spec) {
  defs <- workflow_steps()
  selected <- defs[names(defs) %in% spec$steps]
  if (length(selected) == 0) {
    return(character())
  }
  selected <- selected[order(vapply(selected, function(s) s$order, numeric(1)))]

  unlist(lapply(selected, function(s) {
    c(
      paste("##", s$heading),
      "",
      qmd_prose(s$prose),
      "",
      qmd_chunk(s$emit(spec))
    )
  }))
}

#' @noRd
qmd_export_section <- function(spec) {
  code <- glue::glue('save_report_xlsx(mexp, path = "{spec$output_xlsx}")')
  if (isTRUE(spec$save_rds)) {
    code <- c(code, 'saveRDS(mexp, file = "mrmhub_experiment.rds")')
  }
  c(
    "## Export results",
    "",
    qmd_prose("Write the processed results to an Excel report."),
    "",
    qmd_chunk(code)
  )
}

# ---- App launcher ----------------------------------------------------------

#' Launch the MRMhub Workflow Builder
#'
#' Opens an interactive Shiny application that helps you turn your data and
#' metadata files into a runnable Quarto (`.qmd`) mrmhub workflow. Point the app
#' at your files, tick the processing steps you need, and the app validates the
#' inputs against each step (warning, for example, when `normalize_by_istd` is
#' selected but no `istd_feature_id` is defined) while previewing the generated
#' workflow document for download.
#'
#' @return Invisible `NULL`. Launches the Shiny app in the default browser.
#' @seealso [generate_workflow_qmd()] for the non-interactive generator.
#' @export
#' @examples
#' if (interactive()) {
#'   build_workflow()
#' }
build_workflow <- function() {
  # shiny + bslib are Suggests (not pulled in when mrmhub is installed). On an
  # interactive first run this prompts the user and installs any that are
  # missing; non-interactively it errors with an install hint.
  rlang::check_installed(
    c("shiny", "bslib"),
    reason = "to run the MRMhub workflow builder."
  )

  app_dir <- system.file("shiny", "workflow-builder", package = "mrmhub")
  if (app_dir == "") {
    cli::cli_abort("Could not find the workflow builder app. Try reinstalling mrmhub.")
  }
  shiny::runApp(app_dir, display.mode = "normal")
}
