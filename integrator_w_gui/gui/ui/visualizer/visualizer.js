import { referenceBounds } from "./reference-bounds.js";

const { invoke, Channel } = window.__TAURI__.core;
const dialog = window.__TAURI__.dialog;
const d3 = window.d3;
const decoder = new TextDecoder();
const originalRtMatrix = "RT_matrix_original.csv";
const formatRt = d3.format(".2f");
const formatIntensity = d3.format(",.0f");
const sampleTypeColorPreference = "mrmhub-visualizer-color-sample-types";
const sampleTypePalette = [
  "#1f77b4",
  "#e67e22",
  "#2ca02c",
  "#d62770",
  "#7b61a8",
  "#8c564b",
  "#008c95",
  "#bc8f00",
  "#4f6bed",
  "#c23b22",
];

const elements = {
  transition: document.querySelector("#visualizer-transition"),
  transitionSearch: document.querySelector("#visualizer-transition-search"),
  width: document.querySelector("#visualizer-width"),
  height: document.querySelector("#visualizer-height"),
  colorSampleTypes: document.querySelector("#visualizer-color-sample-types"),
  exportPngs: document.querySelector("#visualizer-export-pngs"),
  exportPngsWrap: document.querySelector("#visualizer-export-wrap"),
  sampleTypeLegend: document.querySelector("#visualizer-sample-type-legend"),
  applyShared: document.querySelector("#visualizer-apply-shared"),
  refresh: document.querySelector("#visualizer-refresh"),
  save: document.querySelector("#visualizer-save"),
  deleteBackup: document.querySelector("#visualizer-delete-backup"),
  renameBackup: document.querySelector("#visualizer-rename-backup"),
  importBackup: document.querySelector("#visualizer-import-backup"),
  backups: document.querySelector("#visualizer-backups"),
  range: document.querySelector("#visualizer-range"),
  rtStart: document.querySelector("#visualizer-rt-start"),
  rtEnd: document.querySelector("#visualizer-rt-end"),
  intensity: document.querySelector("#visualizer-intensity"),
  globalShortcuts: document.querySelector("#visualizer-shortcuts-global"),
  analyte: document.querySelector("#visualizer-analyte"),
  status: document.querySelector("#visualizer-status"),
  cancelRender: document.querySelector("#visualizer-cancel-render"),
  qc: document.querySelector("#visualizer-qc"),
  plots: document.querySelector("#visualizer-plots"),
  toolbar: document.querySelector(".visualizer-toolbar"),
  selectorExpand: document.querySelector("#visualizer-selector-expand"),
  view: document.querySelector("#visualizer-view"),
};

const state = {
  projectPath: null,
  references: [],
  transitions: [],
  samples: [],
  initialized: false,
  loading: false,
  renderToken: 0,
  qcGraphs: [],
  traceGraphs: [],
  traceRecords: [],
  visibleTraceRecords: new Set(),
  traceObserver: null,
  traceMountQueue: [],
  traceMountFrame: 0,
  traceEvictionTimer: 0,
  traceRedrawFrame: 0,
  virtualizedTraces: false,
  hoveredGraph: null,
  rangeManuallySet: false,
  backupLabels: {},
  transitionSearch: "",
  chartId: 0,
  selectedIsomerIndex: null,
  fontScale: 1,
  colorSampleTypes: false,
  sampleTypeColors: new Map(),
  referenceChoices: new Map(),
  exportingPngs: false,
  renderComplete: false,
};

const margins = {
  top: 18,
  right: 10,
  bottom: 18,
  left: 38,
};

const traceBatchSize = 4;
const traceBatchBudgetMs = 10;
const traceVirtualizationThreshold = 1000;
const maxMountedTraceCanvases = 48;
const traceObserverMargin = 640;
const maxHoverDots = 420;
const maxAreaPathPoints = 420;
const maxDragAreaPathPoints = 140;
const viewportRenderMargin = 260;

// reads small visualizer preferences without letting disabled storage prevent
// the visualizer from opening.
function storedPreference(key) {
  try {
    return localStorage.getItem(key);
  } catch {
    return null;
  }
}

function rememberPreference(key, value) {
  try {
    localStorage.setItem(key, String(value));
  } catch {}
}

// keeps plot padding proportional to the selected text size.
function updatePlotMargins() {
  margins.top = Math.round(18 * state.fontScale);
  margins.right = Math.round(10 * state.fontScale);
  margins.bottom = Math.round(18 * state.fontScale);
  margins.left = Math.round(38 * state.fontScale);
}

function applyVisualizerScale() {
  // The application shell now scales the entire native webview. Keep graph
  // geometry at its base size so the visualizer is not enlarged twice.
  state.fontScale = 1;
  elements.view?.style.setProperty("--visualizer-font-scale", "1");
  updatePlotMargins();
}

function sampleTypeOf(sample) {
  return sample?.[1]?.trim() || "Unspecified";
}

function rebuildSampleTypeColors() {
  state.sampleTypeColors.clear();
  for (const sample of state.samples) {
    const type = sampleTypeOf(sample);
    if (!state.sampleTypeColors.has(type)) {
      state.sampleTypeColors.set(
        type,
        sampleTypePalette[state.sampleTypeColors.size % sampleTypePalette.length],
      );
    }
  }
}

function renderSampleTypeLegend() {
  elements.sampleTypeLegend.replaceChildren();
  elements.sampleTypeLegend.classList.toggle("hidden", !state.colorSampleTypes);
  if (!state.colorSampleTypes) return;
  const fragment = document.createDocumentFragment();
  for (const [type, color] of state.sampleTypeColors) {
    const item = document.createElement("span");
    item.className = "sample-type-legend-item";
    const swatch = document.createElement("span");
    swatch.className = "sample-type-swatch";
    swatch.style.setProperty("--sample-type-color", color);
    const label = document.createElement("span");
    label.textContent = type;
    item.append(swatch, label);
    fragment.append(item);
  }
  elements.sampleTypeLegend.append(fragment);
}

function applySampleTypeColorPreference(enabled, persist = true) {
  state.colorSampleTypes = Boolean(enabled);
  elements.colorSampleTypes.checked = state.colorSampleTypes;
  if (persist) rememberPreference(sampleTypeColorPreference, state.colorSampleTypes);
  renderSampleTypeLegend();
}

applyVisualizerScale();
applySampleTypeColorPreference(
  storedPreference(sampleTypeColorPreference) === "true",
  false,
);

// updates the visible visualizer status text
function setStatus(message, options = {}) {
  const cancellable = Boolean(options.cancellable);
  elements.status.textContent = message;
  elements.status.classList.toggle("is-cancellable", cancellable);
  elements.status.title = cancellable
    ? "Click to stop rendering the remaining plots"
    : "";
  elements.cancelRender?.classList.toggle("hidden", !cancellable);
}

// drops a trailing .mzML so sample names compare regardless of extension/case
function stripMzml(name) {
  return typeof name === "string" ? name.replace(/\.mzML$/i, "") : name;
}

// creates one option without constructing html from dataset text
function appendOption(fragment, text, value) {
  const option = document.createElement("option");
  option.textContent = text;
  option.value = value;
  fragment.append(option);
}

// fills the transition chooser from compact metadata only
function populateTransitions() {
  const query = state.transitionSearch.trim().toLowerCase();
  const matches = (text) => !query || text.toLowerCase().includes(query);
  const previousValue = elements.transition.value;
  const fragment = document.createDocumentFragment();
  appendOption(fragment, "Select a transition", "");
  let matchCount = 0;
  state.references.forEach((reference, index) => {
    const label = `${reference.slice(3)}, REF`;
    if (matches(label)) {
      appendOption(fragment, label, `r:${index}`);
      matchCount += 1;
    }
  });
  state.transitions.forEach((transition, index) => {
    const label = `${transition.name}, ${transition.cqq}`;
    if (matches(label)) {
      appendOption(fragment, label, `t:${index}`);
      matchCount += 1;
    }
  });
  if (query && matchCount === 0) {
    appendOption(fragment, `No matches for "${state.transitionSearch}"`, "");
  }
  elements.transition.replaceChildren(fragment);
  if (
    previousValue &&
    [...elements.transition.options].some((option) => option.value === previousValue)
  ) {
    elements.transition.value = previousValue;
  }
}

// applies the typed transition/reference filter. Multiple event types are used
// because macOS WKWebView can be inconsistent with search/text input events.
function applyTransitionSearch() {
  state.transitionSearch = elements.transitionSearch.value ?? "";
  populateTransitions();
}

// releases all per-graph arrays and dom nodes
export function clearPlots() {
  state.renderToken += 1;
  state.renderComplete = false;
  state.hoveredGraph = null;
  if (state.traceMountFrame) cancelAnimationFrame(state.traceMountFrame);
  if (state.traceRedrawFrame) cancelAnimationFrame(state.traceRedrawFrame);
  if (state.traceEvictionTimer) clearTimeout(state.traceEvictionTimer);
  state.traceMountFrame = 0;
  state.traceRedrawFrame = 0;
  state.traceEvictionTimer = 0;
  state.traceMountQueue.length = 0;
  state.traceObserver?.disconnect();
  state.traceObserver = null;
  for (const record of state.traceRecords) {
    disposeTraceRecord(record, false);
    if (record.shell) record.shell.__mrmhubTraceRecord = null;
  }
  state.traceRecords.length = 0;
  state.visibleTraceRecords.clear();
  state.virtualizedTraces = false;
  state.qcGraphs.length = 0;
  state.traceGraphs.length = 0;
  elements.qc.replaceChildren();
  elements.plots.replaceChildren();
}

// Enables full plot virtualization only when the selection is large enough to
// make thousands of Retina canvas backing stores a material memory cost.
function configureTraceVirtualization(expectedPlots) {
  state.virtualizedTraces =
    expectedPlots >= traceVirtualizationThreshold &&
    typeof IntersectionObserver === "function";
  if (!state.virtualizedTraces) return;
  state.traceObserver = new IntersectionObserver(
    (entries) => {
      for (const entry of entries) {
        const record = entry.target.__mrmhubTraceRecord;
        if (!record) continue;
        record.visible = entry.isIntersecting;
        if (entry.isIntersecting) {
          record.lastVisible = performance.now();
          state.visibleTraceRecords.add(record);
          if (record.graph) record.graph.applySampleTypeColor?.();
          else scheduleTraceRecordMount(record);
        } else {
          state.visibleTraceRecords.delete(record);
        }
      }
      scheduleTraceEviction();
    },
    { rootMargin: `${traceObserverMargin}px 0px` },
  );
}

function tracePlaceholder(record, label = "Plot ready when scrolled into view") {
  const placeholder = document.createElement("div");
  placeholder.className = "visualizer-chart virtualized-trace-placeholder";
  placeholder.style.width = `${record.width}px`;
  placeholder.style.height = `${record.height}px`;
  placeholder.textContent = label;
  return placeholder;
}

// Packs streamed object points immediately so the render queue never retains a
// second, much larger object representation while waiting for a WebView frame.
function createTraceRecord(job) {
  const dimensions = graphDimensions();
  const points = packPoints(job.plot.te ?? []);
  job.plot.te = null;
  const shell = document.createElement("div");
  shell.className = "visualizer-chart-shell is-virtual-placeholder";
  shell.style.width = `${dimensions.width}px`;
  shell.style.minHeight = `${dimensions.height + 20}px`;
  const record = {
    ...job,
    width: dimensions.width,
    height: dimensions.height,
    points,
    shell,
    graph: null,
    editRts: new Map(),
    zoomTransform: null,
    ySliderValue: null,
    visible: !state.virtualizedTraces,
    mountQueued: false,
    unrenderable: points.length < 4,
    lastVisible: performance.now(),
  };
  shell.__mrmhubTraceRecord = record;
  shell.replaceChildren(
    tracePlaceholder(
      record,
      record.unrenderable ? "No trace data" : "Plot ready when scrolled into view",
    ),
  );
  job.container.append(shell);
  state.traceRecords.push(record);
  if (state.virtualizedTraces) {
    state.traceObserver.observe(shell);
  }
  return record;
}

function mountTraceRecord(record, options = {}) {
  if (record.graph || record.unrenderable) return record.graph;
  const transient = Boolean(options.transient);
  const shell = transient ? document.createElement("div") : record.shell;
  const graph = renderTrace(
    record.plot,
    record.sample,
    record.index,
    record.container,
    record.isReference,
    record.editContext,
    {
      shell,
      points: record.points,
      record,
      transient,
    },
  );
  if (!transient && graph) {
    record.graph = graph;
    record.lastVisible = performance.now();
    shell.classList.remove("is-virtual-placeholder");
  }
  return graph;
}

