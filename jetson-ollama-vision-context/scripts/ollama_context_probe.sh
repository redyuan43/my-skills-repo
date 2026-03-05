#!/usr/bin/env bash
set -euo pipefail

HOST="http://127.0.0.1:11434"
MODEL="qwen3.5:latest"
CTX_LIST="4096,8192,16384,24576,32768"
PROMPT="只回复OK"

usage() {
  cat <<USAGE
用法:
  $(basename "$0") [选项]

选项:
  --model <name>       模型名 (默认: ${MODEL})
  --ctx-list <csv>     上下文列表，逗号分隔 (默认: ${CTX_LIST})
  --host <url>         Ollama 地址 (默认: ${HOST})
  --prompt <text>      测试提示词 (默认: ${PROMPT})
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --model) MODEL="$2"; shift 2 ;;
    --ctx-list) CTX_LIST="$2"; shift 2 ;;
    --host) HOST="$2"; shift 2 ;;
    --prompt) PROMPT="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "未知参数: $1" >&2; usage; exit 1 ;;
  esac
done

command -v curl >/dev/null || { echo "缺少 curl" >&2; exit 1; }
command -v python3 >/dev/null || { echo "缺少 python3" >&2; exit 1; }

echo "model: $MODEL"
echo "ctx_list: $CTX_LIST"

IFS=',' read -r -a LIST <<< "$CTX_LIST"

for C in "${LIST[@]}"; do
  C="$(echo "$C" | xargs)"
  [[ -z "$C" ]] && continue
  [[ "$C" =~ ^[0-9]+$ ]] || { echo "skip invalid ctx: $C"; continue; }

  PAYLOAD=$(printf '{"model":"%s","stream":false,"keep_alive":"4h","options":{"num_ctx":%s},"messages":[{"role":"user","content":"%s"}]}' "$MODEL" "$C" "$PROMPT")
  RESP_FILE=$(mktemp)
  HTTP_CODE=$(curl -sS "$HOST/api/chat" \
    -H "Content-Type: application/json" \
    -d "$PAYLOAD" \
    -o "$RESP_FILE" \
    -w "%{http_code}")

  echo "--- num_ctx=$C ---"
  echo "http_code: $HTTP_CODE"
  if [[ "$HTTP_CODE" != "200" ]]; then
    echo "status: fail"
    echo "error : http $HTTP_CODE"
    if [[ -s "$RESP_FILE" ]]; then
      head -c 300 "$RESP_FILE"; echo
    fi
    rm -f "$RESP_FILE"
    continue
  fi

  python3 - "$RESP_FILE" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as f:
    resp = f.read()
try:
    d = json.loads(resp)
except Exception as e:
    print('parse_error:', e)
    raise SystemExit(0)

if 'error' in d:
    print('status: fail')
    print('error :', d.get('error'))
else:
    print('status:', 'ok' if d.get('done') else 'unknown')
    print('total :', f"{d.get('total_duration', 0)/1e9:.3f}s" if isinstance(d.get('total_duration'), int) else 'n/a')
    print('load  :', f"{d.get('load_duration', 0)/1e9:.3f}s" if isinstance(d.get('load_duration'), int) else 'n/a')
PY
  rm -f "$RESP_FILE"

  if command -v ollama >/dev/null 2>&1; then
    ollama ps | sed -n '1,3p'
  fi
  if command -v free >/dev/null 2>&1; then
    free -m | awk '/Mem:/ {print "mem_available: "$7" MB"}'
  fi
done
