#!/usr/bin/env bash
set -euo pipefail

HOST="http://127.0.0.1:11434"
MODEL="qwen3.5:latest"
IMAGE=""
PROMPT="请描述这张图片里有什么"
NUM_CTX="32768"
KEEP_ALIVE="4h"
REPEAT=1
STREAM_MODE="both"

usage() {
  cat <<USAGE
用法:
  $(basename "$0") --image "/abs/path/image.png" [选项]

选项:
  --model <name>        模型名 (默认: ${MODEL})
  --image <path>        图片路径 (必填)
  --prompt <text>       提示词 (默认: ${PROMPT})
  --ctx <num>           num_ctx (默认: ${NUM_CTX})
  --host <url>          Ollama 地址 (默认: ${HOST})
  --keep-alive <dur>    keep_alive (默认: ${KEEP_ALIVE})
  --repeat <n>          连续测试次数 (默认: ${REPEAT})
  --stream-mode <mode>  流式输出模式: both|answer|thinking|heartbeat (默认: ${STREAM_MODE})
  -h, --help            显示帮助
USAGE
}

require_cmd() {
  local c="$1"
  if ! command -v "$c" >/dev/null 2>&1; then
    echo "缺少命令: $c" >&2
    exit 1
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --model) MODEL="$2"; shift 2 ;;
    --image) IMAGE="$2"; shift 2 ;;
    --prompt) PROMPT="$2"; shift 2 ;;
    --ctx) NUM_CTX="$2"; shift 2 ;;
    --host) HOST="$2"; shift 2 ;;
    --keep-alive) KEEP_ALIVE="$2"; shift 2 ;;
    --repeat) REPEAT="$2"; shift 2 ;;
    --stream-mode) STREAM_MODE="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "未知参数: $1" >&2; usage; exit 1 ;;
  esac
done

require_cmd curl
require_cmd base64
require_cmd python3

if [[ -z "$IMAGE" ]]; then
  echo "错误: --image 必填" >&2
  usage
  exit 1
fi

if [[ ! -f "$IMAGE" ]]; then
  echo "错误: 图片不存在: $IMAGE" >&2
  exit 1
fi

if ! [[ "$NUM_CTX" =~ ^[0-9]+$ ]]; then
  echo "错误: --ctx 必须是整数" >&2
  exit 1
fi

if ! [[ "$REPEAT" =~ ^[0-9]+$ ]] || [[ "$REPEAT" -lt 1 ]]; then
  echo "错误: --repeat 必须是 >=1 的整数" >&2
  exit 1
fi

case "$STREAM_MODE" in
  both|answer|thinking|heartbeat) ;;
  *)
    echo "错误: --stream-mode 必须是 both|answer|thinking|heartbeat" >&2
    exit 1
    ;;
esac

printf "== 测试配置 ==\n"
printf "host        : %s\n" "$HOST"
printf "model       : %s\n" "$MODEL"
printf "image       : %s\n" "$IMAGE"
printf "num_ctx     : %s\n" "$NUM_CTX"
printf "repeat      : %s\n" "$REPEAT"
printf "keep_alive  : %s\n" "$KEEP_ALIVE"
printf "stream_mode : %s\n" "$STREAM_MODE"
printf "prompt      : %s\n\n" "$PROMPT"

if ! curl -fsS --max-time 5 "$HOST/api/tags" >/dev/null; then
  echo "错误: Ollama 服务不可用，请先启动后台服务并确认 $HOST 可访问" >&2
  exit 1
fi

for i in $(seq 1 "$REPEAT"); do
  B64_FILE=$(mktemp)
  PAYLOAD_FILE=$(mktemp)
  PARSER_FILE=$(mktemp)

  cleanup() {
    rm -f "$B64_FILE" "$PAYLOAD_FILE" "$PARSER_FILE"
  }
  trap cleanup EXIT

  base64 -w 0 "$IMAGE" > "$B64_FILE"

  printf '{"model":"%s","stream":true,"keep_alive":"%s","options":{"num_ctx":%s},"messages":[{"role":"user","content":"' "$MODEL" "$KEEP_ALIVE" "$NUM_CTX" > "$PAYLOAD_FILE"
  printf '%s' "$PROMPT" >> "$PAYLOAD_FILE"
  printf '","images":["' >> "$PAYLOAD_FILE"
  cat "$B64_FILE" >> "$PAYLOAD_FILE"
  printf '"]}]}' >> "$PAYLOAD_FILE"

  cat > "$PARSER_FILE" <<'PY'
import json
import sys
import time

mode = sys.argv[1]
final = None
http_code = "n/a"
api_error = ""

think_started = False
answer_started = False
last_heartbeat = 0.0

def print_heartbeat(force=False):
    global last_heartbeat
    now = time.time()
    if force or (now - last_heartbeat >= 5):
        print("[heartbeat] 推理进行中...", flush=True)
        last_heartbeat = now

