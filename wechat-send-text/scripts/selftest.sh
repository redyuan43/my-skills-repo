#!/usr/bin/env bash
set -euo pipefail

SAFE_MODE=0
CHAT="${WECHAT_SEND_TEXT_SELFTEST_CHAT:-新技术讨论}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNNER="${SCRIPT_DIR}/send_wechat_text.sh"
SELFTEST_ID="wechat-send-text-$(date +%Y%m%d-%H%M%S)"
TEXT="[SELFTEST][wechat-send-text] ${SELFTEST_ID}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --safe)
      SAFE_MODE=1
      shift
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

if [[ "${SAFE_MODE}" -eq 1 ]]; then
  if [[ ! -d "/home/ivan/github/PyWxDump" ]]; then
    echo "safe skip: PyWxDump not found at /home/ivan/github/PyWxDump"
    exit 0
  fi
  OUTPUT="$("${RUNNER}" --chat "${CHAT}" --text "${TEXT}" --print-only)"
  printf '%s\n' "${OUTPUT}"
  printf '%s\n' "${OUTPUT}" | rg -q "Resolved window mode: standalone"
  printf '%s\n' "${OUTPUT}" | rg -q "Resolved PyWxDump:"
  printf '%s\n' "${OUTPUT}" | rg -q "Resolved python:"
  exit 0
fi

"${RUNNER}" --chat "${CHAT}" --text "${TEXT}"
