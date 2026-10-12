import {
  acquisitionBatches,
  acquisitionTime,
  sequenceDisplay,
  sequencePlan,
} from "../ui/visualizer/sequence.js";

function equal(a, b) {
  if (JSON.stringify(a) !== JSON.stringify(b)) {
    throw Error(`${JSON.stringify(a)} != ${JSON.stringify(b)}`);
  }
}
function close(a, b) {
  if (Math.abs(a - b) > 1e-8) throw Error(`${a} != ${b}`);
}

Deno.test("All overview orders every batch chronologically while keeping curves and source positions separate", () => {
  const batches = acquisitionBatches([
    ["last", "", "2026-10-11T02:00:00Z", "B"],
    ["first", "", "2026-10-11T00:00:00Z", "A"],
    ["middle", "", "2026-10-11T01:00:00Z", "A"],
  ]);
  const before = JSON.stringify(batches);
  const display = sequenceDisplay(batches);
  equal(display.rows.map((row) => row.sampleIndex), [1, 2, 0]);
  equal(display.groups.map((group) => group.rows.map((row) => row.batch)), [[
    "B",
  ], ["A", "A"]]);
  equal(display.timed, true);
  equal(JSON.stringify(batches), before);
});

Deno.test("All overview uses one sample-order axis if any batch lacks timestamps, without changing interpolation", () => {
  const samples = [["a", "", "2026-10-11T02:00:00Z", "A"], ["b", "", "", "B"], [
    "c",
    "",
    "2026-10-11T00:00:00Z",
    "A",
  ]];
  const batches = acquisitionBatches(samples);
  const display = sequenceDisplay(batches);
  equal(display.timed, false);
  equal(display.rows.map((row) => [row.sampleIndex, row.position]), [[0, 0], [
    1,
    1,
  ], [2, 2]]);
  equal(
    batches.find((batch) => batch.name === "A").rows.map((row) =>
      row.sampleIndex
    ),
    [2, 0],
  );
});

Deno.test("All selection cannot collide with a batch actually named All; filtering retains its acquisition coordinates", () => {
  const batches = acquisitionBatches([["a", "", "", "All"], [
    "b",
    "",
    "",
    "B",
  ]]);
  equal(sequenceDisplay(batches).rows.length, 2);
  const display = sequenceDisplay(batches, "All");
  equal(display.all, false);
  equal(display.rows.map((row) => [row.fileName, row.position]), [["a", 0]]);
  const simultaneous = acquisitionBatches([[
    "a",
    "",
    "2026-10-11T00:00:00Z",
    "A",
  ], ["b", "", "2026-10-11T00:00:00Z", "B"]]);
  equal(sequenceDisplay(simultaneous).rows.map((row) => row.position), [0, 1]);
  equal(sequenceDisplay(simultaneous).timed, false);
});
const sample = (
  name,
  minute,
  batch = "1",
) => [
  name,
  "QC",
  minute == null ? "" : `2026-10-11T00:${String(minute).padStart(2, "0")}:00Z`,
  batch,
];
const reference = (sampleIndex, rtStart, rtEnd, isomerIndex = 0) => ({
  sampleIndex,
  cqq: "0001",
  fileName: `s${sampleIndex}`,
  rtStart,
  rtEnd,
  isomerIndex,
});
const records = (samples) =>
  samples.map((row, sampleIndex) => ({
    editContext: { cqq: "0001", sampleIndex, fileName: row[0] },
    points: new Float32Array([0, 0, 10, 0]),
  }));

Deno.test("mzML timestamps use explicit offsets or stable instrument clock, and reject missing/invalid dates", () => {
  equal(
    acquisitionTime("2026-10-11T00:00:00"),
    acquisitionTime("2026-10-11T00:00:00Z"),
  );
  equal(
    acquisitionTime("2026-10-11T01:00:00+01:00"),
    acquisitionTime("2026-10-11T00:00:00Z"),
  );
  for (
    const value of ["", "1", null, "2026-02-30T00:00:00", "2026-10-11T99:00:00"]
  ) equal(acquisitionTime(value), null);
});

