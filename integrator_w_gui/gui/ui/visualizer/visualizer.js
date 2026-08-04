const { invoke, Channel } = window.__TAURI__.core;
const dialog = window.__TAURI__.dialog;
const d3 = window.d3;
const decoder = new TextDecoder();
const originalRtMatrix = "RT_matrix_original.csv";
const formatRt = d3.format(".2f");
const formatIntensity = d3.format(",.0f");
const fontScalePreference = "mrmhub-visualizer-font-scale";
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
  fontScale: document.querySelector("#visualizer-font-scale"),
  colorSampleTypes: document.querySelector("#visualizer-color-sample-types"),
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
};

const margins = {
  top: 18,
  right: 10,
  bottom: 18,
  left: 38,
};

const traceBatchSize = 4;
const traceBatchBudgetMs = 10;
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

function applyVisualizerScale(scalePercent, persist = true) {
  const percent = [100, 125, 150, 175, 200].includes(Number(scalePercent))
    ? Number(scalePercent)
    : 100;
  state.fontScale = percent / 100;
  elements.fontScale.value = String(percent);
  elements.view?.style.setProperty("--visualizer-font-scale", String(state.fontScale));
  updatePlotMargins();
  if (persist) rememberPreference(fontScalePreference, percent);
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

applyVisualizerScale(storedPreference(fontScalePreference), false);
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
  state.hoveredGraph = null;
  state.qcGraphs.length = 0;
  state.traceGraphs.length = 0;
  elements.qc.replaceChildren();
  elements.plots.replaceChildren();
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
  const count = state.traceGraphs.filter((item) => item.isReferenceChoice).length;
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
  const { width, height } = graphDimensions();
  const range = graphRange();
  const points = packPoints(plot.te);
  plot.te = null;
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
  const traceColor = state.colorSampleTypes
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
  svg
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
    isReferenceChoice: false,
    editContext,
    integrations,
    dotIndices,
    dotsVisible: false,
    drawTraceCanvas,
    y,
    hasEdit: false,
    editRt: null,
    editRts: new Map(),
    panSlider: null,
    zoomTransform: d3.zoomIdentity,
  };
  state.traceGraphs.push(graph);

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

  ySlider.addEventListener("input", updateYScale);
  ySlider.addEventListener(
    "wheel",
    (event) => {
      event.preventDefault();
      const delta = event.deltaY < 0 ? 36 : -36;
      ySlider.value = String(
        Math.max(0, Math.min(1000, Number(ySlider.value) + delta)),
      );
      updateYScale();
    },
    { passive: false },
  );
  const zoom = wheelZoom(width, height, (event) => {
    graph.zoomTransform = event.transform;
    redrawTrace(event.transform.rescaleX(x));
    updatePanSlider(event.transform);
  });
  graph.zoom = zoom;
  graph.svg = svg;
  svg.call(zoom).call(zoom.transform, d3.zoomIdentity);

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
        graph.editRts = preDrag ? preDrag.editRts : new Map();
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
  const referenceToggle = createReferenceToggle(graph);
  frame.append(canvas, svg.node(), ySlider, referenceToggle);
  shell.replaceChildren(frame, panSlider);
  if (!options.shell) {
    container.append(shell);
  }
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
    if (streamDone && !scheduled && cursor >= queue.length) {
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
      const job = queue[cursor];
      cursor += 1;
      if (job.rendered) continue;
      job.rendered = true;
      renderTrace(
        job.plot,
        job.sample,
        job.index,
        job.container,
        job.isReference,
        job.editContext,
      );
      job.plot = null;
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
      queue.push(job);
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
    setStatus(`${rendered.toLocaleString()} chromatograms rendered`);
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
    setStatus(`${rendered.toLocaleString()} reference chromatograms rendered`);
  }
}

