# mzTab-M (HUPO-PSI) export
#
# Writes an `MRMhubExperiment` to a validator-targeted mzTab-M 2.0.0-M file.
# mzTab-M is plain, line-prefixed TSV with four section types: MTD (metadata),
# SML/SMH (small molecule summary), SMF/SFH (small molecule feature), and
# SME/SEH (small molecule evidence). The writer is pure base/tidyverse R and
# carries no dependency on the `rmzTabM` reference implementation (that package
# is used only as an optional test oracle).
#
# Mapping (see vignette `recipe-03-mztab-export`):
#   analysis  -> assay[n] / ms_run[n] / sample[n]
#   qc_type   -> study_variable[k]
#   feature   -> SMF row  (SMF == mrmhub feature, the per-transition level)
#   analyte   -> SML row  (groups its SMF rows; quantifier drives abundance)
#   feature_conc / feature_intensity -> abundance_assay[n]

# ---- small helpers ----------------------------------------------------------

# first non-NA element, or NA
.mztab_firstnn <- function(x) {
  x <- x[!is.na(x)]
  if (length(x) > 0) x[[1]] else NA
}

# format a CV/user parameter tuple "[label, accession, name, value]"
.mztab_param <- function(label = "", accession = "", name = "", value = "") {
  glue::glue("[{label}, {accession}, {name}, {value}]")
}

# turn a tibble into mzTab section lines (header row + prefixed data rows),
# replacing NA / empty with the mzTab "null" token.
.mztab_section_lines <- function(tbl, header_prefix, row_prefix) {
  header <- glue::glue_collapse(c(header_prefix, names(tbl)), sep = "\t")
  if (nrow(tbl) == 0) {
    return(as.character(header))
  }
  rows <- tbl |>
    dplyr::mutate(dplyr::across(
      dplyr::everything(),
      \(x)
        dplyr::if_else(
          is.na(x) | as.character(x) == "",
          "null",
          as.character(x)
        )
    )) |>
    tidyr::unite("..line", dplyr::everything(), sep = "\t") |>
    dplyr::mutate(
      "..line" := paste(row_prefix, .data[["..line"]], sep = "\t")
    ) |>
    dplyr::pull("..line")
  c(as.character(header), rows)
}

# Write assembled mzTab sections to disk. Sections are written contiguously
# (no blank separator lines): mzTab rows are identified by their line prefix,
# and some downstream readers mishandle empty lines.
write_mztab_sections <- function(path, mtd_lines, sml_tbl, smf_tbl, sme_tbl) {
  lines <- c(
    mtd_lines,
    .mztab_section_lines(sml_tbl, "SMH", "SML"),
    .mztab_section_lines(smf_tbl, "SFH", "SMF"),
    .mztab_section_lines(sme_tbl, "SEH", "SME")
  )
  readr::write_lines(lines, file = path)
}

# ---- MTD assembly -----------------------------------------------------------

