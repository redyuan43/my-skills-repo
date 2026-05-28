#!/usr/bin/env bash
set -euo pipefail

CHAT="新技术讨论"
SAFE=0
VERBOSE=0
SEND_VIA="pywxdump"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNNER="${SCRIPT_DIR}/send_wechat_file.sh"
SELFTEST_ID="wechat-send-file-$(date +%Y%m%d-%H%M%S)"
WORK_DIR="$(mktemp -d -t wechat-send-file-selftest.XXXXXX)"
DISPLAY_VALUE="${DISPLAY:-:0}"
XAUTHORITY_VALUE="${XAUTHORITY:-/run/user/1000/gdm/Xauthority}"

usage() {
  cat <<'EOF'
用法:
  selftest.sh [--chat CHAT] [--send-via MODE] [--safe] [--verbose]
EOF
}

cleanup() {
  rm -rf "${WORK_DIR}"
}

trap cleanup EXIT

log() {
  printf '[selftest][wechat-send-file] %s\n' "$*"
}

run() {
  if [[ "${VERBOSE}" -eq 1 ]]; then
    printf '+'
    printf ' %q' "$@"
    printf '\n'
  fi
  "$@"
}

make_test_file() {
  cat >"${WORK_DIR}/wechat-send-file-selftest.md" <<EOF
# ${SELFTEST_ID}

- 目标会话: ${CHAT}
- 场景: 真实发送本地文件到微信群
- 时间: $(date '+%F %T')
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --chat) CHAT="$2"; shift 2 ;;
    --send-via) SEND_VIA="$2"; shift 2 ;;
    --safe) SAFE=1; shift ;;
    --verbose) VERBOSE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "未知参数: $1" >&2; usage >&2; exit 2 ;;
  esac
done

make_test_file
log "selftest_id=${SELFTEST_ID}"
log "chat=${CHAT}"
log "send_via=${SEND_VIA}"
run "${RUNNER}" --help >/dev/null

if [[ "${SAFE}" -eq 1 ]]; then
  if [[ "${SEND_VIA}" == "pywxdump" && ! -x "/home/ivan/github/PyWxDump/.venv/bin/python" ]]; then
    log "safe skip: PyWxDump python not found"
    exit 0
  fi
  mkdir -p "${WORK_DIR}/documents"
  cp "${WORK_DIR}/wechat-send-file-selftest.md" "${WORK_DIR}/documents/demo.txt"
  run "${RUNNER}" --chat "${CHAT}" --send-via "${SEND_VIA}" --display "${DISPLAY_VALUE}" --xauthority "${XAUTHORITY_VALUE}" --path "${WORK_DIR}/wechat-send-file-selftest.md" --print-only
  run "${RUNNER}" --chat "${CHAT}" --send-via "${SEND_VIA}" --display "${DISPLAY_VALUE}" --xauthority "${XAUTHORITY_VALUE}" --documents-root "${WORK_DIR}/documents" --print-only
  log "safe 模式完成"
  exit 0
fi

run "${RUNNER}" --chat "${CHAT}" --send-via "${SEND_VIA}" --display "${DISPLAY_VALUE}" --xauthority "${XAUTHORITY_VALUE}" --path "${WORK_DIR}/wechat-send-file-selftest.md"
log "live 模式完成 path=${WORK_DIR}/wechat-send-file-selftest.md"
