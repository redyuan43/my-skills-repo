---
name: wechat-link-to-doc
description: Convert a WeChat-shared link, especially a WeChat article URL, into a local Markdown document bundle through PyWxDump. Use when the user wants to turn one URL into `document.md` plus assets, or wants a stable local artifact for downstream summarization and analysis.
---

# Wechat Link To Doc

## Overview

Use this skill to wrap `tools/link_doc_hook.py` from PyWxDump.

This skill takes a URL and an output directory, then asks the hook pipeline to generate:

- `document.md`
- `source.json`
- optional `assets/`

## Workflow

1. Require one URL and one output directory.
2. Prefer `wechat_article` when the URL is clearly from `mp.weixin.qq.com`.
3. Use `generic_web` for other URLs unless the user explicitly needs another doc type.
4. Run `scripts/wechat_link_to_doc.sh`.

## Quick Use

Convert a WeChat article:

```bash
skills/wechat-link-to-doc/scripts/wechat_link_to_doc.sh \
  --url "https://mp.weixin.qq.com/s/xxxx" \
  --output-dir "/tmp/wechat-doc"
```

Convert a generic web page:

```bash
skills/wechat-link-to-doc/scripts/wechat_link_to_doc.sh \
  --url "https://example.com/post" \
  --output-dir "/tmp/web-doc" \
  --doc-type generic_web
```

## Constraints

- This skill assumes `/home/ivan/github/PyWxDump` exists.
- The hook can depend on external tooling or crawlers that PyWxDump already expects on this machine.
- The output directory is created or reused locally.

## Resources

- `scripts/wechat_link_to_doc.sh`: wrapper around `tools/link_doc_hook.py`
