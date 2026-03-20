---
name: wechat-send-text
description: Send text to a specified WeChat chat or group on Ubuntu X11 through the local `PyWxDump` send pipeline. Use when the user wants a reusable text-send wrapper with the same window-mode, GUI prompt, and main-window vision controls as the file and screenshot send skills.
---

# Wechat Send Text

## Overview

Use `scripts/send_wechat_text.sh` to send plain text through `PyWxDump tools/linux_wx_chat_daemon.py send-text`. This skill is intentionally thin: it only resolves arguments, forwards them to the local CLI, and prints the final `restore_action` summary.

## Workflow

1. Determine the target chat title.
2. Provide the text explicitly through `--text`.
3. Choose `--window-mode standalone|main|auto`.
4. If `--window-mode main` is used for a new target, optionally pass explicit main-window vision settings.
5. Run the script and read the final JSON plus the extra wrapper summary line.

## Quick Use

```bash
skills/wechat-send-text/scripts/send_wechat_text.sh \
  --chat "新技术讨论" \
  --text "OK"
```

Use the WeChat main window and explicit Coding Plan vision settings:

```bash
skills/wechat-send-text/scripts/send_wechat_text.sh \
  --chat "丁国华" \
  --window-mode main \
  --text "OK" \
  --main-window-vision-base-url "https://coding.dashscope.aliyuncs.com/apps/anthropic/v1" \
  --main-window-vision-model "qwen3.5-plus" \
  --main-window-vision-thinking-budget-tokens 1024
```

Dry run:

```bash
skills/wechat-send-text/scripts/send_wechat_text.sh \
  --chat "新技术讨论" \
  --text "OK" \
  --print-only
```

## Constraints

- This skill assumes Ubuntu X11 and a local `PyWxDump` clone under `/home/ivan/github/PyWxDump` unless `--pywxdump-root` overrides it.
- `--window-mode standalone` requires the target chat to already be open as an independent WeChat window.
- `--window-mode main` relies on WeChat main-window search and post-send database verification.
- For `--window-mode main`, prefer `qwen3.5-plus` plus the Coding Plan Anthropic endpoint when explicit vision settings are needed.

## Selftest

```bash
skills/wechat-send-text/scripts/selftest.sh
```

Safe mode:

```bash
skills/wechat-send-text/scripts/selftest.sh --safe
```

## Resources

- `scripts/send_wechat_text.sh`: thin wrapper around `PyWxDump send-text`
- `scripts/selftest.sh`: dry-run or live selftest for the text wrapper
