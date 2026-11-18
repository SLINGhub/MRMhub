import { legacySteps, legacyGroups, matchesWorkflow, legacyDraftKey, historyForMode } from "../ui/quant/legacy.js";
Deno.test("Legacy follows all 23 original tutorial steps", () => {
  if (legacySteps.length !== 23 || legacySteps[13] !== "Normalization and quantification based on ISTDs" || legacySteps[22] !== "Sharing the MRMhubExperiment dataset") throw Error("Tutorial steps changed");
});
Deno.test("Legacy navigation groups preserve every original step and draft index exactly once", () => {
  const indices = legacyGroups.flatMap(group => Array.from({length:group.end-group.start+1}, (_,i)=>group.start+i));
  if (indices.length !== legacySteps.length || indices.some((index,i)=>index!==i)) throw Error("Grouped navigation changes step order or omits a step");
});
Deno.test("Workflow search matches labels, stages and function names without interpreting patterns", () => {
  if (!matchesWorkflow("  CALIBRATION curves ", "External calibration curves", "plot_calibrationcurves", "5 · Quantitate")) throw Error("Search should ignore case and outer spaces");
  if (!matchesWorkflow("exclude_features", "Exclude features", "exclude_features")) throw Error("Function-name search failed");
  if (!matchesWorkflow("", "Any operation")) throw Error("Blank search must restore navigation");
  if (matchesWorkflow("drift", "Import metadata workbook") || matchesWorkflow(".*", "Any operation")) throw Error("Search must be literal");
});
Deno.test("Legacy histories and drafts are separate from Guided and other datasets", () => {
  const history = [{id:"old", action:"run"}, {id:"manual", action:"legacy"}, {id:"edited", action:"edit"}];
  if (historyForMode(history, "legacy").map(x => x.id).join() !== "manual") throw Error("Wrong Legacy history");
  if (historyForMode(history, "guided").map(x => x.id).join() !== "old,edited") throw Error("Wrong Guided history");
  if (legacyDraftKey("/one/ASSAY") === legacyDraftKey("/two/ASSAY")) throw Error("Drafts overlap");
});
Deno.test("Output-only history remains archived but cannot be selected as a resumable session", () => {
  const history = [{id:"old",action:"legacy",resumable:false}, {id:"latest",action:"legacy",resumable:true}, {id:"prior-version",action:"run"}];
  if (historyForMode(history,"legacy").map(h=>h.id).join()!=="latest") throw Error("Archived session is still selectable");
  if (historyForMode(history,"guided").map(h=>h.id).join()!=="prior-version") throw Error("Old version support changed");
  if(history.length!==3) throw Error("Graph archive was mutated");
});
