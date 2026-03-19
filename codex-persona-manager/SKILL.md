---
name: codex-persona-manager
description: Install and manage cat-persona templates across Codex, Claude Code, and OpenCode. Use when the user wants to migrate AI CLI personalities to a new computer, list available personas with names and styles, interactively choose one persona instead of editing config files manually, or switch the active persona for `~/.codex/AGENTS.md`, Claude Code output styles, or OpenCode global rules with backups.
---

# Codex Persona Manager

Use this skill when the user wants to set up or switch Codex, Claude Code, or OpenCode personalities on a machine without manually editing config files.

## What this skill provides

- Bundled persona templates under `assets/personas/`
- An interactive installer/switcher script
- A safe activation flow with backup of the previous config/rules file
- A persona reference table with persona id, display style, and self-name
- Multi-target installation for:
  - Codex: `~/.codex/AGENTS.md`
  - Claude Code: `~/.claude/output-styles/` plus `~/.claude/settings.json`
  - OpenCode: `~/.config/opencode/AGENTS.md`

## Default workflow

1. If the user asks what personas are available, run:

```bash
bash scripts/manage_codex_personas.sh --list
```

2. Show the list to the user in chat and ask:

- which persona they want
- which target they want: `Codex` / `Claude Code` / `OpenCode` / all

3. After the user chooses, activate it:

```bash
bash scripts/manage_codex_personas.sh --target <codex|claude|opencode|all> --activate <persona-id>
```

4. Confirm the active persona name and the target file(s):

- `~/.codex/AGENTS.md`
- `~/.claude/output-styles/<persona-id>.md`
- `~/.claude/settings.json`
- `~/.config/opencode/AGENTS.md`

## Interactive mode

If the user wants a terminal-style selection flow, run:

```bash
bash scripts/manage_codex_personas.sh
```

This will:

- ask which target they want to configure
- install/update the bundled personas into the chosen tool directories
- install/update helper scripts where applicable
- print the available personas with numbers
- prompt the user to choose one
- back up the previous active config/rules file
- activate the selected persona

## Non-interactive options

- `--list`: list bundled personas with names and descriptions
- `--install-only`: only install/update personas and helper scripts
- `--target <codex|claude|opencode|all>`: choose install/activation target
- `--activate <persona-id>`: install/update then activate the given persona id on the target

## Safety rules

- Before overwriting `AGENTS.md` or `settings.json`, rely on the script's backup behavior instead of raw `cp`.
- Do not ask the user to hand-edit config files unless they explicitly want manual control.
- Prefer chat-driven selection: list personas first, let the user choose, then activate.

## References

- Persona summary table: `references/persona-table.md`
