#!/usr/bin/env bash
# Upload release APK to prod as a stable download name, and write app-manifest.json
# so non-store clients can check for a newer versionCode.
# Target: krl@karielan-hub:~/punzh-dict/mobile-pack/punzh-dict-latest.apk
#         krl@karielan-hub:~/punzh-dict/mobile-pack/app-manifest.json
# (nginx: …/mobile-pack/punzh-dict-latest.apk , …/mobile-pack/app-manifest.json)
# Download with counter: https://punzhina.krc.karelia.ru/app/apk/
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=env.sh
source "$SCRIPT_DIR/env.sh"

MOBILE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
REMOTE="${PUNZH_APK_DEPLOY:-krl@karielan-hub}"
REMOTE_PATH="${PUNZH_APK_REMOTE_PATH:-punzh-dict/mobile-pack/punzh-dict-latest.apk}"
REMOTE_DIR="$(dirname "$REMOTE_PATH")"
REMOTE_APP_MANIFEST="${PUNZH_APP_MANIFEST_REMOTE_PATH:-$REMOTE_DIR/app-manifest.json}"
APK_DOWNLOAD_URL="${PUNZH_APK_DOWNLOAD_URL:-https://punzhina.krc.karelia.ru/app/apk/}"

version_line="$(grep -E '^version:' "$MOBILE_ROOT/pubspec.yaml" | head -1 | awk '{print $2}')"
version_name="${version_line%%+*}"
version_code="${version_line##*+}"
if [[ -z "$version_name" || -z "$version_code" || "$version_line" != *"+"* ]]; then
  echo "Cannot parse version from pubspec.yaml (want X.Y.Z+N)" >&2
  exit 1
fi
if ! [[ "$version_code" =~ ^[0-9]+$ ]]; then
  echo "versionCode must be an integer, got: $version_code" >&2
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
need ssh
need python3

published_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
manifest_tmp="$(mktemp)"
trap 'rm -f "$manifest_tmp"' EXIT
python3 - "$manifest_tmp" "$version_name" "$version_code" "$APK_DOWNLOAD_URL" "$published_at" <<'PY'
import json, sys
path, name, code, apk_url, published_at = sys.argv[1:6]
doc = {
    "version_name": name,
    "version_code": int(code),
    "apk_url": apk_url,
    "published_at": published_at,
}
with open(path, "w", encoding="utf-8") as f:
    json.dump(doc, f, ensure_ascii=False, indent=2)
    f.write("\n")
PY

echo "Uploading $src_name ($version_line) → $REMOTE:~/$REMOTE_PATH"
scp -o BatchMode=yes "$src" "$REMOTE:~/$REMOTE_PATH"
echo "Uploading app-manifest.json ($version_line) → $REMOTE:~/$REMOTE_APP_MANIFEST"
scp -o BatchMode=yes "$manifest_tmp" "$REMOTE:~/$REMOTE_APP_MANIFEST"
ssh -o BatchMode=yes "$REMOTE" "ls -lh ~/$REMOTE_PATH ~/$REMOTE_APP_MANIFEST"
echo "APK URL: https://punzhina.krc.karelia.ru/mobile-pack/punzh-dict-latest.apk"
echo "Tracked download: $APK_DOWNLOAD_URL"
echo "App manifest: https://punzhina.krc.karelia.ru/mobile-pack/app-manifest.json"
