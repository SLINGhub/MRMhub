// Pure form conversion: no R expressions, eval, or silent numeric coercion.
export function parameterValue(field, text) {
  if (field.type === "mapping") {
    if (!String(text).trim()) return null;
    let mapping;
    try { mapping = JSON.parse(text); } catch { throw Error(`${field.label}: enter a JSON object of column names.`); }
    if (!mapping || Array.isArray(mapping) || typeof mapping !== "object" || Object.entries(mapping).some(([k,v]) => !k || typeof v !== "string" || !v.trim())) throw Error(`${field.label}: use nonempty column names as keys and values.`);
    return mapping;
  }
  if (field.type === "boolean") {
    if (text === "" || text === "NA" || text == null) {
      if (field.required) throw new Error(`${field.label} is required.`);
      return null;
    }
    if (text === true || text === "true") return true;
    if (text === false || text === "false") return false;
    throw new Error(`${field.label}: choose Yes or No.`);
  }
  const value = String(text).trim();
  if (field.type === "choice" && value && value !== "NA" && !field.choices.includes(value)) throw Error(`${field.label}: choose one of the listed options.`);
  if (!value) {
    if (field.required) throw new Error(`${field.label} is required.`);
    return null; // Explicit R NA; an unchecked field is omitted instead.
  }
  let values = field.vector ? value.split(field.lineSeparated ? /\r?\n/ : /\r?\n|,/).map(v => v.trim()) : [value];
  if (field.vector && value.startsWith("[")) {
    try { values = JSON.parse(value); } catch { throw Error(`${field.label}: invalid JSON list.`); }
    if (!Array.isArray(values) || values.some(v => v !== null && !["string", "number"].includes(typeof v))) throw Error(`${field.label}: use a list of IDs or numbers.`);
    if (field.required && !values.length) throw Error(`${field.label} is required.`);
  }
  const converted = values.map(v => {
    if (v === "NA" || v === null) return null;
    if (field.type !== "number") return v;
    if (!String(v).trim() || !Number.isFinite(Number(v))) throw new Error(`${field.label}: enter a finite number (or NA).`);
    return Number(v);
  });
  return field.vector ? converted : converted[0];
}
export function displayValue(value) {
  if (value == null) return "";
  if (typeof value === "object" && !Array.isArray(value)) return JSON.stringify(value);
  return Array.isArray(value) ? value.map(v => v == null ? "NA" : String(v)).join(", ") : String(value);
}
export function resultViewForOperation(kind) { return ["plot", "export", "legacy"].includes(kind) ? "plots" : "data"; }
export function metadataCoverageText(coverage) {
  if (!coverage) return "";
  return ["analyses", "features"].map(kind => {
    const c = coverage[kind];
    return c ? `${kind}: ${c.active} active of ${c.imported} imported; ${c.missing} without metadata; ${c.extra} metadata-only` : "";
  }).filter(Boolean).join(" · ");
}
export const finalFilter = {
  clear_existing: true, use_batch_medians: true,
  include_qualifier: false, include_istd: false,
  "response.curves.selection": [1, 2], "response.curves.summary": "mean",
  "min.rsquare.response": .8, "min.slope.response": .75,
  "max.yintercept.response": .5, "min.signalblank.median.spl.pblk": 10,
  "min.intensity.median.spl": 100, "max.cv.conc.bqc": 25,
};
