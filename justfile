# MRMhub task runner — run `just --list` for the menu.
#
# The mrmhub R package is at the repo root, so R commands run here directly
# (no more `cd quant`). The Rust INTEGRATOR lives in integrator/.
# Install just with: brew install just

# Show available recipes
default:
    @just --list

# --- R package (mrmhub, repo root) ---

# Run the test suite
test:
    Rscript -e 'devtools::test()'

# Full R CMD check (matches CI)
check:
    Rscript -e 'devtools::check()'

# Regenerate man/ + NAMESPACE from roxygen
document:
    Rscript -e 'devtools::document()'

# Rebuild the pkgdown site into docs/
site:
    Rscript -e 'pkgdown::build_site()'

# Format all R sources with air (config: air.toml)
format:
    air format .

# Verify formatting without modifying files (CI / pre-commit)
format-check:
    air format --check .

# --- Rust INTEGRATOR (integrator/) ---

# Build the INTEGRATOR executable
build-rust:
    cd integrator && cargo build --release

# Run the INTEGRATOR test suite
test-rust:
    cd integrator && cargo test
