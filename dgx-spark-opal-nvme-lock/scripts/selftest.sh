#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECKER="${SCRIPT_DIR}/check_opal_state.sh"

usage() {
  cat <<'EOF'
Usage:
  selftest.sh [--safe]

--safe performs static, non-destructive checks only.
EOF
}

case "${1:---safe}" in
  --safe)
    bash -n "${CHECKER}"
    bash -n "${BASH_SOURCE[0]}"
    "${CHECKER}" --help >/dev/null
    printf '%s\n' 'safe selftest passed'
    ;;
  -h|--help)
    usage
    ;;
  *)
    printf 'Unknown argument: %s\n' "$1" >&2
    usage >&2
    exit 2
    ;;
esac
