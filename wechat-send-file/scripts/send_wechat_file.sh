#!/usr/bin/env bash
set -euo pipefail

CHAT=""
FILE_PATH=""
ALLOW_JPEG=0
PRINT_ONLY=0
DOCS_ROOT="${HOME}/Documents"
LEGACY_CONFIG_PATH=""
LEGACY_APP_ROOT=""
PYWXDUMP_ROOT="${PYWXDUMP_ROOT:-/home/ivan/github/PyWxDump}"
DISPLAY_VALUE="${WECHAT_X11_DISPLAY:-${DISPLAY:-:0}}"
XAUTHORITY_VALUE="${WECHAT_X11_XAUTHORITY:-${XAUTHORITY:-/run/user/1000/gdm/Xauthority}}"
WINDOW_MODE="${WECHAT_SEND_WINDOW_MODE:-standalone}"
SEND_STEP_DELAY_MS="${WECHAT_SEND_STEP_DELAY_MS:-220}"
SEND_PASTE_SETTLE_MS="${WECHAT_SEND_PASTE_SETTLE_MS:-320}"
POST_SEND_DELAY_MS="${WECHAT_SEND_POST_DELAY_MS:-1800}"
SEND_TIMEOUT="${WECHAT_SEND_TIMEOUT:-30}"
SEND_GUI_COUNTDOWN_SECONDS="${WECHAT_SEND_GUI_COUNTDOWN_SECONDS:-1}"
SEND_GUI_NOTIFY_TIMEOUT_MS="${WECHAT_SEND_GUI_NOTIFY_TIMEOUT_MS:-4000}"
NO_SEND_GUI_PROMPTS=0

usage() {
  cat <<'EOF'
Usage:
  send_wechat_file.sh --chat CHAT [--path FILE]
  send_wechat_file.sh --chat CHAT [--allow-jpeg] [--print-only]

Options:
  --chat CHAT         WeChat chat title to send to.
  --path FILE         Absolute path of a local file to send.
  --allow-jpeg        Allow jpg/jpeg when auto-picking from Documents.
  --documents-root D  Override the search root. Default: ~/Documents
  --window-mode MODE  Window mode: standalone | main | auto. Default: standalone
  --send-gui-countdown-seconds N
                     Countdown seconds before GUI control. Default: 1
  --send-gui-notify-timeout-ms N
                     GUI result prompt timeout in milliseconds. Default: 4000
  --no-send-gui-prompts
                     Disable GUI countdown/result prompts.
  --config PATH       Legacy compatibility option. Ignored.
  --app-root PATH     Legacy compatibility option. Ignored.
  --pywxdump-root P   Override the local PyWxDump project path.
  --display VALUE     Override the X11 DISPLAY used for sending.
  --xauthority PATH   Override the XAUTHORITY used for sending.
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
    --window-mode)
      WINDOW_MODE="${2:-}"
      shift 2
      ;;
    --send-gui-countdown-seconds)
      SEND_GUI_COUNTDOWN_SECONDS="${2:-}"
      shift 2
      ;;
    --send-gui-notify-timeout-ms)
      SEND_GUI_NOTIFY_TIMEOUT_MS="${2:-}"
      shift 2
      ;;
    --no-send-gui-prompts)
      NO_SEND_GUI_PROMPTS=1
      shift
      ;;
    --config)
      LEGACY_CONFIG_PATH="${2:-}"
      shift 2
      ;;
    --app-root)
      LEGACY_APP_ROOT="${2:-}"
      shift 2
      ;;
    --pywxdump-root)
      PYWXDUMP_ROOT="${2:-}"
      shift 2
      ;;
    --display)
      DISPLAY_VALUE="${2:-}"
      shift 2
      ;;
    --xauthority)
      XAUTHORITY_VALUE="${2:-}"
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

if [[ "${WINDOW_MODE}" != "standalone" && "${WINDOW_MODE}" != "main" && "${WINDOW_MODE}" != "auto" ]]; then
  echo "--window-mode must be one of: standalone, main, auto" >&2
  exit 2
fi

