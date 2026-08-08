#!/usr/bin/env bash
set -euo pipefail

DEVICE="/dev/nvme0n1"
CONTROLLER="/dev/nvme0"
SEDUTIL=""

usage() {
  cat <<'EOF'
Usage:
  check_opal_state.sh [--device PATH] [--controller PATH] [--sedutil PATH]

Read-only checks:
  - root filesystem and block layout
  - NVMe security capabilities
  - TCG Opal state when sedutil-cli is available

This script never sets passwords, locks, resets, sanitizes, or formats a drive.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --device)
      DEVICE="${2:?missing value for --device}"
      shift 2
      ;;
    --controller)
      CONTROLLER="${2:?missing value for --controller}"
      shift 2
      ;;
    --sedutil)
      SEDUTIL="${2:?missing value for --sedutil}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown argument: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -z "${SEDUTIL}" ]]; then
  SEDUTIL="$(command -v sedutil-cli 2>/dev/null || true)"
fi

printf '%s\n' '--- root filesystem ---'
findmnt -no SOURCE,FSTYPE,OPTIONS /

printf '%s\n' '--- block layout ---'
lsblk -o NAME,PATH,SIZE,TYPE,FSTYPE,FSVER,MOUNTPOINTS,MODEL "${DEVICE}"

printf '%s\n' '--- NVMe security capabilities ---'
if command -v nvme >/dev/null 2>&1; then
  sudo -n nvme id-ctrl -H "${CONTROLLER}" 2>/dev/null |
    grep -Ei -C 3 'Security Send|Security Receive|sanicap|fna|oacs' || {
      printf '%s\n' 'Unable to read NVMe controller details with non-interactive sudo.'
    }
else
  printf '%s\n' 'nvme-cli is not installed.'
fi

printf '%s\n' '--- TCG Opal state ---'
if [[ -n "${SEDUTIL}" && -x "${SEDUTIL}" ]]; then
  sudo -n "${SEDUTIL}" --query "${DEVICE}" |
    sed -n \
      '/Locking function/,/Geometry function/p;/Block SID Authentication/,+2p'
else
  printf '%s\n' \
    'sedutil-cli not found. Build it in a disposable directory or pass --sedutil PATH.'
fi
