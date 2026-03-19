#!/usr/bin/env bash
set -euo pipefail

CHAT="新技术讨论"
SAFE=0
VERBOSE=0
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNNER="${SCRIPT_DIR}/run_linux_wx_decrypt.sh"
PYWXDUMP_ROOT="/home/ivan/github/PyWxDump"
SELFTEST_ID="linux-wx-decrypt-$(date +%Y%m%d-%H%M%S)"

usage() {
  cat <<'EOF'
用法:
  selftest.sh [--chat CHAT] [--safe] [--verbose]
EOF
}

log() {
  printf '[selftest][linux-wx-decrypt] %s\n' "$*"
}

run() {
  if [[ "${VERBOSE}" -eq 1 ]]; then
    printf '+'
    printf ' %q' "$@"
    printf '\n'
  fi
  "$@"
}

send_receipt() {
  local text="$1"
  run python3 "${PYWXDUMP_ROOT}/tools/linux_wx_chat_daemon.py" send-text --target "${CHAT}" --text "${text}"
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
  run "${RUNNER}" --print-only --key-only
  run "${RUNNER}" --print-only
  log "safe 模式完成"
  exit 0
fi

send_receipt "[SELFTEST][linux-wx-decrypt][${SELFTEST_ID}] 开始提 key 与全量解密"
run "${RUNNER}"
send_receipt "[SELFTEST][linux-wx-decrypt][${SELFTEST_ID}] 完成 key=${HOME}/.wx_db_keys.json output=${HOME}/wx_decrypted"
log "live 模式完成"
