#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FAILURES=0

check_cmd() {
  local name="$1"
  if command -v "$name" >/dev/null 2>&1; then
    printf 'ok: command %s\n' "$name"
  else
    printf 'missing: command %s\n' "$name" >&2
    FAILURES=$(( FAILURES + 1 ))
  fi
}

check_file() {
  local path="$1"
  if [[ -e "$path" ]]; then
    printf 'ok: file %s\n' "$path"
  else
    printf 'missing: file %s\n' "$path" >&2
    FAILURES=$(( FAILURES + 1 ))
  fi
}

bash -n "${SCRIPT_DIR}/install_wechat_auto_enter.sh"
bash -n "${SCRIPT_DIR}/wechat_auto_enter.sh"
bash -n "${SCRIPT_DIR}/wechat_auto_enter_autostart.sh"
printf 'ok: shell syntax\n'

check_cmd "wechat"
check_cmd "xdotool"
check_cmd "gnome-screenshot"
check_cmd "python3"

if python3 -c "from PIL import Image" >/dev/null 2>&1; then
  printf 'ok: Pillow\n'
else
  printf 'missing: Pillow (python3 -m pip install pillow)\n' >&2
  FAILURES=$(( FAILURES + 1 ))
fi

check_file "${HOME}/Desktop/wechat_auto_enter.sh"
check_file "${HOME}/.local/bin/wechat_auto_enter_autostart.sh"
check_file "${HOME}/.config/autostart/wechat-auto-enter.desktop"

if (( FAILURES > 0 )); then
  printf 'selftest failed: %s issue(s)\n' "${FAILURES}" >&2
  exit 1
fi

printf 'selftest passed\n'
