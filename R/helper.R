safe_min <- function(x, na.rm = FALSE) {
  if (all(is.na(x) | is.nan(x))) NA_real_ else min(x, na.rm = na.rm)
}

safe_max <- function(x, na.rm = FALSE) {
  if (all(is.na(x) | is.nan(x))) NA_real_ else max(x, na.rm = na.rm)
}

# checks if all values of a specific column are identical in a group
# return NA if data frame has no data
check_groupwise_identical_ids <- function(data, group_col, id_col) {
  if (nrow(data) == 0) {
    stop("data has no rows")
  }
  data |>
    summarise(
      all_identical = dplyr::n_distinct(.data[[id_col]]) == 1,
      .by = all_of(group_col)
    ) |>
    pull(.data$all_identical) |>
    all()
}

# Used for qc filtering ####
# Function to used to compare qc values with criteria and deal with NA

#The compare_values function compares a column in a data frame to a threshold using a
#specified operator. It handles NA values by returning NA when both are NA, FALSE
#when the column is NA and the threshold is numeric, and applies the operator
#(e.g., >, <, ==) when both are numeric. If the column does not exist, it returns NA.
# na_replace parameter controls how to handle NA values in the comparison result. NAs will be set as defined by na_replace

# Behaviour:
# value is NA , threshold NA -> NA
# value is num , threshold NA -> NA
# value is NA , threshold is Num -> FALSE
# value is num , threshold is num -> TRUE/FAL

# TODO: Add to function description,
# TODO: make this function public for user to build own?

compare_values <- function(tbl, val, threshold, operator, na_replace = FALSE) {
  if (nrow(tbl) == 0) {
    stop("tbl has no rows")
  }
  if (!val %in% names(tbl) && !is.na(threshold)) {
    var_name <- deparse(substitute(threshold))
    error_message <- case_when(
      str_detect(
        var_name,
        "conc"
      ) ~
        "Cannot filter by {.field {var_name}} because concentration data is unavailable. Please quantify the data first using `quantify_by_*()` functions.",
      str_detect(
        var_name,
        "normint"
      ) ~
        "Cannot filter by {.field {var_name}} because normalized data is unavailable. Please normalize the data first using `normalize_by_*()` functions.",
      str_detect(
        var_name,
        "response"
      ) ~
        "Cannot filter by {.field {var_name}} because response curve data is unavailable. Please verify the corresponding data and metadata.",
      TRUE ~ "QC parameter is not available. Please verify {.arg val}."
    )
    cli_abort(error_message)
  }

  if (all(is.na(tbl[[val]])) && !is.na(threshold)) {
    var_name <- deparse(substitute(threshold))
    cli_abort(
      "The QC parameter {.field {var_name}} is not available. Please verify that the data were processed accordingly and that the selected QC type is present and contains results."
    )
  }

  if (any(is.na(tbl[[val]])) && !is.na(threshold)) {
    var_name <- deparse(substitute(threshold))
    features_with_na <- tbl[is.na(tbl[[val]]), ]$feature_id

    features_with_na <- glue::glue_collapse(
      features_with_na,
      sep = ", ",
      width = 80,
      last = ", and "
    )

    mh_warn(
      "The QC parameter {.field {var_name}} contains NAs for the following features: {features_with_na}. These features failed QC."
    )
  }
  v_val <- tbl[[val]]
  if (is.na(threshold)) {
    return(rep(NA, nrow(tbl)))
  }
  result <- match.fun(operator)(v_val, threshold)
  result <- replace_na(result, na_replace)
}


# ISTDs pass a criterion they have a verdict for; NA ("not applied") stays NA
exempt_istd <- function(x, is_istd) {
  x | (is_istd & !is.na(x))
}

