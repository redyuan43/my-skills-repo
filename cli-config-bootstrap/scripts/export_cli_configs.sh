#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TEMPLATES_DIR="${SKILL_ROOT}/assets/templates"

mkdir -p \
  "${TEMPLATES_DIR}/claude" \
  "${TEMPLATES_DIR}/qwen" \
  "${TEMPLATES_DIR}/kilo" \
  "${TEMPLATES_DIR}/opencode"

export SRC_HOME="${HOME}"

json_sanitize_to_file() {
  local src="$1"
  local dst="$2"
  local mode="$3"
  if [[ ! -f "${src}" ]]; then
    echo "Skip (missing): ${src}"
    return 0
  fi
  SRC_PATH="${src}" DST_PATH="${dst}" SANITIZE_MODE="${mode}" python3 - <<'PY'
import json
import os
from pathlib import Path

src = Path(os.environ["SRC_PATH"])
dst = Path(os.environ["DST_PATH"])
mode = os.environ["SANITIZE_MODE"]
home = os.environ["SRC_HOME"]

with src.open("r", encoding="utf-8") as f:
    data = json.load(f)

def replace_home(obj):
    if isinstance(obj, dict):
        return {k: replace_home(v) for k, v in obj.items()}
    if isinstance(obj, list):
        return [replace_home(v) for v in obj]
    if isinstance(obj, str):
        return obj.replace(home, "__HOME__")
    return obj

data = replace_home(data)

if mode == "claude_settings":
    env = data.setdefault("env", {})
    if "ANTHROPIC_AUTH_TOKEN" in env:
        env["ANTHROPIC_AUTH_TOKEN"] = "__ANTHROPIC_AUTH_TOKEN__"
    if "ANTHROPIC_BASE_URL" in env:
        val = env.get("ANTHROPIC_BASE_URL", "")
        env["ANTHROPIC_BASE_URL"] = "__ANTHROPIC_BASE_URL__" if val else ""
elif mode == "claude_config":
    if "primaryApiKey" in data:
        data["primaryApiKey"] = "__CLAUDE_PRIMARY_API_KEY__"
elif mode == "qwen_settings":
    env = data.setdefault("env", {})
    if "BAILIAN_CODING_PLAN_API_KEY" in env:
        env["BAILIAN_CODING_PLAN_API_KEY"] = "__BAILIAN_CODING_PLAN_API_KEY__"
elif mode in {"kilo_config", "kilo_opencode"}:
    provider = data.get("provider", {})
    for _, cfg in provider.items():
        opts = cfg.get("options")
        if isinstance(opts, dict) and "apiKey" in opts:
            opts["apiKey"] = "__KILO_API_KEY__"
elif mode == "opencode":
    provider = data.get("provider", {})
    for _, cfg in provider.items():
        opts = cfg.get("options")
        if isinstance(opts, dict) and "apiKey" in opts:
            opts["apiKey"] = "__BAILIAN_CODING_PLAN_API_KEY__"
else:
    raise SystemExit(f"Unknown mode: {mode}")

dst.parent.mkdir(parents=True, exist_ok=True)
with dst.open("w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False, indent=2)
    f.write("\n")
PY
  echo "Exported: ${dst}"
}

echo "Exporting sanitized CLI config templates from ${HOME} ..."

# Claude
json_sanitize_to_file "${HOME}/.claude/settings.json" "${TEMPLATES_DIR}/claude/settings.json" "claude_settings"
json_sanitize_to_file "${HOME}/.claude/config.json" "${TEMPLATES_DIR}/claude/config.json" "claude_config"

# Qwen
json_sanitize_to_file "${HOME}/.qwen/settings.json" "${TEMPLATES_DIR}/qwen/settings.json" "qwen_settings"

# Kilo
json_sanitize_to_file "${HOME}/.config/kilo/config.json" "${TEMPLATES_DIR}/kilo/config.json" "kilo_config"
json_sanitize_to_file "${HOME}/.config/kilo/opencode.json" "${TEMPLATES_DIR}/kilo/opencode.json" "kilo_opencode"
if [[ -f "${HOME}/.config/kilo/package.json" ]]; then
  cp "${HOME}/.config/kilo/package.json" "${TEMPLATES_DIR}/kilo/package.json"
  echo "Exported: ${TEMPLATES_DIR}/kilo/package.json"
fi

# OpenCode
json_sanitize_to_file "${HOME}/.config/opencode/opencode.json" "${TEMPLATES_DIR}/opencode/opencode.json" "opencode"

cat <<'EOF'
Done.

Notes:
- OAuth credential files are intentionally not exported as real tokens.
- Please review generated templates before sharing or committing.
EOF
