// Share the console's CSS palette with xterm, including ANSI colors that would
// otherwise stay pale/invisible on a light background. Never reset the buffer.
export function terminalTheme(style) {
  const color = name => style.getPropertyValue(`--q-console-${name}`).trim();
  return {
    background: color("bg"), foreground: color("fg"),
    cursor: color("accent"), cursorAccent: color("bg"),
    selectionBackground: color("selection"), selectionForeground: color("fg"),
    selectionInactiveBackground: color("selection"),
    black: color("black"), red: color("error"), green: color("success"),
    yellow: color("warning"), blue: color("info"), magenta: color("magenta"),
    cyan: color("accent"), white: color("muted"),
    brightBlack: color("muted"), brightRed: color("error"), brightGreen: color("success"),
    brightYellow: color("warning"), brightBlue: color("info"), brightMagenta: color("magenta"),
    brightCyan: color("accent"), brightWhite: color("fg"),
  };
}
