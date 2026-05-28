#!/usr/bin/env bash
set -euo pipefail

CHAT="新技术讨论"
SAFE=0
VERBOSE=0
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNNER="${SCRIPT_DIR}/wechat_link_to_doc.sh"
PYWXDUMP_ROOT="/home/ivan/github/PyWxDump"
SELFTEST_ID="wechat-link-to-doc-$(date +%Y%m%d-%H%M%S)"
WORK_DIR="$(mktemp -d -t wechat-link-to-doc-selftest.XXXXXX)"
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
  printf '[selftest][wechat-link-to-doc] %s\n' "$*"
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

start_stub_site() {
  mkdir -p "${WORK_DIR}/site"
  cat >"${WORK_DIR}/site/index.html" <<EOF
<!doctype html>
<html lang="zh-CN">
<body>
  <h1>${SELFTEST_ID}</h1>
  <p>这是 link-to-doc selftest 的本地页面。</p>
</body>
</html>
EOF
  python3 -m http.server "${PORT}" --bind 127.0.0.1 --directory "${WORK_DIR}/site" >"${WORK_DIR}/site.log" 2>&1 &
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

URL="http://127.0.0.1:${PORT}/index.html"
log "selftest_id=${SELFTEST_ID}"
log "chat=${CHAT}"
run "${RUNNER}" --help >/dev/null

if [[ "${SAFE}" -eq 1 ]]; then
  if [[ ! -d "${PYWXDUMP_ROOT}" ]]; then
    log "safe skip: PyWxDump not found at ${PYWXDUMP_ROOT}"
    exit 0
  fi
  run "${RUNNER}" --url "${URL}" --output-dir "${WORK_DIR}/doc" --doc-type generic_web --chat-name "${CHAT}" --print-only
  log "safe 模式完成"
  exit 0
fi

start_stub_site
send_text "[SELFTEST][wechat-link-to-doc][${SELFTEST_ID}] 测试链接 ${URL}"
run "${RUNNER}" --url "${URL}" --output-dir "${WORK_DIR}/doc" --doc-type generic_web --chat-name "${CHAT}"
DOC_PATH="$(find "${WORK_DIR}/doc" -name 'document.md' | head -n 1)"
if [[ -z "${DOC_PATH}" || ! -f "${DOC_PATH}" ]]; then
  echo "未找到 document.md" >&2
  exit 1
fi
send_text "[SELFTEST][wechat-link-to-doc][${SELFTEST_ID}] 已完成文档化，document=${DOC_PATH}"
log "document=${DOC_PATH}"
