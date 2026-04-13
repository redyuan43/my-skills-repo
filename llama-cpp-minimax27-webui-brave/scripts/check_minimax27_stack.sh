#!/usr/bin/env bash
set -euo pipefail

SERVER_URL="${1:-http://127.0.0.1:8093}"
MCP_URL="${2:-http://127.0.0.1:8765/healthz}"

printf 'BRAVE_MCP_HEALTH '\ncurl -fsS "$MCP_URL"
printf '\nSERVER_HEALTH '\ncurl -fsS "$SERVER_URL/health"
printf '\n\nSAMPLE_CHAT\n'
curl -fsS "$SERVER_URL/v1/chat/completions" \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "minimax-m2.7",
    "messages": [
      {"role": "user", "content": "请先思考，再用中文一句话回答：1+1等于几？"}
    ],
    "stream": false,
    "temperature": 1.0,
    "top_p": 0.95,
    "top_k": 40,
    "reasoning_format": "none"
  }'
printf '\n'