function pumpTraceMountQueue() {
  state.traceMountFrame = 0;
  const started = performance.now();
  let mounted = 0;
  while (
    state.traceMountQueue.length &&
    mounted < traceBatchSize &&
    performance.now() - started < traceBatchBudgetMs
  ) {
    const record = state.traceMountQueue.shift();
    record.mountQueued = false;
    if (record.visible && !record.graph) {
      mountTraceRecord(record);
      mounted += 1;
    }
  }
  if (state.traceMountQueue.length) {
    state.traceMountFrame = requestAnimationFrame(pumpTraceMountQueue);
  }
  scheduleTraceEviction();
}

function scheduleTraceRecordMount(record) {
  if (!state.virtualizedTraces || record.graph || record.mountQueued || record.unrenderable) {
    return;
  }
  record.mountQueued = true;
  state.traceMountQueue.push(record);
  if (!state.traceMountFrame) {
    state.traceMountFrame = requestAnimationFrame(pumpTraceMountQueue);
  }
}

function disposeTraceRecord(record, restorePlaceholder = true) {
  const graph = record.graph;
  if (!graph) return;
  record.zoomTransform = graph.zoomTransform
    ? {
        k: graph.zoomTransform.k,
        x: graph.zoomTransform.x,
        y: graph.zoomTransform.y,
      }
    : null;
  record.ySliderValue = graph.ySlider?.value ?? record.ySliderValue;
  if (state.hoveredGraph === graph) state.hoveredGraph = null;
  if (graph.svg) {
    graph.svg
      .on(".zoom", null)
      .on("pointerdown pointermove pointerup pointercancel pointerleave", null);
  }
  if (graph.canvas) {
    // Explicitly dropping the backing dimensions is important on WKWebView,
    // where detached Retina canvases can otherwise retain their GPU memory.
    graph.canvas.width = 0;
    graph.canvas.height = 0;
  }
  const graphIndex = state.traceGraphs.indexOf(graph);
  if (graphIndex >= 0) state.traceGraphs.splice(graphIndex, 1);
  record.graph = null;
  if (restorePlaceholder && record.shell?.isConnected) {
    record.shell.classList.add("is-virtual-placeholder");
    record.shell.replaceChildren(tracePlaceholder(record));
  }
}

function evictOffscreenTraceRecords() {
  state.traceEvictionTimer = 0;
  if (!state.virtualizedTraces || state.exportingPngs) return;
  const mounted = state.traceRecords.filter((record) => record.graph);
  if (mounted.length <= maxMountedTraceCanvases) return;
  mounted
    .filter((record) => !record.visible)
    .sort((left, right) => left.lastVisible - right.lastVisible)
    .slice(0, mounted.length - maxMountedTraceCanvases)
    .forEach((record) => disposeTraceRecord(record));
}

function scheduleTraceEviction() {
  if (!state.virtualizedTraces || state.traceEvictionTimer) return;
  state.traceEvictionTimer = window.setTimeout(evictOffscreenTraceRecords, 350);
}

// adds a unique clip region so zoomed data stays inside the plotting area
function addPlotClip(svg, width, height, top = margins.top) {
  const id = `visualizer-clip-${state.chartId}`;
  state.chartId += 1;
  svg
    .append("defs")
    .append("clipPath")
    .attr("id", id)
    .append("rect")
    .attr("x", margins.left)
    .attr("y", top)
    .attr("width", Math.max(0, width - margins.left - margins.right))
    .attr("height", Math.max(0, height - top - margins.bottom));
  return `url(#${id})`;
}

// remembers the pointer position used by keyboard and wheel zoom
function trackGraphPointer(graph, event, width) {
  graph.hoverX = Math.max(
    margins.left,
    Math.min(width - margins.right, d3.pointer(event)[0]),
  );
  state.hoveredGraph = graph;
}

// clears the active keyboard zoom target without affecting other graphs
function releaseGraphPointer(graph) {
  if (state.hoveredGraph === graph) {
    state.hoveredGraph = null;
  }
}

// limits zoom to the wheel so dragging cannot pull data outside its graph
function wheelZoom(width, height, onZoom) {
  return d3
    .zoom()
    .filter((event) => event.type === "wheel")
    .scaleExtent([1, 1000])
    .extent([
      [margins.left, margins.top],
      [width - margins.right, height - margins.bottom],
    ])
    .translateExtent([
      [margins.left, margins.top],
      [width - margins.right, height - margins.bottom],
    ])
    .on("zoom", onZoom);
}

// discards cached per-project state so switching datasets cannot leave a
// previous dataset's graphs, transitions, or backup versions on screen
export function resetVisualizer() {
  clearPlots();
  state.projectPath = null;
  state.initialized = false;
  state.references.length = 0;
  state.transitions.length = 0;
  state.samples.length = 0;
  state.backupLabels = {};
  state.sampleTypeColors.clear();
  state.referenceChoices.clear();
  renderSampleTypeLegend();
  const transitions = document.createDocumentFragment();
  appendOption(transitions, "Select a transition", "");
  elements.transition.replaceChildren(transitions);
  const backups = document.createDocumentFragment();
  appendOption(backups, "No saved versions yet", "");
  elements.backups.replaceChildren(backups);
  setRangeControlsDisabled(true);
  updateSaveButton();
  updateDeleteButton();
  setStatus("Select a dataset in the Integrator first.");
}

// loads only the small dataset indexes needed by the chooser
export async function initializeVisualizer(projectPath) {
  if (state.projectPath === projectPath && state.initialized) {
    setStatus("Ready");
    await refreshBackups();
    return;
  }

  clearPlots();
  state.projectPath = projectPath;
  state.initialized = false;
  state.references.length = 0;
  state.transitions.length = 0;
  state.samples.length = 0;
  state.referenceChoices.clear();
  setStatus("Loading dataset index...");

  const [references, transitionBytes, sampleBytes] = await Promise.all([
    invoke("visualizer_get_ref", { projectPath }),
    invoke("visualizer_trans_csv", { projectPath }),
    invoke("visualizer_mzml_tsv", { projectPath }),
  ]);

  state.references = references;
  state.transitions = d3
    .csvParseRows(decoder.decode(transitionBytes))
    .slice(1)
    .map((row) => ({
      cqq: row[0]?.slice(1) ?? "",
      name: row[1]?.slice(0, 99) ?? "",
      precursor: row[2] ?? "",
      product: row[3] ?? "",
    }));
  state.samples = d3
    .tsvParseRows(decoder.decode(sampleBytes))
    .map((row) => {
      row[0] = row[0]?.endsWith(".mzML") ? row[0].slice(0, -5) : row[0];
      return row;
    });
  rebuildSampleTypeColors();
  renderSampleTypeLegend();

  populateTransitions();
  await refreshBackups();
  state.initialized = true;
  setStatus(
    `${state.transitions.length.toLocaleString()} transitions and ${state.samples.length.toLocaleString()} samples ready`,
  );
}

// returns the graph dimensions without retaining input elements
function graphDimensions() {
  const scale = state.fontScale;
  return {
    width: Math.round(
      Math.max(240, Math.min(1600, elements.width.valueAsNumber || 400)) * scale,
    ),
    height: Math.round(
      Math.max(100, Math.min(1000, elements.height.valueAsNumber || 160)) * scale,
    ),
  };
}

// keeps the current graph text size as the maximum, only shrinking labels when
// the graph is squeezed below the default dimensions
function graphFontScale(width, height, baseWidth = 400, baseHeight = 160) {
  return (
    state.fontScale *
    Math.max(
      0.68,
      Math.min(
        1,
        width / (baseWidth * state.fontScale),
        height / (baseHeight * state.fontScale),
      ),
    )
  );
}

// reads and normalizes the optional manual graph range
function graphRange() {
  let start = elements.rtStart.valueAsNumber || 0;
  let end = elements.rtEnd.valueAsNumber || 0;
  if (end <= start) {
    start = 0;
    end = 0;
  }
  return {
    start,
    end,
    intensity: elements.intensity.valueAsNumber || 0,
  };
}

// disables graph range inputs while plots are unavailable or actively rendering
function setRangeControlsDisabled(disabled) {
  elements.rtStart.disabled = disabled;
  elements.rtEnd.disabled = disabled;
  elements.intensity.disabled = disabled;
}

// applies the global maximum-intensity field to every rendered chromatogram
function applyGlobalIntensity() {
  const maximum = elements.intensity.valueAsNumber || 0;
  for (const record of state.traceRecords) {
    record.ySliderValue = null;
  }
  for (const graph of state.traceGraphs) {
    graph.applyGlobalYMaximum?.(maximum);
  }
}

// fills RT range inputs from the full chromatogram span when the user has not
// manually chosen a narrower range.
function applyDetectedRtRange(minimum, maximum) {
  if (
    state.rangeManuallySet ||
    !Number.isFinite(minimum) ||
    !Number.isFinite(maximum) ||
    maximum <= minimum
  ) {
    return;
  }
  elements.rtStart.value = formatRt(minimum);
  elements.rtEnd.value = formatRt(maximum);
}

// finds the closest retention-time index in a compact typed array
function nearestPackedIndex(points, target) {
  const count = points.length / 2;
  let low = 0;
  let high = count - 1;
  while (low < high) {
    const middle = Math.floor((low + high) / 2);
    if (points[middle * 2] < target) {
      low = middle + 1;
    } else {
      high = middle;
    }
  }
  if (
    low > 0 &&
    Math.abs(points[(low - 1) * 2] - target) <
      Math.abs(points[low * 2] - target)
  ) {
    return low - 1;
  }
  return low;
}

// converts object points to a compact representation retained by one graph
function packPoints(points) {
  const packed = new Float32Array(points.length * 2);
  for (let index = 0; index < points.length; index += 1) {
    packed[index * 2] = points[index].x;
    packed[index * 2 + 1] = points[index].y;
  }
  return packed;
}

// creates an svg path without retaining a second point-object array
function packedLinePath(
  points,
  x,
  y,
  start = 0,
  end = points.length / 2,
  maxPoints = Infinity,
) {
  let path = "";
  const step = Math.max(1, Math.ceil((end - start) / maxPoints));
  for (let index = start; index < end; index += step) {
    const px = x(points[index * 2]);
    const py = y(points[index * 2 + 1]);
    path += `${index === start ? "M" : "L"}${px},${py}`;
  }
  if (step > 1 && end > start + 1) {
    const index = end - 1;
    const px = x(points[index * 2]);
    const py = y(points[index * 2 + 1]);
    path += `L${px},${py}`;
  }
  return path;
}

// returns a sparse list of point indices for hover-only dot rendering
function hoverDotIndices(points, start, end, yMaximum) {
  const visible = Math.max(0, end - start + 1);
  const step = Math.max(1, Math.ceil(visible / maxHoverDots));
  const indices = [];
  for (let index = start; index <= end; index += step) {
    if (points[index * 2 + 1] <= yMaximum) indices.push(index);
  }
  if (indices[indices.length - 1] !== end && points[end * 2 + 1] <= yMaximum) {
    indices.push(end);
  }
  return indices;
}

// creates dots only while a graph is hovered, avoiding thousands of idle nodes
function showHoverDots(graph) {
  if (graph.dotsVisible) return;
  graph.dotsVisible = true;
  graph.drawTraceCanvas?.(graph.currentX);
}

// removes hover dots when the pointer leaves so graphs stay lightweight
function hideHoverDots(graph) {
  graph.dotsVisible = false;
  graph.drawTraceCanvas?.(graph.currentX);
}

// limits synchronized hover work to graphs close enough to be visible
function graphNearViewport(graph) {
  if (state.virtualizedTraces && graph.record) {
    return state.visibleTraceRecords.has(graph.record);
  }
  const node = graph.shell ?? graph.svg?.node();
  if (!node) return false;
  const rect = node.getBoundingClientRect();
  return (
    rect.bottom >= -viewportRenderMargin &&
    rect.top <= window.innerHeight + viewportRenderMargin
  );
}

// hides guide lines without forcing work across far-offscreen graphs
function hideVisibleTraceGuides() {
  for (const graph of state.traceGraphs) {
    if (graphNearViewport(graph)) {
      graph.guideNode?.setAttribute("display", "none");
    }
  }
}

// calculates a safe numeric extent for qc graphs
function paddedExtent(values) {
  const extent = d3.extent(values);
  if (!Number.isFinite(extent[0]) || !Number.isFinite(extent[1])) {
    return [0, 1];
  }
  if (extent[0] === extent[1]) {
    const padding = Math.max(Math.abs(extent[0]) * 0.05, 0.05);
    return [extent[0] - padding, extent[1] + padding];
  }
  return extent;
}

// hides all synchronized qc markers
function hideQcMarkers() {
  for (const graph of state.qcGraphs) {
    graph.marker.attr("display", "none");
    graph.tooltip.attr("display", "none");
  }
}