for raw in sys.stdin:
    line = raw.rstrip("\n")
    if not line:
        continue
    if line.startswith("__HTTP_CODE__:"):
        http_code = line.split(":", 1)[1].strip()
        continue
    try:
        d = json.loads(line)
    except Exception:
        continue

    if "error" in d:
        api_error = str(d["error"])
        print(f"api_error           : {api_error}", flush=True)
        continue

    msg = d.get("message", {})
    thinking = msg.get("thinking", "")
    content = msg.get("content", "")

    if mode in ("both", "thinking") and thinking:
        if not think_started:
            print("[thinking] ", end="", flush=True)
            think_started = True
        print(thinking, end="", flush=True)
    if mode in ("both", "answer") and content:
        if not answer_started:
            if think_started:
                print("", flush=True)
            print("[answer] ", end="", flush=True)
            answer_started = True
        print(content, end="", flush=True)
    if mode == "heartbeat":
        print_heartbeat()

    if d.get("done") is True:
        final = d

if think_started or answer_started:
    print("", flush=True)
if mode == "heartbeat":
    print_heartbeat(force=True)

def ns_to_s(v):
    if not isinstance(v, int) or v <= 0:
        return "n/a"
    return f"{v / 1e9:.3f}s"

def tps(tokens, ns):
    if not isinstance(tokens, int) or not isinstance(ns, int) or ns <= 0:
        return "n/a"
    return f"{tokens / (ns / 1e9):.2f} tok/s"

if final is None:
    print(f"http_code           : {http_code}")
    print("done                : n/a")
    print("answer_preview      : n/a")
    print("total_duration      : n/a")
    print("load_duration       : n/a")
    print("prompt_eval_count   : n/a")
    print("prompt_eval_duration: n/a")
    print("eval_count          : n/a")
    print("eval_duration       : n/a")
    print("prompt_speed        : n/a")
    print("decode_speed        : n/a")
    sys.exit(1 if api_error else 0)

msg = final.get("message", {}).get("content", "")
msg = msg.replace("\n", " ").strip()
if len(msg) > 140:
    msg = msg[:140] + "..."

print(f"http_code           : {http_code}")
print(f"done                : {final.get('done')}")
print(f"answer_preview      : {msg}")
print(f"total_duration      : {ns_to_s(final.get('total_duration'))}")
print(f"load_duration       : {ns_to_s(final.get('load_duration'))}")
print(f"prompt_eval_count   : {final.get('prompt_eval_count', 'n/a')}")
print(f"prompt_eval_duration: {ns_to_s(final.get('prompt_eval_duration'))}")
print(f"eval_count          : {final.get('eval_count', 'n/a')}")
print(f"eval_duration       : {ns_to_s(final.get('eval_duration'))}")
print(f"prompt_speed        : {tps(final.get('prompt_eval_count'), final.get('prompt_eval_duration'))}")
print(f"decode_speed        : {tps(final.get('eval_count'), final.get('eval_duration'))}")
PY

  printf -- "---- Run %s ----\n" "$i"
  START_MS=$(date +%s%3N)
  set +e
  curl -sS --no-buffer "$HOST/api/chat" \
    -H "Content-Type: application/json" \
    -d @"$PAYLOAD_FILE" \
    -w '\n__HTTP_CODE__:%{http_code}\n' \
    | python3 "$PARSER_FILE" "$STREAM_MODE"
  PIPE_EXIT=("${PIPESTATUS[@]}")
  CURL_PIPE_EXIT=${PIPE_EXIT[0]:-1}
  PARSER_EXIT=${PIPE_EXIT[1]:-1}
  set -e

  END_MS=$(date +%s%3N)
  WALL_MS=$((END_MS - START_MS))
  printf "wall_time_ms        : %s\n" "$WALL_MS"

  if command -v tegrastats >/dev/null 2>&1; then
    TG_LINE=$(timeout 2 tegrastats 2>/dev/null | head -n 1 || true)
    if [[ -n "$TG_LINE" ]]; then
      printf "tegrastats          : %s\n" "$TG_LINE"
    else
      printf "tegrastats          : n/a\n"
    fi
  else
    printf "tegrastats          : n/a\n"
  fi

  AVAIL_MEM=$(free -m | awk '/Mem:/ {print $7 " MB"}')
  printf "mem_available       : %s\n\n" "$AVAIL_MEM"

  if [[ "$CURL_PIPE_EXIT" -ne 0 ]]; then
    echo "错误: curl 请求失败，退出码: $CURL_PIPE_EXIT" >&2
    exit "$CURL_PIPE_EXIT"
  fi
  if [[ "$PARSER_EXIT" -ne 0 ]]; then
    echo "错误: 流式响应解析失败，退出码: $PARSER_EXIT" >&2
    exit "$PARSER_EXIT"
  fi

  cleanup
  trap - EXIT
done
