import { createFrameQueue, createRequestGate, createVirtualCharts, validPeakRanges } from "./render-state.js";
import { createSelectionLoader } from "./selection-loader.js";
import { createFrameTask } from "./interactions.js";

const { invoke, Channel } = window.__TAURI__.core;
const plotRequests = createRequestGate();
const marginTop = 16;
const marginRight = 10;
const marginBottom = 14;
const marginLeft = 33;
const byId = (id) => document.getElementById(id);
let catalog = { samples: [], transitions: [], selections: new Map() };
let catalogGeneration = 0;
let display = null;
const loader = createSelectionLoader({ invoke, Channel, onChange: updateDisplay });
const redraw = createFrameTask(redrawDisplay);

function setStatus(message, error = false) {
  const status = byId("data_status");
  status.textContent = message;
  status.classList.toggle("error", error);
}

function disposeDisplay() {
  redraw.cancel();
  plotRequests.cancel();
  display?.virtual.dispose();
  display = null;
  byId("qc").replaceChildren();
  byId("container").replaceChildren();
}

async function readCatalog() {
  const token = ++catalogGeneration;
  const { references, transCsv, mzmlTsv, version } = await invoke("get_catalog");
  if (token !== catalogGeneration) return false;
  const transitions = d3.csvParseRows(transCsv).slice(1).filter((row) => row.length >= 4);
  for (const row of transitions) {
    row[0] = row[0].slice(1);
    row[1] = row[1].slice(0, 99);
  }
  const samples = d3.tsvParseRows(mzmlTsv).filter((row) => row[0]);
  for (const row of samples) row[0] = row[0].slice(0, -5);
  const selections = new Map();
  for (const name of references) selections.set("r:" + name, {
    kind: "reference", key: name, label: name.slice(3), count: transitions.length, catalogVersion: version,
  });
  for (const row of transitions) selections.set("t:" + row[0], {
    kind: "transition", key: row[0], label: row[1], row, count: samples.length, catalogVersion: version,
  });
  const old = byId("trans_sel").value;
  const options = document.createDocumentFragment();
  options.appendChild(new Option("--- Select ---", ""));
  for (const [value, selection] of selections) {
    options.appendChild(new Option(selection.kind === "reference"
      ? selection.label + ", REF" : selection.label + ", " + selection.key, value));
  }
  catalog = { samples, transitions, selections };
  byId("trans_sel").replaceChildren(options);
  byId("trans_sel").value = selections.has(old) ? old : "";
  byId("trans_sel").disabled = false;
  return true;
}

function selectionControls() {
  byId("row2").replaceChildren();
  if (catalog.selections.get(byId("trans_sel").value)?.kind !== "transition") return;
  // This fixed markup contains no data from the external folder.
  byId("row2").innerHTML = `
    <div>RT range:
      <input type="number" id="RT0" aria-label="RT range start" min="0" max="999" step="0.1" value="0" />
      to <input type="number" id="RT1" aria-label="RT range end" min="0" max="999" step="0.1" value="0" />
    </div>
    <div>Max. intensity:
      <input type="number" id="INT1" aria-label="Maximum intensity" min="0" max="999999999" step="1" value="0" />
    </div>`;
}

function numericInput(id, fallback = 0, min = 0, max = Infinity) {
  const value = byId(id)?.valueAsNumber;
  return Number.isFinite(value) ? Math.max(min, Math.min(max, value)) : fallback;
}

function plotSettings(selection) {
  const settings = {
    width: numericInput("c_width", 400, 200, 9999),
    height: numericInput("c_height", 120, 80, 9999),
    rt0: numericInput("RT0"), rt1: numericInput("RT1"), int1: numericInput("INT1"),
  };
  if (selection.kind !== "transition") settings.rt0 = settings.rt1 = settings.int1 = 0;
  else if (settings.rt1 <= settings.rt0) settings.rt0 = settings.rt1 = 0;
  return settings;
}

