import { fitPlot, zoomPlot, constrainPlot, panPlot } from "../ui/quant/plot-geometry.js";
import { classifyOutput, classifyLines, initializeOutput, colorPreference } from "../ui/quant/log.js";
function equal(a, b) { if (JSON.stringify(a) !== JSON.stringify(b)) throw Error(`${JSON.stringify(a)} != ${JSON.stringify(b)}`); }
Deno.test("Plot fits original pixels without stretching or unnecessary upscaling", () => {
  equal(fitPlot(2000, 1000, 1000, 800), { scale: .5, x: 0, y: 150 });
  equal(fitPlot(100, 100, 500, 400), { scale: 1, x: 200, y: 150 });
});
Deno.test("Plot zoom anchors image coordinates to the pointer, including repeated zoom", () => {
  const initial = { scale: .5, x: -100, y: 50 }, anchor = { x: 137, y: 263 };
  const zoomed = zoomPlot(initial, 2, anchor, .25);
  equal((anchor.x - zoomed.x) / zoomed.scale, (anchor.x - initial.x) / initial.scale);
  equal((anchor.y - zoomed.y) / zoomed.scale, (anchor.y - initial.y) / initial.scale);
  equal(zoomPlot(zoomed, .5, anchor, .25), initial);
  equal(zoomPlot(initial, 50, anchor, .25).scale, 8);
  equal(zoomPlot(initial, .01, anchor, .25).scale, .25);
});
Deno.test("Plot panning never loses the image outside the viewport", () => {
  equal(constrainPlot({scale: 2, x: -9999, y: 900}, 1000, 800, 500, 500), {scale: 2, x: -1500, y: 0});
  equal(constrainPlot({scale: .1, x: -9999, y: 900}, 1000, 800, 500, 500), {scale: .1, x: 200, y: 210});
});
Deno.test("WASD pans the viewing window and scales source-image jumps with zoom", () => {
  const view = {scale:2,x:-500,y:-500};
  equal(panPlot(view,"w",2000,2000,500,400),{scale:2,x:-500,y:-420});
  equal(panPlot(view,"a",2000,2000,500,400),{scale:2,x:-400,y:-500});
  equal(panPlot(view,"s",2000,2000,500,400),{scale:2,x:-500,y:-580});
  equal(panPlot(view,"D",2000,2000,500,400),{scale:2,x:-600,y:-500});
  const zoomed = {...view,scale:4};
  const jump = (v) => (v.x-panPlot(v,"d",2000,2000,500,400).x)/v.scale;
  equal(jump(zoomed),jump(view)/2);
  const fit = fitPlot(2000,2000,500,400);
  equal(panPlot(fit,"w",2000,2000,500,400),fit);
  equal(panPlot({scale:2,x:0,y:0},"w",2000,2000,500,400),{scale:2,x:0,y:0});
});
Deno.test("R smart colors recognize diagnostics and leave ordinary data uncolored", () => {
  for (const text of ["Error in foo(): bad argument", "Execution halted", "[ERROR] E123: failed", "✖ Missing column"]) equal(classifyOutput(text), "error");
  for (const text of ["Warning message:", "Warning in log(x): NaNs produced", "! QC checks skipped"]) equal(classifyOutput(text), "warning");
  equal(classifyOutput("ℹ 42 rows"), "info");
  equal(classifyOutput("✔ Import complete"), "success");
  for (const text of ["No errors found", 'print("Error")', "# A tibble: 10 × 4", "   1 SAMPLE1 22 0", '<script>alert("Error")</script>']) equal(classifyOutput(text), "plain");
  equal(classifyLines(["Warning messages:", "1: In log(x):", "  NaNs produced", "", "print(x)"]).map(l => l.kind), ["warning", "warning", "warning", "plain", "plain"]);
});
Deno.test("R colors default off, save preference, and clear without changing the preference", () => {
  const previous = globalThis.localStorage;
  const values = new Map();
  Object.defineProperty(globalThis, "localStorage", { configurable: true, value: { getItem: k => values.get(k), setItem: (k, v) => values.set(k, v) } });
  try {
    const element = { textContent: "", scrollHeight: 100, scrollTop: 0, clientHeight: 100 }, toggle = {};
    const output = initializeOutput(element, toggle);
    equal(toggle.checked, false);
    output.append("Error: literal <tag>\n  details"); equal(element.textContent, "Error: literal <tag>\n  details");
    toggle.checked = false; toggle.onchange(); equal(values.get(colorPreference), "false");
    output.clear(); equal(element.textContent, "");
    values.set(colorPreference, "true");
    const remembered = {}; initializeOutput(element, remembered); equal(remembered.checked, true);
  } finally { Object.defineProperty(globalThis, "localStorage", { configurable: true, value: previous }); }
});
Deno.test("Colored R output stays literal text and is bounded to 800 lines", () => {
  const previous = { document: globalThis.document, localStorage: globalThis.localStorage };
  const node = () => ({ children: [], textContent: "", append(child) { this.children.push(child); } });
  Object.defineProperty(globalThis, "document", { configurable: true, value: { createElement: node, createDocumentFragment: node } });
  Object.defineProperty(globalThis, "localStorage", { configurable: true, value: { getItem: () => "true", setItem() {} } });
  try {
    const element = { scrollHeight: 100, scrollTop: 0, clientHeight: 100, replaceChildren(fragment) { this.children = fragment.children; } };
    const output = initializeOutput(element, {});
    output.append('Error: <img src=x onerror="bad()">');
    equal(element.children[0].textContent, 'Error: <img src=x onerror="bad()">');
    equal(element.children[0].className, "q-log-error");
    output.append(Array.from({length: 900}, (_, i) => String(i)).join("\n"));
    equal(element.children.length, 800); equal(element.children[0].textContent, "100\n");
    output.clear(); equal(element.children.length, 0);
  } finally {
    for (const key of Object.keys(previous)) Object.defineProperty(globalThis, key, { configurable: true, value: previous[key] });
  }
});
Deno.test("R console compacts blank output in both color modes without changing aligned text", () => {
  const previous = { document: globalThis.document, localStorage: globalThis.localStorage };
  const node = () => ({ children: [], textContent: "", append(child) { this.children.push(child); } });
  Object.defineProperty(globalThis, "document", { configurable: true, value: { createElement: node, createDocumentFragment: node } });
  Object.defineProperty(globalThis, "localStorage", { configurable: true, value: { getItem: () => "false", setItem() {} } });
  try {
    const element = {textContent:"",scrollHeight:100,clientHeight:100,scrollTop:0,replaceChildren(fragment){this.children=fragment.children;}}, toggle = {};
    const output = initializeOutput(element, toggle);
    output.append("\n\r\n \t\n"); equal(element.textContent, "");
    output.append("Running Legacy step 1…\n\n\n");
    output.append(""); output.append("   ");
    output.append("R block completed. Session saved.\r\n\r\nWarning message:\n  check input\n\n  sample   intensity\n1 A        12.34\r2 B        56.78\n");
    const expected = "Running Legacy step 1…\nR block completed. Session saved.\nWarning message:\n  check input\n  sample   intensity\n1 A        12.34\n2 B        56.78";
    equal(element.textContent, expected);
    toggle.checked = true; toggle.onchange();
    equal(element.children.map(n=>n.textContent).join(""), expected);
    equal(element.children[3].className,"q-log-warning");
    equal(element.children[4].className,"q-log-plain");
    toggle.checked = false; toggle.onchange(); equal(element.textContent, expected);
  } finally {
    for (const key of Object.keys(previous)) Object.defineProperty(globalThis,key,{configurable:true,value:previous[key]});
  }
});