if ! [[ "${SEND_GUI_COUNTDOWN_SECONDS}" =~ ^[0-9]+$ ]]; then
  echo "--send-gui-countdown-seconds must be a non-negative integer" >&2
  exit 2
fi

if ! [[ "${SEND_GUI_NOTIFY_TIMEOUT_MS}" =~ ^[0-9]+$ ]]; then
  echo "--send-gui-notify-timeout-ms must be a non-negative integer" >&2
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

if [[ ! -f "${PYWXDUMP_ROOT}/tools/linux_wx_chat_daemon.py" ]]; then
  echo "PyWxDump not found: ${PYWXDUMP_ROOT}" >&2
  exit 1
fi

CMD=(
  python3
  "${PYWXDUMP_ROOT}/tools/linux_wx_chat_daemon.py"
  send-file
  --target
  "${CHAT}"
  --window-mode
  "${WINDOW_MODE}"
  --path
  "${FILE_PATH}"
  --post-send-delay-ms
  "${POST_SEND_DELAY_MS}"
  --send-timeout
  "${SEND_TIMEOUT}"
  --send-step-delay-ms
  "${SEND_STEP_DELAY_MS}"
  --send-paste-settle-ms
  "${SEND_PASTE_SETTLE_MS}"
  --send-gui-countdown-seconds
  "${SEND_GUI_COUNTDOWN_SECONDS}"
  --send-gui-notify-timeout-ms
  "${SEND_GUI_NOTIFY_TIMEOUT_MS}"
  --display
  "${DISPLAY_VALUE}"
  --xauthority
  "${XAUTHORITY_VALUE}"
)

if [[ "${NO_SEND_GUI_PROMPTS}" -eq 1 ]]; then
  CMD+=(--no-send-gui-prompts)
fi

echo "Resolved chat: ${CHAT}"
echo "Resolved file: ${FILE_PATH}"
echo "Resolved PyWxDump: ${PYWXDUMP_ROOT}"
echo "Resolved window mode: ${WINDOW_MODE}"
echo "Resolved display: ${DISPLAY_VALUE}"
echo "Resolved xauthority: ${XAUTHORITY_VALUE}"
echo "Resolved GUI countdown seconds: ${SEND_GUI_COUNTDOWN_SECONDS}"
echo "Resolved GUI notify timeout ms: ${SEND_GUI_NOTIFY_TIMEOUT_MS}"
if [[ "${NO_SEND_GUI_PROMPTS}" -eq 1 ]]; then
  echo "Resolved GUI prompts: disabled"
fi
if [[ -n "${LEGACY_CONFIG_PATH}" ]]; then
  echo "Ignored legacy --config: ${LEGACY_CONFIG_PATH}"
fi
if [[ -n "${LEGACY_APP_ROOT}" ]]; then
  echo "Ignored legacy --app-root: ${LEGACY_APP_ROOT}"
fi

if [[ "${PRINT_ONLY}" -eq 1 ]]; then
  printf 'Resolved command:'
  printf ' %q' "${CMD[@]}"
  printf '\n'
  exit 0
fi

OUTPUT_FILE="$(mktemp -t wechat-send-file-output.XXXXXX)"
cleanup_output() {
  rm -f "${OUTPUT_FILE}"
}
trap cleanup_output EXIT

set +e
"${CMD[@]}" | tee "${OUTPUT_FILE}"
STATUS=${PIPESTATUS[0]}
set -e

python3 - "${OUTPUT_FILE}" <<'PY'
import json
import sys

path = sys.argv[1]
lines = []
with open(path, "r", encoding="utf-8") as fp:
    lines = [line.rstrip("\n") for line in fp]

payload = None
for line in reversed(lines):
    text = line.strip()
    if not text.startswith("{") or not text.endswith("}"):
        continue
    try:
        payload = json.loads(text)
        break
    except json.JSONDecodeError:
        continue

if payload is not None:
    restore_action = payload.get("restore_action", "none")
    status = payload.get("status", "")
    matched_local_id = payload.get("matched_local_id")
    print(f"[skill][wechat-send-file] status={status} restore_action={restore_action} matched_local_id={matched_local_id}")
PY

exit "${STATUS}"
