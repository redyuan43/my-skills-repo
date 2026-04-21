#!/usr/bin/env bash
set -euo pipefail

echo "[Onyx]"
curl -I --max-time 10 http://127.0.0.1:3000 || true

echo
echo "[LM Studio OpenAI /v1/models]"
curl -sS --max-time 10 http://127.0.0.1:1234/v1/models || true

echo
echo "[LM Studio native /api/v1/models]"
curl -sS --max-time 10 http://127.0.0.1:1234/api/v1/models || true

echo
echo "[Ollama /api/tags]"
curl -sS --max-time 10 http://127.0.0.1:11434/api/tags || true

echo
echo "[Listening ports]"
ss -ltnp | grep -E ':3000\\b|:1234\\b|:11434\\b' || true
