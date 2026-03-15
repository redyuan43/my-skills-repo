#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "Usage: $0 <gpu-uuid> [service-name]"
  exit 1
fi

GPU_UUID="$1"
SERVICE_NAME="${2:-ollama}"
DROPIN_DIR="/etc/systemd/system/${SERVICE_NAME}.service.d"
DROPIN_FILE="${DROPIN_DIR}/10-gpu-selection.conf"

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

if command -v nvidia-smi >/dev/null 2>&1; then
  if ! nvidia-smi -L | grep -Fq "${GPU_UUID}"; then
    echo "GPU UUID not found: ${GPU_UUID}"
    exit 1
  fi
fi

mkdir -p "${DROPIN_DIR}"

cat > "${DROPIN_FILE}" <<EOF
[Service]
Environment="CUDA_VISIBLE_DEVICES=${GPU_UUID}"
EOF

systemctl daemon-reload
systemctl restart "${SERVICE_NAME}"

echo "Applied GPU pinning for ${SERVICE_NAME}.service"
echo "CUDA_VISIBLE_DEVICES=${GPU_UUID}"
echo "Drop-in file: ${DROPIN_FILE}"
