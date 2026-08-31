const tauri = window.__TAURI__;
const isDesktop = Boolean(tauri?.core?.invoke);
const invoke = isDesktop ? tauri.core.invoke : null;
const isWindows = /^Win/i.test(navigator.platform) || /Windows/i.test(navigator.userAgent);
const scratchpadAutoWipePreference = "mrmhub-scratchpad-auto-wipe";
const guiScalePreference = "mrmhub-gui-scale";
const legacyVisualizerScalePreference = "mrmhub-visualizer-font-scale";
const guiScaleOptions = [100, 125, 150, 175, 200];
document.documentElement.classList.toggle("platform-windows", isWindows);

const elements = {
  projectTitle: document.querySelector("#project-title"),
  projectPath: document.querySelector("#project-path"),
  sampleCount: document.querySelector("#sample-count"),
  transitionFile: document.querySelector("#transition-file"),
  projectNotice: document.querySelector("#project-notice"),
  projectIssues: document.querySelector("#project-issues"),
  projectModal: document.querySelector("#project-modal"),
  modalMessage: document.querySelector("#modal-message"),
  missingFilesModal: document.querySelector("#missing-files-modal"),
  missingFilesList: document.querySelector("#missing-files-list"),
  missingParamNote: document.querySelector("#missing-param-note"),
  missingFilesCancel: document.querySelector("#missing-files-cancel"),
  missingFilesCreate: document.querySelector("#missing-files-create"),
  dataEditorModal: document.querySelector("#data-editor-modal"),
  dataEditorFiles: document.querySelector("#data-editor-files"),
  dataEditorCurrent: document.querySelector("#data-editor-current"),
  dataEditorStatus: document.querySelector("#data-editor-status"),
  dataEditorBackups: document.querySelector("#data-editor-backups"),
  dataEditorRestore: document.querySelector("#data-editor-restore"),
  dataEditorRename: document.querySelector("#data-editor-rename"),
  dataEditorDelete: document.querySelector("#data-editor-delete"),
  dataEditorRefresh: document.querySelector("#data-editor-refresh"),
  dataEditorSave: document.querySelector("#data-editor-save"),
  dataEditorClose: document.querySelector("#data-editor-close"),
  dataEditorTableActions: document.querySelector("#data-editor-table-actions"),
  dataEditorAddRow: document.querySelector("#data-editor-add-row"),
  dataEditorAddColumn: document.querySelector("#data-editor-add-column"),
  dataEditorBody: document.querySelector("#data-editor-body"),
  activityLog: document.querySelector("#activity-log"),
  toastRegion: document.querySelector("#toast-region"),
  chooseButtons: [
    document.querySelector("#choose-project"),
    document.querySelector("#modal-choose-project"),
  ],
  editDataButton: document.querySelector("#edit-data"),
  promptModal: document.querySelector("#prompt-modal"),
  promptModalTitle: document.querySelector("#prompt-modal-title"),
  promptModalMessage: document.querySelector("#prompt-modal-message"),
  promptModalInput: document.querySelector("#prompt-modal-input"),
  promptModalOk: document.querySelector("#prompt-modal-ok"),
  promptModalCancel: document.querySelector("#prompt-modal-cancel"),
  themeToggle: document.querySelector("#theme-toggle"),
  guiScale: document.querySelector("#gui-scale"),
  clearActivity: document.querySelector("#clear-activity"),
  visualizerButton: document.querySelector("#open-visualizer"),
  scratchpadButton: document.querySelector("#open-scratchpad"),
  integratorTab: document.querySelector("#integrator-tab"),
  visualizerTab: document.querySelector("#visualizer-tab"),
  scratchpadTab: document.querySelector("#scratchpad-tab"),
  integratorView: document.querySelector("#integrator-view"),
  visualizerView: document.querySelector("#visualizer-view"),
  scratchpadView: document.querySelector("#scratchpad-view"),
  scratchpadAutoWipe: document.querySelector("#scratchpad-auto-wipe"),
  scratchpadAutoPanel: document.querySelector("#scratchpad-auto-panel"),
  scratchpadSavedPanel: document.querySelector("#scratchpad-saved-panel"),
  scratchpadNotes: document.querySelector("#scratchpad-notes"),
  scratchpadSavedNotes: document.querySelector("#scratchpad-saved-notes"),
  scratchpadTitle: document.querySelector("#scratchpad-title"),
  scratchpadIncludeDate: document.querySelector("#scratchpad-include-date"),
  scratchpadPin: document.querySelector("#scratchpad-pin"),
  scratchpadRefreshNote: document.querySelector("#scratchpad-refresh-note"),
  scratchpadDeleteNote: document.querySelector("#scratchpad-delete-note"),
  scratchpadSaveNote: document.querySelector("#scratchpad-save-note"),
  scratchpadNewNote: document.querySelector("#scratchpad-new-note"),
  scratchpadNoteList: document.querySelector("#scratchpad-note-list"),
  visualizerDataset: document.querySelector("#visualizer-dataset"),
  visualizerStatus: document.querySelector("#visualizer-status"),
  externalSlingLinks: [...document.querySelectorAll(".external-sling-link")],
  stepCards: [...document.querySelectorAll("[data-step]")],
};

let project = null;
let activeStep = null;
let visualizerModule = null;
let guiScalePercent = 100;
let pendingSetup = null;
let scratchpadLoaded = false;
const scratchpad = {
  notes: [],
  current: null,
  dirty: false,
  pinnedDraft: false,
};
const dataEditor = {
  files: [],
  current: null,
  content: null,
  viewingBackup: "",
  dirty: false,
};
const completedThisSession = new Set();
const pendingStepProgress = new Map();
let stepProgressFrame = null;
const stepProgressMessages = {
  1: "Preparing validation…",
  2: "Preparing peak detection…",
  3: "Updating integration bounds and areas…",
  4: "Generating chromatogram reports…",
};

const mockProject = {
  name: "MRMhub-Dataset1",
  path: "C:\\Users\\arthur\\Documents\\GitHub\\MRMhub\\MRMhub-Dataset1",
  sampleCount: 937,
  transitionFile: "transition_list_20251009_withRTerrors.csv",
  workerName: "MRMhub-integrator-optimized.exe",
  issues: [],
  outputs: {
    validated: true,
    detected: true,
    integrated: true,
    plotted: false,
  },
  canRun: true,
};

function outputForStep(step) {
  if (!project) return false;
  return {
    1: project.outputs.validated,
    2: project.outputs.detected,
    3: project.outputs.integrated,
    4: project.outputs.plotted,
  }[step];
}

function prerequisiteForStep(step) {
  if (!project?.canRun) return false;
  if (step === 1) return true;
  if (step === 2) return project.outputs.validated;
  if (step === 3) return project.outputs.detected;
  return project.outputs.integrated;
}

