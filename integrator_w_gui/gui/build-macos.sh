#!/usr/bin/env bash

set -Eeuo pipefail

# resolves the repository paths from this script's location
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../.." && pwd)"
integrator_dir="$repo_root/integrator_w_gui"
tauri_dir="$script_dir/src-tauri"

# stops early when the script is not running on macos
if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "Error: this script must be run on macOS."
  exit 1
fi

# checks the required apple and rust build tools
if ! xcode-select -p >/dev/null 2>&1; then
  echo "Error: Xcode Command Line Tools are required."
  echo "Run: xcode-select --install"
  exit 1
fi

for command_name in cargo rustc sips iconutil; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "Error: required command '$command_name' was not found."
    exit 1
  fi
done

# detects the native mac architecture used for the bundled worker
target_triple="$(rustc --print host-tuple 2>/dev/null || true)"
if [[ -z "$target_triple" ]]; then
  target_triple="$(rustc -Vv | awk '/^host:/ { print $2 }')"
fi

case "$target_triple" in
  aarch64-apple-darwin|x86_64-apple-darwin) ;;
  *)
    echo "Error: unsupported macOS Rust target '$target_triple'."
    exit 1
    ;;
esac

echo "Building MRMhub Integrator worker for $target_triple..."
cargo build --release --manifest-path "$integrator_dir/Cargo.toml"

# gives tauri the target-suffixed sidecar filename it expects
sidecar_dir="$tauri_dir/binaries"
sidecar_path="$sidecar_dir/MRMhub-integrator-worker-$target_triple"
mkdir -p "$sidecar_dir"
cp "$integrator_dir/target/release/MRMhub-integrator" "$sidecar_path"
chmod +x "$sidecar_path"

# installs the tauri command only when it is not already available
if ! cargo tauri --version >/dev/null 2>&1; then
  echo "Installing Tauri CLI 2..."
  cargo install tauri-cli --version "^2" --locked
fi

# runs the gui build script once so its neutral png build asset exists
cargo check --manifest-path "$tauri_dir/Cargo.toml"

# generates the neutral icns file required by the macos app bundler
icon_source="$tauri_dir/icons/icon.png"
icon_output="$tauri_dir/icons/icon.icns"
temporary_dir="$(mktemp -d)"
iconset="$temporary_dir/MRMhub.iconset"
trap 'rm -rf "$temporary_dir"' EXIT
mkdir -p "$iconset"

make_icon() {
  local size="$1"
  local filename="$2"
  sips -z "$size" "$size" "$icon_source" --out "$iconset/$filename" >/dev/null
}

make_icon 16 icon_16x16.png
make_icon 32 icon_16x16@2x.png
make_icon 32 icon_32x32.png
make_icon 64 icon_32x32@2x.png
make_icon 128 icon_128x128.png
make_icon 256 icon_128x128@2x.png
make_icon 256 icon_256x256.png
make_icon 512 icon_256x256@2x.png
make_icon 512 icon_512x512.png
make_icon 1024 icon_512x512@2x.png
iconutil -c icns "$iconset" -o "$icon_output"

# bundles the worker beside the gui executable and applies ad-hoc signing
bundle_config='{"bundle":{"externalBin":["binaries/MRMhub-integrator-worker"],"macOS":{"signingIdentity":"-"}}}'

echo "Building MRMhub Integrator GUI app and DMG..."
(
  cd "$tauri_dir"
  cargo tauri build --bundles app,dmg --config "$bundle_config"
)

echo
echo "Build complete."
echo "App: $tauri_dir/target/release/bundle/macos/MRMhub Integrator GUI.app"
echo "DMG directory: $tauri_dir/target/release/bundle/dmg"
