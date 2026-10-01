// A selection owns its callbacks and rendering work until another selection starts.
export function createRequestGate() {
  let active;
  return {
    begin() {
      active?.cancel();
      let cancelled = false;
      const cleanup = new Set();
      active = {
        isCurrent: () => !cancelled,
        onCancel(callback) {
          if (cancelled) callback();
          else cleanup.add(callback);
        },
        cancel() {
          if (cancelled) return;
          cancelled = true;
          for (const callback of cleanup) callback();
          cleanup.clear();
        },
      };
      return active;
    },
    cancel() {
      active?.cancel();
    },
  };
}

// Bound each frame's work without dropping or resampling scientific data.
export function createFrameQueue({
  request,
  renderItem,
  createBatch = () => [],
  commitBatch = () => {},
  onError = () => {},
  schedule = requestAnimationFrame,
  cancelScheduled = cancelAnimationFrame,
  now = () => performance.now(),
  budgetMs = 8,
  maxItems = 128,
}) {
  let items = [];
  let head = 0;
  let frame = null;
  let stopped = false;
  let failure;
  const waiters = [];
  const settle = () => {
    for (const { resolve, reject } of waiters.splice(0)) {
      if (failure) reject(failure);
      else resolve();
    }
  };
  const cancel = () => {
    stopped = true;
    if (frame !== null) cancelScheduled(frame);
    frame = null;
    items = [];
    head = 0;
    settle();
  };
  const flush = () => {
    frame = null;
    if (!request.isCurrent() || stopped) return cancel();
    try {
      const batch = createBatch();
      const started = now();
      let count = 0;
      while (head < items.length) {
        const item = items[head];
        items[head++] = undefined;
        renderItem(item, batch);
        count++;
        if (count >= maxItems || now() - started >= budgetMs) break;
      }
      commitBatch(batch);
      if (head < items.length) {
        if (head > 1024) {
          items = items.slice(head);
          head = 0;
        }
        frame = schedule(flush);
      } else {
        items = [];
        head = 0;
        settle();
      }
    } catch (error) {
      failure = error;
      cancel();
      onError(error);
    }
  };
  request.onCancel(cancel);
  return {
    push(item) {
      if (stopped || !request.isCurrent()) return;
      items.push(item);
      if (frame === null) frame = schedule(flush);
    },
    finish() {
      if (failure) return Promise.reject(failure);
      if (stopped || head === items.length) return Promise.resolve();
      return new Promise((resolve, reject) => waiters.push({ resolve, reject }));
    },
  };
}

export function validPeakRanges(positions, length) {
  const ranges = [];
  for (let i = 0; i + 1 < positions.length; i += 2) {
    const begin = positions[i] - 1;
    const end = positions[i + 1];
    if (Number.isInteger(begin) && Number.isInteger(end) &&
        begin >= 0 && end > begin && end <= length) {
      ranges.push({ begin, end, offset: i });
    }
  }
  return ranges;
}

/**
 * Keep inexpensive layout slots for all records, but SVGs only near the viewport.
 * A renderer returns { node, dispose? }, or null while a streamed record is pending.
 * Width and height are the SVG's inner dimensions; existing charts have 2px borders.
 */
