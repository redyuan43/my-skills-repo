#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd -P)"
TARGET="${REPO_ROOT}/jetson-gpu-fan-guard/scripts/install_jetson_gpu_fan_guard.sh"

if [[ ! -f "${TARGET}" ]]; then
  printf 'Error: missing target script: %s\n' "${TARGET}" >&2
  exit 1
fi

exec bash "${TARGET}" "$@"
