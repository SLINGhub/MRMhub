export function fitPlot(width, height, viewportWidth, viewportHeight) {
  const scale = Math.min(1, viewportWidth / width, viewportHeight / height);
  return { scale, x: (viewportWidth - width * scale) / 2, y: (viewportHeight - height * scale) / 2 };
}

// Keep the image point under the cursor stationary while changing scale.
export function zoomPlot(view, scale, anchor, minScale, maxScale = 8) {
  scale = Math.max(minScale, Math.min(maxScale, scale));
  const ratio = scale / view.scale;
  return { scale, x: anchor.x - (anchor.x - view.x) * ratio, y: anchor.y - (anchor.y - view.y) * ratio };
}

export function constrainPlot(view, width, height, viewportWidth, viewportHeight) {
  const constrain = (position, size, viewport) => size <= viewport ? (viewport - size) / 2 : Math.max(viewport - size, Math.min(0, position));
  return { scale: view.scale, x: constrain(view.x, width * view.scale, viewportWidth), y: constrain(view.y, height * view.scale, viewportHeight) };
}

// Move the viewing window by 20% of its visible image area. Dividing by the
// zoom gives smaller source-image jumps at higher magnification.
export function panPlot(view, key, width, height, viewportWidth, viewportHeight) {
  const directions = { w: [0, 1], a: [1, 0], s: [0, -1], d: [-1, 0] };
  const direction = directions[key.toLowerCase()];
  if (!direction) return view;
  const sourceStepX = viewportWidth * .2 / view.scale;
  const sourceStepY = viewportHeight * .2 / view.scale;
  return constrainPlot({ ...view, x: view.x + direction[0] * sourceStepX * view.scale,
    y: view.y + direction[1] * sourceStepY * view.scale }, width, height, viewportWidth, viewportHeight);
}
