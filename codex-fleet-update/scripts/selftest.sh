#!/usr/bin/env bash
set -euo pipefail

# Supports --safe mode without network access or remote mutations.
if (($# > 1)) || (($# == 1)) && [[ "$1" != "--safe" ]]; then
  echo "Usage: selftest.sh [--safe]" >&2
  exit 2
fi

skill_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
updater="$skill_root/scripts/codex-update.sh"
required_commands=(flock gh rsync sha256sum ssh)
missing=()

bash -n "$updater"
"$updater" --help >/dev/null

if command -v shellcheck >/dev/null 2>&1; then
  shellcheck "$updater"
fi

for command_name in "${required_commands[@]}"; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    missing+=("$command_name")
  fi
done

if ((${#missing[@]})); then
  printf 'Missing required controller commands: %s\n' "${missing[*]}" >&2
  exit 1
fi

echo "codex-fleet-update self-test passed"
