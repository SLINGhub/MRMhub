import { fitPlot, zoomPlot, constrainPlot, panPlot } from "./plot-geometry.js";

export function createPlotViewer(root) {
  const dialog = document.createElement("dialog");
  dialog.className = "q-plot-dialog"; dialog.setAttribute("aria-labelledby", "q-plot-title");
  dialog.innerHTML = `<div class="q-plot-toolbar"><strong id="q-plot-title"></strong><div class="q-actions"><button type="button" data-action="out" aria-label="Zoom out">−</button><output aria-label="Zoom level"></output><button type="button" data-action="in" aria-label="Zoom in">+</button><button type="button" data-action="fit">Fit</button><button type="button" data-action="actual">100%</button><button type="button" data-action="close" autofocus>Close ×</button></div></div><div class="q-plot-viewport" tabindex="0" aria-label="Plot viewer. Scroll or use plus and minus to zoom; drag to pan."><img draggable="false"></div><p class="q-help q-plot-hint">Scroll / pinch or + / − to zoom at your cursor · Drag to pan · Fit to reset · Esc to close</p>`;
  root.append(dialog);
  const viewport = dialog.querySelector(".q-plot-viewport"), image = dialog.querySelector("img");
  const label = dialog.querySelector("output");
  viewport.setAttribute("aria-label", "Plot viewer. Scroll or use plus and minus to zoom; drag or use W A S D to pan.");
  let view, pointer, drag, fitted = true;
  const fitView = () => fitPlot(image.naturalWidth, image.naturalHeight, viewport.clientWidth, viewport.clientHeight);
  const center = () => ({ x: viewport.clientWidth / 2, y: viewport.clientHeight / 2 });
  // Convert screen coordinates to layout pixels, including app GUI scaling.
  const point = event => {
    const rect = viewport.getBoundingClientRect();
    return { x: (event.clientX - rect.left) * viewport.clientWidth / rect.width, y: (event.clientY - rect.top) * viewport.clientHeight / rect.height };
  };
  function draw() {
    view = constrainPlot(view, image.naturalWidth, image.naturalHeight, viewport.clientWidth, viewport.clientHeight);
    image.style.transform = `translate(${view.x}px, ${view.y}px) scale(${view.scale})`;
    label.textContent = `${Math.round(view.scale * 100)}%`;
  }
  function fit() {
    if (!image.naturalWidth || !dialog.open) return;
    fitted = true; view = fitView(); draw();
  }
  function zoom(scale, anchor = pointer ?? center()) {
    if (!view) return;
    fitted = false; view = zoomPlot(view, scale, anchor, fitView().scale); draw();
  }
  viewport.addEventListener("wheel", event => {
    event.preventDefault();
    if (!view) return;
    pointer = point(event);
    const delta = event.deltaY * (event.deltaMode === 1 ? 16 : event.deltaMode === 2 ? viewport.clientHeight : 1);
    zoom(view.scale * Math.exp(-Math.max(-300, Math.min(300, delta)) * (event.ctrlKey ? .01 : .003)));
  }, { passive: false });
  viewport.addEventListener("pointerdown", event => {
    if (event.button !== 0 || !view) return;
    event.preventDefault(); viewport.focus(); pointer = point(event);
    drag = { id: event.pointerId, pointer, x: view.x, y: view.y };
    viewport.setPointerCapture(event.pointerId); viewport.classList.add("dragging");
  });
  viewport.addEventListener("pointermove", event => {
    pointer = point(event);
    if (!drag || event.pointerId !== drag.id) return;
    view.x = drag.x + pointer.x - drag.pointer.x; view.y = drag.y + pointer.y - drag.pointer.y; draw();
  });
  const stopDrag = () => { drag = undefined; viewport.classList.remove("dragging"); };
  viewport.addEventListener("lostpointercapture", stopDrag);
  viewport.addEventListener("pointerup", stopDrag);
  viewport.addEventListener("pointercancel", stopDrag);
  viewport.addEventListener("pointerleave", () => { if (!drag) pointer = undefined; });
  dialog.addEventListener("keydown", event => {
    if (!view || event.metaKey || event.ctrlKey || event.altKey) return;
    if (event.target.closest('input, textarea, select, [contenteditable="true"]')) return;
    if (["w", "a", "s", "d"].includes(event.key.toLowerCase())) {
      event.preventDefault();
      view = panPlot(view, event.key, image.naturalWidth, image.naturalHeight, viewport.clientWidth, viewport.clientHeight);
      draw();
    }
    if (["+", "=", "-", "_"].includes(event.key)) {
      event.preventDefault(); zoom(view.scale * (["+", "="].includes(event.key) ? 1.25 : .8));
    }
  });
  dialog.querySelector('[data-action="in"]').onclick = () => view && zoom(view.scale * 1.25);
  dialog.querySelector('[data-action="out"]').onclick = () => view && zoom(view.scale / 1.25);
  dialog.querySelector('[data-action="fit"]').onclick = fit;
  dialog.querySelector('[data-action="actual"]').onclick = () => zoom(1, center());
  dialog.querySelector('[data-action="close"]').onclick = () => dialog.close();
  dialog.addEventListener("close", () => { stopDrag(); image.removeAttribute("src"); view = undefined; });
  image.onload = () => {
    image.style.width = `${image.naturalWidth}px`; image.style.height = `${image.naturalHeight}px`;
    fit(); image.style.visibility = "visible";
    dialog.querySelector(".q-plot-hint").textContent = `${image.naturalWidth} × ${image.naturalHeight} original pixels · Scroll / pinch or + / − to zoom at your cursor · Drag or W/A/S/D to pan · Esc to close`;
  };
  image.onerror = () => { dialog.querySelector(".q-plot-hint").textContent = "Could not load this plot. Close and try again."; };
  new ResizeObserver(() => { if (dialog.open && view) { pointer = undefined; if (fitted) fit(); else draw(); } }).observe(viewport);
  return {
    close() { if (dialog.open) dialog.close(); },
    open(src, title) {
      view = undefined; pointer = undefined; fitted = true;
      dialog.querySelector("strong").textContent = title; image.alt = title;
      image.style.visibility = "hidden"; label.textContent = "Loading…";
      dialog.showModal(); image.src = src;
    },
  };
}
