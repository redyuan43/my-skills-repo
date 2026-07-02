---
name: gh-auth-bootstrap
description: Configure and verify GitHub CLI authentication reuse for trusted personal devices. Use when the user wants to avoid repeated `gh auth login` device-code and 2FA prompts across multiple machines, set up Git HTTPS credential reuse through `gh auth git-credential`, bootstrap remote devices over SSH, or diagnose why GitHub CLI/Git keeps asking to log in again.
---

# GitHub CLI Auth Bootstrap

## Overview

Use this skill to turn GitHub authentication into a one-time-per-device setup: the user completes browser/device-code login and 2FA once, `gh` stores the token locally, and Git HTTPS operations reuse that credential through the GitHub CLI credential helper.

Never bypass 2FA, copy tokens between devices, or print raw tokens. Prefer each trusted personal device owning its own credential in the local keyring or, on headless hosts without a secret service, the local `gh` hosts file.

## Workflow

1. Inspect current state before changing anything:
   ```bash
   gh auth status --hostname github.com
   git config --show-origin --get-regexp '^credential\.|^url\.|^user\.' || true
   ```

2. If `gh` is already logged in, do not re-run the login flow. Configure reuse only:
   ```bash
   gh config set git_protocol https --host github.com
   gh auth setup-git --hostname github.com
   ```

3. If `gh` is not logged in, start one browser/device-code login and give the user the code and URL. The user must complete GitHub 2FA in the browser.

4. Prefer the bundled script for repeatable setup:
   ```bash
   scripts/gh-auth-bootstrap.sh github.com
   ```

5. For multiple SSH-accessible devices, copy the script to each host and run it there. Do not copy `~/.config/gh/hosts.yml` or any token from one device to another.

## Validation

Use these checks after setup:

```bash
gh auth status --hostname github.com
gh api --hostname github.com user --jq .login
git credential fill <<'EOF' | sed -E 's/^password=.*/password=***MASKED***/'
protocol=https
host=github.com

EOF
```

Success means `gh auth status` shows the intended account, Git operations protocol is `https`, and `git credential fill` returns the username plus a masked password/token.

## Failure Patterns

- Repeated login prompts usually mean Git is not using the `gh` credential helper, the keyring is not unlocked, `GH_TOKEN`/`GITHUB_TOKEN` is overriding stored credentials, or the environment is ephemeral.
- On headless servers, `gh auth status` may report credentials stored in `~/.config/gh/hosts.yml` instead of keyring. Treat this as functional but less secure; avoid broad token scopes and restrict file permissions.
- If the user wants automation without browser 2FA, do not suggest bypassing 2FA. Use an explicit machine-identity design instead, such as deploy keys, GitHub App credentials, or fine-grained short-lived tokens.

## Remote Device Pattern

For aliases such as `ivan`, `AMD`, and `spark`, first verify SSH reachability and installed tools:

```bash
ssh <alias> 'hostname; whoami; command -v gh; command -v git; gh auth status --hostname github.com || true'
```

Then copy and run the script:

```bash
ssh <alias> 'mkdir -p "$HOME/.local/bin"'
scp scripts/gh-auth-bootstrap.sh <alias>:~/.local/bin/gh-auth-bootstrap
ssh <alias> 'chmod 755 "$HOME/.local/bin/gh-auth-bootstrap"; "$HOME/.local/bin/gh-auth-bootstrap"'
```
