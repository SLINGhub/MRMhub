# Functions for MRMhub-Integrator to save integration results to PDFs.
#
# Guo Shou Teo, Bo Burla, National University Singapore / 2025
# Version 2026-07-01

# User parameters ----
low_intensity_threshold <- 150  # Threshold for transition_low folder.
plot_line <- TRUE  # Connect data points with a line.
plot_rows <- 6  # Number of rows in the plot grid.
plot_columns <- 3  # Number of columns in the plot grid.
num_cores <- 14  # Number of cores for parallel processing.

print(R.version.string)

safe_num_cores <- max(1, parallel::detectCores() - 1)
num_cores <- min(num_cores, safe_num_cores)

cat(paste0("Using ", num_cores, " cores.\n"))
cat("This may take a few minutes... Check output folders for progress.\n")

misc_dir <- "misc"

cqq_list <- read.csv(
  file.path(misc_dir, "trans_R.csv"),
  header = TRUE,
  colClasses = c(
    "character", "character", "character", "character",
    "integer", "character", "numeric", "numeric"
  )
)

v0_list <- cqq_list[, 7]
v1_list <- cqq_list[, 8]
v0_list[is.na(v0_list)] <- 0
v1_list[is.na(v1_list)] <- 999

cpd_list <- cqq_list[, 2]
q1_list <- cqq_list[, 3]
q3_list <- cqq_list[, 4]
use_rt_list <- cqq_list[, 5] == 1
bl_list <- cqq_list[, 6]
cqq_list <- substr(cqq_list[, 1], 2, 9)

color_palette <- c(
  "#1f77b4", "#ff7f0e", "#2ca02c", "#d62728", "#9467bd",
  "#8c564b", "#e377c2", "#7f7f7f", "#bcbd22", "#17becf"
)
color_palette50 <- paste0(color_palette, "80")
color_palette20 <- paste0(color_palette, "33")

unlink("by_sample", recursive = TRUE)
dir.create("by_sample")

.DrawPeakRegions <- function(rt, intensity, peak_bounds, baseline, n_peaks) {
  # Draws shaded peak regions and filled polygons on the current plot.
  #
  # Args:
  #   rt: Numeric vector of retention times.
  #   intensity: Numeric vector of intensity values.
  #   peak_bounds: Integer vector of start/end index pairs.
  #   baseline: Numeric vector of baseline values.
  #   n_peaks: Integer number of peak regions.
  #
  # Returns:
  #   NULL, invisibly. Called for the side effect of drawing on the plot.
  for (j in seq_len(n_peaks)) {
    color_index <- ((j - 1) %% length(color_palette)) + 1
    start_index <- peak_bounds[j * 2 - 1]
    end_index <- peak_bounds[j * 2]

    rect(
      rt[start_index],
      par("usr")[3],
      rt[end_index],
      par("usr")[4],
      col = color_palette20[color_index],
      border = NA
    )

    if (!is.nan(baseline[1])) {
      polygon(
        x = c(rt[start_index:end_index], rt[end_index], rt[start_index]),
        y = c(
          intensity[start_index:end_index],
          baseline[j * 2],
          baseline[j * 2 - 1]
        ),
        col = color_palette50[color_index],
        border = NA
      )
    }
  }

  return(invisible(NULL))
}

PlotIonChromatogram <- function(eic_file) {
  # Plots ion chromatograms for a single sample file and saves to PDF.
  #
  # Args:
  #   eic_file: Path to a binary EIC data file.
  #
  # Returns:
  #   NULL, invisibly. Called for the side effect of writing a PDF.
  data_connection <- file(eic_file, "rb")
  on.exit(close(data_connection), add = TRUE)

  first_underscore_position <- unlist(gregexpr("_", eic_file))[1] + 1
  filename <- paste0(
    gsub(
      "[^-_.()a-zA-Z0-9]",
      "_",
      substr(eic_file, first_underscore_position, nchar(eic_file))
    ),
    ".pdf"
  )

  pdf(
    file.path("by_sample", filename),
    paper = "a4r",
    width = 0,
    height = 0
  )
  on.exit(dev.off(), add = TRUE)

  par(
    mfrow = c(plot_rows, plot_columns),
    oma = c(0, 0, 0, 0),
    mar = c(2, 2, 0, 0)
  )

  for (i in seq_along(cpd_list)) {
    data_point_count <- readBin(
      data_connection,
      integer(),
      size = 2,
      signed = FALSE,
      endian = "little"
    )
    intensity <- matrix(
      readBin(
        data_connection,
        numeric(),
        size = 4,
        n = data_point_count * 2,
        endian = "little"
      ),
      ncol = data_point_count
    )
    rt <- intensity[1, ]
    intensity <- intensity[2, ]

    sh <- readBin(data_connection, numeric(), size = 4, endian = "little")
    n_peaks <- readBin(
      data_connection,
      integer(),
      size = 1,
      signed = FALSE,
      endian = "little"
    )

    peak_bounds <- readBin(
      data_connection,
      integer(),
      size = 2,
      n = n_peaks * 2,
      signed = FALSE,
      endian = "little"
    )
    baseline <- readBin(
      data_connection,
      numeric(),
      size = 4,
      n = n_peaks * 2,
      endian = "little"
    )

    max_selected_intensity <- max(
      intensity[peak_bounds[1]:peak_bounds[n_peaks * 2]]
    )

    plot(
      x = rt,
      y = intensity,
      type = "l",
      cex = 3,
      xlab = "",
      ylab = "",
      ylim = c(0, max_selected_intensity),
      yaxt = "n"
    )

    y_axis_ticks <- axTicks(2)
    axis(2, at = c(0, y_axis_ticks[length(y_axis_ticks) - 1]))

    .DrawPeakRegions(rt, intensity, peak_bounds, baseline, n_peaks)

    mtext(
      paste0(cpd_list[i], ", ", round(sh, 2)),
      side = 3,
      line = -1,
      at = par("usr")[1],
      adj = 0
    )
  }

  return(invisible(NULL))
}

