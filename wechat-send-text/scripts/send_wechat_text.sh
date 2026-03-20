#!/usr/bin/env bash
set -euo pipefail

CHAT=""
TEXT=""
PRINT_ONLY=0
PYWXDUMP_ROOT="${PYWXDUMP_ROOT:-${HOME}/github/PyWxDump}"
WINDOW_CLASS="${WECHAT_WINDOW_CLASS:-wechat}"
DISPLAY_VALUE="${WECHAT_X11_DISPLAY:-${DISPLAY:-:0}}"
XAUTHORITY_VALUE="${WECHAT_X11_XAUTHORITY:-${XAUTHORITY:-/run/user/1000/gdm/Xauthority}}"
WINDOW_MODE="${WECHAT_SEND_WINDOW_MODE:-standalone}"
PYTHON_BIN="${WECHAT_PYTHON_BIN:-${PYWXDUMP_ROOT}/.venv/bin/python}"
SEND_STEP_DELAY_MS="${WECHAT_SEND_STEP_DELAY_MS:-220}"
SEND_PASTE_SETTLE_MS="${WECHAT_SEND_PASTE_SETTLE_MS:-320}"
POST_SEND_DELAY_MS="${WECHAT_SEND_POST_DELAY_MS:-1800}"
SEND_TIMEOUT="${WECHAT_SEND_TIMEOUT:-30}"
SEND_GUI_COUNTDOWN_SECONDS="${WECHAT_SEND_GUI_COUNTDOWN_SECONDS:-1}"
SEND_GUI_NOTIFY_TIMEOUT_MS="${WECHAT_SEND_GUI_NOTIFY_TIMEOUT_MS:-4000}"
MAIN_WINDOW_VISION_BASE_URL="${WECHAT_MAIN_WINDOW_VISION_BASE_URL:-}"
MAIN_WINDOW_VISION_MODEL="${WECHAT_MAIN_WINDOW_VISION_MODEL:-}"
MAIN_WINDOW_VISION_API_KEY_ENV="${WECHAT_MAIN_WINDOW_VISION_API_KEY_ENV:-}"
MAIN_WINDOW_VISION_TIMEOUT_SECONDS="${WECHAT_MAIN_WINDOW_VISION_TIMEOUT_SECONDS:-}"
MAIN_WINDOW_VISION_THINKING_BUDGET_TOKENS="${WECHAT_MAIN_WINDOW_VISION_THINKING_BUDGET_TOKENS:-}"
MAIN_WINDOW_VISION_DISABLE_THINKING=0
NO_SEND_GUI_PROMPTS=0

usage() {
  cat <<'EOF'
Usage:
  send_wechat_text.sh --chat CHAT --text TEXT

Options:
  --chat CHAT         WeChat chat title to send to.
  --text TEXT         Text content to send.
  --window-class CLS  X11 微信窗口 class（默认: wechat）
  --window-mode MODE  Window mode: standalone | main | auto. Default: standalone
  --send-gui-countdown-seconds N
                     Countdown seconds before GUI control. Default: 1
  --send-gui-notify-timeout-ms N
                     GUI result prompt timeout in milliseconds. Default: 4000
  --main-window-vision-base-url URL
                     Override main-window vision base URL.
  --main-window-vision-model MODEL
                     Override main-window vision model.
  --main-window-vision-api-key-env ENV
                     Override main-window vision API key env name.
  --main-window-vision-timeout-seconds N
                     Override main-window vision timeout in seconds.
  --main-window-vision-thinking-budget-tokens N
                     Override main-window vision thinking budget tokens.
  --main-window-vision-disable-thinking
                     Disable thinking for main-window vision requests.
  --no-send-gui-prompts
                     Disable GUI countdown/result prompts.
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
    --text)
      TEXT="${2:-}"
      shift 2
      ;;
    --window-mode)
      WINDOW_MODE="${2:-}"
      shift 2
      ;;
    --window-class)
      WINDOW_CLASS="${2:-}"
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
    --main-window-vision-base-url)
      MAIN_WINDOW_VISION_BASE_URL="${2:-}"
      shift 2
      ;;
    --main-window-vision-model)
      MAIN_WINDOW_VISION_MODEL="${2:-}"
      shift 2
      ;;
    --main-window-vision-api-key-env)
      MAIN_WINDOW_VISION_API_KEY_ENV="${2:-}"
      shift 2
      ;;
    --main-window-vision-timeout-seconds)
      MAIN_WINDOW_VISION_TIMEOUT_SECONDS="${2:-}"
      shift 2
      ;;
    --main-window-vision-thinking-budget-tokens)
      MAIN_WINDOW_VISION_THINKING_BUDGET_TOKENS="${2:-}"
      shift 2
      ;;
    --main-window-vision-disable-thinking)
      MAIN_WINDOW_VISION_DISABLE_THINKING=1
      shift
      ;;
    --no-send-gui-prompts)
      NO_SEND_GUI_PROMPTS=1
      shift
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

