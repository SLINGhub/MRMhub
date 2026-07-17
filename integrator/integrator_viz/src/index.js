//import * as d3 from "https://cdn.jsdelivr.net/npm/d3@7/+esm";
const { invoke, Channel } = window.__TAURI__.core;

const utf8d = new TextDecoder();
const load_all = async function () {
  const mzml_Object = await invoke("get_ref");

  const trans_Object = d3
    .csvParseRows(utf8d.decode(await invoke("trans_csv")))
    .slice(1);
  trans_Object.forEach((x) => (x[0] = x[0].slice(1)));
  trans_Object.forEach((x) => (x[1] = x[1].slice(0, 99)));
  const trans_sel = document.getElementById("trans_sel");
  trans_sel.innerHTML = "";
  trans_sel.options[0] = new Option("--Select--");
  mzml_Object.forEach((x, i) => {
    trans_sel.options[trans_sel.options.length] = new Option(
      x.slice(3) + ", REF",
      "r" + i,
    );
  });
  trans_Object.forEach((x, i) => {
    trans_sel.options[trans_sel.options.length] = new Option(
      x[1] + ", " + x[0],
      "t" + i,
    );
  });

  const mzml_l = d3.tsvParseRows(utf8d.decode(await invoke("mzml_tsv")));
  mzml_l.forEach((x) => (x[0] = x[0].slice(0, -5)));

  //await call_plot(trans_Object, "r0", mzml_l, mzml_Object);

  //const sample_loc = document.getElementById("sample_loc");
  //sample_loc.innerHTML = "";
  //sample_loc.options[0] = new Option("top", "");
  //mzml_l.forEach((x, i) => {
  //  sample_loc.options[sample_loc.options.length] = new Option(x[0], i);
  //});

  //sample_loc.onchange = function () {
  //  scrollAdj(this.value);
  //};

  trans_sel.onchange = async function () {
    const row2 = document.getElementById("row2");
    row2.innerHTML = "";
    if (this.value.startsWith("t")) {
      row2.innerHTML = `
          <div>
            RT range:
            <input
              type="number"
              id="RT0"
              min="0"
              max="999"
              step="0.1"
              value="0"
            />
            to
            <input
              type="number"
              id="RT1"
              min="0"
              max="999"
              step="0.1"
              value="0"
            />
          </div>
          <div>
            Max. intensity:
            <input
              type="number"
              id="INT1"
              min="0"
              max="999999999"
              step="1"
              value="0"
            />
          </div> `;
    }
    await call_plot(trans_Object, this.value, mzml_l, mzml_Object);
    //scrollAdj(sample_loc.value);
  };
  const refreshb = document.getElementById("refreshb");
  refreshb.onclick = async function () {
    await call_plot(trans_Object, trans_sel.value, mzml_l, mzml_Object);
    //scrollAdj(sample_loc.value);
  };
};
async function call_plot(trans_Object, val, mzml_l, mzml_Object) {
  width = document.getElementById("c_width").valueAsNumber;
  height = document.getElementById("c_height").valueAsNumber;
  if (val.startsWith("t")) {
    rt0 = document.getElementById("RT0").valueAsNumber;
    rt1 = document.getElementById("RT1").valueAsNumber;
    int1 = document.getElementById("INT1").valueAsNumber;
    if (rt1 <= rt0) {
      rt0 = 0;
      rt1 = 0;
    }
    await gen(trans_Object[val.slice(1)], mzml_l);
  } else if (val.startsWith("r")) {
    rt0 = 0;
    rt1 = 0;
    int1 = 0;
    await gen_ref(mzml_Object[val.slice(1)], trans_Object);
  }
}
window.onload = async function () {
  load_all();
};
//function scrollAdj(id) {
//  const target = document.getElementById(id);
//  if (target) {
//    target.scrollIntoView({ behavior: "smooth", block: "center" });
//    target.animate(
//      {
//        backgroundColor: ["red", "red", "white"],
//        //borderWidth: ["1em 2px", "1em 2px", "1em 2px", "2px"],
//        //border: ["solid", "solid"],
//      },
//      {
//        //easing: "ease",
//        //iterations: 3,
//        duration: 2000,
//      },
//    );
//  } else {
//    window.scrollTo({ top: 0, behavior: "smooth" });
//  }
//}
//const reload = document.getElementById("reload");
//reload.onclick = function () {
//  load_all();
//  //window.location.reload();
//};

