#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TEMPLATES_DIR="${SKILL_ROOT}/assets/templates"

copy_with_replace() {
  local src="$1"
  local dst="$2"
  mkdir -p "$(dirname "${dst}")"
  cp "${src}" "${dst}"
  sed -i "s|__HOME__|${HOME}|g" "${dst}"
}

replace_token_if_set() {
  local file="$1"
  local placeholder="$2"
  local value="${3:-}"
  if [[ -n "${value}" ]]; then
    sed -i "s|${placeholder}|${value}|g" "${file}"
  fi
}

echo "Installing CLI config templates into ${HOME} ..."

# Claude
copy_with_replace "${TEMPLATES_DIR}/claude/settings.json" "${HOME}/.claude/settings.json"
copy_with_replace "${TEMPLATES_DIR}/claude/config.json" "${HOME}/.claude/config.json"
replace_token_if_set "${HOME}/.claude/settings.json" "__ANTHROPIC_AUTH_TOKEN__" "${ANTHROPIC_AUTH_TOKEN:-}"
replace_token_if_set "${HOME}/.claude/settings.json" "__ANTHROPIC_BASE_URL__" "${ANTHROPIC_BASE_URL:-}"
replace_token_if_set "${HOME}/.claude/config.json" "__CLAUDE_PRIMARY_API_KEY__" "${CLAUDE_PRIMARY_API_KEY:-}"

# Qwen
copy_with_replace "${TEMPLATES_DIR}/qwen/settings.json" "${HOME}/.qwen/settings.json"
replace_token_if_set "${HOME}/.qwen/settings.json" "__BAILIAN_CODING_PLAN_API_KEY__" "${BAILIAN_CODING_PLAN_API_KEY:-}"

# Kilo
copy_with_replace "${TEMPLATES_DIR}/kilo/config.json" "${HOME}/.config/kilo/config.json"
copy_with_replace "${TEMPLATES_DIR}/kilo/opencode.json" "${HOME}/.config/kilo/opencode.json"
copy_with_replace "${TEMPLATES_DIR}/kilo/package.json" "${HOME}/.config/kilo/package.json"
replace_token_if_set "${HOME}/.config/kilo/config.json" "__KILO_API_KEY__" "${KILO_API_KEY:-}"
replace_token_if_set "${HOME}/.config/kilo/opencode.json" "__KILO_API_KEY__" "${KILO_API_KEY:-}"

# OpenCode
copy_with_replace "${TEMPLATES_DIR}/opencode/opencode.json" "${HOME}/.config/opencode/opencode.json"
replace_token_if_set "${HOME}/.config/opencode/opencode.json" "__BAILIAN_CODING_PLAN_API_KEY__" "${BAILIAN_CODING_PLAN_API_KEY:-}"

cat <<'EOF'
Done.

Next steps:
1. Fill any remaining placeholders (if env vars were not provided).
2. Re-login for OAuth-based CLIs if needed.
3. Restart the CLIs.
EOF