// highlights one sample across every qc graph
function showQcSample(sampleIndex) {
  const sampleName = state.samples[sampleIndex]?.[0] ?? `Sample ${sampleIndex + 1}`;
  for (const graph of state.qcGraphs) {
    if (sampleIndex >= graph.values.length) continue;
    graph.marker
      .attr("display", null)
      .attr("cx", graph.currentX(sampleIndex))
      .attr("cy", graph.y(graph.values[sampleIndex]));
    graph.tooltip.attr("display", null);
    graph.tooltip.select("text").text(sampleName);
  }
}

// renders one qc series using one path instead of hundreds of point nodes
function renderQcGraph(title, values, width) {
  if (!values.length) return;
  const typedValues = Float32Array.from(values);
  const height = Math.round(200 * state.fontScale);
  const x = d3
    .scaleLinear()
    .domain([0, Math.max(typedValues.length - 1, 1)])
    .range([margins.left, width - margins.right]);
  const extent = paddedExtent(typedValues);
  const y = title.startsWith("area")
    ? d3.scaleSymlog().domain(extent)
    : d3.scaleLinear().domain(extent);
  y.range([height - margins.bottom, margins.top + 6]);

  const svg = d3
    .create("svg")
    .attr("class", "visualizer-chart qc-chart")
    .attr("width", width)
    .attr("height", height)
    .style("--graph-font-scale", graphFontScale(width, height, 400, 200));
  svg
    .append("text")
    .attr("class", "chart-title")
    .attr("x", "50%")
    .attr("y", 4)
    .attr("dominant-baseline", "text-before-edge")
    .attr("text-anchor", "middle")
    .text(title);

  const yAxis = svg
    .append("g")
    .attr("transform", `translate(${margins.left},0)`)
    .call(d3.axisLeft(y).ticks(3, title.startsWith("area") ? "s" : "f").tickSize(0));
  yAxis.select(".domain").remove();

  const xAxis = svg
    .append("g")
    .attr("transform", `translate(0,${height - margins.bottom})`);
  const drawXAxis = (scale) => {
    xAxis.call(d3.axisBottom(scale).ticks(4).tickSize(0));
    xAxis.select(".domain").attr("opacity", 0.5);
  };

  const line = d3
    .line()
    .x((_, index) => x(index))
    .y((value) => y(value));
  const plotClip = addPlotClip(svg, width, height, margins.top + 6);
  const path = svg
    .append("path")
    .attr("class", "qc-trace")
    .attr("clip-path", plotClip)
    .attr("d", line(typedValues));

  const marker = svg
    .append("circle")
    .attr("class", "qc-marker")
    .attr("display", "none")
    .attr("r", 6 * state.fontScale);
  const tooltip = svg.append("g").attr("class", "qc-tooltip").attr("display", "none");
  tooltip
    .append("rect")
    .attr("width", width)
    .attr("height", 20 * state.fontScale);
  tooltip
    .append("text")
    .attr("x", "50%")
    .attr("y", 3 * state.fontScale)
    .attr("text-anchor", "middle")
    .attr("dominant-baseline", "text-before-edge");

  const graph = {
    title,
    width,
    height,
    currentX: x,
    marker,
    tooltip,
    values: typedValues,
    y,
    hoverX: (margins.left + width - margins.right) / 2,
  };
  state.qcGraphs.push(graph);

  const zoom = wheelZoom(width, height, (event) => {
      graph.currentX = event.transform.rescaleX(x);
      drawXAxis(graph.currentX);
      line.x((_, index) => graph.currentX(index));
      path.attr("d", line(typedValues));
      hideQcMarkers();
    });
  graph.zoom = zoom;
  graph.svg = svg;
  svg.call(zoom).call(zoom.transform, d3.zoomIdentity);
  svg
    .on("pointermove", (event) => {
      trackGraphPointer(graph, event, width);
      const index = Math.max(
        0,
        Math.min(
          typedValues.length - 1,
          Math.round(graph.currentX.invert(d3.pointer(event)[0])),
        ),
      );
      showQcSample(index);
    })
    .on("pointerleave", () => {
      releaseGraphPointer(graph);
      hideQcMarkers();
    });

  elements.qc.append(svg.node());
}

// renders retention shift and integrated qc values for one transition
async function renderQc(transition, token, width) {
  const shifts = await invoke("visualizer_get_sh", {
    projectPath: state.projectPath,
    cqq: transition.cqq,
  });
  if (token !== state.renderToken) return;
  renderQcGraph(`RT shift, ${transition.name}`, shifts, width);

  const groups = await invoke("visualizer_read_long", {
    projectPath: state.projectPath,
    cqq: transition.cqq,
  });
  if (token !== state.renderToken) return;
  for (const [featureName, rows] of groups) {
    if (!rows.length) continue;
    for (const key of Object.keys(rows[0])) {
      renderQcGraph(
        `${key.replaceAll("_", " ")}, ${featureName}`,
        rows.map((row) => row[key]),
        width,
      );
    }
  }
}

// returns the maximum retained intensity in one point interval
function maxIntensity(points, start, end) {
  let maximum = 0;
  for (let index = start; index < end; index += 1) {
    maximum = Math.max(maximum, points[index * 2 + 1]);
  }
  return maximum;
}

function referenceChoiceKey(graph) {
  return `${graph.editContext?.cqq ?? ""}:${graph.editContext?.sampleIndex ?? -1}`;
}

function graphReferenceDefault(graph) {
  return false;
}

function syncGraphReferenceState(graph) {
  const key = referenceChoiceKey(graph);
  graph.isReferenceChoice = state.referenceChoices.has(key)
    ? state.referenceChoices.get(key)
    : graphReferenceDefault(graph);
  graph.shell?.classList.toggle("is-reference", graph.isReferenceChoice);
  graph.referenceToggle?.classList.toggle("is-selected", graph.isReferenceChoice);
  graph.referenceToggle?.setAttribute(
    "aria-pressed",
    String(graph.isReferenceChoice),
  );
  if (graph.referenceToggle) {
    graph.referenceToggle.title = graph.isReferenceChoice
      ? "selected RT reference plot"
      : "select this plot as an RT reference";
  }
}

function toggleGraphReference(graph) {
  const key = referenceChoiceKey(graph);
  state.referenceChoices.set(key, !graph.isReferenceChoice);
  syncGraphReferenceState(graph);
  updateSaveButton();
  const count = state.traceRecords.filter(
    (record) => state.referenceChoices.get(referenceChoiceKey(record)) === true,
  ).length;
  setStatus(`${count.toLocaleString()} RT reference plot(s) selected`);
}

function createReferenceToggle(graph) {
  const button = document.createElement("button");
  button.className = "visualizer-reference-toggle";
  button.type = "button";
  button.setAttribute("aria-label", `select ${graph.sampleName} as an RT reference`);
  button.innerHTML = `
    <svg viewBox="0 0 24 24" aria-hidden="true">
      <path d="M5 12.5 10 17l9-10" />
    </svg>
  `;
  button.addEventListener("click", () => toggleGraphReference(graph));
  graph.referenceToggle = button;
  syncGraphReferenceState(graph);
  return button;
}