.mztab_build_mtd <- function(
  data,
  assays,
  study_variables,
  quant_unit,
  instrument,
  contact,
  publication
) {
  mtd <- function(key, value) glue::glue("MTD\t{key}\t{value}")

  title <- if (nzchar(data@title)) data@title else "mrmhub dataset export"
  mztab_id <- stringr::str_replace_all(title, "[^A-Za-z0-9]+", "_")

  head_lines <- c(
    mtd("mzTab-version", "2.0.0-M"),
    mtd("mzTab-ID", mztab_id),
    mtd("title", title),
    # mrmhub as the producing software (user param: no MS CV accession asserted)
    mtd(
      "software[1]",
      .mztab_param(
        name = "mrmhub",
        value = as.character(utils::packageVersion("mrmhub"))
      )
    ),
    mtd(
      "quantification_method",
      .mztab_param("MS", "MS:1001834", "LC-MS label-free quantitation analysis")
    ),
    mtd("small_molecule-quantification_unit", quant_unit),
    mtd("small_molecule_feature-quantification_unit", quant_unit)
  )

  # optional enrichment hooks (NULLs drop out of c())
  optional_lines <- c(
    if (!is.null(instrument)) {
      mtd("instrument[1]-name", .mztab_param(name = instrument))
    },
    if (!is.null(contact)) mtd("contact[1]-name", contact),
    if (!is.null(publication)) mtd("publication[1]", publication)
  )

  # ms_run + assay, one block per analysis. Samples are optional in mzTab-M and
  # carry only biological metadata we don't have, so they are omitted; the
  # analysis identity is preserved via the ms_run location.
  ms_run_lines <- assays |>
    dplyr::mutate(
      .loc = purrr::map2_chr(
        .data$raw_data_filename,
        .data$analysis_id,
        function(file, id) {
          loc <- if (is.na(file) || !nzchar(file)) id else file
          # turn a bare filename/path into a valid file URI: percent-encode
          # spaces etc., and use the empty-authority form `file:///<abs-path>`
          # (three slashes) so the filename is not misread as a host.
          if (!stringr::str_detect(loc, "://")) {
            loc <- paste0(
              "file:///",
              utils::URLencode(sub("^/+", "", loc), reserved = FALSE)
            )
          }
          loc
        }
      )
    ) |>
    purrr::pmap(function(assay_no, .loc, ...) {
      c(
        mtd(glue::glue("ms_run[{assay_no}]-location"), .loc),
        mtd(
          glue::glue("assay[{assay_no}]-ms_run_ref"),
          glue::glue("ms_run[{assay_no}]")
        )
      )
    }) |>
    purrr::list_c()

  # study_variable, one block per qc_type group
  sv_lines <- study_variables |>
    purrr::pmap(function(qc_type, study_variable_no, ...) {
      refs <- assays |>
        dplyr::filter(.data$study_variable_no == .env$study_variable_no) |>
        dplyr::pull("assay_no")
      refs <- glue::glue_collapse(glue::glue("assay[{refs}]"), sep = "|")
      c(
        mtd(glue::glue("study_variable[{study_variable_no}]"), qc_type),
        mtd(
          glue::glue("study_variable[{study_variable_no}]-description"),
          qc_type
        ),
        mtd(glue::glue("study_variable[{study_variable_no}]-assay_refs"), refs),
        mtd(
          glue::glue("study_variable[{study_variable_no}]-average_function"),
          .mztab_param("MS", "MS:1002962", "The arithmetic mean")
        ),
        mtd(
          glue::glue("study_variable[{study_variable_no}]-variation_function"),
          .mztab_param("MS", "MS:1002963", "The coefficient of variation")
        )
      )
    }) |>
    purrr::list_c()

  # controlled vocabularies (cv[1] must reference PSI-MS) + database
  cv_lines <- c(
    mtd("cv[1]-label", "MS"),
    mtd("cv[1]-full_name", "PSI-MS controlled vocabulary"),
    mtd("cv[1]-version", "4.1.130"),
    mtd(
      "cv[1]-uri",
      "https://raw.githubusercontent.com/HUPO-PSI/psi-ms-CV/master/psi-ms.obo"
    ),
    # at least one database is required; declare "no database"
    mtd("database[1]", .mztab_param(name = "no database", value = "null")),
    mtd("database[1]-prefix", "null"),
    mtd("database[1]-version", "Unknown"),
    mtd("database[1]-uri", "null"),
    # required when an SME section is present
    mtd(
      "id_confidence_measure[1]",
      .mztab_param(name = "identification confidence")
    )
  )

  as.character(c(
    head_lines,
    optional_lines,
    ms_run_lines,
    sv_lines,
    cv_lines
  ))
}

# ---- main exporter ----------------------------------------------------------

