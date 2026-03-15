#!/usr/bin/env bash
set -euo pipefail

SERVICE_NAME="${1:-ollama}"
DROPIN_FILE="/etc/systemd/system/${SERVICE_NAME}.service.d/10-gpu-selection.conf"

if [[ "${EUID}" -ne 0 ]]; then
  exec sudo --preserve-env=PATH bash "$0" "$@"
fi

if ! command -v systemctl >/dev/null 2>&1; then
  echo "systemctl not found"
  exit 1
fi

if ! systemctl cat "${SERVICE_NAME}.service" >/dev/null 2>&1; then
  echo "Service not found: ${SERVICE_NAME}.service"
  exit 1
fi

if [[ -f "${DROPIN_FILE}" ]]; then
  rm -f "${DROPIN_FILE}"
  echo "Removed drop-in file: ${DROPIN_FILE}"
else
  echo "No drop-in file found: ${DROPIN_FILE}"
fi

systemctl daemon-reload
systemctl restart "${SERVICE_NAME}"

echo "Rolled back GPU pinning for ${SERVICE_NAME}.service"
