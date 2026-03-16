#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="/home/ivan/github/PyWxDump"
KEY_FILE="${HOME}/.wx_db_keys.json"
OUTPUT_DIR="${HOME}/wx_decrypted"
DB_DIR=""
PID=""
KEY_ONLY=0
DECRYPT_ONLY=0

usage() {
  cat <<'EOF'
用法:
  run_linux_wx_decrypt.sh [--db-dir PATH] [--key-file PATH] [--output DIR] [--pid PID] [--key-only] [--decrypt-only]

说明:
  默认先提取 key，再批量解密数据库。
  本脚本不会自动修改 kernel.yama.ptrace_scope。
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --db-dir) DB_DIR="$2"; shift 2 ;;
    --key-file) KEY_FILE="$2"; shift 2 ;;
    --output) OUTPUT_DIR="$2"; shift 2 ;;
    --pid) PID="$2"; shift 2 ;;
    --key-only) KEY_ONLY=1; shift ;;
    --decrypt-only) DECRYPT_ONLY=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "未知参数: $1" >&2; usage; exit 2 ;;
  esac
done

if [[ ! -d "${REPO_ROOT}" ]]; then
  echo "未找到 PyWxDump 仓库: ${REPO_ROOT}" >&2
  exit 1
fi

cd "${REPO_ROOT}"

if [[ "${DECRYPT_ONLY}" -eq 0 ]]; then
  cmd=(python3 "tools/linux_get_wx_key.py" "--key-file" "${KEY_FILE}")
  if [[ -n "${DB_DIR}" ]]; then
    cmd+=("--db-dir" "${DB_DIR}")
  fi
  if [[ -n "${PID}" ]]; then
    cmd+=("--pid" "${PID}")
  fi
  "${cmd[@]}"
fi

if [[ "${KEY_ONLY}" -eq 1 ]]; then
  exit 0
fi

cmd=(python3 "tools/linux_decrypt_wx_db.py" "--key-file" "${KEY_FILE}" "--output" "${OUTPUT_DIR}")
if [[ -n "${DB_DIR}" ]]; then
  cmd+=("--db-dir" "${DB_DIR}")
fi
"${cmd[@]}"
