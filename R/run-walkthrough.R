#' Launch the MRMhub Walkthrough App
#'
#' Opens an interactive Shiny application that helps new users validate their
#' data format, generate workflow code, and explore results.
#'
#' @return Invisible NULL. Launches the Shiny app in the default browser.
#' @export
#' @examples
#' if (interactive()) {
#'   run_walkthrough()
#' }
run_walkthrough <- function() {
  if (!requireNamespace("shiny", quietly = TRUE)) {
    cli::cli_abort(c(
      "The {.pkg shiny} package is required to run the walkthrough app.",
      "i" = "Install it with: {.code install.packages(\"shiny\")}"
    ))
  }
  if (!requireNamespace("bslib", quietly = TRUE)) {
    cli::cli_abort(c(
      "The {.pkg bslib} package is required to run the walkthrough app.",
      "i" = "Install it with: {.code install.packages(\"bslib\")}"
    ))
  }

  app_dir <- system.file("shiny", "walkthrough", package = "mrmhub")
  if (app_dir == "") {
    cli::cli_abort("Could not find the walkthrough app. Try reinstalling mrmhub.")
  }
  shiny::runApp(app_dir, display.mode = "normal")
}
