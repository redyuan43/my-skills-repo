#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

resolve_project_root() {
  if [[ -n "${QWEN_OMNI_PROJECT_ROOT:-}" ]]; then
    printf '%s\n' "$QWEN_OMNI_PROJECT_ROOT"
    return
  fi

  local probe="$SCRIPT_DIR"
  while [[ "$probe" != "/" ]]; do
    if [[ -f "$probe/pyproject.toml" && -d "$probe/src/qwen_omni_stack" ]]; then
      printf '%s\n' "$probe"
      return
    fi
    probe="$(dirname "$probe")"
  done

  echo "Set QWEN_OMNI_PROJECT_ROOT to the local Qwen3-Omni repository path." >&2
  exit 1
}

ROOT_DIR="$(resolve_project_root)"
CLIENT="$ROOT_DIR/.venv/bin/qwen-omni-client"

if [[ ! -x "$CLIENT" ]]; then
  echo "Client not found: $CLIENT" >&2
  exit 1
fi

if [[ "${1:-}" == "ping" ]]; then
  exec "$CLIENT" ping --server "http://127.0.0.1:8000"
fi

if ! curl -fsS "http://127.0.0.1:8000/readyz" >/dev/null; then
  echo "Wrapper is not ready at http://127.0.0.1:8000/readyz" >&2
  exit 1
fi

exec "$CLIENT" "$@"
