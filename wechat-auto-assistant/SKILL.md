---
name: wechat-auto-assistant
description: Run the PyWxDump event-driven WeChat assistant loop with an external webhook agent that returns structured actions. Use when the user wants a real watch-understand-decide-act loop on Linux WeChat, with explicit allowlisted chats and actions such as send_text, send_file, send_image, or summarize_chat.
---

# Wechat Auto Assistant

## Overview

Use this skill to run the PyWxDump assistant loop:

1. watch new WeChat messages
2. enrich media and links
3. send structured events to an external webhook agent
4. receive structured action JSON
5. execute allowed actions on allowlisted chats

This skill is PyWxDump-specific and depends on the assistant webhook support in `tools/linux_wx_chat_daemon.py`.

## Send Safety Gate

This skill can execute outbound actions continuously, so the gate is stricter than one-shot send skills. Auto-send is allowed only when all of these are explicit:

- 目标明确：every chat that may receive actions is listed with `--assistant-allow-chat`.
- 内容/动作明确：the webhook action contract is restricted to known action types and the requested assistant scope is clear.
- 意图明确：the user explicitly asks to run an assistant that may send messages/files/images or summaries.

If any part is unclear, stop and ask for confirmation. Do not start the watcher in an auto-send mode from a vague “watch this chat” request. Use `--print-only` or `scripts/selftest.sh --safe` for validation.

## Workflow

1. Require one assistant webhook URL.
2. Require at least one `--assistant-allow-chat` value for auto-send.
3. Confirm the user intends to allow outbound assistant actions now.
4. Keep the action contract strict: only `send_text`, `send_file`, `send_image`, `summarize_chat`.
5. Use existing standalone send skills separately when the user wants a one-off send outside the watcher loop.
6. Run `scripts/run_wechat_auto_assistant.sh`.

## Quick Use

Run the assistant for one chat:

```bash
skills/wechat-auto-assistant/scripts/run_wechat_auto_assistant.sh \
  --target "新技术讨论" \
  --assistant-webhook "http://127.0.0.1:8080/assistant" \
  --assistant-allow-chat "新技术讨论"
```

Allow multiple chats but keep auto-send scoped:

```bash
skills/wechat-auto-assistant/scripts/run_wechat_auto_assistant.sh \
  --target "项目群" \
  --assistant-webhook "http://127.0.0.1:8080/assistant" \
  --assistant-allow-chat "项目群" \
  --assistant-allow-chat "Ivan"
```

## Constraints

- This skill assumes `/home/ivan/github/PyWxDump` exists.
- Auto-send only works for chats explicitly listed with `--assistant-allow-chat` and after the send safety gate is satisfied.
- The external webhook must return the structured JSON action contract expected by PyWxDump.
- This skill does not replace one-off send skills; it coordinates a continuous assistant loop.

## Selftest

真实验收默认会启动本地 stub webhook，后台启动 assistant watcher，自动向 `新技术讨论` 注入触发消息，并验证 assistant 已真实执行自动回复。

```bash
skills/wechat-auto-assistant/scripts/selftest.sh
```

只做无副作用检查：

```bash
skills/wechat-auto-assistant/scripts/selftest.sh --safe
```

## Resources

- `scripts/run_wechat_auto_assistant.sh`: wrapper around `linux_wx_chat_daemon.py watch` with assistant parameters
- `scripts/selftest.sh`: real selftest for local assistant webhook, trigger injection, and auto-reply execution
