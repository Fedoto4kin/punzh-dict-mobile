#!/usr/bin/env bash
# Export dict.sqlite via Django in sibling punzh-dict and copy into assets/.
set -euo pipefail

APP_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PUNZH_ROOT="${PUNZH_DICT_ROOT:-$(cd "$APP_ROOT/../punzh-dict" && pwd)}"
CONTAINER="${PUNZH_DJANGO_CONTAINER:-punzh_django}"
REMOTE_TMP="/tmp/punzh-mobile-pack-seed-$$"

if [[ ! -d "$PUNZH_ROOT/app" ]]; then
  echo "punzh-dict not found at $PUNZH_ROOT (set PUNZH_DICT_ROOT)." >&2
  exit 1
fi

need() { command -v "$1" >/dev/null || { echo "Missing: $1" >&2; exit 1; }; }
need docker

# Prefer running export container names used in monorepo.
if [[ -z "${PUNZH_DJANGO_CONTAINER:-}" ]]; then
  names="$(docker ps --format '{{.Names}}' 2>/dev/null || true)"
  if echo "$names" | grep -qx 'punzh_django'; then
    CONTAINER=punzh_django
  elif echo "$names" | grep -qx 'punzh_web'; then
    CONTAINER=punzh_web
  elif echo "$names" | grep -qx 'punzh_django_export'; then
    CONTAINER=punzh_django_export
  fi
fi

mkdir -p "$APP_ROOT/assets"
echo "Exporting via $CONTAINER …"
docker exec -w /app "$CONTAINER" \
  python manage.py export_mobile_db --out "$REMOTE_TMP"
docker cp "$CONTAINER:$REMOTE_TMP/dict.sqlite" "$APP_ROOT/assets/dict.sqlite"
docker exec "$CONTAINER" rm -rf "$REMOTE_TMP"
ls -lh "$APP_ROOT/assets/dict.sqlite"
echo "Seed synced. Rebuild/run the app to pick up changes (first launch copies to documents)."