// enables Save whenever any graph (transition or reference view) holds an
// unsaved dragged band that maps to a known transition
function updateSaveButton() {
  const hasEdits = state.traceGraphs.some(
    (graph) => graph.editRts?.size > 0 && graph.editContext?.cqq,
  );
  const changedReferences = state.traceGraphs.filter(
    (graph) =>
      graph.isReferenceChoice &&
      graph.editRts?.size > 0 &&
      graph.editContext?.cqq,
  );
  elements.save.disabled = !hasEdits || state.loading;
  elements.applyShared.disabled = changedReferences.length === 0 || state.loading;
  elements.applyShared.title = changedReferences.length
    ? `average ${changedReferences.length.toLocaleString()} changed reference plot(s), apply the RT limits to every sample, and reintegrate`
    : "select a reference plot and adjust its integration bounds first";
  elements.toolbar.classList.toggle("has-unsaved", hasEdits);
  elements.toolbar.classList.toggle(
    "has-reference-edits",
    changedReferences.length > 0,
  );
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
  const rendered = state.traceGraphs.length;
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
  return state.traceGraphs
    .filter((graph) => graph.editRts?.size > 0 && graph.editContext?.cqq)
    .flatMap((graph) =>
      [...graph.editRts.entries()].map(([isomerIndex, edit]) => ({
        cqq: graph.editContext.cqq,
        sampleIndex: graph.editContext.sampleIndex,
        fileName: graph.editContext.fileName,
        isomerIndex,
        rtStart: edit.start,
        rtEnd: edit.end,
      })),
    );
}

// averages changed reference windows by transition/isomer, then expands each
// average across every sample row so the resulting RT limits are identical.
function sharedReferenceBoundEdits() {
  const windows = new Map();
  for (const graph of state.traceGraphs) {
    if (
      !graph.isReferenceChoice ||
      !graph.editContext?.cqq ||
      !graph.editRts?.size
    ) {
      continue;
    }
    for (const [isomerIndex, edit] of graph.editRts) {
      const key = `${graph.editContext.cqq}:${isomerIndex}`;
      const window = windows.get(key) ?? {
        cqq: graph.editContext.cqq,
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
    state.samples.forEach((sample, sampleIndex) => {
      edits.push({
        cqq: window.cqq,
        sampleIndex,
        fileName: sample[0] ?? "",
        isomerIndex: window.isomerIndex,
        rtStart,
        rtEnd,
      });
    });
  }
  return { edits, windowCount: windows.size };
}

async function writeAndReintegrate(edits, options = {}) {
  if (state.loading || !edits.length) return;
  const scrollY = window.scrollY;
  const shared = Boolean(options.shared);

  const bridge = shell();
  elements.save.disabled = true;
  elements.applyShared.disabled = true;
  elements.deleteBackup.disabled = true;
  setStatus(
    shared
      ? `Applying shared RT limits to ${state.samples.length.toLocaleString()} samples...`
      : `Saving ${edits.length} integration bound(s)...`,
  );
  try {
    const written = await invoke("visualizer_save_bounds", {
      projectPath: state.projectPath,
      edits,
    });
    for (const graph of state.traceGraphs) {
      graph.hasEdit = false;
      graph.editRt = null;
      graph.editRts?.clear();
    }

    if (!bridge?.runStep) {
      setStatus(
        `${shared ? "Applied" : "Saved"} ${written} bound(s) to RT_matrix.csv. Run Step 3 to recompute.`,
      );
      return;
    }
    setStatus(
      `${shared ? "Applied shared RT limits to" : "Saved"} ${written} bound(s). Re-integrating (Step 3)...`,
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
      await renderSelected({ preserveScroll: true, scrollY });
      setStatus(
        shared
          ? `Applied shared RT limits and re-integrated ${written} bound(s).`
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
    setStatus("Select an RT reference plot and drag its integration bounds first.");
    return;
  }
  await writeAndReintegrate(edits, { shared: true });
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
  elements.applyShared.disabled = true;
  elements.deleteBackup.disabled = true;
  elements.renameBackup.disabled = true;
  elements.importBackup.disabled = true;
  setRangeControlsDisabled(true);
  const token = state.renderToken;
  const [kind, rawIndex] = value.split(":");
  const index = Number(rawIndex);
  elements.range.classList.toggle("hidden", kind !== "t");
  setStatus("Preparing graphs...");

  try {
    if (kind === "t") {
      await renderTransition(state.transitions[index], token);
    } else {
      await renderReference(state.references[index], token);
    }
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
elements.fontScale.addEventListener("change", () => {
  applyVisualizerScale(elements.fontScale.value);
  if (elements.transition.value && !state.loading) {
    renderSelected({ preserveScroll: true });
  }
});
elements.colorSampleTypes.addEventListener("change", () => {
  applySampleTypeColorPreference(elements.colorSampleTypes.checked);
  if (elements.transition.value && !state.loading) {
    renderSelected({ preserveScroll: true });
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
  applyGlobalIntensity();
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
