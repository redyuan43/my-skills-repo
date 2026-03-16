---
name: wechat-chat-summary
description: Export and summarize a WeChat chat through PyWxDump. Use when the user wants a chat summary for a specific chat and time range, wants link-aware summarization, or wants the generated summary optionally sent back to the original chat.
---

# Wechat Chat Summary

## Overview

Use this skill to wrap `tools/linux_wx_chat_daemon.py summarize-chat`.

It supports:

- time-range filtering
- all-history or recent-limit export
- optional link-to-doc preprocessing
- Markdown summary output
- optional send-back of the compact summary

## Workflow

1. Confirm the target chat.
2. Confirm whether the summary should cover all history or a bounded time range.
3. Keep `--with-doc-links` enabled unless the user explicitly wants raw-message summarization only.
4. Run `scripts/summarize_wechat_chat.sh`.

## Quick Use

Summarize the recent window:

```bash
skills/wechat-chat-summary/scripts/summarize_wechat_chat.sh \
  --target "新技术讨论" \
  --since "2026-03-15" \
  --until "2026-03-16"
```

Summarize the full chat:

```bash
skills/wechat-chat-summary/scripts/summarize_wechat_chat.sh \
  --target "新技术讨论" \
  --all
```

Summarize and send the compact result back:

```bash
skills/wechat-chat-summary/scripts/summarize_wechat_chat.sh \
  --target "新技术讨论" \
  --limit 300 \
  --send-back
```

## Constraints

- This skill assumes `/home/ivan/github/PyWxDump` exists.
- Summary quality depends on the configured summary model and available local chat history.
- `--send-back` writes to the live WeChat chat window, so use it only when the user clearly wants that action.

## Resources

- `scripts/summarize_wechat_chat.sh`: wrapper for `linux_wx_chat_daemon.py summarize-chat`
