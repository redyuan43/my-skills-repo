#!/usr/bin/env bash
set -u

# Install/upgrade common AI CLIs:
# claude / kilo / codex / opencode / qwen / gemini

SCRIPT_NAME="$(basename "$0")"
ASSUME_YES=0
ONLY_CHECK=0
DEFAULT_UPGRADE_TIMEOUT_SEC=120
AUTO_FIX_NPM_PERMS=1

# Some shells/tools export npm_config_prefix=/usr, which overrides ~/.npmrc and
# causes false EACCES failures even after user-level npm prefix is configured.
unset npm_config_prefix npm_config_global_prefix NPM_CONFIG_PREFIX NPM_CONFIG_GLOBAL_PREFIX

# If user-level npm global bin exists, prefer it.
if [[ -d "$HOME/.npm-global/bin" ]]; then
  export PATH="$HOME/.npm-global/bin:$PATH"
fi

usage() {
  cat <<'EOF'
Usage:
  install_ai_clis.sh [options]

Options:
  -y, --yes        Upgrade installed CLIs without prompting
  -c, --check      Only check installation status; do not install/upgrade
  --no-npm-fix     Do not auto-configure npm user-level global prefix (~/.npm-global)
  -h, --help       Show this help

Behavior:
  - Missing CLI: installs it
  - Existing CLI: asks whether to upgrade (unless --yes)
  - Permission errors: prints a clear message so you can rerun with authorization
  - npm global permission: can auto-switch to user-level prefix (~/.npm-global)
EOF
}

