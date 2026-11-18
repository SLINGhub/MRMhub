import { Terminal } from "@xterm/xterm";
import { FitAddon } from "@xterm/addon-fit";
import "@xterm/xterm/css/xterm.css";
import { terminalTheme } from "../ui/quant/terminal-theme.js";

// Export only stable public APIs; no commands or clipboard escape handlers.
export function createTerminal(host, onInput, onResize) {
  const terminal = new Terminal({
    cursorBlink: true, scrollback: 5000, fontSize: 13,
    fontFamily: "ui-monospace, SFMono-Regular, Consolas, monospace",
    allowProposedApi: false, screenReaderMode: true,
    theme: terminalTheme(getComputedStyle(host)),
  });
  const fit = new FitAddon(); terminal.loadAddon(fit); terminal.open(host);
  terminal.onData(onInput);
  terminal.onResize(({ cols, rows }) => onResize(cols, rows));
  let frame;
  const resize = () => {
    cancelAnimationFrame(frame);
    frame = requestAnimationFrame(() => { if (host.clientWidth && host.clientHeight) fit.fit(); });
  };
  const resizeObserver = new ResizeObserver(resize);
  resizeObserver.observe(host);
  const themeObserver = new MutationObserver(() => {
    terminal.options.theme = terminalTheme(getComputedStyle(host));
  });
  themeObserver.observe(document.documentElement, { attributes: true, attributeFilter: ["data-theme"] });
  document.fonts.ready.then(resize);
  return { terminal, resize, dispose() {
    cancelAnimationFrame(frame); resizeObserver.disconnect(); themeObserver.disconnect(); terminal.dispose();
  } };
}
