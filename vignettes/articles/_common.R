# Shared knitr setup for mrmhub pkgdown tutorials.
# Sourced from each article's hidden setup chunk: `source("_common.R")`.

library(mrmhub)

knitr::opts_chunk$set(
  collapse = TRUE,
  comment = "", # no "#>" prefix on the cli console-message blocks
  message = FALSE, # console feedback is opt-in per chunk via `#| message: true`
  warning = FALSE
)

# Colour mrmhub's cli console feedback in the rendered HTML and route it to a
# styled `.cell-output-stderr` block (no `#>` prefix). Defined in the package;
# styling lives in pkgdown/extra.css.
mrmhub_enable_cli_color()

# Auto-numbered figure captions. `fig_cap("...")` -> "Figure N. ...", with N
# reset per article (this file is sourced once at the top of each article).
.fig_n <- 0L
fig_cap <- function(text) {
  .fig_n <<- .fig_n + 1L
  paste0("Figure ", .fig_n, ". ", text)
}
