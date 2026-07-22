#' Percent coefficient of variation (%CV)
#'
#' This function computes the percent coefficient of variation  of the values in x.
#' If na.rm is TRUE then missing values are removed before computation proceeds.
#'
#' @param x a numeric vector with untransformed data
#' @param na.rm logical, if TRUE then NA values are stripped from x before
#' computation takes place
#' @param use_robust_cv logical, if TRUE the robust coefficient of variation
#' (scaled median absolute deviation / median) is computed instead of the
#' standard CV (SD / mean)
#' @param min_n integer, the minimum number of observations (non-missing ones
#' when `na.rm = TRUE`) required to return a CV. Fewer than `min_n` values
#' return `NA_real_`. The default (`1`) is a no-op, since `sd()`/`mad()` already
#' return `NA` for fewer than two values.
#'
#' @return a numeric value. If the mean (or the median, for robust CV) is zero,
#' or x is not numeric, NA_real_ is returned

#' @export
#'
#' @examples
#' cv(c(5, 6, 3, 4, 5, NA), na.rm = TRUE)

cv <- function(x, na.rm = FALSE, use_robust_cv = FALSE, min_n = 1L) {
  if (!is.numeric(x)) {
    return(NA_real_)
  }
  # A %CV over too few replicates is not a meaningful precision estimate.
  # `min_n` is the smallest number of observations (non-missing ones when
  # `na.rm = TRUE`) for which a CV is returned; below it the result is NA.
  n_obs <- if (na.rm) sum(!is.na(x)) else length(x)
  if (n_obs < min_n) {
    return(NA_real_)
  }
  if (use_robust_cv) {
    # Robust CV: scaled MAD over the median, on the same scale as the standard
    # SD / mean CV. mad()'s default constant (1.4826) makes MAD a consistent
    # estimator of SD for normal data.
    center <- median(x, na.rm = na.rm)
    spread <- mad(x, na.rm = na.rm)
  } else {
    center <- mean(x, na.rm = na.rm)
    spread <- sd(x, na.rm = na.rm)
  }
  # a zero (or NA) denominator makes the CV undefined
  if (is.na(center) || center == 0) {
    return(NA_real_)
  }
  spread / center * 100
}

#' Percent coefficient of variation (%CV) based on log-transformation
#'
#' Computes the percent coefficient of variation (CV) based on the log-transformation of
#' the input data. This can be more robust in certain cases, especially when the
#' data is not normally distributed.
#'
#' @param x a numeric vector with untransformed data
#' @param na.rm logical, if TRUE then NA values are stripped from x before
#' computation takes place
#'
#' @return a numeric value. If x contains a zero, then NaN is returned. If x is
#' not numeric, NA_real_ is returned
#' @references
#' Canchola et al. (2017) Correct use of percent coefficient of variation (% CV) formula for log-transformed data. MOJ Proteomics Bioinform. 2017;6(4):316‒317.
#' [DOI: 10.15406/mojpb.2017.06.00200](https://doi.org/10.15406/mojpb.2017.06.00200)
#' @export
#'
#' @examples
#' cv_log(c(5, 6, 3, 4, 5, NA), na.rm = TRUE)
#'
cv_log <- function(x, na.rm = FALSE) {
  # sqrt(exp(1)^(sd(log(x, ...))^2)-1) *100
  sqrt(10^(log(10) * stats::sd(log(x, 10), na.rm)^2) - 1) * 100
}