Deno.test("sequence uses elapsed acquisition time, not table order or evenly spaced sample ranks", () => {
  const samples = [sample("s0", 20), sample("s1", 0), sample("s2", 5)];
  const refs = [reference(1, 1, 2), reference(0, 3, 4)];
  const result = sequencePlan(samples, refs, records(samples));
  equal(result.edits.map((edit) => edit.sampleIndex), [1, 2, 0]);
  close(result.edits[1].rtStart, 1.5);
  close(result.edits[1].rtEnd, 2.5);
  equal(
    result.edits.filter((e) => e.sampleIndex !== 2).map(
      (e) => [e.rtStart, e.rtEnd],
    ),
    [[1, 2], [3, 4]],
  );
});

Deno.test("piecewise interpolation preserves anchor widths and holds nearest boundaries outside references", () => {
  const samples = [0, 10, 20, 30, 40, 50].map((min, i) => sample(`s${i}`, min));
  const result = sequencePlan(samples, [
    reference(1, 1, 2),
    reference(3, 3, 5),
    reference(4, 2, 3),
  ], records(samples));
  equal(result.edits.map((e) => [e.rtStart, e.rtEnd]), [
    [1, 2],
    [1, 2],
    [2, 3.5],
    [3, 5],
    [2, 3],
    [2, 3],
  ]);
});

Deno.test("batches and multi-isomer targets never borrow another batch or peak's references", () => {
  const samples = [
    sample("s0", 0, "A"),
    sample("s1", 5, "A"),
    sample("s2", 10, "B"),
  ];
  const result = sequencePlan(samples, [
    reference(0, 1, 2),
    reference(0, 5, 6, 1),
    reference(2, 3, 4),
  ], records(samples));
  equal(result.edits.map((e) => [e.sampleIndex, e.isomerIndex, e.rtStart]), [
    [0, 0, 1],
    [1, 0, 1],
    [0, 1, 5],
    [1, 1, 5],
    [2, 0, 3],
  ]);
  equal(result.skipped, 1);
});

Deno.test("missing or duplicate timestamps fall back consistently within their batch only", () => {
  for (const times of [[0, null, 20], [0, 0, 20]]) {
    const samples = times.map((min, i) => sample(`s${i}`, min));
    equal(acquisitionBatches(samples)[0].timed, false);
    const result = sequencePlan(samples, [
      reference(0, 1, 2),
      reference(2, 3, 4),
    ], records(samples));
    equal(result.edits[1].rtStart, 2);
  }
});

Deno.test("proposals skip missing/out-of-range traces without clipping or changing source data", () => {
  const samples = [sample("s0", 0), sample("s1", 10), sample("s2", 20)];
  const input = records(samples);
  input[1].points = new Float32Array([5, 0, 10, 0]);
  input[2].points = new Float32Array();
  const refs = [reference(0, 1, 2)];
  const before = JSON.stringify([samples, input, refs]);
  const result = sequencePlan(samples, refs, input);
  equal(result.edits.length, 1);
  equal(result.skipped, 2);
  equal(JSON.stringify([samples, input, refs]), before);
});

Deno.test("no references is a no-op; invalid and duplicate reference windows cannot create a plan", () => {
  const samples = [sample("s0", 0)];
  equal(sequencePlan(samples, [], records(samples)).edits, []);
  for (
    const refs of [[reference(0, NaN, 2)], [reference(0, -1, 2)], [
      reference(0, 2, 1),
    ], [reference(0, 1, 2), reference(0, 3, 4)]]
  ) {
    let threw = false;
    try {
      sequencePlan(samples, refs, records(samples));
    } catch {
      threw = true;
    }
    equal(threw, true);
  }
});

Deno.test("large sequence proposals stay bounded to small window records", () => {
  const samples = Array.from(
    { length: 10000 },
    (_, i) => [`s${i}`, "", "", "batch"],
  );
  const result = sequencePlan(samples, [
    reference(0, 1, 2),
    reference(9999, 2, 3),
  ], records(samples));
  equal(result.edits.length, 10000);
  close(result.edits[5000].rtStart, 1 + 5000 / 9999);
});
