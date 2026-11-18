export const colorPreference = "mrmhub-quant-output-colors";

// Classify diagnostics, not arbitrary mentions inside printed data/code.
export function classifyOutput(line) {
  const text = line.trimStart();
  if (/^(?:Error(?:\b|:)|Execution halted\b|Fatal(?:\b|:)|✖|✗|\[error\])/i.test(text)) return "error";
  if (/^(?:Warning(?:s| message(?:s)?)?(?:\b|:)|⚠|!\s|\[warn(?:ing)?\])/i.test(text)) return "warning";
  if (/^(?:✔|✓|\[success\])/.test(text) || /\bcompleted\. Checkpoint saved\.$/.test(text)) return "success";
  if (/^(?:ℹ|\[info\]|Running\s|Loading\s|Installing\s|Checking\s)/i.test(text)) return "info";
  // R adds numbered warnings and indented calls/traceback lines.
  return "plain";
}

export function classifyLines(lines) {
  let diagnostic = "plain";
  return lines.map(line => {
    let kind = classifyOutput(line);
    if (kind === "plain" && diagnostic !== "plain" && /^(?:\s+\S|\d+:\s|Calls:)/.test(line)) kind = diagnostic;
    else diagnostic = ["error", "warning"].includes(kind) ? kind : "plain";
    return { text: line, kind };
  });
}

export function initializeOutput(element, toggle) {
  let lines = [], colored = false;
  try { colored = localStorage.getItem(colorPreference) === "true"; } catch { /* Optional preference. */ }
  toggle.checked = colored;
  function render() {
    const atBottom = element.scrollHeight - element.scrollTop - element.clientHeight < 32;
    const scroll = element.scrollTop;
    // Keep blank separators internally for diagnostic grouping, but don't
    // render them: R/progress framing can emit several empty records per step.
    if (!colored) element.textContent = lines.filter(line => line.trim()).join("\n");
    else {
      const fragment = document.createDocumentFragment();
      const visible = classifyLines(lines).filter(line => line.text.trim());
      visible.forEach(({ text, kind }, index) => {
        const span = document.createElement("span");
        span.className = `q-log-${kind}`;
        span.textContent = text + (index === visible.length - 1 ? "" : "\n");
        fragment.append(span);
      });
      element.replaceChildren(fragment);
    }
    element.scrollTop = atBottom ? element.scrollHeight : scroll;
  }
  toggle.onchange = () => {
    colored = toggle.checked;
    try { localStorage.setItem(colorPreference, String(colored)); } catch { /* Optional preference. */ }
    render();
  };
  return {
    append(text) {
      for (const line of String(text).split(/\r\n|[\r\n]/)) {
        if (line.trim()) lines.push(line); // Preserve table indentation and spacing.
        else if (lines.length && lines.at(-1) !== "") lines.push("");
      }
      lines = lines.slice(-800); render();
    },
    clear() { lines = []; render(); },
  };
}
