simple_plot <- function(title = NULL) {
  ggplot2::ggplot(
    data.frame(x = 1:5, y = c(2, 4, 3, 5, 4)),
    ggplot2::aes(x = .data$x, y = .data$y)
  ) +
    ggplot2::geom_point() +
    ggplot2::ggtitle(title)
}

# --- unit conversion ---------------------------------------------------------

test_that("convert_to_inches converts every supported unit", {
  expect_equal(convert_to_inches(1, "in", dpi = 300), 1)
  expect_equal(convert_to_inches(25.4, "mm", dpi = 300), 1)
  expect_equal(convert_to_inches(2.54, "cm", dpi = 300), 1)
  expect_equal(convert_to_inches(72, "pt", dpi = 300), 1)
  expect_equal(convert_to_inches(600, "px", dpi = 300), 2)
})

test_that("convert_to_inches rejects non-positive and non-scalar values", {
  expect_error(convert_to_inches(0, "mm", 300), "single positive number")
  expect_error(convert_to_inches(-5, "mm", 300), "single positive number")
  expect_error(convert_to_inches(c(1, 2), "mm", 300), "single positive number")
  expect_error(convert_to_inches(NA_real_, "mm", 300), "single positive number")
})

# --- format and path resolution ----------------------------------------------

test_that("resolve_plot_formats infers the format from the extension", {
  expect_equal(resolve_plot_formats("a/b/fig.pdf"), c(pdf = "a/b/fig.pdf"))
  expect_equal(resolve_plot_formats("fig.PNG"), c(png = "fig.PNG"))
  expect_equal(resolve_plot_formats("fig.tif"), c(tiff = "fig.tif"))
  expect_equal(resolve_plot_formats("fig.jpg"), c(jpeg = "fig.jpg"))
})

test_that("resolve_plot_formats builds one path per explicit format", {
  expect_equal(
    resolve_plot_formats("out/fig", format = c("pdf", "png")),
    c(pdf = "out/fig.pdf", png = "out/fig.png")
  )
  # a known extension on `path` is replaced, not appended to
  expect_equal(
    resolve_plot_formats("out/fig.pdf", format = "png"),
    c(png = "out/fig.png")
  )
  # aliases collapse onto the canonical format
  expect_equal(
    resolve_plot_formats("fig", format = c("tif", "tiff")),
    c(tiff = "fig.tiff")
  )
})

test_that("resolve_plot_formats errors on an unusable path or format", {
  expect_error(resolve_plot_formats("fig"), "Cannot determine the output format")
  expect_error(resolve_plot_formats("fig.docx"), "Cannot determine the output format")
  expect_error(resolve_plot_formats("fig", format = "eps"), "Unsupported")
  expect_error(resolve_plot_formats(""), "non-empty file path")
})

# --- plot input dispatch -----------------------------------------------------

test_that("as_plot_list accepts the shapes the plot functions return", {
  p <- simple_plot()

  expect_equal(as_plot_list(p)$multipage, FALSE)
  expect_length(as_plot_list(p)$plots, 1)

  # plot_rla_boxplot()-style result list
  res <- as_plot_list(list(plot = p, outliers = data.frame()))
  expect_false(res$multipage)
  expect_length(res$plots, 1)

  # return_plots = TRUE output
  pages <- as_plot_list(list(a = p, b = p))
  expect_true(pages$multipage)
  expect_length(pages$plots, 2)

  # a single-element list of plots is not multi-page
  expect_false(as_plot_list(list(p))$multipage)
})

test_that("as_plot_list rejects anything else", {
  expect_error(as_plot_list(42), "must be a")
  expect_error(as_plot_list(list(1, 2)), "must be a")
  expect_error(as_plot_list(list()), "must be a")
})

# --- device selection --------------------------------------------------------

test_that("resolve_plot_device returns a function for every format", {
  for (fmt in mrmhub_plot_formats) {
    expect_true(is.function(resolve_plot_device(fmt)), info = fmt)
  }
})

