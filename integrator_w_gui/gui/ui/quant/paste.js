// Never guess at arbitrary invalid R or rewrite paths, strings or calculations.
// Recognize only distinctive tutorial output; preserve commands and line numbers.
// Scan incrementally: quotes/backticks in output must not affect later R strings.
function codeScanner() {
  let quote = null, rawEnd = null;
  return {
    get outside() { return !quote && !rawEnd; },
    scan(line) {
      for (let i = 0; i < line.length; i++) {
        if (rawEnd) {
          const end = line.indexOf(rawEnd, i);
          if (end < 0) break;
          i = end + rawEnd.length - 1; rawEnd = null;
        } else if (quote) {
          if (line[i] === "\\") i++;
          else if (line[i] === quote) quote = null;
        } else {
          if (line[i] === "#") break;
          const raw = line.slice(i).match(/^[rR](["'])(-*)([([{])/);
          if (raw) { rawEnd = ({ "(": ")", "[": "]", "{": "}" })[raw[3]] + raw[2] + raw[1]; i += raw[0].length - 1; }
          else if (['"', "'", "`"].includes(line[i])) quote = line[i];
        }
      }
    },
  };
}

// `!` is also R's NOT operator. Match specific prose, never blanket-strip it.
const warningOutput = /^\s*!\s+(?:\d+\s+features?(?:\(s\))?\s+(?:contain|showed|have)\b|Smoothing failed for \d+ feature|%CV not computed for\b|The QC parameter \S+ contains NAs\b|The following features were forced to be retained\b)/;
const messageOutput = /^\s*[✔✓ℹ✖⚠]\uFE0F?\s+[\p{L}\d]/u;
const metadataSummary = /^\s*Found (?:no|\d+) errors?, (?:no|\d+) warnings?, and (?:no|\d+) notes? in the metadata\.\s*$/;
const separator = /^\s*-{5,}\s*$/;
const metadataHeader = /^\s*Type\s+Table\s+Column\s+Issue\s+Count\s*$/;
const metadataRow = /^\s*\d+\s+(?:E|W\*?|N)\s+\S+\s+\S+\s+.+\s+\d+\s*$/;
const metadataLegend = /^\s*E = Error, W = Warning, W\* = Suppressed Warning, N = Note\s*$/;
export function inspectRPaste(text) {
  const lines = text.replace(/\r\n?/g, "\n").split("\n");
  let fenced = false, outputLines = 0;
  const nonempty = lines.map((line, i) => line.trim() ? i : -1).filter(i => i >= 0);
  const first = nonempty[0], last = nonempty.at(-1);
  if (first !== undefined && /^```(?:r|\{r[^}]*\})?\s*$/i.test(lines[first].trim()) && lines[last].trim() === "```" && lines.slice(first + 1, last).every(line => !/^```/.test(line.trim()))) {
    lines[first] = ""; lines[last] = ""; fenced = true;
  }
  const scanner = codeScanner();
  let folderDiagram = false, executable = false;
  const comment = i => { lines[i] = `# ${lines[i]}`; outputLines++; };
  for (let i = 0; i < lines.length; i++) {
    if (scanner.outside) {
      const line = lines[i];
      if (/^[\s│]*[├└]──/.test(line)) folderDiagram = true;
      if (messageOutput.test(line) || warningOutput.test(line)) { comment(i); continue; }
      if (metadataSummary.test(line)) {
        comment(i);
        // A metadata report has a distinctive header and row status codes.
        if (separator.test(lines[i + 1] || "") && metadataHeader.test(lines[i + 2] || "")) {
          comment(++i); comment(++i);
          while (i + 1 < lines.length) {
            const next = lines[i + 1];
            if (!next.trim()) { i++; continue; }
            if (metadataRow.test(next) || separator.test(next)) { comment(++i); continue; }
            if (metadataLegend.test(next)) {
              comment(++i);
              if (separator.test(lines[i + 1] || "")) comment(++i);
            }
            break;
          }
        }
        continue;
      }
      // The marker + column header + typed row uniquely identify a tibble,
      // regardless of which later step or expression printed it.
      if (/^\s*# A tibble:\s+[\d,]+\s*[×x]\s*\d+/.test(line)
          && /^\s*[\w.]+(?:\s+[\w.]+)*\s*$/.test(lines[i + 1] || "")
          && /^\s*(?:<[^>\n]+>\s*)+$/.test(lines[i + 2] || "")) {
        comment(++i); comment(++i);
        // Only contiguous printed rows; stop before blank lines or actual R.
        while (/^\s*\d+\s+[\p{L}\d_."'`]/u.test(lines[i + 1] || "")) comment(++i);
        continue;
      }
      if (line.trim() && !/^\s*#/.test(line)) executable = true;
    }
    scanner.scan(lines[i]);
  }
  return { code: lines.join("\n"), changed: fenced || outputLines > 0, fenced, outputLines, folderDiagram, executable };
}
export function datasetImportCode(path) {
  const title = path?.split(/[\\/]/).filter(Boolean).at(-1) || "Experiment";
  return `# Import this dataset, not the tutorial's sPerfect example.\n# Change analysis_type if this is not a lipidomics study.\nmexp <- MRMhubExperiment(title = ${JSON.stringify(title)}, analysis_type = "lipidomics")\nmexp <- import_data_mrmhub(\n  mexp,\n  path = file.path(dataset_dir, "long.csv"),\n  import_metadata = TRUE\n)\n`;
}
