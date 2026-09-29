#' Linear regression statistics of response curves
#'
#' This function calculates linear regression statistics (R², slope, and intercept)
#' for each response curve in the provided `MRMhubExperiment` object. Each curve
#' is fitted on its points with a non-missing intensity, with a warning when some
#' are missing; a curve with 2 such points has a slope and intercept but no R²
#' (`NA`), and a curve with fewer gives `NA` throughout. Before fitting,
#' the analyzed sample amount (`x`) and feature intensity (`y`) of these points
#' are each scaled to their maximum (set to 1), so the returned `slopenorm` and
#' `y0norm` are on this normalized scale.
#' Optionally, it can include
#' additional statistics from the `lancer` package (if installed) when `with_saturation_stats` is set to `TRUE`.
#'
#' @param data A [`MRMhubExperiment`][MRMhubExperiment-class] object containing the dataset and response curve annotations.
#' @param with_saturation_stats Logical, if `TRUE`, include additional statistics from the `lancer` package.
#'   Note: The `lancer` package must be installed when this argument is set to `TRUE`.
#' @param limit_to_rqc Logical, if `TRUE`, only include rows with `qc_type == "RQC"`. Default is `FALSE`.
#' @param silent_invalid_data Logical, if `TRUE` suppresses raising an error when
#' required data or metadata are missing, or there is a mismatch between them.

