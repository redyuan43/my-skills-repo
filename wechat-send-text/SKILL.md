---
name: wechat-send-text
description: Send text to a specified WeChat chat or group on Ubuntu X11 through the local `PyWxDump` send pipeline. Use when the user wants a reusable text-send wrapper with the same window-mode, GUI prompt, and main-window vision controls as the file and screenshot send skills.
---

# Wechat Send Text

## Overview

Use `scripts/send_wechat_text.sh` to send plain text through `PyWxDump tools/linux_wx_chat_daemon.py send-text`. This skill keeps the default `standalone` behavior, auto-resolves the local `PyWxDump` clone, prefers the repo-local virtualenv Python, and passes the newest `db_storage` path when it can discover one. By default it force-minimizes the chat window after sending, and it also exposes `--post-send-minimize` and `--post-send-force-minimize` for explicit control.

## Workflow

1. Determine the target chat title.
2. Provide the text explicitly through `--text`.
3. Choose `--window-mode standalone|main|auto`; default remains `standalone`.
4. If `--window-mode main` is used for a new target, optionally pass explicit main-window vision settings.
5. By default the wrapper force-minimizes the chat window after sending; if needed, add `--post-send-minimize` or `--post-send-force-minimize` explicitly for clarity.
6. Run the script and read the final JSON plus the extra wrapper summary line.

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

Send and force-minimize the chat window afterward:

```bash
skills/wechat-send-text/scripts/send_wechat_text.sh \
  --chat "gaming" \
  --text "你好" \
  --window-mode auto \
  --post-send-force-minimize
```

## Constraints

- This skill assumes Ubuntu X11.
- By default the wrapper tries to auto-resolve the local `PyWxDump` clone, repo-local `.venv` Python, `XAUTHORITY`, and the newest `db_storage`. Use `--pywxdump-root` to override the repo path when needed.
- `--window-mode standalone` remains the default and requires the target chat to already be open as an independent WeChat window.
- `--window-mode main` relies on WeChat main-window search and post-send database verification.
- By default the wrapper enables `--post-send-force-minimize`, so the send target window is minimized after a successful send instead of restoring focus.
- `--post-send-minimize` minimizes the target window only when there is no previous window to restore.
- `--post-send-force-minimize` always minimizes the target window after sending and takes priority over restore behavior.
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
