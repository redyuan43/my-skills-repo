#!/usr/bin/env bash
set -euo pipefail

WECHAT_BIN="${WECHAT_BIN:-/usr/bin/wechat}"
WINDOW_WAIT_SECONDS="${WINDOW_WAIT_SECONDS:-30}"
CLICK_X_RATIO="${WECHAT_CLICK_X_RATIO:-50}"
CLICK_Y_RATIO="${WECHAT_CLICK_Y_RATIO:-88}"
LAUNCH_DELAY_SECONDS="${WECHAT_LAUNCH_DELAY_SECONDS:-2}"
MODE="${WECHAT_AUTO_MODE:-__DEFAULT_MODE__}"

log() {
  printf '[wechat-auto-enter] %s\n' "$*"
}

fail() {
  printf '[wechat-auto-enter] %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<'EOF'
用法:
  ./wechat_auto_enter.sh [--mode vision|click|key] [--x-ratio 50] [--y-ratio 88]

说明:
  1. 自动启动微信
  2. 等待微信窗口出现
  3. 聚焦微信窗口
  4. 默认用截图识别绿色按钮，再点击按钮中心

参数:
  --mode        vision: 截图识别绿色按钮并点击中心
                click:  按相对坐标点击按钮
                key:   聚焦窗口后直接发送回车
  --x-ratio     点击位置横向比例，默认 50
  --y-ratio     点击位置纵向比例，默认 88
  --wait        最长等待窗口秒数，默认 30
  --delay       启动微信后额外等待秒数，默认 2
  -h, --help    显示帮助

环境变量:
  WECHAT_BIN=/usr/bin/wechat
  WECHAT_CLICK_X_RATIO=50
  WECHAT_CLICK_Y_RATIO=88
  WECHAT_LAUNCH_DELAY_SECONDS=2
  WECHAT_AUTO_MODE=vision
EOF
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "缺少命令: $1"
}

validate_ratio() {
  local name="$1"
  local value="$2"
  [[ "$value" =~ ^[0-9]+$ ]] || fail "$name 必须是 0 到 100 的整数"
  (( value >= 0 && value <= 100 )) || fail "$name 必须是 0 到 100 的整数"
}

detect_display() {
  if [[ -n "${DISPLAY:-}" ]]; then
    return 0
  fi

  local session_id=""
  local display_value=""
  local socket_path=""

  if command -v "loginctl" >/dev/null 2>&1; then
    session_id="$(loginctl list-sessions --no-legend 2>/dev/null | awk -v user="$USER" '$3 == user {print $1; exit}' || true)"
    if [[ -n "${session_id}" ]]; then
      display_value="$(loginctl show-session "${session_id}" -p Display --value 2>/dev/null || true)"
      if [[ -n "${display_value}" ]]; then
        export DISPLAY="${display_value}"
      fi
    fi
  fi

  if [[ -z "${DISPLAY:-}" ]]; then
    socket_path="$(find "/tmp/.X11-unix" -maxdepth 1 -type s -name "X*" 2>/dev/null | sort | head -n 1 || true)"
    if [[ -n "${socket_path}" ]]; then
      export DISPLAY=":${socket_path##*X}"
    fi
  fi

  if [[ -z "${XAUTHORITY:-}" && -f "${HOME}/.Xauthority" ]]; then
    export XAUTHORITY="${HOME}/.Xauthority"
  fi

  [[ -n "${DISPLAY:-}" ]] || fail "没有可用的 DISPLAY。请在图形桌面终端中运行，或先 export DISPLAY=:0"
}

launch_wechat() {
  log "启动或唤醒微信"
  nohup "${WECHAT_BIN}" >/tmp/wechat-auto-enter.log 2>&1 &
  sleep "${LAUNCH_DELAY_SECONDS}"
}

find_wechat_window() {
  local attempt=0
  local window_id=""

  while (( attempt < WINDOW_WAIT_SECONDS )); do
    window_id="$(xdotool search --onlyvisible --class "wechat" 2>/dev/null | head -n 1 || true)"
    if [[ -z "${window_id}" ]]; then
      window_id="$(xdotool search --onlyvisible --classname "wechat" 2>/dev/null | head -n 1 || true)"
    fi
    if [[ -z "${window_id}" ]]; then
      window_id="$(xdotool search --onlyvisible --name "微信|WeChat|wechat|Weixin" 2>/dev/null | head -n 1 || true)"
    fi
    if [[ -n "${window_id}" ]]; then
      printf '%s\n' "${window_id}"
      return 0
    fi

    sleep 1
    attempt=$(( attempt + 1 ))
  done

  return 1
}

activate_window() {
  local window_id="$1"
  xdotool windowactivate --sync "${window_id}" >/dev/null 2>&1 || true
  sleep 1
}

