import { savedGraphs, chooseGraph } from "../ui/quant/graphs.js";
import { progressDisplay, initializeProgress } from "../ui/quant/progress.js";
import { captureScroll, scrollPosition } from "../ui/quant/scroll-state.js";
function equal(a, b) { if (JSON.stringify(a) !== JSON.stringify(b)) throw Error(`${JSON.stringify(a)} != ${JSON.stringify(b)}`); }
const checkpoint = (id, action = "legacy", images = ["plot.png"]) => ({id, action, operation:"legacy-3", created:"2026-09-26", artifacts:[...images.map(name => ({name, kind:"image"})), {name:"workspace.rds",kind:"file"}]});
Deno.test("Graph history refers to original files across modes without confusing repeated filenames", () => {
  const history = [checkpoint("new", "legacy", []), checkpoint("old"), checkpoint("guided", "run"), checkpoint("old")];
  const before = JSON.stringify(history), graphs = savedGraphs(history);
  equal(graphs.map(g => [g.id,g.name,g.mode]), [["old","plot.png","Legacy"],["guided","plot.png","Guided"]]);
  equal(JSON.stringify(history), before);
  equal(chooseGraph(graphs,"new",""), graphs[0].key);
  equal(chooseGraph(graphs,"new",graphs[1].key), graphs[1].key);
  equal(chooseGraph(graphs,"guided",graphs[0].key), graphs[1].key);
  equal(savedGraphs([]), []); equal(chooseGraph([], "new", graphs[0].key), "");
});
Deno.test("Progress uses one decimal, bounded fixed-width terminal bars and no timer", () => {
  equal(progressDisplay(100/3).bar, "[==========                      ] 33.3%");
  equal(progressDisplay(100).bar, "[================================] 100.0%");
  equal(progressDisplay(-10).percent, 0); equal(progressDisplay(150).percent, 100);
});
Deno.test("Only the active R run can update progress, and finish hides it", () => {
  const styles = {}, pre = {style:{setProperty:(k,v)=>styles[k]=v}}, status = {}, attributes = {}, classes = new Set();
  const host = { querySelector: selector => selector === "pre" ? pre : status, classList:{add:x=>classes.add(x),remove:x=>classes.delete(x)}, setAttribute:(k,v)=>attributes[k]=v };
  const progress = initializeProgress({querySelector:()=>host});
  progress.start("run-a"); equal(classes.has("running"),true);
  equal(styles["--activity-visible"],0);
  progress.receive({token:"old",percent:99,message:"stale"}); equal(attributes["aria-valuenow"],"0.0");
  progress.receive({token:"run-a",percent:50,message:"Running statement 2"}); equal(attributes["aria-valuenow"],"50.0"); equal(status.textContent,"Running statement 2");
  equal(styles["--activity-end"],"15ch"); equal(styles["--activity-steps"],15); equal(styles["--activity-visible"],1);
  progress.finish(); equal(classes.has("running"),false);
  progress.receive({token:"run-a",percent:100,message:"late"}); equal(status.textContent,"Running statement 2");
});
Deno.test("Console resize preserves reading position or bottom anchoring", () => {
  const reading = captureScroll({scrollTop:400,scrollHeight:1500,clientHeight:300});
  equal(scrollPosition(reading,1500,800),400);
  equal(scrollPosition(reading,1500,300),400);
  // Clamping the expanded view must not overwrite the stored compact-view anchor.
  equal(scrollPosition(reading,1500,1400),100);
  equal(scrollPosition(reading,1500,300),400);
  const bottom = captureScroll({scrollTop:1200,scrollHeight:1500,clientHeight:300});
  equal(scrollPosition(bottom,1500,800),700);
  equal(scrollPosition(bottom,1800,300),1500);
});
