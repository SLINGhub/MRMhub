import { showRenameNotice } from "../ui/rename-notice.js";
const assert = (value, message) => { if (!value) throw Error(message); };

Deno.test("No old installation means no popup or cleanup request", async () => {
  const calls = [];
  await showRenameNotice(async command => { calls.push(command); return null; });
  assert(calls.join() === "rename_notice", "Unexpected command");
});

for (const canTrash of [true, false]) {
  Deno.test(`Rename notice acknowledges only after dismissal (${canTrash ? "macOS" : "Windows"})`, async () => {
    const previous = globalThis.document;
    const elements = new Map();
    const listeners = new Map();
    let removed = false, shown = false, acknowledged = false;
    const dialog = {
      setAttribute() {},
      querySelector(selector) { if (!elements.has(selector)) elements.set(selector, { focus() {} }); return elements.get(selector); },
      addEventListener(event, fn) { listeners.set(event, fn); },
      showModal() { shown = true; }, close() { listeners.get("close")(); }, remove() { removed = true; },
    };
    Object.defineProperty(globalThis, "document", { configurable: true, value: { createElement: () => dialog, body: { append() {} } } });
    try {
      const calls = [];
      const invoke = async command => {
        calls.push(command);
        if (command === "rename_notice") return acknowledged ? null : { canTrash, paths: ["/Applications/old <literal>.app"], instructions: "Manual removal instructions" };
        if (command === "rename_notice_acknowledge") acknowledged = true;
        if (command === "rename_trash_old_app") throw Error("Permission denied");
      };
      const pending = showRenameNotice(invoke);
      await Promise.resolve();
      assert(shown && !acknowledged, "Notice marked seen before being handled");
      assert(elements.get(".rename-trash").hidden === !canTrash, "Incorrect platform action");
      assert(elements.get(".rename-paths").textContent === "/Applications/old <literal>.app", "Path was not literal text");
      if (canTrash) {
        await elements.get(".rename-trash").onclick();
        assert(elements.get(".rename-result").textContent.includes("manual instructions"), "Missing permission fallback");
        assert(elements.get(".rename-dismiss").disabled === false, "Dismissal stayed disabled");
      }
      elements.get(".rename-dismiss").onclick();
      await pending;
      assert(removed && acknowledged, "Notice did not persist dismissal");
      shown = false;
      await showRenameNotice(invoke);
      assert(!shown, "Notice repeated after acknowledgement");
      if (!canTrash) assert(!calls.includes("rename_trash_old_app"), "Windows attempted direct deletion");
    } finally { Object.defineProperty(globalThis, "document", { configurable: true, value: previous }); }
  });
}