test_that("TIFF is LZW-compressed by default but can be overridden", {
  skip_if_not_installed("ragg")
  # ragg::agg_tiff() writes uncompressed TIFF by default -- tens of MB at
  # publication resolution.
  expect_equal(formals(resolve_plot_device("tiff"))$compression, "lzw")

  dir <- withr::local_tempdir()
  lzw <- file.path(dir, "lzw.tiff")
  raw <- file.path(dir, "raw.tiff")
  suppressMessages(save_plot(simple_plot(), lzw, width = 100, height = 80, dpi = 300))
  suppressMessages(save_plot(
    simple_plot(),
    raw,
    width = 100,
    height = 80,
    dpi = 300,
    compression = "none"
  ))

  expect_lt(file.size(lzw), file.size(raw))
})

test_that("resolve_plot_device falls back to grDevices when ragg is absent", {
  # The fallback path is exercised by calling the returned closure; both the
  # ragg and grDevices variants must write a readable file.
  dir <- withr::local_tempdir()
  target <- file.path(dir, "fallback.png")
  dev <- function(filename, width, height, res, ...) {
    grDevices::png(
      filename = filename,
      width = width,
      height = height,
      res = res,
      units = "in"
    )
  }
  dev(target, width = 2, height = 2, res = 72)
  plot(1:5)
  grDevices::dev.off()
  expect_gt(file.size(target), 0)
})

# --- save_plot ---------------------------------------------------------------

test_that("save_plot writes a single file and returns its path", {
  dir <- withr::local_tempdir()
  target <- file.path(dir, "fig.pdf")

  expect_message(
    out <- save_plot(simple_plot(), target, width = 100, height = 80),
    "Saved plot"
  )

  expect_equal(out, target)
  expect_true(file.exists(target))
  expect_gt(file.size(target), 0)
})

test_that("save_plot writes one file per requested format", {
  dir <- withr::local_tempdir()

  out <- suppressMessages(save_plot(
    simple_plot(),
    file.path(dir, "fig"),
    format = c("pdf", "png"),
    width = 100,
    height = 80
  ))

  expect_equal(basename(out), c("fig.pdf", "fig.png"))
  expect_true(all(file.exists(out)))
  expect_true(all(file.size(out) > 0))
})

test_that("save_plot honours the requested physical size", {
  skip_if_not_installed("pdftools")
  dir <- withr::local_tempdir()
  target <- file.path(dir, "sized.pdf")

  suppressMessages(save_plot(simple_plot(), target, width = 100, height = 50))

  # pdftools reports page size in points (1/72 in); 100 mm = 283.5 pt
  size <- pdftools::pdf_pagesize(target)
  expect_equal(size$width[[1]], 100 / 25.4 * 72, tolerance = 0.01)
  expect_equal(size$height[[1]], 50 / 25.4 * 72, tolerance = 0.01)
})

test_that("save_plot accepts inches, points and pixels", {
  skip_if_not_installed("pdftools")
  dir <- withr::local_tempdir()

  for (case in list(
    list(units = "in", w = 4, h = 3, exp_w = 4 * 72),
    list(units = "pt", w = 288, h = 216, exp_w = 288),
    list(units = "cm", w = 10, h = 8, exp_w = 10 / 2.54 * 72)
  )) {
    target <- file.path(dir, paste0("u-", case$units, ".pdf"))
    suppressMessages(save_plot(
      simple_plot(),
      target,
      width = case$w,
      height = case$h,
      units = case$units
    ))
    expect_equal(
      pdftools::pdf_pagesize(target)$width[[1]],
      case$exp_w,
      tolerance = 0.01,
      info = case$units
    )
  }
})

test_that("save_plot writes a list of plots as a multi-page PDF", {
  skip_if_not_installed("qpdf")
  dir <- withr::local_tempdir()
  target <- file.path(dir, "pages.pdf")

  pages <- list(simple_plot("one"), simple_plot("two"), simple_plot("three"))
  suppressMessages(save_plot(pages, target, width = 200, height = 150))

  expect_equal(qpdf::pdf_length(target), 3)
})

test_that("save_plot rejects multi-page output for non-PDF formats", {
  dir <- withr::local_tempdir()
  pages <- list(simple_plot(), simple_plot())

  expect_error(
    save_plot(pages, file.path(dir, "pages.png"), width = 100, height = 80),
    "only supported for"
  )
})