// renders one chromatogram while retaining only a compact typed point array
function renderTrace(
  plot,
  sample,
  index,
  container,
  isReference,
  editContext,
  options = {},
) {
  const { width, height } = options.record ?? graphDimensions();
  const range = graphRange();
  const points = options.points ?? packPoints(plot.te ?? []);
  if (plot.te) plot.te = null;
  if (points.length < 4) {
    if (options.shell) {
      const { width, height } = graphDimensions();
      const frame = document.createElement("div");
      frame.className = "visualizer-chart";
      frame.style.width = `${width}px`;
      frame.style.height = `${height}px`;
      frame.textContent = "No trace data";
      options.shell.className = "visualizer-chart-shell";
      options.shell.replaceChildren(frame);
    }
    return;
  }

  const count = points.length / 2;
  let startIndex = range.start === 0 ? 0 : nearestPackedIndex(points, range.start);
  startIndex = Math.min(startIndex, count - 2);
  const endIndex =
    range.end === 0 ? count - 1 : nearestPackedIndex(points, range.end);
  const safeEndIndex = Math.min(
    count - 1,
    Math.max(startIndex + 1, endIndex),
  );
  const x = d3
    .scaleLinear()
    .domain([points[startIndex * 2], points[safeEndIndex * 2]])
    .range([margins.left, width - margins.right]);

  const visibleMaximum = maxIntensity(points, startIndex, safeEndIndex + 1);
  const autoYMax = Math.max(visibleMaximum * 1.1, 1);
  let ySliderBaseMax = autoYMax;
  let y = d3
    .scaleLinear()
    .domain([0, Math.max(ySliderBaseMax, Number.EPSILON)])
    .range([height - margins.bottom, margins.top]);
  const plotBounds = {
    left: margins.left,
    right: width - margins.right,
    top: margins.top,
    bottom: height - margins.bottom,
  };
  const clampPlotX = (value) =>
    Math.max(plotBounds.left, Math.min(plotBounds.right, value));
  const pointerInsidePlot = (event) => {
    const [px, py] = d3.pointer(event);
    return (
      px >= plotBounds.left &&
      px <= plotBounds.right &&
      py >= plotBounds.top &&
      py <= plotBounds.bottom
    );
  };

  const canvas = document.createElement("canvas");
  canvas.className = "visualizer-trace-canvas";
  canvas.width = Math.round(width * Math.min(window.devicePixelRatio || 1, 2));
  canvas.height = Math.round(height * Math.min(window.devicePixelRatio || 1, 2));
  canvas.style.width = `${width}px`;
  canvas.style.height = `${height}px`;
  const canvasScale = canvas.width / width;
  const canvasContext = canvas.getContext("2d", { alpha: true });
  canvasContext.scale(canvasScale, canvasScale);

  const svg = d3
    .create("svg")
    .attr("class", "chromatogram-chart visualizer-chart-overlay")
    .attr("width", width)
    .attr("height", height)
    .style("--graph-font-scale", graphFontScale(width, height));
  const plotClip = addPlotClip(svg, width, height);
  const plotLayer = svg.append("g").attr("clip-path", plotClip);
  const xAxis = svg
    .append("g")
    .attr("transform", `translate(0,${height - margins.bottom})`)
    .call(d3.axisBottom(x).ticks(5).tickSize(0));
  xAxis.select(".domain").attr("opacity", 0.5);
  const yAxis = svg
    .append("g")
    .attr("transform", `translate(${margins.left},0)`)
    .call(d3.axisLeft(y).ticks(2, "s").tickSize(0));
  yAxis.select(".domain").remove();

  // draws a preview fill from the chromatogram line down to the x-axis. This is
  // used while dragging so the blue edit preview stays under the trace instead
  // of forming a diagonal wedge from endpoint baselines.
  const curveAreaPath = (begin, end, scale, maxPoints = maxAreaPathPoints) => {
    const start = Math.max(0, Math.min(count - 1, begin));
    const stop = Math.max(start + 1, Math.min(count, end));
    let baseline = points[start * 2 + 1];
    for (let point = start + 1; point < stop; point += 1) {
      baseline = Math.min(baseline, points[point * 2 + 1]);
    }
    // on multi-isomer graphs, drop the blue preview to the sibling (orange)
    // band's baseline so both regions bottom out at the same level
    const sibling = integrations.find(
      (other) => other !== integrations[0] && other.baselineStart != null,
    );
    if (sibling) {
      baseline = Math.min(baseline, sibling.baselineStart, sibling.baselineEnd);
    }
    const bottom = y(baseline);
    let path = "";
    const step = Math.max(
      1,
      Math.ceil((stop - start) / maxPoints),
    );
    for (let point = start; point < stop; point += step) {
      const px = clampPlotX(scale(points[point * 2]));
      const py = y(points[point * 2 + 1]);
      path += `${point === start ? "M" : "L"}${px},${py}`;
    }
    if (step > 1 && stop > start + 1) {
      const point = stop - 1;
      path += `L${clampPlotX(scale(points[point * 2]))},${y(
        points[point * 2 + 1],
      )}`;
    }
    const endX = clampPlotX(scale(points[(stop - 1) * 2]));
    const beginX = clampPlotX(scale(points[start * 2]));
    return `${path}L${endX},${bottom}L${beginX},${bottom}Z`;
  };

  // repositions one integration region's window box and baseline area for a
  // given x scale; shared by the initial draw, wheel zoom, and drag editing
  const drawRegion = (region, scale, options = {}) => {
    const maxPoints = options.dragPreview
      ? maxDragAreaPathPoints
      : maxAreaPathPoints;
    const beginX = clampPlotX(scale(points[region.begin * 2]));
    const endX = clampPlotX(scale(points[(region.end - 1) * 2]));
    const windowNode = region.windowNode ?? region.window?.node?.();
    if (windowNode) {
      windowNode.setAttribute("x", String(Math.min(beginX, endX)));
      windowNode.setAttribute("width", String(Math.max(0, Math.abs(endX - beginX))));
    }
    if (region.area) {
      const areaNode = region.areaNode ?? region.area.node();
      if (region.previewArea) {
        areaNode.setAttribute(
          "d",
          curveAreaPath(region.begin, region.end, scale, maxPoints),
        );
      } else {
        areaNode.setAttribute(
          "d",
          packedLinePath(
            points,
            scale,
            y,
            region.begin,
            region.end,
            maxPoints,
          ) +
            `L${endX},${y(region.baselineEnd)}` +
            `L${beginX},${y(region.baselineStart)}Z`,
        );
      }
    }
  };

  const integrations = [];
  for (let peakIndex = 0; peakIndex < plot.pos_l.length; peakIndex += 2) {
    const begin = Math.max(plot.pos_l[peakIndex] - 1, 0);
    const end = Math.min(plot.pos_l[peakIndex + 1], count);
    if (end <= begin) continue;
    const color = d3.schemeCategory10[(peakIndex / 2) % 10];
    const region = {
      isomerIndex: peakIndex / 2,
      begin,
      end,
      color,
      baselineStart: plot.bl[0] != null ? (plot.bl[peakIndex] ?? 0) : null,
      baselineEnd: plot.bl[0] != null ? (plot.bl[peakIndex + 1] ?? 0) : null,
      area: null,
      window: null,
    };
    if (region.baselineStart != null) {
      region.area = plotLayer
        .append("path")
        .attr("class", "integration-area")
        .attr("fill", color);
      region.areaNode = region.area.node();
    }
    region.window = plotLayer
      .append("rect")
      .attr("class", "integration-window")
      .attr("fill", color)
      .attr("y", y.range()[1])
      .attr("height", y.range()[0] - y.range()[1]);
    region.windowNode = region.window.node();
    drawRegion(region, x);
    integrations.push(region);
  }

  let graph = null;
  const trace = plotLayer
    .append("path")
    .attr("class", "chromatogram-trace")
    .attr("display", "none");

  const dotIndices = hoverDotIndices(points, startIndex, safeEndIndex, y.domain()[1]);
  const sampleType = sampleTypeOf(sample);
  const sampleTypeColor = state.sampleTypeColors.get(sampleType) ?? sampleTypePalette[0];
  let traceColor = state.colorSampleTypes
    ? sampleTypeColor
    : getComputedStyle(document.documentElement).getPropertyValue("--ink").trim() ||
      "#10202b";

  const drawTraceCanvas = (scale) => {
    canvasContext.clearRect(0, 0, width, height);
    canvasContext.save();
    canvasContext.beginPath();
    canvasContext.rect(
      plotBounds.left,
      plotBounds.top,
      plotBounds.right - plotBounds.left,
      plotBounds.bottom - plotBounds.top,
    );
    canvasContext.clip();
    canvasContext.strokeStyle = traceColor;
    canvasContext.lineWidth = 1.25 * Math.min(state.fontScale, 1.6);
    canvasContext.lineJoin = "round";
    canvasContext.lineCap = "round";
    canvasContext.beginPath();
    const traceStep = Math.max(
      1,
      Math.ceil((safeEndIndex + 1 - startIndex) / Math.max(600, width * 2)),
    );
    let moved = false;
    for (let point = startIndex; point <= safeEndIndex; point += traceStep) {
      const px = scale(points[point * 2]);
      const py = y(points[point * 2 + 1]);
      if (!moved) {
        canvasContext.moveTo(px, py);
        moved = true;
      } else {
        canvasContext.lineTo(px, py);
      }
    }
    if (traceStep > 1) {
      canvasContext.lineTo(
        scale(points[safeEndIndex * 2]),
        y(points[safeEndIndex * 2 + 1]),
      );
    }
    canvasContext.stroke();
    if (graph?.dotsVisible) {
      canvasContext.globalAlpha = 0.5;
      canvasContext.fillStyle = traceColor;
      for (const dot of dotIndices) {
        const px = scale(points[dot * 2]);
        if (px < plotBounds.left || px > plotBounds.right) continue;
        const py = y(points[dot * 2 + 1]);
        canvasContext.beginPath();
        canvasContext.arc(px, py, 1.5 * state.fontScale, 0, Math.PI * 2);
        canvasContext.fill();
      }
    }
    canvasContext.restore();
  };

  const sampleName = sample?.[0] ?? `Graph ${index + 1}`;
  const title = svg
    .append("text")
    .attr("class", "chart-title")
    .attr("x", "50%")
    .attr("y", 3)
    .attr("text-anchor", "middle")
    .attr("dominant-baseline", "text-before-edge")
    .style("fill", state.colorSampleTypes ? sampleTypeColor : null)
    .text(sampleName);
  if (sample?.[4]) {
    svg
      .append("text")
      .attr("class", "chart-detail")
      .attr("x", "98%")
      .attr("y", 3)
      .attr("text-anchor", "end")
      .attr("dominant-baseline", "text-before-edge")
      .text(sample[4] === "1" ? "REF" : d3.format(".2f")(plot.sh));
  }
  if (sample?.[1]?.includes("BLK")) {
    svg
      .append("text")
      .attr("class", "blank-label")
      .attr("x", "50%")
      .attr("y", "50%")
      .attr("text-anchor", "middle")
      .attr("dominant-baseline", "central")
      .text(sample[1]);
  }

  const guide = svg
    .append("line")
    .attr("class", "trace-guide")
    .attr("display", "none")
    .attr("y1", height - margins.bottom)
    .attr("y2", margins.top);
  const guideNode = guide.node();
  const tooltip = svg.append("g").attr("class", "trace-tooltip").attr("display", "none");
  const tooltipNode = tooltip.node();
  const tooltipCircleNode = tooltip
    .append("circle")
    .attr("r", 3 * state.fontScale)
    .node();
  const tooltipRectNode = tooltip
    .append("rect")
    .attr("x", -36 * state.fontScale)
    .attr("y", 0)
    .attr("width", 72 * state.fontScale)
    .attr("height", 20 * state.fontScale)
    .attr("rx", 4 * state.fontScale)
    .node();
  const tooltipTextNode = tooltip
    .append("text")
    .attr("x", 0)
    .attr("y", 10 * state.fontScale)
    .attr("text-anchor", "middle")
    .attr("dominant-baseline", "middle")
    .node();
  graph = {
    width,
    height,
    canvas,
    currentX: x,
    baseDomain: x.domain(),
    guide,
    guideNode,
    hoverX: (margins.left + width - margins.right) / 2,
    points,
    x,
    sampleIndex: index,
    sampleName,
    sampleType,
    sampleTypeColor,
    isReference,
    record: options.record ?? null,
    isReferenceChoice: false,
    editContext,
    integrations,
    dotIndices,
    dotsVisible: false,
    drawTraceCanvas,
    y,
    hasEdit: false,
    editRt: null,
    editRts: options.record?.editRts ?? new Map(),
    panSlider: null,
    zoomTransform: d3.zoomIdentity,
  };
  if (!options.transient) state.traceGraphs.push(graph);

  const panSlider = document.createElement("input");
  panSlider.className = "chart-pan-slider";
  panSlider.type = "range";
  panSlider.min = "0";
  panSlider.max = "1000";
  panSlider.step = "1";
  panSlider.value = "0";
  panSlider.disabled = true;
  panSlider.title = "pan the zoomed graph left or right";
  panSlider.setAttribute("aria-label", `pan zoomed graph for ${sampleName}`);
  graph.panSlider = panSlider;

  const ySlider = document.createElement("input");
  ySlider.className = "chart-y-slider";
  ySlider.type = "range";
  ySlider.min = "0";
  ySlider.max = "1000";
  ySlider.step = "1";
  ySlider.value = "0";
  ySlider.title = "adjust the y-axis scale";
  ySlider.setAttribute("aria-label", `adjust y-axis scale for ${sampleName}`);
  graph.ySlider = ySlider;

  const updatePanSlider = (transform = graph.zoomTransform) => {
    const k = transform.k;
    if (k <= 1.0001) {
      panSlider.disabled = true;
      panSlider.value = "0";
      return;
    }
    const [baseStart, baseEnd] = graph.baseDomain;
    const fullWidth = baseEnd - baseStart;
    const [viewStart, viewEnd] = graph.currentX.domain();
    const viewWidth = viewEnd - viewStart;
    const span = Math.max(fullWidth - viewWidth, Number.EPSILON);
    const value = Math.max(
      0,
      Math.min(1000, ((viewStart - baseStart) / span) * 1000),
    );
    panSlider.disabled = false;
    panSlider.value = String(Math.round(value));
  };

  const transformFromPanSlider = () => {
    const k = Math.max(graph.zoomTransform.k, 1);
    if (k <= 1.0001) return d3.zoomIdentity;
    const [baseStart, baseEnd] = graph.baseDomain;
    const fullWidth = baseEnd - baseStart;
    const viewWidth = fullWidth / k;
    const offset =
      (Number(panSlider.value) / 1000) * Math.max(0, fullWidth - viewWidth);
    const domainStart = baseStart + offset;
    const translateX = margins.left - k * x(domainStart);
    return d3.zoomIdentity.translate(translateX, 0).scale(k);
  };

  panSlider.addEventListener("input", () => {
    if (graph.zoomTransform.k <= 1.0001) return;
    svg.call(zoom.transform, transformFromPanSlider());
  });

  const redrawTrace = (scale) => {
    graph.currentX = scale;
    graph.x = scale;
    xAxis.call(d3.axisBottom(scale).ticks(5).tickSize(0));
    xAxis.select(".domain").attr("opacity", 0.5);
    drawTraceCanvas(scale);
    for (const integration of integrations) {
      drawRegion(integration, scale);
    }
    tooltipNode.setAttribute("display", "none");
    guideNode.setAttribute("display", "none");
  };

  const updateYScale = () => {
    const amount = Number(ySlider.value) / 1000;
    const visibleMax = ySliderBaseMax * Math.pow(0.08, amount);
    y = d3
      .scaleLinear()
      .domain([0, Math.max(visibleMax, Number.EPSILON)])
      .range([height - margins.bottom, margins.top]);
    graph.y = y;
    yAxis.call(d3.axisLeft(y).ticks(2, "s").tickSize(0));
    yAxis.select(".domain").remove();
    redrawTrace(graph.currentX);
  };

  graph.applyGlobalYMaximum = (maximum) => {
    if (maximum > 0 && maximum < autoYMax) {
      ySliderBaseMax = autoYMax;
      const amount = Math.log(maximum / autoYMax) / Math.log(0.08);
      ySlider.value = String(
        Math.max(0, Math.min(1000, Math.round(amount * 1000))),
      );
    } else {
      ySliderBaseMax = maximum > 0 ? maximum : autoYMax;
      ySlider.value = "0";
    }
    updateYScale();
  };

  graph.applyGlobalYMaximum(range.intensity);

  if (options.record?.ySliderValue != null) {
    ySlider.value = options.record.ySliderValue;
    updateYScale();
  }

  ySlider.addEventListener("input", () => {
    if (options.record) options.record.ySliderValue = ySlider.value;
    updateYScale();
  });
  ySlider.addEventListener(
    "wheel",
    (event) => {
      event.preventDefault();
      const delta = event.deltaY < 0 ? 36 : -36;
      ySlider.value = String(
        Math.max(0, Math.min(1000, Number(ySlider.value) + delta)),
      );
      if (options.record) options.record.ySliderValue = ySlider.value;
      updateYScale();
    },
    { passive: false },
  );
  const zoom = wheelZoom(width, height, (event) => {
    graph.zoomTransform = event.transform;
    if (options.record) {
      options.record.zoomTransform = {
        k: event.transform.k,
        x: event.transform.x,
        y: event.transform.y,
      };
    }
    redrawTrace(event.transform.rescaleX(x));
    updatePanSlider(event.transform);
  });
  graph.zoom = zoom;
  graph.svg = svg;
  svg.call(zoom).call(zoom.transform, d3.zoomIdentity);
  if (options.record?.zoomTransform) {
    const stored = options.record.zoomTransform;
    svg.call(
      zoom.transform,
      d3.zoomIdentity.translate(stored.x, stored.y).scale(stored.k),
    );
  }

  // keeps a dragged retention time inside the retained data range
  const clampRt = (rt) =>
    Math.max(points[0], Math.min(points[(count - 1) * 2], rt));

  // returns the blue (primary) region, creating an empty one on demand so a
  // graph with no detected peak can still receive a dragged integration window
  const ensurePrimaryRegion = () => {
    if (integrations[0]) return integrations[0];
    const region = {
      isomerIndex: 0,
      begin: 0,
      end: 1,
      color: d3.schemeCategory10[0],
      baselineStart: null,
      baselineEnd: null,
      area: null,
      previewArea: true,
      created: true,
      window: plotLayer
        .insert("rect", ".chromatogram-trace")
        .attr("class", "integration-window")
        .attr("fill", d3.schemeCategory10[0])
        .attr("y", y.range()[1])
        .attr("height", y.range()[0] - y.range()[1])
        .attr("display", "none"),
    };
    region.windowNode = region.window.node();
    integrations.unshift(region);
    return region;
  };

  // finds the colored integration region under the cursor. Multi-color graphs
  // remember the last selected isomer so ambiguous boundary clicks keep editing
  // that color instead of falling back to whichever region happens to be first.
  const dragRegionAt = (pointerX) => {
    if (integrations.length <= 1) {
      const region = ensurePrimaryRegion();
      state.selectedIsomerIndex = region.isomerIndex;
      return region;
    }
    const selectedRegion = integrations.find(
      (region) => region.isomerIndex === state.selectedIsomerIndex,
    );
    const candidates = [];
    const boundaryTolerance = 4;
    for (let index = integrations.length - 1; index >= 0; index -= 1) {
      const region = integrations[index];
      const beginX = graph.currentX(points[region.begin * 2]);
      const endX = graph.currentX(points[(region.end - 1) * 2]);
      const left = Math.min(beginX, endX);
      const right = Math.max(beginX, endX);
      if (pointerX >= left && pointerX <= right) {
        candidates.push({
          region,
          boundaryDistance: Math.min(
            Math.abs(pointerX - left),
            Math.abs(pointerX - right),
          ),
        });
      }
    }
    const region =
      candidates.find(
        (candidate) => candidate.region.isomerIndex === state.selectedIsomerIndex,
      )?.region ??
      (selectedRegion &&
      candidates.length > 0 &&
      candidates.every((candidate) => candidate.boundaryDistance <= boundaryTolerance)
        ? selectedRegion
        : null) ??
      candidates[0]?.region ??
      selectedRegion ??
      integrations[0] ??
      ensurePrimaryRegion();
    state.selectedIsomerIndex = region.isomerIndex;
    return region;
  };

  // moves the selected colored band to the dragged span and records the edit
  // for saving back into that isomer's RT_matrix columns.
  const setRegionBand = (region, rtLo, rtHi) => {
    const begin = nearestPackedIndex(points, rtLo);
    const end = Math.max(begin + 1, nearestPackedIndex(points, rtHi));
    region.begin = begin;
    region.end = end + 1;
    region.previewArea = true;
    if (!region.area) {
      region.area = plotLayer
        .insert("path", ".chromatogram-trace")
        .attr("class", "integration-area")
        .attr("fill", region.color);
      region.areaNode = region.area.node();
    }
    region.areaNode?.removeAttribute("display");
    region.windowNode?.removeAttribute("display");
    drawRegion(region, graph.currentX, { dragPreview: true });
    graph.editRts.set(region.isomerIndex, {
      start: points[region.begin * 2],
      end: points[(region.end - 1) * 2],
    });
    graph.hasEdit = graph.editRts.size > 0;
  };

  let dragging = false;
  let dragStartRt = 0;
  let dragStartPx = 0;
  let dragRegion = null;
  let preDrag = null;
  let pendingBand = null;
  let dragFrame = 0;
  let pendingHover = null;
  let hoverFrame = 0;

  const flushPendingBand = () => {
    if (dragFrame) {
      cancelAnimationFrame(dragFrame);
      dragFrame = 0;
    }
    if (!pendingBand) return;
    const band = pendingBand;
    pendingBand = null;
    setRegionBand(band.region, band.start, band.end);
  };

  const scheduleRegionBand = (region, start, end) => {
    pendingBand = { region, start, end };
    if (dragFrame) return;
    dragFrame = requestAnimationFrame(() => {
      dragFrame = 0;
      flushPendingBand();
    });
  };

  const formatTooltipPoint = (pointIndex) =>
    `${formatRt(points[pointIndex * 2])}, ${formatIntensity(points[pointIndex * 2 + 1])}`;

  const setTooltipText = (text) => {
    const tooltipWidth = Math.min(
      220 * state.fontScale,
      Math.max(
        72 * state.fontScale,
        text.length * 6.2 * state.fontScale + 16 * state.fontScale,
      ),
    );
    tooltipRectNode.setAttribute("x", String(-tooltipWidth / 2));
    tooltipRectNode.setAttribute("width", String(tooltipWidth));
    tooltipTextNode.textContent = text;
    return tooltipWidth;
  };

  const placeTooltip = (pointX, pointY, text) => {
    const tooltipWidth = setTooltipText(text);
    const tooltipX = Math.max(
      tooltipWidth / 2,
      Math.min(width - tooltipWidth / 2, pointX),
    );
    tooltipNode.removeAttribute("display");
    tooltipNode.setAttribute("transform", `translate(${tooltipX},0)`);
    tooltipCircleNode.setAttribute("cx", String(pointX - tooltipX));
    tooltipCircleNode.setAttribute("cy", String(y(pointY)));
  };

  const renderHoverAt = (pointerX) => {
    showHoverDots(graph);
    graph.hoverX = Math.max(
      margins.left,
      Math.min(width - margins.right, pointerX),
    );
    state.hoveredGraph = graph;
    const retentionTime = graph.currentX.invert(pointerX);
    const pointIndex = nearestPackedIndex(points, retentionTime);
    const pointX = graph.currentX(points[pointIndex * 2]);
    const pointY = points[pointIndex * 2 + 1];
    placeTooltip(pointX, pointY, `(${formatTooltipPoint(pointIndex)})`);
    const graphs = isReference
      ? state.traceGraphs.filter(graphNearViewport)
      : [graph];
    for (const target of graphs) {
      const targetIndex = nearestPackedIndex(
        target.points,
        points[pointIndex * 2],
      );
      const targetX = target.x(target.points[targetIndex * 2]);
      target.guideNode.removeAttribute("display");
      target.guideNode.setAttribute("x1", String(targetX));
      target.guideNode.setAttribute("x2", String(targetX));
    }
  };

  const renderDragTooltipAt = (pointerX) => {
    showHoverDots(graph);
    const startIndex = nearestPackedIndex(points, dragStartRt);
    const retentionTime = graph.currentX.invert(pointerX);
    const pointIndex = nearestPackedIndex(points, retentionTime);
    const pointX = graph.currentX(points[pointIndex * 2]);
    const pointY = points[pointIndex * 2 + 1];
    placeTooltip(
      pointX,
      pointY,
      `(${formatTooltipPoint(startIndex)}) -> (${formatTooltipPoint(pointIndex)})`,
    );
  };

  const scheduleHover = (pointerX) => {
    pendingHover = pointerX;
    if (hoverFrame) return;
    hoverFrame = requestAnimationFrame(() => {
      hoverFrame = 0;
      const pointer = pendingHover;
      pendingHover = null;
      if (!dragging && pointer != null) {
        renderHoverAt(pointer);
      }
    });
  };

  svg
    .on("pointerdown", (event) => {
      if (event.button !== 0) return;
      if (!pointerInsidePlot(event)) return;
      dragging = true;
      dragStartPx = clampPlotX(d3.pointer(event)[0]);
      dragStartRt = clampRt(graph.currentX.invert(dragStartPx));
      dragRegion = dragRegionAt(dragStartPx);
      preDrag = dragRegion
        ? {
            existed: true,
            region: dragRegion,
            begin: dragRegion.begin,
            end: dragRegion.end,
            baselineStart: dragRegion.baselineStart,
            baselineEnd: dragRegion.baselineEnd,
            areaDisplay: dragRegion.area?.attr("display") ?? null,
            previewArea: Boolean(dragRegion.previewArea),
            display: dragRegion.window.attr("display"),
            editRts: new Map(graph.editRts),
          }
        : { existed: false, editRts: new Map(graph.editRts) };
      tooltipNode.setAttribute("display", "none");
      hideVisibleTraceGuides();
      renderDragTooltipAt(dragStartPx);
      svg.classed("is-dragging", true);
      try {
        svg.node().setPointerCapture(event.pointerId);
      } catch {}
      event.preventDefault();
    })
    .on("pointermove", (event) => {
      const pointerX = clampPlotX(d3.pointer(event)[0]);
      if (dragging) {
        const rt = clampRt(graph.currentX.invert(pointerX));
        scheduleRegionBand(
          dragRegion ?? ensurePrimaryRegion(),
          Math.min(dragStartRt, rt),
          Math.max(dragStartRt, rt),
        );
        renderDragTooltipAt(pointerX);
        return;
      }
      scheduleHover(pointerX);
    })
    .on("pointerup pointercancel", (event) => {
      if (!dragging) return;
      flushPendingBand();
      dragging = false;
      svg.classed("is-dragging", false);
      try {
        svg.node().releasePointerCapture(event.pointerId);
      } catch {}
      // a click (negligible drag) reverts to the pre-drag state instead of
      // collapsing the band to a single point
      if (Math.abs(clampPlotX(d3.pointer(event)[0]) - dragStartPx) < 4) {
        if (preDrag?.existed) {
          const region = preDrag.region;
          region.begin = preDrag.begin;
          region.end = preDrag.end;
          region.baselineStart = preDrag.baselineStart;
          region.baselineEnd = preDrag.baselineEnd;
          region.previewArea = preDrag.previewArea;
          region.area?.attr("display", preDrag.areaDisplay);
          region.window.attr("display", preDrag.display);
          drawRegion(region, graph.currentX);
        } else if (dragRegion?.created) {
          dragRegion.area?.remove();
          dragRegion.window.remove();
          const removeIndex = integrations.indexOf(dragRegion);
          if (removeIndex >= 0) integrations.splice(removeIndex, 1);
        }
        graph.editRts.clear();
        for (const [isomerIndex, edit] of preDrag?.editRts ?? []) {
          graph.editRts.set(isomerIndex, edit);
        }
        graph.hasEdit = graph.editRts.size > 0;
      } else if (dragRegion) {
        drawRegion(dragRegion, graph.currentX);
      }
      graph.editRt = graph.editRts.values().next().value ?? null;
      dragRegion = null;
      preDrag = null;
      updateSaveButton();
    })
    .on("pointerleave", () => {
      pendingHover = null;
      releaseGraphPointer(graph);
      hideHoverDots(graph);
      tooltipNode.setAttribute("display", "none");
      hideVisibleTraceGuides();
    });

  if (options.record?.editRts?.size) {
    for (const [isomerIndex, edit] of [...options.record.editRts]) {
      const region =
        integrations.find((candidate) => candidate.isomerIndex === isomerIndex) ??
        (isomerIndex === 0 ? ensurePrimaryRegion() : null);
      if (region) setRegionBand(region, edit.start, edit.end);
    }
    graph.hasEdit = graph.editRts.size > 0;
    graph.editRt = graph.editRts.values().next().value ?? null;
  }

  const shell = options.shell ?? document.createElement("div");
  shell.className = "visualizer-chart-shell";
  shell.style.width = `${width}px`;
  shell.style.setProperty("--graph-font-scale", String(graphFontScale(width, height)));
  shell.style.setProperty("--sample-type-color", sampleTypeColor);
  shell.classList.toggle("sample-type-colored", state.colorSampleTypes);
  const frame = document.createElement("div");
  frame.className = "visualizer-chart visualizer-canvas-frame chromatogram-chart";
  frame.style.width = `${width}px`;
  frame.style.height = `${height}px`;
  graph.shell = shell;
  graph.applySampleTypeColor = () => {
    traceColor = state.colorSampleTypes
      ? sampleTypeColor
      : getComputedStyle(document.documentElement)
          .getPropertyValue("--ink")
          .trim() || "#10202b";
    shell.classList.toggle("sample-type-colored", state.colorSampleTypes);
    title.style("fill", state.colorSampleTypes ? sampleTypeColor : null);
    drawTraceCanvas(graph.currentX);
  };
  const referenceToggle = options.transient ? null : createReferenceToggle(graph);
  frame.append(canvas, svg.node(), ySlider);
  if (referenceToggle) frame.append(referenceToggle);
  shell.replaceChildren(frame, panSlider);
  if (!options.shell) {
    container.append(shell);
  }
  return graph;
}

