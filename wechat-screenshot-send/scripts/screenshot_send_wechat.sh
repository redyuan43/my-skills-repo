#!/usr/bin/env bash
set -euo pipefail

CHAT=""
DELAY_SECONDS=0
PRINT_ONLY=0
SCREENSHOT_DIR="${HOME}/Pictures/Screenshots"
SEND_SCRIPT="/home/dgx/github/DevToolbox/skills/wechat-send-file/scripts/send_wechat_file.sh"

usage() {
  cat <<'EOF'
Usage:
  screenshot_send_wechat.sh --chat CHAT [--delay SECONDS] [--print-only]

Options:
  --chat CHAT         Standalone WeChat window title to send to.
  --delay SECONDS     Wait before capture. Default: 0
  --print-only        Print the resolved commands without executing them.
  -h, --help          Show this help.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --chat)
      CHAT="${2:-}"
      shift 2
      ;;
    --delay)
      DELAY_SECONDS="${2:-}"
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

if ! [[ "${DELAY_SECONDS}" =~ ^[0-9]+$ ]]; then
  echo "--delay must be a non-negative integer" >&2
  exit 2
fi

if [[ ! -x "${SEND_SCRIPT}" ]]; then
  echo "Send script not found or not executable: ${SEND_SCRIPT}" >&2
  exit 1
fi

if ! command -v gnome-screenshot >/dev/null 2>&1; then
  echo "gnome-screenshot is required but not found" >&2
  exit 1
fi

mkdir -p "${SCREENSHOT_DIR}"
STAMP="$(date +%Y%m%d-%H%M%S)"
SHOT_PATH="${SCREENSHOT_DIR}/desktop-${STAMP}.png"

echo "Resolved chat: ${CHAT}"
echo "Resolved screenshot: ${SHOT_PATH}"

if [[ "${PRINT_ONLY}" -eq 1 ]]; then
  echo "Resolved capture: DISPLAY=:1 XAUTHORITY=/run/user/1000/gdm/Xauthority gnome-screenshot -f ${SHOT_PATH}"
  echo "Resolved send: ${SEND_SCRIPT} --chat ${CHAT} --path ${SHOT_PATH}"
  exit 0
fi

if [[ "${DELAY_SECONDS}" -gt 0 ]]; then
  sleep "${DELAY_SECONDS}"
fi

DISPLAY=:1 XAUTHORITY=/run/user/1000/gdm/Xauthority gnome-screenshot -f "${SHOT_PATH}"
"${SEND_SCRIPT}" --chat "${CHAT}" --path "${SHOT_PATH}"
