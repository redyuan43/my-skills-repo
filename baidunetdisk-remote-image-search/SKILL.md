---
name: baidunetdisk-remote-image-search
description: Search image content inside Baidu Netdisk folders through the existing CLI-Anything harness. Use when the user wants OCR- or caption-based retrieval scoped to Baidu Netdisk only, wants the agent to sync a remote folder, build a per-scope image index, and return matching remote paths with hit reasons.
---

# Baidu Netdisk Remote Image Search

## Overview

Use `scripts/search_baidunetdisk_images.py` for the stable workflow:

1. sync one Baidu Netdisk folder into the local cache
2. run a per-scope ZBox `sync`
3. search the cached images by OCR/caption/metadata
4. return remote paths, match source, and snippets for review

Default mode is `local-only`. That keeps image bytes on the current machine by preferring local OCR and local Ollama. If stronger vision recall is needed and the user explicitly accepts cloud vision, add `--allow-cloud-vision`.

## When To Use

- 用户说“只搜百度网盘里的图片内容”
- 用户要找“照片里是身份证/营业执照/某个界面/某段文字”
- 用户希望结果只限定在某个网盘目录，不混入其他知识库来源
- 用户希望知道命中是来自 OCR、caption，还是路径/元数据

## Workflow

1. Prefer the script over ad hoc shell glue.
2. Always pass a remote folder scope with `--path` unless the user explicitly wants `/`.
3. Keep the default `--local-only` unless the user明确接受把图片 bytes 发给云端视觉模型。
4. Report remote paths first. When质量重要，再补 `match_source` 和 `snippet`。
5. For larger folders, keep `--sync-cache` enabled so the per-scope index stays incremental.

## Quick Use

Search one folder with local-only defaults:

```bash
python3 "/home/ivan/.codex/skills/baidunetdisk-remote-image-search/scripts/search_baidunetdisk_images.py" \
  "身份证" \
  --path "/照片"
```

Search and print JSON:

```bash
python3 "/home/ivan/.codex/skills/baidunetdisk-remote-image-search/scripts/search_baidunetdisk_images.py" \
  "安全告知书" \
  --path "/电学资料包" \
  --json
```

Allow configured cloud vision only after explicit approval:

```bash
python3 "/home/ivan/.codex/skills/baidunetdisk-remote-image-search/scripts/search_baidunetdisk_images.py" \
  "海边自拍" \
  --path "/旅行照片" \
  --allow-cloud-vision
```

## Constraints

- This skill depends on the existing harness at `/home/ivan/github/CLI-Anything/baidunetdisk/agent-harness`.
- 搜索范围只针对百度网盘图片缓存，不会混入其他 ZBox 主库来源。
- 默认会同步目标目录并更新一个独立的本地 `state_root`。
- `--allow-cloud-vision` 可能把图片 bytes 发给当前 ZBox 配置里的视觉模型提供方；只有在用户明确接受时才使用。

## Resources

- `scripts/search_baidunetdisk_images.py`: wrap the harness search command with stable defaults
