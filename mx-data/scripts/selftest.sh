#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SAFE=0
[[ "${1:-}" == "--safe" ]] && SAFE=1

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

check_file() {
  local path="$1"
  [[ -s "$ROOT/$path" ]] || fail "missing or empty: $path"
}

check_file "SKILL.md"
check_file "agents/openai.yaml"
check_file "references/gate_checklist.md"
check_file "references/optimizer_memory.md"
check_file "references/rejected_edits.md"
check_file "eval/val/items.json"
check_file "scripts/mx_data.py"

grep -q "~/.mx/mx-data/output" "$ROOT/SKILL.md" || fail "SKILL.md missing canonical output path"
grep -q ".mx/mx-data/output" "$ROOT/scripts/mx_data.py" || fail "script missing canonical output path"

python3 - "$ROOT/eval/val/items.json" <<'PY'
import json
import sys

items = json.load(open(sys.argv[1], "r", encoding="utf-8"))
assert isinstance(items, list) and len(items) >= 5
for item in items:
    assert item.get("id") and item.get("task") and "must_check" in item
PY

if [[ "$SAFE" -eq 1 ]]; then
  printf 'OK: mx-data safe selftest passed\n'
else
  printf 'OK: mx-data selftest passed\n'
fi
