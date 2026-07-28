library(ggplot2)

test_that("no arguments returns NULL (additive no-op)", {
  expect_null(mrmhub_style_layer())
  p <- ggplot(mtcars, aes(wt, mpg, colour = factor(cyl))) + geom_point()
  expect_identical((p + mrmhub_style_layer())$theme, p$theme)
})

test_that("legend_position keyword, corner and c(x,y) all resolve", {
  th <- mrmhub_style_layer(legend_position = "bottom")[[1]]
  expect_equal(th$legend.position, "bottom")

  th <- mrmhub_style_layer(legend_position = "inside-br")[[1]]
  expect_equal(th$legend.position, "inside")
  expect_equal(th$legend.position.inside, c(0.98, 0.02))
  expect_equal(th$legend.justification.inside, c(1, 0))

  th <- mrmhub_style_layer(legend_position = c(0.77, 0.27))[[1]]
  expect_equal(th$legend.position, "inside")
  expect_equal(th$legend.position.inside, c(0.77, 0.27))
})

test_that("legend_size scales text, key and glyph (multiplier <= 3)", {
  l <- mrmhub_style_layer(legend_size = 0.8, font_base_size = 6)
  th <- l[[1]]
  expect_equal(th$legend.text$size, 4.8)
  expect_equal(th$legend.title$size, 4.8)
  expect_equal(as.numeric(th$legend.key.size), 4.8)

  g <- l[[2]]
  expect_s3_class(g, "Guides")
  expect_equal(names(g$guides), "colour")
  expect_equal(g$guides$colour$params$override.aes$size, 4.8 / ggplot2::.pt)
})

test_that("legend_size on a merged legend emits no override.aes warning", {
  p <- ggplot(mtcars, aes(wt, mpg, colour = factor(cyl), shape = factor(cyl))) +
    geom_point()
  f <- withr::local_tempfile(fileext = ".png")
  expect_no_warning(ggplot2::ggsave(
    f,
    p + mrmhub_style_layer(legend_size = 1),
    width = 4,
    height = 3
  ))
})

test_that("size > 3 is treated as an absolute point size", {
  th <- mrmhub_style_layer(legend_size = 7, font_base_size = 6)[[1]]
  expect_equal(th$legend.text$size, 7)
  th <- mrmhub_style_layer(strip_text_size = 5, font_base_size = 6)[[1]]
  expect_equal(th$strip.text$size, 5)
})

test_that("strip_text_size multiplier uses font_base_size", {
  th <- mrmhub_style_layer(strip_text_size = 0.7, font_base_size = 6)[[1]]
  expect_equal(th$strip.text$size, 4.2)
})

test_that("show_legend_title = FALSE blanks the title and wins over legend_size", {
  th <- mrmhub_style_layer(show_legend_title = FALSE)[[1]]
  expect_s3_class(th$legend.title, "element_blank")
  th <- mrmhub_style_layer(legend_size = 0.8, show_legend_title = FALSE)[[1]]
  expect_s3_class(th$legend.title, "element_blank")
})

test_that("legend_bg_alpha sets a translucent white background", {
  th <- mrmhub_style_layer(legend_bg_alpha = 0.6)[[1]]
  expect_s3_class(th$legend.background, "element_rect")
  expect_equal(th$legend.background$fill, scales::alpha("white", 0.6))
})

test_that("legend_aes controls which guides get an override", {
  g <- mrmhub_style_layer(legend_size = 1, legend_aes = "colour")[[2]]
  expect_equal(names(g$guides), "colour")
})

test_that("legend_size with multiple merged aesthetics emits no override.aes warning", {
  # A caller passing legend_aes = c("colour", "fill") on a merged colour+fill
  # legend previously produced two override.aes on one shared key -> ggplot's
  # "Duplicated `override.aes` is ignored" warning. Only one override is needed
  # to resize the merged key.
  p <- ggplot(mtcars, aes(wt, mpg, colour = factor(cyl), fill = factor(cyl))) +
    geom_point(shape = 21)
  f <- withr::local_tempfile(fileext = ".png")
  expect_no_warning(ggplot2::ggsave(
    f,
    p + mrmhub_style_layer(legend_size = 1, legend_aes = c("colour", "fill")),
    width = 4,
    height = 3
  ))
})

# --- resolve_page_size -------------------------------------------------------

test_that("resolve_page_size keeps the historical A4 defaults", {
  landscape <- resolve_page_size(page_orientation = "LANDSCAPE")
  expect_equal(landscape$width, 28 / 2.54)
  expect_equal(landscape$height, 20 / 2.54)
  expect_equal(landscape$paper, "A4r")

  portrait <- resolve_page_size(page_orientation = "PORTRAIT")
  expect_equal(portrait$width, 20 / 2.54)
  expect_equal(portrait$height, 28 / 2.54)
  expect_equal(portrait$paper, "A4")
})

test_that("resolve_page_size converts a custom size and switches paper", {
  # `paper` must become "special", otherwise grDevices::pdf() ignores the size
  mm <- resolve_page_size(180, 240)
  expect_equal(mm$width, 180 / 25.4)
  expect_equal(mm$height, 240 / 25.4)
  expect_equal(mm$paper, "special")

  expect_equal(resolve_page_size(10, 8, "in")$width, 10)
  expect_equal(resolve_page_size(720, 360, "pt")$height, 5)
})

test_that("resolve_page_size ignores orientation once a size is given", {
  a <- resolve_page_size(180, 240, "mm", "LANDSCAPE")
  b <- resolve_page_size(180, 240, "mm", "PORTRAIT")
  expect_equal(a, b)
})

test_that("resolve_page_size requires both dimensions", {
  expect_error(resolve_page_size(page_width = 180), "must both be given")
  expect_error(resolve_page_size(page_height = 240), "must both be given")
})

test_that("resolve_page_size rejects unsupported units and sizes", {
  expect_error(resolve_page_size(180, 240, "px"))
  expect_error(resolve_page_size(-5, 240, "mm"), "single positive number")
})

test_that("resolve_page_size defaults to mm", {
  expect_equal(resolve_page_size(180, 240), resolve_page_size(180, 240, "mm"))
})