// batches expensive graph construction so large selections do not freeze WebView
function createTraceRenderQueue(token, statusMessage) {
  const queue = [];
  let cursor = 0;
  let scheduled = false;
  let streamDone = false;
  let rendered = 0;
  let resolveDrain;
  const drain = new Promise((resolve) => {
    resolveDrain = resolve;
  });

  const finishIfIdle = () => {
    if (
      streamDone &&
      (state.virtualizedTraces || (!scheduled && cursor >= queue.length))
    ) {
      resolveDrain(rendered);
    }
  };

  const pump = () => {
    scheduled = false;
    if (token !== state.renderToken) {
      queue.length = 0;
      cursor = 0;
      resolveDrain(rendered);
      return;
    }

    const started = performance.now();
    let count = 0;
    while (
      cursor < queue.length &&
      token === state.renderToken &&
      count < traceBatchSize &&
      performance.now() - started < traceBatchBudgetMs
    ) {
      const record = queue[cursor];
      cursor += 1;
      if (record.rendered) continue;
      record.rendered = true;
      mountTraceRecord(record);
      rendered += 1;
      count += 1;
      if (rendered % 25 === 0) {
        setStatus(statusMessage(rendered), { cancellable: true });
      }
    }

    if (cursor > 100 && cursor > queue.length / 2) {
      queue.splice(0, cursor);
      cursor = 0;
    }

    if (cursor < queue.length && token === state.renderToken) {
      scheduled = true;
      requestAnimationFrame(pump);
    } else {
      finishIfIdle();
    }
  };

  return {
    push(job) {
      const record = createTraceRecord(job);
      if (state.virtualizedTraces) {
        rendered += 1;
        if (rendered % 100 === 0) {
          setStatus(statusMessage(rendered), { cancellable: true });
        }
        return;
      }
      queue.push(record);
      if (!scheduled) {
        scheduled = true;
        requestAnimationFrame(pump);
      }
    },
    finish() {
      streamDone = true;
      finishIfIdle();
    },
    drain,
    get rendered() {
      return rendered;
    },
  };
}

