#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SAFE=0
[[ "${1:-}" == "--safe" ]] && SAFE=1

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

for path in SKILL.md agents/openai.yaml references/api.md references/gate_checklist.md references/optimizer_memory.md references/rejected_edits.md eval/val/items.json scripts/mx_moni.py; do
  [[ -s "$ROOT/$path" ]] || fail "missing or empty: $path"
done

grep -q -- "--dry-run" "$ROOT/scripts/mx_moni.py" || fail "missing --dry-run gate"
grep -q -- "--yes" "$ROOT/scripts/mx_moni.py" || fail "missing --yes gate"
grep -q "state-changing action requires explicit --yes" "$ROOT/scripts/mx_moni.py" || fail "missing mutation refusal"
grep -q "references/api.md" "$ROOT/SKILL.md" || fail "SKILL.md should route interface details to references/api.md"

python3 - "$ROOT/eval/val/items.json" <<'PY'
import json, sys
items = json.load(open(sys.argv[1], "r", encoding="utf-8"))
assert isinstance(items, list) and len(items) >= 5
for item in items:
    assert item.get("id") and item.get("task") and "must_check" in item
PY

if [[ "$SAFE" -eq 1 ]]; then
  printf 'OK: mx-moni safe selftest passed\n'
else
  printf 'OK: mx-moni selftest passed\n'
fi