bys_files <- Sys.glob(file.path(misc_dir, "se_*"))
results <- lapply(bys_files, FUN = PlotIonChromatogram)

mzml_files <- read.delim(
  file.path(misc_dir, "mzML_list.txt"),
  header = FALSE
)

blank_files <- grepl("BLANK|BLK", mzml_files[, 2])
ref_files <- mzml_files[, 5] == 1

mzml_files <- mzml_files[, 1]

unlink("by_transition", recursive = TRUE)
dir.create("by_transition")

unlink("by_transition_low", recursive = TRUE)
dir.create("by_transition_low")

PlotTransitionChromatogram <- function(cpd_index) {
  # Plots ion chromatograms for a single compound transition across all samples
  # and saves to PDF.
  #
  # Args:
  #   cpd_index: Integer index into the compound list vectors.
  #
  # Returns:
  #   NULL, invisibly. Called for the side effect of writing a PDF.
  cqq <- cqq_list[cpd_index]
  cpd <- cpd_list[cpd_index]
  q1 <- q1_list[cpd_index]
  q3 <- q3_list[cpd_index]
  use_rt <- use_rt_list[cpd_index]
  bl <- bl_list[cpd_index]
  v0 <- v0_list[cpd_index]
  v1 <- v1_list[cpd_index]

  # First pass: compute median intensity range.
  max_intensity <- local({
    data_connection <- file(file.path(misc_dir, paste0("te_", cqq)), "rb")
    on.exit(close(data_connection), add = TRUE)

    peak_connection <- file(file.path(misc_dir, paste0("tp_", cqq)), "rb")
    on.exit(close(peak_connection), add = TRUE)

    n_peaks <- readBin(
      peak_connection,
      integer(),
      size = 1,
      signed = FALSE,
      endian = "little"
    )
    intensity_ranges <- rep(0, length(mzml_files))

    for (i in seq_along(mzml_files)) {
      readBin(peak_connection, numeric(), size = 4, endian = "little")
      peak_bounds <- readBin(
        peak_connection,
        integer(),
        size = 2,
        n = n_peaks * 2,
        signed = FALSE,
        endian = "little"
      )
      readBin(
        peak_connection,
        numeric(),
        size = 4,
        n = n_peaks * 2,
        endian = "little"
      )
      readBin(data_connection, numeric(), size = 4, endian = "little")
      readBin(data_connection, integer(), size = 1, endian = "little")

      data_point_count <- readBin(
        data_connection,
        integer(),
        size = 2,
        signed = FALSE,
        endian = "little"
      )
      intensity <- matrix(
        readBin(
          data_connection,
          numeric(),
          size = 4,
          n = data_point_count * 2,
          endian = "little"
        ),
        ncol = data_point_count
      )[2, peak_bounds[1]:peak_bounds[n_peaks * 2]]

      intensity_ranges[i] <- max(intensity) - min(intensity)
    }

    return(median(intensity_ranges))
  })

  # Second pass: plot chromatograms.
  data_connection <- file(file.path(misc_dir, paste0("te_", cqq)), "rb")
  on.exit(close(data_connection), add = TRUE)

  peak_connection <- file(file.path(misc_dir, paste0("tp_", cqq)), "rb")
  on.exit(close(peak_connection), add = TRUE)

  n_peaks <- readBin(
    peak_connection,
    integer(),
    size = 1,
    signed = FALSE,
    endian = "little"
  )
  filename <- paste0(gsub("[^-_.()a-zA-Z0-9]", "_", cpd), "_", cqq, ".pdf")
  output_dir <- ifelse(
    max_intensity > low_intensity_threshold,
    "by_transition",
    "by_transition_low"
  )

  pdf(
    file.path(output_dir, filename),
    paper = "a4r",
    width = 0,
    height = 0
  )
  on.exit(dev.off(), add = TRUE)

  cat("\r", format(cpd, width = 40))
  flush.console()

  par(
    mfrow = c(plot_rows, plot_columns),
    oma = c(0, 0, 0, 0),
    mar = c(1.5, 1.5, 0, 0),
    mgp = c(3, 0.31, 0),
    tcl = -0.3
  )

  plot.new()
  mtext(cpd, line = -2)
  mtext(paste0(q1, "m/z, ", q3, "m/z"), line = -3.5)
  mtext(paste0("uniform width: ", use_rt), line = -5)
  mtext(paste0("baseline: ", bl), line = -6.5)

  for (i in seq_along(mzml_files)) {
    sh <- readBin(peak_connection, numeric(), size = 4, endian = "little")
    readBin(data_connection, numeric(), size = 4, endian = "little")
    readBin(data_connection, integer(), size = 1, endian = "little")

    data_point_count <- readBin(
      data_connection,
      integer(),
      size = 2,
      signed = FALSE,
      endian = "little"
    )
    intensity <- matrix(
      readBin(
        data_connection,
        numeric(),
        size = 4,
        n = data_point_count * 2,
        endian = "little"
      ),
      ncol = data_point_count
    )
    rt <- intensity[1, ]
    intensity <- intensity[2, ]

    peak_bounds <- readBin(
      peak_connection,
      integer(),
      size = 2,
      n = n_peaks * 2,
      signed = FALSE,
      endian = "little"
    )
    baseline <- readBin(
      peak_connection,
      numeric(),
      size = 4,
      n = n_peaks * 2,
      endian = "little"
    )

    max_selected_intensity <- max(
      intensity[peak_bounds[1]:peak_bounds[n_peaks * 2]]
    )

    plot(
      x = rt,
      y = intensity,
      pch = ".",
      cex = 3,
      xlab = "",
      ylab = "",
      ylim = c(0, max_selected_intensity),
      yaxt = "n",
      xlim = c(max(v0, rt[1]), min(v1, rt[length(rt)]))
    )

    if (plot_line) {
      lines(x = rt, y = intensity, col = "gray33", lwd = 0.5)
    }

    y_axis_ticks <- axTicks(2)
    axis(2, at = c(0, y_axis_ticks[length(y_axis_ticks) - 1]))

    .DrawPeakRegions(rt, intensity, peak_bounds, baseline, n_peaks)

    title_text <- paste0(
      substr(mzml_files[i], 1, nchar(mzml_files[i]) - 5),
      "\n",
      round(sh, 2)
    )

    mtext(
      title_text,
      side = 3,
      line = -1,
      at = par("usr")[1] + 0.025 * diff(par("usr")[1:2]),
      adj = 0,
      padj = 0.9,
      cex = 0.7
    )

    if (blank_files[i]) {
      text(
        (rt[1] + rt[length(rt)]) / 2,
        max_selected_intensity / 2,
        "blank",
        cex = 7,
        col = gray(0, 0.3)
      )
    }
    if (ref_files[i]) {
      text(rt[1], max_selected_intensity / 2, "reference", cex = 1, srt = 90)
    }
  }

  return(invisible(NULL))
}