#' Export an experiment to mzTab-M (HUPO-PSI)
#'
#' Writes an [`MRMhubExperiment`][MRMhubExperiment-class] to an
#' [mzTab-M 2.0.0-M](https://github.com/HUPO-PSI/mzTab-M) file, the HUPO-PSI
#' community standard for reporting quantitative metabolomics / lipidomics
#' results (and the format expected by repositories such as MetaboLights).
#'
#' The full dataset is exported: every analysis becomes an `assay` (QC,
#' blank and calibration samples included), every feature a Small Molecule
#' Feature (`SMF`) row, and features are grouped by analyte into Small Molecule
#' Summary (`SML`) rows. A minimal Small Molecule Evidence (`SME`) row is
#' emitted per feature so all three table types are present.
#'
#' @details
#' **Abundance.** `variable` selects which `feature_*` value is written to the
#' `abundance_assay[n]` columns. The default `"conc"` uses final concentrations
#' and declares the matching concentration unit; if the experiment has not been
#' quantified, the exporter falls back to raw `feature_intensity` with an
#' "Arbitrary quantification unit".
#'
#' **What is *not* exported.** mzTab-M is a quantification report, not a
#' processing-state container. Internal-standard relationships, QC/calibration
#' metrics, drift/batch-correction state and the `qc_type`/batch structure are
#' not representable and are therefore not written (ISTD features are merely
#' flagged via an `opt_global_is_internal_standard` column). See the
#' *mzTab-M export* recipe article for the full mapping.
#'
#' @param data An `MRMhubExperiment` object.
#' @param path Output file path. A `.mzTab` extension is appended if missing.
#' @param variable Feature variable used as abundance. One of `"conc"`,
#'   `"intensity"`, `"norm_intensity"`, `"area"` or `"height"`. Default
#'   `"conc"` (falls back to `"intensity"` if not quantified).
#' @param instrument,contact,publication Optional single strings used to
#'   enrich the `MTD` metadata header (instrument name, contact name,
#'   publication identifier). `NULL` (default) omits them.
#' @param rt_in_minutes Logical; are `feature_rt` values in minutes? mzTab-M
#'   stores retention time in seconds, so values are multiplied by 60 when
#'   `TRUE` (default).
#' @param overwrite Logical; overwrite an existing file. Default `TRUE`.
#'
#' @return Invisibly returns the (normalised) output `path`. Called for its
#'   side effect of writing the file.
#'
#' @seealso [save_report_xlsx()], [save_dataset_csv()]
#'
#' @examples
#' \dontrun{
#' save_dataset_mztab(mexp, "experiment.mzTab")
#' save_dataset_mztab(mexp, "raw.mzTab", variable = "area")
#' }
#'
#' @export
save_dataset_mztab <- function(
  data = NULL,
  path,
  variable = "conc",
  instrument = NULL,
  contact = NULL,
  publication = NULL,
  rt_in_minutes = TRUE,
  overwrite = TRUE
) {
  check_data(data)

  if (nrow(data@dataset) == 0) {
    cli_abort(col_red(
      "No annotated data available. Import and process data before exporting to mzTab-M."
    ))
  }

  # --- resolve abundance variable (with fallback) ---------------------------
  variable <- str_remove(variable, "feature_")
  rlang::arg_match(
    variable,
    c("conc", "intensity", "norm_intensity", "area", "height")
  )
  variable_col <- paste0("feature_", variable)

  if (
    !variable_col %in% names(data@dataset) ||
      all(is.na(data@dataset[[variable_col]]))
  ) {
    if (variable != "intensity") {
      cli_alert_warning(col_yellow(glue::glue(
        "'{variable_col}' not available - falling back to raw 'feature_intensity'."
      )))
    }
    variable <- "intensity"
    variable_col <- "feature_intensity"
  }

  # --- output path ----------------------------------------------------------
  if (!str_detect(path, "\\.mzTab$")) {
    path <- paste0(path, ".mzTab")
  }
  if (fs::file_exists(path) && !overwrite) {
    cli_abort(col_red(
      "File '{path}' already exists. Use `overwrite = TRUE` to replace it."
    ))
  }

  # --- quantification unit --------------------------------------------------
  if (variable == "conc") {
    conc_unit_origin <- if (
      data@is_quantitated &&
        data@status_processing == "Calibration-quantitated data"
    ) {
      unique(data@annot_qcconcentrations$concentration_unit)
    } else {
      "pmol"
    }
    unit_str <- get_conc_unit(
      data@annot_analyses$sample_amount_unit,
      conc_unit_origin
    )
    if (is.na(unit_str) || !nzchar(unit_str)) {
      unit_str <- "arbitrary"
    }
    quant_unit <- .mztab_param(name = unit_str)
  } else {
    quant_unit <- .mztab_param(
      "PRIDE",
      "PRIDE:0000330",
      "Arbitrary quantification unit"
    )
  }

  # --- assays (one per analysis, ordered by analysis_order) -----------------
  assays <- data@dataset |>
    dplyr::distinct(dplyr::across(dplyr::any_of(c(
      "analysis_order",
      "analysis_id",
      "qc_type"
    ))))
  if ("analysis_order" %in% names(assays)) {
    assays <- dplyr::arrange(assays, .data$analysis_order)
  }
  assays <- assays |>
    dplyr::left_join(
      dplyr::distinct(
        data@dataset_orig,
        .data$analysis_id,
        .data$raw_data_filename
      ),
      by = "analysis_id"
    ) |>
    dplyr::mutate(
      assay_no = dplyr::row_number(),
      qc_type = as.character(.data$qc_type)
    )

  # study variables: one per qc_type group (preserving first-appearance order)
  study_variables <- assays |>
    dplyr::distinct(.data$qc_type) |>
    dplyr::mutate(study_variable_no = dplyr::row_number())
  assays <- assays |>
    dplyr::left_join(study_variables, by = "qc_type")

  # --- per-feature metadata -------------------------------------------------
  ds <- data@dataset
  getcol <- function(nm) if (nm %in% names(ds)) ds[[nm]] else rep(NA, nrow(ds))
  feat_meta <- tibble::tibble(
    feature_id = ds$feature_id,
    exp_mz = getcol("method_product_mz"),
    polarity = getcol("method_polarity"),
    rt = getcol("feature_rt"),
    feature_label = getcol("feature_label")
  ) |>
    dplyr::group_by(.data$feature_id) |>
    dplyr::summarise(
      exp_mz = .mztab_firstnn(.data$exp_mz),
      polarity = .mztab_firstnn(.data$polarity),
      rt_s = if (all(is.na(.data$rt))) {
        NA_real_
      } else {
        stats::median(.data$rt, na.rm = TRUE) * if (rt_in_minutes) 60 else 1
      },
      feature_label = .mztab_firstnn(.data$feature_label),
      .groups = "drop"
    )

  # feature attributes from annotation (defensive about missing columns)
  annot <- data@annot_features
  feat <- tibble::tibble(feature_id = unique(ds$feature_id)) |>
    dplyr::left_join(
      annot |>
        dplyr::select(dplyr::any_of(c(
          "feature_id",
          "analyte_id",
          "chem_formula",
          "molecular_weight",
          "is_istd",
          "is_quantifier"
        ))),
      by = "feature_id"
    ) |>
    dplyr::left_join(feat_meta, by = "feature_id")

  if (!"analyte_id" %in% names(feat) || all(is.na(feat$analyte_id))) {
    feat$analyte_id <- feat$feature_id
  } else {
    feat$analyte_id <- dplyr::coalesce(feat$analyte_id, feat$feature_id)
  }
  if (!"is_istd" %in% names(feat)) feat$is_istd <- FALSE
  feat$is_istd <- dplyr::coalesce(feat$is_istd, FALSE)
  if (!"is_quantifier" %in% names(feat)) feat$is_quantifier <- TRUE
  feat$is_quantifier <- dplyr::coalesce(feat$is_quantifier, TRUE)
  if (!"chem_formula" %in% names(feat)) feat$chem_formula <- NA_character_
  if (!"molecular_weight" %in% names(feat)) feat$molecular_weight <- NA_real_
  feat$name <- dplyr::coalesce(
    feat$feature_label,
    feat$analyte_id,
    feat$feature_id
  )
  feat$smf_id <- seq_len(nrow(feat))

  # long view of the chosen abundance, tagged with assay / study_variable
  abundance_long <- ds |>
    dplyr::select(
      "analysis_id",
      "feature_id",
      .val = dplyr::all_of(variable_col)
    ) |>
    dplyr::left_join(
      dplyr::select(
        assays,
        "analysis_id",
        "assay_no",
        "study_variable_no"
      ),
      by = "analysis_id"
    )

  # --- abundance: one wide column per assay (abundance_assay[n]) -------------
  assay_cols <- as.character(glue::glue("abundance_assay[{assays$assay_no}]"))
  abundance_wide <- abundance_long |>
    dplyr::mutate(
      .col = as.character(glue::glue("abundance_assay[{.data$assay_no}]"))
    ) |>
    dplyr::select("feature_id", ".col", ".val") |>
    tidyr::pivot_wider(
      names_from = ".col",
      values_from = ".val",
      values_fn = check_single_pivot_value
    ) |>
    dplyr::select("feature_id", dplyr::all_of(assay_cols))

  # --- study-variable summaries (mean + %CV per qc_type group) --------------
  sv_no <- study_variables$study_variable_no
  # interleave mean/cv per study variable: sv1, var1, sv2, var2, ... (column-major)
  sv_src <- as.character(rbind(
    glue::glue("{sv_no}_.mean"),
    glue::glue("{sv_no}_.cv")
  ))
  sv_final <- as.character(rbind(
    glue::glue("abundance_study_variable[{sv_no}]"),
    glue::glue("abundance_variation_study_variable[{sv_no}]")
  ))
  sv_wide <- abundance_long |>
    dplyr::group_by(.data$feature_id, .data$study_variable_no) |>
    dplyr::summarise(
      .mean = mean(.data$.val, na.rm = TRUE),
      .sd = stats::sd(.data$.val, na.rm = TRUE),
      .groups = "drop"
    ) |>
    dplyr::mutate(
      .mean = dplyr::if_else(is.nan(.data$.mean), NA_real_, .data$.mean),
      .cv = dplyr::if_else(
        is.na(.data$.sd) | is.na(.data$.mean) | .data$.mean == 0,
        NA_real_,
        .data$.sd / .data$.mean * 100
      )
    ) |>
    dplyr::select("feature_id", "study_variable_no", ".mean", ".cv") |>
    tidyr::pivot_wider(
      names_from = "study_variable_no",
      values_from = c(".mean", ".cv"),
      names_glue = "{study_variable_no}_{.value}",
      values_fn = check_single_pivot_value
    )

  # gather a feature's abundance / summary columns in the requested row order
  abundance_for <- function(feature_ids) {
    tibble::tibble(feature_id = feature_ids) |>
      dplyr::left_join(abundance_wide, by = "feature_id") |>
      dplyr::select(dplyr::all_of(assay_cols))
  }
  studyvar_for <- function(feature_ids) {
    tibble::tibble(feature_id = feature_ids) |>
      dplyr::left_join(sv_wide, by = "feature_id") |>
      dplyr::select(dplyr::all_of(sv_src)) |>
      stats::setNames(sv_final)
  }

  # --- SMF table (one row per feature) --------------------------------------
  smf_core <- tibble::tibble(
    SMF_ID = feat$smf_id,
    SME_ID_REFS = feat$smf_id, # 1:1 stub evidence
    SME_ID_REF_ambiguity_code = NA_character_,
    adduct_ion = NA_character_, # minimal: not asserted
    isotopomer = NA_character_,
    exp_mass_to_charge = feat$exp_mz,
    charge = NA_integer_,
    retention_time_in_seconds = feat$rt_s,
    retention_time_in_seconds_start = NA_real_,
    retention_time_in_seconds_end = NA_real_
  )
  smf_tbl <- dplyr::bind_cols(
    smf_core,
    abundance_for(feat$feature_id),
    tibble::tibble(opt_global_is_internal_standard = feat$is_istd)
  )

  # --- SML table (one row per analyte; quantifier drives abundance) ---------
  analytes <- feat |>
    # quantifier first within each analyte, so first() picks it
    dplyr::arrange(.data$analyte_id, dplyr::desc(.data$is_quantifier)) |>
    dplyr::group_by(.data$analyte_id) |>
    dplyr::summarise(
      smf_refs = paste(sort(.data$smf_id), collapse = "|"),
      rep_feature = dplyr::first(.data$feature_id),
      chem_formula = .mztab_firstnn(.data$chem_formula),
      molecular_weight = .mztab_firstnn(.data$molecular_weight),
      chemical_name = .mztab_firstnn(.data$name),
      .groups = "drop"
    ) |>
    dplyr::mutate(SML_ID = dplyr::row_number())

  # column order is fixed by the mzTab-M 2.0-M spec
  sml_core <- tibble::tibble(
    SML_ID = analytes$SML_ID,
    SMF_ID_REFS = analytes$smf_refs,
    chemical_name = analytes$chemical_name,
    database_identifier = NA_character_,
    chemical_formula = analytes$chem_formula,
    smiles = NA_character_,
    inchi = NA_character_,
    uri = NA_character_,
    theoretical_neutral_mass = analytes$molecular_weight,
    adduct_ions = NA_character_,
    reliability = NA_character_,
    best_id_confidence_measure = NA_character_,
    best_id_confidence_value = NA_real_
  )
  sml_tbl <- dplyr::bind_cols(
    sml_core,
    abundance_for(analytes$rep_feature),
    studyvar_for(analytes$rep_feature)
  )

  # --- SME table (minimal stub, one per feature) ----------------------------
  sme_tbl <- tibble::tibble(
    SME_ID = feat$smf_id,
    evidence_input_id = feat$feature_id,
    database_identifier = NA_character_,
    chemical_formula = feat$chem_formula,
    smiles = NA_character_,
    inchi = NA_character_,
    chemical_name = feat$name,
    uri = NA_character_,
    derivatized_form = NA_character_,
    adduct_ion = NA_character_,
    exp_mass_to_charge = feat$exp_mz,
    charge = NA_integer_,
    theoretical_mass_to_charge = NA_real_,
    spectra_ref = NA_character_,
    identification_method = .mztab_param(name = "targeted identification"),
    ms_level = .mztab_param("MS", "MS:1000511", "ms level", "2"),
    `id_confidence_measure[1]` = NA_real_,
    rank = 1L
  )

  # --- assemble + write ------------------------------------------------------
  mtd_lines <- .mztab_build_mtd(
    data,
    assays,
    study_variables,
    quant_unit,
    instrument,
    contact,
    publication
  )
  write_mztab_sections(path, mtd_lines, sml_tbl, smf_tbl, sme_tbl)

  txtitle <- if (nzchar(data@title)) {
    glue::glue(" of experiment '{data@title}'")
  } else {
    ""
  }
  cli_alert_success(col_green(glue::glue(
    "mzTab-M export{txtitle} ({nrow(smf_tbl)} features x {nrow(assays)} analyses) saved to '{path}'."
  )))
  invisible(path)
}

