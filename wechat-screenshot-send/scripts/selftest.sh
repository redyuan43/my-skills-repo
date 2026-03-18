#!/usr/bin/env bash
set -euo pipefail

CHAT="新技术讨论"
SAFE=0
VERBOSE=0
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNNER="${SCRIPT_DIR}/screenshot_send_wechat.sh"
SELFTEST_ID="wechat-screenshot-send-$(date +%Y%m%d-%H%M%S)"
WORK_DIR="$(mktemp -d -t wechat-screenshot-send-selftest.XXXXXX)"
DISPLAY_VALUE="${DISPLAY:-:0}"
XAUTHORITY_VALUE="${XAUTHORITY:-/run/user/1000/gdm/Xauthority}"

usage() {
  cat <<'EOF'
用法:
  selftest.sh [--chat CHAT] [--safe] [--verbose]
EOF
}

log() {
  printf '[selftest][wechat-screenshot-send] %s\n' "$*"
}

cleanup() {
  rm -rf "${WORK_DIR}"
}

trap cleanup EXIT

run() {
  if [[ "${VERBOSE}" -eq 1 ]]; then
    printf '+'
    printf ' %q' "$@"
    printf '\n'
  fi
  "$@"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --chat) CHAT="$2"; shift 2 ;;
    --safe) SAFE=1; shift ;;
    --verbose) VERBOSE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "未知参数: $1" >&2; usage >&2; exit 2 ;;
  esac
done

log "selftest_id=${SELFTEST_ID}"
log "chat=${CHAT}"
run "${RUNNER}" --help >/dev/null

if [[ "${SAFE}" -eq 1 ]]; then
  run "${RUNNER}" --chat "${CHAT}" --display "${DISPLAY_VALUE}" --xauthority "${XAUTHORITY_VALUE}" --print-only
  log "safe 模式完成"
  exit 0
fi

run "${RUNNER}" --chat "${CHAT}" --display "${DISPLAY_VALUE}" --xauthority "${XAUTHORITY_VALUE}"
log "live 模式完成"
