#!/usr/bin/env bash
# Copy the latest release APK into sibling punzh-dict app/downloads/ for site/git.
# Does NOT commit — commit in punzh-dict after review (see AGENTS.md).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=env.sh
source "$SCRIPT_DIR/env.sh"

MOBILE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PUNZH_ROOT="${PUNZH_DICT_ROOT:-$(cd "$MOBILE_ROOT/../punzh-dict" && pwd)}"
DEST="$PUNZH_ROOT/app/downloads"

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

if [[ ! -d "$PUNZH_ROOT/app" ]]; then
  echo "punzh-dict not found at $PUNZH_ROOT (set PUNZH_DICT_ROOT)." >&2
  exit 1
fi

mkdir -p "$DEST"
versioned="punzh-dict-${version_name}-${version_code}.apk"
cp -f "$src" "$DEST/$versioned"
cp -f "$src" "$DEST/punzh-dict.apk"

sha256="$(sha256sum "$DEST/punzh-dict.apk" | awk '{print $1}')"
size="$(stat -c%s "$DEST/punzh-dict.apk")"
built_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

cat >"$DEST/manifest.json" <<EOF
{
  "version": "$version_name",
  "version_code": $version_code,
  "filename": "punzh-dict.apk",
  "sha256": "$sha256",
  "size": $size,
  "built_at": "$built_at",
  "source": "$src_name"
}
EOF

echo "Published to $DEST:"
ls -lh "$DEST/$versioned" "$DEST/punzh-dict.apk" "$DEST/manifest.json"
echo "Next: commit app/downloads/ in punzh-dict (git -C \"$PUNZH_ROOT\" …)."
