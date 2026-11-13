# shellcheck shell=bash
# Shared PATH for Flutter / Android SDK on this machine. Source from other scripts.

: "${ANDROID_HOME:=$HOME/Android/Sdk}"
export ANDROID_HOME
export GRADLE_USER_HOME="${GRADLE_USER_HOME:-$HOME/.gradle}"

_path_prepend() {
  case ":$PATH:" in
    *":$1:"*) ;;
    *) PATH="$1${PATH:+:$PATH}" ;;
  esac
}

_path_prepend "$ANDROID_HOME/cmake/3.22.1/bin"
_path_prepend "$ANDROID_HOME/platform-tools"
_path_prepend "$ANDROID_HOME/cmdline-tools/latest/bin"
_path_prepend "$ANDROID_HOME/emulator"
_path_prepend "$HOME/sdk/flutter/bin"
export PATH
