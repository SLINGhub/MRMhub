# Peak integration in GUI 1.2.5

The Visualizer now includes a collapsible **Peak integration · acquisition sequence** overview for each transition in the dataset's target library. Existing reference view, individual edits, shape alignment, exact shared bounds, saved RT matrices, zoom, and PNG export remain available. This reuses MRMhub's trace and integration framework; no DIA precursor/fragment processing or numerical integration code is imported from Metabokit-DDA.

1. Run Workflow steps 1–2, open **Visualizer**, and choose a transition.
2. Review the **Batch** and **Peak** selectors. **All** shows every batch on a shared acquisition axis, with batch colors and separate start/end curves; choose a batch to focus it. Scroll/pinch to zoom around the pointer, drag to pan, use +/− keys or buttons, and **Reset zoom** (also Home/0) to return to the overview. Zoom survives reference edits and preview updates. Click samples in the sequence overview, or use their chromatogram reference toggles, to select reference plots. Selection includes each plot's valid peak windows.
3. Drag the visible start/end borders independently. A drag elsewhere in the chromatogram still draws a replacement window. Focus a border and use Left/Right to move one acquired point, or Shift+Left/Right for five.
4. Select at least two references spanning the batch to model drift. Click **Preview windows** to see dashed proposed windows in the overview and chromatograms. Preview uses the acquisition-sequence method and never writes files; changing references/bounds invalidates it.
5. **Apply selected RTs to all samples** writes the proposed per-sample bounds, runs the existing Step 3 calculation, saves through the existing matrix backup workflow, and clears reference selection on success. **Save & integrate** still saves individual edits only.

## Sequence rules

- Step 1 already extracts each mzML `<run startTimeStamp>` into column 3 of `misc/mzML_list.txt`. Sequence mode uses that acquisition time, not file creation/modification dates that can change when data is copied. No mzML decoding, new trace cache, R session, or persistent preview files are needed.
- Start and end boundaries interpolate independently, piecewise linearly by elapsed acquisition time. Selected reference windows remain intact. Outside the references' time range, nearest-reference bounds are held rather than extrapolated. One reference produces constant bounds, and the UI explains that limitation.
- Every transition, peak/isomer, and batch is independent. Batches without a reference for that peak stay unchanged. Missing/duplicate timestamps cause an explicit **Step 1 sample order** fallback for the affected batch only. Unzoned timestamps are treated consistently as instrument-clock times on every OS.
- The **All** overview uses a shared time axis when all timestamps are usable and distinct. Otherwise its display falls back to sample order so no samples overlap or disappear. This display choice does not change each batch's interpolation basis.
- Missing traces and windows outside a sample's acquired RT range are skipped rather than clipped. The preview reports the number left unchanged. Review the proposed windows before applying; interpolation does not detect peaks or guarantee that an interferent has been excluded.
- The batch/peak selectors change the overview only. Apply processes all selected-reference windows and their eligible samples, preserving unrelated RT-matrix columns. Use **Peak-shape alignment** for the prior cosine alignment or **Same bounds for all** for exact averaged limits. Those modes also work in reference view; acquisition-sequence mode requires transition view.
- Overview markers are sampled for batches over 400 samples, retaining selected anchors. Curves and proposals include all samples; individual chromatograms remain accessible using the existing lazy rendering.
- The bulk save validates all edits before writing, indexes matrix headers/sample names once, and replaces the active CSV only after a complete temporary write succeeds. Preview overlays and hit targets are omitted from PNG exports.

## Checks

`deno test tests/*.test.js` covers timestamp parsing/order, uneven acquisition gaps, piecewise boundaries, batches, multiple peaks, absent traces, immutable previews, and a 10,000-sample plan. `cargo test --offline --manifest-path src-tauri/Cargo.toml` covers per-sample/per-peak matrix writes and invalid bulk requests leaving the original unchanged. `tests/workspace-preview.html` uses the actual GUI with an in-memory bridge for light/dark, mouse/keyboard bounds, preview, and save/reintegrate checks; it does not access real datasets.
