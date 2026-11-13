import { EditorState, Compartment } from "@codemirror/state";
import { EditorView, keymap, lineNumbers, highlightActiveLine, highlightActiveLineGutter, drawSelection, highlightSpecialChars, placeholder } from "@codemirror/view";
import { StreamLanguage, syntaxHighlighting, HighlightStyle, bracketMatching, indentOnInput, indentUnit } from "@codemirror/language";
import { defaultKeymap, history, historyKeymap, indentWithTab } from "@codemirror/commands";
import { searchKeymap, highlightSelectionMatches } from "@codemirror/search";
import { closeBrackets, closeBracketsKeymap } from "@codemirror/autocomplete";
import { tags } from "@lezer/highlight";
import { r } from "@codemirror/legacy-modes/mode/r";

export function createREditor(host, { onChange, onRun }) {
  const readOnly = new Compartment();
  let updating = false, locked = false, runnable = false;
  const frame = document.createElement("div"); frame.className = "q-code-frame";
  const toolbar = document.createElement("div"); toolbar.className = "q-code-toolbar";
  const title = document.createElement("span"); title.textContent = "R · Code for this step";
  const expand = document.createElement("button"); expand.type = "button"; expand.textContent = "Expand ⛶";
  expand.setAttribute("aria-expanded", "false"); expand.setAttribute("aria-label", "Expand R code editor");
  toolbar.append(title, expand);
  const editorHost = document.createElement("div"); editorHost.className = "q-code-surface";
  frame.append(toolbar, editorHost); host.append(frame);
  const dialog = document.createElement("dialog"); dialog.className = "q-code-dialog"; dialog.setAttribute("aria-label", "Expanded R code editor");
  const footer = document.createElement("div"); footer.className = "q-code-footer";
  const hint = document.createElement("span"); hint.textContent = "Esc to return · Tab to indent · Ctrl/Cmd+F to find";
  const run = document.createElement("button"); run.type = "button"; run.className = "q-primary"; run.textContent = "Run code";
  footer.append(hint, run); dialog.append(footer);
  document.querySelector("#quant-view").append(dialog);
  const highlight = HighlightStyle.define([
    { tag: tags.keyword, color: "var(--r-keyword)" }, { tag: tags.string, color: "var(--r-string)" },
    { tag: tags.comment, color: "var(--r-comment)", fontStyle: "italic" },
    { tag: [tags.number, tags.bool, tags.atom], color: "var(--r-number)" },
    { tag: tags.operator, color: "var(--r-operator)" }, { tag: tags.standard(tags.variableName), color: "var(--r-keyword)" },
  ]);
  const extensions = [
    lineNumbers(), highlightActiveLineGutter(), highlightActiveLine(), drawSelection(), highlightSpecialChars(),
    history(), indentOnInput(), bracketMatching(), closeBrackets(), highlightSelectionMatches(),
    StreamLanguage.define(r), syntaxHighlighting(highlight), indentUnit.of("  "),
    keymap.of([...closeBracketsKeymap, ...defaultKeymap, ...historyKeymap, ...searchKeymap, indentWithTab]),
    placeholder("Paste or type R code here…"),
    EditorView.contentAttributes.of({ "aria-label": "R code for this step", spellcheck: "false", autocapitalize: "off", autocorrect: "off" }),
    readOnly.of([EditorState.readOnly.of(false), EditorView.editable.of(true)]),
    EditorView.updateListener.of(update => {
      if (update.docChanged && !updating) onChange();
      run.disabled = locked || !runnable || !update.state.doc.toString().trim();
    }),
  ];
  const view = new EditorView({ parent: editorHost, state: EditorState.create({ extensions }) });
  const close = () => { if (dialog.open) dialog.close(); };
  dialog.addEventListener("close", () => {
    host.append(frame); expand.textContent = "Expand ⛶";
    expand.setAttribute("aria-expanded", "false"); expand.setAttribute("aria-label", "Expand R code editor");
    view.requestMeasure(); view.focus();
  });
  expand.onclick = () => {
    if (dialog.open) return close();
    dialog.prepend(frame); expand.textContent = "Collapse ↙";
    expand.setAttribute("aria-expanded", "true"); expand.setAttribute("aria-label", "Collapse R code editor");
    dialog.showModal(); view.requestMeasure(); view.focus();
  };
  run.onclick = () => { close(); onRun(); };
  return {
    getValue: () => view.state.doc.toString(),
    setValue(value, reset = false) {
      updating = true;
      if (reset) view.setState(EditorState.create({ doc: value, extensions }));
      else view.dispatch({ changes: { from: 0, to: view.state.doc.length, insert: value }, userEvent: "input" });
      updating = false; run.disabled = locked || !runnable || !value.trim();
    },
    setReadOnly(value) {
      locked = value;
      view.dispatch({ effects: readOnly.reconfigure([EditorState.readOnly.of(value), EditorView.editable.of(!value)]) });
      run.disabled = value || !runnable || !view.state.doc.toString().trim();
    },
    setRunnable(value) { runnable = value; run.disabled = !value || locked || !view.state.doc.toString().trim(); },
    focus: () => view.focus(),
    refresh: () => view.requestMeasure(),
    close,
  };
}
