---
name: wechat-chat-watch
description: Watch one WeChat chat or all chats on Linux through PyWxDump and stream structured new-message events. Use when the user wants to monitor a chat, emit JSON or webhook events, or enable PyWxDump media and link enrichment while watching.
---

# Wechat Chat Watch

## Overview

Use this skill to wrap `tools/linux_wx_chat_daemon.py watch` from PyWxDump.

It supports:

- target chat or all chats
- text or JSON output
- webhook forwarding
- optional image, video, voice, and link processing

## Workflow

1. Confirm the target chat or choose `--all-chats`.
2. Decide whether JSON or webhook output is needed.
3. Disable expensive enrichments only when the user explicitly wants a lighter watcher.
4. Run `scripts/watch_wechat_chat.sh`.

## Quick Use

Watch one chat:

```bash
skills/wechat-chat-watch/scripts/watch_wechat_chat.sh \
  --target "新技术讨论"
```

Watch all chats as JSON:

```bash
skills/wechat-chat-watch/scripts/watch_wechat_chat.sh \
  --all-chats \
  --format json
```

Watch one chat and forward to webhook:

```bash
skills/wechat-chat-watch/scripts/watch_wechat_chat.sh \
  --target "新技术讨论" \
  --webhook "http://127.0.0.1:8080/hook"
```

## Constraints

- This skill assumes `/home/ivan/github/PyWxDump` exists.
- `--all-chats` disables some enrichments in the current PyWxDump implementation.
- The underlying watcher is event-driven and depends on local WeChat database updates.

## Selftest

真实验收默认会后台启动 watcher，自行向 `新技术讨论` 注入一条带 `[SELFTEST]` 标记的消息，并验证 watcher 输出确实捕获到该消息。

```bash
skills/wechat-chat-watch/scripts/selftest.sh
```

只做无副作用检查：

```bash
skills/wechat-chat-watch/scripts/selftest.sh --safe
```

## Resources

- `scripts/watch_wechat_chat.sh`: wrapper for `linux_wx_chat_daemon.py watch`
- `scripts/selftest.sh`: real selftest for watcher startup, event injection, and capture verification
