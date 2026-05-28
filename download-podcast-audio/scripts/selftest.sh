#!/usr/bin/env bash
set -euo pipefail

# Supports --safe mode.

SAFE=0
for arg in "$@"; do
  case "$arg" in
    --safe) SAFE=1 ;;
    -h|--help) echo "usage: selftest.sh --safe"; exit 0 ;;
    *) echo "unknown argument: $arg" >&2; exit 2 ;;
  esac
done

[ "$SAFE" -eq 1 ] || { echo "refusing non-safe run; use --safe" >&2; exit 2; }

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAILURES=0
check_file() { [ -f "$ROOT/$1" ] || { echo "missing file: $1" >&2; FAILURES=$((FAILURES + 1)); }; }
check_contains() { rg -q "$2" "$ROOT/$1" || { echo "missing pattern in $1: $2" >&2; FAILURES=$((FAILURES + 1)); }; }

check_file "SKILL.md"
check_file "scripts/download_podcast.py"
check_file "references/presets.md"
check_file "references/failure_taxonomy.md"
check_file "eval/val/items.json"

bash -n "$ROOT/scripts/selftest.sh"
python3 -m py_compile "$ROOT/scripts/download_podcast.py"
python3 -m json.tool "$ROOT/eval/val/items.json" >/dev/null

check_contains "SKILL.md" "cookies|登录态"
check_contains "SKILL.md" "failure_taxonomy"
check_contains "references/failure_taxonomy.md" "Generic Extractor"
check_contains "references/failure_taxonomy.md" "产物 Gate"

for cmd in yt-dlp ffmpeg; do
  command -v "$cmd" >/dev/null 2>&1 || echo "warning: optional dependency not found: $cmd" >&2
done

[ "$FAILURES" -eq 0 ] || { echo "selftest failed: $FAILURES issue(s)" >&2; exit 1; }
echo "selftest passed"
