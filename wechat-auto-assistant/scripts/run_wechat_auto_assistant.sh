#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="/home/ivan/github/PyWxDump"
HAS_WEBHOOK=0
HAS_ALLOW=0
PRINT_ONLY=0

usage() {
  cat <<'EOF'
用法:
  run_wechat_auto_assistant.sh --target "群名" --assistant-webhook URL --assistant-allow-chat "群名" [--assistant-allow-chat "联系人"] [--print-only]

说明:
  其余参数会原样透传给 tools/linux_wx_chat_daemon.py watch。
EOF
}

if [[ $# -eq 0 ]]; then
  usage
  exit 2
fi

for ((i=1; i<=$#; i++)); do
  arg="${!i}"
  if [[ "${arg}" == "--assistant-webhook" ]]; then
    HAS_WEBHOOK=1
  elif [[ "${arg}" == "--assistant-allow-chat" ]]; then
    HAS_ALLOW=1
  elif [[ "${arg}" == "--print-only" ]]; then
    PRINT_ONLY=1
  elif [[ "${arg}" == "-h" || "${arg}" == "--help" ]]; then
    usage
    exit 0
  fi
done

if [[ "${HAS_WEBHOOK}" -ne 1 || "${HAS_ALLOW}" -ne 1 ]]; then
  echo "必须同时提供 --assistant-webhook 和至少一个 --assistant-allow-chat" >&2
  usage
  exit 2
fi

if [[ ! -d "${REPO_ROOT}" ]]; then
  echo "未找到 PyWxDump 仓库: ${REPO_ROOT}" >&2
  exit 1
fi

cd "${REPO_ROOT}"
forwarded_args=()
allowlisted=()
assistant_webhook=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --print-only)
      shift
      ;;
    --assistant-webhook)
      assistant_webhook="$2"
      forwarded_args+=("$1" "$2")
      shift 2
      ;;
    --assistant-allow-chat)
      allowlisted+=("$2")
      forwarded_args+=("$1" "$2")
      shift 2
      ;;
    *)
      forwarded_args+=("$1")
      shift
      ;;
  esac
done

cmd=(python3 "tools/linux_wx_chat_daemon.py" watch "${forwarded_args[@]}")
echo "Resolved assistant webhook: ${assistant_webhook}"
printf 'Resolved allowlist:'
printf ' %q' "${allowlisted[@]}"
printf '\n'
printf 'Resolved command:'
printf ' %q' "${cmd[@]}"
printf '\n'
if [[ "${PRINT_ONLY}" -eq 1 ]]; then
  exit 0
fi
"${cmd[@]}"
