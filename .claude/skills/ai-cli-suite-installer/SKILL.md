---
name: ai-cli-suite-installer
description: Install, upgrade, and troubleshoot six AI CLIs (claude, kilo, codex, opencode, qwen, gemini) on Linux/macOS. Use when the user asks to install/upgrade these CLIs, batch-manage them with one script, fix npm global permission errors (EACCES/EPERM), switch npm to user-level global prefix (~/.npm-global), or avoid interactive upgrade hangs (kilo/opencode/claude).
---

# AI CLI Suite Installer

Use this skill when the user wants a single workflow to manage these CLIs:

- `claude`
- `kilo`
- `codex`
- `opencode`
- `qwen`
- `gemini`

## Primary workflow (bundled script)

Prefer the bundled script:

- `ai-cli-suite-installer/scripts/install_ai_clis.sh`

Typical usage:

```bash
bash ai-cli-suite-installer/scripts/install_ai_clis.sh --check
bash ai-cli-suite-installer/scripts/install_ai_clis.sh
bash ai-cli-suite-installer/scripts/install_ai_clis.sh -y
```

What the script does:

- Detects installed vs missing CLIs
- Installs missing CLIs
- Prompts to upgrade installed CLIs (or auto-upgrades with `-y`)
- Auto-configures npm user-level global installs (`~/.npm-global`) unless disabled
- Avoids `kilo upgrade` interactive TUI by using npm upgrade path
- Adds timeout protection for `claude` / `kilo` / `opencode` upgrades

## npm permission (EACCES/EPERM) workflow

If npm global installs fail with permission errors:

1. Check prefix:
   - `npm config get prefix`
2. If it points to system dirs (for example `/usr`), switch to user-level:
   - `npm config set prefix ~/.npm-global`
3. Ensure PATH includes:
   - `~/.npm-global/bin`
4. Re-open terminal or start a login shell, then re-run the script.

The bundled script already automates this in most cases.

## CLI-specific notes

- `kilo`: do not rely on `kilo upgrade` in automation if it shows TUI confirmation; prefer `npm update -g @kilocode/cli`
- `codex`: npm package is `@openai/codex`
- `qwen`: npm package is `@qwen-code/qwen-code`
- `gemini`: npm package is `@google/gemini-cli`
- `claude`: prefer `claude update`; installer fallback may be needed
- `opencode`: `opencode upgrade` may hang/no-output; use timeout/fallback installer

## Fast verification

After install/upgrade, verify:

```bash
command -v claude kilo codex opencode qwen gemini
claude --version
kilo --version
codex --version
opencode --version
qwen --version
gemini --version
```

## When to patch the script

Patch `scripts/install_ai_clis.sh` if:

- package names change
- official install URLs change
- a CLI adds a reliable non-interactive upgrade flag
- timeout defaults need adjustment
