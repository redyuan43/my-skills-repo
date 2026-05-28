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
check_contains() {
  rg -q "$2" "$ROOT/$1" || { echo "missing pattern in $1: $2" >&2; FAILURES=$((FAILURES + 1)); }
}

check_file "SKILL.md"
check_file "scripts/ollama_vision_perf.sh"
check_file "scripts/ollama_context_probe.sh"
check_file "scripts/install_jetson_ollama_skill.sh"
check_file "references/jetson-findings.md"
check_file "references/gate_checklist.md"
check_file "references/rejected_edits.md"
check_file "eval/val/items.json"

for script in "$ROOT"/scripts/*.sh; do
  bash -n "$script"
done
python3 -m json.tool "$ROOT/eval/val/items.json" >/dev/null

check_contains "SKILL.md" "OLLAMA_CONTEXT_LENGTH"
check_contains "SKILL.md" "Capabilities|vision"
check_contains "references/gate_checklist.md" "状态 Gate"
check_contains "references/gate_checklist.md" "回滚 Gate"
check_contains "references/rejected_edits.md" "不"

for cmd in ollama jq; do
  command -v "$cmd" >/dev/null 2>&1 || echo "warning: optional runtime dependency not found: $cmd" >&2
done

[ "$FAILURES" -eq 0 ] || { echo "selftest failed: $FAILURES issue(s)" >&2; exit 1; }
echo "selftest passed"
