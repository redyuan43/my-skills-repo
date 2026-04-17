# AI/Dev CLI Update Commands

Use this file for exact commands and package names after the skill triggers.

## Quick Triage

Run for each requested CLI:

```bash
which <cmd>
<cmd> --version
ls -l "$(which <cmd>)"
```

If `which` fails, treat it as missing and switch to install flow. Check likely misspellings only when plausible (for example `kilo` vs `kiro`).

## `opencode`

Preferred updater:

```bash
opencode upgrade
```

Version-specific:

```bash
opencode upgrade v1.2.10
```

Method override if auto-detection fails:

```bash
opencode upgrade --method brew
opencode upgrade --method npm
opencode upgrade --method pnpm
opencode upgrade --method bun
opencode upgrade --method curl
```

Path clue from real usage:

- `~/.opencode/bin/opencode` commonly indicates self-managed install with `curl` updater

Verify:

```bash
opencode -v
```

## `claude` (Claude Code)

Preferred updater:

```bash
claude update
```

Useful diagnostics:

```bash
claude --help
claude doctor
claude --version
```

Path clue from real usage:

- `~/.local/bin/claude -> ~/.local/share/claude/versions/<version>`

Common failure:

- `ECONNREFUSED` while fetching releases usually indicates blocked network access; rerun with network-enabled permissions if available.

## `codex` (OpenAI Codex CLI)

Common global npm package:

```bash
npm list -g --depth=0 @openai/codex
npm config get prefix
npm root -g
which codex
readlink -f "$(which codex)"
```

Update:

```bash
npm install -g @openai/codex@latest
```

If installed under root-owned `/usr/local`, use `sudo`:

```bash
sudo npm install -g @openai/codex@latest
```

Path clue from real usage:

- `/usr/local/bin/codex -> ../lib/node_modules/@openai/codex/bin/codex.js`

Verify:

```bash
codex --version
```

Note:

- Version may remain unchanged after a successful install if the current version is already the latest published npm release.
- If `npm install -g @openai/codex` fails with `ENOTEMPTY` while renaming `@openai/codex` to `@openai/.codex-*`, inspect the package parent directory for a stale hidden temp directory left by a previous failed upgrade.

Codex-specific recovery for mixed user/system npm installs:

```bash
which codex
readlink -f "$(which codex)"
codex --version

sudo sh -lc 'which codex; readlink -f "$(which codex)"; codex --version; npm config get prefix; npm root -g; npm ls -g @openai/codex --depth=0'

ls -la "$HOME/.npm-global/lib/node_modules/@openai"
find "$HOME/.npm-global/lib/node_modules/@openai" -maxdepth 1 -mindepth 1 -printf '%f\n' | sort
```

Interpretation:

- If non-sudo `codex` points to `~/.npm-global/...` but `sudo` points to `/usr/local/...`, you have two installs.
- If `sudo npm install -g` upgraded `/usr/local` but your shell still resolves `~/.npm-global/bin/codex`, the old user-local install is still winning in `PATH`.
- If a stale directory like `~/.npm-global/lib/node_modules/@openai/.codex-XXXX` exists, remove that stale temp directory before retrying the user-local npm upgrade.

Keep in mind:

- Do not delete unrelated custom wrappers such as `local_codex`; verify whether they are aliases/functions before cleanup.
- If the user wants only the new system install, remove the old user-local `codex` package and broken shim, then verify `which codex` resolves to `/usr/local/bin/codex`.

## `kilo` (Kilo Code CLI)

Preferred updater (if installed):

```bash
kilo upgrade
```

npm package update/install:

```bash
npm install -g @kilocode/cli@latest
```

If `/usr/local` is root-owned:

```bash
sudo npm install -g @kilocode/cli@latest
```

Verify:

```bash
kilo --version
npm list -g --depth=0 @kilocode/cli
```

Note:

- `kilo --version` may print a network warning (for example models metadata fetch failure) and still return a valid version number.

## Permission and Safety Rules

- Explain why `sudo` is needed before using it (usually root-owned global npm install paths).
- Prefer interactive `sudo` password entry.
- If the user explicitly shares a password and asks you to proceed, use it only for the requested command and do not persist it.

## Reporting Template (concise)

- `kilo`: installed/updated to `<version>` (or missing / failed)
- `claude`: updated from `<old>` to `<new>` (or already latest / failed)
- `codex`: updated via npm; current version `<version>`
- `opencode`: updated via built-in upgrader; current version `<version>`

Include any warnings (network restrictions, partial failures, follow-up steps).
