#!/usr/bin/env bash
set -euo pipefail

CHAT=""
HOVER_X=""
HOVER_Y=""
DELAY_SECONDS=0
PRINT_ONLY=0
SCREENSHOT_DIR="${HOME}/Pictures/Screenshots"
DISPLAY_VALUE="${WECHAT_X11_DISPLAY:-${DISPLAY:-:0}}"
XAUTHORITY_VALUE="${WECHAT_X11_XAUTHORITY:-${XAUTHORITY:-/run/user/1000/gdm/Xauthority}}"
PYWXDUMP_ROOT="${PYWXDUMP_ROOT:-${HOME}/github/PyWxDump}"
OLLAMA_URL="${WECHAT_VISION_BASE_URL:-http://127.0.0.1:1234}"
VISION_MODEL="${WECHAT_VISION_MODEL:-qwen/qwen3.5-35b-a3b}"
VISION_API_KEY_ENV="${WECHAT_VISION_API_KEY_ENV:-OPENAI_API_KEY}"
NOTE=""

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
用法:
  diagnose_control_wechat.sh --chat CHAT --hover-x X --hover-y Y [--note TEXT] [--delay SECONDS] [--print-only]

选项:
  --chat CHAT           独立微信窗口标题。
  --hover-x X           诊断前鼠标悬停的绝对坐标 X。
  --hover-y Y           诊断前鼠标悬停的绝对坐标 Y。
  --note TEXT           补充给视觉模型的上下文说明。
  --delay SECONDS       截图前等待秒数。默认 0。
  --display VALUE       覆盖 X11 DISPLAY。
  --xauthority PATH     覆盖 XAUTHORITY。
  --pywxdump-root PATH  覆盖本地 PyWxDump 仓库路径。
  --ollama-url URL      视觉模型服务地址。默认 http://127.0.0.1:1234
  --vision-model NAME   视觉模型名称。
  --vision-api-key-env  OpenAI 兼容视觉接口使用的 API Key 环境变量名。
  --print-only          仅打印将执行的命令，不执行。
  -h, --help            显示帮助。
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --chat)
      CHAT="${2:-}"
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
    --note)
      NOTE="${2:-}"
      shift 2
      ;;
    --delay)
      DELAY_SECONDS="${2:-}"
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
    --pywxdump-root)
      PYWXDUMP_ROOT="${2:-}"
      shift 2
      ;;
    --ollama-url)
      OLLAMA_URL="${2:-}"
      shift 2
      ;;
    --vision-model)
      VISION_MODEL="${2:-}"
      shift 2
      ;;
    --vision-api-key-env)
      VISION_API_KEY_ENV="${2:-}"
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
      echo "未知参数: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -z "${CHAT}" ]]; then
  echo "--chat 是必填项" >&2
  exit 2
fi

if [[ -z "${HOVER_X}" || -z "${HOVER_Y}" ]]; then
  echo "--hover-x/--hover-y 都是必填项" >&2
  exit 2
fi

if ! [[ "${HOVER_X}" =~ ^[0-9]+$ && "${HOVER_Y}" =~ ^[0-9]+$ ]]; then
  echo "--hover-x/--hover-y 必须是非负整数" >&2
  exit 2
fi

if ! [[ "${DELAY_SECONDS}" =~ ^[0-9]+$ ]]; then
  echo "--delay must be a non-negative integer" >&2
  exit 2
fi

if [[ ! -f "${PYWXDUMP_ROOT}/tools/linux_wx_chat_daemon.py" ]]; then
  echo "PyWxDump not found: ${PYWXDUMP_ROOT}" >&2
  exit 1
fi

mkdir -p "${SCREENSHOT_DIR}"

