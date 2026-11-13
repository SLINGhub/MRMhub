import { build } from "esbuild";
import { readFile, writeFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
const base = fileURLToPath(new URL(".", import.meta.url));
for (const [entry, licenseFile] of [["r-editor", "EDITOR"], ["terminal", "TERMINAL"]]) {
const result = await build({ absWorkingDir: base, entryPoints: [`${entry}.js`], bundle: true, format: "esm", target: "es2020", minify: true, metafile: true, outfile: `../ui/quant/${entry}.bundle.js`, legalComments: "eof" });
const names = new Set(Object.keys(result.metafile.inputs).filter(p => p.startsWith("node_modules/")).map(p => p.split("/").slice(1, p.split("/")[1].startsWith("@") ? 3 : 2).join("/")));
const licenses = await Promise.all([...names].sort().map(async name => `${name}\n${await readFile(new URL(`node_modules/${name}/LICENSE`, import.meta.url), "utf8")}`));
await writeFile(new URL(`../ui/quant/${licenseFile}-LICENSES.txt`, import.meta.url), licenses.join("\n\n---\n\n"));
}
