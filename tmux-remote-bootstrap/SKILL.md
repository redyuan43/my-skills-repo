---
name: tmux-remote-bootstrap
description: Configure tmux for beginner-friendly local or remote Linux hosts, especially over SSH. Use when the user asks to set up tmux, improve scrolling, create readable status-bar hints, copy tmux config to a new machine, or explain basic tmux session/window/pane operations.
---

# Tmux Remote Bootstrap

## When to use

Use this skill when the user wants help with tmux setup or onboarding, including:

- enabling mouse wheel scrolling and copy mode
- adding visible beginner shortcut hints in the tmux status bar
- installing the same tmux configuration on a remote SSH host such as `ai`
- explaining sessions, windows, panes, attach/detach, and switching
- making the status bar more readable when terminal theme colors make it unclear

## Operating principles

- Prefer a practical setup that works immediately over a heavily customized tmux framework.
- Preserve existing remote state: back up `~/.tmux.conf` before overwriting it.
- If a host is provided, use SSH/SCP and verify on the remote host.
- If no host is provided, apply to the current machine.
- Do not commit or push repository changes unless the user explicitly asks and confirms.

## Standard workflow

1. Check whether the target host is local or remote.
2. Install the beginner tmux config with `scripts/install_tmux_beginner_config.sh`.
3. Reload tmux with `tmux source-file ~/.tmux.conf` if tmux is already running.
4. Verify key options:
   - `mouse on`
   - `history-limit 10000`
   - `mode-keys vi`
   - `status-style bg=colour234,fg=colour250`
5. Give the user the short usage guide below.

## Commands

Local install:

```bash
bash scripts/install_tmux_beginner_config.sh
```

Remote install:

```bash
bash scripts/install_tmux_beginner_config.sh --host ai
```

Install to a non-default remote user/path:

```bash
bash scripts/install_tmux_beginner_config.sh --host user@example.com --remote-path ~/.tmux.conf
```

## User-facing quick guide

Explain these first:

- `tmux ls`: list sessions
- `tmux attach -t 0`: attach to session `0`
- `Ctrl-b s`: choose a session from inside tmux
- `Ctrl-b c`: create a new window
- `Ctrl-b n` / `Ctrl-b p`: next / previous window
- `Ctrl-b |`: split left/right
- `Ctrl-b -`: split top/bottom
- `Ctrl-b h/j/k/l`: move between panes
- `Ctrl-b [`: enter copy/scroll mode; use wheel, arrow keys, or PageUp/PageDown; press `q` to exit
- `Ctrl-b d`: detach without stopping the running process

Clarify terminology:

- Session: a long-running tmux workspace, shown by `tmux ls`.
- Window: a tab-like shell inside a session.
- Pane: a split area inside a window.
- Attached: a terminal client is currently connected to that session.

## Readability rules

If the user says the status bar text is unclear:

- Avoid blue text on green or bright backgrounds.
- Pin the status bar to a dark background:
  - `set -g status-style 'bg=colour234,fg=colour250'`
- Use high-contrast shortcut labels:
  - `colour51` for key names
  - `colour250` for descriptions
  - `colour240` for separators
- Keep hints short. Long status text wraps or becomes noisy on narrow terminals.

## Verification

After installation, run:

```bash
tmux show-options -g mouse
tmux show-options -g history-limit
tmux show-options -g mode-keys
tmux show-options -g status-style
```

For remote hosts:

```bash
ssh <host> 'tmux show-options -g mouse; tmux show-options -g status-style'
```

If tmux reports no server running, the config can still be installed; it will apply when tmux starts.
