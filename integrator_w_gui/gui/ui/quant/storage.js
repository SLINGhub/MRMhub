// File sizes use decimal units, like Finder/Explorer, not rounded-up disk claims.
export function formatStorageBytes(bytes) {
  if (!Number.isFinite(bytes) || bytes < 0) return "Unavailable";
  if (bytes < 1000) return `${Math.floor(bytes)} B`;
  const units = ["KB", "MB", "GB", "TB", "PB"];
  let value = bytes / 1000, index = 0;
  while (value >= 1000 && index < units.length - 1) { value /= 1000; index++; }
  return `${value.toFixed(value < 10 ? 1 : 0)} ${units[index]}`;
}