#'
#' @return A tibble with linear regression statistics (`r2`, `slopenorm`, `y0norm`) for each curve,
#'   or `NULL` if no data matches the criteria.
#'
#' @export
get_response_curve_stats <- function(
  data = NULL,
  with_saturation_stats = FALSE,
  limit_to_rqc = FALSE,
  silent_invalid_data = FALSE
) {
  check_data(data)
  d_stats <- data@dataset

  if (nrow(data@annot_responsecurves) == 0) {
    if (!silent_invalid_data) {
      cli::cli_abort(
        "No response curve metadata found. Please import the corresponding metadata first."
      )
    }
    return(NULL)
  }

  if (limit_to_rqc) {
    d_stats <- d_stats |>
      dplyr::filter(.data$qc_type == "RQC")
    if (nrow(d_stats) == 0) {
      if (!silent_invalid_data) {
        cli::cli_abort(
          "No analyses/samples of QC type `RQC` found. Please verify the analysis metadata."
        )
      }
      return(NULL)
    }
  }

  d_stats <- d_stats |>
    select("analysis_id", "feature_id", "feature_intensity") |>
    dplyr::inner_join(data@annot_responsecurves, by = "analysis_id")

  n_diff <- setdiff(data@annot_responsecurves$analysis_id, d_stats$analysis_id)

  # A subset of missing curve points/series must not void every response metric:
  # warn (naming the missing analysis IDs and their curves), then fit whatever
  # series remain. Abort/NULL only when nothing matches (`nrow(d_stats) == 0`).
  if (nrow(d_stats) == 0) {
    if (!silent_invalid_data) {
      cli::cli_abort(
        "No analysis IDs in the response curve metadata match the dataset. Please verify your metadata."
      )
    }
    return(NULL)
  }

  if (length(n_diff) > 0 && !silent_invalid_data) {
    missing_curves <- data@annot_responsecurves |>
      dplyr::filter(.data$analysis_id %in% n_diff)
    cli::cli_warn(c(
      "Some response curve analyses in the metadata are absent from the dataset and are skipped.",
      "i" = "Affected curve{?s}: {.val {sort(unique(missing_curves$curve_id))}}.",
      "i" = "Missing analysis ID{?s}: {.val {sort(n_diff)}}."
    ))
  }

  # Curves with some (not all) points missing are fitted on the points present;
  # reported also when `silent_invalid_data`, as the fit is on fewer points
  partial <- d_stats |>
    dplyr::summarise(
      n_na = sum(is.na(.data$feature_intensity)),
      n = dplyr::n(),
      .by = c("feature_id", "curve_id")
    ) |>
    dplyr::filter(.data$n_na > 0, .data$n_na < .data$n)
  if (nrow(partial) > 0) {
    cli::cli_warn(c(
      "Response curves with missing points were fitted on the remaining points (R\u00b2 needs at least 3 points, slope and intercept 2).",
      "i" = "Affected feature{?s}: {.val {mh_vec(unique(partial$feature_id))}}."
    ))
  }

  d_stats <- d_stats |>
    dplyr::summarise(
      fit = list(fit_scaled_line(
        .data$analyzed_amount,
        .data$feature_intensity
      )),
      .by = c("feature_id", "curve_id")
    ) |>
    dplyr::mutate(
      r2 = vapply(.data$fit, `[[`, numeric(1), "r2"),
      slopenorm = vapply(.data$fit, `[[`, numeric(1), "slopenorm"),
      y0norm = vapply(.data$fit, `[[`, numeric(1), "y0norm"),
      fit = NULL
    ) |>
    dplyr::arrange(.data$feature_id, .data$curve_id) |>
    tidyr::pivot_wider(
      names_from = "curve_id",
      values_from = c("r2", "slopenorm", "y0norm"),
      names_prefix = "rqc_"
    )

  if (with_saturation_stats) {
    if (!rlang::is_installed("lancer")) {
      cli::cli_abort(
        # nocov start
        c(
          "{.strong Package `lancer`} must be installed when `with_saturation_stats = TRUE`.",
          "It is available from {.url https://github.com/SLINGhub/lancer}.",
          "Install it using {.code pak::pkg_install(\"SLINGhub/lancer\")}."
        ),
        class = "missing_package_error"
      ) # nocov end
    }

    d_stats_lancer <- data@dataset |>
      select("analysis_id", "feature_id", "feature_intensity") |>
      inner_join(data@annot_responsecurves, by = "analysis_id") |>
      dplyr::group_by(.data$feature_id, .data$curve_id) |>
      dplyr::filter(!all(is.na(.data$feature_intensity))) |>
      tidyr::nest() |>
      mutate(
        lancer_raw = map(data, \(x) {
          lancer::summarise_curve_data(
            x,
            "analyzed_amount",
            "feature_intensity"
          )
        }),
        lancer = map(.data$lancer_raw, \(x) lancer::evaluate_linearity(x))
      ) |>
      select(-"lancer_raw") |>
      tidyr::unnest(c("lancer")) |>
      dplyr::select(
        "feature_id",
        "curve_id",
        "r_corr",
        class_wf2 = "wf2_group",
        "pra_linear",
        "mandel_p_val",
        "concavity"
      ) |>
      tidyr::pivot_wider(
        names_from = "curve_id",
        values_from = c(
          "r_corr",
          "class_wf2",
          "pra_linear",
          "mandel_p_val",
          "concavity"
        ),
        names_prefix = "rqc_"
      ) |>
      ungroup()

    d_stats <- d_stats |> left_join(d_stats_lancer, by = c("feature_id"))
  }
  d_stats
}

# Straight-line fit of one response curve on the points with an intensity,
# each scaled to its maximum (1 = max), by least squares as in lm(y ~ x). No fit
# for fewer than 2 points or equal amounts; R2 is NA for fewer than 3 points or
# a flat curve.
fit_scaled_line <- function(amount, intensity) {
  no_fit <- c(r2 = NA_real_, slopenorm = NA_real_, y0norm = NA_real_)
  keep <- !is.na(intensity)
  if (sum(keep) < 2) {
    return(no_fit)
  }
  x <- amount[keep] / safe_max(amount[keep], na.rm = TRUE)
  y <- intensity[keep] / max(intensity[keep])
  ok <- is.finite(x) & is.finite(y) # as lm's na.omit
  x <- x[ok]
  y <- y[ok]
  if (length(x) < 2 || stats::var(x) == 0) {
    return(no_fit)
  }
  fit <- stats::.lm.fit(cbind(1, x), y)
  tss <- sum((y - mean(y))^2)
  c(
    r2 = if (length(x) > 2 && tss > 0) {
      1 - sum(fit$residuals^2) / tss
    } else {
      NA_real_
    },
    slopenorm = fit$coefficients[[2]],
    y0norm = fit$coefficients[[1]]
  )
}
