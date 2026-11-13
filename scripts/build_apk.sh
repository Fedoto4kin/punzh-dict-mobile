#!/usr/bin/env bash
# Build a versioned APK for sideload / store upload.
# Name: punzh-dict-{versionName}-{versionCode}-{debug|release}.apk
# Source of truth: pubspec.yaml (see AGENTS.md).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=env.sh
source "$SCRIPT_DIR/env.sh"

MOBILE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MODE=release
TARGET_PLATFORM="${PUNZH_APK_ABI:-android-arm64}"

usage() {
  cat <<'EOF'
Build versioned APK (name includes pubspec version).

  scripts/build_apk.sh              # release (default)
  scripts/build_apk.sh --debug
  scripts/build_apk.sh --release

Override ABI: PUNZH_APK_ABI=android-arm64 (default).
EOF
  exit "${1:-0}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --debug) MODE=debug; shift ;;
    --release) MODE=release; shift ;;
    -h|--help) usage 0 ;;
    *) echo "Unknown arg: $1" >&2; usage 1 ;;
  esac
done

need() { command -v "$1" >/dev/null || { echo "Missing: $1" >&2; exit 1; }; }
need flutter

cd "$MOBILE_ROOT"

if [[ ! -f assets/dict.sqlite ]]; then
  echo "Missing assets/dict.sqlite — run scripts/sync_seed.sh first" >&2
  exit 1
fi

version_line="$(grep -E '^version:' pubspec.yaml | head -1 | awk '{print $2}')"
version_name="${version_line%%+*}"
version_code="${version_line##*+}"
if [[ -z "$version_name" || -z "$version_code" || "$version_line" != *"+"* ]]; then
  echo "Cannot parse version from pubspec.yaml (want X.Y.Z+N, got: ${version_line:-empty})" >&2
  exit 1
fi

expected="punzh-dict-${version_name}-${version_code}-${MODE}.apk"
out_dir="$MOBILE_ROOT/build/app/outputs/flutter-apk"

echo "Building $MODE APK (pubspec $version_line)…"
flutter build apk "--$MODE" --target-platform="$TARGET_PLATFORM"

built="$out_dir/$expected"
# Flutter sometimes still emits app-{mode}.apk; normalize to versioned name.
if [[ ! -f "$built" ]]; then
  fallback="$out_dir/app-${MODE}.apk"
  if [[ -f "$fallback" ]]; then
    cp -f "$fallback" "$built"
    echo "Renamed $fallback → $built"
  else
    echo "Expected $built (or $fallback) after build; contents of $out_dir:" >&2
    ls -la "$out_dir" >&2 || true
    exit 1
  fi
fi

echo "APK: $built"
ls -lh "$built"