export function createVirtualCharts({
  container,
  count,
  width,
  height,
  render,
  overscanPx = 400,
  onError = (error) => { throw error; },
}) {
  if (!container?.ownerDocument || typeof render !== "function") {
    throw new TypeError("A container and chart renderer are required");
  }
  if (!Number.isSafeInteger(count) || count < 0) {
    throw new RangeError("Chart count must be a nonnegative safe integer");
  }
  const dimension = (value) => {
    if (!Number.isFinite(value) || value <= 0) {
      throw new RangeError("Chart dimensions must be positive finite numbers");
    }
    return value;
  };
  width = dimension(width);
  height = dimension(height);
  if (!Number.isFinite(overscanPx) || overscanPx < 0) {
    throw new RangeError("Viewport overscan must be a nonnegative finite number");
  }

  const doc = container.ownerDocument;
  const view = doc.defaultView ?? globalThis;
  const requestFrame = view.requestAnimationFrame
    ? view.requestAnimationFrame.bind(view)
    : (callback) => globalThis.setTimeout(callback, 16);
  const cancelFrame = view.cancelAnimationFrame
    ? view.cancelAnimationFrame.bind(view)
    : globalThis.clearTimeout;
  const pending = new Set();
  const fragment = doc.createDocumentFragment();
  const statesByNode = new Map();
  let disposed = false;
  let frame = null;
  let measureRequested = false;
  let observer = null;
  let observerGeneration = 0;
  let mountedCount = 0;

  const states = Array.from({ length: count }, (_, index) => {
    const slot = doc.createElement("div");
    slot.className = "chart-slot virtual-chart-slot";
    slot.dataset.chartIndex = String(index);
    // A block wrapper avoids the inline SVG baseline changing reserved height.
    slot.style.boxSizing = "border-box";
    slot.style.flex = "0 0 auto";
    slot.style.position = "relative";
    slot.style.width = `${width + 4}px`;
    slot.style.height = `${height + 4}px`;
    const state = { index, slot, visible: false, chart: null, invalid: false };
    statesByNode.set(slot, state);
    fragment.appendChild(slot);
    return state;
  });
  container.appendChild(fragment);

  function unmount(state) {
    const chart = state.chart;
    if (!chart) return;
    state.chart = null;
    mountedCount -= 1;
    try {
      chart.dispose?.();
    } finally {
      state.slot.replaceChildren();
    }
  }

  function setVisible(state, visible) {
    if (state.visible === visible) return;
    state.visible = visible;
    pending.add(state);
  }

  function measureVisibility() {
    const viewportWidth = view.innerWidth || doc.documentElement.clientWidth;
    const viewportHeight = view.innerHeight || doc.documentElement.clientHeight;
    for (const state of states) {
      const bounds = state.slot.getBoundingClientRect();
      setVisible(
        state,
        bounds.width > 0 && bounds.height > 0 &&
          bounds.bottom >= -overscanPx &&
          bounds.top <= viewportHeight + overscanPx &&
          bounds.right >= -overscanPx &&
          bounds.left <= viewportWidth + overscanPx,
      );
    }
  }

  function flush() {
    frame = null;
    if (disposed) return;
    if (measureRequested) {
      measureRequested = false;
      measureVisibility();
    }
    const started = performance.now();
    for (const state of pending) {
      pending.delete(state);
      if (disposed) return;
      if (!state.visible || state.invalid) unmount(state);
      state.invalid = false;
      if (!state.visible || state.chart) continue;
      let chart;
      try {
        chart = render(state.index);
      } catch (error) {
        pending.clear();
        onError(error);
        return;
      }
      if (chart == null) continue;
      if (!chart.node) {
        throw new TypeError("The chart renderer must return { node, dispose? } or null");
      }
      // Renderers own their listeners; unmount/dispose always invokes their cleanup.
      chart.node.style.display = "block";
      state.slot.appendChild(chart.node);
      state.chart = chart;
      mountedCount += 1;
      if (performance.now() - started >= 8) break;
    }
    if (pending.size) schedule();
  }

  function schedule() {
    if (!disposed && frame === null) frame = requestFrame(flush);
  }

  function requestMeasurement() {
    if (disposed) return;
    measureRequested = true;
    schedule();
  }

  function observeSlots() {
    const generation = ++observerGeneration;
    observer?.disconnect();
    observer = new view.IntersectionObserver((entries) => {
      // A resize/disposal may leave a callback from the previous observer queued.
      if (disposed || generation !== observerGeneration) return;
      for (const entry of entries) {
        const state = statesByNode.get(entry.target);
        if (state) setVisible(state, entry.isIntersecting);
      }
      if (pending.size) schedule();
    }, { root: null, rootMargin: `${overscanPx}px` });
    for (const state of states) observer.observe(state.slot);
  }

  if (typeof view.IntersectionObserver === "function") {
    observeSlots();
  } else {
    // Capture catches scrolling in nested scroll containers, too. The fallback
    // checks viewport bounds once per frame; it never eagerly renders every chart.
    doc.addEventListener("scroll", requestMeasurement, { capture: true, passive: true });
    view.addEventListener("resize", requestMeasurement, { passive: true });
    requestMeasurement();
  }

  return {
    get mountedCount() {
      return mountedCount;
    },

    refresh(index) {
      if (disposed) return;
      if (index !== undefined && (!Number.isInteger(index) || index < 0 || index >= count)) return;
      const targets = index === undefined ? states : [states[index]];
      for (const state of targets) {
        if (!state) continue;
        state.invalid = true;
        if (state.visible) pending.add(state);
      }
      if (pending.size) schedule();
    },

    resize(next) {
      if (disposed) return;
      const nextWidth = dimension(next.width);
      const nextHeight = dimension(next.height);
      if (width === nextWidth && height === nextHeight) return;
      width = nextWidth;
      height = nextHeight;
      for (const state of states) {
        state.slot.style.width = `${width + 4}px`;
        state.slot.style.height = `${height + 4}px`;
        state.invalid = true;
        pending.add(state);
      }
      // Resizing changes flex wrapping. Recalculate layout before the next paint,
      // then let a fresh observer track scrolling using the new slot geometry.
      if (observer) observeSlots();
      requestMeasurement();
    },

    dispose() {
      if (disposed) return;
      disposed = true;
      observerGeneration += 1;
      observer?.disconnect();
      observer = null;
      doc.removeEventListener("scroll", requestMeasurement, true);
      view.removeEventListener("resize", requestMeasurement);
      if (frame !== null) cancelFrame(frame);
      frame = null;
      pending.clear();
      for (const state of states) {
        unmount(state);
        state.slot.remove();
      }
      statesByNode.clear();
      states.length = 0;
    },
  };
}
