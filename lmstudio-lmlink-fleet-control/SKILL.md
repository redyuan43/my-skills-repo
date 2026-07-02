---
name: lmstudio-lmlink-fleet-control
description: Diagnose, start, stop, restart, and re-login LM Studio LM Link across Linux desktop or SSH targets with a reusable `lmlinkctl` script. Use when the user asks why LM Link is offline, wants a non-GUI command to check device activation, needs a pairing/login URL for LM Studio, or wants to start LM Studio/LM Link on devices such as `edge` or `AMD` over SSH.
---

# LM Studio LM Link Fleet Control

Use this skill to keep LM Link status and startup manageable from the command line instead of clicking through the LM Studio GUI.

## Boundary

Use `lmstudio-remote-account-setup` when the main task is switching the LM Studio account on a remote device through `lms login`.

Use this skill when the main task is runtime control: checking whether LM Link is online, starting LM Studio so LM Link comes up, restarting a target, or gathering enough evidence to tell whether the problem is login, GUI startup, server status, or GPU/Electron noise.

## Quick Start

Prefer the bundled script:

```bash
bash "$HOME/.codex/skills/lmstudio-lmlink-fleet-control/scripts/lmlinkctl" status
bash "$HOME/.codex/skills/lmstudio-lmlink-fleet-control/scripts/lmlinkctl" all
bash "$HOME/.codex/skills/lmstudio-lmlink-fleet-control/scripts/lmlinkctl" status AMD
bash "$HOME/.codex/skills/lmstudio-lmlink-fleet-control/scripts/lmlinkctl" start AMD
bash "$HOME/.codex/skills/lmstudio-lmlink-fleet-control/scripts/lmlinkctl" restart AMD
bash "$HOME/.codex/skills/lmstudio-lmlink-fleet-control/scripts/lmlinkctl" relogin AMD
```

If the user wants a short reusable command, install the script:

```bash
install -Dm755 \
  "$HOME/.codex/skills/lmstudio-lmlink-fleet-control/scripts/lmlinkctl" \
  "$HOME/.local/bin/lmlinkctl"
```

For remote SSH targets, copy it once:

```bash
ssh AMD 'mkdir -p "$HOME/.local/bin"'
scp "$HOME/.codex/skills/lmstudio-lmlink-fleet-control/scripts/lmlinkctl" AMD:~/.local/bin/lmlinkctl
ssh AMD 'chmod +x "$HOME/.local/bin/lmlinkctl"'
```

## Status Workflow

1. Run `lmlinkctl status` on the current machine or `lmlinkctl status <ssh-alias>` for a remote target.
2. Read `[auth]` for the account, `[link]` for LM Link activation, `[server]` for the local OpenAI-compatible API, `[systemd]` for managed units, and `[listeners]` / `[processes]` for runtime evidence.
3. Treat `lms link status` as the primary LM Link signal. `lms server status` may be stopped even when LM Link itself is online.
4. If a target is offline but `lms whoami` is valid, start or restart LM Studio before forcing re-login.
5. Use `relogin` only when authentication is absent, expired, or the user explicitly asks for a new pairing link.

## Startup Workflow

Use:

```bash
lmlinkctl start <target>
```

The script starts local hosts directly and SSH targets through their own `~/.local/bin/lmlinkctl`.

For the host named `edge`, it uses a user systemd transient unit with desktop session variables:

```bash
systemd-run --user --unit=lmstudio-manual --collect \
  --setenv=DISPLAY="${DISPLAY:-:1}" \
  --setenv=XAUTHORITY="${XAUTHORITY:-/run/user/$(id -u)/gdm/Xauthority}" \
  --setenv=DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-unix:path=/run/user/$(id -u)/bus}" \
  "$HOME/.local/bin/lmstudio" --no-sandbox --disable-gpu
```

For other hosts, keep startup logic in `~/.local/bin/lmstudio`. If a host needs AppImage flags or proxy settings, patch that wrapper rather than duplicating host-specific launch commands in the skill.

## Re-login Workflow

Use a TTY when the task needs an interactive LM Studio pairing link:

```bash
lmlinkctl relogin AMD
```

Keep the command running until authentication completes. Send the direct `https://lmstudio.ai/pairing?...` URL to the user if they are away from the machine. If the user misses or expires the link, run `relogin` again.

Do not mark the task complete from cache files alone. Verify with:

```bash
lms whoami
lms link status
```

## AMD / Electron GPU Noise

Some AMD desktop sessions can keep printing `libva` / `radeonsi` / GPU helper errors while LM Studio and LM Link are already alive. Do not treat those logs as fatal by themselves.

Fatal pattern:

```text
GPU process isn't usable. Goodbye.
```

Workaround pattern:

- Keep `~/.local/bin/lmstudio` as the host-specific wrapper.
- Add GPU-disable flags and software-render environment when Electron exits on GPU helper crashes.
- Include `--disable-gpu-process-crash-limit` when the process dies despite other `--disable-gpu` flags.
- Re-check with `lms link status`, process list, and listeners before declaring failure.

See `references/field-notes.md` for the concrete `edge` and `AMD` evidence from the original incident.

## Verification Checklist

For each target:

- `lms whoami` returns the expected account or a clear login failure.
- `lms link status` shows `Status: Online` for the current device.
- `lmlinkctl status <target>` prints host, auth, link, server, systemd, listener, and process sections.
- If `start` or `restart` was used, the command waits and reprints link status.
- If remote control is needed later, `ssh <target> '~/.local/bin/lmlinkctl status'` works without opening the GUI.

## Resources

- `scripts/lmlinkctl`: reusable command for status/start/restart/stop/login/relogin across local and SSH targets.
- `references/field-notes.md`: concrete debugging notes for the `edge` and `AMD` LM Link incident.