if [[ -z "${TEXT}" ]]; then
  echo "--text is required" >&2
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

if [[ -z "${WINDOW_CLASS}" ]]; then
  echo "--window-class is required" >&2
  exit 2
fi

if [[ -n "${WECHAT_PYTHON_BIN:-}" ]]; then
  PYTHON_BIN="${WECHAT_PYTHON_BIN}"
else
  PYTHON_BIN="${PYWXDUMP_ROOT}/.venv/bin/python"
fi

if [[ ! -x "${PYTHON_BIN}" ]]; then
  PYTHON_BIN="$(command -v python3 || true)"
fi
if [[ -z "${PYTHON_BIN}" || ! -x "${PYTHON_BIN}" ]]; then
  PYTHON_BIN="python3"
fi
if ! command -v "${PYTHON_BIN}" >/dev/null 2>&1; then
  echo "Python not found" >&2
  exit 1
fi

RESOLVED_CHAT="${CHAT}"

if [[ -n "${MAIN_WINDOW_VISION_TIMEOUT_SECONDS}" ]] && ! [[ "${MAIN_WINDOW_VISION_TIMEOUT_SECONDS}" =~ ^[0-9]+$ ]]; then
  echo "--main-window-vision-timeout-seconds must be a non-negative integer" >&2
  exit 2
fi

if [[ -n "${MAIN_WINDOW_VISION_THINKING_BUDGET_TOKENS}" ]] && ! [[ "${MAIN_WINDOW_VISION_THINKING_BUDGET_TOKENS}" =~ ^[0-9]+$ ]]; then
  echo "--main-window-vision-thinking-budget-tokens must be a non-negative integer" >&2
  exit 2
fi

if [[ ! -f "${PYWXDUMP_ROOT}/tools/linux_wx_chat_daemon.py" ]]; then
  echo "PyWxDump not found: ${PYWXDUMP_ROOT}" >&2
  exit 1
fi

CMD=(
  "${PYTHON_BIN}"
  "${PYWXDUMP_ROOT}/tools/linux_wx_chat_daemon.py"
  send-text
  --target
  "${RESOLVED_CHAT}"
  --window-mode
  "${WINDOW_MODE}"
  --window-class
  "${WINDOW_CLASS}"
  --text
  "${TEXT}"
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
  --auto-resolve-target
  --post-send-force-minimize
)

if [[ "${NO_SEND_GUI_PROMPTS}" -eq 1 ]]; then
  CMD+=(--no-send-gui-prompts)
fi

if [[ -n "${MAIN_WINDOW_VISION_BASE_URL}" ]]; then
  CMD+=(--main-window-vision-base-url "${MAIN_WINDOW_VISION_BASE_URL}")
fi

if [[ -n "${MAIN_WINDOW_VISION_MODEL}" ]]; then
  CMD+=(--main-window-vision-model "${MAIN_WINDOW_VISION_MODEL}")
fi

if [[ -n "${MAIN_WINDOW_VISION_API_KEY_ENV}" ]]; then
  CMD+=(--main-window-vision-api-key-env "${MAIN_WINDOW_VISION_API_KEY_ENV}")
