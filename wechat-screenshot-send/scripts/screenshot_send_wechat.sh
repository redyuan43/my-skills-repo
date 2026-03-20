#!/usr/bin/env bash
set -euo pipefail

CHAT=""
DELAY_SECONDS=0
PRINT_ONLY=0
CAPTURE_MODE="desktop"
HOVER_X=""
HOVER_Y=""
SCREENSHOT_DIR="${HOME}/Pictures/Screenshots"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
SEND_SCRIPT="${WECHAT_SEND_FILE_SCRIPT:-${SKILLS_ROOT}/wechat-send-file/scripts/send_wechat_file.sh}"
PYWXDUMP_ROOT="${PYWXDUMP_ROOT:-}"
SEND_CONFIG="${WECHAT_SEND_CONFIG:-}"
DISPLAY_VALUE="${WECHAT_X11_DISPLAY:-${DISPLAY:-:0}}"
XAUTHORITY_VALUE="${WECHAT_X11_XAUTHORITY:-${XAUTHORITY:-/run/user/1000/gdm/Xauthority}}"
WINDOW_MODE="${WECHAT_SEND_WINDOW_MODE:-standalone}"
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
POST_SEND_MINIMIZE=0
POST_SEND_FORCE_MINIMIZE=1
PYTHON_BIN=""

resolve_pywxdump_root() {
  local candidates=()
  local candidate=""

  if [[ -n "${PYWXDUMP_ROOT}" ]]; then
    candidates+=("${PYWXDUMP_ROOT}")
  fi
  if [[ -n "${PWD:-}" ]]; then
    candidates+=("${PWD}")
  fi
  candidates+=("${HOME}/github/PyWxDump")
  candidates+=("${HOME}/PyWxDump")
  candidates+=("/home/ivan/github/PyWxDump")

  for candidate in "${candidates[@]}"; do
    [[ -n "${candidate}" ]] || continue
    if [[ -f "${candidate}/tools/linux_wx_chat_daemon.py" ]]; then
      printf '%s\n' "${candidate}"
      return 0
    fi
  done
  return 1
}

resolve_python_bin() {
  if [[ -x "${PYWXDUMP_ROOT}/.venv/bin/python" ]]; then
    printf '%s\n' "${PYWXDUMP_ROOT}/.venv/bin/python"
    return 0
  fi
  if command -v python3 >/dev/null 2>&1; then
    command -v python3
    return 0
  fi
  return 1
}

latest_png() {
  "${PYTHON_BIN}" - "$1" <<'PY'
import os
import sys

root = sys.argv[1]
latest_path = ""
latest_mtime = -1.0
for name in os.listdir(root):
    if not name.lower().endswith(".png"):
        continue
    path = os.path.join(root, name)
    if not os.path.isfile(path):
        continue
    mtime = os.path.getmtime(path)
    if mtime > latest_mtime:
        latest_mtime = mtime
        latest_path = path
print(latest_path)
PY
}

activate_chat_window() {
  local title="$1"
  local window_id=""
  window_id="$(
    DISPLAY="${DISPLAY_VALUE}" XAUTHORITY="${XAUTHORITY_VALUE}" xdotool search --name "^${title}$" 2>/dev/null | tail -n1 || true
  )"
  if [[ -z "${window_id}" ]]; then
    echo "Standalone WeChat window not found: ${title}" >&2
    return 1
  fi
  DISPLAY="${DISPLAY_VALUE}" XAUTHORITY="${XAUTHORITY_VALUE}" xdotool windowactivate --sync "${window_id}"
}

