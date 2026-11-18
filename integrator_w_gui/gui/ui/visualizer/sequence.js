// Acquisition metadata comes from Step 1's mzML run/startTimeStamp, not the
// filesystem modification time. Parse unzoned instrument clocks consistently
// on Windows/macOS instead of letting Date.parse use the computer's timezone.
export function acquisitionTime(value) {
  const text = String(value ?? "").trim();
  if (
    !/^\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})?$/
      .test(text)
  ) return null;
  const normalized = text.replace(" ", "T");
  const day = new Date(`${normalized.slice(0, 10)}T00:00:00Z`);
  if (
    !Number.isFinite(day.getTime()) ||
    day.toISOString().slice(0, 10) !== normalized.slice(0, 10)
  ) return null;
  const ms = Date.parse(
    /(?:Z|[+-]\d{2}:\d{2})$/.test(normalized) ? normalized : `${normalized}Z`,
  );
  return Number.isFinite(ms) ? ms : null;
}

export function acquisitionBatches(samples) {
  const batches = new Map();
  samples.forEach((sample, sampleIndex) => {
    const batch = String(sample[3] || "Unspecified");
    if (!batches.has(batch)) batches.set(batch, []);
    batches.get(batch).push({
      sampleIndex,
      fileName: sample[0],
      time: acquisitionTime(sample[2]),
    });
  });
  return [...batches].map(([name, rows]) => {
    // A partially timestamped batch must use one consistent coordinate system.
    const timed = rows.every((row) => row.time != null) &&
      new Set(rows.map((row) => row.time)).size === rows.length;
    if (timed) {
      rows.sort((a, b) => a.time - b.time || a.sampleIndex - b.sampleIndex);
    }
    rows.forEach((row, rank) => {
      row.rank = rank;
      row.position = timed ? row.time : rank;
    });
    return { name, rows, timed };
  });
}

export const windowKey = (edit) =>
  `${edit.cqq}:${edit.sampleIndex}:${edit.isomerIndex}`;

// Display-only grouping: an empty selection means All and cannot collide with
// an actual batch called "All". Applying bounds still uses acquisitionBatches.
export function sequenceDisplay(batches, selected = "") {
  const chosen = selected === ""
    ? batches
    : batches.filter((batch) => batch.name === selected);
  const all = selected === "";
  let timed = chosen.length > 0 && chosen.every((batch) => batch.timed);
  const rows = chosen.flatMap((batch) =>
    batch.rows.map((row) => ({ ...row, batch: batch.name }))
  );
  if (all && new Set(rows.map((row) => row.time)).size !== rows.length) {
    timed = false;
  }
  if (all) {
    rows.sort((a, b) =>
      timed
        ? a.time - b.time || a.sampleIndex - b.sampleIndex
        : a.sampleIndex - b.sampleIndex
    );
    rows.forEach((row, rank) => {
      row.position = timed ? row.time : rank;
    });
  }
  const groups = new Map(
    chosen.map((batch) => [batch.name, { name: batch.name, rows: [] }]),
  );
  for (const row of rows) groups.get(row.batch).rows.push(row);
  return {
    name: all ? "All" : selected,
    all,
    timed,
    rows,
    groups: [...groups.values()],
  };
}

// Piecewise-linear start/end boundaries preserve every selected anchor exactly.
// Hold the nearest anchor outside its range; never extrapolate or cross batches.
// This is a bounds proposal, not peak detection or an AUC calculation.
export function sequencePlan(samples, references, records) {
  const batches = acquisitionBatches(samples);
  const recordIndex = new Map(records.map((record) => [
    `${record.editContext.cqq}:${record.editContext.sampleIndex}`,
    record,
  ]));
  const groups = new Map();
  for (const ref of references) {
    if (
      !Number.isFinite(ref.rtStart) || !Number.isFinite(ref.rtEnd) ||
      ref.rtStart < 0 || ref.rtEnd <= ref.rtStart
    ) {
      throw new Error("A reference has invalid RT bounds.");
    }
    const key = `${ref.cqq}:${ref.isomerIndex}`;
    if (!groups.has(key)) groups.set(key, []);
    groups.get(key).push(ref);
  }
  const edits = [], summaries = [];
  let skipped = 0;
  for (const batch of batches) {
    const positions = new Map(
      batch.rows.map((row) => [row.sampleIndex, row.position]),
    );
    for (const [key, refs] of groups) {
      const anchors = refs.filter((ref) => positions.has(ref.sampleIndex))
        .map((ref) => ({ ...ref, position: positions.get(ref.sampleIndex) }))
        .sort((a, b) => a.position - b.position);
      if (
        new Set(anchors.map((ref) => ref.sampleIndex)).size !== anchors.length
      ) throw new Error("A sample has duplicate reference windows.");
      summaries.push({
        batch: batch.name,
        key,
        timed: batch.timed,
        anchors: anchors.length,
        samples: batch.rows.length,
      });
      const template = refs[0];
      let rightIndex = 0;
      for (const row of batch.rows) {
        if (!anchors.length) {
          skipped++;
          continue;
        }
        while (
          rightIndex < anchors.length - 1 &&
          anchors[rightIndex].position < row.position
        ) rightIndex++;
        const right = anchors[rightIndex];
        const left = anchors[
          Math.max(0, rightIndex - (right.position > row.position ? 1 : 0))
        ];
        const fraction = right.position === left.position ? 0 : Math.max(
          0,
          Math.min(
            1,
            (row.position - left.position) / (right.position - left.position),
          ),
        );
        const rtStart = left.rtStart +
          fraction * (right.rtStart - left.rtStart);
        const rtEnd = left.rtEnd + fraction * (right.rtEnd - left.rtEnd);
        const record = recordIndex.get(`${template.cqq}:${row.sampleIndex}`);
        const points = record?.points;
        // Don't silently clamp a predicted peak outside the acquired trace.
        if (
          !points || points.length < 4 || rtEnd - rtStart < .001 ||
          rtStart < points[0] || rtEnd > points[points.length - 2]
        ) {
          skipped++;
          continue;
        }
        edits.push({
          cqq: template.cqq,
          sampleIndex: row.sampleIndex,
          fileName: row.fileName,
          isomerIndex: template.isomerIndex,
          rtStart,
          rtEnd,
        });
      }
    }
  }
  return { edits, summaries, skipped, windowCount: groups.size };
}