#' Pooled standard deviation across groups
#'
#' Pools the within-group variances of `x` across the levels of `group`,
#' weighting each group by its degrees of freedom (`n_i - 1`), and returns the
#' square root. This is the within-group precision estimate: unlike a plain
#' `sd(x)` it is not inflated by systematic shifts *between* groups (e.g. batch
#' offsets or drift), so it is the appropriate spread for a batch-pooled %RSD.
#'
#' @param x a numeric vector
#' @param group a vector the same length as `x` giving the pooling group of each
#' value (e.g. `batch_id`)
#' @param na.rm logical, if TRUE then NA values in `x` are stripped before
#' pooling
#' @param min_n integer, the minimum number of non-missing values a group must
#' have to contribute. Groups with fewer than `min_n` are dropped; a group is
#' always dropped below two values, which have no within-group variance. The
#' default is `2`.
#'
#' @return a single numeric value. `NA_real_` if `x` is not numeric or no group
#' has enough replicates to pool.
#' @export
#'
#' @examples
#' pooled_sd(c(5, 6, 4, 15, 16, 14), group = c(1, 1, 1, 2, 2, 2))
pooled_sd <- function(x, group, na.rm = FALSE, min_n = 2L) {
  if (!is.numeric(x)) {
    return(NA_real_)
  }
  # match the get_outlier_bounds/cv convention: an NA anywhere makes the result
  # NA unless the caller opts into dropping missing values.
  if (!na.rm && anyNA(x)) {
    return(NA_real_)
  }
  per_group <- tibble(x = x, group = group) |>
    filter(if (na.rm) !is.na(x) else TRUE) |>
    summarise(n = n(), var = var(x), .by = group) |>
    # a group needs at least two (and at least min_n) values for a variance
    filter(n >= max(min_n, 2L), !is.na(var))

  if (nrow(per_group) == 0) {
    return(NA_real_)
  }
  sqrt(sum((per_group$n - 1) * per_group$var) / sum(per_group$n - 1))
}

#' Pooled percent relative standard deviation (%RSD) across groups
#'
#' [pooled_sd()] expressed as a percentage of the grand mean of `x`, i.e. a
#' batch-pooled %CV. The pooled SD weights each group by its degrees of freedom
#' and the grand mean weights each value equally, so both are consistently
#' weighted by group size. See [pooled_sd()] for how groups are pooled.
#'
#' @inheritParams pooled_sd
#'
#' @return a single numeric value. `NA_real_` if the grand mean is zero or NA,
#' `x` is not numeric, or no group has enough replicates.
#' @export
#'
#' @examples
#' pooled_rsd(c(5, 6, 4, 15, 16, 14), group = c(1, 1, 1, 2, 2, 2))
pooled_rsd <- function(x, group, na.rm = FALSE, min_n = 2L) {
  spread <- pooled_sd(x, group, na.rm = na.rm, min_n = min_n)
  center <- mean(x, na.rm = na.rm)
  if (is.na(spread) || is.na(center) || center == 0) {
    return(NA_real_)
  }
  spread / center * 100
}

