import { terminalTheme } from "../ui/quant/terminal-theme.js";

function equal(actual, expected) {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) throw Error(`${actual} != ${expected}`);
}

Deno.test("terminal follows the console palette for default, cursor and selection colors", () => {
  const theme = terminalTheme({ getPropertyValue: name => ` ${name} ` });
  equal(theme.background, "--q-console-bg");
  equal(theme.foreground, "--q-console-fg");
  equal(theme.cursor, "--q-console-accent");
  equal(theme.cursorAccent, theme.background);
  equal(theme.selectionForeground, theme.foreground);
  equal(theme.selectionBackground, "--q-console-selection");
  equal(theme.selectionInactiveBackground, theme.selectionBackground);
});

Deno.test("ANSI colors, including white text, follow the selected theme", () => {
  let mode = "light";
  const style = { getPropertyValue: name => `${mode}:${name}` };
  const light = terminalTheme(style);
  mode = "dark";
  const dark = terminalTheme(style);
  equal(Object.keys(light).length, 23);
  for (const key of Object.keys(light)) equal(dark[key], light[key].replace("light:", "dark:"));
  equal(light.brightWhite, light.foreground);
  equal(light.white, light.brightBlack);
  equal(light.red, light.brightRed);
  equal(light.blue, light.brightBlue);
});
