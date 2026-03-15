---
name: wechat-screenshot-send
description: Capture the current desktop on Ubuntu X11 and immediately send the screenshot to a specified WeChat chat or group through the existing `wechat-send-file` skill. Use when the user asks to “截个图发给某人/某个群”, wants the action completed in one shot without a confirmation round, or wants the screenshot saved locally and sent right away.
---

# Wechat Screenshot Send

## Overview

Use `scripts/screenshot_send_wechat.sh` for a one-shot workflow: capture the desktop, save the screenshot under `~/Pictures/Screenshots/`, and immediately send it to the specified standalone WeChat chat window.

## Workflow

1. Determine the target chat title exactly as shown in the standalone WeChat window.
2. Capture the current desktop with `gnome-screenshot`.
3. Save the screenshot to `~/Pictures/Screenshots/desktop-<timestamp>.png`.
4. Call the existing `wechat-send-file` flow to send the screenshot.
5. Do not ask for an extra confirmation step. If the window is missing or send fails, return the error directly.

## Quick Use

Capture and send to a group or contact immediately:

```bash
skills/wechat-screenshot-send/scripts/screenshot_send_wechat.sh \
  --chat "新技术讨论"
```

Delay a few seconds before capture:

```bash
skills/wechat-screenshot-send/scripts/screenshot_send_wechat.sh \
  --chat "Ivan" \
  --delay 3
```

Resolve the final command without capturing or sending:

```bash
skills/wechat-screenshot-send/scripts/screenshot_send_wechat.sh \
  --chat "新技术讨论" \
  --print-only
```

## Constraints

- The target chat window must already be open as a standalone WeChat window.
- This skill assumes Ubuntu X11 and `gnome-screenshot` is available.
- The script is intentionally non-interactive once started.
- The actual send step delegates to `skills/wechat-send-file/scripts/send_wechat_file.sh`.

## Resources

- `scripts/screenshot_send_wechat.sh`: capture a desktop screenshot and send it in one shot.