//refreshb.addEventListener("click", (e) => {
//  e.preventDefault();
//  gen(document.getElementById("trans_sel").value);
//});

async function gen_ref(mzml_id, trans_Object) {
  const sel_analyte = document.getElementById("sel_analyte");
  sel_analyte.innerHTML = mzml_id.slice(3);
  document.getElementById("qc").innerHTML = "";
  const container = document.getElementById("container");
  container.innerHTML = "";
  const onEvent = new Channel();
  let ii = 0;
  onEvent.onmessage = (message) => {
    gen_svg(message, [trans_Object[ii][1], "", "", "", ""], ii, container);
    ii++;
  };
  await invoke("get_r", { mzml: mzml_id, onEvent });
}
async function gen(trans, mzml_l) {
  const sel_analyte = document.getElementById("sel_analyte");
  //sel_analyte.innerHTML = `${trans[1]} | ${trans[2]}m/z | ${trans[3]}m/z`;
  sel_analyte.innerHTML = `${trans[1]} | ${trans[2]}m/z`;
  if (trans[3].length > 1) {
    sel_analyte.innerHTML += ` | ${trans[3]}m/z`;
  }
  document.getElementById("qc").innerHTML = "";
  const container = document.getElementById("container");
  container.innerHTML = "";
  await gen_sh(trans, mzml_l);
  await gen_qc(trans[0], mzml_l);
  const onEvent = new Channel();
  let ii = 0;
  onEvent.onmessage = (message) => {
    gen_svg(message, mzml_l[ii], ii, container);
    ii++;
  };
  await invoke("get_t", { cqq: trans[0], onEvent });
}

