---
name: wechat-archive
description: Read-only search, summarize, and analyze the WeChat chat archive under /home/nx/chat_archive. Use when the user asks to summarize one day, analyze a specific chat/official account, search topics, compare dates, build topic memory cards, or inspect archive evidence. Indexing, systemd, and deployment details live in references.
---

# WeChat Archive

Use this skill for read-only WeChat archive queries backed by OpenViking.

## Default Mode

默认只做只读查询、总结和分析：

- semantic search
- daily summary
- chat summary
- topic report
- hotspots
- compare days
- timeline report
- sender report
- top articles
- local file discovery with `archive_locator.py`

Do not rebuild indexes, change systemd units, enable timers, or deploy services unless the user explicitly asks for operations work.

## Scope

- Source archive: `/home/nx/chat_archive`
- Exported Markdown corpus: `/home/nx/chat_archive/.openviking_export`
- OpenViking target URI: `viking://resources/wechat_archive`
- HTTP search endpoint: `http://127.0.0.1:1934`
- Main entrypoint: `/home/nx/github/OpenViking/examples/wechat_archive_agent.py`
- Wrapper: `scripts/run_wechat_archive_agent.sh`
- File locator helper: `scripts/archive_locator.py`

## Workflow

1. Resolve relative dates such as today/yesterday to absolute dates before running commands.
2. Prefer explicit `--http-url` when running from a different client machine.
3. Use read-only commands first: `search`, `daily-summary`, `chat-summary`, `topic-report`, `hotspots`, `compare-days`, `timeline-report`, `sender-report`, `top-articles`.
4. Use `archive_locator.py` for exact file discovery or fallback text grep.
5. If the user asks to refresh/rebuild indexes, read `references/index_ops.md` first and confirm the operation.
6. If the user asks to deploy or alter services, read `references/systemd_ops.md` and `references/deploy_ops.md` first and confirm the operation.

## Read-Only Recipes

Search:

```bash
wechat-archive/scripts/run_wechat_archive_agent.sh search "自动驾驶" --limit 5
```

Daily summary:

```bash
wechat-archive/scripts/run_wechat_archive_agent.sh daily-summary "2026-03-30"
```

Chat summary:

```bash
wechat-archive/scripts/run_wechat_archive_agent.sh chat-summary "动点科技" --date "2026-03-30"
```

Topic analysis:

```bash
wechat-archive/scripts/run_wechat_archive_agent.sh topic-report "FSD 特斯拉"
wechat-archive/scripts/run_wechat_archive_agent.sh compare-days "2026-03-30" "2026-03-31"
wechat-archive/scripts/run_wechat_archive_agent.sh top-articles --date "2026-03-31" --limit 5
```

Fallback file discovery:

```bash
python3 wechat-archive/scripts/archive_locator.py chats
python3 wechat-archive/scripts/archive_locator.py daily-files "2026-03-30"
python3 wechat-archive/scripts/archive_locator.py topic-grep "自动驾驶"
```

## Safe Selftest

```bash
wechat-archive/scripts/selftest.sh --safe
```

## References

- `references/index_ops.md`: export/index rebuild and durable report sync
- `references/systemd_ops.md`: service units, timers, and health checks
- `references/deploy_ops.md`: cross-device HTTP usage and deployment notes
