import { referenceBounds } from "./reference-bounds.js";
import { windowKey } from "./sequence.js";

const views = new WeakMap();
let chartId = 0;
const palette = [
  "var(--cyan)",
  "var(--orange)",
  "var(--green)",
  "var(--rose)",
  "#9782c3",
  "#5faaa0",
];

export function clearSequenceChart(container) {
  views.delete(container);
  container.onkeydown = null;
  container.replaceChildren();
}

export function zoomSequence(container, factor, center) {
  const view = views.get(container);
  if (view?.zoom) {
    view.svg.call(
      view.zoom.scaleBy,
      factor,
      center ?? [(view.left + view.right) / 2, 60],
    );
  }
}

export function resetSequenceZoom(container) {
  const view = views.get(container);
  if (view?.zoom) view.svg.call(view.zoom.transform, window.d3.zoomIdentity);
}

// One SVG and compact window records. Zoom never requests traces or changes
// bounds. Each batch gets separate paths, including in the combined overview.
export function drawSequence(
  container,
  display,
  records,
  references,
  plan,
  isomer,
  select,
  scope = "",
  legend,
) {
  const d3 = window.d3;
  const bySample = new Map(
    records.map((record) => [record.editContext.sampleIndex, record]),
  );
  const anchors = new Set(
    references.filter((ref) => ref.isomerIndex === isomer).map((ref) =>
      ref.sampleIndex
    ),
  );
  const proposed = new Map(
    (plan?.edits ?? []).map((edit) => [windowKey(edit), edit]),
  );
  const rows = display.rows.map((row) => {
    const record = bySample.get(row.sampleIndex);
    return {
      ...row,
      record,
      current: record ? referenceBounds(record).get(isomer) : null,
      next: proposed.get(
        `${record?.editContext.cqq}:${row.sampleIndex}:${isomer}`,
      ),
      anchor: anchors.has(row.sampleIndex),
    };
  });
  const rowsByBatch = new Map(display.groups.map((group) => [group.name, []]));
  for (const row of rows) rowsByBatch.get(row.batch).push(row);
  const groups = display.groups.map((group, index) => ({
    name: group.name,
    color: display.all ? palette[index % palette.length] : "var(--muted)",
    rows: rowsByBatch.get(group.name),
  }));
  legend?.replaceChildren();
  legend?.classList.toggle("hidden", !display.all || groups.length < 2);
  if (display.all && legend) {
    for (const group of groups) {
      const label = document.createElement("span");
      label.style.color = group.color;
      label.textContent = `● Batch ${group.name}`;
      legend.append(label);
    }
  }
  const values = rows.flatMap(
    (row) => [
      row.current?.start,
      row.current?.end,
      row.next?.rtStart,
      row.next?.rtEnd,
    ],
  ).filter(Number.isFinite);
  const key = `${scope}:${display.all}:${display.name}:${
    rows.map((row) => `${row.sampleIndex}@${row.position}`).join(",")
  }`;
  const previous = views.get(container);
  const visibleDomain = previous?.key === key ? previous.visibleDomain : null;
  container.replaceChildren();
  if (!rows.length || !values.length) {
    views.delete(container);
    container.onkeydown = null;
    container.textContent =
      "No integration bounds yet. Drag a window on a chromatogram to create one.";
    return;
  }
  const width = Math.max(360, container.clientWidth),
    height = 192,
    left = 60,
    right = width - 24,
    top = 14,
    bottom = height - 40;
  const extent = d3.extent(rows, (row) => row.position);
  if (extent[0] === extent[1]) {
    extent[0] -= 1;
    extent[1] += 1;
  }
  const x = d3.scaleLinear().domain(extent).range([left, right]);
  const [low, high] = d3.extent(values),
    pad = Math.max((high - low) * .15, .015);
  const y = d3.scaleLinear().domain([Math.max(0, low - pad), high + pad]).range(
    [bottom, top],
  );
  const svg = d3.create("svg").attr("viewBox", `0 0 ${width} ${height}`).attr(
    "role",
    "group",
  )
    .attr(
      "aria-label",
      `RT start and end, ${
        display.all ? "all batches" : `batch ${display.name}`
      }; select reference samples`,
    );
  const clipId = `sequence-clip-${++chartId}`;
  svg.append("defs").append("clipPath").attr("id", clipId).append("rect")
    .attr("x", left).attr("y", top - 5).attr("width", right - left).attr(
      "height",
      bottom - top + 10,
    );
  const plot = svg.append("g").attr("clip-path", `url(#${clipId})`);
  const axis = svg.append("g").attr("transform", `translate(0,${bottom})`);
  svg.append("g").attr("transform", `translate(${left},0)`).call(
    d3.axisLeft(y).ticks(4).tickFormat(d3.format(".3f")),
  );
  svg.append("text").attr("x", 8).attr("y", 10).text("RT (min)");
  svg.append("text").attr("x", width / 2).attr("y", height - 3).attr(
    "text-anchor",
    "middle",
  )
    .text(
      display.timed
        ? `Elapsed acquisition time ${
          display.all ? "across all batches" : "within batch"
        }`
        : `Sample order ${
          display.all ? "across all batches" : "within batch"
        } (timestamp fallback)`,
    );
  const separators = [];
  if (display.all) {
    for (let i = 1; i < rows.length; i++) {
      if (rows[i - 1].batch !== rows[i].batch) {
        separators.push((rows[i - 1].position + rows[i].position) / 2);
      }
    }
  }
  const rules = plot.selectAll(".sequence-batch-boundary").data(separators)
    .join("line")
    .attr("class", "sequence-batch-boundary").attr("y1", top).attr(
      "y2",
      bottom,
    );
  const paths = [];
  for (const group of groups) {
    for (const edge of ["start", "end"]) {
      paths.push({
        group,
        edge,
        proposal: false,
        node: plot.append("path").attr("class", "sequence-current").style(
          "stroke",
          group.color,
        ),
      });
      paths.push({
        group,
        edge,
        proposal: true,
        node: plot.append("path").attr("class", "sequence-proposal").style(
          "stroke",
          display.all ? group.color : "var(--cyan)",
        ),
      });
    }
  }
  // Zoom reveals additional markers in the visible range, with a bounded DOM.
  const renderMarkers = (scale) => {
    const domain = scale.domain();
    const visible = rows.filter((row) =>
      row.current && row.record && row.position >= domain[0] &&
      row.position <= domain[1]
    );
    const step = Math.max(1, Math.ceil(visible.length / 400));
    const markers = visible.filter((row, i) =>
      i % step === 0 || row.anchor || i === visible.length - 1
    );
    const nodes = plot.selectAll(".sequence-sample").data(
      markers,
      (row) => row.sampleIndex,
    ).join((enter) => {
      const g = enter.append("g").attr("tabindex", 0).attr("role", "button");
      g.append("title");
      g.append("line");
      g.append("circle").attr("data-edge", "start");
      g.append("circle").attr("data-edge", "end");
      g.on("click", (_, row) => select(row.record)).on(
        "keydown",
        (event, row) => {
          if (event.key === "Enter" || event.key === " ") {
            event.preventDefault();
            event.stopPropagation();
            select(row.record);
          }
        },
      );
      return g;
    });
    nodes.attr(
      "class",
      (row) => `sequence-sample${row.anchor ? " is-anchor" : ""}`,
    )
      .attr("data-sample", (row) => row.sampleIndex).attr(
        "aria-pressed",
        (row) => String(row.anchor),
      )
      .attr(
        "aria-label",
        (row) =>
          `${row.fileName}, batch ${row.batch}, ${
            row.current.start.toFixed(3)
          }–${row.current.end.toFixed(3)} minutes; toggle reference`,
      );
    nodes.select("title").text((row) =>
      `${row.fileName}\nBatch ${row.batch}\n${row.current.start.toFixed(3)}–${
        row.current.end.toFixed(3)
      } min${row.time == null ? "" : `\n${new Date(row.time).toISOString()}`}`
    );
    nodes.select("line").attr("x1", (row) => scale(row.position)).attr(
      "x2",
      (row) => scale(row.position),
    )
      .attr("y1", (row) => y(row.current.start)).attr(
        "y2",
        (row) => y(row.current.end),
      );
    for (const edge of ["start", "end"]) {
      nodes.select(`[data-edge="${edge}"]`).attr(
        "cx",
        (row) => scale(row.position),
      )
        .attr("cy", (row) => y(row.current[edge])).attr(
          "r",
          (row) => row.anchor ? 4 : 2.5,
        );
    }
  };
  const view = { key, svg, left, right, zoom: null, visibleDomain: extent };
  views.set(container, view);
  const redraw = (transform) => {
    const scale = transform.rescaleX(x);
    view.visibleDomain = scale.domain();
    svg.attr("data-zoom", transform.k.toFixed(3));
    const [begin, end] = scale.domain();
    const span = end - begin;
    const unit = span >= 3600000 ? 3600000 : span >= 60000 ? 60000 : 1000;
    const unitName = unit === 3600000 ? "h" : unit === 60000 ? "min" : "s";
    const format = d3.tickFormat(
      (begin - extent[0]) / unit,
      (end - extent[0]) / unit,
      5,
      "~f",
    );
    const ticks = d3.axisBottom(scale).ticks(5);
    if (display.timed) {
      ticks.tickValues(
        d3.ticks((begin - extent[0]) / unit, (end - extent[0]) / unit, 5).map(
          (value) => extent[0] + value * unit,
        ),
      );
      ticks.tickFormat((value) =>
        `${format((value - extent[0]) / unit)} ${unitName}`
      );
    } else {ticks.tickValues(d3.ticks(begin, end, 5).filter(Number.isInteger))
        .tickFormat((value) => String(value + 1));}
    axis.call(ticks);
    for (const { group, edge, proposal, node } of paths) {
      const field = edge === "start" ? "rtStart" : "rtEnd";
      node.datum(group.rows).attr(
        "d",
        d3.line().defined((row) =>
          Number.isFinite(proposal ? row.next?.[field] : row.current?.[edge])
        )
          .x((row) => scale(row.position)).y((row) =>
            y(proposal ? row.next[field] : row.current[edge])
          ),
      );
    }
    rules.attr("x1", (value) => scale(value)).attr(
      "x2",
      (value) => scale(value),
    );
    renderMarkers(scale);
  };
  const zoom = d3.zoom().scaleExtent([1, 1000]).extent([[left, top], [
    right,
    bottom,
  ]])
    .translateExtent([[left, top], [right, bottom]]).clickDistance(4)
    .on("zoom", (event) => redraw(event.transform));
  view.zoom = zoom;
  svg.call(zoom);
  svg.on("wheel.sequence-pointer pointermove.sequence-pointer", (event) => {
    const [px] = d3.pointer(event, svg.node());
    view.pointer = [Math.max(left, Math.min(right, px)), (top + bottom) / 2];
  });
  const k = visibleDomain
    ? (extent[1] - extent[0]) / (visibleDomain[1] - visibleDomain[0])
    : 1;
  const transform = visibleDomain
    ? d3.zoomIdentity.translate(left - k * x(visibleDomain[0]), 0).scale(k)
    : d3.zoomIdentity;
  svg.call(zoom.transform, transform);
  container.onkeydown = (event) => {
    const factor = ["+", "="].includes(event.key)
      ? 1.5
      : event.key === "-"
      ? 1 / 1.5
      : null;
    if (factor != null) {
      event.preventDefault();
      event.stopPropagation();
      zoomSequence(container, factor, view.pointer);
    } else if (event.key === "Home" || event.key === "0") {
      event.preventDefault();
      event.stopPropagation();
      resetSequenceZoom(container);
    }
  };
  container.append(svg.node());
}
