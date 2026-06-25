---
name: siyuan-codex-remote-install
description: Install or repair the Siyuan-branded Codex CLI from the user's redyuan43/codex GitHub release on remote Linux/Jetson/AGX hosts over SSH, including one-command fleet upgrades for AMD, ai, agx, nano, and nano2, release asset selection, local-download-plus-scp fallback, user-level wrapper creation, PATH verification, and optional Codex auth transfer.
---

# Siyuan Codex Remote Install

Use this skill when the user asks to install, update, or repair the Siyuan-branded Codex CLI on a remote SSH host such as `agx`, especially when they mention the release lives in `redyuan43/codex`.

Also use this skill when the user says `全部升级`, `所有设备升级`, or asks to upgrade the known Siyuan Codex fleet. The default fleet is:

```text
AMD ai agx nano nano@nano2
```

## Safety Rules

- Install into the remote user's home directory by default. Do not write to `/usr`, install system packages, or use `sudo` unless the user explicitly asks.
- Do not run `git commit`, `git push`, or modify branches unless the user explicitly asks and confirms.
- Treat `~/.codex/auth.json` as sensitive. Before copying it to a remote host, show the dangerous-operation confirmation block and wait for an explicit confirmation such as "确认".
- If a remote auth file already exists, back it up before replacing it and keep final permissions at `600`.

## Standard Workflow

1. Identify the SSH target and platform:

```bash
ssh "<host>" "uname -a; uname -m; cat /etc/os-release | tr '\n' ' '"
```

For Jetson AGX, expect Ubuntu 22.04 and `aarch64`.

2. Find the latest release and asset:

```bash
curl -fsSL "https://api.github.com/repos/redyuan43/codex/releases/latest" \
  | jq -r '.tag_name, .name, (.assets[]? | [.name, .browser_download_url] | @tsv)'
```

Field note: the Siyuan release may provide only an npm package asset such as `siyuan-codex-npm-0.139.0-siyuan.1.tgz`, not a `.deb`, AppImage, or plain binary tarball.

3. Inspect the npm tarball before installing when the shape is unknown:

```bash
tar -tzf "siyuan-codex-npm-<version>.tgz" | head -80
tar -xzf "siyuan-codex-npm-<version>.tgz" package/package.json
jq . package/package.json
```

The package should contain `vendor/aarch64-unknown-linux-musl/codex/codex` and `vendor/x86_64-unknown-linux-musl/codex/codex`; it usually maps both `codex` and `siyuan` to `bin/codex.js`.

4. Prefer the bundled native binary if the remote host lacks Node/npm. Select the target triple from `uname -m`, then create a versioned user-level install:

- App root: `~/.local/share/siyuan-codex/<version>`
- Commands: `~/.local/bin/siyuan` and `~/.local/bin/codex`
- Wrapper must resolve symlinks with `readlink -f "${BASH_SOURCE[0]}"`; otherwise launching through `~/.local/bin/siyuan` may incorrectly calculate `APP_ROOT` as `~/.local/bin`.

5. Verify both direct and interactive-shell behavior:

```bash
ssh "<host>" "\"/home/<user>/.local/bin/siyuan\" --version"
ssh "<host>" "bash -ic 'command -v siyuan; siyuan --version; command -v codex; codex --version'"
```

Non-interactive `bash -lc` may not load the user's `.bashrc`; use `bash -ic` for "what happens when I SSH in and type it" validation.

## Install Script

Use the bundled script for the common path:

```bash
scripts/install_siyuan_codex_remote.sh --host agx
```

Useful options:

```bash
scripts/install_siyuan_codex_remote.sh --host agx --version 0.139.0-siyuan.1
scripts/install_siyuan_codex_remote.sh --host agx --repo redyuan43/codex
scripts/install_siyuan_codex_remote.sh --all --version 0.139.0-siyuan.2
scripts/install_siyuan_codex_remote.sh --hosts "AMD ai agx nano nano@nano2"
```

The script downloads the release asset locally, transfers it with `scp`, installs under the remote user's home, creates the wrappers, and verifies `siyuan --version`.

## One-Command Fleet Upgrade

When the user says `全部升级`, run:

```bash
scripts/upgrade_all_siyuan_codex.sh
```

For non-interactive runs, provide the Nano password with an environment variable:

```bash
SIYUAN_NANO_PASSWORD='...' scripts/upgrade_all_siyuan_codex.sh
```

The wrapper calls `install_siyuan_codex_remote.sh --all`. It upgrades `AMD`, `ai`, `agx`, `nano`, and `nano@nano2`, downloads the GitHub Release tarball once, copies it to each host, installs a versioned user-level wrapper under `~/.local/share/siyuan-codex/<version>`, and ensures `codex` / `siyuan` aliases in `~/.bashrc` point at the new wrapper.

## Remote Download Fallback

If remote `curl` against GitHub release assets stalls at 0 bytes, do not keep retrying on the remote host. Download locally, then `scp` the asset:

```bash
curl -fL --retry 3 --connect-timeout 20 -o "/tmp/siyuan-codex-npm-<version>.tgz" "<asset-url>"
scp "/tmp/siyuan-codex-npm-<version>.tgz" "<host>:/home/<remote-user>/.cache/"
```

This was required on `agx` even though SSH itself was healthy.

## Optional Auth Transfer

Only do this after explicit confirmation:

```text
⚠️ 危险操作检测！
操作类型：通过 SSH 拷贝 Codex 账户认证文件
影响范围：从本机 ~/.codex/auth.json 拷贝到 <host>:~/.codex/auth.json
风险评估：该文件可能包含可用于访问 Codex/ChatGPT 账户的令牌；如果目标机器被他人访问，账户可能被滥用。SSH 传输本身是加密的。

请确认是否继续？[需要明确的"是"、"确认"、"继续"]
```

After confirmation:

```bash
ssh "<host>" 'mkdir -p "$HOME/.codex"; if [ -f "$HOME/.codex/auth.json" ]; then cp -p "$HOME/.codex/auth.json" "$HOME/.codex/auth.json.backup-$(date +%Y%m%d-%H%M%S)"; fi'
scp "$HOME/.codex/auth.json" "<host>:/home/<remote-user>/.codex/auth.json"
ssh "<host>" 'chmod 600 "$HOME/.codex/auth.json"; stat -c "%U %G %a %s %n" "$HOME/.codex/auth.json"'
```

Do not print the contents of `auth.json`.
