---
name: remote-hostname-rename-over-ssh
description: Rename a remote Linux machine's device name or hostname over SSH when the user's local SSH alias is already correct but the remote host still reports an old name such as `BUS002-GPU` instead of `nx1`. Use when the user wants the actual remote hostname changed, not just `~/.ssh/config` aliases.
---

# Remote Hostname Rename Over SSH

Use this skill when the user says things like:

- "`ssh nx1` can log in, but the device name is still `BUS002-GPU`"
- "把设备名称改成 `nx1`"
- "不是改 SSH 别名，是改远端主机名"
- "登录到远端后提示符/设备名还是旧名字"

## Core Rule

Treat these as different things:

- SSH alias: local name in `~/.ssh/config`, for example `nx1`
- remote username: Linux account used by SSH, for example `nx`
- hostname: what the remote machine reports, for example `BUS002-GPU`

If the user wants the displayed device name changed after logging in over SSH, that is a remote hostname change, not an SSH alias edit.

## Workflow

1. Confirm the target alias and current remote hostname:

```bash
ssh nx1 'hostnamectl status --static && echo --- && hostname && echo --- && cat /etc/hostname'
```

2. Confirm the remote identity if needed:

```bash
ssh nx1 'id -u && whoami'
```

3. Before changing the hostname, warn that this is a remote system configuration change.
4. Prefer `hostnamectl`:

```bash
ssh nx1 'sudo hostnamectl set-hostname nx1'
```

5. Re-read the effective hostname and persisted hostname:

```bash
ssh nx1 'hostnamectl status --static && echo --- && hostname && echo --- && cat /etc/hostname'
```

6. If the user cares about full cleanup, also inspect `/etc/hosts` for stale old names:

```bash
ssh nx1 'grep -nE "BUS002-GPU|nx1" /etc/hosts /etc/hostname'
```

## Preferred Interpretation

- If `ssh nx1` works but the shell prompt or system name still shows `BUS002-GPU`, the alias is already fine.
- The requested fix is to rename the remote machine hostname to `nx1`.
- Do not rename the Linux account unless the user explicitly asks to rename the login user too.

## Validation

Successful change usually means all of these agree:

- `hostnamectl status --static` prints the new name
- `hostname` prints the new name
- `/etc/hostname` contains the new name

If one of them still shows the old value, report exactly which layer did not update.

## Fallbacks

- If `hostnamectl` is unavailable, inspect whether the system is minimal or containerized before editing files manually.
- If `sudo` is unavailable or requires a password that cannot be provided, stop and report the permission blocker clearly.
- If the remote machine is managed by cloud-init, NetworkManager, or another provisioning system that may revert the hostname, mention that the change could be overwritten later.

## Dangerous Operations

Ask for explicit confirmation before:

- running `sudo hostnamectl set-hostname ...`
- editing `/etc/hostname` or `/etc/hosts`
- restarting remote services or the remote machine
- committing or pushing repo changes
