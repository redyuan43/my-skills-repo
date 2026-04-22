---
name: wechat-send-file
description: Send a local file to a specified WeChat target on Ubuntu. Normal chats/groups route through the local `PyWxDump` GUI send pipeline; the local WeClaw bot conversation routes through the running `weclaw` HTTP API first and falls back to `~/github/weclaw/weclaw send --file` only when the API is unavailable. For image files on the bot route, prefer sending as an image message and automatically fall back to a file message if the image send fails. Use when the user asks to send a file to a WeChat conversation, wants a file auto-picked from `~/Documents`, wants to avoid JPEGs by default, or wants the GUI/bot send flow wrapped into a reusable command.
---

# Wechat Send File

## Overview

Use `scripts/send_wechat_file.sh` to send a local file. For normal WeChat chats/groups it routes through `PyWxDump tools/linux_wx_chat_daemon.py send-file`. For the local WeClaw bot conversation it now prefers the running `weclaw` API at `http://127.0.0.1:18012/api/send`, so it can reuse the bot's in-memory conversation context; it only falls back to `~/github/weclaw/weclaw send --file` when that API is unavailable. For image files on the bot route, the skill prefers image-message semantics; if that path fails, it automatically retries once as a file attachment. Prefer an explicit file path when the user gives one; otherwise, auto-pick from `~/Documents`, excluding JPEG files unless the user explicitly allows them.

在这台机器上，执行环境必须固定使用 `~/github/PyWxDump/.venv/bin/python`。不要使用系统 `python3`，否则容易再次触发 `Cryptodome` / `Pillow` 之类的依赖缺失问题。

默认行为是**直接发送**（除非你传 `--print-only`）。普通聊天在 `standalone/auto` 模式下会做窗口名模糊匹配，并在成功后默认走 `--post-send-force-minimize`。如果目标是 `bot` / `owner` / `me` 或显式 `@im.wechat` / `@im.bot` ID，则自动改走 `weclaw` 出站发送，不依赖 GUI 聊天窗口。

Standalone/auto 模式下支持独立窗口名模糊匹配：输入聊天名片段就能匹配到具体独立窗口，如 `meeting` 匹配 `meeting` 群窗口。

首次会话或数据库未预热时，默认会通过 `--allow-missing-msg-table` 允许发送后跳过消息表回读校验。

When `--window-mode main` is used for a target that has not been warmed before, the underlying `PyWxDump` flow may need a vision model to click the correct search result row. In practice, `qwen3.5-plus` is the stable choice for this step. If you use 阿里云 Coding Plan, prefer the native Anthropic-compatible endpoint `https://coding.dashscope.aliyuncs.com/apps/anthropic/v1`. Do not assume `qwen3-coder-plus` is reliable for main-window search-result selection.

## Workflow

1. Determine whether the target is a normal WeChat chat/group or the local WeClaw bot conversation.
2. If the target is `bot` / `owner` / `me` or an explicit `@im.wechat` / `@im.bot` ID, route through the local `weclaw` send path.
3. Otherwise, `standalone|auto` 下先做聊天窗口模糊匹配，仅用于独立窗口发送。
4. If the user provided a file path, use it directly.
5. If the user only said “随便找个文件”, let the script auto-pick from `~/Documents`.
6. Exclude `jpg/jpeg` by default. Only include them when the user explicitly allows JPEG.
7. For normal chats, choose `--window-mode standalone|main|auto` depending on whether the chat is already open as an independent window.
8. Read the final summary line. `PyWxDump` 路径关注 `post_send_check` / `matched_local_id` / `restore_action`，`weclaw` 路径关注 `status=sent route=weclaw-bot`。
9. By default, bot sends wait briefly for a cached `context_token`; if the `weclaw` API still says there is no cached `context_token`, have the user send the bot a fresh WeChat message first, then retry.

## Quick Use

简写命令（兼容）:

```bash
wechat-send-file bot ~/Documents/test.md
```

Explicit bot route:

```bash
skills/wechat-send-file/scripts/send_wechat_file.sh \
  --chat bot \
  --send-via weclaw-bot \
  --path ~/Documents/test.md
```

Prefer image-message semantics on the bot route:

```bash
skills/wechat-send-file/scripts/send_wechat_file.sh \
  --chat bot \
  --path ~/Documents/demo.png \
  --bot-media-mode image
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

Resolve the bot route without sending:

```bash
skills/wechat-send-file/scripts/send_wechat_file.sh \
  --chat bot \
  --print-only
```

## Constraints

- This skill assumes Ubuntu X11 and the local `PyWxDump` clone under `~/github/PyWxDump`.
- This skill also assumes the local `weclaw` clone under `~/github/weclaw` when sending to the local bot conversation.
- On this machine, always run through `~/github/PyWxDump/.venv/bin/python`. Do not fall back to system `python3` when executing live sends.
- Bot sends do not use the PyWxDump GUI path; they prefer the running `weclaw` API, which can auto-reuse a cached `context_token` for the owner chat.
- `--bot-media-mode auto` will infer `image` for common image extensions and `file` for everything else.
- `--bot-media-mode image` will automatically retry once as `file` if the image-message path fails.
- `--bot-wait-context-seconds` controls how long the bot route waits for a cached `context_token` before failing.
- `--window-mode standalone` requires the target chat to already be open as an independent WeChat window.
- `--window-mode main` relies on WeChat main-window search and post-send database verification.
- `--chat` 在 `standalone|auto` 模式下会先做模糊窗口匹配，匹配多于一个时会中止以避免误发。
- `--chat bot` 不是微信窗口名；它会被解析成 `~/.weclaw/config.json` 里的 `bridge.local_user_id`，再通过运行中的 `weclaw` 会话发送到主人的微信会话。
- For `--window-mode main`, the first successful send to a target warms that target. Later sends can reuse the lighter `warm_search_enter_refocus` path.
- For `--window-mode main`, prefer `qwen3.5-plus` as the search-result vision model if you explicitly configure `PyWxDump` main-window vision options.
- For `--window-mode main` with Coding Plan, prefer `https://coding.dashscope.aliyuncs.com/apps/anthropic/v1` instead of the older OpenAI-compatible `/v1` endpoint.
- The underlying CLI now supports `--main-window-vision-timeout-seconds`, `--main-window-vision-thinking-budget-tokens`, and `--main-window-vision-disable-thinking`.
- JPEG is excluded by default because the current workflow often needs “send anything except JPEG”.
- 默认行为会直接发送（非 `--print-only`），`restore_action` 由下游 `PyWxDump` 返回，当前默认值为 `minimized`（成功后发送窗口回退到后台）。

## Selftest

真实验收默认会生成一个带 `[SELFTEST]` 标识的本地 Markdown 文件，并把它发送到 `新技术讨论`。如果要验证 bot 路径，可以显式指定 `--chat bot --send-via weclaw-bot`。

```bash
skills/wechat-send-file/scripts/selftest.sh
```

```bash
skills/wechat-send-file/scripts/selftest.sh --chat bot --send-via weclaw-bot
```

只做无副作用检查：

```bash
skills/wechat-send-file/scripts/selftest.sh --safe
```

## Resources

- `scripts/send_wechat_file.sh`: choose a file, expose `window_mode` / GUI timing parameters, and route to `PyWxDump send-file` or `weclaw send --file`.
- `scripts/selftest.sh`: real selftest for file generation, live send, and dry-run inspection
