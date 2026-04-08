---
name: ssh-monitor-cycle
description: "Cycle through SSH hosts from ~/.ssh/config in a single terminal, run htop then jtop/nvtop on each host, and support in-terminal PageUp/PageDown switching via a local PTY proxy."
---

# SSH Monitor Cycle

Use this skill when the user wants to:
- read hosts from `~/.ssh/config`
- monitor multiple remote machines in one terminal
- run `htop` first, then `jtop` or `nvtop`
- switch hosts with `PageUp` / `PageDown`

## Files

- `scripts/ssh_monitor_cycle.sh`
- `scripts/ssh_monitor_cycle.py`

## Run

From the skill root:

```bash
./scripts/ssh_monitor_cycle.sh
```

## Behavior

- Hosts are collected from explicit `Host` entries in `~/.ssh/config`
- `nano` / `agx` / `nx*` use `jtop`
- other hosts use `nvtop`
- each host runs `htop` for `VIEW_SECONDS`, then GPU monitor for `VIEW_SECONDS`
- default `VIEW_SECONDS` is `30`

## Runtime keys

- `PageDown`: switch to next host
- `PageUp`: switch to previous host
- `Ctrl-G`: hold the current screen and stop auto-advance
- `Ctrl-R`: resume automatic cycling from hold mode
- `Ctrl-C`: quit

## Environment variables

```bash
VIEW_SECONDS=30
HOST_SWITCH_DELAY=1
SSH_CONNECT_TIMEOUT=10
HOSTS="nano nx1"
SSH_PUBKEY=~/.ssh/id_ed25519.pub
AUTO_COPY_ID=0
```

## Notes

- The Python script uses a local PTY proxy so the current terminal can intercept `PageUp` / `PageDown` and `Ctrl-G` / `Ctrl-R` before forwarding other input to the remote monitor.
- If a terminal emulator intercepts `PageUp` / `PageDown` for local scrollback, the user may need to disable that binding or use a terminal that forwards those keys.
- If `htop` is missing on the remote host, the script attempts to install it using the detected package manager.