# ---- import -----------------------------------------------------------------

# Split a vector of raw mzTab lines into a tibble for one section, given its
# header line (e.g. the "SFH ..." line) and the matching data-row prefix
# (e.g. "SMF"). Returns NULL if the section is absent. "null"/empty -> NA.
.mztab_read_section <- function(parts, prefixes, header_prefix, row_prefix) {
  hidx <- which(prefixes == header_prefix)
  if (length(hidx) == 0) {
    return(NULL)
  }
  header <- parts[[hidx[[1]]]][-1]
  rows <- parts[prefixes == row_prefix]
  if (length(rows) == 0) {
    return(NULL)
  }
  ncol <- length(header)
  mat <- t(vapply(
    rows,
    function(r) {
      r <- r[-1]
      length(r) <- ncol
      r
    },
    character(ncol)
  ))
  out <- tibble::as_tibble(mat, .name_repair = "minimal")
  names(out) <- header
  out |>
    dplyr::mutate(dplyr::across(
      dplyr::everything(),
      \(x) dplyr::na_if(dplyr::na_if(x, "null"), "")
    ))
}

# pull MTD index from a key like "assay[3]-ms_run_ref" -> 3
.mztab_index <- function(x) {
  as.integer(stringr::str_match(x, "\\[(\\d+)\\]")[, 2])
}

