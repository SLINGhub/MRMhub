// Missing baseline sidecars affect display only: retain the saved RT bounds and
// use the manual-edit preview fill, without inventing or saving an AUC baseline.
export function savedIntegrationRegions({ pos_l = [], bl = [] }, pointCount) {
  const regions = [];
  for (let offset = 0; offset < pos_l.length; offset += 2) {
    if (!Number.isFinite(pos_l[offset]) || !Number.isFinite(pos_l[offset + 1])) continue;
    const begin = Math.max(pos_l[offset] - 1, 0);
    const end = Math.min(pos_l[offset + 1], pointCount);
    if (end <= begin) continue;
    const hasBaseline = Number.isFinite(bl?.[offset]) && Number.isFinite(bl?.[offset + 1]);
    regions.push({
      isomerIndex: offset / 2,
      begin,
      end,
      baselineStart: hasBaseline ? bl[offset] : null,
      baselineEnd: hasBaseline ? bl[offset + 1] : null,
      previewArea: !hasBaseline,
    });
  }
  return regions;
}
