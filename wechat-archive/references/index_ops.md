# WeChat Archive Index Operations

Indexing is not the default mode of the skill. Run it only when the user explicitly asks to refresh or rebuild the archive.

## Refresh index

```bash
wechat-archive/scripts/run_wechat_archive_agent.sh index
```

Common args:

- `--source` default `/home/nx/chat_archive`
- `--export-root` default `/home/nx/chat_archive/.openviking_export`
- `--target` default `viking://resources/wechat_archive`
- `--workspace` default `/home/nx/.openviking-wechat-archive-local-gpu`
- `--timeout`
- `--wait`
- `--watch-interval`
- `--semantic-concurrency`
- `--embedding-concurrency`
- `--semantic-llm-timeout`
- `--embedding-text-source`

Block until queue completion only when requested:

```bash
wechat-archive/scripts/run_wechat_archive_agent.sh index \
  --wait \
  --timeout 7200 \
  --embedding-text-source content_only \
  --semantic-concurrency 2 \
  --embedding-concurrency 4 \
  --semantic-llm-timeout 180
```

If embedding rules changed and the user wants a full rebuild, confirm before removing any existing target or export.

## Durable derived outputs

```bash
wechat-archive/scripts/run_wechat_archive_agent.sh topic-memory-card "自动驾驶"
wechat-archive/scripts/run_wechat_archive_agent.sh watchlist-alerts
```

Defaults:

- report root: `/home/nx/chat_archive/index/derived`
- report target: `viking://resources/wechat_archive_reports`

These may sync derived reports back into OpenViking; confirm before running when the user did not explicitly ask for persistence.
