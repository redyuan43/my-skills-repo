#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="/home/ivan/github/PyWxDump"
PRINT_ONLY=0

usage() {
  cat <<'EOF'
用法:
  watch_wechat_chat.sh --target "群名"
  watch_wechat_chat.sh --all-chats [--format json] [--webhook URL]
  watch_wechat_chat.sh --target "群名" [--print-only]

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
forwarded_args=()
for arg in "$@"; do
  if [[ "${arg}" == "--print-only" ]]; then
    PRINT_ONLY=1
    continue
  fi
  forwarded_args+=("${arg}")
done

cmd=(python3 "tools/linux_wx_chat_daemon.py" watch "${forwarded_args[@]}")
printf 'Resolved command:'
printf ' %q' "${cmd[@]}"
printf '\n'
if [[ "${PRINT_ONLY}" -eq 1 ]]; then
  exit 0
fi
"${cmd[@]}"
