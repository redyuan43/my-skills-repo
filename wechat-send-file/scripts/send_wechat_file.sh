#!/usr/bin/env bash
set -euo pipefail

CHAT=""
FILE_PATH=""
ALLOW_JPEG=0
PRINT_ONLY=0
DOCS_ROOT="${HOME}/Documents"
LEGACY_CONFIG_PATH=""
LEGACY_APP_ROOT=""
PYWXDUMP_ROOT="${PYWXDUMP_ROOT:-${HOME}/github/PyWxDump}"
WECLAW_ROOT="${WECLAW_ROOT:-${HOME}/github/weclaw}"
WECLAW_API_BASE="${WECHAT_WECLAW_API_BASE:-http://127.0.0.1:18012}"
BOT_MEDIA_MODE="${WECHAT_BOT_MEDIA_MODE:-auto}"
BOT_WAIT_CONTEXT_SECONDS="${WECHAT_BOT_WAIT_CONTEXT_SECONDS:-15}"
WINDOW_CLASS="${WECHAT_WINDOW_CLASS:-wechat}"
DISPLAY_VALUE="${WECHAT_X11_DISPLAY:-${DISPLAY:-:0}}"
XAUTHORITY_VALUE="${WECHAT_X11_XAUTHORITY:-${XAUTHORITY:-/run/user/1000/gdm/Xauthority}}"
PYTHON_BIN="${WECHAT_PYTHON_BIN:-${PYWXDUMP_ROOT}/.venv/bin/python}"
WECLAW_BIN="${WECHAT_WECLAW_BIN:-${WECLAW_ROOT}/weclaw}"
WINDOW_MODE="${WECHAT_SEND_WINDOW_MODE:-standalone}"
SEND_VIA="${WECHAT_SEND_VIA:-auto}"
SEND_STEP_DELAY_MS="${WECHAT_SEND_STEP_DELAY_MS:-220}"
SEND_PASTE_SETTLE_MS="${WECHAT_SEND_PASTE_SETTLE_MS:-320}"
POST_SEND_DELAY_MS="${WECHAT_SEND_POST_DELAY_MS:-1800}"
SEND_TIMEOUT="${WECHAT_SEND_TIMEOUT:-30}"
SEND_GUI_COUNTDOWN_SECONDS="${WECHAT_SEND_GUI_COUNTDOWN_SECONDS:-1}"
SEND_GUI_NOTIFY_TIMEOUT_MS="${WECHAT_SEND_GUI_NOTIFY_TIMEOUT_MS:-4000}"
POSITIONALS=()
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
  send_wechat_file.sh CHAT [PATH]
  send_wechat_file.sh --chat CHAT [--path FILE]
  send_wechat_file.sh --chat CHAT [--allow-jpeg] [--print-only]

Options:
  CHAT                Chat title (positional shorthand for --chat).
  PATH                Absolute path of a local file (positional shorthand for --path).
  --chat CHAT         WeChat chat title to send to.
  --path FILE         Absolute path of a local file to send.
  --allow-jpeg        Allow jpg/jpeg when auto-picking from Documents.
  --documents-root D  Override the search root. Default: ~/Documents
  --window-class CLS  X11 微信窗口 class（默认: wechat）
  --send-via MODE     Send path: auto | pywxdump | weclaw-bot. Default: auto
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
  --config PATH       Legacy compatibility option. Ignored.
  --app-root PATH     Legacy compatibility option. Ignored.
  --pywxdump-root P   Override the local PyWxDump project path.
  --weclaw-root P     Override the local weclaw project path.
  --weclaw-bin PATH   Override the local weclaw executable path.
  --weclaw-api-base U Override the local weclaw HTTP API base URL.
  --bot-media-mode M  Bot send media mode: auto | image | file. Default: auto
  --bot-wait-context-seconds N
                     Wait this many seconds for bot context token. Default: 15
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
    --window-class)
      WINDOW_CLASS="${2:-}"
      shift 2
      ;;
    --send-via)
      SEND_VIA="${2:-}"
      shift 2
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
    --weclaw-root)
      WECLAW_ROOT="${2:-}"
      shift 2
      ;;
    --weclaw-bin)
      WECLAW_BIN="${2:-}"
      shift 2
      ;;
    --weclaw-api-base)
      WECLAW_API_BASE="${2:-}"
      shift 2
      ;;
    --bot-media-mode)
      BOT_MEDIA_MODE="${2:-}"
      shift 2
      ;;
    --bot-wait-context-seconds)
      BOT_WAIT_CONTEXT_SECONDS="${2:-}"
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
      if [[ "$1" == --* ]]; then
        echo "Unknown argument: $1" >&2
        usage >&2
        exit 2
      fi
      POSITIONALS+=("$1")
      shift
      ;;
  esac
done