usage() {
  cat <<'EOF'
Usage:
  screenshot_send_wechat.sh --chat CHAT [--delay SECONDS] [--mode MODE] [--hover-x X --hover-y Y] [--print-only]

Options:
  --chat CHAT         WeChat chat title to send to.
  --delay SECONDS     Wait before capture. Default: 0
  --mode MODE         Capture mode: desktop | ui-window. Default: desktop
  --hover-x X         Move mouse to absolute X before ui-window capture.
  --hover-y Y         Move mouse to absolute Y before ui-window capture.
  --window-mode MODE  Send mode: standalone | main | auto. Default: standalone
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
  --post-send-minimize
                     Minimize the target window after send if there is no window to restore.
  --post-send-force-minimize
                     Always minimize the target window after send instead of restoring focus. Default: enabled
  --send-script PATH  Override the downstream send script.
  --send-config PATH  Pass a config file to the downstream send script.
  --pywxdump-root D   Override the local PyWxDump project path for image send.
  --display VALUE     Override the X11 DISPLAY used for capture and send.
  --xauthority PATH   Override the XAUTHORITY used for capture and send.
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
    --mode)
      CAPTURE_MODE="${2:-}"
      shift 2
      ;;
    --hover-x)
      HOVER_X="${2:-}"
      shift 2
      ;;
    --hover-y)
      HOVER_Y="${2:-}"
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
    --post-send-minimize)
      POST_SEND_MINIMIZE=1
      shift
      ;;
    --post-send-force-minimize)
      POST_SEND_FORCE_MINIMIZE=1
      shift
      ;;
    --send-script)
      SEND_SCRIPT="${2:-}"
      shift 2
      ;;
    --send-config)
      SEND_CONFIG="${2:-}"
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

if ! [[ "${DELAY_SECONDS}" =~ ^[0-9]+$ ]]; then
  echo "--delay must be a non-negative integer" >&2
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

if [[ -n "${MAIN_WINDOW_VISION_TIMEOUT_SECONDS}" ]] && ! [[ "${MAIN_WINDOW_VISION_TIMEOUT_SECONDS}" =~ ^[0-9]+$ ]]; then
  echo "--main-window-vision-timeout-seconds must be a non-negative integer" >&2
  exit 2
fi

if [[ -n "${MAIN_WINDOW_VISION_THINKING_BUDGET_TOKENS}" ]] && ! [[ "${MAIN_WINDOW_VISION_THINKING_BUDGET_TOKENS}" =~ ^[0-9]+$ ]]; then
  echo "--main-window-vision-thinking-budget-tokens must be a non-negative integer" >&2
  exit 2
fi

if [[ "${CAPTURE_MODE}" != "desktop" && "${CAPTURE_MODE}" != "ui-window" ]]; then
  echo "--mode must be one of: desktop, ui-window" >&2
  exit 2
fi

if [[ -n "${HOVER_X}" && ! "${HOVER_X}" =~ ^[0-9]+$ ]]; then
  echo "--hover-x must be a non-negative integer" >&2
  exit 2
fi

if [[ -n "${HOVER_Y}" && ! "${HOVER_Y}" =~ ^[0-9]+$ ]]; then
  echo "--hover-y must be a non-negative integer" >&2
  exit 2
fi

if [[ "${CAPTURE_MODE}" != "ui-window" && ( -n "${HOVER_X}" || -n "${HOVER_Y}" ) ]]; then
  echo "--hover-x/--hover-y are only valid with --mode ui-window" >&2
  exit 2
fi

if [[ -n "${HOVER_X}" && -z "${HOVER_Y}" ]] || [[ -z "${HOVER_X}" && -n "${HOVER_Y}" ]]; then
  echo "--hover-x and --hover-y must be provided together" >&2
  exit 2
fi

mkdir -p "${SCREENSHOT_DIR}"
STAMP="$(date +%Y%m%d-%H%M%S)"
SHOT_PATH="${SCREENSHOT_DIR}/desktop-${STAMP}.png"