#' Parse an mzTab-M file into a long mrmhub table
#'
#' Internal worker behind [import_data_mztab()]. Reads the `MTD`, `SMF`/`SFH`
#' and `SML`/`SMH` sections of an mzTab-M file and returns a long tibble (one
#' row per analysis x feature) shaped like the output of [parse_plain_long_csv()].
#'
#' @param path Path to a `.mzTab` file.
#' @param silent Suppress messages.
#' @return A long-format tibble.
#' @keywords internal
parse_mztab <- function(path, silent = FALSE) {
  lines <- readr::read_lines(path, progress = FALSE)
  parts <- stringr::str_split(lines, "\t")
  prefixes <- purrr::map_chr(parts, \(p) if (length(p) > 0) p[[1]] else "")

  # --- MTD: key/value pairs -------------------------------------------------
  mtd_parts <- parts[prefixes == "MTD"]
  mtd <- tibble::tibble(
    key = purrr::map_chr(mtd_parts, \(p) p[[2]]),
    value = purrr::map_chr(
      mtd_parts,
      \(p) if (length(p) >= 3) p[[3]] else NA_character_
    )
  )

  # assay[n] -> ms_run[m] -> location -> analysis_id
  assays <- mtd |>
    dplyr::filter(stringr::str_detect(
      .data$key,
      "^assay\\[\\d+\\]-ms_run_ref$"
    )) |>
    dplyr::transmute(
      assay_no = .mztab_index(.data$key),
      ms_run_no = .mztab_index(.data$value)
    )
  ms_runs <- mtd |>
    dplyr::filter(stringr::str_detect(
      .data$key,
      "^ms_run\\[\\d+\\]-location$"
    )) |>
    dplyr::transmute(
      ms_run_no = .mztab_index(.data$key),
      location = .data$value
    )

  if (nrow(assays) == 0) {
    # no assay refs: fall back to ms_run order, else number the abundance cols
    assays <- ms_runs |>
      dplyr::mutate(assay_no = dplyr::row_number())
  } else {
    assays <- dplyr::left_join(assays, ms_runs, by = "ms_run_no")
  }

  assays <- assays |>
    dplyr::mutate(
      raw_data_filename = .mztab_clean_location(.data$location),
      analysis_id = stringr::str_remove(
        .data$raw_data_filename,
        stringr::regex(
          "\\.(mzML|d|raw|wiff|wiff2|lcd|chrom)$",
          ignore_case = TRUE
        )
      ),
      analysis_id = dplyr::if_else(
        is.na(.data$analysis_id) | .data$analysis_id == "",
        paste0("assay_", .data$assay_no),
        .data$analysis_id
      )
    )

  # study_variable[k] membership -> best-effort batch_id
  sv_name <- mtd |>
    dplyr::filter(stringr::str_detect(
      .data$key,
      "^study_variable\\[\\d+\\]$"
    )) |>
    dplyr::transmute(sv_no = .mztab_index(.data$key), batch_id = .data$value)
  sv_refs <- mtd |>
    dplyr::filter(stringr::str_detect(
      .data$key,
      "^study_variable\\[\\d+\\]-assay_refs$"
    )) |>
    dplyr::transmute(
      sv_no = .mztab_index(.data$key),
      assay_no = stringr::str_split(.data$value, "\\s*\\|\\s*")
    ) |>
    tidyr::unnest("assay_no") |>
    dplyr::mutate(assay_no = .mztab_index(.data$assay_no))
  sv_map <- sv_refs |>
    dplyr::left_join(sv_name, by = "sv_no") |>
    dplyr::distinct(.data$assay_no, .keep_all = TRUE) |>
    dplyr::select("assay_no", "batch_id")
  if (nrow(sv_map) > 0) {
    assays <- dplyr::left_join(assays, sv_map, by = "assay_no")
  }

  # --- SMF (features) + SML (analyte names) ---------------------------------
  smf <- .mztab_read_section(parts, prefixes, "SFH", "SMF")
  if (is.null(smf)) {
    cli_abort(col_red(
      "No small molecule feature (SMF) section found in '{path}'. mzTab import requires SMF rows."
    ))
  }
  smf <- dplyr::mutate(smf, SMF_ID = stringr::str_squish(.data$SMF_ID))
  sml <- .mztab_read_section(parts, prefixes, "SMH", "SML")

  # SMF_ID -> chemical name / formula / mass, taken from the referencing SML
  if (!is.null(sml) && "SMF_ID_REFS" %in% names(sml)) {
    sml_map <- sml |>
      dplyr::transmute(
        smf_id = stringr::str_split(.data$SMF_ID_REFS, "\\s*\\|\\s*"),
        chemical_name = dplyr::coalesce(
          .mztab_col(sml, "chemical_name"),
          .mztab_col(sml, "database_identifier")
        ),
        chem_formula = .mztab_col(sml, "chemical_formula"),
        molecular_weight = suppressWarnings(as.numeric(
          .mztab_col(sml, "theoretical_neutral_mass")
        ))
      ) |>
      tidyr::unnest("smf_id") |>
      dplyr::mutate(smf_id = stringr::str_squish(.data$smf_id)) |>
      dplyr::distinct(.data$smf_id, .keep_all = TRUE)
  } else {
    sml_map <- tibble::tibble(smf_id = character(), chemical_name = character())
  }

  features <- smf |>
    dplyr::transmute(
      smf_id = .data$SMF_ID,
      adduct_ion = .mztab_col(smf, "adduct_ion"),
      method_product_mz = suppressWarnings(as.numeric(
        .mztab_col(smf, "exp_mass_to_charge")
      )),
      feature_rt = suppressWarnings(as.numeric(
        .mztab_col(smf, "retention_time_in_seconds")
      )) /
        60,
      is_istd = .mztab_logical(.mztab_col(
        smf,
        "opt_global_is_internal_standard"
      ))
    ) |>
    dplyr::left_join(sml_map, by = "smf_id") |>
    dplyr::mutate(
      method_polarity = dplyr::case_when(
        stringr::str_ends(.data$adduct_ion, "-") ~ "NEG",
        stringr::str_ends(.data$adduct_ion, "\\+") ~ "POS",
        TRUE ~ NA_character_
      ),
      .base = dplyr::coalesce(.data$chemical_name, paste0("SMF_", .data$smf_id))
    )

  # build a unique, human-readable feature_id (disambiguate shared names)
  features <- features |>
    dplyr::mutate(.shared = dplyr::n() > 1, .by = ".base") |>
    dplyr::mutate(
      feature_id = dplyr::if_else(
        .data$.shared,
        paste0(
          .data$.base,
          " | ",
          dplyr::coalesce(.data$adduct_ion, paste0("SMF", .data$smf_id))
        ),
        .data$.base
      )
    )
  features$feature_id <- make.unique(features$feature_id, sep = " #")

  # --- abundance_assay[n] -> long feature_intensity -------------------------
  smf_names <- names(smf)
  abund_cols <- smf_names[stringr::str_detect(
    smf_names,
    "^abundance_assay\\[\\d+\\]$"
  )]
  if (length(abund_cols) == 0) {
    cli_abort(col_red(
      "No 'abundance_assay[n]' columns found in the SMF section of '{path}'."
    ))
  }

  long <- smf |>
    dplyr::select(smf_id = "SMF_ID", dplyr::all_of(abund_cols)) |>
    tidyr::pivot_longer(
      dplyr::all_of(abund_cols),
      names_to = "assay_label",
      values_to = "feature_intensity"
    ) |>
    dplyr::mutate(
      assay_no = .mztab_index(.data$assay_label),
      feature_intensity = suppressWarnings(as.numeric(.data$feature_intensity))
    ) |>
    dplyr::left_join(assays, by = "assay_no") |>
    dplyr::left_join(features, by = "smf_id") |>
    dplyr::mutate(integration_qualifier = FALSE) |>
    dplyr::select(
      "analysis_id",
      "raw_data_filename",
      "feature_id",
      "feature_intensity",
      "integration_qualifier",
      dplyr::any_of(c(
        "batch_id",
        "method_product_mz",
        "method_polarity",
        "feature_rt",
        "chem_formula",
        "molecular_weight",
        "is_istd"
      ))
    )

  if (!silent) {
    cli_alert_info(glue::glue(
      "Parsed mzTab-M: {dplyr::n_distinct(long$analysis_id)} analyses x {dplyr::n_distinct(long$feature_id)} features."
    ))
  }
  long
}

