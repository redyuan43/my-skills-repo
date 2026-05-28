#!/usr/bin/env bash
set -euo pipefail

# Supports --safe mode.

SAFE=0
for arg in "$@"; do
  case "$arg" in
    --safe) SAFE=1 ;;
    -h|--help)
      echo "usage: selftest.sh --safe"
      exit 0
      ;;
    *)
      echo "unknown argument: $arg" >&2
      exit 2
      ;;
  esac
done

if [ "$SAFE" -ne 1 ]; then
  echo "refusing non-safe run; use --safe" >&2
  exit 2
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAILURES=0

check_file() {
  if [ ! -f "$ROOT/$1" ]; then
    echo "missing file: $1" >&2
    FAILURES=$((FAILURES + 1))
  fi
}

check_contains() {
  local file="$1"
  local pattern="$2"
  if ! rg -q "$pattern" "$ROOT/$file"; then
    echo "missing pattern in $file: $pattern" >&2
    FAILURES=$((FAILURES + 1))
  fi
}

check_file "SKILL.md"
check_file "references/runbook.md"
check_file "assets/vncserver-headless.service"
check_file "assets/xstartup"
check_file "assets/xfce4-session.xml"
check_file "scripts/vnc_audio_server_setup.sh"
check_file "scripts/vnc_audio_status.sh"
check_file "scripts/vnc_audio_client_attach.sh"
check_file "scripts/vnc_session_poststart.sh"

for script in "$ROOT"/scripts/*.sh; do
  bash -n "$script"
done

for placeholder in "__USER__" "__HOME__" "__DISPLAY__" "__GEOMETRY__" "__DEPTH__"; do
  check_contains "assets/vncserver-headless.service" "$placeholder"
done

check_contains "SKILL.md" "确认 Gate"
check_contains "SKILL.md" "references/runbook.md"
check_contains "references/runbook.md" "PulseAudio"
check_contains "references/runbook.md" "5901|4713"

for cmd in vncviewer parec pacat pactl; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "warning: optional dependency not found: $cmd" >&2
  fi
done

if [ "$FAILURES" -ne 0 ]; then
  echo "selftest failed: $FAILURES issue(s)" >&2
  exit 1
fi

echo "selftest passed"
