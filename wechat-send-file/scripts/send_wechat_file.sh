#!/usr/bin/env bash
set -euo pipefail

CHAT=""
FILE_PATH=""
ALLOW_JPEG=0
PRINT_ONLY=0
DOCS_ROOT="${HOME}/Documents"
CONFIG_PATH="${HOME}/.config/wechat-auto-reply/config.yaml"
APP_ROOT="/home/dgx/github/DevToolbox/wechat-auto-reply"

usage() {
  cat <<'EOF'
Usage:
  send_wechat_file.sh --chat CHAT [--path FILE]
  send_wechat_file.sh --chat CHAT [--allow-jpeg] [--print-only]

Options:
  --chat CHAT         Standalone WeChat window title to send to.
  --path FILE         Absolute path of a local file to send.
  --allow-jpeg        Allow jpg/jpeg when auto-picking from Documents.
  --documents-root D  Override the search root. Default: ~/Documents
  --config PATH       Override config.yaml path.
  --print-only        Print the resolved command without sending.
  -h, --help          Show this help.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --chat)
      CHAT="${2:-}"
      shift 2
      ;;
    --path)
      FILE_PATH="${2:-}"
      shift 2
      ;;
    --allow-jpeg)
      ALLOW_JPEG=1
      shift
      ;;
    --documents-root)
      DOCS_ROOT="${2:-}"
      shift 2
      ;;
    --config)
      CONFIG_PATH="${2:-}"
      shift 2
      ;;
    --print-only)
      PRINT_ONLY=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -z "${CHAT}" ]]; then
  echo "--chat is required" >&2
  exit 2
fi

pick_file() {
  local root="$1"
  if [[ ! -d "${root}" ]]; then
    echo "Documents root not found: ${root}" >&2
    return 1
  fi

  local find_cmd=(find "${root}" -maxdepth 3 -type f)
  local selected=""

  if [[ "${ALLOW_JPEG}" -eq 0 ]]; then
    selected="$("${find_cmd[@]}" \
      ! -iname '*.jpg' ! -iname '*.jpeg' \
      | sort \
      | head -n 1)"
  fi

  if [[ -z "${selected}" ]]; then
    selected="$("${find_cmd[@]}" | sort | head -n 1)"
  fi

  if [[ -z "${selected}" ]]; then
    echo "No candidate file found under ${root}" >&2
    return 1
  fi

  printf '%s\n' "${selected}"
}

if [[ -z "${FILE_PATH}" ]]; then
  FILE_PATH="$(pick_file "${DOCS_ROOT}")"
fi

if [[ ! -f "${FILE_PATH}" ]]; then
  echo "File not found: ${FILE_PATH}" >&2
  exit 1
fi

CMD=(
  python3
  "${APP_ROOT}/main.py"
  --config
  "${CONFIG_PATH}"
  send-file
  --chat
  "${CHAT}"
  --path
  "${FILE_PATH}"
)

echo "Resolved chat: ${CHAT}"
echo "Resolved file: ${FILE_PATH}"

if [[ "${PRINT_ONLY}" -eq 1 ]]; then
  printf 'Resolved command: DISPLAY=:1 XAUTHORITY=/run/user/1000/gdm/Xauthority'
  printf ' %q' "${CMD[@]}"
  printf '\n'
  exit 0
fi

DISPLAY=:1 XAUTHORITY=/run/user/1000/gdm/Xauthority "${CMD[@]}"
