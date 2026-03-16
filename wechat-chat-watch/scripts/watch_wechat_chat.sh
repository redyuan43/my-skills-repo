#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="/home/ivan/github/PyWxDump"

usage() {
  cat <<'EOF'
用法:
  watch_wechat_chat.sh --target "群名"
  watch_wechat_chat.sh --all-chats [--format json] [--webhook URL]

说明:
  其余参数会原样透传给 tools/linux_wx_chat_daemon.py watch。
EOF
}

if [[ $# -eq 0 ]]; then
  usage
  exit 2
fi

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ ! -d "${REPO_ROOT}" ]]; then
  echo "未找到 PyWxDump 仓库: ${REPO_ROOT}" >&2
  exit 1
fi

cd "${REPO_ROOT}"
python3 "tools/linux_wx_chat_daemon.py" watch "$@"