if [[ "${PRINT_ONLY}" -eq 1 ]]; then
  PYWXDUMP_ROOT="$(resolve_pywxdump_root)" || {
    echo "PyWxDump not found. Use --pywxdump-root to override." >&2
    exit 1
  }
  PYTHON_BIN="$(resolve_python_bin)" || {
    echo "python3 not found, and repo-local .venv python is unavailable: ${PYWXDUMP_ROOT}" >&2
    exit 1
  }
  echo "Resolved chat: ${CHAT}"
  echo "Resolved screenshot: ${SHOT_PATH}"
  echo "Resolved mode: ${CAPTURE_MODE}"
  echo "Resolved PyWxDump: ${PYWXDUMP_ROOT}"
  echo "Resolved python: ${PYTHON_BIN}"
  echo "Resolved window mode: ${WINDOW_MODE}"
  if [[ -n "${HOVER_X}" ]]; then
    echo "Resolved hover point: ${HOVER_X},${HOVER_Y}"
  fi
  if [[ -n "${SEND_CONFIG}" ]]; then
    echo "Resolved send config: ${SEND_CONFIG}"
  fi
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
  if [[ "${POST_SEND_MINIMIZE}" -eq 1 ]]; then
    echo "Resolved post send minimize: enabled"
  fi
  if [[ "${POST_SEND_FORCE_MINIMIZE}" -eq 1 ]]; then
    echo "Resolved post send force minimize: enabled"
  fi
  if [[ "${CAPTURE_MODE}" == "desktop" ]]; then
    printf 'Resolved capture: DISPLAY=%q XAUTHORITY=%q gnome-screenshot -f %q\n' "${DISPLAY_VALUE}" "${XAUTHORITY_VALUE}" "${SHOT_PATH}"
  else
    if [[ -n "${HOVER_X}" ]]; then
      printf 'Resolved capture: DISPLAY=%q XAUTHORITY=%q xdotool mousemove --sync %q %q ; xdotool key --clearmodifiers shift+ctrl+super+s ; wait for new PNG under %q\n' "${DISPLAY_VALUE}" "${XAUTHORITY_VALUE}" "${HOVER_X}" "${HOVER_Y}" "${SCREENSHOT_DIR}"
    else
      printf 'Resolved capture: DISPLAY=%q XAUTHORITY=%q xdotool key --clearmodifiers shift+ctrl+super+s ; wait for new PNG under %q\n' "${DISPLAY_VALUE}" "${XAUTHORITY_VALUE}" "${SCREENSHOT_DIR}"
    fi
  fi
  printf 'Resolved send:'
  printf ' %q' "${PYTHON_BIN}" "${PYWXDUMP_ROOT}/tools/linux_wx_chat_daemon.py" send-image --target "${CHAT}" --window-mode "${WINDOW_MODE}" --path "${SHOT_PATH}" --post-send-delay-ms "${POST_SEND_DELAY_MS}" --send-timeout "${SEND_TIMEOUT}" --send-step-delay-ms "${SEND_STEP_DELAY_MS}" --send-paste-settle-ms "${SEND_PASTE_SETTLE_MS}" --send-gui-countdown-seconds "${SEND_GUI_COUNTDOWN_SECONDS}" --send-gui-notify-timeout-ms "${SEND_GUI_NOTIFY_TIMEOUT_MS}" --display "${DISPLAY_VALUE}" --xauthority "${XAUTHORITY_VALUE}"
  if [[ -n "${MAIN_WINDOW_VISION_BASE_URL}" ]]; then
    printf ' %q %q' --main-window-vision-base-url "${MAIN_WINDOW_VISION_BASE_URL}"
  fi
  if [[ -n "${MAIN_WINDOW_VISION_MODEL}" ]]; then
    printf ' %q %q' --main-window-vision-model "${MAIN_WINDOW_VISION_MODEL}"
  fi
  if [[ -n "${MAIN_WINDOW_VISION_API_KEY_ENV}" ]]; then
    printf ' %q %q' --main-window-vision-api-key-env "${MAIN_WINDOW_VISION_API_KEY_ENV}"
  fi
  if [[ -n "${MAIN_WINDOW_VISION_TIMEOUT_SECONDS}" ]]; then
    printf ' %q %q' --main-window-vision-timeout-seconds "${MAIN_WINDOW_VISION_TIMEOUT_SECONDS}"
  fi
  if [[ -n "${MAIN_WINDOW_VISION_THINKING_BUDGET_TOKENS}" ]]; then
    printf ' %q %q' --main-window-vision-thinking-budget-tokens "${MAIN_WINDOW_VISION_THINKING_BUDGET_TOKENS}"
  fi
  if [[ "${MAIN_WINDOW_VISION_DISABLE_THINKING}" -eq 1 ]]; then
    printf ' %q' --main-window-vision-disable-thinking
  fi
  if [[ "${NO_SEND_GUI_PROMPTS}" -eq 1 ]]; then
    printf ' %q' --no-send-gui-prompts
  fi
  if [[ "${POST_SEND_MINIMIZE}" -eq 1 ]]; then
    printf ' %q' --post-send-minimize
  fi
  if [[ "${POST_SEND_FORCE_MINIMIZE}" -eq 1 ]]; then
    printf ' %q' --post-send-force-minimize
  fi
  printf '\n'
  exit 0
fi