function beginDisplay(dataset) {
  disposeDisplay();
  const request = plotRequests.begin();
  const context = {
    request, ...plotSettings(dataset.selection),
    qcViews: [], traceViews: [], highlightedTraces: [], cleanups: new Set(),
  };
  request.onCancel(() => {
    for (const cleanup of context.cleanups) cleanup();
    context.cleanups.clear();
  });
  const { samples, transitions } = catalog;
  const qcRequests = createRequestGate();
  request.onCancel(() => qcRequests.cancel());
  const virtual = createVirtualCharts({
    container: byId("container"), count: dataset.selection.count,
    width: context.width, height: context.height,
    render(index) {
      const data = dataset.records[index];
      if (!data || !request.isCurrent()) return null;
      const id = dataset.selection.kind === "transition"
        ? samples[index] || [`Sample ${index + 1}`, "", "", "", ""]
        : [transitions[index]?.[1] || `Transition ${index + 1}`, "", "", "", ""];
      return genSvg(data, id, index, context);
    },
    onError(error) {
      if (request.isCurrent()) {
        request.cancel();
        setStatus(String(error), true);
      }
    },
  });
  display = { dataset, context, samples, virtual, qcRequests };
}

function drawQc() {
  if (!display) return;
  const current = display;
  const { dataset, context, samples, qcRequests } = current;
  const request = qcRequests.begin();
  for (const view of context.qcViews) view.dispose();
  context.qcViews = [];
  byId("qc").replaceChildren();
  if (!dataset.complete || dataset.selection.kind !== "transition") return;
  const queue = createFrameQueue({
    request,
    createBatch: () => document.createDocumentFragment(),
    renderItem({ key, name, values }, fragment) {
      const chart = genQc(key, name, values, samples, context);
      if (chart) fragment.append(chart.node);
    },
    commitBatch: (fragment) => byId("qc").append(fragment),
    onError(error) {
      if (display === current) setStatus(String(error), true);
    },
  });
  queue.push({ key: "RT shift", name: dataset.selection.label, values: dataset.records.map((record) => record.sh) });
  for (const [name, rows] of dataset.groups) {
    if (!rows.length) continue;
    for (const key of Object.keys(rows[0])) queue.push({ key, name, values: rows.map((row) => row[key]) });
  }
}

function redrawDisplay() {
  if (!display) return;
  const { context, dataset, virtual } = display;
  const settings = plotSettings(dataset.selection);
  const widthChanged = settings.width !== context.width;
  const sizeChanged = widthChanged || settings.height !== context.height;
  const rangeChanged = settings.rt0 !== context.rt0 || settings.rt1 !== context.rt1 || settings.int1 !== context.int1;
  Object.assign(context, settings);
  if (sizeChanged) virtual.resize(settings);
  else if (rangeChanged) virtual.refresh();
  if (widthChanged) drawQc();
}

function updateDisplay(dataset, event) {
  if (event.type === "clear") {
    disposeDisplay();
    byId("sel_analyte").textContent = "";
    setStatus("Select a transition or reference.");
  } else if (event.type === "start") {
    beginDisplay(dataset);
    setStatus(`Loading ${dataset.selection.label}…`);
  } else if (event.type === "batch" && display?.dataset === dataset) {
    for (let i = event.start; i < event.start + event.count; i++) display.virtual.refresh(i);
    setStatus(`Loaded ${dataset.loadedCount} of ${dataset.selection.count} chromatograms…`);
  } else if (event.type === "complete") {
    drawQc();
    setStatus(`Loaded ${dataset.loadedCount} chromatograms.`);
  } else if (event.type === "reuse") {
    if (display?.dataset !== dataset || !display.context.request.isCurrent()) {
      beginDisplay(dataset);
      drawQc();
    } else redrawDisplay();
    setStatus(`Loaded ${dataset.loadedCount} chromatograms. Data is up to date.`);
  } else if (event.type === "checking") {
    setStatus("Checking for updated data…");
  } else if (event.type === "error") {
    if (!dataset.complete) disposeDisplay();
    setStatus(`${dataset.error}${dataset.complete ? " Showing previously loaded data." : ""}`, true);
  }
}

async function selectCurrent(checkVersion = false) {
  const selection = catalog.selections.get(byId("trans_sel").value);
  if (!selection) {
    byId("row2").replaceChildren();
    loader.clear();
    return;
  }
  const row = selection.row;
  byId("sel_analyte").textContent = selection.kind === "reference" ? selection.label
    : `${row[1]} | ${row[2]}m/z${row[3].length > 1 ? ` | ${row[3]}m/z` : ""}`;
  await loader.select(selection, { checkVersion });
}

