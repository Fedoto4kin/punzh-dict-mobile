#!/usr/bin/env bash
# Build + install + launch the offline dictionary on a USB-connected phone.
#
# One-time on Huawei (EMUI/Harmony): Developer options → enable
#   «Отладка по USB», «Установка через USB» / «USB debugging (Security settings)»,
#   then accept the RSA fingerprint dialog once.
#
# Usage:
#   scripts/debug_usb.sh              # flutter run (hot reload)
#   scripts/debug_usb.sh --install    # build APK, adb install -r, launch
#   scripts/debug_usb.sh --fast       # reinstall existing debug APK only
#   scripts/debug_usb.sh --seed       # sync dict.sqlite then run
#   scripts/debug_usb.sh --device ID  # pick serial if several phones
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=env.sh
source "$SCRIPT_DIR/env.sh"

MOBILE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PKG="${PUNZH_ANDROID_PKG:-host.punzh.punzh_dict}"
ACTIVITY="${PUNZH_ANDROID_ACTIVITY:-$PKG/.MainActivity}"
FLUTTER_APK_DIR="$MOBILE_ROOT/build/app/outputs/flutter-apk"
WAIT_SEC="${PUNZH_ADB_WAIT:-60}"

# Prefer versioned name (punzh-dict-{ver}-{code}-debug.apk); fall back to Flutter default.
resolve_debug_apk() {
  local f
  f="$(ls -1t "$FLUTTER_APK_DIR"/punzh-dict-*-debug.apk 2>/dev/null | head -1 || true)"
  if [[ -n "$f" && -f "$f" ]]; then
    echo "$f"
    return 0
  fi
  if [[ -f "$FLUTTER_APK_DIR/app-debug.apk" ]]; then
    echo "$FLUTTER_APK_DIR/app-debug.apk"
    return 0
  fi
  return 1
}

MODE=run
SYNC_SEED=0
DEVICE=""

usage() {
  cat <<'EOF'
Build + install + launch on a USB phone.

One-time Huawei: developer options → USB debugging + «Установка через USB»,
accept RSA dialog once (Always allow).

  scripts/debug_usb.sh              # flutter run (hot reload)
  scripts/debug_usb.sh --install    # build APK, adb install -r, launch
  scripts/debug_usb.sh --fast       # reinstall existing debug APK only
  scripts/debug_usb.sh --seed       # sync dict.sqlite then run/install
  scripts/debug_usb.sh --device ID  # serial if several phones
EOF
  exit "${1:-0}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --run) MODE=run; shift ;;
    --install) MODE=install; shift ;;
    --fast) MODE=fast; shift ;;
    --seed) SYNC_SEED=1; shift ;;
    --device) DEVICE="${2:?}"; shift 2 ;;
    -h|--help) usage 0 ;;
    *) echo "Unknown arg: $1" >&2; usage 1 ;;
  esac
done

need() { command -v "$1" >/dev/null || { echo "Missing: $1" >&2; exit 1; }; }
need adb
need flutter

huawei_hint() {
  cat <<'EOF' >&2

Huawei / EMUI — если установка просит подтверждение или падает с
INSTALL_FAILED_USER_RESTRICTED / INSTALL_FAILED_VERIFICATION_FAILURE:

  1. Параметры → О телефоне → 7× «Номер сборки» (режим разработчика)
  2. Для разработчиков:
       • Отладка по USB — вкл
       • Установка через USB — вкл
       • Отладка по USB (параметры безопасности) — вкл (если есть)
  3. Шторка USB → «Передача файлов» / MTP (не «Только зарядка»)
  4. На экране принять «Разрешить отладку по USB?» (с галкой «Всегда»)

После этого повторные install/run обычно без ручных шагов.
EOF
}

wait_for_device() {
  echo "Waiting for USB device (timeout ${WAIT_SEC}s)…"
  if ! timeout "$WAIT_SEC" adb wait-for-device; then
    echo "No device within ${WAIT_SEC}s. Plug the phone and unlock it." >&2
    huawei_hint
    exit 1
  fi
  # Authorization can leave device as "unauthorized"
  local deadline=$((SECONDS + WAIT_SEC))
  while (( SECONDS < deadline )); do
    local line
    if [[ -n "$DEVICE" ]]; then
      line="$(adb devices | awk -v d="$DEVICE" '$1==d {print $2}')"
    else
      line="$(adb devices | awk 'NR>1 && $2=="device" {print $2; exit}')"
    fi
    if [[ "$line" == "device" ]]; then
      return 0
    fi
    if adb devices | grep -q 'unauthorized'; then
      echo "Phone is unauthorized — accept the USB debugging dialog on the screen." >&2
    fi
    sleep 1
  done
  echo "Device not ready (still unauthorized / offline)." >&2
  adb devices -l >&2 || true
  huawei_hint
  exit 1
}

pick_serial() {
  if [[ -n "$DEVICE" ]]; then
    echo "$DEVICE"
    return
  fi
  local serials
  mapfile -t serials < <(adb devices | awk 'NR>1 && $2=="device" {print $1}')
  if ((${#serials[@]} == 0)); then
    echo "No authorized device." >&2
    huawei_hint
    exit 1
  fi
  if ((${#serials[@]} > 1)); then
    echo "Several devices; pass --device <serial>:" >&2
    printf '  %s\n' "${serials[@]}" >&2
    exit 1
  fi
  echo "${serials[0]}"
}

adb_install() {
  local serial="$1"
  local apk="$2"
  echo "Installing $apk → $serial"
  set +e
  local out
  out="$(adb -s "$serial" install -r -t -d --user 0 "$apk" 2>&1)"
  local rc=$?
  set -e
  echo "$out"
  if ((rc != 0)); then
    if echo "$out" | grep -qiE 'USER_RESTRICTED|VERIFICATION_FAILURE|INSTALL_FAILED|not authorized'; then
      huawei_hint
    fi
    exit "$rc"
  fi
}

launch_app() {
  local serial="$1"
  echo "Launching $ACTIVITY"
  adb -s "$serial" shell am force-stop "$PKG" >/dev/null 2>&1 || true
  adb -s "$serial" shell am start -n "$ACTIVITY" >/dev/null
}

cd "$MOBILE_ROOT"

if [[ ! -f assets/dict.sqlite ]]; then
  echo "Missing assets/dict.sqlite — run with --seed or scripts/sync_seed.sh" >&2
  exit 1
fi

if ((SYNC_SEED)); then
  "$SCRIPT_DIR/sync_seed.sh"
fi

wait_for_device
SERIAL="$(pick_serial)"
echo "Device: $SERIAL"
adb -s "$SERIAL" devices -l | grep "$SERIAL" || true

case "$MODE" in
  fast)
    APK="$(resolve_debug_apk || true)"
    if [[ -z "${APK:-}" ]]; then
      echo "No debug APK in $FLUTTER_APK_DIR — building once…"
      flutter build apk --debug --target-platform=android-arm64
      APK="$(resolve_debug_apk)"
    fi
    adb_install "$SERIAL" "$APK"
    launch_app "$SERIAL"
    echo "Installed. For hot reload: flutter attach -d $SERIAL"
    ;;
  install)
    flutter build apk --debug --target-platform=android-arm64
    APK="$(resolve_debug_apk)"
    adb_install "$SERIAL" "$APK"
    launch_app "$SERIAL"
    echo "Done. Hot reload: flutter attach -d $SERIAL"
    ;;
  run)
    # Interactive session with hot reload (r / R / q).
    exec flutter run -d "$SERIAL" --debug
    ;;
esac
