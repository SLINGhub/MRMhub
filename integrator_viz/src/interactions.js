// Keep the latest input until the browser can paint it. flush() is used for
// the final zoom transform before rebuilding the nearest-point index.
export function createFrameTask(callback, scheduler = {
  request: (callback) => requestAnimationFrame(callback),
  cancel: (id) => cancelAnimationFrame(id),
}) {
  let frame = null;
  let pending = false;
  let value;
  let disposed = false;
  let generation = 0;
  function run() {
    if (!pending || disposed) return;
    const next = value;
    pending = false;
    value = undefined;
    callback(next);
  }
  function cancelFrame() {
    generation++;
    if (frame !== null) scheduler.cancel(frame);
    frame = null;
  }
  function cancel() {
    cancelFrame();
    pending = false;
    value = undefined;
  }
  return {
    schedule(next) {
      if (disposed) return;
      value = next;
      pending = true;
      if (frame !== null) return;
      const scheduledGeneration = ++generation;
      frame = scheduler.request(() => {
        if (disposed || scheduledGeneration !== generation) return;
        frame = null;
        run();
      });
    },
    flush() { cancelFrame(); run(); },
    cancel,
    dispose() { disposed = true; cancel(); },
  };
}

