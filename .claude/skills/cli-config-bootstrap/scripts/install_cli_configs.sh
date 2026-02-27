#!/usr/bin/env bash
set -euo pipefail

# Default to install all CLIs if no arguments provided
INSTALL_CLAUDE=true
INSTALL_QWEN=true
INSTALL_KILO=true
INSTALL_OPENCODE=true

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --claude-only)
      INSTALL_CLAUDE=true
      INSTALL_QWEN=false
      INSTALL_KILO=false
      INSTALL_OPENCODE=false
      shift
      ;;
    --qwen-only)
      INSTALL_CLAUDE=false
      INSTALL_QWEN=true
      INSTALL_KILO=false
      INSTALL_OPENCODE=false
      shift
      ;;
    --kilo-only)
      INSTALL_CLAUDE=false
      INSTALL_QWEN=false
      INSTALL_KILO=true
      INSTALL_OPENCODE=false
      shift
      ;;
    --opencode-only|--opencode)
      INSTALL_CLAUDE=false
      INSTALL_QWEN=false
      INSTALL_KILO=false
      INSTALL_OPENCODE=true
      shift
      ;;
    --exclude-claude)
      INSTALL_CLAUDE=false
      shift
      ;;
    --exclude-qwen)
      INSTALL_QWEN=false
      shift
      ;;
    --exclude-kilo)
      INSTALL_KILO=false
      shift
      ;;
    --exclude-opencode)
      INSTALL_OPENCODE=false
      shift
      ;;
    -h|--help)
      echo "Usage: $0 [OPTIONS]"
      echo "Options:"
      echo "  --claude-only       Install only Claude CLI configuration"
      echo "  --qwen-only         Install only Qwen CLI configuration"
      echo "  --kilo-only         Install only Kilo CLI configuration"
      echo "  --opencode-only     Install only OpenCode CLI configuration"
      echo "  --exclude-claude    Exclude Claude CLI from installation"
      echo "  --exclude-qwen      Exclude Qwen CLI from installation"
      echo "  --exclude-kilo      Exclude Kilo CLI from installation"
      echo "  --exclude-opencode  Exclude OpenCode CLI from installation"
      echo "  -h, --help          Show this help message"
      echo ""
      echo "By default, all CLI configurations will be installed."
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      echo "Use --help for usage information."
      exit 1
      ;;
  esac
done

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
if [[ "${INSTALL_CLAUDE}" == "true" ]]; then
  copy_with_replace "${TEMPLATES_DIR}/claude/settings.json" "${HOME}/.claude/settings.json"
  copy_with_replace "${TEMPLATES_DIR}/claude/config.json" "${HOME}/.claude/config.json"
  replace_token_if_set "${HOME}/.claude/settings.json" "__ANTHROPIC_AUTH_TOKEN__" "${ANTHROPIC_AUTH_TOKEN:-}"
  replace_token_if_set "${HOME}/.claude/settings.json" "__ANTHROPIC_BASE_URL__" "${ANTHROPIC_BASE_URL:-}"
  replace_token_if_set "${HOME}/.claude/config.json" "__CLAUDE_PRIMARY_API_KEY__" "${CLAUDE_PRIMARY_API_KEY:-}"
fi

# Qwen
if [[ "${INSTALL_QWEN}" == "true" ]]; then
  copy_with_replace "${TEMPLATES_DIR}/qwen/settings.json" "${HOME}/.qwen/settings.json"
  replace_token_if_set "${HOME}/.qwen/settings.json" "__BAILIAN_CODING_PLAN_API_KEY__" "${BAILIAN_CODING_PLAN_API_KEY:-}"
fi

# Kilo
if [[ "${INSTALL_KILO}" == "true" ]]; then
  copy_with_replace "${TEMPLATES_DIR}/kilo/config.json" "${HOME}/.config/kilo/config.json"
  copy_with_replace "${TEMPLATES_DIR}/kilo/opencode.json" "${HOME}/.config/kilo/opencode.json"
  copy_with_replace "${TEMPLATES_DIR}/kilo/package.json" "${HOME}/.config/kilo/package.json"
  replace_token_if_set "${HOME}/.config/kilo/config.json" "__KILO_API_KEY__" "${KILO_API_KEY:-}"
  replace_token_if_set "${HOME}/.config/kilo/opencode.json" "__KILO_API_KEY__" "${KILO_API_KEY:-}"
fi

# OpenCode
if [[ "${INSTALL_OPENCODE}" == "true" ]]; then
  copy_with_replace "${TEMPLATES_DIR}/opencode/opencode.json" "${HOME}/.config/opencode/opencode.json"
  replace_token_if_set "${HOME}/.config/opencode/opencode.json" "__BAILIAN_CODING_PLAN_API_KEY__" "${BAILIAN_CODING_PLAN_API_KEY:-}"
fi

cat <<'EOF'
Done.

Next steps:
1. Fill any remaining placeholders (if env vars were not provided).
2. Re-login for OAuth-based CLIs if needed.
3. Restart the CLIs.
EOF
