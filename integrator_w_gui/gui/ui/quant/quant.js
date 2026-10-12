import { parameterValue, displayValue, finalFilter, resultViewForOperation, metadataCoverageText } from "./model.js";
import { legacySteps, legacyGroups, matchesWorkflow, legacyDraftKey, historyForMode } from "./legacy.js?v=1.2.4-layout";
import { createREditor } from "./r-editor.bundle.js";
import { inspectRPaste, datasetImportCode } from "./paste.js";
import { initializeConsole } from "./console.js?v=1.2.4-console-theme";
import { initializeOutput } from "./log.js";
import { createPlotViewer } from "./plot-viewer.js";
import { savedGraphs, chooseGraph } from "./graphs.js";
import { initializeProgress } from "./progress.js";
import { formatStorageBytes } from "./storage.js";

const native = window.__TAURI__;
const invoke = (...args) => native.core.invoke(...args);
const shell = () => window.__mrmhubShell;
const confirm = (title, message) => shell().confirm(message, title);
let root, path, history = [], allHistory = [], graphs = [], current, catalog = [], selected, ready = false, busy = false;
let table = "dataset", offset = 0, page, changes = new Map(), generation = 0;
let resultView = "plots", loadedTableKey = "", selectedRows = new Set();
const drafts = new Map();
let mode = "guided", legacyStep = 0, legacyDrafts = {}, legacyTrusted = false;
let legacyEditor, output, plotViewer, runProgress;
let storageInfo, storageLoading = false, storageToken = 0, storageCheckedAt = 0;
const $ = id => root.querySelector(`#q-${id}`);
const make = (tag, text, className) => {
  const el = document.createElement(tag); if (text != null) el.textContent = text;
  if (className) el.className = className; return el;
};
const checkpointKey = () => mode === "legacy" ? `mrmhub-quant-legacy-checkpoint:${path}` : `mrmhub-quant-checkpoint:${path}`;
const opName = id => id?.startsWith("legacy-") ? `Step ${Number(id.slice(7)) + 1} · ${legacySteps[Number(id.slice(7))]}` : catalog.find(o => o.id === id)?.label ?? id ?? "Edit metadata";
const trashButton = (id, label, all = false) => `<button id="q-${id}" type="button" class="q-trash" aria-label="${label}" title="${label}" disabled><svg aria-hidden="true" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"><path d="M3 6h18M9 6V3h6v3M5 6l1 15h12l1-15M10 10v7M14 10v7"/></svg>${all ? '<span>All</span>' : ''}</button>`;
function log(text) {
  output.append(text);
}
function setBusy(value, message = "") {
  busy = value;
  $("busy").classList.toggle("hidden", !value);
  $("busy-text").textContent = message;
  $("workspace").disabled = value;
  $("setup").disabled = value;
  $("runtime").disabled = value;
  $("check").disabled = value;
  $("guided-tab").disabled = value;
  $("legacy-tab").disabled = value;
  legacyEditor?.setReadOnly(value);
  $("terminal-state").textContent = value ? "Running" : "Idle";
  $("terminal-state").classList.toggle("running", value);
  root.setAttribute("aria-busy", String(value));
}
async function task(message, fn) {
  if (busy) return;
  setBusy(true, message); $("error").textContent = "";
  try { return await fn(); }
  catch (e) { $("error").textContent = String(e); log(`Error: ${e}`); }
  finally { setBusy(false); updateRun(); }
}
function updateRun() {
  $("run").disabled = busy || !ready || !path || !!selected?.missingPackages?.length || (!current && selected?.kind !== "import");
  $("legacy-run").disabled = busy || !ready || !path || !legacyEditor?.getValue().trim();
  legacyEditor?.setRunnable(!$("legacy-run").disabled);
  $("delete-plot").disabled = busy || !graphs.length;
  $("delete-plots").disabled = busy || !graphs.length;
  $("delete-checkpoint").disabled = busy || !current;
  $("delete-checkpoints").disabled = busy || !allHistory.some(h => (h.action === "legacy") === (mode === "legacy"));
  $("compact").disabled = busy || !path;
  $("storage-refresh").disabled = busy || storageLoading || !native || !path;
  $("exclude-rows").disabled = busy || !selectedRows.size;
  $("legacy-prev").disabled = busy || legacyStep === 0;
  $("legacy-next").disabled = busy || legacyStep === legacySteps.length - 1;
}
export async function initializeQuant(projectPath) {
  if (!root) {
    root = document.querySelector("#quant-view");
    root.innerHTML = `
      <div class="q-chrome">
        <header class="q-topbar">
          <div><span class="eyebrow">Quantitation & quality control</span><h1>QUANT</h1><p id="q-dataset" class="q-dataset"></p></div>
          <details id="q-engine-settings" class="q-engine-settings">
            <summary><span id="q-engine-indicator" class="q-status-dot" aria-hidden="true"></span><strong id="q-engine-title">Checking R…</strong><span class="q-engine-label">R setup<svg aria-hidden="true" viewBox="0 0 12 12" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><path d="m3 7.5 3-3 3 3"/></svg></span></summary>
            <div class="q-engine-popover"><h2>R engine</h2><p id="q-engine-detail" class="q-help">R runs in the background. No RStudio or separate plot windows.</p><div class="q-actions"><button id="q-check" type="button">Check R</button><button id="q-runtime" type="button">Locate Rscript</button><button id="q-setup" type="button">Set up R dependencies</button></div></div>
          </details>
        </header>
        <div class="q-modebar"><div class="q-subtabs q-mode-tabs" role="tablist" aria-label="QUANT workflow mode"><button id="q-guided-tab" type="button" role="tab" aria-selected="true" aria-controls="q-guided-editor">Guided workflow</button><button id="q-legacy-tab" type="button" role="tab" aria-selected="false" aria-controls="q-legacy-editor" tabindex="-1">Legacy · R code</button></div><span id="q-mode-description" class="q-help">Choose operations and adjust their settings.</span></div>
        <div id="q-busy" class="q-progress hidden" role="status"><span></span><p id="q-busy-text"></p></div>
        <p id="q-error" class="q-error" role="alert"></p>
        <fieldset id="q-workspace" class="q-workspace">
          <aside class="q-stages" aria-label="Workflow navigation">
            <div class="q-nav-heading"><h2 id="q-nav-title">Workflow</h2><span id="q-nav-count"></span></div>
            <p id="q-stage-help" class="q-help">Choose what your assay needs. Optional steps stay optional.</p>
            <div class="q-search"><input id="q-search" type="search" aria-label="Find a workflow operation or Legacy step" placeholder="Find an operation…" autocomplete="off"><button id="q-search-clear" type="button" class="hidden" aria-label="Clear workflow search">×</button></div>
            <nav id="q-stages" aria-label="Guided operations"></nav><nav id="q-legacy-stages" class="hidden" aria-label="Legacy tutorial steps"></nav>
            <p id="q-search-empty" class="q-help hidden" role="status">No matching steps. Try another name or clear the search.</p>
          </aside>
          <div class="q-main q-workbench">
            <section class="q-session" aria-label="Active analysis">
              <div class="q-session-bar"><label for="q-checkpoint" class="q-section-label">Current session</label><select id="q-checkpoint" aria-label="Analysis checkpoint"></select><span class="q-session-local">Local to this dataset</span></div>
              <p id="q-summary" class="q-help"></p>
              <details class="q-disclosure q-session-tools"><summary>Manage session & storage<span id="q-storage-summary" class="q-storage-summary" aria-live="polite">Checking folder size…</span></summary><div class="q-session-management"><div class="q-storage-row" role="group" aria-label="QUANT folder storage"><div><span>QUANT folder</span><strong id="q-storage-total">—</strong></div><div><span>Cleanup estimate</span><strong id="q-storage-free">—</strong></div><div><span>In trash</span><strong id="q-storage-trash">—</strong></div><button id="q-storage-refresh" type="button" aria-label="Refresh QUANT folder size">Refresh size</button></div><p id="q-storage-path" class="q-help q-storage-path"></p><p id="q-storage-note" class="q-help q-storage-note">Sizes count saved sessions, graphs, exports and trash. Linked folders are not followed; shared hard-linked files count once.</p><p class="q-help">One latest saved session per workflow. Earlier graphs and exports stay available; old-version snapshots remain until you free their storage.</p><div class="q-actions"><button id="q-legacy-new" type="button" class="hidden">New R session</button><button id="q-compact" type="button">Free old session storage…</button><div class="q-action-group" aria-label="Checkpoint deletion">${trashButton("delete-checkpoint", "Delete selected checkpoint")}${trashButton("delete-checkpoints", "Delete all checkpoints in this mode", true)}</div></div></div></details>
            </section>
            <section id="q-guided-editor" role="tabpanel" aria-labelledby="q-guided-tab" class="q-panel q-editor">
              <div class="q-editor-heading"><div><p id="q-operation-stage" class="q-section-label"></p><h2 id="q-operation-title">Choose an operation</h2></div><span id="q-operation-kind" class="q-kind"></span></div>
              <p id="q-note" class="q-operation-note"></p>
              <div id="q-import" class="q-form hidden"><label>Experiment title<input id="q-title" type="text" value=""></label><label>Analysis type<select id="q-analysis-type"><option value="lipidomics">Lipidomics</option><option value="metabolomics">Metabolomics</option><option value="externalcalib">External calibration</option><option value="others">Other</option></select></label></div>
              <div id="q-presets" class="q-actions q-presets hidden"></div><div id="q-fields" class="q-form"></div>
              <details id="q-advanced" class="q-disclosure q-advanced"><summary>More settings <span id="q-advanced-count"></span></summary><div id="q-extra-fields" class="q-form"></div></details>
              <details class="q-disclosure q-settings-help"><summary>How settings work</summary><p class="q-help">Checked settings are passed to R; unchecked settings use the original function default. IDs and patterns use one per line, other lists use commas. NA means missing / no restriction. Blank optional checked values mean NA.</p></details>
              <footer class="q-runbar"><span class="q-help">Saved automatically after a successful run.</span><button id="q-run" type="button" class="q-primary">Run operation</button></footer>
            </section>
            <section id="q-legacy-editor" role="tabpanel" aria-labelledby="q-legacy-tab" class="q-panel q-editor hidden">
              <div class="q-editor-heading"><div><p id="q-legacy-phase" class="q-section-label"></p><h2 id="q-legacy-title"></h2></div><div class="q-step-navigation"><button id="q-legacy-prev" type="button" aria-label="Previous Legacy step">←</button><span id="q-legacy-position" aria-live="polite"></span><button id="q-legacy-next" type="button" aria-label="Next Legacy step">→</button></div></div>
              <p class="q-operation-note">Paste or write R for this step. Your objects carry over between successful runs.</p>
              <div class="q-legacy-tools"><details class="q-disclosure"><summary>Tutorial & code help</summary><div class="q-help"><p>Follow the <a href="https://slinghub.github.io/MRMhub/quant/articles/tutorial-03-lipidomics-workflow.html" target="_blank" rel="noopener noreferrer">original lipidomics tutorial</a>. Edit paths, sample IDs and settings for your dataset. Recognized pasted output is cleaned when you Run; nothing runs automatically.</p><p>Keep your experiment in <code>mexp</code> to inspect its tables. Relative paths start in <code>dataset_dir</code>; use <code>output_dir</code> for this run’s exports. Plots appear in Results and View() prints in Activity. Live connections and background workers are not restored between blocks.</p></div></details><button id="q-legacy-import" type="button" class="hidden">Insert import for this dataset</button></div>
              <div id="q-legacy-code"></div><p id="q-legacy-paste-note" class="q-help" role="status"></p>
              <footer class="q-runbar"><span class="q-help">Only run trusted code. R has access to your files and network.</span><button id="q-legacy-run" type="button" class="q-primary">Run code</button></footer>
            </section>
            <section class="q-results" aria-label="Analysis results">
              <header class="q-results-heading"><h2>Results</h2><div class="q-subtabs q-result-tabs" role="tablist" aria-label="QUANT results"><button id="q-plots-tab" type="button" role="tab" aria-selected="true" aria-controls="q-plots-panel">Graphs & outputs</button><button id="q-data-tab" type="button" role="tab" aria-selected="false" aria-controls="q-data-panel" tabindex="-1">Data & metadata</button></div></header>
              <section id="q-data-panel" role="tabpanel" aria-labelledby="q-data-tab" class="q-panel hidden">
                <div class="q-result-toolbar"><label for="q-table-choice" class="q-section-label">Table</label><select id="q-table-choice" aria-label="Data table"></select></div>
                <p id="q-metadata-coverage" class="q-help q-coverage"></p><details class="q-disclosure"><summary>About this table</summary><p id="q-table-note" class="q-help">Import data to inspect tables.</p></details>
                <div id="q-exclusions" class="q-actions q-exclusions hidden"><button id="q-exclude-rows" type="button" disabled>Exclude selected rows</button><button id="q-restore-rows" type="button">Restore all exclusions in this table</button><span id="q-selected-count" class="q-help"></span></div>
                <div id="q-table" class="q-table-wrap"></div><div class="q-row q-table-footer"><div class="q-actions"><button id="q-prev" type="button" aria-label="Previous table page">←</button><span id="q-page"></span><button id="q-next" type="button" aria-label="Next table page">→</button></div><div class="q-actions"><button id="q-discard" type="button">Discard edits</button><button id="q-save-edits" type="button" class="q-primary">Save metadata changes</button></div></div>
              </section>
              <section id="q-plots-panel" role="tabpanel" aria-labelledby="q-plots-tab" class="q-panel">
                <div class="q-result-toolbar"><label for="q-plot-choice" class="q-section-label">Saved graph</label><select id="q-plot-choice" aria-label="Saved graphs from all steps"></select><div class="q-actions"><button id="q-save-plot" type="button" disabled>Save graph…</button><div class="q-action-group" aria-label="Plot deletion">${trashButton("delete-plot", "Delete displayed plot")}${trashButton("delete-plots", "Delete all saved plots", true)}</div></div></div>
                <p class="q-help q-result-hint">All steps, both workflows. Viewing a graph never changes your current session.</p><div id="q-plot"></div>
                <details class="q-disclosure q-downloads"><summary>Downloads & run details</summary><div id="q-files" class="q-files"></div><p id="q-output-path" class="q-help"></p></details>
              </section>
            </section>
          </div>
        </fieldset>
      </div>
      <section class="q-activity q-terminal" aria-label="QUANT activity">
        <div class="q-terminal-bar"><div class="q-actions"><span class="q-terminal-title"><span aria-hidden="true">&gt;_</span> QUANT activity</span>
          <div class="q-console-tabs" role="tablist" aria-label="Activity console">
            <button id="q-r-console-tab" type="button" role="tab" aria-selected="true" aria-controls="q-r-console-panel">R Console</button>
            <button id="q-shell-console-tab" type="button" role="tab" aria-selected="false" aria-controls="q-shell-console-panel" tabindex="-1">Terminal</button>
          </div></div>
          <div class="q-actions"><label id="q-output-colors-label" class="q-output-colors"><input id="q-output-colors" type="checkbox"> Smart colors</label><span id="q-terminal-state" class="q-terminal-state">Idle</span><span id="q-shell-state" class="q-terminal-state hidden">Stopped</span><button id="q-shell-start" type="button" class="hidden">Start session</button><button id="q-clear-log" type="button">Clear</button><button id="q-console-expand" type="button" aria-expanded="false">Expand ⛶</button></div>
        </div>
        <div id="q-r-console-panel" role="tabpanel" aria-labelledby="q-r-console-tab"><pre id="q-log" aria-label="R activity log" tabindex="0"></pre><div id="q-run-progress" role="progressbar" aria-label="Legacy R work progress" aria-valuemin="0" aria-valuemax="100"><pre></pre><div class="q-run-progress-status"></div><small>Completed work units: session load, top-level R statements, session save. Long statements may hold at one percentage.</small></div><div class="q-terminal-foot">R workflow output · stdout / stderr · Run R code in the editor above</div></div>
        <div id="q-shell-console-panel" role="tabpanel" aria-labelledby="q-shell-console-tab" class="hidden"><div id="q-shell-screen" aria-label="Interactive system terminal"></div><div id="q-shell-note" class="q-terminal-foot" role="status">Local shell · Starts in your home folder · Commands have normal access to your files</div></div>
      </section>`;
    legacyEditor = createREditor($("legacy-code"), { onChange: () => { saveLegacyDraft(); updatePasteNote(); updateRun(); }, onRun: runLegacy });
    output = initializeOutput($("log"), $("output-colors"));
    runProgress = initializeProgress(root);
    initializeConsole(root, confirm, () => output.clear());
    plotViewer = createPlotViewer(root);
    $("check").onclick = () => task("Checking R…", checkRuntime);
    $("runtime").onclick = async () => {
      if (!native) return;
      const file = await native.dialog.open({ title: "Choose Rscript (Rscript.exe on Windows)", multiple: false });
      if (file) await task("Checking the selected R runtime…", () => checkRuntime(file));
    };
    $("setup").onclick = async () => {
      if (!await confirm("Download QUANT’s R dependencies?", "This installs packages from CRAN and Bioconductor into an app-owned library and installs this app’s bundled QUANT source. It needs internet access and may take several minutes. Your system R library is not changed.")) return;
      await task("Installing R dependencies — see activity below. Keep the app open.", async () => {
        await invoke("quant_setup"); await checkRuntime();
      });
    };
    $("run").onclick = run;
    $("guided-tab").onclick = () => switchMode("guided");
    $("legacy-tab").onclick = () => switchMode("legacy");
    for (const [key, other] of [["guided", "legacy"], ["legacy", "guided"]]) {
      $(`${key}-tab`).onkeydown = event => {
        if (!["ArrowLeft", "ArrowRight", "Home", "End"].includes(event.key)) return;
        event.preventDefault();
        const next = event.key === "Home" ? "guided" : event.key === "End" ? "legacy" : other;
        $(`${next}-tab`).focus(); $(`${next}-tab`).click();
      };
    }
    $("search").oninput = filterNavigation;
    $("search-clear").onclick = () => { $("search").value = ""; filterNavigation(); $("search").focus(); };
    $("search").onkeydown = event => { if (event.key === "Escape") { event.preventDefault(); $("search-clear").click(); } };
    for (const [id, delta] of [["legacy-prev", -1], ["legacy-next", 1]]) $(id).onclick = () => {
      if (busy) return;
      $("search").value = ""; chooseLegacyStep(Math.max(0, Math.min(legacySteps.length - 1, legacyStep + delta)));
      $("legacy-title").scrollIntoView({block:"nearest"});
    };
    $("legacy-import").onclick = async () => {
      if (busy) return;
      if (legacyEditor.getValue().trim() && !await confirm("Replace this step’s code?", "Insert an import that reads long.csv from the selected dataset. You can undo this edit in the code editor. Review analysis_type before running.")) return;
      legacyEditor.setValue(datasetImportCode(path)); saveLegacyDraft(); updatePasteNote(); updateRun(); legacyEditor.focus();
    };
    $("legacy-run").onclick = runLegacy;
    $("legacy-new").onclick = () => task("Starting a new R session…", async () => {
      if (!await confirm("Start a new R session?", "This clears the active Legacy session. Your code boxes and saved outputs are kept. The current session snapshot is retired only after a new block succeeds.")) return;
      current = undefined; remember(); await renderResult();
    });
    for (const group of legacyGroups) {
      const box = make("details"); box.className = "q-nav-group";
      const summary = make("summary"); summary.append(make("span", group.label), make("small", `${group.start + 1}–${group.end + 1}`)); box.append(summary);
      for (let index = group.start; index <= group.end; index++) {
        const button = make("button"); button.type = "button"; button.dataset.legacyStep = index;
        button.append(make("span", String(index + 1).padStart(2, "0"), "q-step-number"), make("span", legacySteps[index]));
        button.onclick = () => { chooseLegacyStep(index); $("legacy-title").scrollIntoView({ block: "nearest" }); };
        box.append(button);
      }
      $("legacy-stages").append(box);
    }
    chooseLegacyStep(0);
    $("checkpoint").onchange = () => task("Loading checkpoint…", async () => {
      if (!await discardWarning()) { $("checkpoint").value = current?.id ?? ""; return; }
      current = history.find(h => h.id === $("checkpoint").value); remember();
      await renderResult();
    });
    $("table-choice").onchange = () => task("Loading table…", async () => {
      if (!await discardWarning()) { $("table-choice").value = table; return; }
      table = $("table-choice").value; offset = 0; await loadTable();
    });
    $("prev").onclick = () => navigateTable(-50);
    $("next").onclick = () => navigateTable(50);
    $("discard").onclick = () => task("Reloading table…", async () => { if (await discardWarning()) await loadTable(); });
    $("save-edits").onclick = saveEdits;
    $("exclude-rows").onclick = () => excludeRows(false);
    $("restore-rows").onclick = () => excludeRows(true);
    for (const view of ["plots", "data"]) {
      $(`${view}-tab`).onclick = () => task("Loading results…", () => showResults(view));
      $(`${view}-tab`).onkeydown = event => {
        if (!["ArrowLeft", "ArrowRight", "Home", "End"].includes(event.key)) return;
        event.preventDefault(); const next = event.key === "Home" ? "plots" : event.key === "End" ? "data" : view === "plots" ? "data" : "plots";
        $(`${next}-tab`).focus(); $(`${next}-tab`).click();
      };
    }
    $("plot-choice").onchange = () => task("Loading graph…", loadPlot);
    $("delete-plot").onclick = () => deleteHistory("plots", false);
    $("delete-plots").onclick = () => deleteHistory("plots", true);
    $("delete-checkpoint").onclick = () => deleteHistory("checkpoints", false);
    $("delete-checkpoints").onclick = () => deleteHistory("checkpoints", true);
    $("compact").onclick = compactStorage;
    $("storage-refresh").onclick = () => refreshStorage(true);
    $("save-plot").onclick = () => task("Saving graph…", async () => {
      const graph = graphs.find(g => g.key === $("plot-choice").value);
      if (!graph) return;
      const destination = await native.dialog.save({ defaultPath: graph.name, title: "Save selected QUANT graph" });
      if (destination) await invoke("quant_save_artifact", { project: path, id: graph.id, name: graph.name, destination });
    });
    if (native) await native.event.listen("quant-log", event => log(event.payload));
    if (native) await native.event.listen("quant-progress", event => runProgress.receive(event.payload));
  }
  if (busy) {
    if (projectPath !== path) $("error").textContent = "An analysis for the previous dataset is still running. Reopen QUANT when it finishes to switch datasets.";
    return;
  }
  if (path !== projectPath) {
    if (!await discardWarning()) return;
    path = projectPath; current = undefined; history = []; allHistory = []; graphs = []; offset = 0; generation++;
    storageInfo = undefined; storageLoading = false; storageCheckedAt = 0; storageToken++;
    $("storage-summary").textContent = path ? "Checking folder size…" : "No dataset selected";
    for (const id of ["storage-total", "storage-free", "storage-trash"]) $(id).textContent = "—";
    $("storage-path").textContent = "";
    loadLegacyDrafts();
    drafts.clear(); selected = undefined;
    $("dataset").textContent = path?.split(/[\\/]/).pop() || "Select a dataset folder in Integrator to begin.";
    $("dataset").title = path || "";
    $("title").value = path?.split(/[\\/]/).pop() || "Experiment";
    await task("Loading this dataset’s QUANT history…", async () => {
      if (native && path) allHistory = await invoke("quant_history", { project: path });
      history = historyForMode(allHistory, mode);
      let remembered; try { remembered = localStorage.getItem(checkpointKey()); } catch { /* optional */ }
      current = remembered === "" ? undefined : history.find(h => h.id === remembered) ?? history[0];
      await renderResult();
    });
    if (catalog.length) chooseOperation("import_data_mrmhub");
  }
  if (!native) { $("engine-title").textContent = "Desktop app required"; $("engine-detail").textContent = "QUANT runs in the desktop app. This browser preview cannot execute R."; $("storage-summary").textContent = "Folder size available in desktop app"; $("setup").disabled = true; return; }
  if (!catalog.length) await task("Checking the R engine…", checkRuntime);
  await refreshStorage();
  updateRun();
}
async function refreshStorage(force = false) {
  if (!native || !path || storageLoading) return storageInfo;
  if (!force && storageInfo && Date.now() - storageCheckedAt < 10_000) return storageInfo;
  const project = path, token = ++storageToken;
  storageLoading = true; updateRun();
  try {
    const info = await invoke("quant_storage", { project });
    if (token !== storageToken || project !== path) return;
    storageInfo = info; storageCheckedAt = Date.now();
    const prefix = info.skippedEntries ? "≥ " : "";
    $("storage-summary").textContent = `Folder: ${prefix}${formatStorageBytes(info.totalBytes)}`;
    $("storage-summary").title = `Updated ${new Date(storageCheckedAt).toLocaleTimeString()} · ${info.folder}`;
    $("storage-total").textContent = prefix + formatStorageBytes(info.totalBytes);
    $("storage-free").textContent = formatStorageBytes(info.reclaimableBytes);
    $("storage-trash").textContent = formatStorageBytes(info.trashBytes);
    $("storage-path").textContent = info.folder;
    $("storage-note").textContent = `${Number(info.files).toLocaleString()} files. Estimates count shared hard-linked files once and exclude data still linked elsewhere. Linked folders are not followed.${info.skippedEntries ? ` ${info.skippedEntries} linked or unreadable entries omitted; total is a lower bound.` : ""}`;
    return info;
  } catch (error) {
    if (token !== storageToken || project !== path) return;
    storageInfo = undefined;
    $("storage-summary").textContent = "Folder size unavailable";
    $("storage-note").textContent = `Could not read folder size: ${error}. You can retry with Refresh size.`;
    for (const id of ["storage-total", "storage-free", "storage-trash"]) $(id).textContent = "—";
  } finally {
    if (token === storageToken) { storageLoading = false; updateRun(); }
  }
}
async function deleteHistory(kind, all) {
  await task("Updating saved QUANT history…", async () => {
    const graph = graphs.find(g => g.key === $("plot-choice").value);
    const modeRuns = allHistory.filter(h => (h.action === "legacy") === (mode === "legacy"));
    if (!path || (kind === "plots" ? !graphs.length : !modeRuns.length)) return;
    if (!all && (kind === "plots" ? !graph : !current)) return;
    const label = mode === "legacy" ? "Legacy" : "Guided";
    const selection = kind === "plots"
      ? (all ? `all ${graphs.length} saved plot images from BOTH Guided and Legacy steps` : `the displayed plot “${graph.name}” from ${opName(graph.operation)}`)
      : (all ? `all ${modeRuns.length} ${label} saved runs, including older output-only runs` : `the selected ${label} checkpoint (${opName(current.operation)})`);
    const detail = kind === "plots"
      ? "Analysis sessions, data, PDFs and other non-image exports are kept."
      : `This includes their saved R sessions, data snapshots, graphs and other outputs. ${all ? `The other workflow mode is kept.` : "Other checkpoints are kept."} Any code that explicitly refers to files inside a removed checkpoint will need those files restored.`;
    if (!await confirm(`Delete ${all ? "all" : "selected"} ${kind === "plots" ? "plot" + (all ? "s" : "") : "checkpoint" + (all ? "s" : "")}?`,
      `Move ${selection} to trash for this dataset?\n\n${detail}\n\nItems go to QUANT/.trash with recovery instructions, not permanent deletion. They still use disk space until you use “Free old session storage…” or manually empty that folder. Dataset input files and exports saved elsewhere are untouched.`)) return;
    if (!await discardWarning()) return;
    const oldId = current?.id;
    plotViewer.close();
    try {
      const result = await invoke("quant_delete", { project: path, kind, all, mode,
        id: kind === "plots" ? graph?.id ?? "" : current?.id ?? "", name: graph?.name ?? "" });
      log(`Moved ${result.count} ${kind} to dataset trash.${result.trash ? ` Recovery: ${result.trash}` : ""}`);
    } finally {
      // Also refresh after a partial filesystem failure, so no stale selection
      // can point at an item that was already moved successfully.
      allHistory = await invoke("quant_history", { project: path });
      history = historyForMode(allHistory, mode);
      current = oldId ? history.find(h => h.id === oldId) ?? history[0] : undefined;
      changes.clear(); offset = 0; generation++; remember();
      await renderResult();
      await refreshStorage(true);
    }
  });
}