# performs element-wise logical operations (AND or OR) across multiple
# logical vectors in a list. It returns a vector of the results,
# where each element is the result of applying the specified operation to the
# corresponding elements of the input vectors.
# If any element is NA, the result for that position will also be NA.
# If list is empty NULL is returned
comp_lgl_vec <- function(lgl_list, .operator) {
  # Convert the list of vectors into a matrix
  matrix_data <- do.call(cbind, lgl_list)

  # Define the operation function based on the operator
  op_func <- switch(
    .operator,
    "AND" = function(x) if (all(is.na(x))) NA else all(x, na.rm = TRUE),
    "OR" = function(x) if (all(is.na(x))) NA else any(x, na.rm = TRUE),
    "XOR" = function(x) if (all(is.na(x))) NA else Reduce(xor, x[!is.na(x)]),
    stop("Unsupported operator")
  )

  # Apply the operation function across the columns
  result <- apply(matrix_data, 1, op_func)

  return(result)
}


# Custom assertr function to test if at least one of provided columns exists
has_any_name = function(...) {
  check_this <- list(...)
  parent <- parent.frame()
  given_names <- rlang::env_names(parent$.top_env)
  given_names <- given_names[given_names != ".data"]
  any(check_this %in% given_names)
}


# Add each column of `defaults` (a named list: column = default value) that is
# missing from `data` (names compared case-insensitively). Columns named in
# `replace_all_na` are also set to their default when they hold only NA.
add_missing_columns <- function(data, defaults, replace_all_na = character()) {
  for (col in names(defaults)) {
    if (!tolower(col) %in% tolower(names(data))) {
      data[[col]] <- defaults[[col]]
    } else if (col %in% replace_all_na && all(is.na(data[[col]]))) {
      data[[col]] <- defaults[[col]]
    }
  }
  data
}

#' Get concentration unit based on sample amount unit
#' internally analyte amount is pmol, thus when sample amount unit is uL,
#' pmol/uL equal to umol/L
#'
#' @param sample_amount_unit string with sample amount unit
#' @param analyte_amount_unit string with base analyte amount unit
#' @return string with feature_conc unit
#' @noRd

# `conc_analyte_unit` was added after the bundled datasets and users' saved
# objects were serialized, and R does not retrofit slots onto deserialized S4
# instances. Such an object cannot have been quantitated by a version that sets
# the slot, so NA -- no concentration unit -- is the right answer for it.
get_conc_analyte_unit <- function(data) {
  if (methods::.hasSlot(data, "conc_analyte_unit")) {
    data@conc_analyte_unit
  } else {
    NA_character_
  }
}

get_conc_unit <- function(sample_amount_unit, analyte_amount_unit) {
  units <- tolower(unique(sample_amount_unit))
  analyte_units <- tolower(unique(analyte_amount_unit))
  if (length(units) == 0) {
    return(NA_character_)
  }
  # Unquantitated data has no analyte amount unit, so no concentration unit
  # can be named. Guessing one would misreport mass-quantitated data as molar.
  if (length(analyte_units) == 0 || all(is.na(analyte_units))) {
    return(NA_character_)
  }
  if (length(units) > 1) {
    conc_unit <- glue::glue(
      "{analyte_amount_unit}/sample amount unit (multiple units)"
    )
  } else if (length(analyte_units) > 1) {
    conc_unit <- glue::glue(
      "analyte amount unit/{sample_amount_unit} (multiple units)"
    )
  } else if (analyte_units == "pmol" && (units == "ul" | units == "\U003BCl")) {
    conc_unit <- "\U003BCmol/L"
  } else if (analyte_units == "ng" && (units == "ul" | units == "\U003BCl")) {
    conc_unit <- "\U003BCg/L"
  } else if (
    !str_detect(analyte_units, "\\/") && !str_detect(analyte_units, "\\-1")
  ) {
    conc_unit <- glue::glue("{analyte_amount_unit}/{sample_amount_unit}")
  } else {
    conc_unit <- analyte_amount_unit
  }

  unique(conc_unit)
}

# ---- Shared pretty-axis helper -------------------------------------------
# One place every plot builds its continuous axes, so break counts adapt to
# panel size and labels stay legible instead of each plot rolling its own.
# `plot_abundanceprofile` (plot-featureprofile.R) is the log-axis template.