#' Get outlier bounds via different methods
#'
#' Computes lower and upper bounds for a numeric vector using one of several methods:
#' \itemize{
#'   \item \code{"iqr"}: Tukey's Interquartile Range fences
#'   \item \code{"mad"}: Median Absolute Deviation
#'   \item \code{"sd"}: Standard deviation from mean
#'   \item \code{"quantile"}: Fixed percentile cutoffs
#'   \item \code{"z_normal"}: Standard Z-score using mean & SD
#'   \item \code{"z_robust"}: Modified Z-score using median & MAD
#'   \item \code{"fold_change"}: Median ± log10(k), assumes log-transformed data
#' }
#'
#' @param x A numeric vector.
#' @param method Character string: one of \code{"iqr"}, \code{"mad"}, \code{"sd"},
#'   \code{"quantile"}, \code{"z_normal"}, \code{"z_robust"}, or \code{"fold_change"}.
#' @param k Numeric multiplier or threshold. Defaults depend on method:
#'   \itemize{
#'     \item \code{"iqr"}: 1.5 (multiplier of IQR)
#'     \item \code{"mad"}: 3 (multiplier of MAD)
#'     \item \code{"sd"}: 3 (multiplier of SD)
#'     \item \code{"z_normal"}: 3 (threshold in SD units)
#'     \item \code{"z_robust"}: 3.5 (threshold in robust Z units)
#'     \item \code{"fold_change"}: 2 (fold-change multiplier, assumes log-transformed data)
#'     \item \code{"quantile"}: 0.01 (lower/upper quantiles, e.g., 1% and 99%)
#'   }
#' @param outlier_log Logical. If \code{TRUE}, applies log10 transformation to \code{x}
#' @param na.rm Logical. Should missing values be removed? Default is \code{FALSE}.
#'
#' @return A numeric vector of length 2: \code{c(lower_bound, upper_bound)} representing
#' the smallest and largest observed values within the computed fences.
#'
#' @examples
#' get_outlier_bounds(c(1, 2, 3, 4, 100), "iqr")
#' get_outlier_bounds(c(1, 2, 3, 4, 100), "mad")
#' get_outlier_bounds(c(1, 2, 3, 4, 100), "sd")
#' get_outlier_bounds(c(1, 2, 3, 4, 100), "quantile", k = 0.05)
#' get_outlier_bounds(c(1, 2, 3, 4, 100), "z_normal")
#' get_outlier_bounds(c(1, 2, 3, 4, 100), "z_robust")
#' get_outlier_bounds(log10(c(1, 2, 4, 8)), "fold_change")       # default 2×
#' get_outlier_bounds(log10(c(1, 2, 4, 8)), "fold_change", k = 3) # 3× fold-change
#'
#' @export
get_outlier_bounds <- function(
  x,
  method = c(
    "iqr",
    "mad",
    "sd",
    "quantile",
    "z_normal",
    "z_robust",
    "fold_change"
  ),
  k = NULL,
  outlier_log = FALSE,
  na.rm = FALSE
) {
  method <- rlang::arg_match(method)

  if (!na.rm && any(is.na(x))) {
    return(c(NA_real_, NA_real_))
  }

  if (na.rm) {
    x <- x[!is.na(x)]
  }

  if (length(x) < 2) {
    return(c(NA_real_, NA_real_))
  }

  if (outlier_log) {
    if (any(x <= 0))
      cli::cli_abort("All values must be positive for log transformation.")
    x <- log10(x)
  }

  lower <- upper <- NA_real_

  if (method == "iqr") {
    if (is.null(k)) {
      k <- 1.5
    }
    q1 <- quantile(x, 0.25)
    q3 <- quantile(x, 0.75)
    iqr <- q3 - q1
    lower <- q1 - k * iqr
    upper <- q3 + k * iqr
  } else if (method == "mad") {
    if (is.null(k)) {
      k <- 3
    }
    med <- median(x)
    # Scaled (consistent) MAD via mad()'s default constant (1.4826) so the fence
    # is comparable to the "sd" method at the same k.
    mad_val <- mad(x)
    lower <- med - k * mad_val
    upper <- med + k * mad_val
  } else if (method == "sd") {
    if (is.null(k)) {
      k <- 3
    }
    mu <- mean(x)
    sd_val <- sd(x)
    lower <- mu - k * sd_val
    upper <- mu + k * sd_val
  } else if (method == "quantile") {
    if (is.null(k)) {
      k <- 0.01
    }
    lower <- quantile(x, k)
    upper <- quantile(x, 1 - k)
  } else if (method == "z_normal") {
    if (is.null(k)) {
      k <- 3
    }
    mu <- mean(x)
    sd_val <- sd(x)
    lower <- mu - k * sd_val
    upper <- mu + k * sd_val
  } else if (method == "z_robust") {
    if (is.null(k)) {
      k <- 3.5
    }
    med <- median(x)
    mad_val <- mad(x, constant = 1)
    if (mad_val == 0) {
      return(range(x))
    }
    mod_z <- 0.6745 * (x - med) / mad_val
    lower <- min(x[abs(mod_z) <= k], na.rm = TRUE)
    upper <- max(x[abs(mod_z) <= k], na.rm = TRUE)
    return(c(lower, upper))
  } else if (method == "fold_change") {
    if (is.null(k)) {
      k <- 2
    }
    med <- median(x)

    if (length(k) == 1) {
      k <- c(k, k)
    } else if (length(k) != 2) {
      cli::cli_abort("k must be a single number or a vector of length 2.")
    }
    # Data are assumed log10-transformed (see @description), so a k-fold change is
    # log10(k) on this scale, not log2(k).
    delta <- log10(abs(k))
    lower <- med - delta[1]
    upper <- med + delta[2]
  }

  vals_lo <- x[x >= lower]
  lo <- if (length(vals_lo) > 0) min(vals_lo, na.rm = TRUE) else NA_real_

  vals_up <- x[x <= upper]
  up <- if (length(vals_up) > 0) max(vals_up, na.rm = TRUE) else NA_real_

  c(lo, up)
}
#' Get MAD-based tails
#'
#' Computes the lower and upper boundaries based on Median Absolute Deviation
#' (MAD) from a numeric vector. Returns c(NA_real_, NA_real_) if the input vector
#' has less than 2 elements or if no values fall within the computed fences.
#'
#' @param x a numeric vector
#' @param k multiplier for the MAD
#' @param na.rm if TRUE then NA values are stripped from x before computation takes place.
#'
#' @return a numeric vector of length 2 with the lower and upper boundaries.
#'
#' @export
get_mad_tails <- function(x, k, na.rm = FALSE) {
  if (na.rm) {
    x <- x[!is.na(x)]
  }

  if (length(x) < 2) {
    return(c(NA_real_, NA_real_))
  }

  med <- median(x, na.rm = na.rm)
  mad_val <- mad(x, na.rm = na.rm)

  if (is.na(med) || is.na(mad_val)) {
    return(c(NA_real_, NA_real_))
  }

  upper_fence <- med + k * mad_val
  lower_fence <- med - k * mad_val

  # Find values that are strictly inside the fences
  vals_above_lower <- x[x > lower_fence]
  vals_below_upper <- x[x < upper_fence]

  # If the resulting subsets are empty, return NA instead of Inf/-Inf
  lo <- if (length(vals_above_lower) > 0)
    min(vals_above_lower, na.rm = TRUE) else NA_real_
  up <- if (length(vals_below_upper) > 0)
    max(vals_below_upper, na.rm = TRUE) else NA_real_

  return(c(lo, up))
}
#' Get Tukey's IQR fences
#'
#' Computes the lower and upper boundaries based on Tukey's Interquartile Range (IQR)
#' fences from a numeric vector.
#'
#' @param x A numeric vector.
#' @param k A numeric multiplier for the IQR. Default is \code{1.5}.
#' @param na.rm Logical. Should missing values be removed? Default is \code{FALSE}.
#'
#' @return A numeric vector of length 2: \code{c(lower_tail, upper_tail)}.
#'
#' @export
get_iqr_tails <- function(x, k = 1.5, na.rm = FALSE) {
  # If na.rm is FALSE and there are any NAs, return NA immediately to prevent
  # an error from the internal quantile() function.
  if (!na.rm && any(is.na(x))) {
    return(c(NA_real_, NA_real_))
  }

  # It's also good practice to remove NAs if na.rm=TRUE before the length check.
  if (na.rm) {
    x <- x[!is.na(x)]
  }

  if (length(x) < 2) {
    return(c(NA_real_, NA_real_))
  }

  # Because of the checks above, we can now safely call quantile.
  # We still pass na.rm for correctness, though the error case is handled.
  q1 <- quantile(x, 0.25, na.rm = na.rm)
  q3 <- quantile(x, 0.75, na.rm = na.rm)
  iqr <- q3 - q1

  # If IQR is NA (e.g., from a vector of NAs with na.rm=TRUE), return NA.
  if (is.na(iqr)) {
    return(c(NA_real_, NA_real_))
  }

  lower_fence <- q1 - k * iqr
  upper_fence <- q3 + k * iqr

  ## Trim values outside the fences
  lo <- min(x[x >= lower_fence], na.rm = na.rm)
  up <- max(x[x <= upper_fence], na.rm = na.rm)

  return(c(lo, up))
}

# find closest available number in a vector
find_closest <- function(x, available_numbers, method = "absolute") {
  method <- rlang::arg_match(method, c("absolute", "lower", "higher"))

  switch(
    method,
    "absolute" = {
      available_numbers[which.min(abs(available_numbers - x))]
    },
    "lower" = {
      valid_nums <- available_numbers[available_numbers <= x]
      if (length(valid_nums) == 0) {
        return(min(available_numbers))
      }
      max(valid_nums)
    },
    "higher" = {
      valid_nums <- available_numbers[available_numbers >= x]
      if (length(valid_nums) == 0) {
        return(max(available_numbers))
      }
      min(valid_nums)
    }
  )
}
