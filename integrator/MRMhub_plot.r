## User Parameters ###############################################################
low_intensity_threshold = 150      # Intensity threshold for folder transition_low
plot_line = TRUE                   # Connect data points with a line
plot_rows = 6                      # Number of rows in the plot grid
plot_columns = 3                   # Number of columns in the plot grid

ncores = 14                        # Number of cores for parallel processing
##################################################################################

# MRMhub_plot.R -
# Functions for MRMhub-Integrator to save integration results to PDFs
#
# Guo Shou Teo, National Unversity Singapore / 2025
# Version 2025-10-06




R.version.string

safe_ncores <- max(1, parallel::detectCores() - 1)   #BB
ncores <- min(ncores, safe_ncores) #BB

cat(paste0("Using ", as.character(ncores), " cores.\n")) #BB
cat("This may take a few minutes... Check output folders for progress.\n") #BB

miscdir = "misc"
cqq_l = read.csv(file.path(miscdir, "trans_R.csv"), header = T, colClasses = c("character", "character", "character", "character", "integer", "numeric", "numeric"))
v0_l = cqq_l[, 6]
v1_l = cqq_l[, 7]
v0_l[is.na(v0_l)] = 0
v1_l[is.na(v1_l)] = 999
cpd_l = cqq_l[,2]
q1_l = cqq_l[,3]
q3_l = cqq_l[,4]
u_rt_l = cqq_l[,5] == 1
cqq_l = substr(cqq_l[,1], 2, 9)

cp = c("#1f77b4", "#ff7f0e", "#2ca02c", "#d62728", "#9467bd", "#8c564b", "#e377c2", "#7f7f7f", "#bcbd22", "#17becf")
cp_ = sapply(cp, function(x) paste0(x, "80"))
cp2 = sapply(cp, function(x) paste0(x, "33"))

if (dir.exists("by_sample")) {
    unlink(list.files(path = "by_sample", full.names = TRUE))
} else {
    dir.create("by_sample")
}
plot_ionc <- function(eic_d) {
    dat = file(eic_d, "rb")
    find1_ = unlist(gregexpr("_", eic_d))[1] + 1
    filename_ = paste0(gsub("[^-_.()a-zA-Z0-9]", "_", substr(eic_d, find1_, nchar(eic_d))), ".pdf")
    pdf(file.path("by_sample", filename_), paper = "a4r", width = 0, height = 0)
    par(mfrow = c(plot_rows, plot_columns), oma = c(0, 0, 0, 0), mar = c(2, 2, 0, 0))
    for (i in 1:length(cpd_l)) {
        # for each sample
        len1 = readBin(dat, integer(), size = 2, signed = FALSE, endian = "little")
        I_ = matrix(readBin(dat, numeric(), size = 4, n = len1 * 2, endian = "little"), ncol = len1)
        rt_ = I_[1,]
        I_ = I_[2,]
        sh = readBin(dat, numeric(), size = 4, endian = "little")
        len0 = readBin(dat, integer(), size = 1, signed = FALSE, endian = "little")
        sta_end = readBin(dat, integer(), size = 2, n = len0 * 2, signed = FALSE, endian = "little")
        max_sel = max(I_[sta_end[1]:sta_end[len0 * 2]])
        # max_sel = max(I_)
        plot(x = rt_, y = I_, pch = ".", cex = 3, xlab = "", ylab = "", ylim = c(0, max_sel), yaxt = "n")
        xaxs = axTicks(1)
        # rug(x = seq(xaxs[1], xaxs[length(xaxs)], 0.1), ticksize = -0.05, side = 1, lwd = 1)
        xaxs = axTicks(2)
        axis(2, at = c(0, xaxs[length(xaxs) - 1]))
        for (j in 1:len0) {
            sta = sta_end[j * 2 - 1]
            end = sta_end[j * 2]
            # ci = (j - 1)%%length(cp_) + 1
            rect(rt_[sta], par("usr")[3], rt_[end], par("usr")[4], col = cp2[j], border = NA)
            I_s = I_[sta:end]
            first_dec = quantile(I_, 0.05)
            for (k in 1:length(I_s)) {
                I_s[k] = max(first_dec, I_s[k])
            }
            polygon(x = c(rt_[sta:end], rt_[end], rt_[sta]), y = c(I_s, first_dec, first_dec), col = cp_[j], border = "NA")
        }
        # rect(-1, par("usr")[3], l_bd[i], par("usr")[4], col = gray(0, 0.1), border = NA)
        # rect(r_bd[i], par("usr")[3], 999, par("usr")[4], col = gray(0, 0.1), border = NA)
        #title(main = paste0(cpd_l[i], ", ", round(sh, 2)), line = -1)
        mtext(paste0(cpd_l[i], ", ", round(sh, 2)), side = 3, line = -1, at = par("usr")[1], adj = 0)
    }
    dev.off()
    close(dat)
}
###### by sample
bys_files = Sys.glob(file.path(miscdir, "se_*"))
# results = parallel::mclapply(bys_files, FUN = plot_ionc, mc.cores = ncores)
results = sapply(bys_files, FUN = plot_ionc)
#######################################################