#' Panel-size-aware tick count
#'
#' More facets per page -> fewer ticks per panel, so faceted plots don't crowd
#' or blank. Floored at 3 to keep the ">=3 non-empty labels" guarantee.
#'
#' @param n_panels Number of panels on the page (`rows_page * cols_page`).
#' @keywords internal
pretty_n_breaks <- function(n_panels = 1L) {
  if (n_panels <= 1L) {
    6L
  } else if (n_panels <= 4L) {
    5L
  } else if (n_panels <= 12L) {
    4L
  } else {
    3L
  }
}

# Adaptive axis labels: plain comma numbers, switching the *whole* axis to
# superscript scientific (`10^n` / `m %*% 10^n`) only when a break reaches ~1e5
# or ~1e-4. Keyed on the break VALUES, not the variable -- a CV/RT never trips
# it, a raw intensity does -- so one formatter serves every plot and there is no
# per-axis "is this scientific" bookkeeping to drift. Returns a list of plotmath
# expressions in the scientific case so ggplot renders real superscripts.
.pretty_labels <- function(x) {
  # Switch the whole axis to superscript once a break reaches these magnitudes.
  # 1e4 keeps CV / RT / concentration / run-order (all < 1e4) as plain numbers
  # while high intensity/response axes (>= 1e4) read as 10^n. Tune here.
  hi <- 1e4
  lo <- 1e-4
  ax <- abs(x[is.finite(x) & x != 0])
  extreme <- length(ax) > 0L && (max(ax) >= hi || min(ax) < lo)
  if (!extreme) {
    return(scales::label_comma()(x))
  }
  lapply(x, function(v) {
    if (is.na(v)) {
      return(NA)
    }
    if (v == 0) {
      return(0)
    }
    e <- floor(log10(abs(v)))
    m <- round(v / 10^e, 1)
    if (isTRUE(all.equal(m, 1))) {
      bquote(10^.(e))
    } else {
      # centered dot (%.%) is narrower than the times sign (%*%)
      bquote(.(m) %.% 10^.(e))
    }
  })
}

# Decade exponent range covering the positive limits.
.log_decade_range <- function(limits) {
  limits <- limits[is.finite(limits) & limits > 0]
  if (length(limits) < 1) {
    return(NULL)
  }
  c(floor(log10(min(limits))), ceiling(log10(max(limits))))
}

# Decade breaks (10^n) spanning the axis limits — the featureprofile template.
.pretty_log_breaks <- function(limits) {
  rng <- .log_decade_range(limits)
  if (is.null(rng)) {
    return(numeric(0))
  }
  10^(rng[1]:rng[2])
}

# 1:9 subdivisions between decades -> faint log gridlines.
.pretty_log_minor <- function(limits) {
  rng <- .log_decade_range(limits)
  if (is.null(rng)) {
    return(numeric(0))
  }
  as.vector(outer(1:9, 10^(rng[1]:rng[2])))
}

# Decade-padded limits guaranteeing >=3 decade breaks (>=2 decade span), so a
# narrow-range log panel still renders >=3 clean 10^n labels. Used only when the
# caller supplies no limits of its own.
.pretty_log_limits <- function(limits) {
  rng <- .log_decade_range(limits)
  if (is.null(rng)) {
    return(c(NA_real_, NA_real_))
  }
  if (rng[2] - rng[1] < 2) {
    rng[2] <- rng[1] + 2
  }
  c(10^rng[1], 10^rng[2])
}

# breaks_extended targets `n`, but bumps up until >=3 breaks land in range so a
# small panel still honours the >=3-label guarantee.
.pretty_lin_breaks <- function(n) {
  function(limits) {
    for (k in seq.int(n, n + 3L)) {
      b <- scales::breaks_extended(k)(limits)
      if (sum(b >= limits[1] & b <= limits[2], na.rm = TRUE) >= 3L) {
        return(b)
      }
    }
    scales::breaks_extended(max(n + 3L, 5L))(limits)
  }
}

