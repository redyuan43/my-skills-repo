#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

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
check_file "references/api-data-sources.md"
check_file "references/gate_checklist.md"
check_file "references/optimizer_memory.md"
check_file "references/rejected_edits.md"
check_file "eval/val/items.json"

python3 - "$ROOT/eval/val/items.json" <<'PY'
import json
import sys

path = sys.argv[1]
with open(path, "r", encoding="utf-8") as fh:
    items = json.load(fh)

assert isinstance(items, list) and len(items) >= 5, "need at least 5 eval items"
for item in items:
    assert item.get("id"), "eval item missing id"
    assert item.get("task"), f"eval item missing task: {item!r}"
    assert "must_check" in item, f"eval item missing must_check: {item.get('id')}"
PY

grep -q "MX_APIKEY" "$ROOT/SKILL.md" || fail "SKILL.md missing MX_APIKEY"
grep -q "POLYGON_API_KEY" "$ROOT/SKILL.md" || fail "SKILL.md missing POLYGON_API_KEY"
grep -q "mkapi2.dfcfs.com" "$ROOT/SKILL.md" || fail "SKILL.md missing MX endpoint warning"
grep -q "明确要求" "$ROOT/SKILL.md" || fail "SKILL.md missing explicit authorization guard"

if command -v rg >/dev/null 2>&1; then
  if rg -n "(sk-[A-Za-z0-9_-]{20,}|mkt_[A-Za-z0-9]{12,})" "$ROOT" >/tmp/cfo-check-secret-scan.txt; then
    cat /tmp/cfo-check-secret-scan.txt >&2
    fail "possible real API key found"
  fi
else
  if grep -R -n -E "(sk-[A-Za-z0-9_-]{20,}|mkt_[A-Za-z0-9]{12,})" "$ROOT" >/tmp/cfo-check-secret-scan.txt; then
    cat /tmp/cfo-check-secret-scan.txt >&2
    fail "possible real API key found"
  fi
fi

printf 'OK: cfo-check skill structure passed\n'
