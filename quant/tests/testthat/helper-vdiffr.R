# quant/tests/testthat/helper-vdiffr.R

expect_doppelganger_cond_cond <- function(title, fig, path = NULL) {
  if (Sys.getenv("RUN_VDIFFR", unset = "true") != "true") {
    testthat::skip("Skipping vdiffr test: RUN_VDIFFR != 'true'")
  } else {
    vdiffr::expect_doppelganger(title = title, fig = fig, path = path)
  }
}
