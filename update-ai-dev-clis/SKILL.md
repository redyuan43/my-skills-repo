---
name: update-ai-dev-clis
description: Update, install, and troubleshoot AI/developer CLI tools (especially `kilo`, `claude`, `codex`, and `opencode`) in local shell environments. Use when a user asks to upgrade a CLI, fix a failed upgrade, identify install method (npm/brew/curl/self-managed updater), verify versions and executable paths, handle `sudo` for root-owned global installs, or resolve `command not found` during CLI maintenance.
---

# Update AI Dev CLIs

## Overview

Standardize a fast workflow for updating common AI coding CLIs and proving the result with path/version checks. Prioritize install-method detection, safe privilege handling, and clear final reporting.

## Workflow

### 1. Triage the requested tools

Run discovery commands first for every requested CLI:

- `which <cmd>`
- `<cmd> --version` (or `-v`)
- `ls -l "$(which <cmd>)"` if present

Use this step to separate three cases:

- Installed and updatable
- Installed but failing due to network/permissions
- Not installed (`command not found`)

If a tool name may be mistyped (for example `kilo` vs `kiro`), check likely variants before assuming the tool is missing.

### 2. Determine install method before updating

Prefer path and symlink inspection over guessing. The same CLI may support multiple update methods.

Use path clues such as:

- Home dir self-managed binary (`~/.opencode/bin/opencode`) -> built-in updater often knows the method
- User-local symlink (`~/.local/bin/claude`) -> built-in `claude update`
- Root-owned `/usr/local/bin/<cmd>` symlink to npm global package -> `npm install -g ...`, often with `sudo`

Confirm npm-based installs with `npm list -g --depth=0 <package>`.

When npm is configured with a user-local prefix, also check:

- `npm config get prefix`
- `npm root -g`
- `which <cmd>` and `readlink -f "$(which <cmd>)"`

This catches mixed-install situations where the same CLI exists in both `~/.npm-global` and `/usr/local`.

### 3. Run the updater that matches the install method

Prefer vendor-native update commands when they exist (`opencode upgrade`, `claude update`, `kilo upgrade`). Fall back to the package manager if the built-in updater is unavailable or the install method is clearly package-manager-based.

If the command writes into root-owned locations (for example `/usr/local/lib/node_modules`), request `sudo` and explain why.

Treat passwords as sensitive. Prefer interactive `sudo` prompts. Only use non-interactive password piping if the user explicitly provides the password and expects you to use it.

### 4. Handle failures pragmatically

Common failure classes:

- Network restricted / `ECONNREFUSED`: request permission/escalation for network access and rerun
- Permission denied / root-owned install prefix: use `sudo` (or switch to a user-local install if the user wants)
- npm `ENOTEMPTY` during global update: inspect the package directory for stale hidden temp directories such as `@scope/.pkg-*`; remove only the stale temp directory or old package copy after verifying the active install path
- Updater spinner hangs with no output: poll the process and independently verify version/path before retrying
- Update succeeded but shell still reports the old version: compare `which <cmd>` with `sudo which <cmd>`, inspect `npm config get prefix`, and look for duplicate installs in both user-local and system npm roots
- Command still missing after update: install instead of update, then verify

If the tool is unfamiliar and the user says to search, use web lookup and prefer official docs for package names and update commands.

### 5. Verify and report exact outcomes

After each update or install, run:

- `which <cmd>`
- `<cmd> --version` (or `-v`)

Report:

- What changed (old version -> new version) when known
- Which tools were already latest
- Which tools were missing and were installed (or still missing)
- Any residual issue (for example connectivity warning during version check)

## Tool Notes

Read `references/commands.md` for exact commands and package names for `kilo`, `claude`, `codex`, and `opencode`, plus troubleshooting patterns seen in real sessions.
