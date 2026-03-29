---
name: wechat-send-file
description: Send a local file to a specified WeChat chat or group on Ubuntu X11 through the local `PyWxDump` send pipeline. Use when the user asks to send a file to a WeChat conversation, wants a file auto-picked from `~/Documents`, wants to avoid JPEGs by default, or wants the GUI send flow wrapped into a reusable command.
---

# Wechat Send File

## Overview

Use `scripts/send_wechat_file.sh` to send a local file through `PyWxDump tools/linux_wx_chat_daemon.py send-file`. Prefer an explicit file path when the user gives one; otherwise, auto-pick from `~/Documents`, excluding JPEG files unless the user explicitly allows them.

在这台机器上，执行环境必须固定使用 `~/github/PyWxDump/.venv/bin/python`。不要使用系统 `python3`，否则容易再次触发 `Cryptodome` / `Pillow` 之类的依赖缺失问题。

默认行为是**直接发送**（除非你传 `--print-only`）并对 `standalone/auto` 模式下的窗口名做模糊匹配。发送成功后默认走 `--post-send-force-minimize`，脚本会尝试让发送窗口最小化到后台并在结果里返回 `restore_action=minimized`。

Standalone/auto 模式下支持独立窗口名模糊匹配：输入聊天名片段就能匹配到具体独立窗口，如 `meeting` 匹配 `meeting` 群窗口。

首次会话或数据库未预热时，默认会通过 `--allow-missing-msg-table` 允许发送后跳过消息表回读校验。

When `--window-mode main` is used for a target that has not been warmed before, the underlying `PyWxDump` flow may need a vision model to click the correct search result row. In practice, `qwen3.5-plus` is the stable choice for this step. If you use 阿里云 Coding Plan, prefer the native Anthropic-compatible endpoint `https://coding.dashscope.aliyuncs.com/apps/anthropic/v1`. Do not assume `qwen3-coder-plus` is reliable for main-window search-result selection.

## Workflow

1. Determine the target chat title.
2. `standalone|auto` 下先做聊天窗口模糊匹配，仅用于独立窗口发送。
3. If the user provided a file path, use it directly.
4. If the user only said “随便找个文件”, let the script auto-pick from `~/Documents`.
5. Exclude `jpg/jpeg` by default. Only include them when the user explicitly allows JPEG.
6. Choose `--window-mode standalone|main|auto` depending on whether the chat is already open as an independent window.
7. Run the send script. The wrapper delegates to `PyWxDump tools/linux_wx_chat_daemon.py send-file`.
8. Read the final JSON and the extra wrapper summary line to inspect `post_send_check`, `matched_local_id`, and `restore_action`.

## Quick Use

简写命令（兼容）:

```bash
wechat-send-file bot ~/Documents/test.md
```

Explicit file path:

```bash
skills/wechat-send-file/scripts/send_wechat_file.sh \
  --chat "新技术讨论" \
  --path ~/Documents/videos/IMG_9069.MOV
```

Use the main WeChat window instead of a standalone chat window:

```bash
skills/wechat-send-file/scripts/send_wechat_file.sh \
  --chat "新技术讨论" \
  --window-mode main \
  --path ~/Documents/demo.txt
```

Use explicit main-window vision settings for a new target:

```bash
skills/wechat-send-file/scripts/send_wechat_file.sh \
  --chat "丁国华" \
  --window-mode main \
  --path ~/Documents/demo.txt \
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

## Constraints

- This skill assumes Ubuntu X11 and the local `PyWxDump` clone under `~/github/PyWxDump`.
- On this machine, always run through `~/github/PyWxDump/.venv/bin/python`. Do not fall back to system `python3` when executing live sends.
- `--window-mode standalone` requires the target chat to already be open as an independent WeChat window.
- `--window-mode main` relies on WeChat main-window search and post-send database verification.
- `--chat` 在 `standalone|auto` 模式下会先做模糊窗口匹配，匹配多于一个时会中止以避免误发。
- For `--window-mode main`, the first successful send to a target warms that target. Later sends can reuse the lighter `warm_search_enter_refocus` path.
- For `--window-mode main`, prefer `qwen3.5-plus` as the search-result vision model if you explicitly configure `PyWxDump` main-window vision options.
- For `--window-mode main` with Coding Plan, prefer `https://coding.dashscope.aliyuncs.com/apps/anthropic/v1` instead of the older OpenAI-compatible `/v1` endpoint.
- The underlying CLI now supports `--main-window-vision-timeout-seconds`, `--main-window-vision-thinking-budget-tokens`, and `--main-window-vision-disable-thinking`.
- JPEG is excluded by default because the current workflow often needs “send anything except JPEG”.
- 默认行为会直接发送（非 `--print-only`），`restore_action` 由下游 `PyWxDump` 返回，当前默认值为 `minimized`（成功后发送窗口回退到后台）。

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