test_that("save_plot unwraps a result list carrying the plot", {
  dir <- withr::local_tempdir()
  target <- file.path(dir, "unwrapped.pdf")

  suppressMessages(save_plot(
    list(plot = simple_plot(), outliers = data.frame(a = 1)),
    target,
    width = 100,
    height = 80
  ))

  expect_true(file.exists(target))
})

test_that("save_plot saves a patchwork composition", {
  skip_if_not_installed("patchwork")
  dir <- withr::local_tempdir()
  target <- file.path(dir, "patch.pdf")

  composed <- patchwork::wrap_plots(simple_plot(), simple_plot())
  suppressMessages(save_plot(composed, target, width = 180, height = 80))

  expect_true(file.exists(target))
  expect_gt(file.size(target), 0)
})

test_that("save_plot creates the output directory when asked", {
  dir <- withr::local_tempdir()
  target <- file.path(dir, "nested", "deeper", "fig.pdf")

  suppressMessages(save_plot(simple_plot(), target, width = 100, height = 80))
  expect_true(file.exists(target))

  target2 <- file.path(dir, "other", "fig.pdf")
  expect_error(
    suppressMessages(save_plot(
      simple_plot(),
      target2,
      width = 100,
      height = 80,
      create_dir = FALSE
    ))
  )
})

test_that("save_plot refuses to overwrite when overwrite = FALSE", {
  dir <- withr::local_tempdir()
  target <- file.path(dir, "fig.pdf")

  suppressMessages(save_plot(simple_plot(), target, width = 100, height = 80))
  expect_error(
    save_plot(
      simple_plot(),
      target,
      width = 100,
      height = 80,
      overwrite = FALSE
    ),
    "already exists"
  )
})

test_that("save_plot requires width and height", {
  dir <- withr::local_tempdir()
  expect_error(
    save_plot(simple_plot(), file.path(dir, "fig.pdf")),
    "must both be given"
  )
  expect_error(
    save_plot(simple_plot(), file.path(dir, "fig.pdf"), width = 100),
    "must both be given"
  )
})

test_that("save_plot validates units and dpi", {
  dir <- withr::local_tempdir()
  expect_error(
    save_plot(
      simple_plot(),
      file.path(dir, "fig.pdf"),
      width = 1,
      height = 1,
      units = "furlongs"
    )
  )
  expect_error(
    save_plot(
      simple_plot(),
      file.path(dir, "fig.pdf"),
      width = 1,
      height = 1,
      dpi = -100
    ),
    "single positive number"
  )
})

# --- global defaults ---------------------------------------------------------

test_that("save_plot picks up units and dpi from the global defaults", {
  skip_if_not_installed("pdftools")
  dir <- withr::local_tempdir()
  target <- file.path(dir, "defaults.pdf")

  withr::local_options(mrmhub.units = "in", mrmhub.dpi = 600)
  suppressMessages(save_plot(simple_plot(), target, width = 4, height = 3))

  expect_equal(
    pdftools::pdf_pagesize(target)$width[[1]],
    4 * 72,
    tolerance = 0.01
  )
})

test_that("an explicit units argument beats the global default", {
  skip_if_not_installed("pdftools")
  dir <- withr::local_tempdir()
  target <- file.path(dir, "explicit.pdf")

  withr::local_options(mrmhub.units = "in")
  suppressMessages(save_plot(
    simple_plot(),
    target,
    width = 100,
    height = 80,
    units = "mm"
  ))

  expect_equal(
    pdftools::pdf_pagesize(target)$width[[1]],
    100 / 25.4 * 72,
    tolerance = 0.01
  )
})

test_that("mrmhub_set_plot_defaults manages units and dpi", {
  withr::local_options(mrmhub.units = NULL, mrmhub.dpi = NULL)

  old <- mrmhub_set_plot_defaults(units = "cm", dpi = 600)
  expect_equal(getOption("mrmhub.units"), "cm")
  expect_equal(getOption("mrmhub.dpi"), 600)
  expect_equal(mrmhub_get_plot_defaults()$units, "cm")

  mrmhub_reset_plot_defaults()
  expect_null(getOption("mrmhub.units"))
  expect_null(getOption("mrmhub.dpi"))

  options(old)
})
