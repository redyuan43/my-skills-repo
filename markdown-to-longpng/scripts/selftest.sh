#!/usr/bin/env bash
set -euo pipefail

# Supports --safe and --local-smoke modes.

SAFE=0
LOCAL_SMOKE=0
for arg in "$@"; do
  case "$arg" in
    --safe) SAFE=1 ;;
    --local-smoke) LOCAL_SMOKE=1 ;;
    -h|--help) echo "usage: selftest.sh --safe [--local-smoke]"; exit 0 ;;
    *) echo "unknown argument: $arg" >&2; exit 2 ;;
  esac
done

[ "$SAFE" -eq 1 ] || { echo "refusing non-safe run; use --safe" >&2; exit 2; }

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="$(mktemp -d -t md-longpng-selftest.XXXXXX)"
cleanup() { rm -rf "$WORK_DIR"; }
trap cleanup EXIT

FAILURES=0
check_file() { [ -f "$ROOT/$1" ] || { echo "missing file: $1" >&2; FAILURES=$((FAILURES + 1)); }; }
check_contains() { rg -q "$2" "$ROOT/$1" || { echo "missing pattern in $1: $2" >&2; FAILURES=$((FAILURES + 1)); }; }

check_file "SKILL.md"
check_file "scripts/md_to_longpng.sh"
check_file "references/output_gate.md"

bash -n "$ROOT/scripts/md_to_longpng.sh"
bash -n "$ROOT/scripts/selftest.sh"
check_contains "SKILL.md" "Verification|验证"
check_contains "SKILL.md" "output_gate"
check_contains "references/output_gate.md" "PNG"

if [ "$LOCAL_SMOKE" -eq 0 ]; then
  [ "$FAILURES" -eq 0 ] || { echo "selftest failed: $FAILURES issue(s)" >&2; exit 1; }
  echo "safe selftest passed"
  exit 0
fi

cat >"$WORK_DIR/input.md" <<'MD'
# Selftest

This is a minimal markdown-to-longpng smoke document.
MD

export npm_config_cache="$WORK_DIR/npm-cache"
LONGPNG_VIEWPORT_SIZE=800,600 "$ROOT/scripts/md_to_longpng.sh" "$WORK_DIR/input.md" "$WORK_DIR/output.png" >/dev/null

[ -s "$WORK_DIR/output.png" ] || { echo "empty PNG output" >&2; exit 1; }
file_output="$(file "$WORK_DIR/output.png")"
printf '%s\n' "$file_output" | rg -q "PNG image data" || { echo "output is not a PNG" >&2; exit 1; }
dimensions="$(printf '%s\n' "$file_output" | sed -nE 's/.*PNG image data, ([0-9]+) x ([0-9]+).*/\1 \2/p')"
width="${dimensions%% *}"
height="${dimensions##* }"
[ "${width:-0}" -gt 0 ] && [ "${height:-0}" -gt 0 ] || { echo "invalid PNG dimensions" >&2; exit 1; }

[ "$FAILURES" -eq 0 ] || { echo "selftest failed: $FAILURES issue(s)" >&2; exit 1; }
echo "selftest passed"
