---
name: wechat-send-file
description: Send a local file to a specified WeChat chat or group on Ubuntu X11 through the local `PyWxDump` send pipeline. Use when the user asks to send a file to a WeChat conversation, wants a file auto-picked from `~/Documents`, wants to avoid JPEGs by default, or wants the GUI send flow wrapped into a reusable command.
---

# Wechat Send File

## Overview

Use `scripts/send_wechat_file.sh` to send a local file through `PyWxDump tools/linux_wx_chat_daemon.py send-file`. Prefer an explicit file path when the user gives one; otherwise, auto-pick from `~/Documents`, excluding JPEG files unless the user explicitly allows them. The wrapper now supports both `standalone` and `main` window modes, auto-resolves the local `PyWxDump` clone, exposes GUI prompt timing, prints the final `restore_action`, and by default force-minimizes the chat window after sending.

When `--window-mode main` is used for a target that has not been warmed before, the underlying `PyWxDump` flow may need a vision model to click the correct search result row. In practice, `qwen3.5-plus` is the stable choice for this step. If you use 阿里云 Coding Plan, prefer the native Anthropic-compatible endpoint `https://coding.dashscope.aliyuncs.com/apps/anthropic/v1`. Do not assume `qwen3-coder-plus` is reliable for main-window search-result selection.

## Workflow

1. Determine the target chat title.
2. If the user provided a file path, use it directly.
3. If the user only said “随便找个文件”, let the script auto-pick from `~/Documents`.
4. Exclude `jpg/jpeg` by default. Only include them when the user explicitly allows JPEG.
5. Choose `--window-mode standalone|main|auto` depending on whether the chat is already open as an independent window.
6. By default the wrapper force-minimizes the chat window after sending; if needed, add `--post-send-minimize` or `--post-send-force-minimize` explicitly for clarity.
7. Run the send script. The wrapper delegates to `PyWxDump tools/linux_wx_chat_daemon.py send-file`.
8. Read the final JSON and the extra wrapper summary line to inspect `post_send_check`, `matched_local_id`, and `restore_action`.

## Quick Use

Explicit file path:

```bash
skills/wechat-send-file/scripts/send_wechat_file.sh \
  --chat "新技术讨论" \
  --path /home/ivan/Documents/videos/IMG_9069.MOV
```

Use the main WeChat window instead of a standalone chat window:

```bash
skills/wechat-send-file/scripts/send_wechat_file.sh \
  --chat "新技术讨论" \
  --window-mode main \
  --path /home/ivan/Documents/demo.txt
```

Use explicit main-window vision settings for a new target:

```bash
skills/wechat-send-file/scripts/send_wechat_file.sh \
  --chat "丁国华" \
  --window-mode main \
  --path /home/ivan/Documents/demo.txt \
  --main-window-vision-base-url "https://coding.dashscope.aliyuncs.com/apps/anthropic/v1" \
  --main-window-vision-model "qwen3.5-plus" \
  --main-window-vision-thinking-budget-tokens 1024
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

Explicitly force-minimize the chat window after sending:

```bash
skills/wechat-send-file/scripts/send_wechat_file.sh \
  --chat "新技术讨论" \
  --path /home/ivan/Documents/demo.txt \
  --post-send-force-minimize
```

## Constraints

- This skill assumes Ubuntu X11. By default the wrapper auto-resolves the local `PyWxDump` clone; use `--pywxdump-root` to override it when needed.
- `--window-mode standalone` requires the target chat to already be open as an independent WeChat window.
- `--window-mode main` relies on WeChat main-window search and post-send database verification.
- For `--window-mode main`, the first successful send to a target warms that target. Later sends can reuse the lighter `warm_search_enter_refocus` path.
- For `--window-mode main`, prefer `qwen3.5-plus` as the search-result vision model if you explicitly configure `PyWxDump` main-window vision options.
- For `--window-mode main` with Coding Plan, prefer `https://coding.dashscope.aliyuncs.com/apps/anthropic/v1` instead of the older OpenAI-compatible `/v1` endpoint.
- The underlying CLI now supports `--main-window-vision-timeout-seconds`, `--main-window-vision-thinking-budget-tokens`, and `--main-window-vision-disable-thinking`.
- JPEG is excluded by default because the current workflow often needs “send anything except JPEG”.
- By default the wrapper enables `--post-send-force-minimize`, so the send target window is minimized after a successful send instead of restoring focus.
- `--post-send-minimize` minimizes the target window only when there is no previous window to restore.
- `--post-send-force-minimize` always minimizes the target window after sending and takes priority over restore behavior.

## Selftest

真实验收默认会生成一个带 `[SELFTEST]` 标识的本地 Markdown 文件，并把它发送到 `新技术讨论`。

```bash
skills/wechat-send-file/scripts/selftest.sh
```

只做无副作用检查：

```bash
skills/wechat-send-file/scripts/selftest.sh --safe
```

## Resources

- `scripts/send_wechat_file.sh`: choose a file, expose `window_mode` / GUI timing parameters, and call `PyWxDump send-file`.
- `scripts/selftest.sh`: real selftest for file generation, live send, and dry-run inspection