function prerequisiteMessage(step) {
  if (!project) return "Select a dataset before running an integration step.";
  if (!project.canRun) {
    return "This dataset needs attention before processing can begin.";
  }
  if (step === 2 && !project.outputs.validated) {
    return "Run step 1, Validate data, before detecting peaks.";
  }
  if (step === 3 && !project.outputs.detected) {
    return "Run step 2, Detect peaks, before integrating peaks.";
  }
  if (step === 4 && !project.outputs.integrated) {
    return "Run step 3, Integrate peaks, before generating reports.";
  }
  return null;
}

function setStepStatus(step, status) {
  const card = elements.stepCards.find(
    (candidate) => Number(candidate.dataset.step) === step,
  );
  if (!card) return;
  card.classList.remove("complete", "already-complete", "running", "failed");
  if (status !== "waiting") card.classList.add(status);
  const badge = card.querySelector(".step-status");
  badge.className = "step-status";
  badge.classList.add(status === "optional" ? "optional-label" : status);
  badge.textContent =
    status === "already-complete" ? "already complete" : status;
}

function stepCard(step) {
  return elements.stepCards.find(
    (candidate) => Number(candidate.dataset.step) === step,
  );
}

// Replaces the normal output label with an in-card progress display while a
// workflow step is active. Steps without numeric worker progress remain
// animated instead of displaying a made-up percentage.
function beginStepProgress(step) {
  const card = stepCard(step);
  const progress = card?.querySelector("[data-step-progress]");
  if (!progress) return;
  card.classList.add("progress-active");
  progress.classList.remove("hidden");
  progress.classList.add("indeterminate");
  progress.removeAttribute("aria-valuenow");
  progress.querySelector("div span").style.width = "";
  progress.querySelector("small").textContent =
    stepProgressMessages[step] ?? "Working…";
}

function resetStepProgress(step) {
  const card = stepCard(step);
  const progress = card?.querySelector("[data-step-progress]");
  if (!progress) return;
  card.classList.remove("progress-active");
  progress.classList.add("hidden", "indeterminate");
  progress.removeAttribute("aria-valuenow");
  progress.querySelector("div span").style.width = "";
  progress.querySelector("small").textContent =
    stepProgressMessages[step] ?? "Preparing…";
  if (isWindows) pendingStepProgress.delete(step);
}

function resetAllStepProgress() {
  for (const card of elements.stepCards) {
    resetStepProgress(Number(card.dataset.step));
  }
}

