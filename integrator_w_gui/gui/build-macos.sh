#!/usr/bin/env bash

set -Eeuo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../.." && pwd)"
integrator_dir="$repo_root/integrator_w_gui"
tauri_dir="$script_dir/src-tauri"

architecture="${MACOS_ARCHITECTURE:-universal}"
signing_identity="${APPLE_SIGNING_IDENTITY:-}"
notary_profile="${NOTARYTOOL_PROFILE:-mrmhub-notary}"
output_dir="${MACOS_OUTPUT_DIR:-$script_dir/dist}"
skip_notarization=false
ad_hoc=false

usage() {
  cat <<'EOF'
Build a signed, notarized macOS DMG for MRMhub Integrator GUI.

Usage: ./build-macos.sh [options]

Options:
  --architecture <universal|native|arm64|x86_64>
                              Target architecture (default: universal)
  --identity <name>           Developer ID Application identity. By default,
                              the first valid matching identity is selected.
  --notary-profile <name>     notarytool Keychain profile
                              (default: mrmhub-notary)
  --output-dir <path>         Copy the finished DMG here (default: ./dist)
  --skip-notarization         Build a Developer ID-signed DMG without submitting
                              it to Apple. It is not ready for public distribution.
  --ad-hoc                    Build an ad-hoc signed development DMG. This also
                              skips notarization and is not publicly distributable.
  -h, --help                  Show this help

Environment variable equivalents:
  MACOS_ARCHITECTURE, APPLE_SIGNING_IDENTITY, NOTARYTOOL_PROFILE,
  MACOS_OUTPUT_DIR
EOF
}

while (($# > 0)); do
  case "$1" in
    --architecture)
      [[ $# -ge 2 ]] || { echo "Error: --architecture requires a value." >&2; exit 2; }
      architecture="$2"
      shift 2
      ;;
    --identity)
      [[ $# -ge 2 ]] || { echo "Error: --identity requires a value." >&2; exit 2; }
      signing_identity="$2"
      shift 2
      ;;
    --notary-profile)
      [[ $# -ge 2 ]] || { echo "Error: --notary-profile requires a value." >&2; exit 2; }
      notary_profile="$2"
      shift 2
      ;;
    --output-dir)
      [[ $# -ge 2 ]] || { echo "Error: --output-dir requires a value." >&2; exit 2; }
      output_dir="$2"
      shift 2
      ;;
    --skip-notarization)
      skip_notarization=true
      shift
      ;;
    --ad-hoc)
      ad_hoc=true
      skip_notarization=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Error: unknown option '$1'." >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "Error: this script must be run on macOS." >&2
  exit 1
fi

if [[ -z "${DEVELOPER_DIR:-}" && -d /Applications/Xcode.app/Contents/Developer ]]; then
  active_developer_dir="$(xcode-select -p 2>/dev/null || true)"
  if [[ "$active_developer_dir" == */CommandLineTools ]]; then
    export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
  fi
fi

required_commands=(cargo rustc rustup xcrun xcodebuild codesign security ditto hdiutil)
for command_name in "${required_commands[@]}"; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "Error: required command '$command_name' was not found." >&2
    exit 1
  fi
done

if ! xcodebuild -version >/dev/null 2>&1; then
  echo "Error: a working full Xcode installation is required." >&2
  exit 1
fi

host_target="$(rustc -Vv | awk '/^host:/ { print $2 }')"
case "$architecture" in
  universal)
    tauri_target="universal-apple-darwin"
    worker_targets=(aarch64-apple-darwin x86_64-apple-darwin)
    ;;
  native)
    case "$host_target" in
      aarch64-apple-darwin|x86_64-apple-darwin) ;;
      *) echo "Error: unsupported macOS Rust host '$host_target'." >&2; exit 1 ;;
    esac
    tauri_target="$host_target"
    worker_targets=("$host_target")
    ;;
  arm64|aarch64|aarch64-apple-darwin)
    tauri_target="aarch64-apple-darwin"
    worker_targets=(aarch64-apple-darwin)
    ;;
  x86_64|x64|x86_64-apple-darwin)
    tauri_target="x86_64-apple-darwin"
    worker_targets=(x86_64-apple-darwin)
    ;;
  *)
    echo "Error: unsupported architecture '$architecture'." >&2
    echo "Choose universal, native, arm64, or x86_64." >&2
    exit 2
    ;;
esac

installed_targets="$(rustup target list --installed)"
for worker_target in "${worker_targets[@]}"; do
  if ! grep -Fxq "$worker_target" <<<"$installed_targets"; then
    echo "Error: Rust target '$worker_target' is not installed." >&2
    echo "Install it with: rustup target add $worker_target" >&2
    exit 1
  fi
done

if [[ "$ad_hoc" == true ]]; then
  signing_identity="-"
