# Internal helpers replacing broom for the small set of broom functions used in
# this package (avoids broom + transitive deps in DESCRIPTION Imports).

# Mimic `broom::augment(prcomp_obj, data)` — append .fittedPC1..PCp columns to
# the supplied data frame in column order.
pca_augment <- function(pca, data) {
  scores <- pca$x
  colnames(scores) <- paste0(".fittedPC", seq_len(ncol(scores)))
  dplyr::bind_cols(data, tibble::as_tibble(scores))
}

# Mimic `broom::tidy(prcomp_obj, matrix = "eigenvalues")` — per-PC variance
# decomposition tibble with PC / std.dev / percent / cumulative.
pca_eigenvalues <- function(pca) {
  sdev <- pca$sdev
  v <- sdev^2
  tibble::tibble(
    PC = seq_along(sdev),
    std.dev = sdev,
    percent = v / sum(v),
    cumulative = cumsum(v) / sum(v)
  )
}

# Mimic the wide-format result of
# `broom::tidy(prcomp_obj, matrix = "rotation") |> pivot_wider(...)` — return
# the rotation matrix as a tibble with feature names as the first column.
pca_rotation_wide <- function(pca, name_col = "feature_name") {
  tibble::as_tibble(pca$rotation, rownames = name_col)
}
