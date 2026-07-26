test_that("mrmhub_set_plot_defaults stores options and returns old values", {
  withr::local_options(list(
    mrmhub.font_base_size = NULL,
    mrmhub.point_size = NULL
  ))
  old <- mrmhub_set_plot_defaults(font_base_size = 8, point_size = 0.8)
  expect_equal(getOption("mrmhub.font_base_size"), 8)
  expect_equal(getOption("mrmhub.point_size"), 0.8)
  expect_null(old$mrmhub.font_base_size)
})

test_that("only supplied arguments are changed", {
  withr::local_options(list(mrmhub.font_base_size = 8, mrmhub.point_size = 0.8))
  mrmhub_set_plot_defaults(point_size = 0.4)
  expect_equal(getOption("mrmhub.font_base_size"), 8)
  expect_equal(getOption("mrmhub.point_size"), 0.4)
})

test_that("mrmhub_get_plot_defaults reports set options and omits unset", {
  withr::local_options(list(
    mrmhub.font_base_size = 8,
    mrmhub.point_size = NULL,
    mrmhub.legend_position = "bottom"
  ))
  got <- mrmhub_get_plot_defaults()
  expect_equal(got, list(font_base_size = 8, legend_position = "bottom"))
})

test_that("mrmhub_reset_plot_defaults clears all managed options", {
  withr::local_options(list(
    mrmhub.font_base_size = 8,
    mrmhub.strip_bg_color = "red"
  ))
  mrmhub_reset_plot_defaults()
  expect_null(getOption("mrmhub.font_base_size"))
  expect_null(getOption("mrmhub.strip_bg_color"))
})

test_that("resolve_plot_opt precedence is explicit > option > default", {
  withr::local_options(list(mrmhub.font_base_size = 8))
  expect_equal(resolve_plot_opt(6, "font_base_size", 11), 6)
  expect_equal(resolve_plot_opt(NULL, "font_base_size", 11), 8)
  withr::local_options(list(mrmhub.font_base_size = NULL))
  expect_equal(resolve_plot_opt(NULL, "font_base_size", 11), 11)
})

test_that("mrmhub_autoscale_sizes lets a global default override the lookup", {
  withr::local_options(list(mrmhub.font_base_size = 8, mrmhub.point_size = 0.9))
  res <- mrmhub_autoscale_sizes(cols_page = 6)
  expect_equal(res$font_base_size, 8)
  expect_equal(res$point_size, 0.9)
  # an explicit value still wins over the option
  res2 <- mrmhub_autoscale_sizes(cols_page = 6, font_base_size = 5)
  expect_equal(res2$font_base_size, 5)
})

test_that("mrmhub_style_layer honours options but stays a no-op when nothing is set", {
  withr::local_options(list(
    mrmhub.legend_position = NULL,
    mrmhub.show_legend_title = NULL
  ))
  expect_null(mrmhub_style_layer())
  withr::local_options(list(mrmhub.legend_position = "bottom"))
  expect_type(mrmhub_style_layer(), "list")
})
