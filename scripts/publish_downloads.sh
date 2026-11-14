#!/usr/bin/env bash
# Upload release APK to prod as a stable download name.
# Target: krl@karielan-hub:~/punzh-dict/mobile-pack/punzh-dict-latest.apk
# (nginx: https://punzhina.krc.karelia.ru/mobile-pack/punzh-dict-latest.apk)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=env.sh
source "$SCRIPT_DIR/env.sh"

MOBILE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
REMOTE="${PUNZH_APK_DEPLOY:-krl@karielan-hub}"
REMOTE_PATH="${PUNZH_APK_REMOTE_PATH:-punzh-dict/mobile-pack/punzh-dict-latest.apk}"

version_line="$(grep -E '^version:' "$MOBILE_ROOT/pubspec.yaml" | head -1 | awk '{print $2}')"
version_name="${version_line%%+*}"
version_code="${version_line##*+}"
if [[ -z "$version_name" || -z "$version_code" || "$version_line" != *"+"* ]]; then
  echo "Cannot parse version from pubspec.yaml (want X.Y.Z+N)" >&2
  exit 1
fi

src_name="punzh-dict-${version_name}-${version_code}-release.apk"
src="$MOBILE_ROOT/build/app/outputs/flutter-apk/$src_name"
if [[ ! -f "$src" ]]; then
  alt="$MOBILE_ROOT/store/rustore/$src_name"
  if [[ -f "$alt" ]]; then
    src="$alt"
  else
    echo "Missing $src_name — build release APK first (scripts/build_apk.sh)" >&2
    exit 1
  fi
fi

need() { command -v "$1" >/dev/null || { echo "Missing: $1" >&2; exit 1; }; }
need scp

echo "Uploading $src_name ($version_line) → $REMOTE:~/$REMOTE_PATH"
scp -o BatchMode=yes "$src" "$REMOTE:~/$REMOTE_PATH"
ssh -o BatchMode=yes "$REMOTE" "ls -lh ~/$REMOTE_PATH"
echo "URL: https://punzhina.krc.karelia.ru/mobile-pack/punzh-dict-latest.apk"
