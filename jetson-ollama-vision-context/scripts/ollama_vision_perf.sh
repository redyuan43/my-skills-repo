#!/usr/bin/env bash
set -euo pipefail

HOST="http://127.0.0.1:11434"
MODEL="qwen3.5:latest"
IMAGE=""
PROMPT="请描述这张图片里有什么"
NUM_CTX="32768"
KEEP_ALIVE="4h"
REPEAT=1

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

printf "== 测试配置 ==\n"
printf "host        : %s\n" "$HOST"
printf "model       : %s\n" "$MODEL"
printf "image       : %s\n" "$IMAGE"
printf "num_ctx     : %s\n" "$NUM_CTX"
printf "repeat      : %s\n" "$REPEAT"
printf "keep_alive  : %s\n" "$KEEP_ALIVE"
printf "prompt      : %s\n\n" "$PROMPT"

for i in $(seq 1 "$REPEAT"); do
  B64_FILE=$(mktemp)
  PAYLOAD_FILE=$(mktemp)
  RESP_FILE=$(mktemp)

  cleanup() {
    rm -f "$B64_FILE" "$PAYLOAD_FILE" "$RESP_FILE"
  }
  trap cleanup EXIT

  base64 -w 0 "$IMAGE" > "$B64_FILE"

  printf '{"model":"%s","stream":false,"keep_alive":"%s","options":{"num_ctx":%s},"messages":[{"role":"user","content":"' "$MODEL" "$KEEP_ALIVE" "$NUM_CTX" > "$PAYLOAD_FILE"
  printf '%s' "$PROMPT" >> "$PAYLOAD_FILE"
  printf '","images":["' >> "$PAYLOAD_FILE"
  cat "$B64_FILE" >> "$PAYLOAD_FILE"
  printf '"]}]}' >> "$PAYLOAD_FILE"

  START_MS=$(date +%s%3N)
  HTTP_CODE=$(curl -sS "$HOST/api/chat" \
    -H "Content-Type: application/json" \
    -d @"$PAYLOAD_FILE" \
    -o "$RESP_FILE" \
    -w "%{http_code}")
  END_MS=$(date +%s%3N)
  WALL_MS=$((END_MS - START_MS))

  printf -- "---- Run %s ----\n" "$i"
  printf "http_code           : %s\n" "$HTTP_CODE"
  printf "wall_time_ms        : %s\n" "$WALL_MS"

  python3 - "$RESP_FILE" <<'PY'
import json
import sys

path = sys.argv[1]
try:
    with open(path, 'r', encoding='utf-8') as f:
        d = json.load(f)
except Exception as e:
    print(f"parse_error         : {e}")
    sys.exit(0)

if 'error' in d:
    print(f"api_error           : {d['error']}")
    sys.exit(0)

def ns_to_s(v):
    if not isinstance(v, int) or v <= 0:
        return "n/a"
    return f"{v / 1e9:.3f}s"

def tps(tokens, ns):
    if not isinstance(tokens, int) or not isinstance(ns, int) or ns <= 0:
        return "n/a"
    return f"{tokens / (ns / 1e9):.2f} tok/s"

msg = d.get('message', {}).get('content', '')
msg = msg.replace('\n', ' ').strip()
if len(msg) > 140:
    msg = msg[:140] + '...'

print(f"done                : {d.get('done')}")
print(f"answer_preview      : {msg}")
print(f"total_duration      : {ns_to_s(d.get('total_duration'))}")
print(f"load_duration       : {ns_to_s(d.get('load_duration'))}")
print(f"prompt_eval_count   : {d.get('prompt_eval_count', 'n/a')}")
print(f"prompt_eval_duration: {ns_to_s(d.get('prompt_eval_duration'))}")
print(f"eval_count          : {d.get('eval_count', 'n/a')}")
print(f"eval_duration       : {ns_to_s(d.get('eval_duration'))}")
print(f"prompt_speed        : {tps(d.get('prompt_eval_count'), d.get('prompt_eval_duration'))}")
print(f"decode_speed        : {tps(d.get('eval_count'), d.get('eval_duration'))}")
PY

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

  cleanup
  trap - EXIT
done