fi

if [[ -n "${MAIN_WINDOW_VISION_TIMEOUT_SECONDS}" ]]; then
  CMD+=(--main-window-vision-timeout-seconds "${MAIN_WINDOW_VISION_TIMEOUT_SECONDS}")
fi

if [[ -n "${MAIN_WINDOW_VISION_THINKING_BUDGET_TOKENS}" ]]; then
  CMD+=(--main-window-vision-thinking-budget-tokens "${MAIN_WINDOW_VISION_THINKING_BUDGET_TOKENS}")
fi

if [[ "${MAIN_WINDOW_VISION_DISABLE_THINKING}" -eq 1 ]]; then
  CMD+=(--main-window-vision-disable-thinking)
fi

echo "Resolved chat: ${RESOLVED_CHAT}"
if [[ "${RESOLVED_CHAT}" == "${CHAT}" ]]; then
  echo "Original chat query: ${CHAT}"
fi
echo "Resolved text length: ${#TEXT}"
echo "Resolved PyWxDump: ${PYWXDUMP_ROOT}"
echo "Resolved window mode: ${WINDOW_MODE}"
echo "Resolved display: ${DISPLAY_VALUE}"
echo "Resolved xauthority: ${XAUTHORITY_VALUE}"
echo "Resolved GUI countdown seconds: ${SEND_GUI_COUNTDOWN_SECONDS}"
echo "Resolved GUI notify timeout ms: ${SEND_GUI_NOTIFY_TIMEOUT_MS}"
if [[ -n "${MAIN_WINDOW_VISION_BASE_URL}" ]]; then
  echo "Resolved main-window vision base URL: ${MAIN_WINDOW_VISION_BASE_URL}"
fi
if [[ -n "${MAIN_WINDOW_VISION_MODEL}" ]]; then
  echo "Resolved main-window vision model: ${MAIN_WINDOW_VISION_MODEL}"
fi
if [[ -n "${MAIN_WINDOW_VISION_API_KEY_ENV}" ]]; then
  echo "Resolved main-window vision API key env: ${MAIN_WINDOW_VISION_API_KEY_ENV}"
fi
if [[ -n "${MAIN_WINDOW_VISION_TIMEOUT_SECONDS}" ]]; then
  echo "Resolved main-window vision timeout seconds: ${MAIN_WINDOW_VISION_TIMEOUT_SECONDS}"
fi
if [[ -n "${MAIN_WINDOW_VISION_THINKING_BUDGET_TOKENS}" ]]; then
  echo "Resolved main-window vision thinking budget tokens: ${MAIN_WINDOW_VISION_THINKING_BUDGET_TOKENS}"
fi
if [[ "${MAIN_WINDOW_VISION_DISABLE_THINKING}" -eq 1 ]]; then
  echo "Resolved main-window vision thinking: disabled"
fi
if [[ "${NO_SEND_GUI_PROMPTS}" -eq 1 ]]; then
  echo "Resolved GUI prompts: disabled"
fi

if [[ "${PRINT_ONLY}" -eq 1 ]]; then
  printf 'Resolved command:'
  printf ' %q' "${CMD[@]}"
  printf '\n'
  exit 0
fi

OUTPUT_FILE="$(mktemp -t wechat-send-text-output.XXXXXX)"
cleanup_output() {
  rm -f "${OUTPUT_FILE}"
}
trap cleanup_output EXIT

set +e
"${CMD[@]}" | tee "${OUTPUT_FILE}"
STATUS=${PIPESTATUS[0]}
set -e

"${PYTHON_BIN}" - "${OUTPUT_FILE}" <<'PY'
import json
import sys

path = sys.argv[1]
payload = None
with open(path, "r", encoding="utf-8") as fp:
    lines = [line.rstrip("\n") for line in fp]

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
    print(f"[skill][wechat-send-text] status={status} restore_action={restore_action} matched_local_id={matched_local_id}")
PY

exit "${STATUS}"
