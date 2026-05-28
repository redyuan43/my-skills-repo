#!/usr/bin/env bash
set -euo pipefail

CHAT="新技术讨论"
SAFE=0
VERBOSE=0
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNNER="${SCRIPT_DIR}/send_wechat_camera_roll.py"
SELFTEST_ID="wechat-send-camera-roll-$(date +%Y%m%d-%H%M%S)"
WORK_DIR="$(mktemp -d -t wechat-send-camera-roll-selftest.XXXXXX)"

usage() {
  cat <<'EOF'
用法:
  selftest.sh [--chat CHAT] [--safe] [--verbose]
EOF
}

cleanup() {
  rm -rf "${WORK_DIR}"
}

trap cleanup EXIT

log() {
  printf '[selftest][wechat-send-camera-roll] %s\n' "$*"
}

run() {
  if [[ "${VERBOSE}" -eq 1 ]]; then
    printf '+'
    printf ' %q' "$@"
    printf '\n'
  fi
  "$@"
}

make_test_images() {
  python3 - "${WORK_DIR}" "${SELFTEST_ID}" <<'PY'
import base64
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
selftest_id = sys.argv[2]
png = base64.b64decode("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO2W7S8AAAAASUVORK5CYII=")
for index in range(1, 3):
    path = root / f"{index:02d}-{selftest_id}.png"
    path.write_bytes(png)
PY
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

make_test_images
log "selftest_id=${SELFTEST_ID}"
log "chat=${CHAT}"
run python3 "${RUNNER}" --help >/dev/null

if [[ "${SAFE}" -eq 1 ]]; then
  if ! command -v xinput >/dev/null 2>&1; then
    log "safe skip: xinput not found"
    exit 0
  fi
  run python3 "${RUNNER}" --chat "${CHAT}" --dir "${WORK_DIR}" --start-after "01-${SELFTEST_ID}.png" --limit 1 --print-only
  log "safe 模式完成"
  exit 0
fi

run python3 "${RUNNER}" --chat "${CHAT}" --dir "${WORK_DIR}" --limit 1
log "live 模式完成 dir=${WORK_DIR}"
