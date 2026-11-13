# Test and legacy-code audit — 2026-10-18

Scope: the desktop GUI, native backend, GUI worker, standalone INTEGRATOR/VIZ,
and the R package. The audit began on a clean checkout at `46fd887f`. No release
installer was built and no changes were committed or pushed.

## Removal evidence

Two duplicate ISTD tests were removed from
`tests/testthat/test-calc-istd-normalization.R`. Parsing the original file with
`keep.source = FALSE` proves expressions 7 and 8 duplicate expressions 5 and 6
exactly, including all expectations and setup. The first copies remain.

Four unused Tauri starter files in `integrator_viz/src/` were removed:
`main.js`, `styles.css`, `assets/tauri.svg`, and `assets/javascript.svg`.
`src-tauri/tauri.conf.json` serves `src/index.html`, which imports `index.js`
and uses its own inline styles. None of the four files has an inbound
HTML/import/CSS/config reference. The starter script's greet form is absent
from the real app. The standalone visualizer and its runtime icons remain.

The one-line `.covrignore` excluded `R/calc-eda.R`, but those PCA helpers are
called by the current plotting and outlier code. That exclusion was removed
to restore coverage measurement of active code; the implementation remains.

The following are **retained**, because absence of an internal caller is not
proof of obsolescence:

- `integrator/` and `integrator_viz/` have current release-workflow and manual
  references, and independent tests.
- QUANT Legacy is an active GUI workflow. The browser previews provide documented
  manual coverage; the R harnesses check different execution paths and parity.
- CSV aliases, nested-backup migration, and standalone worker discovery have
  current callers or backwards-compatibility contracts.
- The CodeMirror legacy-mode dependency supplies the current R editor. Its name
  does not make it obsolete. The editor and terminal bundles match their source
  when rebuilt in memory with the installed, locked dependencies.

## Confirmed fixes

- Terminal Stop could hang while reaping a shell with unacknowledged output.
  Its PTY reader now drains queued output during shutdown without waiting for
  GUI acknowledgements. The existing real-process regression has a deadline
  so another deadlock produces a failure rather than wedging the suite.
- Worker Step 4 ignored a failed R subprocess exit. Failures now propagate and
  stderr reaches the existing activity stream.
- Worker mzML parsing could loop forever when no run element existed. Missing
  runs, malformed XML and premature EOF now return errors through Step 1.
  Valid-input sample ordering and timestamp extraction are preserved.
- The native build watched only already discovered QUANT package files. Adding
  a new R/data file could leave the embedded package stale. Source-directory
  watches now trigger discovery again; adding and removing a temporary R file
  was verified against the generated embedded source, then the probe was removed.
- Sequence tests used JSON equality that conflated nonfinite numbers with null,
  and approximate comparisons that accepted NaN. Strict comparisons now reject
  invalid RT values without removing any integration coverage.
