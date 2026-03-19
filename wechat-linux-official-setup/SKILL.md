---
name: wechat-linux-official-setup
description: Install the official Linux WeChat client on ARM Ubuntu, launch it in the current GNOME session, pin it to the launcher, and guide the manual QR login flow. Use when the user wants the official Tencent package on an ARM Linux machine and needs a repeatable install-and-login workflow.
---

# WeChat Linux Official Setup

## Overview

Use `scripts/install_wechat_official.sh` to install the official Tencent Linux WeChat package on ARM Ubuntu, then launch the client in the current desktop session and pin it to the GNOME launcher.

This skill is for the official Linux build only:

- ARM machines use `WeChatLinux_arm64.deb`
- The current official landing page is `https://linux.weixin.qq.com/`
- Login is still manual inside the WeChat UI after the client opens

## Workflow

1. Confirm the machine is ARM Linux.
2. Download the official ARM package from the Tencent Linux WeChat page.
3. Install the package with `apt` so dependencies resolve cleanly.
4. Verify that `wechat` is installed and the desktop entry exists.
5. Launch WeChat in the current GNOME session with the correct `DISPLAY` and `XAUTHORITY`.
6. Pin `wechat.desktop` to the GNOME favorites list if requested.
7. Complete QR login manually in the client.

## Quick Use

Install, launch, and pin:

```bash
skills/wechat-linux-official-setup/scripts/install_wechat_official.sh --launch --pin
```

Install only:

```bash
skills/wechat-linux-official-setup/scripts/install_wechat_official.sh
```

Use a different package URL when Tencent changes the download path:

```bash
skills/wechat-linux-official-setup/scripts/install_wechat_official.sh \
  --package-url "https://dldir1v6.qq.com/weixin/Universal/Linux/WeChatLinux_arm64.deb"
```

## Constraints

- This workflow assumes an ARM Linux host.
- The official package path may change, so the script accepts `--package-url`.
- Login cannot be automated safely; the skill only opens the client and leaves QR scanning to the user.
- GNOME launcher pinning requires a GNOME session with `gsettings` available.

## Resources

- `scripts/install_wechat_official.sh`: download, install, launch, and pin the official ARM client