// renders all samples for one transition through a bounded rust channel
async function renderTransition(transition, token) {
  const { width } = graphDimensions();
  elements.analyte.textContent = `${transition.name} | ${transition.precursor}m/z${
    transition.product ? ` | ${transition.product}m/z` : ""
  }`;
  try {
    await renderQc(transition, token, width);
  } catch (error) {
    if (token === state.renderToken) {
      setStatus(`QC unavailable; rendering chromatograms...`);
      console.warn("Visualizer QC data could not be rendered:", error);
    }
  }
  if (token !== state.renderToken) return;

  const channel = new Channel();
  let index = 0;
  let minimumRt = Infinity;
  let maximumRt = -Infinity;
  const queue = createTraceRenderQueue(
    token,
    (rendered) => `Rendering sample ${rendered.toLocaleString()}...`,
  );
  setStatus("Rendering sample 0... click to cancel", { cancellable: true });
  channel.onmessage = (plot) => {
    if (token !== state.renderToken) return;
    if (plot.te?.length) {
      minimumRt = Math.min(minimumRt, plot.te[0].x);
      maximumRt = Math.max(maximumRt, plot.te[plot.te.length - 1].x);
    }
    queue.push({
      plot,
      sample: state.samples[index],
      index,
      container: elements.plots,
      isReference: false,
      editContext: {
        cqq: transition.cqq,
        sampleIndex: index,
        fileName: state.samples[index]?.[0] ?? "",
      },
    });
    index += 1;
  };
  await invoke("visualizer_get_t", {
    projectPath: state.projectPath,
    cqq: transition.cqq,
    onEvent: channel,
  });
  queue.finish();
  const rendered = await queue.drain;
  if (token === state.renderToken) {
    applyDetectedRtRange(minimumRt, maximumRt);
    setStatus(
      state.virtualizedTraces
        ? `${rendered.toLocaleString()} chromatograms ready; plots render as you scroll`
        : `${rendered.toLocaleString()} chromatograms rendered`,
    );
  }
}

// renders every transition for one reference sample
async function renderReference(reference, token) {
  elements.analyte.textContent = `${reference.slice(3)} | REF`;
  // reference view fixes one sample row; each graph edits a different transition
  const referenceFile = reference.slice(3);
  const referenceSampleIndex = Math.max(
    0,
    state.samples.findIndex(
      (sample) => stripMzml(sample[0]) === stripMzml(referenceFile),
    ),
  );
  const referenceMetadata = state.samples[referenceSampleIndex] ?? [];
  const channel = new Channel();
  let index = 0;
  const queue = createTraceRenderQueue(
    token,
    (rendered) => `Rendering transition ${rendered.toLocaleString()}...`,
  );
  setStatus("Rendering transition 0... click to cancel", { cancellable: true });
  channel.onmessage = (plot) => {
    if (token !== state.renderToken) return;
    const transition = state.transitions[index];
    const sample = [
      transition?.name ?? `Transition ${index + 1}`,
      referenceMetadata[1] ?? "",
      referenceMetadata[2] ?? "",
      referenceMetadata[3] ?? "",
      referenceMetadata[4] ?? "",
    ];
    queue.push({
      plot,
      sample,
      index,
      container: elements.plots,
      isReference: true,
      editContext: {
        cqq: transition?.cqq,
        sampleIndex: referenceSampleIndex,
        fileName: referenceFile,
      },
    });
    index += 1;
  };
  await invoke("visualizer_get_r", {
    projectPath: state.projectPath,
    mzml: reference,
    onEvent: channel,
  });
  queue.finish();
  const rendered = await queue.drain;
  if (token === state.renderToken) {
    setStatus(
      state.virtualizedTraces
        ? `${rendered.toLocaleString()} reference chromatograms ready; plots render as you scroll`
        : `${rendered.toLocaleString()} reference chromatograms rendered`,
    );
  }
}

// Enables Save for dragged edits and the shared action for any selected plot
// that already contains a valid existing or edited integration window.
function updateSaveButton() {
  const hasEdits = state.traceRecords.some(
    (record) => record.editRts?.size > 0 && record.editContext?.cqq,
  );
  const selection = elements.transition.value;
  const selectedReferences = state.traceRecords.filter(
    (record) =>
      state.referenceChoices.get(referenceChoiceKey(record)) === true &&
      record.editContext?.cqq &&
      referenceBounds(record).size > 0,
  );
  elements.save.disabled = !hasEdits || state.loading;
  elements.applyShared.disabled = selectedReferences.length === 0 || state.loading;
  elements.applyShared.title = selectedReferences.length
    ? `average the current bounds from ${selectedReferences.length.toLocaleString()} selected reference plot(s), apply them to every sample, and reintegrate`
    : "select at least one reference plot with usable integration bounds";
  elements.toolbar.classList.toggle("has-unsaved", hasEdits);
  elements.toolbar.classList.toggle(
    "has-reference-selection",
    selectedReferences.length > 0,
  );
  const canExport =
    Boolean(selection) &&
    !hasEdits &&
    !state.loading &&
    !state.exportingPngs &&
    state.renderComplete &&
    (state.qcGraphs.length > 0 || state.traceRecords.length > 0);
  const exportTitle = canExport
    ? "export all PNGs for the saved current reference"
    : "save current reference to export .pngs";
  elements.exportPngs.disabled = !canExport;
  elements.exportPngs.title = exportTitle;
  elements.exportPngsWrap.title = exportTitle;
}

// enables deletion only for user-created snapshots, keeping the protected
// original available as a safe baseline
function updateDeleteButton() {
  const name = elements.backups.value;
  const disabled = state.loading || !name || name === originalRtMatrix;
  elements.deleteBackup.disabled = disabled;
  elements.renameBackup.disabled = disabled;
  elements.importBackup.disabled = state.loading || !state.projectPath;
}

// stops the current graph construction pass while keeping whatever has already
// been drawn, so large selections can be abandoned without clearing useful
// preview plots from the screen.
function cancelRendering() {
  if (!state.loading) return;
  state.renderToken += 1;
  state.loading = false;
  elements.transition.disabled = false;
  elements.refresh.disabled = false;
  elements.importBackup.disabled = false;
  const [kind] = elements.transition.value.split(":");
  setRangeControlsDisabled(kind !== "t");
  updateSaveButton();
  updateDeleteButton();
  const rendered = state.traceRecords.length;
  const marker = document.createElement("div");
  marker.className = "visualizer-chart render-cancelled-marker";
  marker.textContent = "Remaining plots not rendered.";
  elements.plots.append(marker);
  setStatus(
    `Rendering cancelled. ${rendered.toLocaleString()} plot${
      rendered === 1 ? "" : "s"
    } shown; remaining plots not rendered.`,
  );
}

// the bridge app.js exposes for raising toasts and running Step 3
function shell() {
  return window.__mrmhubShell ?? null;
}

// returns the sortable local timestamp used by imported RT_matrix backups
function fileTimestamp(date = new Date()) {
  const pad = (value) => String(value).padStart(2, "0");
  return (
    `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}_` +
    `${pad(date.getHours())}-${pad(date.getMinutes())}-${pad(date.getSeconds())}`
  );
}

function exportSlug(value, fallback = "visualizer") {
  const slug = String(value ?? "")
    .normalize("NFKD")
    .replace(/[^a-zA-Z0-9._-]+/g, "_")
    .replace(/^_+|_+$/g, "")
    .slice(0, 80);
  return slug || fallback;
}

function themeColor(name, fallback) {
  return (
    getComputedStyle(document.documentElement).getPropertyValue(name).trim() ||
    fallback
  );
}

// Embeds the small graph stylesheet once instead of calling getComputedStyle
// for every node in every exported plot.
function pngSvgStyles() {
  const ink = themeColor("--ink", "#10202b");
  const muted = themeColor("--muted", "#72808a");
  const surface = themeColor("--surface", "#ffffff");
  const rose = themeColor("--rose", "#d45d79");
  const navy = themeColor("--navy-deep", "#172b4d");
  return `
    text { fill: ${ink}; stroke: none; font-family: Inter, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; font-size: calc(10px * var(--graph-font-scale, 1)); }
    .domain, .tick line { stroke: ${muted}; }
    .chart-title { font-size: calc(10px * var(--graph-font-scale, 1)); font-weight: 700; }
    .chart-detail { fill: ${muted}; font-size: calc(9px * var(--graph-font-scale, 1)); }
    .qc-trace, .chromatogram-trace { fill: none; stroke: ${ink}; stroke-width: 1.25; }
    .qc-marker { fill: ${surface}; stroke: ${rose}; stroke-width: 3; }
    .qc-tooltip rect, .trace-tooltip rect { fill: ${navy}; stroke: none; }
    .qc-tooltip text, .trace-tooltip text { fill: ${surface}; }
    .trace-tooltip circle { fill: ${ink}; stroke: none; }
    .trace-guide { stroke: ${muted}; stroke-width: 1.5; }
    .integration-area { stroke: none; opacity: 0.52; }
    .integration-window { stroke: none; opacity: 0.16; }
    .blank-label { fill: ${muted}; font-size: calc(54px * var(--graph-font-scale, 1)); opacity: 0.15; stroke: none; }
  `;
}

async function svgExportImage(svgNode) {
  const clone = svgNode.cloneNode(true);
  clone.setAttribute("xmlns", "http://www.w3.org/2000/svg");
  const style = document.createElementNS("http://www.w3.org/2000/svg", "style");
  style.textContent = pngSvgStyles();
  clone.prepend(style);
  const source = new XMLSerializer().serializeToString(clone);
  const url = URL.createObjectURL(
    new Blob([source], { type: "image/svg+xml;charset=utf-8" }),
  );
  try {
    const image = new Image();
    image.src = url;
    await image.decode();
    return image;
  } finally {
    URL.revokeObjectURL(url);
  }
}

// Draws a clean chromatogram trace for exported images. This deliberately
// ignores the interactive canvas so hover dots and sample-type colors cannot
// leak into the PNG; the line remains visible above the integration shading.
function drawExportTrace(context, graph, width, height) {
  const points = graph.points;
  if (!points || points.length < 4 || !graph.currentX || !graph.y) return;
  const count = points.length / 2;
  const step = Math.max(1, Math.ceil(count / Math.max(600, width * 2)));
  context.save();
  context.beginPath();
  context.rect(
    margins.left,
    margins.top,
    width - margins.left - margins.right,
    height - margins.top - margins.bottom,
  );
  context.clip();
  context.strokeStyle = themeColor("--ink", "#10202b");
  context.lineWidth = 1.5;
  context.lineJoin = "round";
  context.lineCap = "round";
  context.beginPath();
  for (let point = 0; point < count; point += step) {
    const x = graph.currentX(points[point * 2]);
    const y = graph.y(points[point * 2 + 1]);
    if (point === 0) context.moveTo(x, y);
    else context.lineTo(x, y);
  }
  if ((count - 1) % step !== 0) {
    context.lineTo(
      graph.currentX(points[(count - 1) * 2]),
      graph.y(points[(count - 1) * 2 + 1]),
    );
  }
  context.stroke();
  context.restore();
}

async function graphExportCanvas(graph, kind) {
  const scale = 2;
  const width = graph.width;
  const height = graph.height;
  const canvas = document.createElement("canvas");
  canvas.width = width * scale;
  canvas.height = height * scale;
  const context = canvas.getContext("2d", { alpha: false });
  context.scale(scale, scale);
  context.fillStyle = themeColor("--surface", "#ffffff");
  context.fillRect(0, 0, width, height);
  const overlay = await svgExportImage(graph.svg.node());
  context.drawImage(overlay, 0, 0, width, height);
  if (kind === "plots") {
    drawExportTrace(context, graph, width, height);
  }
  context.strokeStyle = themeColor("--line-strong", "#ced7dc");
  context.lineWidth = 1;
  context.strokeRect(0.5, 0.5, width - 1, height - 1);
  return canvas;
}

