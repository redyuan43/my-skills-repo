---
name: wechat-send-file
description: Send a local file to a specified WeChat chat or group on Ubuntu X11 through the existing `wechat-auto-reply` project. Use when the user asks to send a file to a WeChat conversation, wants a file auto-picked from `~/Documents`, wants to avoid JPEGs by default, or wants the existing GUI send flow wrapped into a reusable command.
---

# Wechat Send File

## Overview

Use `scripts/send_wechat_file.sh` to send a local file to a WeChat chat window that is already open. Prefer an explicit file path when the user gives one; otherwise, auto-pick from `~/Documents`, excluding JPEG files unless the user explicitly allows them.

## Workflow

1. Determine the target chat title exactly as shown in the WeChat standalone window.
2. If the user provided a file path, use it directly.
3. If the user only said “随便找个文件”, let the script auto-pick from `~/Documents`.
4. Exclude `jpg/jpeg` by default. Only include them when the user explicitly allows JPEG.
5. Run the send script. The script delegates to `wechat-auto-reply/main.py send-file`.

## Quick Use

Explicit file path:

```bash
skills/wechat-send-file/scripts/send_wechat_file.sh \
  --chat "新技术讨论" \
  --path /home/dgx/Documents/videos/IMG_9069.MOV
```

Auto-pick a non-JPEG file from `~/Documents`:

```bash
skills/wechat-send-file/scripts/send_wechat_file.sh \
  --chat "新技术讨论"
```

Allow JPEG when explicitly requested:

```bash
skills/wechat-send-file/scripts/send_wechat_file.sh \
  --chat "新技术讨论" \
  --allow-jpeg
```

Resolve the target without sending, useful for inspection:

```bash
skills/wechat-send-file/scripts/send_wechat_file.sh \
  --chat "新技术讨论" \
  --print-only
```

## Constraints

- The target chat window must already be open as a standalone WeChat window.
- This skill assumes Ubuntu X11 and the existing `wechat-auto-reply` project layout under `/home/dgx/github/DevToolbox/wechat-auto-reply`.
- The script does not browse the main WeChat conversation list; it only delegates to the existing standalone-window send flow.
- JPEG is excluded by default because the current workflow often needs “send anything except JPEG”.

## Resources

- `scripts/send_wechat_file.sh`: choose a file and call the existing `send-file` command.
