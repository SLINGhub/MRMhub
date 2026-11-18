# INTEGRATOR CI

Two GitHub Actions workflows build and test INTEGRATOR (`MRMhub`) and the viewer `mrmhub-viz`.

| Workflow | Runs on | Result |
|---|---|---|
| [`integrator-release.yml`](../.github/workflows/integrator-release.yml) | push to any branch that changes INTEGRATOR files; manual; publishing a Release with a `v*` tag | zips for macOS (Apple silicon and Intel), Windows (x64) and Linux (x64) as run artifacts; for a Release also attached to it, together with the R source package |
| [`integrator-smoke-windows.yml`](../.github/workflows/integrator-smoke-windows.yml) | manual only (input `tag`) | runs steps 1–3 of a published release's Windows demo package and checks the results |

## integrator-release.yml

Push builds are limited to changes in `integrator/{Cargo.toml,Cargo.lock,src,build.rs,example,demo,MRMhub_plot.r}`, `integrator_viz/`, `docs-site/get-started.qmd` and the workflow file itself; this includes fast-forward pushes of `main` or `develop`.

Jobs:

- **get-started** renders `docs-site/get-started.qmd` to a self-contained `Get-started.html` (artifact `get-started`).
- **build** (one per platform) runs `cargo build --release --locked`, builds `mrmhub-viz` with Tauri, and packs `MRMhub-<version>-<target>.zip` with both binaries, `MRMhub_plot.r` and the example inputs (artifact of the same name). The version comes from the tag on a Release, otherwise from `integrator/Cargo.toml`.
- **r-tarball** (Releases only) checks that `DESCRIPTION` has the tag's version and runs `R CMD build .` (artifact `mrmhub-source-package`).
- **publish** (Releases only) attaches the zips and `mrmhub_<version>.tar.gz` to the Release with `gh release upload`. It is the only job with write access and runs no build code; all other jobs get a read-only token.

Releases whose tag does not start with `v` (e.g. the old GUI tags) are skipped. Actions are pinned to commit SHAs; Dependabot (`.github/dependabot.yml`) proposes updates monthly.

Optional configuration (repository Settings → Secrets and variables → Actions):

- macOS signing and notarization: secrets `MACOS_CERT_P12_BASE64`, `MACOS_CERT_PASSWORD`, `MACOS_KEYCHAIN_PASSWORD`, `MACOS_SIGN_IDENTITY`, `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8_BASE64`. Without them the macOS binaries get an ad-hoc signature, and users clear Gatekeeper as described in the [setup guide](https://slinghub.github.io/MRMhub/integrator/setup.html).
- Demo packages: variable `DEMO_DATA_URL` (zip with `mzML/` and `QUANT/`). When it is set, each build also packs `MRMhub-demo-<version>-<target>.zip`.

Neither is configured at present (October 2026). The demo packages of a release are therefore assembled locally from its program zips and added with `gh release upload`.

## integrator-smoke-windows.yml

Downloads `MRMhub-demo-*-x86_64-pc-windows-msvc.zip` from the given release, runs `MRMhub.exe 1`, `2` and `3`, and fails unless `missing_files.txt`, `missing_compounds.txt` and `ambiguous_assignment.csv` are empty and `long.csv` has one row per run and transition. The resulting `long.csv` is kept as artifact `long-windows-<tag>`, e.g. for comparison with a macOS run.

## Triggering manually

Manual runs need write access to the repository. In the browser: **Actions** tab → workflow → **Run workflow**.

### Command line (GitHub CLI)

```bash
# Build all platforms from a branch (artifacts only; nothing is published)
gh workflow run integrator-release.yml --ref develop

# Windows smoke test of a published release
gh workflow run integrator-smoke-windows.yml -f tag=v1.0.1

# Follow runs and fetch results
gh run list --workflow integrator-release.yml --limit 3
gh run watch <run-id> --exit-status > /dev/null; echo $?   # 0 = success
gh run download <run-id> -n MRMhub-1.0.1-aarch64-apple-darwin
gh run download <run-id> -n long-windows-v1.0.1
gh run rerun <run-id> --failed
```

Publishing a Release (`gh release create v1.0.1 --verify-tag …`) starts the release build by itself.

### R (gh package)

The [gh](https://gh.r-lib.org) package calls the same GitHub API. It needs a GitHub token with `repo` scope, e.g. from `usethis::create_github_token()` stored with `gitcreds::gitcreds_set()`; `gh::gh_whoami()` checks it.

```r
# Build all platforms from a branch
gh::gh(
  "POST /repos/{owner}/{repo}/actions/workflows/{workflow}/dispatches",
  owner = "SLINGhub", repo = "MRMhub",
  workflow = "integrator-release.yml", ref = "develop"
)

# Windows smoke test of a published release
gh::gh(
  "POST /repos/{owner}/{repo}/actions/workflows/{workflow}/dispatches",
  owner = "SLINGhub", repo = "MRMhub",
  workflow = "integrator-smoke-windows.yml",
  ref = "main", inputs = list(tag = "v1.0.1")
)

# Latest runs of a workflow
runs <- gh::gh(
  "GET /repos/{owner}/{repo}/actions/workflows/{workflow}/runs",
  owner = "SLINGhub", repo = "MRMhub",
  workflow = "integrator-release.yml", per_page = 3
)
vapply(runs$workflow_runs, \(r) paste(r$id, r$head_branch, r$status, r$conclusion %||% ""), "")

# Open the Actions page in the browser
usethis::browse_github_actions()
```

A dispatch returns an empty response; the new run appears in the list after a few seconds. The CLI can also be called from R, e.g. `system2("gh", c("workflow", "run", "integrator-release.yml", "--ref", "develop"))`.

## Local equivalents

`just build-rust` (`cargo build --release` in `integrator/`) and `just test-rust` (`cargo test`).
