#!/usr/bin/env bash
set -euo pipefail

CHAT="新技术讨论"
SAFE=0
VERBOSE=0
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNNER="${SCRIPT_DIR}/watch_wechat_chat.sh"
PYWXDUMP_ROOT="/home/ivan/github/PyWxDump"
SELFTEST_ID="wechat-chat-watch-$(date +%Y%m%d-%H%M%S)"
WATCH_LOG="$(mktemp -t wechat-chat-watch-selftest.XXXXXX.log)"
WATCH_PID=""

usage() {
  cat <<'EOF'
用法:
  selftest.sh [--chat CHAT] [--safe] [--verbose]
EOF
}

cleanup() {
  if [[ -n "${WATCH_PID}" ]] && kill -0 "${WATCH_PID}" >/dev/null 2>&1; then
    kill "${WATCH_PID}" >/dev/null 2>&1 || true
    wait "${WATCH_PID}" >/dev/null 2>&1 || true
  fi
}

trap cleanup EXIT

log() {
  printf '[selftest][wechat-chat-watch] %s\n' "$*"
}

run() {
  if [[ "${VERBOSE}" -eq 1 ]]; then
    printf '+'
    printf ' %q' "$@"
    printf '\n'
  fi
  "$@"
}

send_text() {
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
  if [[ ! -d "${PYWXDUMP_ROOT}" ]]; then
    log "safe skip: PyWxDump not found at ${PYWXDUMP_ROOT}"
    exit 0
  fi
  run "${RUNNER}" --target "${CHAT}" --format text --no-link-docs --no-image-analysis --no-video-analysis --no-voice-asr --print-only
  log "safe 模式完成"
  exit 0
fi

timeout 45s "${RUNNER}" --target "${CHAT}" --format text --no-link-docs --no-image-analysis --no-video-analysis --no-voice-asr >"${WATCH_LOG}" 2>&1 &
WATCH_PID=$!
sleep 5

TRIGGER_TEXT="[SELFTEST][wechat-chat-watch][${SELFTEST_ID}] 监听链路验证"
send_text "${TRIGGER_TEXT}"

for _ in $(seq 1 20); do
  if grep -Fq "${TRIGGER_TEXT}" "${WATCH_LOG}"; then
    send_text "[SELFTEST][wechat-chat-watch][${SELFTEST_ID}] 已在 watcher 输出中捕获触发消息"
    log "watch 命中，日志=${WATCH_LOG}"
    exit 0
  fi
  sleep 1
done

log "watch 日志未捕获触发消息"
cat "${WATCH_LOG}" >&2
exit 1