if [[ "${PRINT_ONLY}" -eq 1 ]]; then
  printf 'Resolved capture: python3 <inline> %q %q %q %q %q %q -> crop target control ROI under %q\n' \
    "${PYWXDUMP_ROOT}" "${CHAT}" "${HOVER_X}" "${HOVER_Y}" "${DISPLAY_VALUE}" "${XAUTHORITY_VALUE}" "${SCREENSHOT_DIR}"
  printf 'Resolved send image:'
  printf ' %q' python3 "${PYWXDUMP_ROOT}/tools/linux_wx_chat_daemon.py" send-image --target "${CHAT}" --window-mode standalone --path "<captured-png>" --post-send-delay-ms 1800 --send-timeout 30 --display "${DISPLAY_VALUE}" --xauthority "${XAUTHORITY_VALUE}"
  printf ' %q' --auto-resolve-target
  printf ' %q' --post-send-force-minimize
  printf '\n'
  printf 'Resolved diagnose: python3 <inline> %q %q %q %q %q\n' "${PYWXDUMP_ROOT}" "${OLLAMA_URL}" "${VISION_MODEL}" "${VISION_API_KEY_ENV}" "<captured-png>"
  printf 'Resolved send text:'
  printf ' %q' python3 "${PYWXDUMP_ROOT}/tools/linux_wx_chat_daemon.py" send-text --target "${CHAT}" --window-mode standalone --text "<diagnosis-md>" --post-send-delay-ms 1200 --send-timeout 30 --display "${DISPLAY_VALUE}" --xauthority "${XAUTHORITY_VALUE}"
  printf ' %q' --auto-resolve-target
  printf ' %q' --post-send-force-minimize
  printf '\n'
  exit 0
fi

if [[ "${DELAY_SECONDS}" -gt 0 ]]; then
  sleep "${DELAY_SECONDS}"
fi

activate_chat_window "${CHAT}"
sleep 0.2
captured_png="$(
  python3 - "${PYWXDUMP_ROOT}" "${CHAT}" "${HOVER_X}" "${HOVER_Y}" "${DISPLAY_VALUE}" "${XAUTHORITY_VALUE}" "${SCREENSHOT_DIR}" <<'PY'
import os
import shutil
import sys
from datetime import datetime

repo_root, chat_title, hover_x, hover_y, display, xauthority, screenshot_dir = sys.argv[1:]
hover_x = int(hover_x)
hover_y = int(hover_y)
sys.path.insert(0, os.path.join(repo_root, "tools"))
import linux_wx_x11_send as x11  # noqa: E402

window = x11.discover_standalone_window(chat_title, display=display, xauthority=xauthority)
if not window:
    raise SystemExit(f"Standalone window not found: {chat_title}")

relative_x = max(0, min(window.width - 1, hover_x - window.x))
relative_y = max(0, min(window.height - 1, hover_y - window.y))
half_width = 140
half_height = 120
left = max(0, relative_x - half_width)
top = max(0, relative_y - half_height)
right = min(window.width, relative_x + half_width)
bottom = min(window.height, relative_y + half_height)

window_png = x11.capture_window_png(window.window_id, display=display, xauthority=xauthority)
crop_png = x11.crop_png(window_png, (left, top, right, bottom))
target_path = os.path.join(screenshot_dir, f"control-diagnose-{datetime.now().strftime('%Y%m%d-%H%M%S')}.png")
shutil.copy2(crop_png, target_path)
print(target_path)
PY
)"

python3 "${PYWXDUMP_ROOT}/tools/linux_wx_chat_daemon.py" \
  send-image \
  --target "${CHAT}" \
  --window-mode standalone \
  --path "${captured_png}" \
  --post-send-delay-ms 1800 \
  --send-timeout 30 \
  --auto-resolve-target \
  --post-send-force-minimize \
  --display "${DISPLAY_VALUE}" \
  --xauthority "${XAUTHORITY_VALUE}"

diagnosis_md=""
if ! diagnosis_md="$(
  python3 - "${PYWXDUMP_ROOT}" "${OLLAMA_URL}" "${VISION_MODEL}" "${VISION_API_KEY_ENV}" "${captured_png}" "${NOTE}" <<'PY'