- Archive verification hashed process-specific metadata callback environments.
  Reopening a calibrated Dataset4 archive produced false mismatch messages even
  with identical data. New archives use a versioned serialized-content hash;
  legacy hashes still use their original verification. Tests retain detection
  of changed scientific values and cover resaving archives and disabling hashes.
  The helper normalizes only serialization's R-runtime header fields, retaining
  the format and payload, following [R Internals section 1.8](https://cran.r-project.org/doc/manuals/r-devel/R-ints.html#Serialization-Formats).
- The dependency-diagnostic test mocked every optional package as installed,
  then failed when fetching versions of absent suggestions. It now overrides
  only the required package whose absence it is testing.
- The local Shiny browser smoke test caught every launch error and reported a
  skip. It now checks browser prerequisites explicitly; actual app startup
  errors fail. Browser discovery follows the documented
  [chromote API](https://rstudio.github.io/chromote/reference/find_chrome.html).
- Two multicore plotting tests stopped their mirai daemons only at the end of
  the happy path. Deferred cleanup now stops them even if a test errors. Both
  tests pass again, and daemon status is zero after completion.

## Completed checks

| Check | Result |
| --- | --- |
| GUI frontend, Deno | 62 passed |
| Tutorial paste, actual R parser | 36 expression-parity cases passed |
| Native GUI, Cargo | 59 passed, including real PTY/process cleanup |
| GUI worker, Cargo | 7 passed, including 4 added regressions |
| Windows GUI, cargo-xwin check | Passed |
| Standalone INTEGRATOR, Cargo | 1 passed |
| Standalone VIZ, Cargo | 14 passed; 2 external-dataset tests remain ignored |
| QUANT Guided integration | Passed; exact numeric parity, plots, table edits, exports |
| QUANT Legacy integration | Passed; session, graphics, RNG and error isolation |
| QUANT current API / Dataset4 integration | Passed; metadata, exclusions, calibration and exports |
| R affected dependency/multicore rerun | 1,037 assertions passed; no errors; 65 skips |
| R final archive/setup rerun | 118 assertions passed; no errors or skips |
| Workflow-builder server tests | 14 assertions passed; browser smoke needs shinytest2 |
| Editor and terminal generated assets | All three bundles matched source in memory |
| Native Clippy | Completed with existing style warnings |

The R integration suites use a fresh installation of this checkout's package
1.0.1 in an isolated temporary library, reusing installed dependencies read-only.
They do not test against the older package installed for the user's application.

## Limits

- The standalone VIZ's two external-data regressions need
  `MRMHUB_TEST_DATA_DIR`; the dataset is not available in this checkout.
- Windows source compilation is verified; Windows runtime/installer behavior
  was not exercised on Windows during this audit.
- Native lint warnings are retained as style findings, not recast as runtime
  defects. Strict worker Clippy with `-D warnings` is not clean.
- Existing GitHub CI primarily checks the R package. The desktop commands above
  still need to be run explicitly; no hosted CI run was initiated by this audit.

## R package suite and remaining environment work

The full source-package run recorded **2,546 passing assertions, 20 errors,
80 skips and no failed expectations**. This was not a green full-suite run.
All 20 errors were investigated: 12 needed `enviPat`, four plot files imported
absent `vdiffr`, one needed `qpdf`, one needed `lancer`, and two mirai tests hit
sandbox socket restrictions. These tests were retained. Small CRAN dependencies
were subsequently installed in the temporary audit library and the affected
files rerun with socket access and child-process library paths supplied.

After the final archive fix, **118 targeted archive/setup assertions pass with
zero errors or skips**. The real Dataset4 GUI adapter also passed again with an
explicit assertion that archive reopening verifies its fingerprint and does not
emit a mismatch. Exact object equality, scientific numerical parity, and tamper
detection remain covered. New tests check runtime header variation and older
archive verification. This host has one R version; the header-variation test
simulates another writer version rather than claiming a second R installation
was exercised.

The four workflow-builder server tests pass (14 assertions). The local browser
smoke is still unverified because `shinytest2` is absent. Its startup exceptions
are no longer converted into skips once prerequisites are satisfied.

`lancer` is still absent; its optional plotting/export dependency stack was not
installed solely to make the audit green. The `test-calc-response.R` test
`get_response_curve_stats works` still errors when requesting saturation
statistics that require it. Visual snapshot comparisons are not claimed as passed under
`RUN_VDIFFR=false`; all tracked snapshot files are preserved unchanged.

Combining each file's latest result from the full run and the focused reruns
gives **3,171 passing assertions, zero failed expectations, one error, 112 skips
and no warnings across 892 test cases**. This is an aggregate of runs, not a
claim that a third full-suite invocation passed. The one remaining error is the
missing-`lancer` case above. No failing test was removed or converted into a skip.
Both changed multicore tests additionally passed a direct five-assertion rerun
with their new cleanup, leaving zero daemons. Complete current results are in
`/private/tmp/mrmhub-r-audit.OEahIC/combined-latest.csv`.

`R CMD check`, a coverage-percentage run, designated visual-baseline comparisons,
and actual Windows runtime checks were not performed. The PCA coverage exclusion
was removed based on live callers, not on a claimed coverage-percentage increase.

Debug build artifacts generated for the Rust audit were removed with Cargo's
development-profile cleanup (approximately 4.8 GiB). They can be regenerated;
release installers and user datasets were not changed. Temporary R libraries
and complete diagnostic logs remain under `/private/tmp/mrmhub-r-audit.OEahIC`.
