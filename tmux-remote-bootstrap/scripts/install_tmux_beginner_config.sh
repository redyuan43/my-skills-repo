#!/usr/bin/env bash
set -euo pipefail

host=""
remote_path="~/.tmux.conf"
local_path="${HOME}/.tmux.conf"

usage() {
  cat <<'USAGE'
Usage:
  install_tmux_beginner_config.sh
  install_tmux_beginner_config.sh --host ai
  install_tmux_beginner_config.sh --host user@example.com --remote-path ~/.tmux.conf

Options:
  --host HOST          Install on a remote SSH host.
  --remote-path PATH   Remote tmux config path. Default: ~/.tmux.conf
  --local-path PATH    Local tmux config path. Default: ~/.tmux.conf
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host)
      host="${2:?missing host}"
      shift 2
      ;;
    --remote-path)
      remote_path="${2:?missing remote path}"
      shift 2
      ;;
    --local-path)
      local_path="${2:?missing local path}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

tmp_config="$(mktemp)"
trap 'rm -f "$tmp_config"' EXIT

cat > "$tmp_config" <<'TMUXCONF'
# --- Basic usability config for beginner-friendly tmux ---

# Use Ctrl-b as the prefix (tmux default, avoid changing habits).
set -g prefix C-b
unbind C-b
set -g prefix2 C-a
bind C-b send-prefix

# Make numbering human-friendly: start windows/panes from 1.
set -g base-index 1
setw -g pane-base-index 1

# Renumber windows automatically when one is closed.
set -g renumber-windows on

# Bigger scrollback buffer for browsing logs.
set -g history-limit 10000

# Enable vi-style keys in copy mode and status line.
set -g mode-keys vi
set -g status-keys vi

# Turn on mouse support (mouse wheel, select panes by click, resize by drag).
set -g mouse on

# Useful pane navigation and split key bindings.
unbind %
bind | split-window -h
unbind '"'
bind - split-window -v
bind h select-pane -L
bind j select-pane -D
bind k select-pane -U
bind l select-pane -R
bind -r H resize-pane -L 5
bind -r J resize-pane -D 3
bind -r K resize-pane -U 3
bind -r L resize-pane -R 5

# Windows/sessions shortcuts.
bind c new-window
bind n next-window
bind p previous-window
bind r refresh-client

# Copy mode:
# Enter copy mode, then v: start selection, y: copy selection, Enter: copy too (vi style).
bind [ copy-mode -e
bind -T copy-mode-vi 'v' send -X begin-selection
bind -T copy-mode-vi 'y' send -X copy-selection
bind -T copy-mode-vi 'Enter' send -X copy-selection

# Make copied text available to system clipboard in X11/Wayland (if tools exist).
set -s set-clipboard on
bind -T copy-mode-vi MouseDragEnd1Pane send -X copy-selection

# Status bar with short, high-contrast beginner tips.
set -g status on
set -g status-interval 5
set -g status-justify left
set -g status-left-length 180
set -g status-right-length 160
set -g status-style 'bg=colour234,fg=colour250'
set -g status-left '#[bg=colour39,fg=colour16,bold] #S #[bg=colour234,fg=colour250] '
set -g status-right '#[fg=colour51,bold]C-b c#[fg=colour250] 新窗 #[fg=colour240]| #[fg=colour51,bold]C-b |#[fg=colour250] 左右 #[fg=colour240]| #[fg=colour51,bold]C-b -#[fg=colour250] 上下 #[fg=colour240]| #[fg=colour51,bold]C-b [#[fg=colour250] 翻页 #[fg=colour240]| #[fg=colour51,bold]C-b d#[fg=colour250] 脱离 #[fg=colour240]| #[fg=colour51,bold]C-b s#[fg=colour250] 会话 #[fg=colour240]| #[fg=colour245]%H:%M '

# Keep the current-window title short and clear.
set -g window-status-format '#[bg=colour234,fg=colour245] #I:#W '
set -g window-status-current-format '#[bg=colour238,fg=colour51,bold] #I:#W '
TMUXCONF

install_local() {
  local target="$1"
  mkdir -p "$(dirname "$target")"
  if [[ -e "$target" ]]; then
    cp -a "$target" "${target}.bak.$(date +%Y%m%d-%H%M%S)"
  fi
  cp "$tmp_config" "$target"
  if command -v tmux >/dev/null 2>&1 && tmux info >/dev/null 2>&1; then
    tmux source-file "$target"
  fi
  if command -v tmux >/dev/null 2>&1; then
    tmux show-options -g mouse || true
    tmux show-options -g status-style || true
  fi
  echo "Installed tmux config at $target"
}

install_remote() {
  local target_host="$1"
  local target_path="$2"
  local remote_tmp="/tmp/tmux-beginner-config.$$"

  scp "$tmp_config" "${target_host}:${remote_tmp}"
  ssh "$target_host" "set -e; target=${target_path}; mkdir -p \"\$(dirname \"\$target\")\"; if [ -e \"\$target\" ]; then cp -a \"\$target\" \"\$target.bak.\$(date +%Y%m%d-%H%M%S)\"; fi; cp '${remote_tmp}' \"\$target\"; rm -f '${remote_tmp}'; if command -v tmux >/dev/null 2>&1 && tmux info >/dev/null 2>&1; then tmux source-file \"\$target\"; fi; if command -v tmux >/dev/null 2>&1; then tmux show-options -g mouse || true; tmux show-options -g status-style || true; fi; echo \"Installed tmux config at \$target on ${target_host}\""
}

if [[ -n "$host" ]]; then
  install_remote "$host" "$remote_path"
else
  install_local "$local_path"
fi