// Worker output remains live status text on every platform. On Windows, exact
// current/total reports use a determinate width because WebView2 can restart a
// transform animation whenever frequent native events arrive.
function updateStepProgress(step, rawLine) {
  const progress = stepCard(step)?.querySelector("[data-step-progress]");
  if (!progress || progress.classList.contains("hidden")) return;
  const line = String(rawLine)
    .replace(/\x1b\[[0-?]*[ -/]*[@-~]/g, "")
    .trim();
  if (!line) return;
  const reported = line.match(/^Progress:\s*(\d+)\s*\/\s*(\d+)\s*-\s*(.+)$/);
  const legacy = reported ? null : line.match(/^(\d+)\s*\/\s*(\d+)$/);
  const numeric = reported ?? legacy;
  if (numeric && Number(numeric[2]) > 0) {
    const current = Number(numeric[1]);
    const total = Number(numeric[2]);
    if (isWindows) {
      const percentage = Math.min(100, Math.max(6, current / total * 100));
      progress.classList.remove("indeterminate");
      progress.setAttribute("aria-valuemin", "0");
      progress.setAttribute("aria-valuemax", String(total));
      progress.setAttribute("aria-valuenow", String(current));
      progress.querySelector("div span").style.width = `${percentage}%`;
    }
    const detail = reported?.[3] ?? "Validating data";
    progress.querySelector("small").textContent =
      `${current.toLocaleString()}/${total.toLocaleString()} · ${detail}`;
    return;
  }
  progress.querySelector("small").textContent = line;
}

// Coalesce bursts from the native worker into at most one Windows WebView2
// update per browser frame. macOS keeps its existing immediate update path.
function queueStepProgress(step, rawLine) {
  pendingStepProgress.set(step, rawLine);
  if (stepProgressFrame !== null) return;
  stepProgressFrame = requestAnimationFrame(() => {
    for (const [pendingStep, pendingLine] of pendingStepProgress) {
      updateStepProgress(pendingStep, pendingLine);
    }
    pendingStepProgress.clear();
    stepProgressFrame = null;
  });
}

function updateWorkflow() {
  for (const card of elements.stepCards) {
    const step = Number(card.dataset.step);
    if (activeStep === step) {
      setStepStatus(step, "running");
    } else if (step === 4) {
      setStepStatus(step, "optional");
    } else if (outputForStep(step)) {
      setStepStatus(
        step,
        completedThisSession.has(step) ? "complete" : "already-complete",
      );
    } else {
      setStepStatus(step, "waiting");
    }
  }
  for (const card of elements.stepCards) {
    const step = Number(card.dataset.step);
    const actionable = activeStep === null && prerequisiteForStep(step);
    card.classList.toggle("actionable", actionable);
    card.classList.toggle("locked", !actionable && activeStep !== step);
    card.setAttribute("aria-disabled", String(activeStep !== null));
    card.tabIndex = activeStep === null ? 0 : -1;
    const indicator = card.querySelector(".card-run-indicator");
    if (indicator) {
      indicator.firstChild.textContent =
        activeStep === step ? "Working " : "Run ";
    }
  }
}

function renderProject(summary) {
  if (project && project.path !== summary.path) {
    completedThisSession.clear();
    resetAllStepProgress();
    // invalidate cached per-project UI so a new dataset never shows the old
    // dataset's graphs or backup versions
    visualizerModule?.resetVisualizer?.();
    dataEditor.files = [];
    dataEditor.current = null;
    dataEditor.content = null;
    dataEditor.viewingBackup = "";
    dataEditor.dirty = false;
  }
  project = summary;
  elements.projectTitle.textContent = summary.name;
  elements.projectPath.textContent = summary.path;
  elements.sampleCount.textContent = summary.sampleCount.toLocaleString();
  elements.transitionFile.textContent = summary.transitionFile ?? "not found";

  elements.projectIssues.replaceChildren();
  if (summary.issues.length) {
    for (const issue of summary.issues) {
      const item = document.createElement("li");
      item.textContent = issue;
      elements.projectIssues.append(item);
    }
    elements.projectNotice.classList.remove("hidden");
  } else {
    elements.projectNotice.classList.add("hidden");
  }
  elements.projectModal.classList.add("hidden");
  updateWorkflow();
}

function addActivity(message, kind = "") {
  const empty = elements.activityLog.querySelector(".empty-log");
  if (empty) empty.remove();
  const row = document.createElement("p");
  row.className = kind;
  const timestamp = new Date().toLocaleTimeString([], {
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
  });
  row.textContent = `${timestamp}  ${message}`;
  elements.activityLog.append(row);
  elements.activityLog.scrollTop = elements.activityLog.scrollHeight;
}

function showToast(message, kind = "") {
  const toast = document.createElement("div");
  toast.className = `toast ${kind}`.trim();
  toast.textContent = message;
  elements.toastRegion.append(toast);
  window.setTimeout(() => toast.remove(), 4200);
}

// in-app text prompt used instead of window.prompt(), which is not implemented
// in the macOS webview (WKWebView) and silently returns null there. Resolves to
// the entered string, or null if cancelled.
function appPrompt(message, defaultValue = "", title = "Rename") {
  return new Promise((resolve) => {
    const { promptModal, promptModalInput, promptModalOk, promptModalCancel } =
      elements;
    elements.promptModalTitle.textContent = title;
    elements.promptModalMessage.textContent = message;
    promptModalInput.value = defaultValue ?? "";
    promptModal.classList.remove("hidden");
    promptModalInput.focus();
    promptModalInput.select();

    const finish = (value) => {
      promptModal.classList.add("hidden");
      promptModalOk.removeEventListener("click", onOk);
      promptModalCancel.removeEventListener("click", onCancel);
      promptModalInput.removeEventListener("keydown", onKey);
      resolve(value);
    };
    const onOk = () => finish(promptModalInput.value);
    const onCancel = () => finish(null);
    const onKey = (event) => {
      if (event.key === "Enter") {
        event.preventDefault();
        onOk();
      } else if (event.key === "Escape") {
        event.preventDefault();
        onCancel();
      }
    };
    promptModalOk.addEventListener("click", onOk);
    promptModalCancel.addEventListener("click", onCancel);
    promptModalInput.addEventListener("keydown", onKey);
  });
}

// in-app confirmation prompt used for actions that should never silently
// continue if the platform webview suppresses native confirm dialogs.
function appConfirm(
  message,
  title = "Confirm",
  okText = "OK",
  cancelText = "Cancel",
) {
  return new Promise((resolve) => {
    const { promptModal, promptModalInput, promptModalOk, promptModalCancel } =
      elements;
    const previousOkText = promptModalOk.textContent;
    const previousCancelText = promptModalCancel.textContent;
    elements.promptModalTitle.textContent = title;
    elements.promptModalMessage.textContent = message;
    promptModalInput.classList.add("hidden");
    promptModalInput.value = "";
    promptModalOk.textContent = okText;
    promptModalCancel.textContent = cancelText;
    promptModal.classList.remove("hidden");
    promptModalOk.focus();

    const finish = (value) => {
      promptModal.classList.add("hidden");
      promptModalInput.classList.remove("hidden");
      promptModalOk.textContent = previousOkText;
      promptModalCancel.textContent = previousCancelText;
      promptModalOk.removeEventListener("click", onOk);
      promptModalCancel.removeEventListener("click", onCancel);
      document.removeEventListener("keydown", onKey);
      resolve(value);
    };
    const onOk = () => finish(true);
    const onCancel = () => finish(false);
    const onKey = (event) => {
      if (event.key === "Enter") {
        event.preventDefault();
        onOk();
      } else if (event.key === "Escape") {
        event.preventDefault();
        onCancel();
      }
    };
    promptModalOk.addEventListener("click", onOk);
    promptModalCancel.addEventListener("click", onCancel);
    document.addEventListener("keydown", onKey);
  });
}

// formats saved note timestamps for compact note-list display
function formatNoteDate(timestamp) {
  return new Date(timestamp).toLocaleString([], {
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
  });
}

// combines the note title with its creation timestamp when requested
function noteDisplayTitle(note) {
  if (!note) return "Untitled note";
  return note.includeTimestamp
    ? `${note.title} - ${formatNoteDate(note.createdAt)}`
    : note.title;
}

// updates saved-note buttons for current note and dirty state
function updateScratchpadActions() {
  const hasCurrent = Boolean(scratchpad.current?.id);
  elements.scratchpadPin.textContent = scratchpad.pinnedDraft ? "Unpin" : "Pin";
  elements.scratchpadPin.classList.toggle("active", scratchpad.pinnedDraft);
  elements.scratchpadDeleteNote.disabled = !hasCurrent;
  elements.scratchpadRefreshNote.disabled = !hasCurrent && !scratchpad.dirty;
  elements.scratchpadSaveNote.disabled = !scratchpad.dirty;
}

// marks the open saved note as edited and refreshes the note-list asterisk
function markScratchpadDirty() {
  scratchpad.dirty = true;
  renderScratchpadList();
  updateScratchpadActions();
}

// protects saved-note edits from accidental note switches
function confirmScratchpadDiscard() {
  return (
    !scratchpad.dirty ||
    window.confirm("Discard unsaved changes to the current scratchpad note?")
  );
}

// renders saved note metadata in pinned-first chronological order
function renderScratchpadList() {
  elements.scratchpadNoteList.replaceChildren();
  if (!scratchpad.notes.length) {
    const empty = document.createElement("p");
    empty.className = "empty-notes";
    empty.textContent = "No saved notes yet.";
    elements.scratchpadNoteList.append(empty);
    return;
  }
  for (const note of scratchpad.notes) {
    const button = document.createElement("button");
    button.type = "button";
    button.className = "scratchpad-note-item";
    if (scratchpad.current?.id === note.id) button.classList.add("active");
    const dirty = scratchpad.current?.id === note.id && scratchpad.dirty;
    const title = document.createElement("strong");
    title.textContent = `${dirty ? "* " : ""}${noteDisplayTitle(note)}`;
    const meta = document.createElement("span");
    meta.textContent = `${note.pinned ? "Pinned - " : ""}${formatNoteDate(note.createdAt)}`;
    button.append(title, meta);
    button.addEventListener("click", () => openScratchpadNote(note.id));
    elements.scratchpadNoteList.append(button);
  }
}

// clears the saved-note editor into the default new-note screen
function showNewScratchpadNote(options = {}) {
  if (!options.force && !confirmScratchpadDiscard()) return;
  scratchpad.current = null;
  scratchpad.dirty = false;
  scratchpad.pinnedDraft = false;
  elements.scratchpadTitle.value = "";
  elements.scratchpadIncludeDate.checked = true;
  elements.scratchpadSavedNotes.value = "";
  elements.scratchpadSavedNotes.placeholder = "Write a new saved note...";
  renderScratchpadList();
  updateScratchpadActions();
}

// loads the saved-note list from disk
async function loadScratchpadNotes() {
  if (!isDesktop) {
    renderScratchpadList();
    scratchpadLoaded = true;
    return;
  }
  try {
    scratchpad.notes = await invoke("scratchpad_list_notes");
    renderScratchpadList();
    scratchpadLoaded = true;
  } catch (error) {
    showToast(`Could not load scratchpad notes: ${String(error)}`, "error");
  }
}

// opens one saved note and loads its text body
async function openScratchpadNote(id, options = {}) {
  if (!isDesktop) return;
  if (!options.force && !confirmScratchpadDiscard()) return;
  try {
    const note = await invoke("scratchpad_load_note", { id });
    scratchpad.current = note;
    scratchpad.dirty = false;
    scratchpad.pinnedDraft = note.pinned;
    elements.scratchpadTitle.value = note.title;
    elements.scratchpadIncludeDate.checked = note.includeTimestamp;
    elements.scratchpadSavedNotes.value = note.content;
    renderScratchpadList();
    updateScratchpadActions();
  } catch (error) {
    showToast(`Could not open note: ${String(error)}`, "error");
    await loadScratchpadNotes();
  }
}

// saves either a new saved note or edits to the open saved note
async function saveScratchpadNote() {
  if (!isDesktop) {
    scratchpad.dirty = false;
    updateScratchpadActions();
    return;
  }
  const title = elements.scratchpadTitle.value;
  const content = elements.scratchpadSavedNotes.value;
  const includeTimestamp = elements.scratchpadIncludeDate.checked;
  try {
    let current = scratchpad.current;
    if (!current?.id) {
      current = await invoke("scratchpad_create_note", {
        title,
        includeTimestamp,
      });
    }
    const saved = await invoke("scratchpad_save_note", {
      input: {
        id: current.id,
        title,
        content,
        pinned: scratchpad.pinnedDraft,
        includeTimestamp,
      },
    });
    scratchpad.current = saved;
    scratchpad.dirty = false;
    await loadScratchpadNotes();
    renderScratchpadList();
    updateScratchpadActions();
    showToast("Scratchpad note saved.");
  } catch (error) {
    showToast(`Could not save note: ${String(error)}`, "error");
  }
}

// reloads the open note from disk or clears an unsaved new note
async function refreshScratchpadNote() {
  if (!confirmScratchpadDiscard()) return;
  if (scratchpad.current?.id) {
    await openScratchpadNote(scratchpad.current.id, { force: true });
  } else {
    showNewScratchpadNote({ force: true });
  }
}

// deletes the selected saved note after confirmation
async function deleteScratchpadNote() {
  if (!scratchpad.current?.id || !isDesktop) return;
  const label = noteDisplayTitle(scratchpad.current);
  if (!window.confirm(`Delete saved note "${label}"?`)) return;
  try {
    await invoke("scratchpad_delete_note", { id: scratchpad.current.id });
    showNewScratchpadNote({ force: true });
    await loadScratchpadNotes();
    showToast("Scratchpad note deleted.");
  } catch (error) {
    showToast(`Could not delete note: ${String(error)}`, "error");
  }
}

// toggles between temporary auto-wipe mode and saved-note mode
async function updateScratchpadMode() {
  const autoWipe = elements.scratchpadAutoWipe.checked;
  try {
    localStorage.setItem(scratchpadAutoWipePreference, String(autoWipe));
  } catch {}
  elements.scratchpadAutoPanel.classList.toggle("hidden", !autoWipe);
  elements.scratchpadSavedPanel.classList.toggle("hidden", autoWipe);
  if (!autoWipe && !scratchpadLoaded) {
    await loadScratchpadNotes();
    showNewScratchpadNote();
  }
}

// returns the sortable local timestamp used by generated dataset inputs
function fileTimestamp(date = new Date()) {
  const pad = (value) => String(value).padStart(2, "0");
  return (
    `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}_` +
    `${pad(date.getHours())}-${pad(date.getMinutes())}-${pad(date.getSeconds())}`
  );
}

// offers to create only the required dataset inputs that are currently absent
async function offerMissingFiles(summary) {
  if (!isDesktop) return false;
  const runOrderName = `run_order_${fileTimestamp()}.csv`;
  const transitionName = "transition_list.csv";
  try {
    const plan = await invoke("missing_project_files", {
      projectPath: summary.path,
      runOrderName,
      transitionName,
    });
    if (!plan.files.length) return false;
    pendingSetup = {
      projectPath: summary.path,
      runOrderName,
      transitionName,
    };
    elements.missingFilesList.replaceChildren();
    for (const file of plan.files) {
      const item = document.createElement("li");
      item.textContent = file.name;
      elements.missingFilesList.append(item);
    }
    elements.missingParamNote.classList.add("hidden");
    elements.missingFilesModal.classList.remove("hidden");
    return true;
  } catch (error) {
    showToast(`Could not inspect missing files: ${String(error)}`, "error");
    return false;
  }
}

// creates the approved templates and refreshes project validation
async function createMissingFiles() {
  if (!pendingSetup) return;
  const setup = pendingSetup;
  elements.missingFilesCreate.disabled = true;
  elements.missingFilesCancel.disabled = true;
  try {
    const result = await invoke("create_missing_project_files", {
      projectPath: setup.projectPath,
      runOrderName: setup.runOrderName,
      transitionName: setup.transitionName,
    });
    renderProject(result.project);
    elements.missingFilesModal.classList.add("hidden");
    for (const name of result.created) {
      addActivity(`Created template ${name}.`, "success");
    }
    showToast(
      `${result.created.length} missing file${result.created.length === 1 ? "" : "s"} created.`,
    );
    pendingSetup = null;
  } catch (error) {
    showToast(`Could not create the missing files: ${String(error)}`, "error");
  } finally {
    elements.missingFilesCreate.disabled = false;
    elements.missingFilesCancel.disabled = false;
  }
}

// renders the file buttons in the data editor sidebar
function renderDataEditorFiles() {
  elements.dataEditorFiles.replaceChildren();
  for (const file of dataEditor.files) {
    const button = document.createElement("button");
    button.type = "button";
    button.className = "data-editor-file";
    if (dataEditor.current?.kind === file.kind) button.classList.add("active");
    const title = document.createElement("strong");
    title.textContent = file.title;
    const name = document.createElement("span");
    name.textContent = file.name;
    button.append(title, name);
    button.addEventListener("click", () => openDataEditorFile(file.kind));
    elements.dataEditorFiles.append(button);
  }
}

// updates the backup dropdown for the selected data file
function isDataEditorOriginalBackup(backup) {
  return /^original\.[^.]+$/i.test(backup);
}

function renderDataEditorBackups(backups = [], selectedBackup = "") {
  const fragment = document.createDocumentFragment();
  if (!backups.length) {
    const option = document.createElement("option");
    option.value = "";
    option.textContent = "No backups yet";
    fragment.append(option);
  } else {
    const currentOption = document.createElement("option");
    currentOption.value = "";
    currentOption.textContent = "Current file (live)";
    fragment.append(currentOption);
    for (const backup of backups) {
      const option = document.createElement("option");
      option.value = backup;
      option.textContent = isDataEditorOriginalBackup(backup)
        ? "Original"
        : backup;
      fragment.append(option);
    }
  }
  elements.dataEditorBackups.replaceChildren(fragment);
  elements.dataEditorBackups.value = selectedBackup;
  const backupSelected = Boolean(selectedBackup);
  const originalSelected = isDataEditorOriginalBackup(selectedBackup);
  elements.dataEditorRestore.disabled = !backupSelected;
  elements.dataEditorRestore.title = backupSelected
    ? "restore this backup over the current file"
    : "select a backup before restoring";
  elements.dataEditorRename.disabled = !backupSelected || originalSelected;
  elements.dataEditorRename.title = originalSelected
    ? "Original cannot be renamed"
    : backupSelected
      ? "rename this backup"
      : "select a backup before renaming";
  elements.dataEditorDelete.disabled = !backupSelected || originalSelected;
  elements.dataEditorDelete.title = originalSelected
    ? "Original cannot be deleted"
    : backupSelected
      ? "delete this backup"
      : "select a backup before deleting";
}

// marks the data editor as changed after a cell or text edit
function markDataEditorDirty() {
  dataEditor.dirty = true;
  elements.dataEditorStatus.textContent = "Unsaved changes";
}

// renders one text or CSV file into the editor body
function renderDataEditorContent(content, options = {}) {
  const selectedBackup = options.backup ?? "";
  dataEditor.content = content;
  dataEditor.current = content.file;
  dataEditor.viewingBackup = selectedBackup;
  dataEditor.dirty = false;
  renderDataEditorFiles();
  const backupLabel = isDataEditorOriginalBackup(selectedBackup)
    ? "Original"
    : selectedBackup;
  elements.dataEditorCurrent.textContent = selectedBackup
    ? `${content.file.title} - ${backupLabel}`
    : `${content.file.title} - ${content.file.name}`;
  elements.dataEditorStatus.textContent = selectedBackup
    ? `Viewing backup preview for ${content.file.name}`
    : "Ready";
  renderDataEditorBackups(content.backups, selectedBackup);
  elements.dataEditorTableActions.classList.toggle(
    "hidden",
    content.file.format !== "csv",
  );
  elements.dataEditorBody.classList.toggle(
    "text-mode",
    content.file.format === "text",
  );
  elements.dataEditorBody.classList.toggle(
    "table-mode",
    content.file.format === "csv",
  );
  elements.dataEditorBody.replaceChildren();
  if (content.file.format === "text") {
    const textarea = document.createElement("textarea");
    textarea.className = "data-editor-text";
    textarea.value = content.text ?? "";
    textarea.spellcheck = false;
    textarea.addEventListener("input", markDataEditorDirty);
    elements.dataEditorBody.append(textarea);
    return;
  }

  const table = document.createElement("table");
  table.className = "data-editor-table";
  const thead = document.createElement("thead");
  const headerRow = document.createElement("tr");
  for (const header of content.headers) {
    const th = document.createElement("th");
    const input = document.createElement("input");
    input.value = header;
    input.addEventListener("input", markDataEditorDirty);
    th.append(input);
    headerRow.append(th);
  }
  thead.append(headerRow);
  const tbody = document.createElement("tbody");
  for (const row of content.rows) {
    const tr = document.createElement("tr");
    for (let index = 0; index < content.headers.length; index += 1) {
      const td = document.createElement("td");
      const input = document.createElement("input");
      input.value = row[index] ?? "";
      input.addEventListener("input", markDataEditorDirty);
      td.append(input);
      tr.append(td);
    }
    tbody.append(tr);
  }
  table.append(thead, tbody);
  elements.dataEditorBody.append(table);
}

// reads the current editor DOM into a save payload
function collectDataEditorInput() {
  if (!dataEditor.current) return null;
  if (dataEditor.current.format === "text") {
    return {
      kind: dataEditor.current.kind,
      text: elements.dataEditorBody.querySelector("textarea")?.value ?? "",
      headers: [],
      rows: [],
    };
  }
  const table = elements.dataEditorBody.querySelector("table");
  const headers = [...table.querySelectorAll("thead input")].map(
    (input) => input.value,
  );
  const rows = [...table.querySelectorAll("tbody tr")].map((row) =>
    [...row.querySelectorAll("input")].map((input) => input.value),
  );
  return {
    kind: dataEditor.current.kind,
    text: null,
    headers,
    rows,
  };
}

// opens and loads the data editor
async function openDataEditor() {
  if (!project) {
    showToast("Select a dataset before editing data.", "error");
    return;
  }
  if (!isDesktop) {
    showToast("Data editing is available in the desktop build.", "error");
    return;
  }
  elements.dataEditorModal.classList.remove("hidden");
  elements.dataEditorStatus.textContent = "Loading files...";
  try {
    dataEditor.files = await invoke("data_editor_files", {
      projectPath: project.path,
    });
    renderDataEditorFiles();
    if (dataEditor.files[0]) {
      await openDataEditorFile(dataEditor.files[0].kind);
    }
  } catch (error) {
    elements.dataEditorStatus.textContent = String(error);
  }
}

// closes the data editor, protecting unsaved edits
function closeDataEditor() {
  if (dataEditor.dirty && !window.confirm("Discard unsaved data edits?")) return;
  elements.dataEditorModal.classList.add("hidden");
}

// opens a specific editable file
async function openDataEditorFile(kind, options = {}) {
  if (
    !options.force &&
    dataEditor.dirty &&
    !window.confirm("Discard unsaved data edits?")
  ) {
    elements.dataEditorBackups.value = dataEditor.viewingBackup;
    return;
  }
  elements.dataEditorStatus.textContent = "Loading...";
  try {
    const content = await invoke("data_editor_read", {
      projectPath: project.path,
      kind,
    });
    renderDataEditorContent(content);
  } catch (error) {
    elements.dataEditorStatus.textContent = String(error);
  }
}

// loads a selected backup as a preview without replacing the active dataset file
async function openDataEditorBackup(backup, options = {}) {
  if (!dataEditor.current || !backup) return;
  if (
    !options.force &&
    dataEditor.dirty &&
    !window.confirm("Discard unsaved data edits?")
  ) {
    elements.dataEditorBackups.value = dataEditor.viewingBackup;
    return;
  }
  elements.dataEditorStatus.textContent = "Loading backup...";
  try {
    const content = await invoke("data_editor_read_backup", {
      projectPath: project.path,
      kind: dataEditor.current.kind,
      backup,
    });
    renderDataEditorContent(content, { backup });
  } catch (error) {
    elements.dataEditorStatus.textContent = String(error);
  }
}

// saves the selected editable file and refreshes project status afterward
async function saveDataEditorFile() {
  const input = collectDataEditorInput();
  if (!input || !dataEditor.current) return;
  const savedKind = dataEditor.current.kind;
  elements.dataEditorStatus.textContent = "Saving...";
  try {
    const content = await invoke("data_editor_save", {
      projectPath: project.path,
      input,
    });
    renderDataEditorContent(content);
    addActivity(`Saved ${content.file.name}.`, "success");
    await refreshProject();
    if (savedKind === "transition") {
      const shouldRun = await appConfirm(
        "Transition list saved. Would you like to re-run Step 3 now?",
        "Re-run Step 3?",
        "Run Step 3",
        "Not now",
      );
      if (!shouldRun) {
        elements.dataEditorStatus.textContent =
          "Saved. Step 3 was not re-run.";
        return;
      }
      elements.dataEditorStatus.textContent = "Saved. Re-integrating Step 3...";
      const result = await runStep(3, { backup: true });
      if (result.success) {
        elements.dataEditorStatus.textContent = "Saved and re-integrated Step 3.";
        if (!elements.visualizerView.classList.contains("hidden")) {
          await visualizerModule?.refreshCurrentVisualizer?.({
            preserveScroll: true,
          });
        }
      } else {
        elements.dataEditorStatus.textContent =
          "Saved, but Step 3 did not finish.";
      }
    }
  } catch (error) {
    elements.dataEditorStatus.textContent = `Save failed: ${String(error)}`;
  }
}

// reloads the selected editable file from disk
async function refreshDataEditorFile() {
  if (!dataEditor.current) return;
  if (dataEditor.dirty && !window.confirm("Discard unsaved data edits?")) return;
  if (dataEditor.viewingBackup) {
    await openDataEditorBackup(dataEditor.viewingBackup, { force: true });
    return;
  }
  await openDataEditorFile(dataEditor.current.kind, { force: true });
}

// restores the selected backup over the current editable file
async function restoreDataEditorBackup() {
  if (!dataEditor.current || !dataEditor.viewingBackup) return;
  const backup = dataEditor.viewingBackup;
  const backupLabel = isDataEditorOriginalBackup(backup) ? "Original" : backup;
  if (!window.confirm(`Restore ${backupLabel} over ${dataEditor.current.name}?`)) {
    return;
  }
  elements.dataEditorStatus.textContent = "Restoring backup...";
  try {
    const content = await invoke("data_editor_restore_backup", {
      projectPath: project.path,
      kind: dataEditor.current.kind,
      backup,
    });
    renderDataEditorContent(content);
    addActivity(`Restored backup for ${content.file.name}.`, "success");
    await refreshProject();
  } catch (error) {
    elements.dataEditorStatus.textContent = `Restore failed: ${String(error)}`;
  }
}

// renames the selected editor backup file
async function renameDataEditorBackup() {
  if (!dataEditor.current || !dataEditor.viewingBackup) return;
  if (dataEditor.dirty && !window.confirm("Discard unsaved data edits?")) return;
  const current = dataEditor.viewingBackup;
  const name = await appPrompt(
    `Rename selected backup:\n${current}`,
    current,
    "Rename backup",
  );
  if (name === null) return;
  const trimmed = name.trim();
  if (!trimmed || trimmed === current) return;
  elements.dataEditorStatus.textContent = "Renaming backup...";
  try {
    const renamed = await invoke("data_editor_rename_backup", {
      projectPath: project.path,
      kind: dataEditor.current.kind,
      backup: current,
      name: trimmed,
    });
    await openDataEditorBackup(renamed, { force: true });
    addActivity(`Renamed ${current} to ${renamed}.`, "success");
  } catch (error) {
    elements.dataEditorStatus.textContent = `Rename failed: ${String(error)}`;
  }
}

// deletes the selected editor backup file
async function deleteDataEditorBackup() {
  if (!dataEditor.current || !dataEditor.viewingBackup) return;
  const backup = dataEditor.viewingBackup;
  if (!window.confirm(`Delete backup ${backup}? This cannot be undone.`)) return;
  elements.dataEditorStatus.textContent = "Deleting backup...";
  try {
    const content = await invoke("data_editor_delete_backup", {
      projectPath: project.path,
      kind: dataEditor.current.kind,
      backup,
    });
    renderDataEditorContent(content);
    addActivity(`Deleted backup ${backup}.`, "success");
  } catch (error) {
    elements.dataEditorStatus.textContent = `Delete failed: ${String(error)}`;
  }
}

// adds one blank CSV row to the current table
function addDataEditorRow() {
  if (!dataEditor.current || dataEditor.current.format !== "csv") return;
  const tbody = elements.dataEditorBody.querySelector("tbody");
  const columns = elements.dataEditorBody.querySelectorAll("thead input").length;
  const tr = document.createElement("tr");
  for (let index = 0; index < columns; index += 1) {
    const td = document.createElement("td");
    const input = document.createElement("input");
    input.addEventListener("input", markDataEditorDirty);
    td.append(input);
    tr.append(td);
  }
  tbody.append(tr);
  markDataEditorDirty();
}

// adds one blank CSV column to the current table
function addDataEditorColumn() {
  if (!dataEditor.current || dataEditor.current.format !== "csv") return;
  const headerCell = document.createElement("th");
  const headerInput = document.createElement("input");
  headerInput.value = "new_column";
  headerInput.addEventListener("input", markDataEditorDirty);
  headerCell.append(headerInput);
  elements.dataEditorBody.querySelector("thead tr").append(headerCell);
  for (const row of elements.dataEditorBody.querySelectorAll("tbody tr")) {
    const td = document.createElement("td");
    const input = document.createElement("input");
    input.addEventListener("input", markDataEditorDirty);
    td.append(input);
    row.append(td);
  }
  markDataEditorDirty();
}

// loads the bundled d3 runtime only when the visualizer is first opened
function loadD3() {
  if (window.d3) return Promise.resolve();
  return new Promise((resolve, reject) => {
    const existing = document.querySelector('script[data-mrmhub-d3="true"]');
    if (existing) {
      existing.addEventListener("load", resolve, { once: true });
      existing.addEventListener("error", reject, { once: true });
      return;
    }
    const script = document.createElement("script");
    script.src = "visualizer/d3.v7.min.js";
    script.dataset.mrmhubD3 = "true";
    script.addEventListener("load", resolve, { once: true });
    script.addEventListener("error", reject, { once: true });
    document.head.append(script);
  });
}

// switches to the integration workflow while preserving rendered graphs
function showIntegrator() {
  elements.visualizerView.classList.add("hidden");
  elements.scratchpadView.classList.add("hidden");
  elements.integratorView.classList.remove("hidden");
  elements.integratorTab.classList.add("active");
  elements.integratorTab.setAttribute("aria-current", "page");
  elements.visualizerTab.classList.remove("active");
  elements.visualizerTab.removeAttribute("aria-current");
  elements.scratchpadTab.classList.remove("active");
  elements.scratchpadTab.removeAttribute("aria-current");
}

// opens and lazily initializes the integrated visualizer
async function showVisualizer() {
  if (!project) {
    showToast("Select a dataset before opening the visualizer.", "error");
    return;
  }
  if (!project.outputs.validated) {
    showToast("Run step 1 before opening the visualizer.", "error");
    return;
  }

  elements.integratorView.classList.add("hidden");
  elements.scratchpadView.classList.add("hidden");
  elements.visualizerView.classList.remove("hidden");
  elements.integratorTab.classList.remove("active");
  elements.integratorTab.removeAttribute("aria-current");
  elements.visualizerTab.classList.add("active");
  elements.visualizerTab.setAttribute("aria-current", "page");
  elements.scratchpadTab.classList.remove("active");
  elements.scratchpadTab.removeAttribute("aria-current");
  elements.visualizerDataset.textContent = project.path;

  if (!isDesktop) {
    elements.visualizerStatus.textContent =
      "The live dataset visualizer is available in the desktop build.";
    return;
  }

  elements.visualizerStatus.textContent = "Loading visualizer...";
  try {
    await loadD3();
    visualizerModule ??= await import("./visualizer/visualizer.js");
    await visualizerModule.initializeVisualizer(project.path);
  } catch (error) {
    elements.visualizerStatus.textContent = "Visualizer could not be loaded.";
    showToast(String(error), "error");
  }
}

// opens the placeholder scratchpad tab
function showScratchpad() {
  elements.integratorView.classList.add("hidden");
  elements.visualizerView.classList.add("hidden");
  elements.scratchpadView.classList.remove("hidden");
  elements.integratorTab.classList.remove("active");
  elements.integratorTab.removeAttribute("aria-current");
  elements.visualizerTab.classList.remove("active");
  elements.visualizerTab.removeAttribute("aria-current");
  elements.scratchpadTab.classList.add("active");
  elements.scratchpadTab.setAttribute("aria-current", "page");
  updateScratchpadMode();
}

function updateThemeToggle() {
  const isDark = document.documentElement.dataset.theme === "dark";
  elements.themeToggle.setAttribute(
    "aria-label",
    isDark ? "disable night mode" : "enable night mode",
  );
  elements.themeToggle.title = isDark
    ? "disable night mode"
    : "enable night mode";
}

function rememberedGuiScale() {
  try {
    return (
      localStorage.getItem(guiScalePreference) ??
      localStorage.getItem(legacyVisualizerScalePreference) ??
      "100"
    );
  } catch {
    return "100";
  }
}

// Scales the native webview so every tab, modal, graph, and control grows as
// one UI. Browser preview uses CSS zoom as a close fallback.
async function setGuiScale(value, options = {}) {
  const percent = guiScaleOptions.includes(Number(value)) ? Number(value) : 100;
  const scale = percent / 100;
  guiScalePercent = percent;
  elements.guiScale.value = String(percent);
  if (options.persist !== false) {
    try {
      localStorage.setItem(guiScalePreference, String(percent));
    } catch {}
  }

  let nativeZoomApplied = false;
  if (isDesktop && tauri.webview?.getCurrentWebview) {
    try {
      await tauri.webview.getCurrentWebview().setZoom(scale);
      nativeZoomApplied = true;
    } catch (error) {
      console.warn("Native GUI scaling was unavailable:", error);
    }
  }
  document.body.style.zoom = nativeZoomApplied ? "" : String(scale);
  if (options.notify !== false) {
    document.dispatchEvent(
      new CustomEvent("mrmhub-gui-scale-change", { detail: { percent } }),
    );
  }
  return percent;
}

async function toggleTheme() {
  const theme =
    document.documentElement.dataset.theme === "dark" ? "light" : "dark";
  document.documentElement.dataset.theme = theme;
  try {
    localStorage.setItem("mrmhub-theme", theme);
  } catch {
    // the selected theme still applies for the current session
  }
  if (isDesktop) {
    try {
      await invoke("set_theme", { theme });
    } catch (error) {
      showToast(String(error), "error");
    }
  }
  updateThemeToggle();
}

async function chooseProject() {
  if (!isDesktop) {
    renderProject(mockProject);
    addActivity("Demo project selected for browser preview.");
    return;
  }
  try {
    const path = await tauri.dialog.open({
      directory: true,
      multiple: false,
      title: "Choose an MRMhub project folder",
    });
    if (!path) return;
    const summary = await invoke("select_project", { path });
    renderProject(summary);
    addActivity(`Selected ${summary.name}.`);
    const offered = await offerMissingFiles(summary);
    if (!summary.canRun && !offered) {
      showToast("The project was selected, but some required files are missing.", "error");
    }
  } catch (error) {
    showToast(String(error), "error");
  }
}

async function refreshProject() {
  if (!project) return;
  if (!isDesktop) {
    renderProject({ ...project });
    addActivity("Project status refreshed.");
    return;
  }
  try {
    const summary = await invoke("refresh_project", { path: project.path });
    renderProject(summary);
    addActivity("Project status refreshed.");
  } catch (error) {
    showToast(String(error), "error");
  }
}

async function runMockStep(step) {
  addActivity(`Step ${step} started.`);
  await new Promise((resolve) => window.setTimeout(resolve, 900));
  const outputKey = {
    1: "validated",
    2: "detected",
    3: "integrated",
    4: "plotted",
  }[step];
  project.outputs[outputKey] = true;
  addActivity(`Step ${step} completed.`, "success");
  return { ...project, outputs: { ...project.outputs } };
}

// builds a filesystem-safe, chronologically sortable backup file name
function backupFileName(date = new Date()) {
  return `RT_matrix_${fileTimestamp(date)}.csv`;
}

// runs one workflow step; step 3 snapshots RT_matrix.csv first unless the
// caller opts out (e.g. a revert, which restored an existing snapshot).
// returns { success, backup } so callers like the visualizer can react.
async function runStep(step, options = {}) {
  const { backup = step === 3 } = options;
  if (!project || activeStep !== null) return { success: false, backup: null };
  const prerequisite = prerequisiteMessage(step);
  if (prerequisite) {
    addActivity(prerequisite, "error");
    showToast(prerequisite, "error");
    return { success: false, backup: null };
  }
  activeStep = step;
  beginStepProgress(step);
  updateWorkflow();
  addActivity(`Starting step ${step}…`);
  let backupName = null;
  try {
    if (isDesktop && backup) {
      try {
        backupName =
          (await invoke("backup_rtmatrix", {
            projectPath: project.path,
            name: backupFileName(),
          })) ?? null;
        if (backupName) addActivity(`Backed up RT_matrix.csv → ${backupName}.`);
      } catch (error) {
        backupName = null;
        addActivity(`RT_matrix backup skipped: ${String(error)}`, "error");
      }
    }
    const summary = isDesktop
      ? await invoke("run_step", { path: project.path, step })
      : await runMockStep(step);
    completedThisSession.add(step);
    renderProject(summary);
    addActivity(`Step ${step} completed successfully.`, "success");
    showToast(`Step ${step} complete.`);
    return { success: true, backup: backupName };
  } catch (error) {
    setStepStatus(step, "failed");
    addActivity(String(error), "error");
    showToast(String(error), "error");
    return { success: false, backup: backupName };
  } finally {
    resetStepProgress(step);
    activeStep = null;
    updateWorkflow();
  }
}

async function registerDesktopEvents() {
  if (!isDesktop) return;
  await tauri.event.listen("worker-output", ({ payload }) => {
    if (isWindows) {
      queueStepProgress(payload.step, payload.line);
    } else {
      updateStepProgress(payload.step, payload.line);
    }
    if (/^Progress:\s*\d+\s*\/\s*\d+\s*-/.test(payload.line)) return;
    addActivity(payload.line, payload.stream === "error" ? "error" : "");
  });
  await tauri.event.listen("step-state", ({ payload }) => {
    if (payload.status === "running") {
      activeStep = payload.step;
    }
    updateWorkflow();
  });
}

async function bootstrap() {
  try {
    elements.scratchpadAutoWipe.checked =
      localStorage.getItem(scratchpadAutoWipePreference) === "true";
  } catch {
    elements.scratchpadAutoWipe.checked = false;
  }
  for (const button of elements.chooseButtons) {
    button.addEventListener("click", chooseProject);
  }
  elements.editDataButton.addEventListener("click", openDataEditor);
  elements.missingFilesCancel.addEventListener("click", () => {
    elements.missingFilesModal.classList.add("hidden");
    pendingSetup = null;
  });
  elements.missingFilesCreate.addEventListener("click", createMissingFiles);
  elements.dataEditorClose.addEventListener("click", closeDataEditor);
  elements.dataEditorSave.addEventListener("click", saveDataEditorFile);
  elements.dataEditorRefresh.addEventListener("click", refreshDataEditorFile);
  elements.dataEditorRestore.addEventListener("click", restoreDataEditorBackup);
  elements.dataEditorRename.addEventListener("click", renameDataEditorBackup);
  elements.dataEditorDelete.addEventListener("click", deleteDataEditorBackup);
  elements.dataEditorBackups.addEventListener("change", () => {
    const backup = elements.dataEditorBackups.value;
    if (backup) {
      openDataEditorBackup(backup);
    } else if (dataEditor.current) {
      openDataEditorFile(dataEditor.current.kind);
    }
  });
  elements.dataEditorAddRow.addEventListener("click", addDataEditorRow);
  elements.dataEditorAddColumn.addEventListener("click", addDataEditorColumn);
  elements.themeToggle.addEventListener("click", toggleTheme);
  elements.guiScale.addEventListener("change", () => {
    setGuiScale(elements.guiScale.value);
  });
  elements.clearActivity.addEventListener("click", () => {
    elements.activityLog.innerHTML =
      '<p class="empty-log">Activity cleared.</p>';
  });
  elements.visualizerButton.addEventListener("click", () => {
    showVisualizer();
  });
  elements.scratchpadButton.addEventListener("click", showScratchpad);
  elements.integratorTab.addEventListener("click", showIntegrator);
  elements.visualizerTab.addEventListener("click", showVisualizer);
  elements.scratchpadTab.addEventListener("click", showScratchpad);
  elements.scratchpadAutoWipe.addEventListener("change", updateScratchpadMode);
  elements.scratchpadNewNote.addEventListener("click", showNewScratchpadNote);
  elements.scratchpadSaveNote.addEventListener("click", saveScratchpadNote);
  elements.scratchpadDeleteNote.addEventListener("click", deleteScratchpadNote);
  elements.scratchpadRefreshNote.addEventListener("click", refreshScratchpadNote);
  elements.scratchpadPin.addEventListener("click", () => {
    scratchpad.pinnedDraft = !scratchpad.pinnedDraft;
    markScratchpadDirty();
  });
  elements.scratchpadTitle.addEventListener("input", markScratchpadDirty);
  elements.scratchpadSavedNotes.addEventListener("input", markScratchpadDirty);
  elements.scratchpadIncludeDate.addEventListener("change", markScratchpadDirty);
  document.addEventListener("pointerdown", (event) => {
    const active = document.activeElement;
    if (
      (active === elements.scratchpadNotes ||
        active === elements.scratchpadSavedNotes ||
        active === elements.scratchpadTitle ||
        active?.closest?.(".data-editor-modal")) &&
      event.target !== active
    ) {
      active.blur();
    }
  });
  for (const link of elements.externalSlingLinks) {
    link.addEventListener("click", async (event) => {
      if (!isDesktop) return;
      event.preventDefault();
      try {
        await invoke("open_sling");
      } catch (error) {
        showToast(String(error), "error");
      }
    });
  }
  for (const card of elements.stepCards) {
    const trigger = () => {
      if (activeStep !== null) return;
      const step = Number(card.dataset.step);
      const prerequisite = prerequisiteMessage(step);
      if (prerequisite) {
        addActivity(prerequisite, "error");
        showToast(prerequisite, "error");
      } else {
        runStep(step);
      }
    };
    card.addEventListener("click", trigger);
    card.addEventListener("keydown", (event) => {
      if (event.key === "Enter" || event.key === " ") {
        event.preventDefault();
        trigger();
      }
    });
  }

  await setGuiScale(rememberedGuiScale(), { persist: false });
  await registerDesktopEvents();
  updateThemeToggle();
  updateScratchpadActions();
  if (!isDesktop) {
    renderProject(mockProject);
    addActivity("Browser preview mode is active.");
    return;
  }

  try {
    const state = await invoke("load_startup_state");
    if (state.theme === "light" || state.theme === "dark") {
      document.documentElement.dataset.theme = state.theme;
      updateThemeToggle();
    }
    if (state.project) {
      renderProject(state.project);
      addActivity(`Restored ${state.project.name}.`);
      await offerMissingFiles(state.project);
    } else {
      if (state.needsReselection) {
        elements.modalMessage.textContent =
          `The previous folder (${state.rememberedPath}) is no longer available. Choose its new location.`;
      }
      elements.projectModal.classList.remove("hidden");
      updateWorkflow();
    }
  } catch (error) {
    elements.projectModal.classList.remove("hidden");
    showToast(String(error), "error");
  }
}

// bridge the visualizer module needs to raise toasts and drive Step 3 reruns
window.__mrmhubShell = {
  showToast,
  runStep,
  refreshProject,
  getProject: () => project,
  prompt: appPrompt,
  confirm: appConfirm,
  getGuiScale: () => guiScalePercent,
  setGuiScale,
};

bootstrap();
