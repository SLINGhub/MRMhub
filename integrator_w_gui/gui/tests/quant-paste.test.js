import { inspectRPaste, datasetImportCode } from "../ui/quant/paste.js";
import { pasteFixtures } from "./quant-paste-fixtures.js";
const table = 'print(mexp@dataset)\n# A tibble: 250,997 × 21\n   analysis_order analysis_id qc_type\n            <int> <chr> <chr>\n 1              1 Longit_BLANK SBLK\n# ℹ 250,987 more rows';
Deno.test("Copied tutorial tibble output is commented, not executed", () => {
  const result = inspectRPaste(table + '\nmexp <- normalize_by_istd(mexp)');
  if (!result.changed || result.outputLines !== 3 || !result.code.includes('#    analysis_order')) throw Error("Missed output");
  if (!result.code.endsWith('mexp <- normalize_by_istd(mexp)')) throw Error("Changed following R");
  if (inspectRPaste(result.code).changed) throw Error("Cleanup is not idempotent");
});
Deno.test("Only complete R fences are removed", () => {
  const code = '```{r chunk}\nx <- 1\n```';
  if (inspectRPaste(code).code.trim() !== 'x <- 1') throw Error("Fence kept");
  if (inspectRPaste('```python\nx = 1\n```').changed) throw Error("Changed another language");
});
Deno.test("Quoted examples and arbitrary R remain unchanged", () => {
  for (const code of ['label <- "' + table + '"', 'label <- r"---(' + table + ')---"', 'x <- c(1, 2)\n# A tibble: 1 × 1\nprint(x)', 'value <- "├── data"', '1 + 1\nprint("hello")']) {
    const result = inspectRPaste(code);
    if (result.changed || result.folderDiagram || result.code !== code) throw Error("Changed actual code: " + code);
  }
  if (!inspectRPaste('my_study/\n├── data/\n└── output/').folderDiagram) throw Error("Missed folder diagram");
});
Deno.test("Dataset import uses the selected directory, not tutorial paths", () => {
  const code = datasetImportCode('/test/My "study"');
  if (!code.includes('file.path(dataset_dir, "long.csv")') || !code.includes('title = "My \\"study\\""')) throw Error("Incorrect import");
});
for (const fixture of pasteFixtures) Deno.test(`Automatic cleanup: ${fixture.name}`, () => {
  const cleaned = inspectRPaste(fixture.pasted);
  const commands = cleaned.code.split('\n').filter(line => line.trim() && !/^\s*#/.test(line)).join('\n');
  if (commands !== fixture.expected || !cleaned.changed || !cleaned.executable) throw Error(JSON.stringify(cleaned));
  if (inspectRPaste(cleaned.code).changed) throw Error("Not idempotent");
  if (cleaned.code.split('\n').length !== fixture.pasted.split('\n').length) throw Error("Line numbers changed");
});
Deno.test("Automatic cleanup does not alter strings, NOT, numeric expressions or unknown prose", () => {
  for (const fixture of pasteFixtures) {
    const quoted = `example <- r"---(${fixture.pasted})---"`;
    if (inspectRPaste(quoted).changed) throw Error("Changed a raw-string example");
  }
  for (const code of ['! TRUE', '!is.na(x)', '! valid', 'ℹ <- 2', 'message("✔ Done")', 'x <- "✔ Done\n! Smoothing failed for 2 features"', 'Unknown console output', '-----x']) {
    if (inspectRPaste(code).changed) throw Error("Changed actual or unrecognized R: " + code);
  }
  for (const code of ['1 + 2', '1 -> x', '1 [1]', '1 # a numeric expression', '1 / 2', '1 |> sqrt()']) {
    const pasted = 'print(x)\n# A tibble: 1 × 1\n  value\n  <dbl>\n1 4\n' + code;
    if (!inspectRPaste(pasted).code.endsWith('\n' + code)) throw Error("Commented following R: " + code);
  }
});
Deno.test("Output-only pastes are not treated as executable code", () => {
  for (const code of ['✔ 20 features normalized.', '# A tibble: 1 × 1\n  value\n  <dbl>\n1 4', '```r\n# comment\n```']) {
    if (inspectRPaste(code).executable) throw Error("Output-only paste could create a no-op checkpoint");
  }
});