async function gen_sh(trans, mzml_l) {
  const qcs = await invoke("get_sh", { cqq: trans[0] });
  gen_qc_i("RT shift", trans[1], qcs, mzml_l);
}
async function gen_qc(cqq, mzml_l) {
  const qcs = await invoke("read_long", { cqq });
  for (const qc of qcs) {
    for (const key of Object.keys(qc[1][0])) {
      gen_qc_i(
        key,
        qc[0],
        qc[1].map((d) => d[key]),
        mzml_l,
      );
    }
  }
}
function gen_qc_i(key, iso_name, qc_dat, mzml_l) {
  const height = 200;
  const marginTop = 23;
  const x = d3
    .scaleLinear()
    .domain([1, qc_dat.length])
    .range([marginLeft, width - marginRight]);
  //const yext = d3.extent(qc_dat, (d) => d[key]);
  const yext = d3.extent(qc_dat);
  const y = key.startsWith("area")
    ? d3.scaleSymlog().domain([yext[0], yext[1]])
    : d3.scaleLinear().domain([yext[0] - 0.05, yext[1] + 0.05]);
  y.range([height - marginBottom, marginTop]);
  //const y = d3
  //  .scaleLinear()
  //  .domain([yext[0] - 0.05, yext[1] + 0.05])
  //  .range([height - marginBottom, marginTop]);
  const svg = d3
    .create("svg")
    .attr("width", width)
    .attr("height", height)
    .style("background", "white")
    .style("cursor", "crosshair")
    .style("border", "2px solid")
    .style("border-radius", "8px");
  //macOS
  svg
    .append("rect")
    .attr("width", width)
    .attr("height", height)
    .style("fill", "none");
  svg
    .append("text")
    .attr("x", "50%")
    .attr("dominant-baseline", "text-before-edge")
    .attr("text-anchor", "middle")
    .text(key + ", " + iso_name);
  svg
    .append("g")
    .attr("transform", `translate(${marginLeft})`)
    .call(
      d3
        .axisLeft(y)
        .ticks(3, key == "area" ? "s" : "f")
        .tickSize(0),
    )
    .call((g) => g.select(".domain").remove())
    .call((g) => g.attr("font-size", 12));
  const xAxis = (g, x) => {
    g.call(d3.axisBottom(x).tickSize(0).ticks(4));
    g.select(".domain").attr("opacity", 0.5);
    g.attr("font-size", 12);
  };
  const gx = svg
    .append("g")
    .attr("transform", `translate(0,${height - marginBottom})`);
  const gLine = svg
    .append("g")
    .attr("stroke", "black")
    .attr("stroke-opacity", 0.5)
    .selectAll("line")
    .data(
      qc_dat
        .slice(0, -1)
        .map((d, i) => i)
        .filter((d) => mzml_l[d][3] != mzml_l[d + 1][3])
        .map((d) => d + 1.5),
    )
    .join("line")
    .attr("y1", y.range()[0])
    .attr("y2", y.range()[1]);
  const gp = svg
    .append("g")
    .attr("class", "gp")
    //.attr("stroke", "black")
    .selectAll("circle")
    .data(qc_dat)
    .join("circle")
    //.attr("cy", (d) => y(d[key]))
    .attr("cy", (d) => y(d))
    //.attr("fill", "none")
    .attr("r", 2);
  const line0 = d3.line().y((d) => y(d));
  const gtrace = svg
    .append("path")
    .attr("opacity", 0.5)
    .attr("fill", "none")
    .attr("stroke", "black");
  const mark = svg
    .append("circle")
    .attr("class", "samplec")
    .attr("fill", "none")
    .attr("stroke", "red")
    .attr("stroke-width", 5)
    .attr("r", 7);
  let delaunay;
  const zoom = d3
    .zoom()
    .translateExtent([
      [0, -Infinity],
      [width, Infinity],
    ])
    .scaleExtent([1, 9999])
    .on("zoom", (e) => {
      const xz = e.transform.rescaleX(x);
      gx.call(xAxis, xz);
      gLine.attr("x1", (d) => xz(d)).attr("x2", (d) => xz(d));
      gp.attr("cx", (d, i) => xz(i + 1));
      delaunay = d3.Delaunay.from(
        qc_dat,
        (d, i) => xz(i + 1),
        //(d) => y(d[key]),
        (d) => y(d),
      );
      line0.x((d, i) => xz(i + 1));
      gtrace.attr("d", line0(qc_dat));
      mark.attr("display", "none");
    });
  svg.call(zoom).call(zoom.transform, d3.zoomIdentity);
  const tt = svg.append("g").style("display", "none");
  tt.append("rect").attr("width", width).attr("height", 20);
  tt.append("text")
    .attr("fill", "white")
    .attr("x", "50%")
    .attr("text-anchor", "middle")
    .attr("dominant-baseline", "text-before-edge");
  svg
    .on("mousemove", (event) => {
      const ii = delaunay.find(...d3.pointer(event));
      //const sel = d3.selectAll(".gp");
      //sel.selectAll("circle").attr("fill", "none").attr("r", 3);
      //sel
      //  .select(`:nth-child(${ii + 1})`)
      //  .attr("fill", "red")
      //  .attr("r", 9);
      const cc = d3
        .selectAll(".gp")
        .select(`:nth-child(${ii + 1})`)
        .nodes();
      d3.selectAll(".samplec").each(function (d, i) {
        const node = d3.select(cc[i]);
        d3.select(this)
          .attr("display", null)
          .attr("cx", node.attr("cx"))
          .attr("cy", node.attr("cy"));
      });
      tt.style("display", null);
      tt.select("text").text(mzml_l[ii][0]);
    })
    .on("mouseout", () => {
      tt.style("display", "none");
      d3.selectAll(".samplec").attr("display", "none");
      //d3.selectAll(".gp circle").attr("fill", "none").attr("r", 3);
    });

  //gp.on("mousemove", (event, [, ii]) => {
  //  tt.attr("opacity", 1);
  //  //tt.select("text").text(mzml_l[ii][0] + ", " + a[key].toString());
  //  tt.select("text").text(mzml_l[ii][0]);
  //  //gp.attr("fill-opacity", (d, i) => (ii == i ? 1 : 0)).attr("r", (d, i) =>
  //  //  ii == i ? 9 : 4,
  //  //);
  //  d3.selectAll(".gpoint" + ii)
  //    .attr("fill", "red")
  //    .attr("r", 9);
  //}).on("mouseout", (event, [, ii]) => {
  //  //gp.attr("fill-opacity", 0).attr("r", 4);
  //  d3.selectAll(".gpoint" + ii)
  //    .attr("fill", "none")
  //    .attr("r", 3);
  //  tt.attr("opacity", 0);
  //});

  document.getElementById("qc").append(svg.node());
}

