#!/usr/bin/env bash
set -euo pipefail

CHAT="新技术讨论"
SAFE=0
VERBOSE=0
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNNER="${SCRIPT_DIR}/summarize_wechat_chat.sh"
PYWXDUMP_ROOT="/home/ivan/github/PyWxDump"
SELFTEST_ID="wechat-chat-summary-$(date +%Y%m%d-%H%M%S)"
WORK_DIR="$(mktemp -d -t wechat-chat-summary-selftest.XXXXXX)"
PORT="$(python3 - <<'PY'
import socket
s = socket.socket()
s.bind(("127.0.0.1", 0))
print(s.getsockname()[1])
s.close()
PY
)"
SERVER_PID=""

usage() {
  cat <<'EOF'
用法:
  selftest.sh [--chat CHAT] [--safe] [--verbose]
EOF
}

cleanup() {
  if [[ -n "${SERVER_PID}" ]] && kill -0 "${SERVER_PID}" >/dev/null 2>&1; then
    kill "${SERVER_PID}" >/dev/null 2>&1 || true
    wait "${SERVER_PID}" >/dev/null 2>&1 || true
  fi
  rm -rf "${WORK_DIR}"
}

trap cleanup EXIT

log() {
  printf '[selftest][wechat-chat-summary] %s\n' "$*"
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
  local response_file="${WORK_DIR}/summary_response.txt"
  cat >"${response_file}" <<EOF
# ${SELFTEST_ID}

- 已覆盖“新技术讨论”里的 selftest 触发消息
- 这是本地 stub summary server 返回的固定摘要
EOF
  SELFTEST_WORK_DIR="${WORK_DIR}" SELFTEST_PORT="${PORT}" python3 - <<'PY' >"${WORK_DIR}/summary_server.log" 2>&1 &
import json
import os
from http.server import BaseHTTPRequestHandler, HTTPServer

work_dir = os.environ["SELFTEST_WORK_DIR"]
port = int(os.environ["SELFTEST_PORT"])
response_path = os.path.join(work_dir, "summary_response.txt")

class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        length = int(self.headers.get("Content-Length", "0"))
        self.rfile.read(length)
        with open(response_path, "r", encoding="utf-8") as fh:
            content = fh.read()
        payload = {
            "id": "selftest-chatcmpl",
            "object": "chat.completion",
            "choices": [
                {
                    "index": 0,
                    "message": {"role": "assistant", "content": content},
                    "finish_reason": "stop",
                }
            ],
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

TODAY="$(date +%F)"
if [[ "${SAFE}" -eq 1 ]]; then
  run "${RUNNER}" --target "${CHAT}" --since "${TODAY}" --until "${TODAY}" --limit 20 --send-back --print-only
  log "safe 模式完成"
  exit 0
fi

start_stub_server
send_text "[SELFTEST][wechat-chat-summary][${SELFTEST_ID}] 第一条摘要触发消息"
send_text "[SELFTEST][wechat-chat-summary][${SELFTEST_ID}] 第二条摘要触发消息"
run "${RUNNER}" --target "${CHAT}" --since "${TODAY}" --until "${TODAY}" --limit 50 --no-doc-links --send-back --output-dir "${WORK_DIR}/summary" --summary-base-url "http://127.0.0.1:${PORT}/v1" --summary-model "selftest-summary"
DOC_PATH="$(find "${WORK_DIR}/summary" -name 'document.md' | head -n 1)"
if [[ -z "${DOC_PATH}" || ! -f "${DOC_PATH}" ]]; then
  echo "未找到 summary document.md" >&2
  exit 1
fi
send_text "[SELFTEST][wechat-chat-summary][${SELFTEST_ID}] 已生成总结并回发，document=${DOC_PATH}"
log "document=${DOC_PATH}"
