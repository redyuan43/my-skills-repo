#!/usr/bin/env bash
set -euo pipefail

resolve_repo_root() {
  if [[ -n "${PYWXDUMP_REPO_ROOT:-}" && -d "${PYWXDUMP_REPO_ROOT}" ]]; then
    printf '%s\n' "${PYWXDUMP_REPO_ROOT}"
    return 0
  fi

  if [[ -f "./tools/bootstrap_linux_wechat_stack.py" ]]; then
    pwd
    return 0
  fi

  if [[ -d "$HOME/github/PyWxDump" && -f "$HOME/github/PyWxDump/tools/bootstrap_linux_wechat_stack.py" ]]; then
    printf '%s\n' "$HOME/github/PyWxDump"
    return 0
  fi

  return 1
}

REPO_ROOT="$(resolve_repo_root)"
PYTHON_BIN="${PYWXDUMP_BOOTSTRAP_PYTHON:-}"
if [[ -z "${PYTHON_BIN}" ]]; then
  if [[ -x "${REPO_ROOT}/.venv/bin/python" ]]; then
    PYTHON_BIN="${REPO_ROOT}/.venv/bin/python"
  else
    PYTHON_BIN="python3"
  fi
fi

exec "${PYTHON_BIN}" "${REPO_ROOT}/tools/bootstrap_linux_wechat_stack.py" "$@"
