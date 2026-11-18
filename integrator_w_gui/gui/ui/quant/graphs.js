// Metadata-only references: images stay in their original immutable checkpoints.
export function savedGraphs(history) {
  const seen = new Set(), graphs = [];
  for (const checkpoint of history) {
    for (const artifact of checkpoint.artifacts ?? []) {
      if (artifact.kind !== "image") continue;
      const key = JSON.stringify([checkpoint.id, artifact.name]);
      if (seen.has(key)) continue;
      seen.add(key);
      graphs.push({ key, id: checkpoint.id, name: artifact.name, created: checkpoint.created,
        operation: checkpoint.operation, mode: checkpoint.action === "legacy" ? "Legacy" : "Guided" });
    }
  }
  return graphs;
}

export function chooseGraph(graphs, currentId, previousKey) {
  return graphs.find(g => g.id === currentId)?.key
    ?? graphs.find(g => g.key === previousKey)?.key ?? graphs[0]?.key ?? "";
}