import json
import os
import sys

repo_root, base_url, model, api_key_env, image_path, note = sys.argv[1:]
sys.path.insert(0, os.path.join(repo_root, "tools"))
import linux_wx_msg_monitor as monitor  # noqa: E402

prompt = """你是一名微信 Linux GUI 自动化排障助手。
请针对这张“控件级或窗口级截图”输出一份极简 Markdown 诊断。

必须包含以下小节：
## 观察
## 判断
## 建议动作

要求：
1. 只输出最终 Markdown，不要解释你的分析过程，不要复述用户要求。
2. 只基于截图中能确认的事实做判断，不要编造系统状态。
3. 每个小节最多 2 个短 bullet，总长度尽量控制在 220 个中文字符以内。
4. 明确指出当前是否存在会阻塞微信自动化的弹窗、文件选择器、权限提示、模态对话框、发送确认界面、下载确认界面或焦点丢失迹象。
5. 如果能识别具体控件，请点名控件位置和作用。
6. 建议动作最多 3 条，优先写可以立刻执行的 GUI 操作。
"""
if note.strip():
    prompt += f"\n补充上下文：{note.strip()}\n"

raw = monitor.analyze_images_with_ollama([image_path], prompt, base_url, model, api_key_env=api_key_env)
text = (raw or "").strip()
if not text:
    raise RuntimeError("视觉模型未返回诊断结果")
print(text)
PY
)"; then
  diagnosis_md=$(cat <<EOF
## 观察
- 已完成控件级截图并发送到微信群。
- 截图文件：$(basename "${captured_png}")

## 判断
- 自动视觉诊断失败，暂时无法生成结构化结论。

## 建议动作
- 检查视觉模型服务是否可用：${OLLAMA_URL}
- 检查模型名是否正确：${VISION_MODEL}
- 必要时改用本地可用模型后重试本脚本。
EOF
)
fi

diagnosis_md="$(
  python3 - "${diagnosis_md}" <<'PY'
import sys

raw = sys.argv[1].strip()
if len(raw) <= 600 and "## " in raw:
    print(raw)
    raise SystemExit(0)

sections = {"## 观察": [], "## 判断": [], "## 建议动作": []}
current = None
for raw_line in raw.splitlines():
    line = raw_line.strip()
    if not line:
        continue
    if line in sections:
        current = line
        continue
    if current and (line.startswith("- ") or line.startswith("* ")):
        sections[current].append(line.replace("* ", "- ", 1))
        continue
    if any(keyword in line for keyword in ("弹窗", "文件选择器", "输入框", "焦点", "工具栏", "按钮", "发送", "终端", "微信")):
        target = current or "## 观察"
        sections[target].append(f"- {line}")

for key in sections:
    deduped = []
    seen = set()
    for item in sections[key]:
        normalized = item.strip()
        if normalized and normalized not in seen:
            seen.add(normalized)
            deduped.append(normalized)
    sections[key] = deduped[:2]

if not any(sections.values()):
    print(raw[:500])
    raise SystemExit(0)

parts = []
for heading in ("## 观察", "## 判断", "## 建议动作"):
    parts.append(heading)
    items = sections[heading] or ["- 无法从当前截图提取稳定结论。"]
    parts.extend(items)
print("\n".join(parts))
PY
)"

python3 "${PYWXDUMP_ROOT}/tools/linux_wx_chat_daemon.py" \
  send-text \
  --target "${CHAT}" \
  --window-mode standalone \
  --text "${diagnosis_md}" \
  --post-send-delay-ms 1200 \
  --send-timeout 30 \
  --auto-resolve-target \
  --post-send-force-minimize \
  --display "${DISPLAY_VALUE}" \
  --xauthority "${XAUTHORITY_VALUE}"

printf 'diagnosis_image=%s\n' "${captured_png}"
