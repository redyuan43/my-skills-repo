#!/usr/bin/env bash
set -euo pipefail

# Supported non-destructive mode: --safe
if [[ "${1:-}" != "--safe" ]]; then
  printf 'Usage: %s --safe\n' "${0##*/}" >&2
  exit 2
fi

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
diagnostic_script="${script_dir}/diagnose_tailscale_path.sh"

bash -n "$diagnostic_script"
output="$($diagnostic_script --help)"

if [[ "$output" != *"Runs read-only Tailscale and SSH path diagnostics."* ]]; then
  printf 'ERROR: diagnostic help output is incomplete.\n' >&2
  exit 1
fi

printf 'PASS: syntax and read-only help path validated.\n'
