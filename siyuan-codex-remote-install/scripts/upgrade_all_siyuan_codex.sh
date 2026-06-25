#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

for arg in "$@"; do
  case "$arg" in
    -h|--help)
      exec "$script_dir/install_siyuan_codex_remote.sh" --help
      ;;
  esac
done

if [[ -z "${SIYUAN_NANO_PASSWORD:-}" ]]; then
  if [[ -t 0 ]]; then
    read -r -s -p "Nano password: " SIYUAN_NANO_PASSWORD
    echo
    export SIYUAN_NANO_PASSWORD
  else
    echo "Set SIYUAN_NANO_PASSWORD for password-only Nano hosts." >&2
    exit 2
  fi
fi

exec "$script_dir/install_siyuan_codex_remote.sh" --all "$@"
