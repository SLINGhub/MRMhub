const sameSelection = (a, b) => a?.kind === b?.kind && a?.key === b?.key;

// One current dataset is retained. Plot-only edits can reuse it without any IPC.
// Rust jobs have unique IDs; canceling an old job can never cancel a newer one.
export function createSelectionLoader({ invoke, Channel, onChange, newId = () => crypto.randomUUID() }) {
  let generation = 0;
  let current = null;
  let pending = null;
  let disposed = false;

  function notify(type, detail = {}) {
    if (!disposed) onChange(current, { type, ...detail });
  }

  function cancelPending() {
    const old = pending;
    pending = null;
    if (!old) return;
    old.finish();
    // Stale callbacks are also guarded locally, even if cancellation fails.
    Promise.resolve(invoke("cancel_load", { requestId: old.id })).catch(() => {});
  }

  async function select(selection, { checkVersion = false } = {}) {
    if (disposed) return;
    const token = ++generation;
    cancelPending();
    const isCurrent = () => !disposed && generation === token;
    const reusable = current?.complete && sameSelection(current.selection, selection)
      && current.selection.count === selection.count
      && current.selection.catalogVersion === selection.catalogVersion;

    if (reusable) {
      current.selection = selection;
      current.error = null;
      if (!checkVersion) {
        notify("reuse");
        return current;
      }
      notify("checking");
      try {
        const version = await invoke("selection_version", { kind: selection.kind, key: selection.key });
        if (!isCurrent()) return;
        if (version === current.version) {
          notify("reuse");
          return current;
        }
      } catch (error) {
        if (isCurrent()) {
          current.error = String(error);
          notify("error");
        }
        return;
      }
    }
    if (!isCurrent()) return;

    const id = newId();
    const dataset = {
      selection,
      records: new Array(selection.count),
      groups: [],
      loadedCount: 0,
      complete: false,
      version: null,
      error: null,
    };
    current = dataset;
    let finish;
    let fail;
    const completed = new Promise((resolve, reject) => { finish = resolve; fail = reject; });
    const job = { id, finish };
    pending = job;
    const channel = new Channel();
    let streamError = null;
    let receivedComplete = false;
    channel.onmessage = (event) => {
      if (!isCurrent() || event.requestId !== id || streamError || receivedComplete) return;
      try {
        if (event.type === "qc") {
          dataset.groups = event.groups;
          notify("qc");
        } else if (event.type === "traces") {
          if (!Array.isArray(event.traces) || event.start !== dataset.loadedCount
              || event.start + event.traces.length > selection.count) {
            throw new Error("Trace count/order does not match the sample or transition list. Refresh the data files.");
          }
          for (let offset = 0; offset < event.traces.length; offset++) {
            dataset.records[event.start + offset] = event.traces[offset];
          }
          dataset.loadedCount += event.traces.length;
          notify("batch", { start: event.start, count: event.traces.length });
        } else if (event.type === "complete") {
          if (event.count !== selection.count || dataset.loadedCount !== event.count) {
            throw new Error(`Received ${event.count} traces; the list contains ${selection.count}. Refresh the data files.`);
          }
          receivedComplete = true;
          dataset.version = event.version;
          finish();
        } else {
          throw new Error("Unrecognized data message from the backend.");
        }
      } catch (error) {
        streamError = error;
        fail(error);
        Promise.resolve(invoke("cancel_load", { requestId: id })).catch(() => {});
      }
    };
    notify("start");
    try {
      // Channel delivery and command completion can arrive in either order.
      // Do not cache an incomplete stream merely because invoke() resolved.
      await Promise.all([
        invoke("load_selection", {
          kind: selection.kind, key: selection.key, catalogVersion: selection.catalogVersion,
          requestId: id, onEvent: channel,
        }),
        completed,
      ]);
      if (!isCurrent()) return;
      dataset.complete = true;
      notify("complete");
      return dataset;
    } catch (error) {
      finish();
      if (isCurrent()) {
        dataset.records = new Array(selection.count);
        dataset.groups = [];
        dataset.loadedCount = 0;
        dataset.error = error instanceof Error ? error.message : String(error);
        notify("error");
      }
    } finally {
      if (pending === job) pending = null;
    }
  }

  return {
    select,
    get current() { return current; },
    clear() {
      generation++;
      cancelPending();
      current = null;
      notify("clear");
    },
    dispose() {
      disposed = true;
      generation++;
      cancelPending();
      current = null;
    },
  };
}