function pngBlob(canvas) {
  return new Promise((resolve, reject) => {
    canvas.toBlob(
      (blob) => (blob ? resolve(blob) : reject(new Error("PNG encoding failed"))),
      "image/png",
    );
  });
}

function blobBase64(blob) {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.addEventListener("load", () => {
      const result = String(reader.result ?? "");
      const separator = result.indexOf(",");
      if (separator < 0) reject(new Error("PNG encoding failed"));
      else resolve(result.slice(separator + 1));
    });
    reader.addEventListener("error", () =>
      reject(reader.error ?? new Error("PNG encoding failed")),
    );
    reader.readAsDataURL(blob);
  });
}

function disposeTransientGraph(graph) {
  if (graph?.svg) {
    graph.svg
      .on(".zoom", null)
      .on("pointerdown pointermove pointerup pointercancel pointerleave", null);
  }
  if (graph?.canvas) {
    graph.canvas.width = 0;
    graph.canvas.height = 0;
  }
  graph?.shell?.replaceChildren();
}

function exportGraph(item, kind) {
  if (kind !== "plots" || !item?.points) {
    return { graph: item, transient: false };
  }
  if (item.graph) {
    item.graph.applySampleTypeColor?.();
    return { graph: item.graph, transient: false };
  }
  return { graph: mountTraceRecord(item, { transient: true }), transient: true };
}

async function saveGraphSheets(graphs, kind, prefix, folderName) {
  if (!graphs.length) return 0;
  const exportScale = 2;
  const cardPixels = graphs[0].width * exportScale * graphs[0].height * exportScale;
  const perPage = Math.max(1, Math.min(12, Math.floor(24_000_000 / cardPixels)));
  let written = 0;
  for (let offset = 0; offset < graphs.length; offset += perPage) {
    const page = graphs.slice(offset, offset + perPage);
    const cards = [];
    for (const item of page) {
      const materialized = exportGraph(item, kind);
      if (!materialized.graph) continue;
      try {
        cards.push(await graphExportCanvas(materialized.graph, kind));
      } finally {
        if (materialized.transient) disposeTransientGraph(materialized.graph);
      }
    }
    if (!cards.length) continue;
    const columns = Math.min(3, cards.length);
    const rows = Math.ceil(cards.length / columns);
    const gap = 24;
    const cardWidth = cards[0].width;
    const cardHeight = cards[0].height;
    const sheet = document.createElement("canvas");
    sheet.width = columns * cardWidth + (columns + 1) * gap;
    sheet.height = rows * cardHeight + (rows + 1) * gap;
    const context = sheet.getContext("2d", { alpha: false });
    context.fillStyle = themeColor("--canvas", "#f5f7f8");
    context.fillRect(0, 0, sheet.width, sheet.height);
    cards.forEach((card, index) => {
      const column = index % columns;
      const row = Math.floor(index / columns);
      context.drawImage(
        card,
        gap + column * (cardWidth + gap),
        gap + row * (cardHeight + gap),
      );
      card.width = 0;
      card.height = 0;
    });
    const blob = await pngBlob(sheet);
    sheet.width = 0;
    sheet.height = 0;
    const dataBase64 = await blobBase64(blob);
    const pageNumber = String(Math.floor(offset / perPage) + 1).padStart(2, "0");
    await invoke("visualizer_save_png", {
      projectPath: state.projectPath,
      folderName,
      fileName: `${prefix}_${kind}_${pageNumber}.png`,
      dataBase64,
    });
    written += 1;
    const renderedGraphs = Math.min(offset + page.length, graphs.length);
    setStatus(
      `Exporting PNGs: ${renderedGraphs.toLocaleString()} of ${graphs.length.toLocaleString()} ${kind === "qc" ? "QC" : "chromatogram"} graph(s) written...`,
    );
    await new Promise((resolve) => requestAnimationFrame(resolve));
  }
  return written;
}

async function exportRenderedPngs() {
  if (
    elements.exportPngs.disabled ||
    state.exportingPngs ||
    !state.projectPath ||
    (!state.qcGraphs.length && !state.traceRecords.length)
  ) {
    return null;
  }
  state.exportingPngs = true;
  updateSaveButton();
  const [kind, rawIndex] = elements.transition.value.split(":");
  const index = Number(rawIndex);
  const selectionName =
    kind === "r"
      ? state.references[index]?.slice(3)
      : `${state.transitions[index]?.name ?? "transition"}_${state.transitions[index]?.cqq ?? index}`;
  const prefix = exportSlug(selectionName, kind === "r" ? "reference" : "transition");
  const folderName = `${fileTimestamp()}_${prefix}`;
  setStatus("Exporting rendered QC and chromatogram PNG sheets...");
  shell()?.showToast?.("PNG export started. Creating the dataset export folder...");
  try {
    const exportPath = await invoke("visualizer_prepare_png_export", {
      projectPath: state.projectPath,
      folderName,
    });
    setStatus(`Export folder ready: ${exportPath}`);
    const qcSheets = await saveGraphSheets(
      state.qcGraphs,
      "qc",
      prefix,
      folderName,
    );
    const plotSheets = await saveGraphSheets(
      state.traceRecords,
      "plots",
      prefix,
      folderName,
    );
    const count = qcSheets + plotSheets;
    setStatus(
      `Saved ${count.toLocaleString()} PNG sheet(s) to visualizer_png/${folderName}`,
    );
    shell()?.showToast?.(`Exported ${count.toLocaleString()} visualizer PNG sheet(s).`);
  } catch (error) {
    setStatus(`PNG export failed: ${String(error)}`);
    shell()?.showToast?.(`PNG export failed: ${String(error)}`, "error");
  } finally {
    state.exportingPngs = false;
    updateSaveButton();
  }
}

// builds the timestamped file name for an imported RT_matrix backup
function backupFileName(date = new Date()) {
  return `RT_matrix_${fileTimestamp(date)}.csv`;
}

// turns a backup file name into a readable "HH:MM:SS  MM/DD/YYYY" label
function backupLabelFallback(name) {
  if (name === originalRtMatrix) {
    return "Original RT_matrix";
  }
  const match = name.match(/(\d{4})-(\d{2})-(\d{2})_(\d{2})-(\d{2})-(\d{2})/);
  if (!match) return name;
  const [, year, month, day, hour, minute, second] = match;
  return `${hour}:${minute}:${second}  ${month}/${day}/${year}`;
}

// returns the user-facing dropdown label, honoring any stored custom rename
function backupLabel(name) {
  return state.backupLabels[name] ?? backupLabelFallback(name);
}

// reloads the version dropdown, selecting `selected` (or the remembered one).
// setting .value programmatically does not fire "change", so this never reverts
async function refreshBackups(selected) {
  const showEmpty = () => {
    const fragment = document.createDocumentFragment();
    appendOption(fragment, "No saved versions yet", "");
    elements.backups.replaceChildren(fragment);
    state.backupLabels = {};
    updateDeleteButton();
  };
  if (!state.projectPath) {
    showEmpty();
    return;
  }
  let list;
  try {
    list = await invoke("list_rtmatrix_backups", {
      projectPath: state.projectPath,
    });
  } catch {
    showEmpty();
    return;
  }
  state.backupLabels = list.labels ?? {};
  const fragment = document.createDocumentFragment();
  if (!list.backups.length) {
    appendOption(fragment, "No saved versions yet", "");
  } else {
    for (const name of list.backups) {
      const label = backupLabel(name);
      const text = state.backupLabels[name]
        ? `${label} (${backupLabelFallback(name)})`
        : label;
      appendOption(fragment, text, name);
    }
  }
  elements.backups.replaceChildren(fragment);
  const target =
    selected ??
    list.last ??
    (list.backups.includes(originalRtMatrix) ? originalRtMatrix : "");
  elements.backups.value = list.backups.includes(target) ? target : "";
  updateDeleteButton();
}

// restores a chosen backup and re-integrates so the graphs reflect it
async function onBackupChange() {
  const name = elements.backups.value;
  const bridge = shell();
  if (!name || state.loading || !bridge?.runStep) return;
  const scrollY = window.scrollY;
  elements.backups.disabled = true;
  elements.deleteBackup.disabled = true;
  elements.renameBackup.disabled = true;
  setStatus(`Restoring ${backupLabel(name)} and re-integrating...`);
  try {
    await invoke("restore_rtmatrix_backup", {
      projectPath: state.projectPath,
      name,
    });
    await invoke("set_last_backup", { projectPath: state.projectPath, name });
    // the snapshot already exists, so this Step 3 run must not create another
    const result = await bridge.runStep(3, { backup: false });
    if (result.success) {
      await renderSelected({ preserveScroll: true, scrollY });
      bridge.showToast?.(`Reverted to ${backupLabel(name)} and re-integrated.`);
      setStatus(`Showing ${backupLabel(name)}.`);
    } else {
      setStatus(`Restored ${backupLabel(name)}, but Step 3 did not finish.`);
    }
  } catch (error) {
    setStatus(`Revert failed: ${String(error)}`);
  } finally {
    elements.backups.disabled = false;
    updateDeleteButton();
  }
}

// deletes one timestamped RT_matrix snapshot after confirmation
async function deleteSelectedBackup() {
  const name = elements.backups.value;
  const bridge = shell();
  if (state.loading || !name || name === originalRtMatrix) return;
  const confirmed = window.confirm(
    `Delete RT_matrix backup "${backupLabel(name)}"?\n\nThis only deletes the saved backup file. Your current RT_matrix.csv will not be changed.`,
  );
  if (!confirmed) return;
  elements.deleteBackup.disabled = true;
  elements.renameBackup.disabled = true;
  elements.backups.disabled = true;
  setStatus(`Deleting ${backupLabel(name)}...`);
  try {
    await invoke("delete_rtmatrix_backup", {
      projectPath: state.projectPath,
      name,
    });
    await refreshBackups();
    bridge?.showToast?.(`Deleted ${backupLabel(name)}.`);
    setStatus(`Deleted ${backupLabel(name)}.`);
  } catch (error) {
    setStatus(`Delete failed: ${String(error)}`);
  } finally {
    elements.backups.disabled = false;
    updateDeleteButton();
  }
}

// renames the selected backup's dropdown label without changing its file name
async function renameSelectedBackup() {
  const name = elements.backups.value;
  const bridge = shell();
  if (state.loading || !name || name === originalRtMatrix) return;
  const current = backupLabel(name);
  const message = `Rename the selected RT_matrix backup:\n\nCurrently selected: ${current}\nFile: ${name}\n\nEnter the new dropdown label:`;
  // window.prompt is not implemented in the macOS webview, so use the in-app
  // prompt exposed by app.js (falling back to window.prompt on Windows only)
  const label = bridge?.prompt
    ? await bridge.prompt(message, current, "Rename backup")
    : window.prompt(message, current);
  if (label == null) return;
  const trimmed = label.trim();
  if (!trimmed) {
    bridge?.showToast?.("Backup label cannot be blank.", "error");
    setStatus("Rename cancelled: backup label cannot be blank.");
    return;
  }
  elements.deleteBackup.disabled = true;
  elements.renameBackup.disabled = true;
  elements.backups.disabled = true;
  setStatus(`Renaming ${current}...`);
  try {
    await invoke("rename_rtmatrix_backup", {
      projectPath: state.projectPath,
      name,
      label: trimmed,
    });
    await refreshBackups(name);
    bridge?.showToast?.(`Renamed backup to ${trimmed}.`);
    setStatus(`Renamed backup to ${trimmed}.`);
  } catch (error) {
    setStatus(`Rename failed: ${String(error)}`);
  } finally {
    elements.backups.disabled = false;
    updateDeleteButton();
  }
}

// imports an external CSV into the backup folder, selects it, and re-integrates
async function importBackupCsv() {
  const bridge = shell();
  if (state.loading || !state.projectPath) return;
  const sourcePath = await dialog.open({
    directory: false,
    multiple: false,
    title: "Import an RT_matrix CSV backup",
    filters: [{ name: "CSV", extensions: ["csv"] }],
  });
  if (!sourcePath) return;
  const scrollY = window.scrollY;
  elements.importBackup.disabled = true;
  elements.deleteBackup.disabled = true;
  elements.renameBackup.disabled = true;
  elements.backups.disabled = true;
  setStatus("Importing RT_matrix backup...");
  try {
    const imported = await invoke("import_rtmatrix_backup", {
      projectPath: state.projectPath,
      sourcePath,
      name: backupFileName(),
    });
    await refreshBackups(imported.name);
    await invoke("restore_rtmatrix_backup", {
      projectPath: state.projectPath,
      name: imported.name,
    });
    if (bridge?.runStep) {
      setStatus(`Imported ${imported.label}. Re-integrating (Step 3)...`);
      const result = await bridge.runStep(3, { backup: false });
      if (result.success) {
        await renderSelected({ preserveScroll: true, scrollY });
        bridge.showToast?.(`Imported and loaded ${imported.label}.`);
        setStatus(`Showing imported backup ${imported.label}.`);
      } else {
        setStatus(`Imported ${imported.label}, but Step 3 did not finish.`);
      }
    } else {
      setStatus(`Imported ${imported.label}.`);
    }
  } catch (error) {
    setStatus(`Import failed: ${String(error)}`);
  } finally {
    elements.backups.disabled = false;
    updateDeleteButton();
  }
}