async function initialize() {
  byId("trans_sel").addEventListener("change", () => {
    catalogGeneration++;
    selectionControls();
    selectCurrent().catch((error) => setStatus(String(error), true));
  });
  byId("stick_top").addEventListener("change", (event) => {
    if (["c_width", "c_height", "RT0", "RT1", "INT1"].includes(event.target.id)) redraw.schedule();
  });
  byId("refreshb").addEventListener("click", async () => {
    setStatus("Checking for updated data…");
    try {
      if (await readCatalog()) await selectCurrent(true);
    } catch (error) {
      setStatus(String(error), true);
    }
  });
  try {
    if (await readCatalog()) setStatus(`Loaded ${catalog.transitions.length} transitions and ${catalog.samples.length} samples. Select a transition or reference.`);
  } catch (error) {
    setStatus(`${String(error)} Place the misc folder beside the executable, then restart the app.`, true);
  }
  byId("refreshb").disabled = false;
}
if (document.readyState === "loading") {
  window.addEventListener("DOMContentLoaded", initialize, { once: true });
} else {
  initialize();
}
window.addEventListener("beforeunload", () => {
  catalogGeneration++;
  loader.dispose();
  disposeDisplay();
  redraw.dispose();
});

function genQc(key, name, values, samples, context) {
  const validIndices = values.map((_, i) => i).filter((i) => Number.isFinite(values[i]));
  if (!validIndices.length) return;
  const { width } = context;
  const height = 200;
  const top = 23;
  const x = d3.scaleLinear().domain([1, Math.max(1, values.length)]).range([marginLeft, width - marginRight]);
  const extent = d3.extent(validIndices, (i) => values[i]);
  const y = (key.startsWith("area")
    ? d3.scaleSymlog().domain(extent)
    : d3.scaleLinear().domain([extent[0] - 0.05, extent[1] + 0.05]))
    .range([height - marginBottom, top]);
  const svg = chartSvg(width, height).style("cursor", "crosshair");
  svg.append("rect").attr("width", width).attr("height", height).style("fill", "none");
  svg.append("text").attr("x", "50%").attr("dominant-baseline", "text-before-edge")
    .attr("text-anchor", "middle").text(key + ", " + name);
  svg.append("g").attr("transform", `translate(${marginLeft})`)
    .call(d3.axisLeft(y).ticks(3, key === "area" ? "s" : "f").tickSize(0))
    .call((g) => g.select(".domain").remove()).attr("font-size", 12);
  const gx = svg.append("g").attr("transform", `translate(0,${height - marginBottom})`);
  const boundaries = [];
  for (let i = 0; i < values.length - 1; i++) {
    if (samples[i] && samples[i + 1] && samples[i][3] !== samples[i + 1][3]) boundaries.push(i + 1.5);
  }
  const gLine = svg.append("g").attr("stroke", "black").attr("stroke-opacity", 0.5)
    .selectAll("line").data(boundaries).join("line").attr("y1", y.range()[0]).attr("y2", y.range()[1]);
  const line = d3.line().defined(Number.isFinite).y((d) => y(d));
  const trace = svg.append("path").attr("opacity", 0.5).attr("fill", "none").attr("stroke", "black");
  const mark = svg.append("circle").attr("class", "samplec").attr("fill", "none")
    .attr("stroke", "red").attr("stroke-width", 5).attr("r", 7).attr("display", "none");
  const view = { mark, values, x, y, dispose };
  context.qcViews.push(view);
  context.qcHover = null;
  let active = true;
  let delaunay;
  let indexDirty = true;
  let zooming = false;
  const tooltip = svg.append("g").style("display", "none").style("pointer-events", "none");
  tooltip.append("rect").attr("width", width).attr("height", 20);
  const label = tooltip.append("text").attr("fill", "white").attr("x", "50%")
    .attr("text-anchor", "middle").attr("dominant-baseline", "text-before-edge");
  const isActive = () => active && context.request.isCurrent();
  const hideMarkers = () => {
    context.qcHover = null;
    for (const other of context.qcViews) other.mark.attr("display", "none");
  };
  const renderZoom = createFrameTask((transform) => {
    if (!isActive()) return;
    view.x = transform.rescaleX(x);
    gx.call(d3.axisBottom(view.x).tickSize(0).ticks(4)).attr("font-size", 12);
    gx.select(".domain").attr("opacity", 0.5);
    gLine.attr("x1", (d) => view.x(d)).attr("x2", (d) => view.x(d));
    trace.attr("d", line.x((_, i) => view.x(i + 1))(values));
    indexDirty = true;
  });
  const hover = createFrameTask((pointer) => {
    if (!isActive() || zooming) return;
    if (indexDirty) {
      // Keep the exact screen-space nearest point metric, but build only on hover.
      delaunay = d3.Delaunay.from(validIndices, (i) => view.x(i + 1), (i) => y(values[i]));
      indexDirty = false;
    }
    const index = validIndices[delaunay.find(...pointer)];
    if (context.qcHover?.view === view && context.qcHover.index === index) return;
    context.qcHover = { view, index };
    for (const other of context.qcViews) {
      const value = other.values[index];
      other.mark.attr("display", Number.isFinite(value) ? null : "none");
      if (Number.isFinite(value)) other.mark.attr("cx", other.x(index + 1)).attr("cy", other.y(value));
    }
    tooltip.style("display", null);
    label.text(samples[index]?.[0] || `Sample ${index + 1}`);
  });
  const zoom = d3.zoom().extent([[0, 0], [width, height]])
    .translateExtent([[0, -Infinity], [width, Infinity]]).scaleExtent([1, 9999])
    .on("start.chart", () => {
      if (!isActive()) return;
      zooming = true;
      hover.cancel();
      tooltip.style("display", "none");
      hideMarkers();
    })
    .on("zoom.chart", (event) => {
      if (isActive()) renderZoom.schedule(event.transform);
    })
    .on("end.chart", () => {
      if (!isActive()) return;
      renderZoom.flush();
      zooming = false;
    });
  svg.on("pointermove.chart", (event) => {
    if (isActive() && !zooming) hover.schedule(d3.pointer(event, svg.node()));
  }).on("pointerleave.chart", () => {
    hover.cancel();
    tooltip.style("display", "none");
    if (context.qcHover?.view === view) hideMarkers();
  });
  function dispose() {
    if (!active) return;
    active = false;
    hover.dispose();
    renderZoom.dispose();
    if (context.qcHover?.view === view) hideMarkers();
    svg.on(".chart", null).on(".zoom", null).interrupt();
    context.cleanups.delete(dispose);
  }
  context.cleanups.add(dispose);
  svg.call(zoom).call(zoom.transform, d3.zoomIdentity);
  return { node: svg.node(), dispose };
}

