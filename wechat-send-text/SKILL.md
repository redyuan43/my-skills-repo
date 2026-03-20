---
name: wechat-send-text
description: Send text to a specified WeChat chat or group on Ubuntu X11 through the local `PyWxDump` send pipeline. Use when the user wants a reusable text-send wrapper with the same window-mode, GUI prompt, and main-window vision controls as the file and screenshot send skills.
---

# Wechat Send Text

## Overview

Use `scripts/send_wechat_text.sh` to send plain text through `PyWxDump tools/linux_wx_chat_daemon.py send-text`. This skill is intentionally thin: it only resolves arguments, forwards them to the local CLI, and prints the final `restore_action` summary.

在这台机器上，执行环境必须固定使用 `~/github/PyWxDump/.venv/bin/python`。不要使用系统 `python3`，否则容易再次触发 `Cryptodome` / `Pillow` 之类的依赖缺失问题。

默认行为是**直接发送**（除非你传 `--print-only`）且`standalone/auto` 下默认走模糊匹配。`post-send` 阶段默认会强制最小化发送窗口，返回值通常为 `restore_action=minimized`，以便回到后台。

Standalone/auto 模式下会对聊天窗口名做模糊匹配，输入独立聊天窗口名片段即可定位，如 `meeting` 可匹配 `meeting` 群窗口；匹配到多个窗口会直接报错并要求你补充更长关键词。

## Workflow

1. Determine the target chat title.
2. Provide the text explicitly through `--text`.
3. Choose `--window-mode standalone|main|auto`.
4. If `--window-mode main` is used for a new target, optionally pass explicit main-window vision settings.
5. Run the script and read the final JSON plus the extra wrapper summary line.
6. 独立窗口匹配使用 `--chat` 里给出的片段进行包含匹配，若片段无法匹配到独立窗口会尝试原始目标名（适用于主窗口路径）。

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

- This skill assumes Ubuntu X11 and the local `PyWxDump` clone under `~/github/PyWxDump`.
- On this machine, always run through `~/github/PyWxDump/.venv/bin/python`. Do not fall back to system `python3` when executing live sends.
- `--window-mode standalone` requires the target chat to already be open as an independent WeChat window.
- `--window-mode main` relies on WeChat main-window search and post-send database verification.
- For `--window-mode main`, prefer `qwen3.5-plus` plus the Coding Plan Anthropic endpoint when explicit vision settings are needed.
- `--chat` 在 `standalone|auto` 模式下支持窗口名模糊匹配；多窗口命中会中止发送防止误发。
- 默认不需要额外确认，若使用默认参数则会执行发送；`restore_action` 会标识发送后恢复行为（`minimized` 或 `restored`）。

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
