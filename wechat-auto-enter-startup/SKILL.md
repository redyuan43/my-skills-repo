---
name: wechat-auto-enter-startup
description: Install a vision-based Linux WeChat auto-enter flow that starts `wechat`, detects the green `Enter Weixin` button from a window screenshot, clicks it, and optionally enables desktop-login autostart through `~/.config/autostart`. Use when the user wants to automate the initial WeChat enter button, replace brittle fixed-coordinate clicking with image-based detection, or make the flow run automatically after XFCE/GNOME login.
---

# Wechat Auto Enter Startup

## Overview

Use `scripts/install_wechat_auto_enter.sh` to install or update the full workflow:

1. Copy the runtime script to `~/Desktop/wechat_auto_enter.sh`
2. Install an autostart wrapper to `~/.local/bin/wechat_auto_enter_autostart.sh`
3. Write `~/.config/autostart/wechat-auto-enter.desktop`

The installed runtime script defaults to `vision` mode, which screenshots the WeChat login window, locates the largest green button region, and clicks its center. This avoids fixed coordinates when the Linux WeChat build does not expose a standard accessibility tree.

## When To Use

- The user wants `wechat` to open and automatically press `Enter Weixin`
- The user says the coordinate-based approach is unreliable and wants image-based targeting instead
- The user wants the action to happen automatically after logging into XFCE or GNOME

## Workflow

1. Confirm this is a GUI desktop-login workflow, not a pre-login boot service.
2. Run `scripts/install_wechat_auto_enter.sh`.
3. Keep the default `vision` mode unless the user explicitly wants `key` or legacy `click`.
4. If startup timing is sensitive, set a longer `--autostart-delay`.
5. Use `scripts/selftest.sh` to verify runtime dependencies and installed files.

## Quick Use

Install with desktop-login autostart enabled:

```bash
skills/wechat-auto-enter-startup/scripts/install_wechat_auto_enter.sh
```

Install with a longer login delay:

```bash
skills/wechat-auto-enter-startup/scripts/install_wechat_auto_enter.sh \
  --autostart-delay 12
```

Install but do not keep an autostart entry:

```bash
skills/wechat-auto-enter-startup/scripts/install_wechat_auto_enter.sh \
  --no-autostart
```

Install and run once immediately:

```bash
skills/wechat-auto-enter-startup/scripts/install_wechat_auto_enter.sh \
  --run-now
```

## Constraints

- This is for a logged-in graphical session. It is not a headless boot automation.
- Runtime requires `wechat`, `xdotool`, `gnome-screenshot`, `python3`, and Pillow (`PIL`).
- If the WeChat build still exposes a focusable default button, `key` mode can be used, but `vision` is the stable default.

## Resources

- `scripts/install_wechat_auto_enter.sh`: installer for runtime script and autostart entry
- `scripts/wechat_auto_enter.sh`: runtime script that launches WeChat and clicks the green button
- `scripts/wechat_auto_enter_autostart.sh`: wrapper run from XDG autostart after desktop login
- `scripts/selftest.sh`: syntax and dependency checks
