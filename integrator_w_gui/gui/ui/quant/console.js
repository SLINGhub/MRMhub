import { createTerminal } from "./terminal.bundle.js?v=1.2.4-console-theme";
import { captureScroll, scrollPosition } from "./scroll-state.js";

export function initializeConsole(root, confirm, clearR) {
  const $ = id => root.querySelector(`#q-${id}`);
  const native = window.__TAURI__;
  const invoke = (...args) => native.core.invoke(...args);
  let view, id, active = false, pending = false, trusted = false, token = 0;
  let writes = Promise.resolve(), terminalSelected = false;
  let startReady = Promise.resolve();
  const section = $("console-expand").closest(".q-terminal");
  const placeholder = document.createElement("div");
  placeholder.hidden = true;
  placeholder.setAttribute("aria-hidden", "true");
  section.before(placeholder);
  const dialog = document.createElement("dialog");
  dialog.className = "q-console-dialog";
  dialog.setAttribute("aria-label", "Expanded QUANT console");
  root.append(dialog);
  let pageScroll, logScroll, terminalScroll, restoring = false, restoreGeneration = 0;
  $("log").addEventListener("scroll", () => {
    if (dialog.open && !restoring && $("log").clientHeight) logScroll = captureScroll($("log"));
  });
  function saveTerminalScroll() {
    if (!view || !terminalSelected) return;
    const buffer = view.terminal.buffer.active;
    terminalScroll = { top: buffer.viewportY, bottom: buffer.viewportY >= buffer.baseY };
  }
  function restoreScroll() {
    const generation = ++restoreGeneration;
    restoring = true;
    const restore = () => {
      if (generation !== restoreGeneration) return;
      if (logScroll) $("log").scrollTop = scrollPosition(logScroll, $("log").scrollHeight, $("log").clientHeight);
      if (terminalScroll && view && terminalSelected) {
        if (terminalScroll.bottom) view.terminal.scrollToBottom();
        else view.terminal.scrollToLine(terminalScroll.top);
      }
      if (pageScroll) window.scrollTo({ left: pageScroll.x, top: pageScroll.y, behavior: "instant" });
    };
    restore();
    // FitAddon and browser layout complete on animation frames after reparenting.
    requestAnimationFrame(() => { restore(); requestAnimationFrame(() => {
      restore(); if (generation === restoreGeneration) restoring = false;
    }); });
  }
  function expand() {
    pageScroll = { x: window.scrollX, y: window.scrollY };
    if ($("log").clientHeight) logScroll = captureScroll($("log"));
    saveTerminalScroll(); restoring = true;
    const style = getComputedStyle(section);
    placeholder.style.height = `${section.offsetHeight}px`;
    placeholder.style.marginTop = style.marginTop; placeholder.style.marginBottom = style.marginBottom;
    placeholder.hidden = false;
    dialog.append(section);
    $("console-expand").textContent = "Collapse ↙";
    $("console-expand").setAttribute("aria-expanded", "true");
    dialog.showModal(); view?.resize();
    if (terminalSelected && view) view.terminal.focus(); else $("log").focus({ preventScroll: true });
    restoreScroll();
  }
  function collapse() {
    restoring = true;
    dialog.close(); placeholder.after(section);
    placeholder.hidden = true;
    $("console-expand").textContent = "Expand ⛶";
    $("console-expand").setAttribute("aria-expanded", "false");
    view?.resize(); $("console-expand").focus({ preventScroll: true });
    restoreScroll();
  }
  dialog.addEventListener("cancel", event => { event.preventDefault(); collapse(); });
  $("console-expand").onclick = () => dialog.open ? collapse() : expand();
  // The app's shared confirmation is outside the native dialog's modal layer.
  async function ask(title, message) {
    const expanded = dialog.open;
    if (expanded) collapse();
    try { return await confirm(title, message); }
    finally { if (expanded) expand(); }
  }
  const note = message => { $("shell-note").textContent = message; };
  function controls() {
    $("shell-start").disabled = pending || !native;
    $("shell-start").textContent = active ? "End session" : "Start session";
    $("shell-state").textContent = pending ? (active ? "Stopping…" : "Starting…") : active ? "Running" : "Stopped";
    $("shell-state").classList.toggle("running", active);
    $("clear-log").textContent = "Clear";
  }
  function input(data) {
    const current = token;
    // Preserve keystroke/paste order across asynchronous native writes.
    // Chunk by code points so UTF-8 and surrogate pairs are not split.
    const points = Array.from(data);
    for (let offset = 0; offset < points.length; offset += 4096) {
      const chunk = points.slice(offset, offset + 4096).join("");
      writes = writes.then(async () => {
        await startReady;
        if (current !== token || !active || id == null) return;
        await invoke("terminal_write", { id, data: chunk });
      }).catch(error => note(String(error)));
    }
  }
  function ensureView() {
    if (view) return;
    view = createTerminal($("shell-screen"), input, (cols, rows) => {
      if (id != null && active) invoke("terminal_resize", { id, cols, rows }).catch(error => note(String(error)));
    });
    view.terminal.onScroll(() => { if (dialog.open && !restoring) saveTerminalScroll(); });
  }
  async function start() {
    if (pending || active || !native) return;
    pending = true; controls();
    if (!trusted) {
      if (!await ask("Open a local terminal?", "This is a real system shell with your account’s file and network access. Commands can change or delete files. It starts in your home folder and is separate from QUANT’s R session. Only run commands you trust.")) { pending = false; controls(); return; }
      trusted = true;
    }
    ensureView(); view.terminal.reset(); view.resize();
    pending = true; controls(); note("Starting your local shell…");
    const current = ++token;
    let finishStart;
    startReady = new Promise(resolve => { finishStart = resolve; });
    let exited = false;
    const output = new native.core.Channel();
    output.onmessage = event => {
      if (current !== token) return;
      if (event.kind === "data") {
        view.terminal.write(new Uint8Array(event.data), () => {
          invoke("terminal_ack", { id: event.id }).catch(() => {});
        });
      } else if (event.kind === "exit") {
        exited = true; active = false; controls(); note(`${event.message}. Start a new session to continue.`);
      }
    };
    try {
      const info = await invoke("terminal_start", { output, cols: view.terminal.cols, rows: view.terminal.rows });
      id = info.id; active = !exited;
      if (!exited) note(`${info.shell} · Starts in ${info.home} · Separate from the R workflow · Ctrl+C interrupts`);
      view.resize(); if (terminalSelected) view.terminal.focus();
    } catch (error) { note(`Could not start terminal: ${error}`); }
    finally { pending = false; finishStart(); controls(); }
  }
  async function stop() {
    if (!active || pending) return;
    if (!await ask("End this terminal session?", "This closes the shell and can interrupt commands running in it. QUANT’s R workflow is unaffected.")) return;
    pending = true; controls();
    try {
      await invoke("terminal_stop", { id }); token++; id = undefined; active = false;
      view.terminal.writeln("\r\n[Session ended]"); note("Session ended. Start session opens a new shell in your home folder.");
    } catch (error) { note(String(error)); }
    pending = false; controls();
  }
  function select(terminal) {
    if (!terminalSelected && $("log").clientHeight) logScroll = captureScroll($("log"));
    terminalSelected = terminal;
    for (const [name, selected] of [["r", !terminal], ["shell", terminal]]) {
      $(`${name}-console-tab`).setAttribute("aria-selected", String(selected));
      $(`${name}-console-tab`).tabIndex = selected ? 0 : -1;
      $(`${name}-console-panel`).classList.toggle("hidden", !selected);
    }
    $("terminal-state").classList.toggle("hidden", terminal);
    $("shell-state").classList.toggle("hidden", !terminal);
    $("shell-start").classList.toggle("hidden", !terminal);
    $("output-colors-label").classList.toggle("hidden", terminal);
    if (terminal) {
      if (!native) { note("The interactive terminal is available in the desktop app, not the browser preview."); return; }
      ensureView(); view.resize();
      if (!id && !active) start(); else view.terminal.focus();
    }
  }
  $("r-console-tab").onclick = () => select(false);
  $("shell-console-tab").onclick = () => select(true);
  for (const name of ["r", "shell"]) {
    $(`${name}-console-tab`).onkeydown = event => {
      if (!["ArrowLeft", "ArrowRight", "Home", "End"].includes(event.key)) return;
      event.preventDefault();
      const terminal = event.key === "End" || (event.key !== "Home" && !terminalSelected);
      select(terminal); $(`${terminal ? "shell" : "r"}-console-tab`).focus();
    };
  }
  $("shell-start").onclick = () => active ? stop() : start();
  $("clear-log").onclick = () => terminalSelected ? view?.terminal.clear() : clearR();
  controls();
}