function chartSvg(width, height) {
  return d3.create("svg").attr("width", width).attr("height", height)
    .style("background", "white").style("border", "2px solid").style("border-radius", "8px");
}

function genSvg({ sh, pos_l = [], bl = [], te = [] }, id, index, context) {
  const { width, height, rt0, rt1, int1 } = context;
  const svg = chartSvg(width, height);
  svg.append("text").attr("x", "50%").attr("dominant-baseline", "text-before-edge")
    .attr("text-anchor", "middle").text(id[0]);
  if (!te.length || !te.every((point) => Number.isFinite(point.x) && Number.isFinite(point.y))) {
    svg.append("text").attr("x", "50%").attr("y", "50%").attr("text-anchor", "middle")
      .text(te.length ? "Invalid chromatogram data" : "No chromatogram data");
    return { node: svg.node() };
  }
  const bisect = d3.bisector((d) => d.x).center;
  const rti0 = rt0 === 0 ? 0 : bisect(te, rt0);
  const rti1 = rt1 === 0 ? te.length - 1 : bisect(te, rt1);
  const x = d3.scaleLinear().domain([te[rti0].x, te[rti1].x]).range([marginLeft, width - marginRight]);
  let region = te.slice(pos_l[0], pos_l[pos_l.length - 1]);
  if (!region.length) region = te;
  const maxIntensity = int1 === 0 ? d3.max(region, (d) => d.y)
    : Math.min(int1, d3.max(te.slice(rti0, rti1 + (rti0 === rti1 ? 1 : 0)), (d) => d.y));
  const y = d3.scaleLinear().domain([0, 1.1 * (maxIntensity > 0 ? maxIntensity : 1)])
    .range([height - marginBottom, marginTop]);
  svg.append("g").attr("transform", `translate(0,${height - marginBottom})`)
    .call(d3.axisBottom(x).tickSize(0)).call((g) => g.select(".domain").attr("opacity", 0.5))
    .call((g) => g.selectAll(".tick:nth-of-type(odd)").remove()).attr("font-size", 12);
  svg.append("g").attr("transform", `translate(${marginLeft})`)
    .call(d3.axisLeft(y).ticks(2, "s").tickSize(0)).call((g) => g.select(".domain").remove()).attr("font-size", 12);
  const line = d3.line().x((d) => x(d.x)).y((d) => y(d.y));
  for (const { begin, end, offset } of validPeakRanges(pos_l, te.length)) {
    const color = d3.schemeCategory10[(offset / 2) % 10];
    if (Number.isFinite(bl[offset]) && Number.isFinite(bl[offset + 1])) {
      svg.append("path").attr("fill", color).attr("opacity", 0.6).attr("d",
        line([...te.slice(begin, end), { x: te[end - 1].x, y: bl[offset + 1] }, { x: te[begin].x, y: bl[offset] }]) + "Z");
    }
    svg.append("rect").attr("fill", color).attr("opacity", 0.3)
      .attr("x", x(te[begin].x)).attr("y", y.range()[1])
      .attr("width", x(te[end - 1].x) - x(te[begin].x)).attr("height", y.range()[0] - y.range()[1]);
  }
  if (id[4] === "1") {
    svg.append("rect").attr("width", "100%").attr("height", marginTop).attr("fill", "#FF000080");
    svg.select("text").raise();
  }
  if (id[4]) svg.append("text").attr("x", "99%").attr("dominant-baseline", "text-before-edge")
    .attr("text-anchor", "end").text(id[4] === "1" ? "REF" : d3.format(".2f")(sh));
  const sampleType = id[1] || "";
  if (sampleType.includes("BLK")) svg.append("text").attr("y", "50%").attr("x", "50%")
    .attr("text-anchor", "middle").attr("dominant-baseline", "central")
    .attr("font-size", height).attr("opacity", 0.2).text(sampleType);
  svg.append("path").attr("class", "chromatogram-trace").attr("fill", "none")
    .attr("stroke", "black").attr("d", line(te));
  const tooltip = svg.append("g").style("display", "none").style("pointer-events", "none");
  const dot = tooltip.append("circle").attr("r", 3);
  tooltip.append("rect").attr("width", 55).attr("height", marginTop + 4).attr("x", -27.5).attr("rx", 4);
  const label = tooltip.append("text").attr("text-anchor", "middle")
    .attr("dominant-baseline", "text-before-edge").attr("fill", "white");
  const cursor = svg.append("line").attr("class", "tl").attr("y1", "100%").attr("y2", y.range()[1])
    .style("display", "none").attr("stroke", "black").attr("opacity", 0.5).attr("stroke-width", 2);
  const view = { cursor, x };
  context.traceViews[index] = view;
  context.traceRevision = (context.traceRevision || 0) + 1;
  let active = true;
  let lastPoint = -1;
  let lastRevision = -1;
  const formatTime = d3.format(".3f");
  const hideCursors = () => {
    for (const other of context.highlightedTraces) other.cursor.style("display", "none");
    context.highlightedTraces = [];
    context.traceHover = null;
  };
  const hover = createFrameTask((pointerX) => {
    if (!active || !context.request.isCurrent()) return;
    const pointIndex = bisect(te, x.invert(pointerX));
    if (pointIndex === lastPoint && context.traceRevision === lastRevision && context.traceHover === view) return;
    const point = te[pointIndex];
    label.text(formatTime(point.x));
    tooltip.attr("transform", `translate(${x(point.x)})`).style("display", null);
    dot.attr("cy", y(point.y));
    hideCursors();
    context.traceHover = view;
    const radius = id[4] ? 49 : 0;
    for (let i = Math.max(0, index - radius); i <= index + radius; i++) {
      const other = context.traceViews[i];
      if (!other) continue;
      const cx = other.x(point.x);
      other.cursor.style("display", null).attr("x1", cx).attr("x2", cx);
      context.highlightedTraces.push(other);
    }
    lastPoint = pointIndex;
    lastRevision = context.traceRevision;
  });
  svg.on("pointerenter.chart pointermove.chart", (event) => {
    if (active && context.request.isCurrent()) hover.schedule(d3.pointer(event, svg.node())[0]);
  }).on("pointerleave.chart", () => {
    hover.cancel();
    lastPoint = -1;
    tooltip.style("display", "none");
    if (context.traceHover === view) hideCursors();
  });
  function dispose() {
    if (!active) return;
    active = false;
    hover.dispose();
    if (context.traceHover === view) hideCursors();
    if (context.traceViews[index] === view) context.traceViews[index] = undefined;
    context.highlightedTraces = context.highlightedTraces.filter((other) => other !== view);
    context.traceRevision++;
    svg.on(".chart", null);
    context.cleanups.delete(dispose);
  }
  context.cleanups.add(dispose);
  return { node: svg.node(), dispose };
}
