// Step names follow the original lipidomics tutorial, not the guided UI groups.
export const legacySteps = [
  "Set up a project", "Importing analysis results", "A glimpse on the imported data",
  "Analytical design and timeline", "Overview of chromatographic separation",
  "Peak picking QC", "Signal trends of internal standards", "Adding detailed metadata",
  "Overall trends and possible outliers", "PCA of all QC types", "Excluding technical outliers",
  "Response curves", "Isotope interference correction",
  "Normalization and quantification based on ISTDs", "Effects of class-wide ISTD normalization",
  "Drift correction", "Batch-effect correction", "Saving runscatter plots of all features as PDF",
  "QC-based feature filtering", "Summary of the QC filtering", "Lipidome profile",
  "Saving a report with data, metadata and processing details", "Sharing the MRMhubExperiment dataset",
];
// Navigation groups only: original step indices and saved drafts never change.
export const legacyGroups = [
  { label: "Project & import", start: 0, end: 2 },
  { label: "Inspect & annotate", start: 3, end: 7 },
  { label: "QC & exclusions", start: 8, end: 12 },
  { label: "Quantitate", start: 13, end: 14 },
  { label: "Correct & compare", start: 15, end: 17 },
  { label: "Review & export", start: 18, end: 22 },
];
export function matchesWorkflow(query, ...labels) {
  const text = labels.join(" ").toLocaleLowerCase();
  return query.trim().toLocaleLowerCase().split(/\s+/).every(word => text.includes(word));
}
export const legacyDraftKey = path => `mrmhub-quant-legacy-drafts:${path}`;
export function historyForMode(history, mode) {
  return history.filter(item => item.resumable !== false && (item.action === "legacy") === (mode === "legacy"));
}
