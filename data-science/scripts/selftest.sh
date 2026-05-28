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

python3 - "$ROOT/eval/val/items.json" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as fh:
    items = json.load(fh)
assert isinstance(items, list) and len(items) >= 5, "need at least 5 eval items"
for item in items:
    assert item.get("id"), "eval item missing id"
    assert item.get("task"), f"eval item missing task: {item!r}"
    assert "must_check" in item, f"eval item missing must_check: {item.get('id')}"
PY

if command -v rg >/dev/null 2>&1; then
  if rg -n "(sk-[A-Za-z0-9_-]{20,}|mkt_[A-Za-z0-9]{12,})" "$ROOT" >/tmp/data-science-secret-scan.txt; then
    cat /tmp/data-science-secret-scan.txt >&2
    fail "possible real API key found"
  fi
fi

if [[ "$SAFE" -eq 1 ]]; then
  printf 'OK: data-science safe selftest passed\n'
else
  printf 'OK: data-science selftest passed\n'
fi