# helper: safe column extraction (returns NA vector if column absent)
.mztab_col <- function(tbl, name) {
  if (name %in% names(tbl)) tbl[[name]] else rep(NA_character_, nrow(tbl))
}

# helper: "TRUE"/"true" -> TRUE, else FALSE/NA
.mztab_logical <- function(x) {
  out <- toupper(x) == "TRUE"
  out
}

# helper: turn an ms_run location URI into a plain filename
.mztab_clean_location <- function(loc) {
  loc <- stringr::str_remove(loc, "^file://+")
  loc <- vapply(
    loc,
    function(x) if (is.na(x)) NA_character_ else utils::URLdecode(x),
    character(1),
    USE.NAMES = FALSE
  )
  fs::path_file(loc)
}

#' Import data from an mzTab-M file
#'
#' Imports quantitative results from an
#' [mzTab-M](https://github.com/HUPO-PSI/mzTab-M) file (e.g. produced by
#' Lipid Data Analyzer, MS-DIAL or MZmine) into an `MRMhubExperiment`. Each
#' Small Molecule Feature (`SMF`) becomes an mrmhub feature and each assay an
#' analysis; the per-assay abundances are imported as `feature_intensity`.
#'
#' @details
#' mzTab-M is a quantification *report*, so an import is necessarily partial:
#' the single reported abundance per feature is mapped to `feature_intensity`,
#' and feature identities (name, formula, neutral mass, m/z, retention time)
#' are taken from the `SMF`/`SML` sections where available. Internal-standard
#' relationships, QC-type assignments and calibration metadata are **not**
#' part of mzTab-M and must be supplied afterwards with [add_metadata()].
#' `study_variable` group membership is imported best-effort as `batch_id`
#' (mzTab-M has no analytical-batch concept).
#'
#' @param data An `MRMhubExperiment` object (e.g. from [MRMhubExperiment()]).
#' @param path Path to a `.mzTab` file, or a directory of them.
#' @param import_metadata If `TRUE` (default), derive analysis/feature metadata
#'   (incl. `batch_id`, formula, neutral mass) from the imported data via
#'   [import_metadata_from_data()].
#' @param silent Suppress messages.
#'
#' @return The updated `MRMhubExperiment`.
#'
#' @seealso [import_data_mrmhub()], [save_dataset_mztab()], [add_metadata()]
#'
#' @examples
#' \dontrun{
#' mexp <- MRMhubExperiment()
#' mexp <- import_data_mztab(mexp, "LDA_export.mzTab")
#' }
#'
#' @export
import_data_mztab <- function(
  data = NULL,
  path,
  import_metadata = TRUE,
  silent = FALSE
) {
  check_data(data)
  data <- import_data_main(
    data = data,
    path = path,
    import_function = "parse_mztab",
    file_ext = "*.mzTab|*.mztab",
    silent = silent
  )
  data <- set_intensity_var(
    data,
    variable_name = NULL,
    auto_select = TRUE,
    warnings = !silent,
    "feature_intensity"
  )
  if (import_metadata) {
    data <- import_metadata_from_data(data, qc_type_column_name = "qc_type")
  }
  data
}
