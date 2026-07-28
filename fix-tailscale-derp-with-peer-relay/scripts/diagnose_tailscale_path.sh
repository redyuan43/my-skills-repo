#!/usr/bin/env bash
set -u

usage() {
  printf 'Usage: %s <tailscale-target> [ssh-alias]\n' "${0##*/}"
  printf 'Runs read-only Tailscale and SSH path diagnostics.\n'
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ $# -lt 1 || $# -gt 2 ]]; then
  usage >&2
  exit 2
fi

target="$1"
ssh_alias="${2:-}"

if ! command -v tailscale >/dev/null 2>&1; then
  printf 'ERROR: tailscale command not found.\n' >&2
  exit 127
fi

run_section() {
  local title="$1"
  shift
  printf '\n## %s\n' "$title"
  "$@" || printf 'WARN: command exited with status %s\n' "$?" >&2
}

run_section "Tailscale status" tailscale status
run_section "Ping target: ${target}" tailscale ping --c 3 "$target"
run_section "Local network characteristics" tailscale netcheck

if [[ -n "$ssh_alias" ]]; then
  if command -v ssh >/dev/null 2>&1; then
    run_section "Effective SSH configuration: ${ssh_alias}" \
      sh -c 'ssh -G -T -- "$1" | sed -n "/^hostname /p; /^user /p; /^port /p; /^proxyjump /p; /^proxycommand /p; /^connecttimeout /p"' \
      sh "$ssh_alias"
  else
    printf '\nWARN: ssh command not found; skipped effective SSH configuration.\n' >&2
  fi
fi

printf '\nInterpretation: compare this output with reverse-direction tests from the target and relay candidate.\n'