mzML_files = read.delim(file.path(miscdir, "mzML_list.txt"), header = F)
blk_files = rep(F, nrow(mzML_files))
ref_files = rep(F, nrow(mzML_files))
for (i in 1:nrow(mzML_files)) {
    stype = mzML_files[i, 2]
    if (grepl("BLANK", stype) || grepl("BLK", stype)) {
        blk_files[i] = T
    } else if (mzML_files[i, 5] == 1) {
        ref_files[i] = T
    }
}
mzML_files = mzML_files[, 1]

##################
if (dir.exists("by_transition")) {
    unlink(list.files(path = "by_transition", full.names = TRUE))
} else {
    dir.create("by_transition")
}
if (dir.exists("by_transition_low")) {
    unlink(list.files(path = "by_transition_low", full.names = TRUE))
} else {
    dir.create("by_transition_low")
}


plot_ionc <- function(cpd_i) {
    cqq = cqq_l[cpd_i]
    cpd = cpd_l[cpd_i]
    q1 = q1_l[cpd_i]
    q3 = q3_l[cpd_i]
    u_rt = u_rt_l[cpd_i]
    v0 = v0_l[cpd_i]
    v1 = v1_l[cpd_i]
    dat = file(file.path(miscdir, paste0("te_", cqq)), "rb")
    dat2 = file(file.path(miscdir, paste0("tp_", cqq)), "rb")
    len0 = readBin(dat2, integer(), size = 1, signed = FALSE, endian = "little")
    maxi = rep(0, length(mzML_files))
    for (i in 1:length(mzML_files)) {
        readBin(dat2, numeric(), size = 4, endian = "little")  # sh
        sta_end = readBin(dat2, integer(), size = 2, n = len0 * 2, signed = FALSE, endian = "little")
        readBin(dat, numeric(), size = 4, endian = "little")
        readBin(dat, integer(), size = 1, endian = "little")
        len1 = readBin(dat, integer(), size = 2, signed = FALSE, endian = "little")
        I_ = matrix(readBin(dat, numeric(), size = 4, n = len1 * 2, endian = "little"), ncol = len1)[2,sta_end[1]:sta_end[len0 * 2]]
        maxi[i] = max(I_) - min(I_)
    }
    maxi = median(maxi)
    close(dat)
    close(dat2)
    dat = file(file.path(miscdir, paste0("te_", cqq)), "rb")
    dat2 = file(file.path(miscdir, paste0("tp_", cqq)), "rb")
    len0 = readBin(dat2, integer(), size = 1, signed = FALSE, endian = "little")
    filename_ = paste0(gsub("[^-_.()a-zA-Z0-9]", "_", cpd), "_", cqq, ".pdf")
    pdf(file.path(ifelse(maxi > low_intensity_threshold, "by_transition", "by_transition_low"), filename_), paper = "a4r", width = 0, height = 0)
    cat("\r", format(cpd, width = 40))
    # print(cpd)
    flush.console()
    par(mfrow = c(plot_rows, plot_columns), oma = c(0, 0, 0, 0), mar = c(1.5, 1.5, 0, 0), mgp = c(3, 0.31, 0), tcl = -0.3)  #BB
    plot.new()
    mtext(cpd, line = -2)
    mtext(paste0("precursor: ", q1, "m/z"), line = -3.5)
    mtext(paste0("product: ", q3, "m/z"), line = -5)
    mtext(paste0("uniform width: ", u_rt), line = -6.5)
    for (i in 1:length(mzML_files)) {
        # for each sample
        sh = readBin(dat2, numeric(), size = 4, endian = "little")
        readBin(dat, numeric(), size = 4, endian = "little")
        readBin(dat, integer(), size = 1, endian = "little")
        len1 = readBin(dat, integer(), size = 2, signed = FALSE, endian = "little")
        I_ = matrix(readBin(dat, numeric(), size = 4, n = len1 * 2, endian = "little"), ncol = len1)
        rt_ = I_[1,]
        I_ = I_[2,]
        sta_end = readBin(dat2, integer(), size = 2, n = len0 * 2, signed = FALSE, endian = "little")
        max_sel = max(I_[sta_end[1]:sta_end[len0 * 2]])
        # max_sel = max(I_)
        plot(x = rt_, y = I_, pch = ".", cex = 3, xlab = "", ylab = "", ylim = c(0, max_sel), yaxt = "n", xlim = c(max(v0, rt_[1]), min(v1, rt_[length(rt_)])))
        if(plot_line) lines(x = rt_, y = I_, col = "gray33", lwd = 0.5)  #BB
        xaxs = axTicks(1)
        # rug(x = seq(xaxs[1], xaxs[length(xaxs)], 0.1), ticksize = -0.05, side = 1, lwd = 1)
        xaxs = axTicks(2)
        axis(2, at = c(0, xaxs[length(xaxs) - 1]))
        for (j in 1:len0) {
            sta = sta_end[j * 2 - 1]
            end = sta_end[j * 2]
            # ci = (j - 1)%%length(cp_) + 1
            rect(rt_[sta], par("usr")[3], rt_[end], par("usr")[4], col = cp2[j], border = NA)
            I_s = I_[sta:end]
            first_dec = quantile(I_, 0.05)
            for (k in 1:length(I_s)) {
                I_s[k] = max(first_dec, I_s[k])
            }
            polygon(x = c(rt_[sta:end], rt_[end], rt_[sta]), y = c(I_s, first_dec, first_dec), col = cp_[j], border = "NA")
        }
        # rect(-1, par("usr")[3], l_bd[cpd_i], par("usr")[4], col = gray(0, 0.1), border = NA)
        # rect(r_bd[cpd_i], par("usr")[3], 999, par("usr")[4], col = gray(0, 0.1), border = NA)
        #title(main = paste0(substr(mzML_files[i], 0, nchar(mzML_files[i]) - 5), ", ", round(sh, 2)), line = -1)  #BB

        ## BB - adjust title position
        title_text <- paste0(substr(mzML_files[i], 1, nchar(mzML_files[i]) - 5), "\n", round(sh, 2))

        mtext(
            title_text,
            side = 3,
            line = -1,
            at = par("usr")[1] + 0.025 * diff(par("usr")[1:2]),  # adjust spacing here
            adj = 0,
            padj = 0.9,
            cex = 0.7
        )

        ## BB
        if (blk_files[i]) {
            text((rt_[1] + rt_[length(rt_)])/2, max_sel/2, "blank", cex = 7, col = gray(0, 0.3))
        }
        if (ref_files[i]) {
            text(rt_[1], max_sel/2, "reference", cex = 1, srt = 90)
        }
    }
    dev.off()
    close(dat)
    close(dat2)
}
##### by transition

#BB windows version
if (.Platform$OS.type == "windows") {
  cl <- parallel::makeCluster(ncores)

  parallel::clusterExport(cl, varlist = c(
    "plot_ionc", "miscdir", "cqq_l", "cpd_l", "q1_l", "q3_l", "u_rt_l",
    "mzML_files", "blk_files", "ref_files", "cp_", "cp2", "plot_line",
    "plot_rows", "plot_columns", "low_intensity_threshold",
    "v0_l", "v1_l"
  ), envir = environment())

  results <- tryCatch({
    parallel::parLapply(cl, seq_along(cpd_l), fun = plot_ionc)
  }, error = function(e) {
    print("An error occurred during parallel processing:")
    print(e)
    return(NULL)
  })

  parallel::stopCluster(cl)

} else {
  results <- parallel::mclapply(seq_along(cpd_l), FUN = plot_ionc, mc.cores = ncores)
}


cat("\r", format("", width = 40), "\n")
#######################################################
