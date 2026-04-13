#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNNER="${SCRIPT_DIR}/lmstudio_auto_update.sh"
SAFE=0

usage() {
  cat <<'EOF'
用法:
  selftest.sh [--safe]
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --safe)
      SAFE=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "未知参数: $1" >&2
      exit 2
      ;;
  esac
done

echo "[selftest][lmstudio-auto-updater] runner=${RUNNER}"
bash "$RUNNER" help >/dev/null
bash "$RUNNER" status
bash "$RUNNER" check

if [ "$SAFE" -eq 1 ]; then
  echo "[selftest][lmstudio-auto-updater] safe 模式完成"
  exit 0
fi

LATEST_URL="$(bash "$RUNNER" check | awk -F= '/^latest_url=/{print $2}')"
[ -n "$LATEST_URL" ]
echo "[selftest][lmstudio-auto-updater] latest_url=${LATEST_URL}"