# Platform-specific parallel execution.
if (.Platform$OS.type == "windows") {
  cl <- parallel::makeCluster(num_cores)

  parallel::clusterExport(
    cl,
    varlist = c(
      ".DrawPeakRegions",
      "PlotTransitionChromatogram",
      "misc_dir",
      "color_palette",
      "color_palette50",
      "color_palette20",
      "plot_line",
      "plot_rows",
      "plot_columns",
      "low_intensity_threshold",
      "cqq_list",
      "cpd_list",
      "q1_list",
      "q3_list",
      "use_rt_list",
      "bl_list",
      "v0_list",
      "v1_list",
      "mzml_files",
      "blank_files",
      "ref_files"
    ),
    envir = environment()
  )

  results <- tryCatch(
    {
      parallel::parLapply(
        cl,
        seq_along(cpd_list),
        fun = PlotTransitionChromatogram
      )
    },
    error = function(e) {
      message("An error occurred during parallel processing:")
      message(conditionMessage(e))
      return(NULL)
    },
    finally = {
      parallel::stopCluster(cl)
    }
  )
} else {
  results <- parallel::mclapply(
    seq_along(cpd_list),
    FUN = PlotTransitionChromatogram,
    mc.cores = num_cores
  )
}

cat("\r", format("", width = 40), "\n")
