---
name: v2rayn-linux-github-install
description: Install `v2rayN` on Linux directly from the official GitHub Releases page, especially when the user specifies a concrete version such as `7.20.2`, needs the Linux `.deb` package rather than Windows assets, or wants verification of the installed GUI client on Ubuntu ARM64/x64.
---

# v2rayN Linux GitHub Install

Use this skill when the user wants `v2rayN` installed from GitHub Releases on Linux.

## What to verify first

- Confirm the machine is Linux and capture:
  - distro and version from `/etc/os-release`
  - architecture from `uname -m`
- Check whether `v2rayn` is already installed:
  - `dpkg -s v2rayn`
  - `command -v v2rayn`

## Release selection

- Use the official repo: `https://github.com/2dust/v2rayN`
- Use the Linux release asset that matches the machine architecture.
- If the user specifies a version, use that exact version.
- For ARM64 machines, prefer:
  - `v2rayN-linux-arm64.deb`
- For x64 machines, prefer:
  - `v2rayN-linux-x64.deb`

## Install workflow

1. Download the requested asset to a temp path such as `/tmp/v2rayN-linux-<arch>.deb`.
2. Install with apt so dependencies are handled:

```bash
sudo apt-get install -y /tmp/v2rayN-linux-arm64.deb
```

3. Verify:
  - `dpkg -s v2rayn`
  - `command -v v2rayn`
  - `dpkg -L v2rayn | rg 'v2rayn.desktop|/usr/bin/v2rayn|/opt/v2rayN'`

## Expected Linux result

- Package name: `v2rayn`
- Main command: `v2rayn`
- Desktop file: `/usr/share/applications/v2rayn.desktop`
- Main app directory: `/opt/v2rayN`

## Failure handling

- If DNS or download fails once, retry the GitHub download once before changing approach.
- If the user asks for Linux but names a Windows-oriented client, verify whether the repo now ships Linux assets before rejecting the request.
- If a prior command downloaded the wrong version, do not install it; replace the temp file with the user-requested version.
- If the package is installed but GUI launch is not verified, say so explicitly.

## Response requirements

- State the exact version installed.
- State the exact command to launch it: `v2rayn`
- Provide the official repo and releases links.
- Mention any related older `v2ray` core package separately so the user does not confuse it with the GUI client.
