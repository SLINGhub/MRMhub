// Returns every usable integration window for one reference record. Existing
// detected bounds are the default; dragged edits replace only their matching
// isomer windows.
export function referenceBounds(record) {
  const bounds = new Map();
  const positions = record.plot?.pos_l ?? [];
  const pointCount = (record.points?.length ?? 0) / 2;
  for (let offset = 0; offset + 1 < positions.length; offset += 2) {
    const begin = Math.max(Number(positions[offset]) - 1, 0);
    const end = Math.min(Number(positions[offset + 1]), pointCount);
    if (end <= begin) continue;
    const start = record.points[begin * 2];
    const finish = record.points[(end - 1) * 2];
    if (Number.isFinite(start) && Number.isFinite(finish) && finish > start) {
      bounds.set(offset / 2, { start, end: finish });
    }
  }
  for (const [isomerIndex, edit] of record.editRts ?? []) {
    if (
      Number.isFinite(edit.start) &&
      Number.isFinite(edit.end) &&
      edit.end > edit.start
    ) {
      bounds.set(isomerIndex, edit);
    }
  }
  return bounds;
}
