# Route stray graphics to a null device for the duration of the test run. Some
# plot tests draw to the active device (e.g. a bare `print()` of a ggplot); when
# no device is open, R auto-opens `pdf("Rplots.pdf")` in the working directory,
# littering the test folder. Opening a null device first sends those draws to
# nowhere. Only needed non-interactively (an interactive session already has a
# screen device); closed again after the suite via `defer()`.
if (!interactive()) {
  grDevices::pdf(file = nullfile())
  withr::defer(grDevices::dev.off(), teardown_env())
}