else
  if [[ -z "$signing_identity" ]]; then
    signing_identity="$({ security find-identity -v -p codesigning 2>/dev/null || true; } \
      | awk -F'"' '/Developer ID Application:/ { print $2; exit }')"
  fi

  if [[ -z "$signing_identity" ]]; then
    echo "Error: no usable 'Developer ID Application' identity was found." >&2
    echo "Install the certificate and its private key in your login Keychain, then check:" >&2
    echo "  security find-identity -v -p codesigning" >&2
    echo "For a local-only test build, pass --ad-hoc." >&2
    exit 1
  fi

  if [[ "$signing_identity" != "Developer ID Application:"* ]]; then
    echo "Error: '$signing_identity' is not a Developer ID Application identity." >&2
    echo "Apple notarization does not accept development or Mac App Distribution identities." >&2
    exit 1
  fi

  if ! security find-identity -v -p codesigning 2>/dev/null | grep -Fq "\"$signing_identity\""; then
    echo "Error: signing identity '$signing_identity' is not currently usable." >&2
    exit 1
  fi
fi

if [[ "$skip_notarization" == false ]]; then
  echo "Checking Apple notarization credentials in Keychain profile '$notary_profile'..."
  if ! xcrun notarytool history --keychain-profile "$notary_profile" --output-format json >/dev/null; then
    echo "Error: notarization profile '$notary_profile' could not be used." >&2
    echo "Create it once with:" >&2
    echo "  xcrun notarytool store-credentials \"$notary_profile\"" >&2
    exit 1
  fi
fi

if ! cargo tauri --version >/dev/null 2>&1; then
  echo "Installing Tauri CLI 2..."
  cargo install tauri-cli --version "^2" --locked
fi

sidecar_dir="$tauri_dir/binaries"
mkdir -p "$sidecar_dir"

for worker_target in "${worker_targets[@]}"; do
  echo "Building MRMhub Integrator worker for $worker_target..."
  cargo build \
    --release \
    --locked \
    --target "$worker_target" \
    --manifest-path "$integrator_dir/Cargo.toml"
  worker_sidecar="$sidecar_dir/MRMhub-integrator-worker-$worker_target"
  cp "$integrator_dir/target/$worker_target/release/MRMhub-integrator" "$worker_sidecar"
  chmod +x "$worker_sidecar"
done

if [[ "$tauri_target" == "universal-apple-darwin" ]]; then
  universal_worker="$sidecar_dir/MRMhub-integrator-worker-universal-apple-darwin"
  echo "Combining fresh worker builds into a universal sidecar..."
  lipo -create \
    "$sidecar_dir/MRMhub-integrator-worker-aarch64-apple-darwin" \
    "$sidecar_dir/MRMhub-integrator-worker-x86_64-apple-darwin" \
    -output "$universal_worker"
  chmod +x "$universal_worker"
fi

bundle_config='{"bundle":{"externalBin":["binaries/MRMhub-integrator-worker"]}}'

echo "Building and signing the $tauri_target app and DMG..."
(
  cd "$tauri_dir"
  LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    APPLE_SIGNING_IDENTITY="$signing_identity" \
    cargo tauri build \
      --target "$tauri_target" \
      --bundles app,dmg \
      --config "$bundle_config"
)

bundle_root="$tauri_dir/target/$tauri_target/release/bundle"
app_path="$bundle_root/macos/MRMhub Integrator GUI.app"
dmg_candidates=("$bundle_root/dmg/"*.dmg)

if [[ ! -d "$app_path" ]]; then
  echo "Error: expected app bundle was not created at '$app_path'." >&2
  exit 1
fi
if [[ ${#dmg_candidates[@]} -ne 1 || ! -f "${dmg_candidates[0]}" ]]; then
  echo "Error: expected exactly one DMG in '$bundle_root/dmg'." >&2
  exit 1
fi
dmg_path="${dmg_candidates[0]}"

codesign --verify --deep --strict --verbose=2 "$app_path"
if [[ "$ad_hoc" == false ]]; then
  codesign --verify --strict --verbose=2 "$dmg_path"
fi

if [[ "$skip_notarization" == false ]]; then
  echo "Submitting the DMG to Apple's notary service..."
  xcrun notarytool submit "$dmg_path" \
    --keychain-profile "$notary_profile" \
    --wait \
    --timeout 45m

  echo "Stapling and validating the notarization ticket..."
  xcrun stapler staple "$dmg_path"
  xcrun stapler validate "$dmg_path"
  spctl --assess --type open --context context:primary-signature --verbose=2 "$dmg_path"
else
  echo "Warning: notarization was skipped; this DMG is not ready for public distribution." >&2
fi

hdiutil verify "$dmg_path"

mkdir -p "$output_dir"
final_dmg="$output_dir/$(basename "$dmg_path")"
ditto "$dmg_path" "$final_dmg"

echo
echo "Build complete."
echo "DMG: $final_dmg"
echo "App: $app_path"
