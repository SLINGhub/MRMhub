export function progressDisplay(percent, width = 32) {
  percent = Math.max(0, Math.min(100, Number(percent) || 0));
  const filled = Math.floor(width * percent / 100);
  return { percent, filled, bar: `[${"=".repeat(filled)}${" ".repeat(width - filled)}] ${percent.toFixed(1)}%` };
}

export function initializeProgress(root) {
  const host = root.querySelector("#q-run-progress");
  const bar = host.querySelector("pre"), status = host.querySelector(".q-run-progress-status");
  let token;
  function update(percent, message) {
    const display = progressDisplay(percent);
    bar.textContent = display.bar;
    bar.style.setProperty("--activity-end", `${Math.max(0, display.filled - 1)}ch`);
    bar.style.setProperty("--activity-steps", Math.max(1, display.filled - 1));
    bar.style.setProperty("--activity-visible", display.filled ? 1 : 0);
    host.setAttribute("aria-valuenow", display.percent.toFixed(1));
    host.setAttribute("aria-valuetext", `${display.percent.toFixed(1)} percent of work units completed. ${message}`);
    status.textContent = message;
  }
  return {
    start(runToken) { token = runToken; update(0, "Starting R and loading the QUANT engine…"); host.classList.add("running"); },
    receive(event) { if (token && event.token === token) update(event.percent, event.message); },
    finish() { token = undefined; host.classList.remove("running"); },
  };
}