let width, height;
let rt0, rt1, int1;
const marginTop = 16;
const marginRight = 10;
const marginBottom = 14;
const marginLeft = 33;
function gen_svg({ sh, pos_l, bl, te }, id, ii, container) {
  const stype = id[1];

  const svg = d3
    .create("svg")
    .attr("id", ii)
    .attr("width", width)
    .attr("height", height)
    .style("background", "white")
    .style("border", "2px solid")
    .style("border-radius", "8px");

  const bisect = d3.bisector((d) => d.x).center;
  const rti0 = rt0 == 0 ? 0 : bisect(te, rt0);
  const rti1 = rt1 == 0 ? te.length - 1 : bisect(te, rt1);
  const x = d3
    .scaleLinear()
    //.domain([te[0].x, te[te.length - 1].x])
    .domain([te[rti0].x, te[rti1].x])
    .range([marginLeft, width - marginRight]);
  let int_region = te.slice(pos_l[0], pos_l[pos_l.length - 1]);
  if (int_region.length == 0) {
    int_region = te;
  }
  const max_i =
    int1 == 0
      ? d3.max(int_region, (d) => d.y)
      : Math.min(
          int1,
          d3.max(te.slice(rti0, rti1), (d) => d.y),
        );
  const y = d3
    .scaleLinear()
    .domain([0, 1.1 * max_i])
    .range([height - marginBottom, marginTop]);

  svg
    .append("g")
    .attr("transform", `translate(0,${height - marginBottom})`)
    .call(d3.axisBottom(x).tickSize(0))
    .call((g) => g.select(".domain").attr("opacity", 0.5))
    .call((g) => g.selectAll(".tick:nth-of-type(odd)").remove())
    .call((g) => g.attr("font-size", 12));
  svg
    .append("g")
    .attr("transform", `translate(${marginLeft})`)
    .call(d3.axisLeft(y).ticks(2, "s").tickSize(0))
    .call((g) => g.select(".domain").remove())
    .call((g) => g.attr("font-size", 12));

  const line0 = d3
    .line()
    .x((d) => x(d.x))
    .y((d) => y(d.y));
  for (let i = 0; i < pos_l.length; i += 2) {
    const beg = pos_l[i] - 1;
    const end = pos_l[i + 1];
    const j = (i / 2) % 10;
    if (bl[0] !== null) {
      svg
        .append("path")
        .attr("fill", d3.schemeCategory10[j])
        .attr("opacity", 0.6)
        .attr(
          "d",
          line0([
            ...te.slice(beg, end),
            { x: te[end - 1].x, y: bl[i + 1] },
            { x: te[beg].x, y: bl[i] },
          ]) + "Z",
        );
    }
    svg
      .append("rect")
      .attr("fill", d3.schemeCategory10[j])
      .attr("opacity", 0.3)
      .attr("x", x(te[beg].x))
      .attr("y", y.range()[1])
      .attr("width", x(te[end - 1].x) - x(te[beg].x))
      .attr("height", y.range()[0] - y.range()[1]);
  }
  if (id[4] == "1") {
    svg
      .append("rect")
      .attr("width", "100%")
      .attr("height", marginTop)
      .attr("fill", "#FF000080");
  }
  svg
    .append("text")
    .attr("x", "50%")
    .attr("dominant-baseline", "text-before-edge")
    .attr("text-anchor", "middle")
    .text(id[0]);
  if (id[4]) {
    svg
      .append("text")
      .attr("x", "99%")
      .attr("dominant-baseline", "text-before-edge")
      .attr("text-anchor", "end")
      .text(id[4] == "1" ? "REF" : d3.format(".2f")(sh));
  }
  if (stype.includes("BLK")) {
    svg
      .append("text")
      .attr("y", "50%")
      .attr("x", "50%")
      .attr("text-anchor", "middle")
      .attr("dominant-baseline", "central")
      .attr("font-size", height)
      .attr("opacity", 0.2)
      .text(stype);
  }

  svg
    .append("g")
    .selectAll("circle")
    .data(te.filter((d) => d.y <= y.domain()[1]))
    .join("circle")
    .attr("cx", (d) => x(d.x))
    .attr("cy", (d) => y(d.y))
    .attr("r", 1.5);

  const tt = svg.append("g").style("display", "none");
  tt.append("circle").attr("r", 3);
  tt.append("rect")
    .attr("width", 55)
    .attr("height", marginTop + 4)
    .attr("x", -tt.select("rect").attr("width") / 2)
    .attr("rx", 4);
  tt.append("text")
    .attr("text-anchor", "middle")
    .attr("dominant-baseline", "text-before-edge")
    .attr("fill", "white");
  svg
    .append("line")
    .attr("class", "tl")
    .attr("y1", "100%")
    .attr("y2", y.range()[1])
    .style("display", "none")
    .attr("stroke", "black")
    .attr("opacity", 0.5)
    .attr("stroke-width", 2);

  svg
    .on("pointerenter pointermove", (event) => {
      const i = bisect(te, x.invert(d3.pointer(event)[0]));
      tt.select("text").text(d3.format(".3f")(te[i].x));
      const cx = x(te[i].x);
      tt.attr("transform", `translate(${x(te[i].x)})`).style("display", null);
      tt.select("circle").attr("cy", y(te[i].y));
      const adj_chrom = id[4] ? 50 : 0.1;
      d3.selectAll(".tl")
        .filter((d, i) => Math.abs(i - ii) < adj_chrom)
        .style("display", null)
        .attr("x1", cx)
        .attr("x2", cx);
    })
    .on("pointerleave", () => {
      tt.style("display", "none");
      d3.selectAll(".tl").style("display", "none");
    });
  //svg
  //  .append("g")
  //  .attr("fill", "none")
  //  .attr("pointer-events", "all")
  //  .selectAll("rect")
  //  .data(d3.pairs(te))
  //  .join("rect")
  //  .attr("x", ([a]) => x(a.x))
  //  .attr("y", y.range()[1])
  //  .attr("height", height)
  //  .attr("width", ([a, b]) => x(b.x) - x(a.x))
  //  .on("mouseover", (event, [a]) => {
  //    tt.select("text").text(d3.format(".3f")(a.x));
  //    //event.target.setAttribute("style", "border-left: solid;");
  //    //const cx = event.target.getAttribute("x");
  //    const cx = x(a.x);
  //    tt.attr("transform", `translate(${cx})`).attr("opacity", 1);
  //    tt.select("circle").attr("cy", y(a.y));
  //    d3.selectAll(".tl")
  //      .filter((d, i) => Math.abs(i - ii) < 50)
  //      .attr("opacity", 0.5)
  //      .attr("x1", cx)
  //      .attr("x2", cx);
  //  })
  //  .on("mouseout", () => {
  //    tt.attr("opacity", 0);
  //    d3.selectAll(".tl").attr("opacity", 0);
  //  });
  //const container = document.getElementById("container");
  container.append(svg.node());
}

//(async () => {
//    const blob = new Blob([new Uint8Array([3]), new Float32Array([12, 13, 14])]);
//    const ee = await blob.stream();
//    const reader = ee.getReader({mode: 'byob'});
//    let buffer = new ArrayBuffer(1);
//    const {value: [len], done} = await reader.read(new Uint8Array(buffer, 0, 1));
//    console.log(len, done);
//    let buffer2 = new ArrayBuffer(4 * len);
//    console.log(await reader.read(new Float32Array(buffer2, 0, len)));
//
//    console.log('==========')
//
//    {
//        const blob = await new Blob([new Uint8Array([3]), new Float32Array([12, 13, 14])]).arrayBuffer();
//        const view = new DataView(blob);
//        const len = view.getUint8(0);
//        for (let i = 0; i < len; i++)
//            console.log(view.getFloat32(1 + i * 4, true));
//    }
//})();
