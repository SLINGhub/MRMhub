import { referenceBounds } from "../ui/visualizer/reference-bounds.js";

function record(positions, edits = new Map()) {
  return {
    plot: { pos_l: positions },
    points: new Float32Array([
      0, 0,
      1, 10,
      2, 20,
      3, 15,
      4, 5,
      5, 0,
    ]),
    editRts: edits,
  };
}

Deno.test("selected reference uses its existing integration bounds", () => {
  const bounds = referenceBounds(record([2, 5]));
  if (JSON.stringify([...bounds]) !== JSON.stringify([[0, { start: 1, end: 4 }]])) {
    throw new Error(`unexpected bounds: ${JSON.stringify([...bounds])}`);
  }
});

Deno.test("dragged bounds override the selected reference's existing isomer", () => {
  const bounds = referenceBounds(
    record([2, 5], new Map([[0, { start: 1.5, end: 3.5 }]])),
  );
  if (
    JSON.stringify([...bounds]) !==
    JSON.stringify([[0, { start: 1.5, end: 3.5 }]])
  ) {
    throw new Error(`unexpected bounds: ${JSON.stringify([...bounds])}`);
  }
});

Deno.test("existing multi-isomer bounds are all retained", () => {
  const bounds = referenceBounds(record([1, 3, 4, 6]));
  const expected = [
    [0, { start: 0, end: 2 }],
    [1, { start: 3, end: 5 }],
  ];
  if (JSON.stringify([...bounds]) !== JSON.stringify(expected)) {
    throw new Error(`unexpected bounds: ${JSON.stringify([...bounds])}`);
  }
});

Deno.test("reference without a valid window remains unusable", () => {
  const bounds = referenceBounds(record([3, 3]));
  if (bounds.size !== 0) throw new Error("invalid bounds should be ignored");
});