if [[ -z "${CHAT}" && ${#POSITIONALS[@]} -ge 1 ]]; then
  CHAT="${POSITIONALS[0]}"
fi

if [[ -z "${FILE_PATH}" && ${#POSITIONALS[@]} -ge 2 ]]; then
  FILE_PATH="${POSITIONALS[1]}"
fi

if [[ ${#POSITIONALS[@]} -gt 2 ]]; then
  echo "Too many positional arguments" >&2
  usage >&2
  exit 2
fi

if [[ -z "${CHAT}" ]]; then
  echo "--chat is required" >&2
  exit 2
fi

if [[ "${WINDOW_MODE}" != "standalone" && "${WINDOW_MODE}" != "main" && "${WINDOW_MODE}" != "auto" ]]; then
  echo "--window-mode must be one of: standalone, main, auto" >&2
  exit 2
fi

if [[ "${SEND_VIA}" != "auto" && "${SEND_VIA}" != "pywxdump" && "${SEND_VIA}" != "weclaw-bot" ]]; then
  echo "--send-via must be one of: auto, pywxdump, weclaw-bot" >&2
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

if [[ "${BOT_MEDIA_MODE}" != "auto" && "${BOT_MEDIA_MODE}" != "image" && "${BOT_MEDIA_MODE}" != "file" ]]; then
  echo "--bot-media-mode must be one of: auto, image, file" >&2
  exit 2
fi

if ! [[ "${BOT_WAIT_CONTEXT_SECONDS}" =~ ^[0-9]+$ ]]; then
  echo "--bot-wait-context-seconds must be a non-negative integer" >&2
  exit 2
fi

if [[ -n "${WECHAT_PYTHON_BIN:-}" ]]; then
  PYTHON_BIN="${WECHAT_PYTHON_BIN}"
elif [[ -z "${WECHAT_PYTHON_BIN:-}" ]]; then
  PYTHON_BIN="${PYWXDUMP_ROOT}/.venv/bin/python"
fi

if [[ ! -x "${PYTHON_BIN}" ]]; then
  echo "Required PyWxDump python not found: ${PYTHON_BIN}" >&2
  exit 1
fi

RESOLVED_CHAT="${CHAT}"
WECLAW_TARGET=""

if [[ -n "${MAIN_WINDOW_VISION_TIMEOUT_SECONDS}" ]] && ! [[ "${MAIN_WINDOW_VISION_TIMEOUT_SECONDS}" =~ ^[0-9]+$ ]]; then
  echo "--main-window-vision-timeout-seconds must be a non-negative integer" >&2
  exit 2
fi

if [[ -n "${MAIN_WINDOW_VISION_THINKING_BUDGET_TOKENS}" ]] && ! [[ "${MAIN_WINDOW_VISION_THINKING_BUDGET_TOKENS}" =~ ^[0-9]+$ ]]; then
  echo "--main-window-vision-thinking-budget-tokens must be a non-negative integer" >&2
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

resolve_weclaw_local_user_id() {
  local config_path="${HOME}/.weclaw/config.json"
  if [[ ! -f "${config_path}" ]]; then
    echo "WeClaw config not found: ${config_path}" >&2
    return 1
  fi
  python3 - "${config_path}" <<'PY'
import json
import sys

path = sys.argv[1]
with open(path, "r", encoding="utf-8") as fp:
    data = json.load(fp)
value = (((data or {}).get("bridge") or {}).get("local_user_id") or "").strip()
if not value:
    raise SystemExit(1)
print(value)
PY
}

run_weclaw_send() {
  if [[ -z "${WECLAW_TARGET}" ]]; then
    echo "Resolved WeClaw target is empty" >&2
    exit 1
  fi

  local request_media_mode="${BOT_MEDIA_MODE}"
  if [[ "${request_media_mode}" == "auto" ]]; then
    case "${FILE_PATH,,}" in
      *.png|*.jpg|*.jpeg|*.gif|*.webp|*.bmp)
        request_media_mode="image"
        ;;
      *)
        request_media_mode="file"
        ;;
    esac
  fi

  local api_send=0
  if curl -fsS --max-time 2 "${WECLAW_API_BASE}/health" >/dev/null 2>&1; then
    api_send=1
  fi

  local weclaw_cmd=(
    "${WECLAW_BIN}"
    send
    --to
    "${WECLAW_TARGET}"
    --file
    "${FILE_PATH}"
  )

  echo "Resolved route: weclaw-bot"
  echo "Resolved chat: ${RESOLVED_CHAT}"
  echo "Original chat query: ${CHAT}"
  echo "Resolved file: ${FILE_PATH}"
  echo "Resolved WeClaw target: ${WECLAW_TARGET}"
  echo "Resolved WeClaw API base: ${WECLAW_API_BASE}"
  echo "Resolved bot media mode: ${request_media_mode}"
  echo "Resolved bot wait context seconds: ${BOT_WAIT_CONTEXT_SECONDS}"
  echo "Resolved WeClaw bin: ${WECLAW_BIN}"

  if [[ "${PRINT_ONLY}" -eq 1 ]]; then
    if [[ "${api_send}" -eq 1 ]]; then
      printf 'Resolved API request: POST %s/api/send\n' "${WECLAW_API_BASE}"
    else
      printf 'Resolved command:'
      printf ' %q' "${weclaw_cmd[@]}"
      printf '\n'
    fi
    exit 0
  fi

  if [[ "${api_send}" -eq 1 ]]; then
    local payload
    payload="$(python3 - "${WECLAW_TARGET}" "${FILE_PATH}" "${request_media_mode}" "${BOT_WAIT_CONTEXT_SECONDS}" <<'PY'
import json
import sys

print(json.dumps({
    "to": sys.argv[1],
    "media_path": sys.argv[2],
    "media_mode": sys.argv[3],
    "wait_context_token_seconds": int(sys.argv[4]),
}, ensure_ascii=False))
PY
)"
    local response_file
    response_file="$(mktemp -t wechat-send-file-weclaw-api.XXXXXX)"
    local status_code
    set +e
    status_code="$(curl -sS -o "${response_file}" -w "%{http_code}" \
      -X POST "${WECLAW_API_BASE}/api/send" \
      -H "Content-Type: application/json" \
      -d "${payload}")"
    local curl_status=$?
    set -e
    if [[ ${curl_status} -ne 0 ]]; then
      rm -f "${response_file}"
      echo "WeClaw API request failed" >&2
      exit 1
    fi
    if [[ "${status_code}" != "200" ]]; then
      if [[ "${request_media_mode}" == "image" ]]; then
        local body_text
        body_text="$(cat "${response_file}")"
        if [[ "${body_text}" == *"send media failed"* ]]; then
          rm -f "${response_file}"
          echo "WeClaw image send failed, retrying as file..." >&2
          payload="$(python3 - "${WECLAW_TARGET}" "${FILE_PATH}" "${BOT_WAIT_CONTEXT_SECONDS}" <<'PY'
import json
import sys

print(json.dumps({
    "to": sys.argv[1],
    "media_path": sys.argv[2],
    "media_mode": "file",
    "wait_context_token_seconds": int(sys.argv[3]),
}, ensure_ascii=False))
PY
)"
          status_code="$(curl -sS -o "${response_file}" -w "%{http_code}" \
            -X POST "${WECLAW_API_BASE}/api/send" \
            -H "Content-Type: application/json" \
            -d "${payload}")"
        fi
      fi
    fi
    if [[ "${status_code}" != "200" ]]; then
      cat "${response_file}" >&2
      rm -f "${response_file}"
      exit 1
    fi
    cat "${response_file}"
    rm -f "${response_file}"
  else
    if [[ ! -x "${WECLAW_BIN}" ]]; then
      echo "WeClaw executable not found and API unavailable: ${WECLAW_BIN}" >&2
      exit 1
    fi
    "${weclaw_cmd[@]}"
  fi
  echo "[skill][wechat-send-file] status=sent route=weclaw-bot target=${WECLAW_TARGET} file=${FILE_PATH}"
  exit 0
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

if [[ "${SEND_VIA}" == "auto" ]]; then
  case "${CHAT}" in
    bot|Bot|BOT|owner|me|self)
      SEND_VIA="weclaw-bot"
      ;;
    *@im.wechat|*@im.bot)
      SEND_VIA="weclaw-bot"
      ;;
    *)
      SEND_VIA="pywxdump"
      ;;
  esac
fi

if [[ "${SEND_VIA}" == "weclaw-bot" ]]; then
  case "${CHAT}" in
    bot|Bot|BOT|owner|me|self)
      WECLAW_TARGET="$(resolve_weclaw_local_user_id)"
      RESOLVED_CHAT="bot(${WECLAW_TARGET})"
      ;;
    *)
      WECLAW_TARGET="${CHAT}"
      RESOLVED_CHAT="${CHAT}"
      ;;
  esac
  run_weclaw_send
fi

CMD=(
  "${PYTHON_BIN}"
  "${PYWXDUMP_ROOT}/tools/linux_wx_chat_daemon.py"
  send-file
  --target
  "${RESOLVED_CHAT}"
  --window-mode
  "${WINDOW_MODE}"
  --window-class
  "${WINDOW_CLASS}"
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
  --allow-missing-msg-table
  --display
  "${DISPLAY_VALUE}"
  --xauthority
  "${XAUTHORITY_VALUE}"
  --no-image-analysis
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
echo "Resolved route: pywxdump"
echo "Resolved file: ${FILE_PATH}"
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

"${PYTHON_BIN}" - "${OUTPUT_FILE}" <<'PY'
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