# Builds one continuous scale for either axis; x/y differ only in the scale fn.
.scale_pretty <- function(
  axis,
  log = FALSE,
  n = 5L,
  limits = NULL,
  expand = ggplot2::waiver(),
  name = ggplot2::waiver(),
  minor_ticks = TRUE
) {
  if (log) {
    scale_fn <- if (axis == "x") {
      ggplot2::scale_x_log10
    } else {
      ggplot2::scale_y_log10
    }
    # A fully-NA (or NULL) limits vector means "no caller limits": decade-pad so
    # a narrow-range panel still renders >=3 clean decade labels.
    caller_limits <- !is.null(limits) &&
      !(is.numeric(limits) && all(is.na(limits)))
    scale_fn(
      name = name,
      breaks = .pretty_log_breaks,
      minor_breaks = .pretty_log_minor,
      labels = .pretty_labels,
      limits = if (caller_limits) limits else .pretty_log_limits,
      expand = expand
    )
  } else {
    scale_fn <- if (axis == "x") {
      ggplot2::scale_x_continuous
    } else {
      ggplot2::scale_y_continuous
    }
    scale_fn(
      name = name,
      breaks = .pretty_lin_breaks(n),
      labels = .pretty_labels,
      guide = if (minor_ticks) {
        ggplot2::guide_axis(minor.ticks = TRUE)
      } else {
        ggplot2::waiver()
      },
      limits = limits,
      expand = expand
    )
  }
}

#' Pretty continuous x/y scale
#'
#' Returns a ggplot2 scale (composable with `+` or `ggh4x::facetted_pos_scales`)
#' with panel-aware break counts, adaptive labels (`.pretty_labels()`: plain
#' numbers, superscript scientific only for extreme magnitudes), and minor ticks.
#' Log axes use decade breaks; add `pretty_logticks()` for the log tick marks.
#' `expand` is passed straight through so callers keep their tuned axis expansion.
#'
#' @param log Log10 axis if `TRUE`, else linear.
#' @param n Target number of breaks (see `pretty_n_breaks()`).
#' @param limits,expand,name Passed to the underlying scale unchanged.
#' @param minor_ticks Add minor tick marks on linear axes.
#' @keywords internal
scale_pretty_x <- function(
  log = FALSE,
  n = 5L,
  limits = NULL,
  expand = ggplot2::waiver(),
  name = ggplot2::waiver(),
  minor_ticks = TRUE
) {
  .scale_pretty("x", log, n, limits, expand, name, minor_ticks)
}

#' @rdname scale_pretty_x
#' @keywords internal
scale_pretty_y <- function(
  log = FALSE,
  n = 5L,
  limits = NULL,
  expand = ggplot2::waiver(),
  name = ggplot2::waiver(),
  minor_ticks = TRUE
) {
  .scale_pretty("y", log, n, limits, expand, name, minor_ticks)
}

#' Styled log-tick marks for a log axis
#'
#' `ggh4x` (0.3.1) has no `guide_axis_logticks`, so log tick marks use
#' [ggplot2::annotation_logticks()] as in `plot_abundanceprofile`. Add once per
#' plot when the log scale is global.
#'
#' @param sides Which axes carry the ticks, e.g. `"b"`, `"l"`, `"bl"`.
#' @keywords internal
pretty_logticks <- function(sides = "bl") {
  ggplot2::annotation_logticks(
    base = 10,
    sides = sides,
    linewidth = 0.3,
    colour = "grey80",
    long = ggplot2::unit(1, "mm"),
    mid = ggplot2::unit(0.5, "mm"),
    short = ggplot2::unit(0.5, "mm")
  )
}


# Used to desaturate colors to be used as fill colors in plots
desaturate_colors <- function(colors, amount = 0.5) {
  x <- sapply(colors, function(col) {
    rgb_vals <- grDevices::col2rgb(col)
    hsv_vals <- grDevices::rgb2hsv(
      r = rgb_vals[1],
      g = rgb_vals[2],
      b = rgb_vals[3]
    )
    grDevices::hsv(
      h = hsv_vals["h", ],
      s = hsv_vals["s", ] * amount,
      v = hsv_vals["v", ]
    )
  })
  if (all(is.null(names(colors)))) unname(x) else x
}
