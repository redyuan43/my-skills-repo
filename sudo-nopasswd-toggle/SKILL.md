---
name: sudo-nopasswd-toggle
description: Configure or remove passwordless sudo (NOPASSWD) for a local Linux user by managing a dedicated `/etc/sudoers.d` drop-in and validating with `visudo`. Use when a user asks to make `sudo` stop prompting for a password (`sudo 免密`, `NOPASSWD`, `sudo 不用输密码`) or to revert back to password-required mode.
---

# Sudo Nopasswd Toggle

Enable, inspect, or remove a per-user passwordless sudo rule using a managed drop-in file instead of editing `/etc/sudoers` directly. Prefer the bundled script for deterministic changes and validate the resulting config after every write.

## Workflow

### 1. Confirm the target action and user

Determine:

- action: `enable`, `disable`, or `status`
- target user: default to `whoami` unless the user names another account
- whether the user explicitly wants full `NOPASSWD:ALL` access

If the request is ambiguous, assume the current user.

### 2. Use the managed drop-in script

Use `scripts/manage_sudo_nopasswd.sh` instead of editing `/etc/sudoers` inline.

Examples:

```bash
bash scripts/manage_sudo_nopasswd.sh status
bash scripts/manage_sudo_nopasswd.sh enable --user dgx
bash scripts/manage_sudo_nopasswd.sh disable --user dgx
```

The script manages only:

- `/etc/sudoers.d/90-<user>-nopasswd`

Do not delete or rewrite unrelated sudoers entries.

### 3. Authenticate safely

Prefer normal `sudo` prompting when possible.

If the user explicitly provides a password and expects non-interactive execution, pass it once on stdin:

```bash
printf '%s\n' "$PASSWORD" | bash scripts/manage_sudo_nopasswd.sh enable --user <user> --password-stdin
printf '%s\n' "$PASSWORD" | bash scripts/manage_sudo_nopasswd.sh disable --user <user> --password-stdin
```

Never store the password in files, shell init, or the skill itself.

### 4. Verify and report the result

After `enable` or `disable`, confirm both syntax and behavior:

```bash
sudo -k
sudo -n true && echo enabled || echo password-required
```

`status` should report the managed file path and whether it exists.

## Behavior

- `enable` installs `USER ALL=(ALL) NOPASSWD:ALL`
- `disable` removes only the managed drop-in and returns the user to the system's normal password policy
- `status` shows whether the managed drop-in exists and prints its current contents when present

Treat passwordless sudo as high risk. If the user asks for a safer setup, scope `NOPASSWD` to specific commands instead of `ALL`.

## Resource

### `scripts/manage_sudo_nopasswd.sh`

Use this script for `status`, `enable`, and `disable`. It validates username input, writes the drop-in atomically, and runs `visudo` checks.
