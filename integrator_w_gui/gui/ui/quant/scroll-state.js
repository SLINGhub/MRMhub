export function captureScroll(element) {
  return { top: element.scrollTop, bottom: element.scrollHeight - element.clientHeight - element.scrollTop <= 2 };
}
export function scrollPosition(state, scrollHeight, clientHeight) {
  const max = Math.max(0, scrollHeight - clientHeight);
  return state.bottom ? max : Math.min(max, Math.max(0, state.top));
}