find_green_button_center() {
  local image_path="$1"

  python3 - "$image_path" <<'PY'
from collections import deque
import sys

from PIL import Image


def is_green(pixel):
    r, g, b = pixel
    return g > 150 and g > r + 40 and g > b + 40


image = Image.open(sys.argv[1]).convert("RGB")
width, height = image.size
pixels = image.load()
visited = set()
best = None

for y in range(height):
    for x in range(width):
        if (x, y) in visited or not is_green(pixels[x, y]):
            continue

        queue = deque([(x, y)])
        visited.add((x, y))
        size = 0
        min_x = max_x = x
        min_y = max_y = y

        while queue:
            current_x, current_y = queue.popleft()
            size += 1
            min_x = min(min_x, current_x)
            min_y = min(min_y, current_y)
            max_x = max(max_x, current_x)
            max_y = max(max_y, current_y)

            for next_x, next_y in (
                (current_x - 1, current_y),
                (current_x + 1, current_y),
                (current_x, current_y - 1),
                (current_x, current_y + 1),
            ):
                if not (0 <= next_x < width and 0 <= next_y < height):
                    continue
                if (next_x, next_y) in visited:
                    continue
                if not is_green(pixels[next_x, next_y]):
                    continue
                visited.add((next_x, next_y))
                queue.append((next_x, next_y))

        if size < 500:
            continue

        if best is None or size > best[0]:
            best = (size, min_x, min_y, max_x, max_y)

if best is None:
    raise SystemExit(1)

_, min_x, min_y, max_x, max_y = best
center_x = (min_x + max_x) // 2
center_y = (min_y + max_y) // 2
print(center_x, center_y, min_x, min_y, max_x, max_y)
PY
}

vision_click_enter_button() {
  local window_id="$1"
  local image_path=""
  local result=""
  local click_x=0
  local click_y=0
  local min_x=0
  local min_y=0
  local max_x=0
  local max_y=0

  image_path="$(mktemp --suffix=.png /tmp/wechat-auto-enter-XXXXXX)"
  gnome-screenshot -w -f "${image_path}" >/dev/null 2>&1
  result="$(find_green_button_center "${image_path}")" || {
    rm -f "${image_path}"
    fail "视觉定位失败，没有识别到绿色按钮"
  }
  rm -f "${image_path}"

  read -r click_x click_y min_x min_y max_x max_y <<<"${result}"
  log "视觉定位按钮区域 (${min_x}, ${min_y}) - (${max_x}, ${max_y})，点击中心 (${click_x}, ${click_y})"
  xdotool mousemove --window "${window_id}" "${click_x}" "${click_y}" click 1
}

click_enter_button() {
  local window_id="$1"
  local width=0
  local height=0
  local click_x=0
  local click_y=0

  eval "$(xdotool getwindowgeometry --shell "${window_id}")"

  width="${WIDTH:-0}"
  height="${HEIGHT:-0}"
  (( width > 0 && height > 0 )) || fail "读取微信窗口尺寸失败"

  click_x=$(( width * CLICK_X_RATIO / 100 ))
  click_y=$(( height * CLICK_Y_RATIO / 100 ))

  if (( click_x <= 0 )); then
    click_x=1
  fi
  if (( click_y <= 0 )); then
    click_y=1
  fi
  if (( click_x >= width )); then
    click_x=$(( width - 1 ))
  fi
  if (( click_y >= height )); then
    click_y=$(( height - 1 ))
  fi

  log "点击微信窗口相对坐标 (${click_x}, ${click_y})"
  xdotool mousemove --window "${window_id}" "${click_x}" "${click_y}" click 1
}

press_enter_key() {
  local window_id="$1"
  log "向微信窗口发送回车"
  xdotool key --window "${window_id}" --clearmodifiers Return
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --mode)
        [[ $# -ge 2 ]] || fail "--mode 缺少参数"
        MODE="$2"
        shift 2
        ;;
      --x-ratio)
        [[ $# -ge 2 ]] || fail "--x-ratio 缺少参数"
        CLICK_X_RATIO="$2"
        shift 2
        ;;
      --y-ratio)
        [[ $# -ge 2 ]] || fail "--y-ratio 缺少参数"
        CLICK_Y_RATIO="$2"
        shift 2
        ;;
      --wait)
        [[ $# -ge 2 ]] || fail "--wait 缺少参数"
        WINDOW_WAIT_SECONDS="$2"
        shift 2
        ;;
      --delay)
        [[ $# -ge 2 ]] || fail "--delay 缺少参数"
        LAUNCH_DELAY_SECONDS="$2"
        shift 2
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        fail "未知参数: $1"
        ;;
    esac
  done
}

main() {
  parse_args "$@"

  require_command "xdotool"
  [[ -x "${WECHAT_BIN}" ]] || fail "找不到可执行微信程序: ${WECHAT_BIN}"

  [[ "${WINDOW_WAIT_SECONDS}" =~ ^[0-9]+$ ]] || fail "--wait 必须是正整数"
  [[ "${LAUNCH_DELAY_SECONDS}" =~ ^[0-9]+([.][0-9]+)?$ ]] || fail "--delay 必须是正数"
  [[ "${MODE}" == "vision" || "${MODE}" == "click" || "${MODE}" == "key" ]] || fail "--mode 仅支持 vision、click 或 key"
  validate_ratio "x-ratio" "${CLICK_X_RATIO}"
  validate_ratio "y-ratio" "${CLICK_Y_RATIO}"

  detect_display
  launch_wechat

  local window_id=""
  window_id="$(find_wechat_window)" || fail "等待微信窗口超时，请先手动打开一次微信确认窗口标题"
  log "找到微信窗口: ${window_id}"
  activate_window "${window_id}"

  if [[ "${MODE}" == "vision" ]]; then
    require_command "gnome-screenshot"
    require_command "python3"
    vision_click_enter_button "${window_id}"
  elif [[ "${MODE}" == "key" ]]; then
    press_enter_key "${window_id}"
  else
    click_enter_button "${window_id}"
  fi

  log "执行完成"
}

main "$@"
