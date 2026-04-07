#!/usr/bin/env bash
set -euo pipefail

LMSTUDIO_DIR="${LMSTUDIO_DIR:-$HOME/.lmstudio}"
CREDENTIALS_FILE="${LMSTUDIO_DIR}/credentials/brave-search.env"

if [[ -f "${CREDENTIALS_FILE}" ]]; then
  # shellcheck disable=SC1090
  source "${CREDENTIALS_FILE}"
fi

if [[ -z "${BRAVE_API_KEY:-}" || "${BRAVE_API_KEY}" == "YOUR_BRAVE_API_KEY" ]]; then
  echo "Error: BRAVE_API_KEY is missing. Fill ${CREDENTIALS_FILE} first." >&2
  exit 1
fi

exec npx -y @modelcontextprotocol/server-brave-search
