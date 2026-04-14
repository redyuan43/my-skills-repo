#!/usr/bin/env bash
set -euo pipefail

resolve_repo_root() {
  if [[ -n "${PYWXDUMP_REPO_ROOT:-}" && -d "${PYWXDUMP_REPO_ROOT}" ]]; then
    printf '%s\n' "${PYWXDUMP_REPO_ROOT}"
    return 0
  fi

  if [[ -f "./tools/install_obsidian_vault_shortcut.py" ]]; then
    pwd
    return 0
  fi

  if [[ -d "$HOME/github/PyWxDump" && -f "$HOME/github/PyWxDump/tools/install_obsidian_vault_shortcut.py" ]]; then
    printf '%s\n' "$HOME/github/PyWxDump"
    return 0
  fi

  return 1
}

REPO_ROOT="$(resolve_repo_root)"
PYTHON_BIN="${PYWXDUMP_SHORTCUT_PYTHON:-}"
if [[ -z "${PYTHON_BIN}" ]]; then
  if [[ -x "${REPO_ROOT}/.venv/bin/python" ]]; then
    PYTHON_BIN="${REPO_ROOT}/.venv/bin/python"
  else
    PYTHON_BIN="python3"
  fi
fi

exec "${PYTHON_BIN}" "${REPO_ROOT}/tools/install_obsidian_vault_shortcut.py" "$@"