PYWXDUMP_ROOT="$(resolve_pywxdump_root)" || {
  echo "PyWxDump not found. Use --pywxdump-root to override." >&2
  exit 1
}

PYTHON_BIN="$(resolve_python_bin)" || {
  echo "python3 not found, and repo-local .venv python is unavailable: ${PYWXDUMP_ROOT}" >&2
  exit 1
}

if [[ ! -f "${PYWXDUMP_ROOT}/tools/linux_wx_chat_daemon.py" ]]; then
  echo "PyWxDump not found: ${PYWXDUMP_ROOT}" >&2
  exit 1
fi

echo "Resolved chat: ${CHAT}"
echo "Resolved screenshot: ${SHOT_PATH}"
echo "Resolved mode: ${CAPTURE_MODE}"
echo "Resolved PyWxDump: ${PYWXDUMP_ROOT}"
echo "Resolved python: ${PYTHON_BIN}"
echo "Resolved window mode: ${WINDOW_MODE}"
if [[ -n "${HOVER_X}" ]]; then
  echo "Resolved hover point: ${HOVER_X},${HOVER_Y}"
fi
if [[ -n "${SEND_CONFIG}" ]]; then
  echo "Resolved send config: ${SEND_CONFIG}"
fi
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
if [[ "${POST_SEND_MINIMIZE}" -eq 1 ]]; then
  echo "Resolved post send minimize: enabled"
fi
if [[ "${POST_SEND_FORCE_MINIMIZE}" -eq 1 ]]; then
  echo "Resolved post send force minimize: enabled"
fi

if [[ "${DELAY_SECONDS}" -gt 0 ]]; then
  sleep "${DELAY_SECONDS}"
fi

latest_png_before="$(latest_png "${SCREENSHOT_DIR}")"

if [[ "${CAPTURE_MODE}" == "desktop" ]]; then
  if command -v gnome-screenshot >/dev/null 2>&1; then
    DISPLAY="${DISPLAY_VALUE}" XAUTHORITY="${XAUTHORITY_VALUE}" gnome-screenshot -f "${SHOT_PATH}"
  else
    DISPLAY="${DISPLAY_VALUE}" XAUTHORITY="${XAUTHORITY_VALUE}" "${PYTHON_BIN}" - "${SHOT_PATH}" <<'PY'
import sys
from PIL import ImageGrab

target = sys.argv[1]
image = ImageGrab.grab()
image.save(target)
PY
  fi
else
  activate_chat_window "${CHAT}"
  sleep 0.2
  if [[ -n "${HOVER_X}" ]]; then
    DISPLAY="${DISPLAY_VALUE}" XAUTHORITY="${XAUTHORITY_VALUE}" xdotool mousemove --sync "${HOVER_X}" "${HOVER_Y}"
    sleep 0.15
  fi
  DISPLAY="${DISPLAY_VALUE}" XAUTHORITY="${XAUTHORITY_VALUE}" xdotool key --clearmodifiers "shift+ctrl+super+s"
  found_path=""
  for _ in $(seq 1 120); do
    latest_png_after="$(latest_png "${SCREENSHOT_DIR}")"
    if [[ -n "${latest_png_after}" && "${latest_png_after}" != "${latest_png_before}" ]]; then
      found_path="${latest_png_after}"
      break
    fi
    sleep 0.25
  done
  if [[ -z "${found_path}" ]]; then
    echo "Timed out waiting for interactive screenshot output under ${SCREENSHOT_DIR}" >&2
    exit 1
  fi
  SHOT_PATH="${found_path}"
fi

CMD=(
  "${PYTHON_BIN}"
  "${PYWXDUMP_ROOT}/tools/linux_wx_chat_daemon.py"
  send-image
  --target
  "${CHAT}"
  --window-mode
  "${WINDOW_MODE}"
  --path
  "${SHOT_PATH}"
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

if [[ "${POST_SEND_MINIMIZE}" -eq 1 ]]; then
  CMD+=(--post-send-minimize)
fi

if [[ "${POST_SEND_FORCE_MINIMIZE}" -eq 1 ]]; then
  CMD+=(--post-send-force-minimize)
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

OUTPUT_FILE="$(mktemp -t wechat-screenshot-send-output.XXXXXX)"
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
    print(f"[skill][wechat-screenshot-send] status={status} restore_action={restore_action} matched_local_id={matched_local_id}")
PY

exit "${STATUS}"
