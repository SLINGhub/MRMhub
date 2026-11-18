import { savedIntegrationRegions } from "../ui/visualizer/integration-regions.js";

function equal(actual, expected) {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw Error(`${JSON.stringify(actual)} != ${JSON.stringify(expected)}`);
  }
}

Deno.test("saved bounds without baseline data get a preview fill without changing the input", () => {
  for (const bl of [undefined, [], [null, null]]) {
    const plot = { pos_l: [2, 5], bl }, before = JSON.stringify(plot);
    equal(savedIntegrationRegions(plot, 6), [{
      isomerIndex: 0, begin: 1, end: 5,
      baselineStart: null, baselineEnd: null, previewArea: true,
    }]);
    equal(JSON.stringify(plot), before);
  }
});

Deno.test("saved zero and sloped baselines are preserved exactly rather than previewed", () => {
  const regions = savedIntegrationRegions({ pos_l: [1, 3, 4, 6], bl: [0, 0, 7, 11] }, 6);
  equal(regions.map(r => [r.baselineStart, r.baselineEnd, r.previewArea]), [[0, 0, false], [7, 11, false]]);
});

Deno.test("each isomer's baseline is checked independently of the first peak", () => {
  const regions = savedIntegrationRegions({ pos_l: [1, 3, 4, 6], bl: [null, null, 7, 11] }, 6);
  equal(regions.map(r => [r.baselineStart, r.baselineEnd, r.previewArea]), [[null, null, true], [7, 11, false]]);
});

Deno.test("partial and invalid baselines use preview fills, not made-up zero baselines", () => {
  for (const bl of [[3], [3, null], [NaN, 3], [3, Infinity]]) {
    equal(savedIntegrationRegions({ pos_l: [1, 5], bl }, 6)[0].previewArea, true);
  }
});

Deno.test("saved regions are clipped to trace bounds and invalid ranges retain isomer numbering", () => {
  const regions = savedIntegrationRegions({ pos_l: [10, 15, 0, 20, 3] }, 6);
  equal(regions.map(r => [r.isomerIndex, r.begin, r.end]), [[1, 0, 6]]);
  equal(savedIntegrationRegions({ pos_l: [1, 5] }, 0), []);
  equal(savedIntegrationRegions({}, 6), []);
});
