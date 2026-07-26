# MRMhub-viz

Interactive viewer for INTEGRATOR peak-integration results — a [Tauri](https://tauri.app) app
(Rust backend + HTML/JS/d3 frontend). It reads the `misc/` binary results produced by INTEGRATOR
step 3 and lets you review every transition's chromatograms and integration borders.

## Building from source

**Prerequisites**

- **Rust** (stable) — the `src-tauri` backend is compiled by cargo. Install via <https://rustup.rs>.
- **Node.js + npm** — for the frontend and the Tauri CLI. Install via <https://nodejs.org>.
- **Platform system dependencies** required by Tauri — see
  <https://tauri.app/start/prerequisites/>:
  - **Windows:** WebView2 runtime (preinstalled on Windows 11) + the MSVC C++ Build Tools.
  - **macOS:** Xcode Command Line Tools (`xcode-select --install`).
  - **Linux:** WebKitGTK and related dev libraries (e.g. `webkit2gtk-4.1`, `libgtk-3-dev`,
    `librsvg2-dev`, `libayatana-appindicator3-dev`, `build-essential`).

**Build**

```bash
cd integrator_viz
npm install            # frontend + Tauri CLI dependencies
npm run tauri build    # compiles the Rust backend and bundles the app
```

The bundled application is written to `src-tauri/target/release/bundle/`. For a live-reloading
development window, use `npm run tauri dev` instead.

## Version

The version is set in `src-tauri/tauri.conf.json` (`version`) and mirrored in `package.json` and
`src-tauri/Cargo.toml`; keep the three in sync when bumping. It is embedded into the bundled
executable (shown in the window title, and in the file's OS properties / bundle metadata).