log() { printf '%s\n' "$*"; }
info() { printf '[INFO] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*" >&2; }
err() { printf '[ERROR] %s\n' "$*" >&2; }

has_cmd() { command -v "$1" >/dev/null 2>&1; }

is_permission_error() {
  local text="$1"
  printf '%s' "$text" | grep -Eiq '(permission denied|eacces|eperm|operation not permitted)'
}

prompt_yes_no() {
  local prompt="$1"
  local default="${2:-N}"
  local answer

  if [[ "$ASSUME_YES" -eq 1 ]]; then
    return 0
  fi

  if [[ ! -t 0 ]]; then
    return 1
  fi

  if [[ "$default" == "Y" ]]; then
    read -r -p "$prompt [Y/n] " answer || return 1
    [[ -z "$answer" || "$answer" =~ ^[Yy]$ ]]
  else
    read -r -p "$prompt [y/N] " answer || return 1
    [[ "$answer" =~ ^[Yy]$ ]]
  fi
}

run_step() {
  local label="$1"
  local cmd="$2"
  local timeout_sec="${3:-0}"
  local out
  local status

  info "$label"
  if [[ "$timeout_sec" -gt 0 ]] && has_cmd timeout; then
    out="$(timeout --foreground "${timeout_sec}s" bash -lc "$cmd" 2>&1)"
  else
    out="$(bash -lc "$cmd" 2>&1)"
  fi
  status=$?

  if [[ $status -eq 0 ]]; then
    printf '%s\n' "$out" | sed -n '1,4p'
    return 0
  fi

  if [[ $status -eq 124 ]]; then
    err "$label timed out after ${timeout_sec}s"
    err "Skipped to avoid hanging. You can rerun that CLI upgrade manually."
    return $status
  fi

  err "$label failed (exit $status)"
  if [[ -n "$out" ]]; then
    printf '%s\n' "$out" | sed -n '1,12p' >&2
  fi

  if is_permission_error "$out"; then
    err "Looks like a permission issue."
    err "Please authorize elevated permissions (or rerun with sudo if you prefer), then run this script again."
  fi
  return $status
}

need_npm_prereqs() {
  local missing=()
  has_cmd node || missing+=("node")
  has_cmd npm || missing+=("npm")
  if [[ ${#missing[@]} -gt 0 ]]; then
    warn "Missing prerequisite(s): ${missing[*]} (required for npm-based CLIs)."
    return 1
  fi
  return 0
}

show_version() {
  local bin="$1"
  if has_cmd "$bin"; then
    "$bin" --version 2>/dev/null | head -n 1 || true
  fi
}

append_unique_line() {
  local file="$1"
  local line="$2"
  mkdir -p "$(dirname "$file")"
  touch "$file"
  if ! grep -Fqx "$line" "$file" 2>/dev/null; then
    printf '\n%s\n' "$line" >> "$file"
  fi
}

ensure_npm_user_prefix() {
  local target_prefix="$HOME/.npm-global"
  local current_prefix

  has_cmd npm || return 1

  current_prefix="$(npm config get prefix 2>/dev/null || true)"
  if [[ "$current_prefix" == "$target_prefix" ]]; then
    info "npm global prefix already set to $target_prefix"
  else
    if [[ "$ONLY_CHECK" -eq 1 ]]; then
      warn "npm global prefix is '$current_prefix' (recommended: $target_prefix)"
      return 0
    fi

    if [[ "$AUTO_FIX_NPM_PERMS" -eq 0 ]]; then
      warn "npm auto-fix disabled. Current npm global prefix: $current_prefix"
      return 0
    fi

    if [[ "$current_prefix" == "/usr"* ]] || [[ "$current_prefix" == "/opt/"* ]] || [[ "$current_prefix" == "/usr/local"* ]]; then
      if [[ "$ASSUME_YES" -eq 1 ]] || prompt_yes_no "Switch npm global installs to user path ($target_prefix)?"; then
        info "Configuring npm user-level global prefix"
        mkdir -p "$target_prefix/bin"
        if ! npm config set prefix "$target_prefix"; then
          err "Failed to set npm prefix to $target_prefix"
          return 1
        fi
      else
        warn "Keeping npm prefix as '$current_prefix' (you may need sudo for npm -g)."
        return 0
      fi
    fi
  fi

  # Make PATH persistent in login shells and interactive shells.
  append_unique_line "$HOME/.profile" '# npm global (user-level, no sudo)'
  append_unique_line "$HOME/.profile" 'case ":$PATH:" in'
  append_unique_line "$HOME/.profile" '    *":$HOME/.npm-global/bin:"*) ;;'
  append_unique_line "$HOME/.profile" '    *) PATH="$HOME/.npm-global/bin:$PATH" ;;'
  append_unique_line "$HOME/.profile" 'esac'

  append_unique_line "$HOME/.bashrc" '# npm global (user-level, no sudo)'
  append_unique_line "$HOME/.bashrc" 'case ":$PATH:" in'
  append_unique_line "$HOME/.bashrc" '  *":$HOME/.npm-global/bin:"*) ;;'
  append_unique_line "$HOME/.bashrc" '  *) export PATH="$HOME/.npm-global/bin:$PATH" ;;'
  append_unique_line "$HOME/.bashrc" 'esac'

  export PATH="$HOME/.npm-global/bin:$PATH"
  info "npm user-level global setup ready (prefix: $(npm config get prefix 2>/dev/null || echo unknown))"
  return 0
}

handle_cli() {
  local name="$1"
  local bin="$2"
  local install_cmd="$3"
  local upgrade_cmd="$4"
  local install_hint="$5"
  local upgrade_hint="$6"
  local upgrade_timeout_sec="${7:-0}"

  log
  log "=== $name ($bin) ==="

  if has_cmd "$bin"; then
    info "Installed: $(show_version "$bin")"
    info "Upgrade command: $upgrade_hint"

    if [[ "$ONLY_CHECK" -eq 1 ]]; then
      return 0
    fi

    if prompt_yes_no "Upgrade $name now?"; then
      run_step "Upgrading $name" "$upgrade_cmd" "$upgrade_timeout_sec"
    else
      info "Skipped upgrade for $name"
    fi
  else
    warn "Not installed"
    info "Install command: $install_hint"

    if [[ "$ONLY_CHECK" -eq 1 ]]; then
      return 0
    fi

    run_step "Installing $name" "$install_cmd"
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -y|--yes) ASSUME_YES=1 ;;
    -c|--check) ONLY_CHECK=1 ;;
    --no-npm-fix) AUTO_FIX_NPM_PERMS=0 ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      err "Unknown option: $1"
      usage
      exit 2
      ;;
  esac
  shift
done

info "Target CLIs: claude, kilo, codex, opencode, qwen, gemini"

if ! has_cmd curl; then
  warn "curl is not installed. Claude/OpenCode install via official curl installers may fail."
fi

NPM_OK=1
if ! need_npm_prereqs; then
  NPM_OK=0
elif ! ensure_npm_user_prefix; then
  warn "npm user-level setup failed; continuing with current npm configuration."
fi

# Claude Code (official native installer; npm install is deprecated)
handle_cli \
  "Claude Code" \
  "claude" \
  "curl -fsSL https://claude.ai/install.sh | bash" \
  "claude update || (npm update -g @anthropic-ai/claude-code)" \
  "curl -fsSL https://claude.ai/install.sh | bash" \
  "claude update  (fallback: npm update -g @anthropic-ai/claude-code)" \
  "$DEFAULT_UPGRADE_TIMEOUT_SEC"

# Kilo CLI (npm package)
if [[ "$NPM_OK" -eq 1 ]]; then
  handle_cli \
    "Kilo CLI" \
    "kilo" \
    "npm install -g @kilocode/cli@latest" \
    "npm update -g @kilocode/cli || npm install -g @kilocode/cli@latest" \
    "npm install -g @kilocode/cli@latest" \
    "npm update -g @kilocode/cli  (fallback: npm install -g @kilocode/cli@latest)" \
    "$DEFAULT_UPGRADE_TIMEOUT_SEC"
else
  warn "Skipping Kilo CLI install/upgrade because npm prerequisites are missing."
fi

# Codex CLI (OpenAI)
if [[ "$NPM_OK" -eq 1 ]]; then
  handle_cli \
    "Codex CLI" \
    "codex" \
    "npm install -g @openai/codex@latest" \
    "npm update -g @openai/codex" \
    "npm install -g @openai/codex@latest" \
    "npm update -g @openai/codex"
else
  warn "Skipping Codex CLI install/upgrade because npm prerequisites are missing."
fi

# OpenCode CLI (official curl installer)
handle_cli \
  "OpenCode CLI" \
  "opencode" \
  "curl -fsSL https://opencode.ai/install | bash" \
  "CI=1 opencode upgrade || (curl -fsSL https://opencode.ai/install | bash)" \
  "curl -fsSL https://opencode.ai/install | bash" \
  "CI=1 opencode upgrade  (fallback: rerun installer)" \
  "$DEFAULT_UPGRADE_TIMEOUT_SEC"

# Qwen Code CLI
if [[ "$NPM_OK" -eq 1 ]]; then
  handle_cli \
    "Qwen Code CLI" \
    "qwen" \
    "npm install -g @qwen-code/qwen-code@latest" \
    "npm update -g @qwen-code/qwen-code" \
    "npm install -g @qwen-code/qwen-code@latest" \
    "npm update -g @qwen-code/qwen-code"
else
  warn "Skipping Qwen Code CLI install/upgrade because npm prerequisites are missing."
fi

# Gemini CLI
if [[ "$NPM_OK" -eq 1 ]]; then
  handle_cli \
    "Gemini CLI" \
    "gemini" \
    "npm install -g @google/gemini-cli@latest" \
    "npm update -g @google/gemini-cli" \
    "npm install -g @google/gemini-cli@latest" \
    "npm update -g @google/gemini-cli"
else
  warn "Skipping Gemini CLI install/upgrade because npm prerequisites are missing."
fi

log
info "Done."
info "Tip: run '$SCRIPT_NAME --check' to see current status only."
