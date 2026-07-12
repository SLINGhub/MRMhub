# Tauri + Vanilla

This template should help get you started developing with Tauri in vanilla HTML, CSS and Javascript.

## Recommended IDE Setup

- [VS Code](https://code.visualstudio.com/) + [Tauri](https://marketplace.visualstudio.com/items?itemName=tauri-apps.tauri-vscode) + [rust-analyzer](https://marketplace.visualstudio.com/items?itemName=rust-lang.rust-analyzer)

## Self compilation

To compile on Mac:
- Download the source and cd bash directory to the MRMhub folder
- run `bash integrator/gui/build-macos.sh`
- output in integrator/gui/src-tauri/target/release, put both executables in the same directory to run (may need to verify security perms on newer versions of OSX!)

To compile on Windows:
- Download the source and cd bash directory to the MRMhub folder
- run `cargo build --release --manifest-path integrator/Cargo.toml`
- outputs in /integrator/gui/src-tauri-target/release; MRMhub-integrator-worker.exe must be in the same directory to run the gui !