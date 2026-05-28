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
WORK_DIR="$(mktemp -d -t md-mobile-pdf-selftest.XXXXXX)"
cleanup() { rm -rf "$WORK_DIR"; }
trap cleanup EXIT

FAILURES=0
check_file() { [ -f "$ROOT/$1" ] || { echo "missing file: $1" >&2; FAILURES=$((FAILURES + 1)); }; }
check_contains() { rg -q "$2" "$ROOT/$1" || { echo "missing pattern in $1: $2" >&2; FAILURES=$((FAILURES + 1)); }; }

check_file "SKILL.md"
check_file "scripts/md_to_mobile_pdf.sh"
check_file "scripts/md_to_mobile_pdf.py"
check_file "references/output_gate.md"

bash -n "$ROOT/scripts/md_to_mobile_pdf.sh"
bash -n "$ROOT/scripts/selftest.sh"
python3 -m py_compile "$ROOT/scripts/md_to_mobile_pdf.py"
check_contains "SKILL.md" "Verification|验证"
check_contains "SKILL.md" "output_gate"
check_contains "references/output_gate.md" "Pages"

if [ "$LOCAL_SMOKE" -eq 0 ]; then
  [ "$FAILURES" -eq 0 ] || { echo "selftest failed: $FAILURES issue(s)" >&2; exit 1; }
  echo "safe selftest passed"
  exit 0
fi

cat >"$WORK_DIR/input.md" <<'MD'
# Selftest

这是一份手机 PDF smoke 文档。
MD

"$ROOT/scripts/md_to_mobile_pdf.sh" "$WORK_DIR/input.md" "$WORK_DIR/output.pdf" "Selftest" >/dev/null

[ -s "$WORK_DIR/output.pdf" ] || { echo "empty PDF output" >&2; exit 1; }
file "$WORK_DIR/output.pdf" | rg -q "PDF" || { echo "output is not a PDF" >&2; exit 1; }
if command -v pdfinfo >/dev/null 2>&1; then
  pages="$(pdfinfo "$WORK_DIR/output.pdf" | awk -F: '/^Pages:/ {gsub(/ /, "", $2); print $2}')"
  [ "${pages:-0}" -ge 1 ] || { echo "PDF has no pages" >&2; exit 1; }
fi

[ "$FAILURES" -eq 0 ] || { echo "selftest failed: $FAILURES issue(s)" >&2; exit 1; }
echo "selftest passed"
