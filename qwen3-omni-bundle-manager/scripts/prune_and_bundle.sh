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

if [[ "${1:-}" == "--verify" ]]; then
  shift
  exec "$ROOT_DIR/scripts/verify_usable_bundle.sh" "$@"
fi

if [[ "${1:-}" == "--dry-run" ]]; then
  exec "$ROOT_DIR/scripts/prune_model_cache.sh"
fi

if [[ "${1:-}" == "--apply-prune" ]]; then
  "$ROOT_DIR/scripts/stop_model_server.sh"
  "$ROOT_DIR/scripts/stop_api_server.sh"
  "$ROOT_DIR/scripts/prune_model_cache.sh" --apply
  exec "$ROOT_DIR/scripts/create_usable_bundle.sh"
fi

echo "Usage:" >&2
echo "  $0 --dry-run" >&2
echo "  $0 --apply-prune" >&2
echo "  $0 --verify dist/Qwen3-Omni-gptq4-usable-<timestamp>.tar.zst" >&2
exit 1
