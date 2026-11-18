import { parameterValue, displayValue, finalFilter, resultViewForOperation, metadataCoverageText } from "../ui/quant/model.js";
function equal(a, b) { if (JSON.stringify(a) !== JSON.stringify(b)) throw Error(`${JSON.stringify(a)} != ${JSON.stringify(b)}`); }
Deno.test("QUANT preserves literal text without evaluating R", () => {
  equal(parameterValue({type:"text", label:"filter"}, "system('bad')"), "system('bad')");
  equal(parameterValue({type:"text", label:"filter"}, "^PC 3[0-5]"), "^PC 3[0-5]");
});
Deno.test("QUANT parses numeric and character vectors with explicit NA", () => {
  equal(parameterValue({type:"number",vector:true}, "-5, 1e-9, NA"), [-5, 1e-9, null]);
  equal(parameterValue({type:"number",vector:true}, "[0, -5, null]"), [0, -5, null]);
  equal(parameterValue({type:"text",vector:true}, "SPL, BQC\nTQC"), ["SPL","BQC","TQC"]);
  equal(parameterValue({type:"boolean"}, "false"), false);
  equal(parameterValue({type:"boolean"}, ""), null);
});
Deno.test("QUANT rejects invalid numbers and required blanks", () => {
  for (const value of ["Infinity","bad","1, 2"]) {
    let threw = false; try { parameterValue({type:"number"}, value); } catch { threw = true; }
    if (!threw) throw Error(`Accepted ${value}`);
  }
  let threw = false; try { parameterValue({type:"text",required:true}, ""); } catch { threw = true; }
  if (!threw) throw Error("Accepted missing required input");
  equal(parameterValue({type:"number"}, ""), null);
});
Deno.test("QUANT roundtrips defaults and final QC has no example sample IDs", () => {
  equal(displayValue([1, null, 3]), "1, NA, 3");
  equal(finalFilter["min.rsquare.response"], .8);
  if ("features.to.keep" in finalFilter) throw Error("Tutorial-specific species must not be forced");
});
Deno.test("Current R choices and named column mappings stay literal and typed", () => {
  equal(parameterValue({type:"choice",choices:["none","1/sqrt(x)"]}, "1/sqrt(x)"), "1/sqrt(x)");
  equal(parameterValue({type:"mapping"}, '{"analysis_id":"sample","feature_area":"area"}'), {analysis_id:"sample",feature_area:"area"});
  for (const bad of ['[]','null','{"analysis_id":3}', 'c(analysis_id="sample")']) {
    let threw=false; try { parameterValue({type:"mapping"},bad); } catch { threw=true; }
    if (!threw) throw Error(`Accepted invalid mapping: ${bad}`);
  }
  equal(displayValue({analysis_id:"sample"}), '{"analysis_id":"sample"}');
  equal(parameterValue({type:"text",vector:true,lineSeparated:true}, "PC(18:1,16:0)\n^TG[0-9]{2,4}"), ["PC(18:1,16:0)","^TG[0-9]{2,4}"]);
  equal(parameterValue({type:"text",vector:true,lineSeparated:true}, '["a,b","c"]'),["a,b","c"]);
});
Deno.test("Plot and export operations avoid loading tables; metadata exposes coverage", () => {
  equal(resultViewForOperation("plot"),"plots"); equal(resultViewForOperation("export"),"plots");
  equal(resultViewForOperation("metadata"),"data"); equal(resultViewForOperation("import"),"data");
  equal(metadataCoverageText({features:{active:30,imported:64,missing:34,extra:0}}), "features: 30 active of 64 imported; 34 without metadata; 0 metadata-only");
});
