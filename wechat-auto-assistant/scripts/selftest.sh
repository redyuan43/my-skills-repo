#!/usr/bin/env bash
set -euo pipefail

CHAT="新技术讨论"
SAFE=0
VERBOSE=0
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNNER="${SCRIPT_DIR}/run_wechat_auto_assistant.sh"
PYWXDUMP_ROOT="/home/ivan/github/PyWxDump"
SELFTEST_ID="wechat-auto-assistant-$(date +%Y%m%d-%H%M%S)"
WORK_DIR="$(mktemp -d -t wechat-auto-assistant-selftest.XXXXXX)"
PORT="$(python3 - <<'PY'
import socket
s = socket.socket()
s.bind(("127.0.0.1", 0))
print(s.getsockname()[1])
s.close()
PY
)"
SERVER_PID=""
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
  if [[ -n "${SERVER_PID}" ]] && kill -0 "${SERVER_PID}" >/dev/null 2>&1; then
    kill "${SERVER_PID}" >/dev/null 2>&1 || true
    wait "${SERVER_PID}" >/dev/null 2>&1 || true
  fi
  rm -rf "${WORK_DIR}"
}

trap cleanup EXIT

log() {
  printf '[selftest][wechat-auto-assistant] %s\n' "$*"
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

start_stub_server() {
  SELFTEST_REPLY_TEXT="[SELFTEST][wechat-auto-assistant][${SELFTEST_ID}] Assistant 自动回复成功"
  export SELFTEST_REPLY_TEXT
  export SELFTEST_PORT="${PORT}"
  python3 - <<'PY' >"${WORK_DIR}/assistant_stub.log" 2>&1 &
import json
import os
from http.server import BaseHTTPRequestHandler, HTTPServer

port = int(os.environ["SELFTEST_PORT"])
reply_text = os.environ["SELFTEST_REPLY_TEXT"]

class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        length = int(self.headers.get("Content-Length", "0"))
        self.rfile.read(length)
        payload = {
            "version": "1",
            "reply_mode": "auto_send",
            "reason": "selftest",
            "actions": [{"type": "send_text", "text": reply_text}],
        }
        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, format, *args):
        return

HTTPServer(("127.0.0.1", port), Handler).serve_forever()
PY
  SERVER_PID=$!
  sleep 1
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
  if "${RUNNER}" --target "${CHAT}" >/dev/null 2>&1; then
    echo "缺少 assistant 参数时不应成功" >&2
    exit 1
  fi
  run "${RUNNER}" --target "${CHAT}" --assistant-webhook "http://127.0.0.1:18080/assistant" --assistant-allow-chat "${CHAT}" --no-link-docs --no-image-analysis --no-video-analysis --no-voice-asr --print-only
  log "safe 模式完成"
  exit 0
fi

start_stub_server
timeout 45s "${RUNNER}" --target "${CHAT}" --assistant-webhook "http://127.0.0.1:${PORT}/assistant" --assistant-allow-chat "${CHAT}" --no-link-docs --no-image-analysis --no-video-analysis --no-voice-asr >"${WORK_DIR}/assistant_watch.log" 2>&1 &
WATCH_PID=$!
sleep 5

TRIGGER_TEXT="[SELFTEST][wechat-auto-assistant][${SELFTEST_ID}] 触发 assistant 自动回复"
send_text "${TRIGGER_TEXT}"

for _ in $(seq 1 20); do
  if grep -Fq "Assistant 动作" "${WORK_DIR}/assistant_watch.log" || grep -Fq "${SELFTEST_ID}" "${WORK_DIR}/assistant_watch.log"; then
    send_text "[SELFTEST][wechat-auto-assistant][${SELFTEST_ID}] watcher 已执行 assistant 动作"
    log "assistant 动作已执行"
    exit 0
  fi
  sleep 1
done

echo "assistant selftest 未在日志中观测到动作执行" >&2
cat "${WORK_DIR}/assistant_watch.log" >&2
exit 1