async function compactStorage() {
  await task("Freeing old QUANT session storage…", async () => {
    if (!path) return;
    const size = await refreshStorage(true);
    const estimate = size ? `QUANT folder: ${size.skippedEntries ? "at least " : ""}${formatStorageBytes(size.totalBytes)}. Estimated space reclaimed: ${formatStorageBytes(size.reclaimableBytes)}. Trash contains ${formatStorageBytes(size.trashBytes)}.\n\n` : "";
    if (!await confirm("Permanently free old QUANT storage?",
      estimate + "This keeps only the newest resumable session in EACH workflow (Guided and Legacy), permanently removes older automatic session/plot-object snapshots, and empties this dataset’s QUANT/.trash.\n\nEarlier graphs, PDFs, exports, R code and logs outside trash stay available. Input datasets and Integrator results are untouched. Older sessions can no longer be resumed, and trashed items cannot be recovered. Export any session you want to keep first.")) return;
    if (!await discardWarning()) return;
    const oldId = current?.id;
    try {
      await invoke("quant_compact", {project:path});
      log("Old session snapshots and dataset trash cleared permanently. Latest Guided/Legacy sessions and saved outputs kept.");
    } finally {
      allHistory = await invoke("quant_history", {project:path}); history = historyForMode(allHistory, mode);
      current = history.find(h=>h.id===oldId) ?? history[0];
      changes.clear(); offset=0; generation++; remember(); await renderResult();
      await refreshStorage(true);
    }
  });
}

