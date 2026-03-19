#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
RUNNER_PY="${SCRIPT_DIR}/send_text_with_setup.py"

KEY_FILE="${HOME}/.wx_db_keys.json"
OUTPUT_DIR="${HOME}/wx_decrypted"
DB_DIR=""
TARGET=""
TEXT=""
ALLOW_PTRACE_TOGGLE=0

usage() {
  cat <<'EOF'
用法:
  send_text_with_setup.sh --target NAME --text TEXT [--db-dir PATH] [--key-file PATH] [--output DIR] [--allow-ptrace-toggle]

说明:
  1. 自动定位 PyWxDump 仓库（或使用 PYWXDUMP_REPO_ROOT 指定）
  2. 必要时创建 .venv，并确保其中存在 pycryptodomex 和 Pillow
  3. 必要时提取微信数据库 key
  4. 解密 db_storage
  5. 进入交互式 bash 读取 ~/.bashrc 中的 OPENAI_API_KEY
  6. 走“搜索 + 视觉验标题 + 发送 + 数据库回读”链路
EOF
}

resolve_repo_root() {
  local candidates=()
  local candidate=""

  if [[ -n "${PYWXDUMP_REPO_ROOT:-}" ]]; then
    candidates+=("${PYWXDUMP_REPO_ROOT}")
  fi
  candidates+=("${PWD}")
  candidates+=("${HOME}/github/PyWxDump")
  candidates+=("${HOME}/PyWxDump")
  candidates+=("/home/ivan/github/PyWxDump")
  candidates+=("/home/dgx/github/PyWxDump")
  candidates+=("$(cd "${SKILL_DIR}/../.." && pwd)")

  for candidate in "${candidates[@]}"; do
    [[ -n "${candidate}" ]] || continue
    if [[ -f "${candidate}/tools/linux_wx_chat_daemon.py" ]]; then
      printf '%s\n' "${candidate}"
      return 0
    fi
  done

  return 1
}

REPO_ROOT="$(resolve_repo_root)" || {
  echo "未找到 PyWxDump 仓库。请先克隆仓库，或导出 PYWXDUMP_REPO_ROOT=/path/to/PyWxDump" >&2
  exit 1
}

VENV_DIR="${REPO_ROOT}/.venv"
VENV_PY="${VENV_DIR}/bin/python"
VENV_PIP="${VENV_DIR}/bin/pip"

ensure_venv() {
  if [[ -x "${VENV_PY}" && -x "${VENV_PIP}" ]]; then
    return 0
  fi
  python3 -m venv "${VENV_DIR}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)
      TARGET="$2"
      shift 2
      ;;
    --text)
      TEXT="$2"
      shift 2
      ;;
    --db-dir)
      DB_DIR="$2"
      shift 2
      ;;
    --key-file)
      KEY_FILE="$2"
      shift 2
      ;;
    --output)
      OUTPUT_DIR="$2"
      shift 2
      ;;
    --allow-ptrace-toggle)
      ALLOW_PTRACE_TOGGLE=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "未知参数: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -z "${TARGET}" || -z "${TEXT}" ]]; then
  usage >&2
  exit 2
fi

if [[ ! -f "${REPO_ROOT}/tools/linux_wx_chat_daemon.py" ]]; then
  echo "未找到 PyWxDump 发送入口: ${REPO_ROOT}/tools/linux_wx_chat_daemon.py" >&2
  exit 1
fi

find_latest_db_dir() {
  find "${HOME}/Documents/xwechat_files" -maxdepth 3 -type d -name db_storage -printf '%T@ %p\n' 2>/dev/null \
    | sort -nr \
    | head -n1 \
    | awk '{print $2}'
}

ensure_module() {
  local module_name="$1"
  local package_name="$2"
  if ! "${VENV_PY}" -c "import ${module_name}" >/dev/null 2>&1; then
    "${VENV_PIP}" install "${package_name}"
  fi
}

key_file_has_entries() {
  "${VENV_PY}" - "$1" <<'PY'
import json
import sys

path = sys.argv[1]
try:
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)
except Exception:
    raise SystemExit(1)

raise SystemExit(0 if isinstance(data, dict) and bool(data) else 1)
PY
}

extract_keys_if_needed() {
  local db_dir="$1"
  if key_file_has_entries "${KEY_FILE}"; then
    return 0
  fi

  local orig_ptrace
  orig_ptrace="$(cat /proc/sys/kernel/yama/ptrace_scope)"
  local restore_needed=0

  if [[ "${orig_ptrace}" != "0" ]]; then
    if [[ "${ALLOW_PTRACE_TOGGLE}" -ne 1 ]]; then
      echo "key 文件为空，且当前 ptrace_scope=${orig_ptrace}。请先确认风险后重试并传入 --allow-ptrace-toggle。" >&2
      exit 1
    fi
    sudo sysctl -w kernel.yama.ptrace_scope=0 >/dev/null
    restore_needed=1
    trap 'sudo sysctl -w kernel.yama.ptrace_scope='"${orig_ptrace}"' >/dev/null' EXIT
  fi

  "${VENV_PY}" "${REPO_ROOT}/tools/linux_get_wx_key.py" --db-dir "${db_dir}"

  if ! key_file_has_entries "${KEY_FILE}"; then
    echo "提取 key 后 ${KEY_FILE} 仍为空" >&2
    exit 1
  fi

  if [[ "${restore_needed}" -eq 1 ]]; then
    sudo sysctl -w kernel.yama.ptrace_scope="${orig_ptrace}" >/dev/null
    trap - EXIT
  fi
}

if [[ -z "${DB_DIR}" ]]; then
  DB_DIR="$(find_latest_db_dir)"
fi

if [[ -z "${DB_DIR}" || ! -d "${DB_DIR}" ]]; then
  echo "未找到可用的 db_storage，请用 --db-dir 指定" >&2
  exit 1
fi

ensure_venv
ensure_module "Cryptodome" "pycryptodomex"
ensure_module "PIL" "Pillow"

mkdir -p "$(dirname "${KEY_FILE}")"
if [[ ! -f "${KEY_FILE}" ]]; then
  printf '{}\n' > "${KEY_FILE}"
fi

extract_keys_if_needed "${DB_DIR}"
"${VENV_PY}" "${REPO_ROOT}/tools/linux_decrypt_wx_db.py" --key-file "${KEY_FILE}" --db-dir "${DB_DIR}" --output "${OUTPUT_DIR}"

export PYWXDUMP_REPO_ROOT="${REPO_ROOT}"
export PYWXDUMP_TARGET="${TARGET}"
export PYWXDUMP_TEXT="${TEXT}"
export PYWXDUMP_DB_DIR="${DB_DIR}"
export PYWXDUMP_KEY_FILE="${KEY_FILE}"
export PYWXDUMP_OUTPUT_DIR="${OUTPUT_DIR}"
export PYWXDUMP_VENV_PY="${VENV_PY}"

bash -ic 'cd "${PYWXDUMP_REPO_ROOT}" && "${PYWXDUMP_VENV_PY}" "'"${RUNNER_PY}"'"'
