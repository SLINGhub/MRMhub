// Run from the repo root with node. No dataset files are read or modified.
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { execFileSync } from "node:child_process";
import { inspectRPaste } from "../ui/quant/paste.js";
import { pasteFixtures } from "./quant-paste-fixtures.js";

const tutorial = readFileSync("vignettes/articles/tutorial-03-lipidomics-workflow.Rmd", "utf8");
const chunks = [...tutorial.matchAll(/^```\{r[^\n]*\}\n([\s\S]*?)^```/gm)].map(match => match[1]);
assert.ok(chunks.length >= 23);
for (const code of chunks) assert.equal(inspectRPaste(code).code, code, "Changed original tutorial code");
const cases = pasteFixtures.map(fixture => ({ name: fixture.name, cleaned: inspectRPaste(fixture.pasted).code, expected: fixture.expected }));
for (const [i, code] of chunks.entries()) cases.push({ name: `tutorial chunk ${i}`, cleaned: inspectRPaste(code).code, expected: code });
const rCases = cases.map(test => `list(name=${JSON.stringify(test.name)}, cleaned=${JSON.stringify(test.cleaned)}, expected=${JSON.stringify(test.expected)})`).join(',\n');
const r = `cases <- list(${rCases})
for (case in cases) {
  actual <- parse(text = case$cleaned, keep.source = FALSE)
  expected <- parse(text = case$expected, keep.source = FALSE)
  if (!identical(actual, expected)) stop(paste("R expressions changed:", case$name))
}
cat("PASS", length(cases), "R expression parity checks\\n")`;
process.stdout.write(execFileSync("Rscript", ["--vanilla", "-"], {
  input: r, encoding: "utf8",
  env: { ...process.env, LC_ALL: process.platform === "darwin" ? "en_US.UTF-8" : "C.UTF-8" },
}));
