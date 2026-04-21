# Linux Desktop Auto-Start Case Notes

This note captures how to turn a one-machine Linux startup fix into reusable published skill guidance.

## Case shape

The solved task had two startup goals after login:

- `v2rayN` should start automatically and stay in the background with its proxy-active behavior preserved.
- `CapsWriter` should launch a background development stack after login.

The final working setup did not come from a single command. It came from identifying the correct persistence layer for each app.

## Reusable decision order

When publishing a Linux desktop startup skill, check startup control points in this order:

1. Application-owned persisted settings
2. XDG desktop-session auto-start entries in `~/.config/autostart`
3. User-level `systemd` units in `~/.config/systemd/user`
4. System-wide services only if the task truly requires machine-level startup rather than user-login startup

This order keeps the published skill aligned with how Linux desktop apps actually behave.

## What this case taught

### 1. Prefer app-native persistence over wrappers

For `v2rayN`, the key behavior was already represented in the application's persisted config:

- `GuiItem.AutoRun`
- `UiItem.AutoHideStartup`
- existing proxy/tun state

That means the published guidance should first inspect and update the app's own config instead of immediately inventing a shell wrapper or a new `systemd` unit.

### 2. Use desktop auto-start for desktop-session apps

`v2rayN` is a desktop app, so a user desktop entry under `~/.config/autostart/*.desktop` is a better fit than a custom background service.

Published guidance should explicitly distinguish:

- login-session startup: `~/.config/autostart`
- background service management: `systemd --user`

Do not blur them together.

### 3. Reuse the already-tested launcher, not the raw command

The user mentioned `./start_all.sh`, but the machine already had a better maintained launcher:

- `/home/ivan/.local/bin/capswriter-dev start`
- backed by `capswriter_dev.sh`
- already designed for background launch, logs, PID files, and restart behavior

When publishing a skill, document the real stable entrypoint that was validated on the machine. Do not blindly publish the user's first-mentioned command if the repo already contains a safer wrapper.

### 4. Shell environment matters for login auto-start

Desktop-session auto-start does not always inherit interactive shell setup such as `nvm` paths.

In this case, the safer desktop entry used:

```bash
bash -lc "/home/ivan/.local/bin/capswriter-dev start"
```

That pattern should be documented when the app depends on `node`, `npm`, or other tools provided by shell initialization.

### 5. Keep only one owner for one startup responsibility

The machine originally had more than one startup path for CapsWriter:

- a user `systemd` service for `capswriter-server.service`
- a separate background dev launcher path

The final cleanup kept only the validated `capswriter-dev` login auto-start path and removed the redundant `capswriter-server.service`.

Published skills should include an explicit consolidation step:

- identify all startup owners
- keep one
- disable and remove the redundant one if the user wants a single canonical path

### 6. Verification should be concrete

A publishable skill should not stop at "files written". It should verify runtime state with concrete checks such as:

- `systemctl --user status <unit>`
- `systemctl --user is-enabled <unit>`
- `desktop-file-validate ~/.config/autostart/*.desktop`
- `ss -ltnp | rg ':8001|:8002|:5175'`
- process checks with `pgrep -af`

## Publishable guidance pattern

When converting a real startup fix into a public skill, keep the narrative short and reusable:

- state the user's desired startup behavior
- identify the real persistence layer
- record the exact files changed
- explain why one startup path was preferred
- include a short verification checklist
- include a cleanup/consolidation step if duplicate startup mechanisms existed

## Anti-patterns to avoid

- Publishing only the final shell command without the persistence path
- Adding a `systemd` service for a desktop app when `~/.config/autostart` is the real fit
- Leaving duplicate startup paths active
- Assuming interactive shell `PATH` is available during login auto-start
- Treating "service enabled" as enough without checking the actual listening ports or processes
