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
check_file "scripts/download_bilibili.py"
check_file "references/failure_taxonomy.md"
check_file "eval/val/items.json"

bash -n "$ROOT/scripts/selftest.sh"
python3 -m py_compile "$ROOT/scripts/download_bilibili.py"
python3 -m json.tool "$ROOT/eval/val/items.json" >/dev/null

check_contains "SKILL.md" "cookies|登录态|browser-profile"
check_contains "SKILL.md" "failure_taxonomy"
check_contains "references/failure_taxonomy.md" "412"
check_contains "references/failure_taxonomy.md" "产物 Gate"

command -v yt-dlp >/dev/null 2>&1 || echo "warning: optional dependency not found: yt-dlp" >&2

[ "$FAILURES" -eq 0 ] || { echo "selftest failed: $FAILURES issue(s)" >&2; exit 1; }
echo "selftest passed"