function individualBoundEdits() {
  return state.traceRecords
    .filter((record) => record.editRts?.size > 0 && record.editContext?.cqq)
    .flatMap((record) =>
      [...record.editRts.entries()].map(([isomerIndex, edit]) => ({
        cqq: record.editContext.cqq,
        sampleIndex: record.editContext.sampleIndex,
        fileName: record.editContext.fileName,
        isomerIndex,
        rtStart: edit.start,
        rtEnd: edit.end,
      })),
    );
}

// Averages selected reference windows by transition/isomer. Existing bounds
// are used when a reference was selected without being dragged; an edited
// isomer uses its dragged bounds instead. The backend applies each compact edit
// directly to every RT_matrix sample row.
function sharedReferenceBoundEdits() {
  const windows = new Map();
  for (const record of state.traceRecords) {
    if (
      state.referenceChoices.get(referenceChoiceKey(record)) !== true ||
      !record.editContext?.cqq
    ) {
      continue;
    }
    for (const [isomerIndex, edit] of referenceBounds(record)) {
      const key = `${record.editContext.cqq}:${isomerIndex}`;
      const window = windows.get(key) ?? {
        cqq: record.editContext.cqq,
        isomerIndex,
        startTotal: 0,
        endTotal: 0,
        count: 0,
      };
      window.startTotal += edit.start;
      window.endTotal += edit.end;
      window.count += 1;
      windows.set(key, window);
    }
  }

  const edits = [];
  for (const window of windows.values()) {
    const rtStart = window.startTotal / window.count;
    const rtEnd = window.endTotal / window.count;
    if (!Number.isFinite(rtStart) || !Number.isFinite(rtEnd) || rtEnd <= rtStart) {
      continue;
    }
    edits.push({
      cqq: window.cqq,
      isomerIndex: window.isomerIndex,
      rtStart,
      rtEnd,
    });
  }
  return { edits, windowCount: windows.size };
}

async function writeAndReintegrate(edits, options = {}) {
  if (state.loading || !edits.length) return;
  const scrollY = window.scrollY;
  const shared = Boolean(options.shared);
  const sharedWindowCount = Number(options.windowCount) || edits.length;
  const sharedScope = `${sharedWindowCount.toLocaleString()} RT window(s) across ${state.samples.length.toLocaleString()} samples`;

  const bridge = shell();
  elements.save.disabled = true;
  elements.applyShared.disabled = true;
  elements.deleteBackup.disabled = true;
  setStatus(
    shared
      ? `Applying ${sharedScope}...`
      : `Saving ${edits.length} integration bound(s)...`,
  );
  try {
    const written = await invoke(
      shared ? "visualizer_save_shared_bounds" : "visualizer_save_bounds",
      {
        projectPath: state.projectPath,
        edits,
      },
    );
    for (const record of state.traceRecords) {
      record.editRts?.clear();
      if (record.graph) {
        record.graph.hasEdit = false;
        record.graph.editRt = null;
      }
    }

    if (!bridge?.runStep) {
      setStatus(
        `${shared ? "Applied" : "Saved"} ${written} bound(s) to RT_matrix.csv. Run Step 3 to recompute.`,
      );
      return;
    }
    setStatus(
      shared
        ? `Applied ${sharedScope} (${written.toLocaleString()} bounds). Re-integrating (Step 3)...`
        : `Saved ${written} bound(s). Re-integrating (Step 3)...`,
    );
    const result = await bridge.runStep(3, { backup: true });
    if (result.success) {
      if (result.backup) {
        await invoke("set_last_backup", {
          projectPath: state.projectPath,
          name: result.backup,
        });
      }
      await refreshBackups(result.backup);
      // A successful shared apply consumes the reference selection. Clear it
      // before re-rendering so the refreshed plots and toolbar return to their
      // unselected/disabled state; failed Step 3 runs retain the selection for
      // an easy retry.
      if (shared) state.referenceChoices.clear();
      await renderSelected({ preserveScroll: true, scrollY });
      setStatus(
        shared
          ? `Applied ${sharedScope} and re-integrated.`
          : `Saved and re-integrated ${written} bound(s).`,
      );
    } else {
      await refreshBackups();
      setStatus(`Saved to RT_matrix.csv, but Step 3 did not finish.`);
    }
  } catch (error) {
    setStatus(`Save failed: ${String(error)}`);
  } finally {
    updateSaveButton();
    updateDeleteButton();
  }
}

// writes every dragged colored band into RT_matrix.csv, then re-integrates so
// the change actually lands; each edit carries its own transition, sample, and
// isomer index, so both transition and reference views share this path
async function saveBounds() {
  await writeAndReintegrate(individualBoundEdits());
}

async function applySharedRtLimits() {
  const { edits, windowCount } = sharedReferenceBoundEdits();
  if (!edits.length || windowCount === 0) {
    setStatus("Select at least one RT reference plot with usable integration bounds.");
    return;
  }
  await writeAndReintegrate(edits, { shared: true, windowCount });
}

// renders the current chooser value without allowing overlapping streams
async function renderSelected(options = {}) {
  const value = elements.transition.value;
  if (!value || state.loading) return;
  const scrollY =
    options.scrollY ?? (options.preserveScroll ? window.scrollY : null);
  clearPlots();
  state.loading = true;
  elements.transition.disabled = true;
  elements.refresh.disabled = true;
  elements.save.disabled = true;
  elements.exportPngs.disabled = true;
  elements.applyShared.disabled = true;
  elements.deleteBackup.disabled = true;
  elements.renameBackup.disabled = true;
  elements.importBackup.disabled = true;
  setRangeControlsDisabled(true);
  const token = state.renderToken;
  const [kind, rawIndex] = value.split(":");
  const index = Number(rawIndex);
  configureTraceVirtualization(
    kind === "t" ? state.samples.length : state.transitions.length,
  );
  elements.range.classList.toggle("hidden", kind !== "t");
  setStatus("Preparing graphs...");

  try {
    if (kind === "t") {
      await renderTransition(state.transitions[index], token);
    } else {
      await renderReference(state.references[index], token);
    }
    state.renderComplete = true;
  } catch (error) {
    if (token === state.renderToken) {
      setStatus(`Visualizer error: ${String(error)}`);
    }
  } finally {
    if (token !== state.renderToken) return;
    state.loading = false;
    elements.transition.disabled = false;
    elements.refresh.disabled = false;
    setRangeControlsDisabled(kind !== "t");
    updateSaveButton();
    updateDeleteButton();
    if (scrollY != null) {
      requestAnimationFrame(() => {
        requestAnimationFrame(() => {
          window.scrollTo({ top: scrollY, left: window.scrollX, behavior: "auto" });
        });
      });
    }
  }
}

// allows the Integrator/editor shell to refresh the currently displayed graphs
// after Step 3 rewrites integration outputs.
export async function refreshCurrentVisualizer(options = {}) {
  await renderSelected(options);
}

elements.transition.addEventListener("change", () => {
  state.rangeManuallySet = false;
  elements.rtStart.value = "0";
  elements.rtEnd.value = "0";
  renderSelected();
});
for (const eventName of ["input", "change", "search", "keyup", "compositionend"]) {
  elements.transitionSearch.addEventListener(eventName, applyTransitionSearch);
}
elements.refresh.addEventListener("click", () =>
  renderSelected({ preserveScroll: true }),
);
document.addEventListener("mrmhub-gui-scale-change", () => {
  applyVisualizerScale();
});
elements.colorSampleTypes.addEventListener("change", () => {
  applySampleTypeColorPreference(elements.colorSampleTypes.checked);
  for (const graph of state.traceGraphs) {
    if (!state.virtualizedTraces || graphNearViewport(graph)) {
      graph.applySampleTypeColor?.();
    }
  }
});
elements.exportPngs.addEventListener("click", async () => {
  await exportRenderedPngs();
  elements.exportPngs.blur();
});
elements.exportPngsWrap.addEventListener("pointerdown", () => {
  if (elements.exportPngs.disabled) {
    shell()?.showToast?.("Save current reference to export .pngs");
  }
});
elements.rtStart.addEventListener("change", () => {
  if (state.loading) return;
  state.rangeManuallySet = true;
  renderSelected({ preserveScroll: true });
});
elements.rtEnd.addEventListener("change", () => {
  if (state.loading) return;
  state.rangeManuallySet = true;
  renderSelected({ preserveScroll: true });
});
elements.intensity.addEventListener("input", () => {
  if (state.loading) return;
  if (state.traceRedrawFrame) return;
  state.traceRedrawFrame = requestAnimationFrame(() => {
    state.traceRedrawFrame = 0;
    applyGlobalIntensity();
  });
});
elements.save.addEventListener("click", saveBounds);
elements.applyShared.addEventListener("click", applySharedRtLimits);
elements.deleteBackup.addEventListener("click", deleteSelectedBackup);
elements.renameBackup.addEventListener("click", renameSelectedBackup);
elements.importBackup.addEventListener("click", importBackupCsv);
elements.backups.addEventListener("change", onBackupChange);
elements.status.addEventListener("click", () => {
  if (elements.status.classList.contains("is-cancellable")) {
    cancelRendering();
  }
});
elements.cancelRender?.addEventListener("click", cancelRendering);
elements.view?.addEventListener("pointerdown", (event) => {
  if (!(event.target instanceof Element)) return;
  if (!event.target.closest(".visualizer-canvas-frame")) {
    state.selectedIsomerIndex = null;
  }
});
elements.globalShortcuts?.addEventListener("change", () => {
  elements.globalShortcuts.blur();
});
elements.selectorExpand.addEventListener("click", () => {
  const collapsed = elements.toolbar.classList.toggle("selector-collapsed");
  const label = collapsed ? "expand graph selector" : "collapse graph selector";
  elements.selectorExpand.setAttribute("aria-expanded", String(!collapsed));
  elements.selectorExpand.setAttribute("aria-label", label);
  elements.selectorExpand.title = label;
});

document.addEventListener("keydown", (event) => {
  const target = event.target;
  const visualizerOpen = !elements.view?.classList.contains("hidden");
  const collapsed = elements.toolbar.classList.contains("selector-collapsed");
  const shortcutToggleFocused = target === elements.globalShortcuts;
  const isTypingTarget =
    (target instanceof HTMLInputElement && !shortcutToggleFocused) ||
    target instanceof HTMLTextAreaElement ||
    target?.isContentEditable;
  if (visualizerOpen && !isTypingTarget) {
    const shortcutsEnabled =
      !collapsed || elements.globalShortcuts?.checked !== false;
    if (shortcutsEnabled && !state.loading) {
      if (event.key === "ArrowUp" || event.key === "ArrowDown") {
        event.preventDefault();
        const delta = event.key === "ArrowDown" ? 1 : -1;
        const next = Math.max(
          0,
          Math.min(
            elements.transition.options.length - 1,
            elements.transition.selectedIndex + delta,
          ),
        );
        if (next !== elements.transition.selectedIndex) {
          elements.transition.selectedIndex = next;
          const option = elements.transition.options[next];
          if (option?.value) {
            setStatus(`${option.textContent} selected. Press Enter to render.`);
          } else {
            setStatus("Choose a transition or reference, then press Enter to render.");
          }
        }
        return;
      }
      if (event.key === "Enter") {
        if (elements.transition.value) {
          event.preventDefault();
          state.rangeManuallySet = false;
          elements.rtStart.value = "0";
          elements.rtEnd.value = "0";
          renderSelected();
        }
        return;
      }
      if (event.key === "ArrowLeft") {
        event.preventDefault();
        renderSelected({ preserveScroll: true });
        return;
      }
      if (event.key === "ArrowRight") {
        event.preventDefault();
        if (!elements.save.disabled) saveBounds();
        return;
      }
    }
  }
  if (
    !state.hoveredGraph ||
    isTypingTarget ||
    target instanceof HTMLSelectElement ||
    target?.isContentEditable
  ) {
    return;
  }
  const zoomIn = event.key === "=" || event.key === "+";
  const zoomOut = event.key === "-";
  if (!zoomIn && !zoomOut) return;
  event.preventDefault();
  const graph = state.hoveredGraph;
  graph.zoom.scaleBy(
    graph.svg,
    zoomIn ? 1.25 : 0.8,
    [graph.hoverX, margins.top],
  );
});