async function checkRuntime(rscript = null) {
  const status = await invoke("quant_status", { rscript });
  ready = status.ready;
  $("engine-title").textContent = ready ? `QUANT ${status.catalog.version} · Ready` : "One-time R setup needed";
  $("engine-detail").textContent = status.message || `${status.rVersion} · ${status.rscript}`;
  $("setup").textContent = ready ? "Repair R dependencies" : "Set up R dependencies";
  $("engine-indicator").classList.toggle("ready", ready);
  $("engine-settings").open = !ready;
  if (ready) {
    catalog = status.catalog.operations;
    renderStages(); chooseOperation(selected?.id || "import_data_mrmhub");
    await renderResult();
  }
}
function saveLegacyDraft() {
  legacyDrafts[legacyStep] = legacyEditor.getValue();
  if (!path) return;
  try { localStorage.setItem(legacyDraftKey(path), JSON.stringify(legacyDrafts)); }
  catch { $("error").textContent = "Could not save code drafts locally. Copy your code before closing the app."; }
}
function loadLegacyDrafts() {
  legacyDrafts = {}; legacyStep = 0;
  try {
    const saved = JSON.parse(localStorage.getItem(legacyDraftKey(path)) || "{}");
    if (saved && typeof saved === "object" && !Array.isArray(saved)) legacyDrafts = saved;
  } catch { /* Keep the editor usable when stored drafts are unavailable. */ }
  chooseLegacyStep(0);
}
function chooseLegacyStep(index) {
  legacyStep = index;
  $("legacy-title").textContent = legacySteps[index];
  $("legacy-phase").textContent = legacyGroups.find(group => index >= group.start && index <= group.end)?.label ?? "Legacy workflow";
  $("legacy-position").textContent = `${index + 1} / ${legacySteps.length}`;
  legacyEditor.setValue(typeof legacyDrafts[index] === "string" ? legacyDrafts[index] : "", true);
  $("legacy-import").classList.toggle("hidden", index !== 1);
  updatePasteNote();
  root.querySelectorAll("[data-legacy-step]").forEach(button => {
    const active = Number(button.dataset.legacyStep) === index;
    button.classList.toggle("active", active); button.setAttribute("aria-current", active ? "step" : "false");
  });
  filterNavigation();
  updateRun();
}
async function switchMode(next) {
  if (mode === next) return;
  await task("Loading workflow…", async () => {
    if (!await discardWarning()) return;
    mode = next; offset = 0; generation++; current = undefined; history = [];
    legacyEditor.close();
    const legacy = mode === "legacy";
    $("guided-tab").setAttribute("aria-selected", String(!legacy));
    $("legacy-tab").setAttribute("aria-selected", String(legacy));
    $("guided-tab").tabIndex = legacy ? -1 : 0; $("legacy-tab").tabIndex = legacy ? 0 : -1;
    $("guided-editor").classList.toggle("hidden", legacy);
    $("legacy-editor").classList.toggle("hidden", !legacy);
    $("stages").classList.toggle("hidden", legacy);
    $("legacy-stages").classList.toggle("hidden", !legacy);
    $("stage-help").textContent = legacy ? "The original tutorial, grouped for easy navigation. Skip or revisit any step." : "Choose what your assay needs. Optional steps stay optional.";
    $("nav-title").textContent = legacy ? "Tutorial steps" : "Workflow";
    $("mode-description").textContent = legacy ? "Write R code, one step at a time." : "Choose operations and adjust their settings.";
    $("search").placeholder = legacy ? "Find a tutorial step…" : "Find an operation…";
    $("search").value = ""; filterNavigation();
    $("legacy-new").classList.toggle("hidden", !legacy);
    $("save-edits").classList.toggle("hidden", legacy);
    $("discard").classList.toggle("hidden", legacy);
    if (native && path) allHistory = await invoke("quant_history", { project: path });
    history = historyForMode(allHistory, mode);
    let remembered; try { remembered = localStorage.getItem(checkpointKey()); } catch { /* optional */ }
    current = remembered === "" ? undefined : history.find(h => h.id === remembered) ?? history[0];
    await renderResult();
    legacyEditor.refresh();
  });
}
function updatePasteNote() {
  const paste = inspectRPaste(legacyEditor.getValue());
  $("legacy-paste-note").textContent = paste.folderDiagram ? "This contains a folder-layout illustration, not executable R. Start with library(mrmhub), then import your dataset in step 2." : paste.changed ? "Run will automatically comment out recognized tutorial output and remove surrounding R code fences. Commands and paths stay unchanged; Undo restores the paste." : legacyStep === 1 ? "The tutorial’s sPerfect file is an example. Insert an import for this dataset, or change the path to your own results file." : "R syntax highlighting · Ctrl/Cmd+F to find · Recognized tutorial output is cleaned automatically when you Run";
}
async function runLegacy() {
  if (busy || !ready || !path) return;
  const paste = inspectRPaste(legacyEditor.getValue());
  if (paste.folderDiagram) { $("error").textContent = "The pasted folder diagram is documentation, not R code. Run library(mrmhub), then use step 2 to import your dataset."; return; }
  if (!paste.executable) { $("error").textContent = "This paste contains only comments or example output. Paste the R commands above the output, then Run."; return; }
  await task("Running your R code in the background…", async () => {
    if (!legacyTrusted) {
      if (!await confirm("Run trusted R code?", "Legacy runs your code with your user account’s file and network access, like RStudio. It is not sandboxed. Only run code you trust. A failed block keeps the previous session but cannot undo file writes or other side effects.")) return;
      legacyTrusted = true;
    }
    if (paste.changed) {
      legacyEditor.setValue(paste.code); updatePasteNote();
      log(`Automatically cleaned pasted tutorial output: ${paste.outputLines} output line(s) commented${paste.fenced ? "; surrounding R code fence removed" : ""}. R commands unchanged.`);
    }
    saveLegacyDraft();
    const request = { action: "legacy", operation: `legacy-${legacyStep}`, code: legacyEditor.getValue(), checkpoint: current?.id ?? "", progressToken: crypto.randomUUID() };
    log(`Running Legacy step ${legacyStep + 1}: ${legacySteps[legacyStep]}…`);
    runProgress.start(request.progressToken);
    try { const result = await invoke("quant_execute", { project: path, request }); resultView = "plots"; await accept(result); }
    finally { runProgress.finish(); }
    log("R block completed. Session saved.");
  });
}
function renderStages() {
  $("stages").replaceChildren();
  for (const stage of [...new Set(catalog.map(o => o.stage))].sort()) {
    const box = make("details"); box.className = "q-nav-group"; box.open = stage.startsWith("1");
    const summary = make("summary"); summary.append(make("span", stage), make("small", String(catalog.filter(o => o.stage === stage).length))); box.append(summary);
    for (const op of catalog.filter(o => o.stage === stage)) {
      const button = make("button", op.label); button.type = "button"; button.dataset.operation = op.id;
      button.onclick = () => {
        chooseOperation(op.id);
        $("operation-title").scrollIntoView({ block: "nearest" });
      }; box.append(button);
    }
    $("stages").append(box);
  }
}
function filterNavigation() {
  const query = $("search").value;
  let visible = 0, total = 0;
  for (const [id, activeMode] of [["stages", "guided"], ["legacy-stages", "legacy"]]) {
    for (const group of $(id).children) {
      let matches = 0;
      for (const button of group.querySelectorAll("button")) {
        const show = matchesWorkflow(activeMode === mode ? query : "", button.textContent, button.dataset.operation ?? "", group.querySelector("summary").textContent);
        button.classList.toggle("hidden", !show); if (show) matches++;
        if (activeMode === mode) { total++; if (show) visible++; }
      }
      group.classList.toggle("hidden", !matches);
      group.open = !!(activeMode === mode && query.trim() && matches) || !!group.querySelector("button.active");
    }
  }
  $("search-clear").classList.toggle("hidden", !query);
  $("search-empty").classList.toggle("hidden", !query.trim() || visible > 0);
  $("nav-count").textContent = query.trim() ? `${visible} / ${total}` : String(total || "");
}
function stashForm() {
  if (!selected) return;
  const draft = {};
  for (const field of selected.fields) {
    const input = document.getElementById(`q-input-${field.name}`), check = document.getElementById(`q-enable-${field.name}`);
    if (input && check) draft[field.name] = { enabled: check.checked, text: input.value };
  }
  drafts.set(selected.id, draft);
}
function chooseOperation(id, preset) {
  if (!preset) stashForm();
  selected = catalog.find(o => o.id === id) ?? catalog[0];
  if (!selected) return;
  root.querySelectorAll("[data-operation]").forEach(button => {
    const active = button.dataset.operation === selected.id; button.classList.toggle("active", active);
    button.setAttribute("aria-current", active ? "step" : "false");
  });
  filterNavigation();
  $("operation-stage").textContent = selected.stage;
  $("operation-title").textContent = selected.label;
  $("operation-kind").textContent = selected.kind;
  $("note").textContent = selected.note || "Uses the bundled QUANT function with the settings below.";
  if (selected.id.startsWith("import_metadata_")) $("note").textContent += " Match analysis_id / feature_id to the imported results. For Dataset4's MSorganiser workbook the published workflow explicitly enables Allow metadata validation warnings and Exclude analyses without matching metadata. Review Activity and the matching summary; these options are not enabled automatically.";
  $("import").classList.toggle("hidden", selected.kind !== "import");
  $("fields").replaceChildren(); $("extra-fields").replaceChildren(); $("presets").replaceChildren();
  const exclusion = ["exclude_analyses", "exclude_features"].includes(selected.id);
  $("presets").classList.toggle("hidden", selected.id !== "filter_features_qc" && !exclusion && !selected.missingPackages?.length);
  if (exclusion) {
    const button = make("button", "Select IDs in the metadata table"); button.type = "button";
    button.onclick = () => task("Loading exclusion controls…", async () => {
      if (!await discardWarning()) return;
      table = selected.id === "exclude_analyses" ? "annot_analyses" : "annot_features"; offset = 0;
      $("table-choice").value = table; await showResults("data"); $("data-panel").scrollIntoView({block:"start"});
    }); $("presets").append(button);
  }
  if (selected.missingPackages?.length) {
    const packages = selected.missingPackages;
    $("note").textContent += ` Optional R dependencies needed: ${packages.join(", ")}. These are downloaded only if you choose to install them.`;
    const button = make("button", `Install ${packages.join(" + ")}…`); button.type = "button";
    button.onclick = async () => {
      if (!await confirm("Install optional R dependencies?", `Download ${packages.join(", ")} and their dependencies from CRAN/Bioconductor into the app-owned R library? This uses disk space and can take several minutes. System R libraries are not changed.`)) return;
      await task("Installing optional R dependencies…", async () => { await invoke("quant_setup", {packages}); await checkRuntime(); });
    }; $("presets").append(button);
  }
  if (selected.id === "filter_features_qc") {
    for (const [label, values] of [["Initial QC", { include_qualifier: false, include_istd: true, "min.intensity.median.spl": 200 }], ["Normalization QC", {include_qualifier:false, include_istd:true,"min.intensity.median.spl":1000}], ["Final tutorial QC", finalFilter]]) {
      const button = make("button", label); button.type = "button";
      button.onclick = () => chooseOperation(selected.id, values); $("presets").append(button);
    }
  }
  for (const field of selected.fields) {
    if (selected.kind === "plot" && field.name === "path") continue;
    const draft = preset ? { enabled: field.name in preset, text: displayValue(preset[field.name]) } : drafts.get(selected.id)?.[field.name];
    const box = make("div", null, "q-field");
    const heading = make("div", null, "q-field-heading");
    const toggle = make("input"); toggle.type = "checkbox"; toggle.id = `q-enable-${field.name}`;
    toggle.checked = field.required || (draft?.enabled ?? field.enabled); toggle.disabled = field.required;
    toggle.setAttribute("aria-label", `Use ${field.label}`);
    const label = make("label", field.label + (field.required ? " *" : "")); label.htmlFor = `q-input-${field.name}`;
    label.title = `${field.name} — R default: ${field.original || "required"}`; heading.append(toggle, label);
    const input = make(["boolean", "choice"].includes(field.type) ? "select" : field.type === "mapping" || field.lineSeparated ? "textarea" : "input"); input.id = `q-input-${field.name}`;
    if (field.type === "boolean") for (const value of [...(field.value == null && !field.required ? [""] : []), "true", "false"]) { const option = make("option", value === "" ? "Automatic / NA" : value === "true" ? "Yes" : "No"); option.value = value; input.append(option); }
    else if (field.type === "choice") for (const value of [...(!field.required ? [""] : []), ...field.choices]) { const option = make("option", value || "Automatic / NA"); option.value = value; input.append(option); }
    else { if (field.type !== "mapping") input.type = "text"; input.placeholder = field.required ? "Required" : `Default: ${field.original}`; }
    input.value = draft?.text ?? (field.lineSeparated && Array.isArray(field.value) ? field.value.join("\n") : displayValue(field.value));
    input.disabled = !toggle.checked; toggle.onchange = () => { input.disabled = !toggle.checked; };
    if (field.name === "path") {
      toggle.checked = true; input.disabled = false;
      const actions = make("div", null, "q-actions");
      const browse = make("button", "Choose file…"); browse.type = "button";
      browse.onclick = async () => {
        const file = await native.dialog.open({ multiple: false, title: selected.kind === "import" ? "Choose results file" : "Choose metadata file", filters: [{ name: "Data", extensions: ["csv", "tsv", "xlsx", "txt", "rds"] }] });
        if (file) input.value = file;
      };
      actions.append(browse);
      if (selected.id === "import_data_mrmhub") {
        const use = make("button", "Use this dataset’s long.csv"); use.type = "button";
        use.onclick = () => { input.value = `${path}/long.csv`; }; actions.append(use);
        if (!input.value && path) input.value = `${path}/long.csv`;
      }
      box.append(heading, input, actions);
    } else box.append(heading, input);
    if (field.vector) box.append(make("small", field.lineSeparated ? "One ID / pattern per line, or a JSON list. Commas inside IDs and patterns are preserved." : "Comma-separated values, or a JSON list", "q-help"));
    const primary = field.required || toggle.checked || ["path", "sheet", "qc_types", "ref_qc_types", "variable", "include_feature_filter", "exclude_feature_filter", "ignore_warnings", "excl_unmatched_analyses", "fit_model", "fit_weighting", "column_mapping"].includes(field.name);
    $(primary ? "fields" : "extra-fields").append(box);
  }
  $("advanced-count").textContent = `(${ $("extra-fields").children.length })`;
  $("advanced").classList.toggle("hidden", !$("extra-fields").children.length);
  $("run").textContent = selected.kind === "plot" ? "Generate graph" : selected.kind === "export" ? "Generate export" : "Run operation";
  updateRun();
}
async function discardWarning() {
  if (!changes.size) return true;
  if (!await confirm("Discard unsaved metadata edits?", "Save your metadata changes first to include them in processing, or discard them to continue.")) return false;
  changes.clear(); return true;
}
async function run() {
  await task("Running QUANT in the background…", async () => {
    if (!await discardWarning()) return;
    if (selected.kind === "import" && current && !await confirm("Start a new import?", "After a successful import this replaces the current Guided session snapshot. Earlier graphs and exports are kept. Save an RDS archive first if you need to resume the current session later.")) return;
    const parameters = {};
    for (const field of selected.fields) {
      const toggle = document.getElementById(`q-enable-${field.name}`), input = document.getElementById(`q-input-${field.name}`);
      if (toggle?.checked) parameters[field.name] = parameterValue(field, input.value);
    }
    const request = { action: "run", operation: selected.id, parameters, checkpoint: selected.kind === "import" ? "" : current?.id ?? "", title: $("title").value.trim() || "Experiment", analysisType: $("analysis-type").value };
    log(`Running ${selected.label}…`);
    const result = await invoke("quant_execute", { project: path, request });
    resultView = resultViewForOperation(selected.kind);
    await accept(result); log(`${selected.label} completed. Checkpoint saved.`);
  });
}
function remember() { try { localStorage.setItem(checkpointKey(), current?.id ?? ""); } catch { /* optional */ } }
async function accept(result) {
  current = result;
  allHistory = await invoke("quant_history", {project:path}); history = historyForMode(allHistory, mode);
  remember(); changes.clear(); offset = 0;
  await renderResult();
  await refreshStorage(true);
}
function renderHistory() {
  $("checkpoint").replaceChildren();
  if (!current) { const empty = make("option", mode === "legacy" ? "New R session" : "No analysis yet"); empty.value = ""; $("checkpoint").append(empty); }
  for (const h of history) {
    const option = make("option", `${new Date(h.created).toLocaleString()} · ${opName(h.operation)}`); option.value = h.id;
    option.selected = current?.id === h.id; $("checkpoint").append(option);
  }
}
async function renderResult() {
  loadedTableKey = ""; selectedRows.clear();
  renderHistory();
  $("summary").textContent = current ? `${current.title} · ${current.samples} samples · ${current.features} features · ${current.normalized ? "ISTD normalized" : "Not normalized"} · ${current.quantitated ? "Quantitated" : "Not quantitated"} · ${current.filtered ? "QC filtered" : "Not filtered"}` : "Import results to begin. All analysis stays local to this dataset.";
  if (mode === "legacy") $("summary").textContent = current ? `Saved R objects: ${[].concat(current.objects ?? []).join(", ") || "none"}. Working directory: ${current.workingDirectory}` : "New Legacy session. Paste library(mrmhub) or your import code to begin. Guided checkpoints are separate.";
  $("metadata-coverage").textContent = metadataCoverageText(current?.metadataCoverage);
  $("table-choice").replaceChildren();
  const tables = current?.tables ?? [];
  if (!tables.some(t => t.name === table)) table = tables.find(t => t.name === "dataset")?.name ?? tables[0]?.name ?? "dataset";
  for (const t of tables) {
    const option = make("option", `${t.name.replaceAll("_", " ")} (${t.rows.toLocaleString()})${t.editable ? " · editable" : ""}`); option.value = t.name; option.selected = table === t.name; $("table-choice").append(option);
  }
  const previousGraph = $("plot-choice").value;
  graphs = savedGraphs(allHistory);
  $("plot-choice").replaceChildren(); $("files").replaceChildren(); $("plot").replaceChildren();
  const groups = new Map();
  for (const graph of graphs) {
    if (!groups.has(graph.id)) {
      const group = make("optgroup"); group.label = `${graph.mode} · ${opName(graph.operation)} · ${new Date(graph.created).toLocaleString()}`;
      groups.set(graph.id, group); $("plot-choice").append(group);
    }
    const option = make("option", graph.name); option.value = graph.key; groups.get(graph.id).append(option);
  }
  $("plot-choice").value = chooseGraph(graphs, current?.id, previousGraph);
  $("plot-choice").disabled = !graphs.length;
  $("save-plot").disabled = !graphs.length;
  for (const a of current?.artifacts ?? []) {
    const button = make("button", `Save ${a.name}…`); button.type = "button";
    button.onclick = () => task("Saving output…", async () => {
      const destination = await native.dialog.save({ defaultPath: a.name, title: "Save QUANT output" });
      if (destination) await invoke("quant_save_artifact", { project: path, id: current.id, name: a.name, destination });
    }); $("files").append(button);
  }
  $("output-path").textContent = current ? `Saved in ${current.directory}. ${mode === "legacy" ? "workspace.rds preserves your R objects; code.R records the executed code. Explicit export paths are respected; use output_dir to collect exports here." : "RDS preserves the full-precision experiment; request.json and session-info.txt record the settings and R environment."}` : "Graphs and exports appear here after their operation completes.";
  renderTable(null);
  await showResults(resultView); updateRun();
}
async function showResults(view) {
  resultView = view;
  for (const key of ["plots", "data"]) {
    $(`${key}-panel`).classList.toggle("hidden", view !== key);
    $(`${key}-tab`).setAttribute("aria-selected", String(view === key));
    $(`${key}-tab`).tabIndex = view === key ? 0 : -1;
  }
  // Never deserialize an entire R experiment merely to display its graph.
  if (view === "data") {
    const key = `${current?.id}:${table}:${offset}:${mode}`;
    if (ready && current?.tables?.length && loadedTableKey !== key) await loadTable();
  } else if (!$("plot").children.length) await loadPlot();
}
async function loadPlot() {
  const graph = graphs.find(g => g.key === $("plot-choice").value); $("plot").replaceChildren();
  if (!graph) {
    const empty = make("div", null, "q-empty-results");
    empty.append(make("h3", "Your plots will appear here"), make("p", "Generate a graph in either workflow. Saved plots from every step stay available in the selector above."));
    $("plot").append(empty); return;
  }
  const project = path;
  const image = make("img"); image.alt = `${graph.mode} · ${opName(graph.operation)} — ${graph.name}`;
  image.src = await invoke("quant_image", { project, id: graph.id, name: graph.name });
  if (project !== path || graph.key !== $("plot-choice").value) return;
  const button = make("button", null, "q-plot-open"); button.type = "button";
  button.setAttribute("aria-label", `Enlarge ${image.alt}`);
  button.title = "Open full-resolution plot · Zoom and pan";
  button.append(image); button.onclick = () => plotViewer.open(image.src, image.alt);
  $("plot").append(button, make("p", `${graph.mode} · ${opName(graph.operation)} · ${new Date(graph.created).toLocaleString()}. Click to enlarge, zoom and pan.`, "q-help"));
}
async function loadTable() {
  if (!current) return renderTable(null);
  const token = generation;
  const result = await invoke("quant_execute", { project: path, request: { action: "table", checkpoint: current.id, table, offset, limit: 50 } });
  if (token === generation) { changes.clear(); loadedTableKey = `${current?.id}:${table}:${offset}:${mode}`; renderTable(mode === "legacy" ? { ...result, editable: false } : result); }
}
function renderTable(data) {
  page = data; $("table").replaceChildren();
  selectedRows.clear(); $("selected-count").textContent = ""; $("exclude-rows").disabled = true;
  const idColumn = table === "annot_analyses" ? "analysis_id" : table === "annot_features" ? "feature_id" : null;
  const canExclude = !!data && mode === "guided" && !!idColumn;
  $("exclusions").classList.toggle("hidden", !canExclude);
  $("prev").disabled = !data || offset === 0; $("next").disabled = !data || offset + 50 >= data.total;
  $("page").textContent = data ? `${data.total ? offset + 1 : 0}–${Math.min(offset + 50, data.total)} of ${data.total.toLocaleString()}` : "";
  $("save-edits").disabled = true; $("discard").disabled = true;
  $("table-note").textContent = data?.editable ? "Edit cells, then save to validate with QUANT’s original metadata importer. Clear a cell to mark it missing. Metadata edits reset downstream processing; rerun those steps afterwards. Import a table/workbook to add columns or rows." : "Read-only measurements / results. Edit annotations using the metadata tables; imported measurements remain unchanged.";
  if (mode === "legacy") $("table-note").textContent = data ? "Read-only preview of mexp. Make changes using your R code above." : "Create or import an MRMhubExperiment named mexp to browse its tables here. Other printed results appear in Activity.";
  if (!data) return;
  const grid = make("table"), head = make("thead"), tr = make("tr"), body = make("tbody");
  if (canExclude) tr.append(make("th", "Select"));
  for (const name of data.columns) { const cell = make("th", name); cell.scope = "col"; tr.append(cell); }
  head.append(tr); grid.append(head, body);
  for (const [i, row] of data.rows.entries()) {
    const line = make("tr");
    if (canExclude) {
      const cell = make("td"), check = make("input"); check.type = "checkbox";
      check.setAttribute("aria-label", `Select ${row[idColumn]}`);
      check.onchange = () => {
        if (check.checked) selectedRows.add(row[idColumn]); else selectedRows.delete(row[idColumn]);
        $("selected-count").textContent = `${selectedRows.size} selected on this page`;
        $("exclude-rows").disabled = !selectedRows.size;
      }; cell.append(check); line.append(cell);
    }
    for (const col of data.columns) {
      const cell = make("td");
      if (data.editable) {
        const logical = data.types?.[col] === "logical";
        const input = make(logical ? "select" : "input");
        if (logical) for (const value of ["", "true", "false"]) { const option = make("option", value === "" ? "NA" : value === "true" ? "Yes" : "No"); option.value = value; input.append(option); }
        else { input.type = "text"; input.placeholder = "NA"; }
        input.value = displayValue(row[col]);
        input.setAttribute("aria-label", `${col}, row ${offset + i + 1}`);
        const changed = () => {
          const key = `${offset + i}:${col}`;
          if (input.value === displayValue(row[col])) changes.delete(key);
          else changes.set(key, { row: offset + i, column: col, value: input.value === "" ? null : input.value });
          input.classList.toggle("q-changed", changes.has(key));
          $("save-edits").disabled = !changes.size; $("discard").disabled = !changes.size;
        }; input.oninput = changed; input.onchange = changed; cell.append(input);
      } else cell.textContent = displayValue(row[col]) || "—";
      line.append(cell);
    }
    body.append(line);
  }
  $("table").append(grid);
}
async function excludeRows(restore) {
  if (mode !== "guided" || !current || !["annot_analyses", "annot_features"].includes(table)) return;
  const analyses = table === "annot_analyses", ids = [...selectedRows];
  if (!restore && !ids.length) return;
  const warning = "This uses QUANT’s original exclusion function. Original measurements stay intact. Normalization, quantitation and other downstream processing must be rerun. " + (restore ? "This marks every row in this metadata table valid, including rows originally imported as invalid." : "Existing exclusions are kept.");
  if (!await confirm(restore ? "Restore all exclusions?" : `Exclude ${ids.length} selected ${analyses ? "analyses" : "features"}?`, warning)) return;
  await task("Updating exclusions…", async () => {
    if (!await discardWarning()) return;
    const parameters = {[analyses ? "analyses" : "features"]: restore ? [null] : ids, clear_existing: restore};
    await accept(await invoke("quant_execute", {project:path, request:{action:"run", operation:analyses ? "exclude_analyses" : "exclude_features", checkpoint:current.id, parameters}}));
  });
}
async function navigateTable(delta) {
  await task("Loading table…", async () => {
    if (!await discardWarning()) return;
    offset = Math.max(0, offset + delta); await loadTable();
  });
}
async function saveEdits() {
  if (!changes.size) return;
  if (!await confirm("Save metadata and reset downstream processing?", "QUANT will revalidate and relink the annotations. Rerun normalization, quantitation, corrections, and filtering afterwards. On success this replaces the previous session snapshot; saved outputs are kept.")) return;
  await task("Validating metadata…", async () => {
    const result = await invoke("quant_execute", { project: path, request: { action: "edit", checkpoint: current.id, table, changes: [...changes.values()] } });
    await accept(result);
  });
}
